-- ===========================================================================
-- 条目15：队友资源可见性显示（STR）——移植自联机工具箱 1.67（工坊 3693899014 STR 目录）
-- 同队队友已通过科技/市政解锁、而本地玩家尚未解锁的资源，在地图已探索迷雾格显示迷雾样式
-- 图标（条目9 顶部面板「队友战略资源清单」的地图侧对应能力）。
-- 实现：include 原版 WorldViewIconsManager 后覆盖 Initialize/GetNonEmptyAt/
-- OnResearchCompleted/OnCivicCompleted/OnShutdown；原版该文件仅 Base 一个版本
-- （DLC/资料片无变体，已验证），无需版本探测（区别条目9/14 的 Exp 探测）。
-- 相对 1.67（WorldViewIconsManager_STR.lua）的优化：
--   1. 观察者/热座 nil 防御——本 mod 条目7 有观战功能，观察者非主要玩家，1.67 每回合
--      Players[Game.GetLocalPlayer()]:GetTeam() 报错；全部入口加 -1/nil 守卫
--   2. GetTeamVisibleResources/_Governor 两个 90% 重复函数合并为 MPT_UpdateTeamVisibleResources()
--   3. 解锁科技/市政表由数组线性扫描改为 [Type]=Index O(1) 映射；未解锁资源表存轻量 {Index, Hash}
--   4. 本地玩家自己已可见的资源从扫描表剪除（1.67 永久残留致空表早退失效）
--   5. LoadGameViewStateDone + Initialize 尾部立即同步（1.67 读档/中途加入后要等首回合结束才首次扫描）
--   6. OnShutdown 覆盖：卸载本功能注册的全部监听（1.67 注册后从不清除）
--   7. Events.GovernorAppointed 仅 Exp1+ 存在（总督/结社），挂载/卸载前 nil 守卫
--   8. 外部刷新接口 LuaEvents.TPT_WorldViewIcon_Rebuild → MPT_WorldViewIcon_Rebuild（与 1.67 互不联动）
-- 注册：ReplaceUIScript(LuaContext=WorldViewIconsManager, LoadOrder 100000) 投递本文件 + ImportFiles(100010)
-- ===========================================================================

-- ===========================================================================
-- INCLUDES（原版基类：先载入再捕获覆盖）
-- ===========================================================================
include( "WorldViewIconsManager" );

-- ===========================================================================
--	OVERRIDES（捕获原版函数：先捕获后覆盖，覆盖版内部回调原版）
-- ===========================================================================
BASE_Initialize = Initialize
BASE_OnShutdown = OnShutdown

-- ===========================================================================
-- 全局变量
-- ===========================================================================
local m_TeamVisibleResources	: table = {};		-- 队友已解锁的资源（resource Index => true），GetNonEmptyAt 显示判定用
local m_UnlockResources			: table = {};		-- 本地玩家未解锁的资源轻量表（{Index, Hash} 数组，倒序遍历剪除）

-- 解锁映射表（O(1) 查表，替代 1.67 数组线性扫描）
local MPT_TechsThatUnlockResources		: table = {};	-- [TechnologyType] = resource Index
local MPT_CivicsThatUnlockResources		: table = {};	-- [CivicType] = resource Index
local MPT_TechsThatUnlockImprovements	: table = {};	-- 改良设施解锁科技 set（[TechnologyType] = true，语义同原版数组）

-- ===========================================================================
-- 核心：扫描队友资源可见性——本地已可见的剪除扫描表（引擎自行显示）；
-- 队友已可见的标记进 m_TeamVisibleResources；有新增时 Rebuild 地图图标并返回 true。
-- 空表/观察者/热座空位直接跳过（观察者本地玩家非主要玩家，1.67 此处每回合报错）。
-- 用法：MPT_UpdateTeamVisibleResources() → boolean（是否发生刷新）
-- ===========================================================================
function MPT_UpdateTeamVisibleResources()
	local localPlayerID : number = Game.GetLocalPlayer();
	if localPlayerID == -1 or Players[localPlayerID] == nil then
		return false;		-- 观察者/热座空位：无法参与队伍判定
	end
	if #m_UnlockResources == 0 then
		return false;		-- 全部资源已处理完毕，免每回合空扫
	end

	local localPlayerResources	: table = Players[localPlayerID]:GetResources();
	local localPlayerTeam		: number = Players[localPlayerID]:GetTeam();
	local NeedRebuild			: boolean = false;

	for _, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
		if localPlayerID ~= playerID and Players[playerID]:GetTeam() == localPlayerTeam then		-- 是队友
			local pPlayerResources : table = Players[playerID]:GetResources();
			for i = #m_UnlockResources, 1, -1 do		-- 倒序遍历便于 table.remove
				local kResource = m_UnlockResources[i];
				if localPlayerResources:IsResourceVisible(kResource.Hash) then
					table.remove(m_UnlockResources, i);		-- 本地玩家自己已解锁（引擎可见层自行显示），移出扫描表即可
				elseif pPlayerResources:IsResourceVisible(kResource.Hash) then
					if not m_TeamVisibleResources[kResource.Index] then
						NeedRebuild = true;
						m_TeamVisibleResources[kResource.Index] = true;
					end
					table.remove(m_UnlockResources, i);
				end
			end
		end
	end

	if NeedRebuild then
		Rebuild();
	end
	return NeedRebuild;
end

-- ===========================================================================
-- 事件处理器：回合结束扫描队友可见性
-- ===========================================================================
function OnMPTLocalPlayerTurnEnd()
	MPT_UpdateTeamVisibleResources();
end

-- ===========================================================================
-- 事件处理器：总督任命一次性补扫（结社/总督解锁场景）——产生过一次刷新即自移除
-- （保持 1.67 语义；无变化则继续等待下次任命）
-- ===========================================================================
function OnMPTGovernorAppointed(playerID:number, governorID:number)
	if MPT_UpdateTeamVisibleResources() and Events.GovernorAppointed ~= nil then
		Events.GovernorAppointed.Remove(OnMPTGovernorAppointed);
	end
end

-- ===========================================================================
-- 事件处理器：读档/中途加入完成——立即同步（1.67 需等首回合结束，期间地图图标缺失）
-- ===========================================================================
function OnMPTLoadGameViewStateDone()
	MPT_UpdateTeamVisibleResources();
end

-- ===========================================================================
--	OVERRIDE：格子图标取用（基于原版复制 + 追加队友已解锁资源分支）
-- 原版仅按引擎可见层（本地已解锁）显示；追加分支：格子实际资源已被队友解锁
-- （m_TeamVisibleResources 命中）时按迷雾样式 REVEALED 显示。
-- 优化：GetResourceType 取值加 pPlot nil 守卫（1.67 无守卫，pPlot 为 nil 时报错）
-- ===========================================================================
function GetNonEmptyAt(plotIndex, state)
	local eObserverID = Game.GetLocalObserver();
	local pLocalPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(eObserverID);
	if (pLocalPlayerVis ~= nil) then
		local pInstance = nil;
		local pPlot = Map.GetPlotByIndex(plotIndex);
		-- Have a Resource?
		local eResource = pLocalPlayerVis:GetLayerValue(VisibilityLayerTypes.RESOURCES, plotIndex);
		local bHideResource = ( pPlot ~= nil and ( pPlot:GetDistrictType() > 0 or pPlot:IsCity() ) );
		local eResourceType = ( pPlot ~= nil and pPlot:GetResourceType() ) or -1;		-- 格子实际资源（引擎可见层只含本地已解锁，队友已解锁的走下一分支）
		if (eResource ~= nil and eResource ~= -1 and not bHideResource and GameCapabilities.HasCapability("CAPABILITY_DISPLAY_MINIMAP_RESOURCES")) then
			pInstance = GetInstanceAt(plotIndex);
			SetResourceIcon(pInstance, pPlot, eResource, state);
		elseif (eResourceType ~= -1 and m_TeamVisibleResources[eResourceType] and not bHideResource and GameCapabilities.HasCapability("CAPABILITY_DISPLAY_MINIMAP_RESOURCES")) then		-- 队友已解锁：按迷雾样式显示
			pInstance = GetInstanceAt(plotIndex);
			SetResourceIcon(pInstance, pPlot, eResourceType, RevealedState.REVEALED);
		else
			UnloadResourceIconAt(plotIndex);
		end
		if (pPlot) then
			-- Starting plot?
			if pPlot:IsStartingPlot() and WorldBuilder.IsActive() and WorldBuilder.GetWBAdvancedMode() then
				pInstance = GetInstanceAt(plotIndex);
				pInstance.RecommendationIconTexture:TrySetIcon("ICON_UNITOPERATION_FOUND_CITY", 256);
				pInstance.RecommendationIconText:SetHide( false );

				local iPlayer = GetStartingPlotPlayer( pPlot );
				if (iPlayer >= 0) then
					pInstance.RecommendationIconText:SetText( tostring(iPlayer + 1) );
				else
					pInstance.RecommendationIconText:SetText( "" );
				end
			else
				UnloadRecommendationIconAt(plotIndex);
			end
		end
		return pInstance;
	end
end

-- ===========================================================================
--	OVERRIDE：研究完成（原版仅本地玩家；扩展为同队队友——队友研究的解锁科技
-- 命中资源映射表时标记并重建；命中改良解锁科技时仅重建）
-- ===========================================================================
function OnResearchCompleted( player:number, tech:number, isCanceled:boolean )
	local localPlayerID : number = Game.GetLocalPlayer();
	if localPlayerID == -1 or Players[localPlayerID] == nil or Players[player] == nil then
		return;
	end
	if Players[localPlayerID]:GetTeam() == Players[player]:GetTeam() or player == localPlayerID then		-- 自己或队友
		local techType = GameInfo.Technologies[tech].TechnologyType;
		local resourceIndex = MPT_TechsThatUnlockResources[techType];
		if resourceIndex ~= nil then
			if not m_TeamVisibleResources[resourceIndex] then
				m_TeamVisibleResources[resourceIndex] = true;
				Rebuild();
			end
			return;
		end
		if MPT_TechsThatUnlockImprovements[techType] then
			Rebuild();
		end
	end
end

-- ===========================================================================
--	OVERRIDE：市政完成（原版仅本地玩家；扩展为同队队友，同 OnResearchCompleted）
-- ===========================================================================
function OnCivicCompleted( player:number, civic:number, isCanceled:boolean )
	local localPlayerID : number = Game.GetLocalPlayer();
	if localPlayerID == -1 or Players[localPlayerID] == nil or Players[player] == nil then
		return;
	end
	if Players[localPlayerID]:GetTeam() == Players[player]:GetTeam() or player == localPlayerID then		-- 自己或队友
		local resourceIndex = MPT_CivicsThatUnlockResources[GameInfo.Civics[civic].CivicType];
		if resourceIndex ~= nil and not m_TeamVisibleResources[resourceIndex] then
			m_TeamVisibleResources[resourceIndex] = true;
			Rebuild();
		end
	end
end

-- ===========================================================================
-- 事件处理器：区域拍下（区域/城市盖住队友已解锁资源时按可见性刷新该格图标）
-- ===========================================================================
function OnMPTDistrictAddedToMap(playerID, districtID, cityID, iX, iY, districtType, percentComplete)
	if UI.IsInGame() == false then
		return;
	end
	local eObserverID = Game.GetLocalObserver();
	local pLocalPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(eObserverID);
	if (pLocalPlayerVis ~= nil) then
		local visibilityType	= pLocalPlayerVis:GetState(iX, iY);
		local plotIndex:number = GetPlotIndex(iX, iY);
		if plotIndex == -1 then
			return;
		end
		if (visibilityType == RevealedState.HIDDEN) then
			UnloadResourceIconAt(plotIndex);
		elseif (visibilityType == RevealedState.REVEALED) then
			ChangeToMidFog(plotIndex);
		elseif (visibilityType == RevealedState.VISIBLE) then
			ChangeToVisible(plotIndex);
		end
	end
end

-- ===========================================================================
--	OVERRIDE：UI 关闭（先卸载本功能监听（1.67 从不清除），再回调原版卸载）
-- ===========================================================================
function OnShutdown()
	Events.LocalPlayerTurnEnd.Remove(OnMPTLocalPlayerTurnEnd);
	Events.DistrictAddedToMap.Remove(OnMPTDistrictAddedToMap);
	Events.LoadGameViewStateDone.Remove(OnMPTLoadGameViewStateDone);
	if Events.GovernorAppointed ~= nil then		-- 仅 Exp1+ 存在（总督/结社）
		Events.GovernorAppointed.Remove(OnMPTGovernorAppointed);
	end
	LuaEvents.MPT_WorldViewIcon_Rebuild.Remove( Rebuild );

	BASE_OnShutdown();
end

-- ===========================================================================
--	OVERRIDE：初始化（先回调原版注册原版监听，再注册本功能监听并构建数据表）
-- 注意：原版文件尾部自身会执行一次 Initialize()（include 时已注册原版监听），
-- 此处与 1.67 一致仍回调 BASE_Initialize（事件重复注册均为幂等处理器，1.67 生产验证无害）。
-- ===========================================================================
function Initialize()
	BASE_Initialize();

	Events.LocalPlayerTurnEnd.Add(OnMPTLocalPlayerTurnEnd);
	Events.DistrictAddedToMap.Add(OnMPTDistrictAddedToMap);
	Events.LoadGameViewStateDone.Add(OnMPTLoadGameViewStateDone);
	if Events.GovernorAppointed ~= nil then		-- 仅 Exp1+ 存在（总督/结社）
		Events.GovernorAppointed.Add(OnMPTGovernorAppointed);
	end
	LuaEvents.MPT_WorldViewIcon_Rebuild.Add( Rebuild );		-- 外部刷新接口（1.67 TPT_WorldViewIcon_Rebuild 的 MPT 命名版）

	for row in GameInfo.Resources() do
		if row.PrereqTech ~= nil then
			MPT_TechsThatUnlockResources[row.PrereqTech] = row.Index;
		end
		if row.PrereqCivic ~= nil then
			MPT_CivicsThatUnlockResources[row.PrereqCivic] = row.Index;
		end
	end

	for row in GameInfo.Improvements() do
		if row.PrereqTech ~= nil then
			MPT_TechsThatUnlockImprovements[row.PrereqTech] = true;
		end
	end

	-- 本地玩家当前未解锁资源（队友可见性扫描范围；轻量 {Index, Hash}）
	local localPlayerID : number = Game.GetLocalPlayer();
	if localPlayerID ~= -1 and Players[localPlayerID] ~= nil then
		local pPlayerResources : table = Players[localPlayerID]:GetResources();
		for row in GameInfo.Resources() do
			if not pPlayerResources:IsResourceVisible(row.Hash) then
				table.insert(m_UnlockResources, {Index = row.Index, Hash = row.Hash});
			end
		end
		MPT_UpdateTeamVisibleResources();		-- 初始化即同步一次（读档/中途加入场景不等首回合）
	end
end
Initialize();
