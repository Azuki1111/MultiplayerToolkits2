-- ===========================================================================
-- 条目24：外交丝带扩展（DPR）+ BSM 观察者兼容——移植自联机工具箱 1.67（工坊 3693899014 DPR/UI/DiplomacyRibbon_TPT.lua）
-- 基底 = DPR 完整独立 fork（不 include 原版 DiplomacyRibbon 链，样式基准），本文件在其上叠加：
--   1. 分组重构（用户裁决）：XML StatStack 分组（Group_Stock/Group_Rate/Group_TechCivis/Group_Observer），
--      FinishAddingLeader 原约 40 行逐 Label SetHide → 组级一次 SetHide；组内个别 SetHide 仅保留给
--      信息披露门槛（Model 三档/IsTeamPlayer/isMasked）与观察者 Army 视图等特例。
--   2. BSM 观察者兼容（Better Spectator Mod 工坊 1916397407，diplomacyribbon_spec.lua 移植）：
--      本地玩家为 LEADER_SPECTATOR 时点头像切 POV（UIEvents.UIDoObserverPlayer / GameConfiguration
--      "OBSERVER_ID_<n>" / LuaEvents.DiplomacyRibbon_Click 三键名为 BSM 生态协议，其 worldtracker 等
--      靠它刷新，勿改）；观察者丝带显示全部玩家（teamer×观察者四象限排序）；观察者条目六视图
--      （Score/Techs/Eras/Army/Yield/Total）+ 20 秒轮播（OnTimePasses）+ Host/Ping；非观战局观察者
--      组整体隐藏零侵入。原 BSM HideSpecInfo 40 余行逐控件隐藏 → Group_Observer 组级 2 次 SetHide。
--      修复：BSM 观察者检测循环误用本地玩家 LeaderType 判断第 i 位（其非观察者分支成死代码），
--      改查 Players[i]，四象限分支对非观察者也生效。
--   3. 科文仪表真实预估（用户裁决）：RefreshTechMeter/RefreshCivisMeter 加速值由 DPR 朴素百分比
--      公式改 MPT_EngineBoost 引擎精确定点链（条目14 TechAndCivicSupport，Ghidra 反编译复刻、
--      39 组实测全对）+ DPR 按目标玩家的 modifier 附加加速（MPT_GetBoostValue 兜底回退原公式）。
--   4. 裁剪（相对 BSM）：Data0..Data7 死控件剔除（BSM 中被无条件隐藏）；BSM 队名前缀（Name 行
--      [NEWLINE] 队名）不移植——与 DPR 玩家名测宽居中布局冲突，样式以 DPR 为准。
--   5. 玩家名/文明名开关双通道：同时监听条目12 MPT_Settings_Toggle 与 1.67 TPT_Settings_Toggle。
-- 与 1.67 同装：本文件 ReplaceUIScript 100000 压过其 DPR(101)；参数/热键沿用 1.67 原 key 自然共享。
-- 与 BSM 同装：100000 压过其 9999 丝带；其 gameplay 脚本/worldtracker/CityBanner 不受影响继续工作。
-- 注册：ReplaceUIScript(LuaContext=DiplomacyRibbon, LoadOrder 100000) + ImportFiles(100010)
-- ===========================================================================
-- Copyright 2017-2019, Firaxis Games.
-- Leader container list on top of the HUD

include("InstanceManager");
include("LeaderIcon");
include("PlayerSupport");
include("SupportFunctions");
include( "PopupDialog" );
include("TechAndCivicSupport");		-- 条目24：复用条目14 的 MPT_EngineBoost（引擎精确加速值）；带 MPT_GetBoostValue 兜底

-- ===========================================================================
--	条目24 分区：BSM 观察者状态（键名与语义原样保留自 BSM 协议）
--	注意：这些 local 必须先于本文件中所有使用它们的函数定义（Lua 词法作用域，声明顺序踩坑见技能库）
-- ===========================================================================
UIEvents = nil;						-- BSM 协议桥：LateInitialize 时取 ExposedMembers.LuaEvents（BSM gameplay 脚本写入）
local bspec_loc		= false;		-- 本地玩家是观察者
local bspec_game	= false;		-- 场上存在观察者
local bspec_loc_id	= -1;			-- 本地观察者的玩家 ID
local m_first_spec_id	= -1;		-- 场上首个观察者的玩家 ID（主观察者条目）
local b_hide		= false;		-- 轮播相位：true=基础统计行隐藏（BSM 语义）
local b_hide_2		= true;			-- 轮播相位：true=科文仪表隐藏（与 b_hide 恒互补）
local b_score		= false;		-- 六视图：Score
local b_trees		= false;		-- 六视图：Techs
local b_eras		= false;		-- 六视图：Eras
local b_army		= false;		-- 六视图：Army
local b_yield		= false;		-- 六视图：Yield
local b_accu		= false;		-- 六视图：Total（累计）
local g_lasttime	= 0;			-- 轮播计时

-- 条目24修复：观察者界面文本本地化（原 BSM 英文硬编码；按本 mod 规约预加载为 local，拼接走 ..）
local SpecStr_Score		= Locale.Lookup("LOC_MPT_DPR_SPEC_SCORE");
local SpecStr_Yield		= Locale.Lookup("LOC_MPT_DPR_SPEC_YIELD");
local SpecStr_Total		= Locale.Lookup("LOC_MPT_DPR_SPEC_TOTAL");
local SpecStr_Techs		= Locale.Lookup("LOC_MPT_DPR_SPEC_TECHS");
local SpecStr_Eras		= Locale.Lookup("LOC_MPT_DPR_SPEC_ERAS");
local SpecStr_Army		= Locale.Lookup("LOC_MPT_DPR_SPEC_ARMY");
local SpecStr_Land		= Locale.Lookup("LOC_MPT_DPR_SPEC_LAND");
local SpecStr_Navy		= Locale.Lookup("LOC_MPT_DPR_SPEC_NAVY");
local SpecStr_Air		= Locale.Lookup("LOC_MPT_DPR_SPEC_AIR");


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local SCROLL_SPEED			 = 3;
local UPDATE_FRAMES			 = 2;	-- HACK: Require 2 frames to update size change :(
local LEADER_ART_OFFSET_X	 = -4;
local LEADER_ART_OFFSET_Y	 = -10;
local LEADER_ART_OFFSET_Z	 = -24;		-- HACK: Require 3th frames to update size change

local GAME_SPEED = GameConfiguration.GetGameSpeedType()
local GAME_SPEED_MULTIPLIER = GameInfo.GameSpeeds[GAME_SPEED] and GameInfo.GameSpeeds[GAME_SPEED].CostMultiplier / 100 or 1

local Invisible = ""		-- 不可见时的符号
-- ===========================================================================
--	自定义设置，显示玩家ID和文明名称
-- ===========================================================================
local HidePlayerInfo_PlayerName = false
local HidePlayerInfo_CiviName = false

local PlayerInfo_Text = {}

function OnTPT_Settings_Toggle(ParameterId, Value)
	if ParameterId == "DiplomacyRibbon_PlayerInfo_PlayerName" then
		HidePlayerInfo_PlayerName = not Value
		UpdateLeaders(true);
		return
	end
	if ParameterId == "DiplomacyRibbon_PlayerInfo_CiviName" then
		HidePlayerInfo_CiviName = not Value
		UpdateLeaders(true);
		return
	end	
end
LuaEvents.TPT_Settings_Toggle.Add(OnTPT_Settings_Toggle)

-- 条目24：条目12 设置面板广播同参数键（双通道——本 mod 设置面板与 1.67 TPT_Settings 均可控制）
function OnMPT_Settings_Toggle(ParameterId, Value)
	OnTPT_Settings_Toggle(ParameterId, Value);
end
LuaEvents.MPT_Settings_Toggle.Add(OnMPT_Settings_Toggle)


-- ===========================================================================
-- 在头像处显示玩家的技能
-- ===========================================================================
function LeaderIcon:GetToolTipString(playerID)
	local result = "";
	local pPlayerConfig = PlayerConfigurations[playerID];
	if pPlayerConfig and pPlayerConfig:GetLeaderTypeName() then
		local isHuman		 = pPlayerConfig:IsHuman();
		local leaderDesc	 = pPlayerConfig:GetLeaderName();
		local civDesc		 = pPlayerConfig:GetCivilizationDescription();
		local localPlayerID	 = Game.GetLocalPlayer();
		if localPlayerID==PlayerTypes.NONE or localPlayerID==PlayerTypes.OBSERVER  then
			return "";
		end
		if GameConfiguration.IsAnyMultiplayer() and isHuman then
			if(playerID ~= localPlayerID and not Players[localPlayerID]:GetDiplomacy():HasMet(playerID)) then
				result = Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER") .. "（" .. pPlayerConfig:GetPlayerName() .. "）";
			else
				result = Locale.Lookup("LOC_DIPLOMACY_DEAL_PLAYER_PANEL_TITLE", leaderDesc, civDesc) .. "（" .. pPlayerConfig:GetPlayerName() .. "）" .. GetPlayerAbilityText(playerID);
			end
		else
			if(playerID ~= localPlayerID and not Players[localPlayerID]:GetDiplomacy():HasMet(playerID)) then
				result = Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER");
			else
				result = Locale.Lookup("LOC_DIPLOMACY_DEAL_PLAYER_PANEL_TITLE", leaderDesc, civDesc) .. GetPlayerAbilityText(playerID);
			end
		end
	end

	return result;
end

            
function GetPlayerAbilityText(playerID)
	if PlayerInfo_Text and PlayerInfo_Text[playerID] then
		return PlayerInfo_Text[playerID]
	end
	local pPlayerConfig	 = PlayerConfigurations[playerID];
	local leaderName = pPlayerConfig:GetLeaderTypeName()
	local civilizationName = pPlayerConfig:GetCivilizationTypeName();
	local Traits = {}
	-- 找到领袖技能
	for row in GameInfo.LeaderTraits() do
		if row.LeaderType == leaderName then
			table.insert(Traits,row.TraitType)
		end
	end
	-- 找到文明技能
	for row in GameInfo.CivilizationTraits() do
		if row.CivilizationType == civilizationName then
			table.insert(Traits,row.TraitType)
		end
	end
	local result = Trait2Text(Traits);
	PlayerInfo_Text[playerID] = result;
	return result
end

function GetPreCT(PreCivic,PreTech)
	local result = '无前置'
    if PreCivic and GameInfo.Civics[PreCivic] then
        result = '[ICON_GoingTo][COLOR_FLOAT_CULTURE]'..Locale.Lookup( GameInfo.Civics[PreCivic].Name )..'[ENDCOLOR]'
    end
    if PreTech and GameInfo.Technologies[PreTech] then
        result = '[ICON_GoingTo][COLOR_Blue]'..Locale.Lookup( GameInfo.Technologies[PreTech].Name )..'[ENDCOLOR]'
    end
    return result
end

function GetPreText(Type)
	local result = ''
    local DisInfo = GameInfo.Districts[Type]
    local BuildingInfo = GameInfo.Buildings[Type]
    local ImprovementInfo = GameInfo.Improvements[Type]
    local UnitInfo = GameInfo.Units[Type]
    if DisInfo then
        -- 前置科文
        result = result..GetPreCT(DisInfo.PrereqCivic,DisInfo.PrereqTech)
    end
    if BuildingInfo then
        -- 前置科文
        result = result..GetPreCT(BuildingInfo.PrereqCivic,BuildingInfo.PrereqTech)
        result = result..'，[ICON_Production] '..BuildingInfo.Cost * GAME_SPEED_MULTIPLIER
    end
    if ImprovementInfo then
        -- 前置科文
        result = result..GetPreCT(ImprovementInfo.PrereqCivic,ImprovementInfo.PrereqTech)
        if ImprovementInfo.PlunderType ~= 'NO_PLUNDER' and ImprovementInfo.PlunderType ~= 'PLUNDER_NONE' then
            result = result..'，掠夺提供：[ICON_'..string.gsub(string.gsub(ImprovementInfo.PlunderType,'HEAL','DAMAGED'),'PLUNDER_','')..']'
        end
    end
    if UnitInfo then
        -- 前置科文
        result = result..GetPreCT(UnitInfo.PrereqCivic,UnitInfo.PrereqTech)
        -- 近战力（如有）、移动力、远程力（如有）、轰炸力（如有）、射程（如有）
        if UnitInfo.Combat > 0 then
            result = result..'，[ICON_Strength] '..UnitInfo.Combat
        end
        if UnitInfo.CostProgressionModel == 'NO_COST_PROGRESSION' then
            result = result..'，[ICON_Production] '..UnitInfo.Cost * GAME_SPEED_MULTIPLIER
        elseif UnitInfo.CostProgressionModel == 'COST_PROGRESSION_PREVIOUS_COPIES' then
            result = result..'，[ICON_Production] '..UnitInfo.Cost * GAME_SPEED_MULTIPLIER..'+'..UnitInfo.CostProgressionParam1 * GAME_SPEED_MULTIPLIER..'N'
        end
        if UnitInfo.BaseMoves > 0 then
            result = result..'，[ICON_Movement] '..UnitInfo.BaseMoves
        end
        if UnitInfo.RangedCombat > 0 then
            result = result..'，[ICON_Ranged] '..UnitInfo.RangedCombat
        end
        if UnitInfo.Bombard > 0 then
            result = result..'，[ICON_Bombard] '..UnitInfo.Bombard
        end
        if UnitInfo.Range > 0 then
            result = result..'，[ICON_Range] '..UnitInfo.Range
        end

    end
    if result ~= '' then
        result = '「'..result..'」'
    end
    return result
end


function Trait2Text(Traits)
	local result = ''
	local UpResult = ''
	local newline = '[NEWLINE]'
	local line = newline..'----------------------'..newline
    local TraitFlag = 0
	for _,TraitType in ipairs(Traits) do
        TraitFlag = 0
        for row in GameInfo.Districts() do
            if row.TraitType == TraitType and row.Name and row.Name ~= Locale.Lookup( row.Name ) and row.Description then
                result = result..line..Locale.Lookup( row.Name )..GetPreText(row.DistrictType)..newline..Locale.Lookup( row.Description )
                TraitFlag = 1
            end
        end
        for row in GameInfo.Buildings() do
            if row.TraitType == TraitType and row.Name and row.Name ~= Locale.Lookup( row.Name ) and row.Description then
                result = result..line..Locale.Lookup( row.Name )..GetPreText(row.BuildingType)..newline..Locale.Lookup( row.Description )
                TraitFlag = 1
            end
        end
        for row in GameInfo.Improvements() do
            if row.TraitType == TraitType and row.Name and row.Name ~= Locale.Lookup( row.Name ) and row.Description then
                result = result..line..Locale.Lookup( row.Name )..GetPreText(row.ImprovementType)..newline..Locale.Lookup( row.Description )
                TraitFlag = 1
            end
        end
        for row in GameInfo.Units() do
            if row.TraitType == TraitType and row.Name and row.Name ~= Locale.Lookup( row.Name ) and row.Description then
                result = result..line..Locale.Lookup( row.Name )..GetPreText(row.UnitType)..newline..Locale.Lookup( row.Description )
                TraitFlag = 1
            end
        end
		if TraitFlag == 0 then
            for row in GameInfo.Traits() do
				if row.Name and row.Description then
					local LocaleName = Locale.Lookup( row.Name )
					local LocaleDescription = Locale.Lookup( row.Description )
					if row.TraitType == TraitType and row.Name ~= LocaleName and row.Description ~= LocaleDescription then
						UpResult = UpResult..line..Locale.Lookup( row.Name )..newline..Locale.Lookup( row.Description )
					end
				end
			end
		end
	end
	return string.gsub(string.gsub(UpResult .. result,'%[NEWLINE%]%[NEWLINE%]','%[NEWLINE%]'),'%[newline%]%[newline%]','%[newline%]')
end


-- ===========================================================================
--	条目24：领袖头像富 Tooltip（用户裁决：仿准备房间领袖详情面板——原版 AdvancedSetup.xml CivToolTip
--	实例族 + PlayerSetupLogic.lua PopulateLeaderTooltip L833-878 结构取证）：
--	  结构 = EnhancedToolTip 底板 + 居中区头（HeaderInstance 原样：DivHeader + FontFlair18 glow
--	  ShellHeader，大写领袖/文明名）+ 圈图标行三态——领袖能力 CircleBacking45（图标=领袖头像
--	  ICON_<LeaderType>）、文明能力 CircleBacking44+Darker/Lighter（图标=文明徽记 ICON_<CivType>）、
--	  特色内容 CircleCompass（区域/建筑/改良/单位，行须有真名与描述过滤非特色条目）+ TextStack
--	  （FontFlair14 ShellHeader 标题 + DawnText 描述，缩进 55px）；标题 Locale.ToUpper 照搬原版。
--	属性行（解锁科文/造价/战力等 GetPreText）按用户裁决去除。
--	尺寸收尾照搬原版（PlayerSetupLogic L876-877）：InfoStack:CalculateSize()+ReprocessAnchoring()
--	后按实测高收口外框，且在每次回调都执行——首次构建用全新控件、当帧文本布局未完成实测偏小
--	（用户实测第一次悬停偏小第二次才对），悬停期间引擎反复触发回调（WorldRankings TeamTooltip
--	同款取证），第二次起以已布局控件实测自愈；去重仅免行重建。
-- ===========================================================================
local MPT_TipControls = {};			-- ToolTipType 控件表（TTManager 填充）
local MPT_TipHeaderIM = nil;		-- 居中区头实例管理器（MPT_SectionHeaderInstance → InfoStack）
local MPT_TipRowIM = nil;			-- 圈图标行实例管理器（MPT_TraitRowInstance → InfoStack）
local MPT_TipSpacerIM = nil;		-- 底部透明撑高块实例管理器（MPT_SpacerInstance → InfoStack）
local MPT_TipRowCache = {};			-- 结构化条目缓存（GameInfo 静态数据，按玩家缓存）
local MPT_TipCurrent = nil;			-- 当前 tooltip 承载的去重键

-- 懒初始化（首次悬停时模板必已随本上下文 XML 注册；nil 防御——同名覆盖未生效时静默回退无 tooltip）
function MPT_EnsureLeaderTooltip()
	if MPT_TipRowIM == nil then
		TTManager:GetTypeControlTable("MPT_LeaderInfoTooltip", MPT_TipControls);
		if MPT_TipControls.InfoStack ~= nil then
			MPT_TipHeaderIM = InstanceManager:new("MPT_SectionHeaderInstance", "HeaderRoot", MPT_TipControls.InfoStack);
			MPT_TipRowIM = InstanceManager:new("MPT_TraitRowInstance", "RowRoot", MPT_TipControls.InfoStack);
			MPT_TipSpacerIM = InstanceManager:new("MPT_SpacerInstance", "SpacerRoot", MPT_TipControls.InfoStack);
			-- 文本布局跨帧完成（本文件头部原版注释 UPDATE_FRAMES=2 HACK 同源）：栈尺寸实际变化时
			-- （晚于填充当帧）引擎回调再收口一次，消除首测偏小导致的底边裁切；Shrink 内有同值幂等
			-- 守卫不会循环
			MPT_TipControls.InfoStack:RegisterSizeChanged(function() MPT_ShrinkLeaderTooltip(); end);
		end
	end
	return MPT_TipRowIM ~= nil;
end

-- 结构化条目（有序）：{kind="header", sText=} | {kind="leader"|"civ"|"unique", sIcon=, sTitle=, sDesc=}
-- 顺序照搬准备房间面板（PopulateLeaderTooltip）：领袖区头 → 领袖能力行 → 文明区头 → 文明能力行 →
-- 特色内容行（区域→建筑→改良→单位，两特性来源合并扫描，各表行须有真名与描述过滤非特色条目）
function MPT_GetLeaderInfoSections(playerID)
	if MPT_TipRowCache[playerID] ~= nil then
		return MPT_TipRowCache[playerID];
	end
	local tSections = {};
	local pPlayerConfig = PlayerConfigurations[playerID];
	if pPlayerConfig == nil then
		return tSections;
	end
	local sLeaderType = pPlayerConfig:GetLeaderTypeName();
	local sCivType = pPlayerConfig:GetCivilizationTypeName();
	-- 领袖区：区头（大写名）+ 领袖特性行（圈=领袖头像）
	table.insert(tSections, {kind="header", sText=Locale.ToUpper(Locale.Lookup(pPlayerConfig:GetLeaderName()))});
	for row in GameInfo.LeaderTraits() do
		if row.LeaderType == sLeaderType then
			local tTrait = GameInfo.Traits[row.TraitType];
			if tTrait ~= nil and tTrait.Name and tTrait.Description and tTrait.Name ~= Locale.Lookup(tTrait.Name) and tTrait.Description ~= Locale.Lookup(tTrait.Description) then
				table.insert(tSections, {kind="leader", sIcon="ICON_"..sLeaderType, sTitle=Locale.ToUpper(Locale.Lookup(tTrait.Name)), sDesc=Locale.Lookup(tTrait.Description)});
			end
		end
	end
	-- 文明区：区头 + 文明特性行（圈=文明徽记）。文明名取 GameInfo.Civilizations 行的 Name 列——
	-- 原版 PlayerSetupLogic L553 的 CivilizationName 列来自 Players 配置表（SQL from Players），
	-- Civilizations 表无 CivilizationName 列，首版误用致区头空文本（用户实测截图红框）
	local tCiv = GameInfo.Civilizations[sCivType];
	local sCivName = "";
	if tCiv ~= nil and tCiv.Name ~= nil then
		sCivName = Locale.ToUpper(Locale.Lookup(tCiv.Name));
	end
	table.insert(tSections, {kind="header", sText=sCivName});
	for row in GameInfo.CivilizationTraits() do
		if row.CivilizationType == sCivType then
			local tTrait = GameInfo.Traits[row.TraitType];
			if tTrait ~= nil and tTrait.Name and tTrait.Description and tTrait.Name ~= Locale.Lookup(tTrait.Name) and tTrait.Description ~= Locale.Lookup(tTrait.Description) then
				table.insert(tSections, {kind="civ", sIcon="ICON_"..sCivType, sTitle=Locale.ToUpper(Locale.Lookup(tTrait.Name)), sDesc=Locale.Lookup(tTrait.Description)});
			end
		end
	end
	-- 特色内容区（区域→建筑→改良→单位，两特性来源合并）
	local tTraits = {};
	for row in GameInfo.LeaderTraits() do
		if row.LeaderType == sLeaderType then table.insert(tTraits, row.TraitType); end
	end
	for row in GameInfo.CivilizationTraits() do
		if row.CivilizationType == sCivType then table.insert(tTraits, row.TraitType); end
	end
	for _,TraitType in ipairs(tTraits) do
		for row in GameInfo.Districts() do
			if row.TraitType == TraitType and row.Name and row.Name ~= Locale.Lookup(row.Name) and row.Description then
				table.insert(tSections, {kind="unique", sIcon="ICON_"..row.DistrictType, sTitle=Locale.ToUpper(Locale.Lookup(row.Name)), sDesc=Locale.Lookup(row.Description)});
			end
		end
		for row in GameInfo.Buildings() do
			if row.TraitType == TraitType and row.Name and row.Name ~= Locale.Lookup(row.Name) and row.Description then
				table.insert(tSections, {kind="unique", sIcon="ICON_"..row.BuildingType, sTitle=Locale.ToUpper(Locale.Lookup(row.Name)), sDesc=Locale.Lookup(row.Description)});
			end
		end
		for row in GameInfo.Improvements() do
			if row.TraitType == TraitType and row.Name and row.Name ~= Locale.Lookup(row.Name) and row.Description then
				table.insert(tSections, {kind="unique", sIcon="ICON_"..row.ImprovementType, sTitle=Locale.ToUpper(Locale.Lookup(row.Name)), sDesc=Locale.Lookup(row.Description)});
			end
		end
		for row in GameInfo.Units() do
			if row.TraitType == TraitType and row.Name and row.Name ~= Locale.Lookup(row.Name) and row.Description then
				table.insert(tSections, {kind="unique", sIcon="ICON_"..row.UnitType, sTitle=Locale.ToUpper(Locale.Lookup(row.Name)), sDesc=Locale.Lookup(row.Description)});
			end
		end
	end
	MPT_TipRowCache[playerID] = tSections;
	return tSections;
end

-- 尺寸确定性收口：宽度恒 400（行宽 340 + EnhancedToolTip 帧 InnerPadding 30×2），高度 = 内容栈
-- 实测 + 26×2。收尾两连照搬原版 PlayerSetupLogic L876-877（CalculateSize + ReprocessAnchoring）。
-- 不用 AutoSize 的原因：此前 parent,parent 背景图参与 AutoSize 测量会把外框撑到历史最大/屏高
-- 且不再收缩（用户实测整幅背景拖长上千像素、宽度同时失控致内容贴左缘不对齐）
function MPT_ShrinkLeaderTooltip()
	MPT_TipControls.InfoStack:CalculateSize();
	MPT_TipControls.InfoStack:ReprocessAnchoring();
	local _, h = MPT_TipControls.InfoStack:GetSizeVal();
	local nTargetH = h + 52;
	local _, nCurH = MPT_TipControls.BG:GetSizeVal();
	if nCurH ~= nTargetH then
		-- 同值幂等守卫：RegisterSizeChanged 回调里再收口时目标不变则不再 SetSizeVal，防事件循环
		MPT_TipControls.BG:SetSizeVal(400, nTargetH);
	end
end

-- 悬停填充（UpdateIcon 包装绑定回调；无本地玩家/未遇见玩家与原 GetToolTipString 同口径）
function MPT_FillLeaderTooltip(playerID)
	if not MPT_EnsureLeaderTooltip() then
		return;
	end
	local pPlayerConfig = PlayerConfigurations[playerID];
	if pPlayerConfig == nil or pPlayerConfig:GetLeaderTypeName() == nil then
		return;
	end
	local localPlayerID = Game.GetLocalPlayer();
	local bNoLocal = (localPlayerID == PlayerTypes.NONE or localPlayerID == PlayerTypes.OBSERVER);
	local bUnmet = false;
	if not bNoLocal and playerID ~= localPlayerID and Players[localPlayerID] ~= nil then
		bUnmet = not Players[localPlayerID]:GetDiplomacy():HasMet(playerID);
	end
	-- 行重建按「playerID|相遇态」去重（GameInfo 数据静态、相遇态变化才重建）；尺寸收口在去重之外
	-- 每次回调都执行——首次构建用全新控件、当帧文本布局未完成实测偏小（用户实测第一次悬停偏小
	-- 第二次才对），悬停期间引擎反复触发回调，第二次起以已布局控件实测自愈
	local sKey = tostring(playerID).."|"..tostring(bUnmet).."|"..tostring(bNoLocal);
	if MPT_TipCurrent ~= sKey then
		MPT_TipCurrent = sKey;
		MPT_TipHeaderIM:ResetInstances();
		MPT_TipRowIM:ResetInstances();
		MPT_TipSpacerIM:ResetInstances();

		if bNoLocal then
			-- 无本地玩家：原口径返回空串 → 全空（tooltip 收缩为空底板）
		elseif bUnmet then
			-- 未遇见：原口径只显示未遇见提示（多人局附玩家名）
			local sText = Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER");
			if GameConfiguration.IsAnyMultiplayer() then
				sText = sText .. "（" .. pPlayerConfig:GetPlayerName() .. "）";
			end
			MPT_TipHeaderIM:GetInstance().HeaderText:SetText(sText);
		else
			for _,t in ipairs(MPT_GetLeaderInfoSections(playerID)) do
				if t.kind == "header" then
					MPT_TipHeaderIM:GetInstance().HeaderText:SetText(t.sText);
				else
					local kRow = MPT_TipRowIM:GetInstance();
					if t.kind == "leader" then
						-- 领袖能力行（IconInstance 样式）：CircleBacking45 + 领袖头像
						kRow.RowCircleLeader:SetHide(false);
						kRow.RowCircleCiv:SetHide(true);
						kRow.RowCircleUnique:SetHide(true);
						kRow.RowIconLeader:SetIcon(t.sIcon);
					elseif t.kind == "civ" then
						-- 文明能力行（CivIconInstance 样式）：CircleBacking44 + 叠层 + 文明徽记
						kRow.RowCircleLeader:SetHide(true);
						kRow.RowCircleCiv:SetHide(false);
						kRow.RowCircleUnique:SetHide(true);
						kRow.RowIconCiv:SetIcon(t.sIcon);
						-- 文明徽记按玩家双色上色（原版 PlayerSetupLogic L851-855：符号=前景色、圆底=背景色；
						-- 取色走 UI.GetPlayerColors 运行时玩家色，同本文件 Logo 徽记先例，nil 兜底同款）
						local primaryColor, secondaryColor = UI.GetPlayerColors(playerID);
						if primaryColor == nil then
							primaryColor = UI.GetColorValueFromHexLiteral(0xff99aaaa);
						end
						if secondaryColor == nil then
							secondaryColor = UI.GetColorValueFromHexLiteral(0xffaa9999);
						end
						kRow.RowCircleCiv:SetColor(primaryColor);
						kRow.RowIconCiv:SetColor(secondaryColor);
					else
						-- 特色内容行（IconInfoInstance 样式）：CircleCompass + 条目图标
						kRow.RowCircleLeader:SetHide(true);
						kRow.RowCircleCiv:SetHide(true);
						kRow.RowCircleUnique:SetHide(false);
						kRow.RowIconUnique:SetIcon(t.sIcon);
					end
					kRow.RowTitle:SetText(t.sTitle);
					kRow.RowDesc:SetText(t.sDesc);
				end
			end
			-- 栈尾透明撑高块（用户裁决）：固定高 24px 无需文本布局、测高精确，为末行兜底吸收
			-- 文本行跨帧布局的测量缺口
			MPT_TipSpacerIM:GetInstance();
		end
	end
	-- 收口在去重之外：每次回调都按当前已布局内容实测（首帧失真由悬停期间后续回调自愈）
	MPT_ShrinkLeaderTooltip();
end

-- UpdateIcon 包装：原版设置纯文本 Tooltip 后改挂富 Tooltip 类型+回调（类型优先于字符串，
-- 见技能库 tooltip-type；ResetInstances 回收复用属性保留，重复设置幂等）
BASE_LeaderIcon_UpdateIcon = LeaderIcon.UpdateIcon;
function LeaderIcon:UpdateIcon(iconName, playerID, isUniqueLeader, ttDetails)
	BASE_LeaderIcon_UpdateIcon(self, iconName, playerID, isUniqueLeader, ttDetails);
	if self.Controls ~= nil and self.Controls.Portrait ~= nil then
		self.Controls.Portrait:SetToolTipType("MPT_LeaderInfoTooltip");
		self.Controls.Portrait:SetToolTipCallback(function() MPT_FillLeaderTooltip(playerID); end);
	end
end


-- ===========================================================================
--	获取当前外交能见度模式类型
-- ===========================================================================
local Model = 0		-- 游戏模式
if GameConfiguration.GetValue("SETTINGS_DIPLOMACYRIBBON_TPT") == "SETTINGS_DIPLOMACYRIBBON_NORM" then
	Model = 0
	print("模式：标准(推荐)")
end

if GameConfiguration.GetValue("SETTINGS_DIPLOMACYRIBBON_TPT") == "SETTINGS_DIPLOMACYRIBBON_VISIBILITY_TEAM" then
	Model = 1
--	Modding.UpdateSubscription(3041524474)
	print("模式：外交能见度模式(团队)")
end

if GameConfiguration.GetValue("SETTINGS_DIPLOMACYRIBBON_TPT") == "SETTINGS_DIPLOMACYRIBBON_PUBLIC" then
	Model = 2
	print("模式：公开(完全透明)")
end

-- 条目24修复：默认模式（用户需求）——标准（推荐）的基础上显示所有玩家的军事实力
if GameConfiguration.GetValue("SETTINGS_DIPLOMACYRIBBON_TPT") == "SETTINGS_DIPLOMACYRIBBON_DEFAULT" then
	Model = 3
	print("模式：默认(标准+军力)")
end

--Model = 2		--debug

--[[		规则说明
模式0

分数：		所有人✓			
军力：		仅队友			人口：		仅队友
科技：		所有人✓			粮食：		仅队友
文化：		所有人✓			生产力：		仅队友
金币：		所有人✓			回合金：		所有人✓
信仰：		所有人✓			回合信仰：	所有人✓
外交支持：	所有人✓			回合外交：	所有人✓

模式1

能见度0：										能见度1：											能见度2：											能见度3

分数：		所有人✓			      				|	分数：		所有人✓			      				|	分数：		所有人✓			      				|	分数：		所有人✓			      				|
军力：		仅队友			人口：		仅队友	|	军力：		仅队友			人口：		仅队友	|	军力：		仅队友			人口：		所有人✓	|	军力：		所有人✓			人口：		所有人✓	|		
科技：		仅队友			粮食：		仅队友	|	科技：		仅队友			粮食：		仅队友	|	科技：		所有人✓			粮食：		所有人✓	|	科技：		所有人✓			粮食：		所有人✓	|
文化：		仅队友			生产力：		仅队友	|	文化：		仅队友			生产力：		仅队友	|	文化：		所有人✓			生产力：		仅队友	|	文化：		所有人✓			生产力：		所有人✓	|
金币：		仅队友			回合金：		仅队友	|	金币：		所有人✓			回合金：		所有人✓	|	金币：		所有人✓			回合金：		所有人✓	|	金币：		所有人✓			回合金：		所有人✓	|
信仰：		仅队友			回合信仰：	仅队友	|	信仰：		所有人✓			回合信仰：	所有人✓	|	信仰：		所有人✓			回合信仰：	所有人✓	|	信仰：		所有人✓			回合信仰：	所有人✓	|
外交支持：	仅队友			回合外交：	仅队友	|	外交支持：	所有人✓			回合外交：	所有人✓	|	外交支持：	所有人✓			回合外交：	所有人✓	|	外交支持：	所有人✓			回合外交：	所有人✓	|

模式2

分数：		所有人✓			
军力：		所有人✓			人口：		所有人✓
科技：		所有人✓			粮食：		所有人✓
文化：		所有人✓			生产力：		所有人✓
金币：		所有人✓			回合金：		所有人✓
信仰：		所有人✓			回合信仰：	所有人✓
外交支持：	所有人✓			回合外交：	所有人✓
]]
-- ===========================================================================
--	获取队伍信息
-- ===========================================================================
local IsTeamPlayer  = {}		-- 是否是队友
for _, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
	local localplayerTeam = Players[Game.GetLocalPlayer()]:GetTeam();
	if Players[playerID]:GetTeam() == localplayerTeam then
		IsTeamPlayer[playerID] = true
	else
		IsTeamPlayer[playerID] = false
	end
end
-- ===========================================================================
--	获取最高能见度
-- ===========================================================================	
local g_AccessLevel	 = {}		--本地玩家对所有其他玩家的能见度	。
function RefreshAccessLevel()		
	local localplayerID = Game.GetLocalPlayer()
	local localplayer 	= Players[localplayerID]
	
	for _, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do		-- 这个playerID是目标
		local localPlayerDiplomacy = localplayer:GetDiplomacy();
		local localPlayerAccessLevel = localPlayerDiplomacy:GetVisibilityOn(playerID);	
		g_AccessLevel[playerID] = localPlayerAccessLevel;		-- 先获取自己对所有人的能见度
		if not IsTeamPlayer[playerID] then		--目标不是队友时，以队友对目标的最高能见度为准
			for _, iplayerID in ipairs(PlayerManager.GetAliveMajorIDs()) do		--开始遍历队友
				if IsTeamPlayer[iplayerID] then		--是队友时
					local pPlayerDiplomacy = Players[iplayerID]:GetDiplomacy();		-- 队友i的能见度
					local iTeamAccessLevel = pPlayerDiplomacy:GetVisibilityOn(playerID);		--目标是playerID的玩家
					if	iTeamAccessLevel > g_AccessLevel[playerID] then
						g_AccessLevel[playerID] = iTeamAccessLevel		--用更高的能见度替换
					end
				end
			end
		end
		if playerID == localplayerID then	--当目标是自己时，能见度是最高
			g_AccessLevel[playerID] = 4
		end
	end
end
RefreshAccessLevel();		--立即运行，初始化
-- ===========================================================================
--	获取额外的尤里卡加成
-- ===========================================================================
local cached_turn	 = {};
local cached_extra_techboost	 = {};
local cached_extra_civicboost	 = {};
function GetExtraBoostFromModifiers(playerID, isTech)		--获取修改器额外提示

    local cur = Game.GetCurrentGameTurn()

    if cur == cached_turn[playerID] then		-- 如果是本回合，则快速返回储存的值，减少运算量
        if isTech then
            return cached_extra_techboost[playerID] or 0
        else
            return cached_extra_civicboost[playerID] or 0
        end
    end

	cached_turn[playerID] = cur;
	
    local tech_ratio = 0;
    local civic_ratio = 0;
    for _, modifierObjID in ipairs(GameEffects.GetModifiers()) do
        -- Check player ids.
        local isActive = GameEffects.GetModifierActive(modifierObjID);
        local ownerObjID = GameEffects.GetModifierOwner(modifierObjID);
        if isActive and IsOwnerRequirementSetMet(modifierObjID) and (GameEffects.GetObjectsPlayerId(ownerObjID) == playerID) then
            -- The modifier is active, belongs to the given player, and owner requirement set is met.
            local modifierDef = GameEffects.GetModifierDefinition(modifierObjID);
            local modifierType = GameInfo.Modifiers[modifierDef.Id].ModifierType;
            if modifierType then
                local modifierTypeRow = GameInfo.DynamicModifiers[modifierType];
                -- print(modifierTypeRow.EffectType)
                if modifierTypeRow then
                    if modifierTypeRow.EffectType == 'EFFECT_ADJUST_TECHNOLOGY_BOOST' then
                        tech_ratio = tech_ratio + modifierDef.Arguments.Amount;
                    end
                    if modifierTypeRow.EffectType == 'EFFECT_ADJUST_CIVIC_BOOST' then
                        civic_ratio = civic_ratio + modifierDef.Arguments.Amount;
                    end
                end
            end
        end
    end
    -- print(cur, tech_ratio, civic_ratio)
    cached_extra_techboost[playerID] = tech_ratio;
    cached_extra_civicboost[playerID] = civic_ratio;
    if isTech then
        return cached_extra_techboost[playerID];
    else
        return cached_extra_civicboost[playerID];
    end
end
function IsOwnerRequirementSetMet(modifierObjId)
    -- Check if owner requirements are met.
    if modifierObjId ~= nil and modifierObjId ~= 0 then
        local ownerRequirementSetId = GameEffects.GetModifierOwnerRequirementSet(modifierObjId);
        if ownerRequirementSetId then
            return GameEffects.GetRequirementSetState(ownerRequirementSetId) == "Met";
        end
    end
    return true;
end
-- ===========================================================================
--	刷新仪表盘
-- ===========================================================================
local m_currentTechID	 = {}	-- 存储ID
local m_currentCivicID	 = {}
function InitcurrentID()
	for _, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do		--初始化
		m_currentTechID[playerID] = -1
		m_currentCivicID[playerID] = -1
	end
end
InitcurrentID()

function RefreshTechMeter(playerID, uiLeader)	
	local localPlayer = Players[playerID]
	if localPlayer ~= nil  then
		local playerTechs			= localPlayer:GetTechs();
		local currentTechID		 = playerTechs:GetResearchingTech();
----------------------------------------------------------------------------------------------		
		if(currentTechID >= 0) then
			local progress			 = playerTechs:GetResearchProgress(currentTechID);
			local cost					= playerTechs:GetResearchCost(currentTechID);
			uiLeader.ScienceProgressMeter:SetPercent(progress/cost);		-- 设置研究进度
			
			if playerTechs:HasTech(currentTechID) then	-- 上个研究的项目完成了
				uiLeader.ScienceProgressMeter:SetPercent(1);
			end			
			---------------------------------------------------
			local isBoostable	 = false;
			local boostValue	 = 0;
			local Estimates		 = progress;			
			
			local techType = GameInfo.Technologies[currentTechID].TechnologyType;
			local boosted = playerTechs:HasBoostBeenTriggered(currentTechID)
			-- 条目24：加速值改走 MPT_GetBoostValue（引擎精确定点链 + 按目标玩家 modifier 附加），原 DPR 朴素公式保留于该函数内
			for row in GameInfo.Boosts() do
				if row.TechnologyType == techType then		
					isBoostable	= true;		
					boostValue = MPT_GetBoostValue(playerID, cost, row.Boost, true);
					break;
				end
			end
			if isBoostable and not boosted then
				Estimates = math.min(progress + boostValue, cost)
			end	
			uiLeader.ScienceBoostMeter:SetPercent(Estimates/cost);			-- 设置尤里卡进度
----------------------------------------------------------------------------------------------				
			local techInfo = GameInfo.Technologies[currentTechID];
			if (techInfo ~= nil) then
				local textureString = "ICON_" .. techInfo.TechnologyType;
				local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(textureString,38);
				if textureSheet ~= nil then
					uiLeader.ResearchIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
					local namestr = Locale.Lookup(GameInfo.Technologies[currentTechID].Name )
					if namestr ~= nil then
						if string.len(namestr) > 13 then
							namestr = string.sub(namestr,1,12)
						end
						uiLeader.ScienceText:SetText( namestr )
						
						if uiLeader.ScienceText:GetSizeX() > 60 and string.len(namestr) > 10 then
							namestr = string.sub(namestr,1,9)
							uiLeader.ScienceText:SetText( namestr )
						end
					end
					uiLeader.ScienceTurnsLeft:SetText( "[ICON_Turn] "..playerTechs:GetTurnsLeft().." " )
				end
			end
			if playerTechs:HasTech(currentTechID) then
				uiLeader.ScienceTurnsLeft:SetText(Locale.Lookup("LOC_RESEARCH_CHOOSER_JUST_COMPLETED"))
			end
		end
	end
	SetOffsetX2Center( uiLeader.ScienceText , 60 )
	SetOffsetX2Center( uiLeader.ScienceTurnsLeft , 60 )
end
function RefreshCivisMeter(playerID, uiLeader)		-- 神奇的是，结算市政环节很靠后
	local localPlayer = Players[playerID]
	if localPlayer ~= nil  then
	
		local pPlayerCulture		= localPlayer:GetCulture();
		local currentCivicID     = pPlayerCulture:GetProgressingCivic();
----------------------------------------------------------------------------------------------					
		if(currentCivicID >= 0) then
			local civicProgress	 = pPlayerCulture:GetCulturalProgress(currentCivicID);
			local civicCost			= pPlayerCulture:GetCultureCost(currentCivicID);	
			uiLeader.CultureProgressMeter:SetPercent(civicProgress/civicCost);		-- 设置研究进度
			
			if pPlayerCulture:HasCivic(currentCivicID) then		-- 上个研究的项目完成了
				uiLeader.CultureProgressMeter:SetPercent(1);
			end				
			----------------------------------------------------------------------------------------------		
			local isBoostable	 = false;
			local boostValue	 = 0;
			local Estimates		 = civicProgress;
			
			local civicType = GameInfo.Civics[currentCivicID].CivicType;
			local boosted = pPlayerCulture:HasBoostBeenTriggered(currentCivicID)
			-- 条目24：同 RefreshTechMeter，引擎精确加速值
			for row in GameInfo.Boosts() do
				if row.CivicType == civicType then				
					isBoostable	= true;		
					boostValue = MPT_GetBoostValue(playerID, civicCost, row.Boost, false);
					break;
				end
			end
			if isBoostable and not boosted then
				Estimates = math.min(civicProgress + boostValue, civicCost)
			end
			uiLeader.CultureBoostMeter:SetPercent(Estimates/civicCost);		--	设置尤里卡进度	
----------------------------------------------------------------------------------------------				
			local CivicInfo = GameInfo.Civics[currentCivicID];
			if (CivicInfo ~= nil) then
				local civictextureString = "ICON_" .. CivicInfo.CivicType;
				local civictextureOffsetX, civictextureOffsetY, civictextureSheet = IconManager:FindIconAtlas(civictextureString,38);
				if civictextureSheet ~= nil then
					uiLeader.CultureIcon:SetTexture(civictextureOffsetX, civictextureOffsetY, civictextureSheet);
					local namestr = Locale.Lookup(GameInfo.Civics[currentCivicID].Name )		
					if namestr ~= nil then
						if string.len(namestr) > 13 then
							namestr = string.sub(namestr,1,12)
						end
						uiLeader.CultureText:SetText( namestr )
						
						if uiLeader.CultureText:GetSizeX() > 60 and string.len(namestr) > 10 then
							namestr = string.sub(namestr,1,9)
							uiLeader.CultureText:SetText( namestr )
						end						
					end
					uiLeader.CultureTurnsLeft:SetText( "[ICON_Turn] "..pPlayerCulture:GetTurnsLeft().." ")
				end
			end
			if pPlayerCulture:HasCivic(currentCivicID) then
				uiLeader.CultureTurnsLeft:SetText(Locale.Lookup("LOC_CIVICS_CHOOSER_JUST_COMPLETED"))
			end	
			m_currentCivicID[playerID] = currentCivicID
		elseif pPlayerCulture:HasCivic(m_currentCivicID[playerID]) then
			uiLeader.CultureProgressMeter:SetPercent(1);
			uiLeader.CultureTurnsLeft:SetText(Locale.Lookup("LOC_CIVICS_CHOOSER_JUST_COMPLETED"))
		end
	end
	SetOffsetX2Center( uiLeader.CultureText , 60 )
	SetOffsetX2Center( uiLeader.CultureTurnsLeft , 60 )	
end
-- ===========================================================================
--	左键和右键的响应
-- ===========================================================================
local m_TechCivisProgress = true		-- 是否隐藏 正在研究的项目
local m_Totalyield = true				-- 是否隐藏 粮锤部分

function OnMouseClick_TPT_Control_1L()
	m_TechCivisProgress = not m_TechCivisProgress
	UpdateLeaders(true);
end
function OnMouseClick_TPT_Control_1R()
	UI.PlaySound("Play_UI_Click");		-- 右键没有直接的声音反馈
	m_Totalyield = not m_Totalyield
	UpdateLeaders(true);
end
-- ===========================================================================
--	绑定快捷键
-- ===========================================================================
local m_TechCivisProgressActionId = Input.GetActionId("HotKey_DPR_TechCivisProgress");
local m_TotalyieldActionId = Input.GetActionId("HotKey_DPR_Totalyield");
function OnInputActionTriggered(actionId)
	if actionId == m_TechCivisProgressActionId then
		UI.PlaySound("Play_UI_Click");
		OnMouseClick_TPT_Control_1L()
	end
	if actionId == m_TotalyieldActionId then
		OnMouseClick_TPT_Control_1R()
	end
end
Events.InputActionTriggered.Add(OnInputActionTriggered)
-- ===========================================================================
--	获取统计数据
-- ===========================================================================
function GetPopulation(playerID)
	local pPlayerCities = Players[playerID]:GetCities()
	local pTotalPopulation = 0
	for i, pCity in pPlayerCities:Members() do
		pTotalPopulation = pTotalPopulation + pCity:GetPopulation()
	end
	return pTotalPopulation
end

function GetFoodSurplusTotal(playerID)
	local pPlayerCities = Players[playerID]:GetCities()
	local pTotalFood = 0
	for i, pCity in pPlayerCities:Members() do
		pTotalFood = pTotalFood + GetFoodSurplus(pCity)
	end
	return pTotalFood
end
function GetFoodSurplus(pCity)
	local FoodSurplusNum = 0
	local iModifiedFood;
	local pCityGrowth	 = pCity:GetGrowth();
	local isStarving = pCityGrowth:GetTurnsUntilStarvation() ~= -1;
	local HappinessGrowthModifier		= pCityGrowth:GetHappinessGrowthModifier();
	local OtherGrowthModifiers			= pCityGrowth:GetOtherGrowthModifier();
	local FoodSurplus					= Round( pCityGrowth:GetFoodSurplus(), 1);
	local HousingMultiplier				= pCityGrowth:GetHousingGrowthModifier();
	local Occupied                      = pCity:IsOccupied();
	local OccupationMultiplier			= pCityGrowth:GetOccupationGrowthModifier();

	if not isStarving then
		local growthModifier =  math.max(1 + (HappinessGrowthModifier/100) + OtherGrowthModifiers, 0);
		iModifiedFood = Round(FoodSurplus * growthModifier, 2);
		FoodSurplusNum = iModifiedFood * HousingMultiplier;		
		if Occupied then
			FoodSurplusNum = iModifiedFood * OccupationMultiplier;
		end
	else
		iModifiedFood = FoodSurplus;
		FoodSurplusNum = iModifiedFood;		
	end		

	return FoodSurplusNum
end

function GetProduction(playerID)
	local pPlayerCities = Players[playerID]:GetCities()
	local pTotalProduction = 0
	for i, pCity in pPlayerCities:Members() do
		pTotalProduction = pTotalProduction + pCity:GetYield(YieldTypes.PRODUCTION)
	end
	return pTotalProduction
end

-- ===========================================================================
--	GLOBALS
-- ===========================================================================
g_maxNumLeaders	= 0;		-- Number of leaders that can fit in the ribbon
g_kRefreshRequesters = {}	-- Who requested a (refresh of stats)


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_kLeaderIM			 = InstanceManager:new("LeaderInstance", "LeaderContainer", Controls.LeaderStack);
local m_leadersMet			 = 0;		-- Number of leaders in the ribbon
local m_scrollIndex			 = 0;		-- Index of leader that is supposed to be on the far right.  TODO: Remove this and instead scroll based on visible area.
local m_scrollPercent		 = 0;		-- Necessary for scroll lerp
local m_isScrolling			 = false;
local m_uiLeadersByID		 = {};		-- map of (entire) leader controls based on player id
local m_uiLeadersByPortrait	 = {};		-- map of leader portraits based on player id
local m_uiChatIconsVisible	 = {};
local m_leaderInstanceHeight = 0;		-- How tall is an instantiated leader instance.
local m_ribbonStats			 = -1;		-- From Options menu, enum of how this should display.
local m_isIniting			 = true;	-- Tracking if initialization is occuring.
local m_kActiveIds			 = {};		-- Which player(s) are active.
local m_isYieldsSubscribed	 = false;	-- Are yield events subscribed to?


-- ===========================================================================
--	Cleanup leaders
-- ===========================================================================
function ResetLeaders()
	m_kLeaderIM:ResetInstances();
	m_leadersMet = 0;
	m_uiLeadersByID = {};	
	m_uiLeadersByPortrait = {};
	m_scrollPercent = 0;
	m_scrollIndex = 0;
	m_leaderInstanceHeight = 0;
	RealizeScroll();
end

-- ===========================================================================
function OnLeaderClicked(playerID  )
	-- Send an event to open the leader in the diplomacy view (only if they met)

	local localPlayerID = Game.GetLocalPlayer();
	local pPlayer = PlayerConfigurations[localPlayerID];
	local isAlive = (localPlayerID ~= PlayerTypes.NONE and pPlayer:IsAlive())
	if (playerID == localPlayerID or Players[localPlayerID]:GetDiplomacy():HasMet(playerID)) and isAlive then
		LuaEvents.DiplomacyRibbon_OpenDiplomacyActionView( playerID );
	end
end

-- ===========================================================================
function ShowStats( uiLeader )
	uiLeader.StatStack:SetHide(false);
	uiLeader.StatStack:CalculateSize();
	uiLeader.StatBacking:SetColorByName("HUDRIBBON_STATS_SHOW");
	uiLeader.ActiveLeaderAndStats:SetHide(false);
end

-- ===========================================================================
function HideStats( uiLeader )
	uiLeader.StatStack:SetHide(true);			
	uiLeader.StatBacking:SetColorByName("HUDRIBBON_STATS_HIDE");
	uiLeader.ActiveLeaderAndStats:SetHide(true);
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnLeaderSizeChanged( uiLeader )	
--	local pSize = uiLeader.LeaderContainer:GetSize();
--	uiLeader.ActiveLeaderAndStats:SetSizeVal( pSize.x + LEADER_ART_OFFSET_X, pSize.y + LEADER_ART_OFFSET_Y );
end

-- ===========================================================================
-- The four following getter functions are exposed for scenario/mod usage
-- ===========================================================================
function GetLeaderIcon()
	return LeaderIcon:GetInstance(m_kLeaderIM);
end

-- ===========================================================================
function GetUILeadersByID()
	return m_uiLeadersByID;
end

-- ===========================================================================
function GetUILeadersByPortrait()
	return m_uiLeadersByPortrait;
end

-- ===========================================================================
function GetLeadersMet()
	return m_leadersMet;
end

-- ===========================================================================
--	Add a leader (from right to left)
--	iconName,	What icon to draw for the leader portrait
--	playerID,	gamecore's player ID
--	kProps,		(optional) properties about the leader
--					isUnique, no other leaders are like this one
--					isMasked, even if stats are show, hide their values.
-- ===========================================================================

function AddLeader(iconName , playerID , kProps)
	
	local isUnique = false;
	if kProps == nil then kProps={}; end
	if kProps.isUnqiue then	isUnqiue=kProps.isUnqiue; end

	m_leadersMet = m_leadersMet + 1;

	-- Create a new leader instance
	local oLeaderIcon  = GetLeaderIcon();
	local uiPortraitButton  = oLeaderIcon.Controls.SelectButton;
	m_uiLeadersByID[playerID] = oLeaderIcon;
	m_uiLeadersByPortrait[uiPortraitButton] = oLeaderIcon;

	oLeaderIcon:UpdateIcon(iconName, playerID, isUnqiue);
	oLeaderIcon:RegisterCallback(Mouse.eLClick, function() OnLeaderClicked(playerID); end);

	-- If using focus, setup mouse in/out callbacks... otherwise clear them.
	if 	m_ribbonStats == RibbonHUDStats.FOCUS then
		uiPortraitButton:RegisterMouseEnterCallback( 
			function( uiControl )
				ShowStats( oLeaderIcon );
			end
		);
		uiPortraitButton:RegisterMouseExitCallback( 
			function( uiControl )
				HideStats( oLeaderIcon );
			end	
		);
	else
		uiPortraitButton:ClearMouseEnterCallback(); 
		uiPortraitButton:ClearMouseExitCallback();
	end

	oLeaderIcon.LeaderContainer:RegisterSizeChanged( 
		function( uiControl ) 
			OnLeaderSizeChanged( oLeaderIcon );
		end
	);

	FinishAddingLeader( playerID, oLeaderIcon, kProps );

	-- Returning so mods can override them and modify the icons
	return oLeaderIcon;
end


-- ===========================================================================
--	Complete adding a leader.
--	Two steps for allowing easier MOD overrides/explansion.
-- ===========================================================================
-- 条目24优化：观察者局高亮高度缓存（键 = 视图签名，见 FinishAddingLeader 内说明）与收敛计数
local MPT_ObserverHeightCache = {};
local MPT_ObserverShrinkCount = {};

function FinishAddingLeader( playerID, uiLeader, kProps)
	
	-- ==== 条目24：观察者判定（BSM 移植）====
	-- 旧代码（DPR 原始）：观察者条目无条件隐藏——收窄为按局面区分：
	--   本地观察者视角下主观察者条目必须显示（承载六视图按钮）；其余局面观察者条目隐藏（BSM 语义）
	local bIsSpec = false;
	local bmasterspec = false;
	if PlayerConfigurations[playerID] ~= nil and PlayerConfigurations[playerID]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
		bIsSpec = true;
		if playerID == m_first_spec_id then
			bmasterspec = true;
		end
	end
	if bspec_game == false then
		uiLeader.LeaderContainer:SetHide(bIsSpec);
		uiLeader.Group_Observer:SetHide(true);			-- 观察者组整组隐藏（原 BSM HideSpecInfo 40 余行逐控件 → 组级 1 次）
		uiLeader.LogoContainer:SetHide(true);
	elseif bspec_loc == false then
		uiLeader.LeaderContainer:SetHide(bIsSpec);
		uiLeader.Group_Observer:SetHide(true);
		uiLeader.LogoContainer:SetHide(true);
	end
	
	local isMasked = false;
	if kProps.isMasked then
		isMasked = kProps.isMasked;
	end	

	uiLeader.TPT_Control_1:SetHide(isMasked);
	
	-- ==== 条目24：显隐走组级（用户裁决分组架构），披露门槛语义与原 DPR 完全一致 ====
	-- 旧代码（DPR 原始）：组合1（Military/Science/Culture/Gold/Faith/Favor）、组合2（Cities/Food_Total/
	-- Production_Total/GoldPerTurn/FaithperTurn/FavorperTurn）各 6 行逐 Label SetHide + 科文 6 控件逐个
	-- CanHide，共约 40 行（原文见 git 历史），收敛为组级调用；组内个别 SetHide 不再使用。
	if bspec_loc == true then
		-- 本地观察者：BSM 六视图/轮播经组架构接管全部行显隐（原 BSM FinishAddingLeader L527-938 逐控件版）
		-- 条目24修复：DPR 隐形热区 TPT_Control_1（60x115、Offset 0,60）覆盖实例 y60-175，压住观察者列
		-- Score/Yield 两按钮吃掉点击（用户实测两键无反应，其余四键位置更低正常）——观察者局整局隐藏；
		-- 观察者模式下 DPR 逐 Label 显隐本就不再生效（MPT_RealizeObserverView 接管），热键 ; ' 走 Input 事件不受影响
		uiLeader.TPT_Control_1:SetHide(true);
		MPT_RealizeObserverView(playerID, uiLeader, isMasked, bIsSpec, bmasterspec);
	else
		if Model ~= 2 then
			if m_TechCivisProgress	then
				uiLeader.Score:SetHide(isMasked);
				uiLeader.Group_Stock:SetHide( not m_Totalyield or isMasked);								-- 组合1
				uiLeader.Group_Rate:SetHide( m_Totalyield or isMasked);										-- 组合2
			else
				uiLeader.Score:SetHide(IsTeamPlayer[playerID] or isMasked);
				uiLeader.Group_Stock:SetHide( not m_Totalyield or IsTeamPlayer[playerID] or isMasked);		-- 组合1
				uiLeader.Group_Rate:SetHide( m_Totalyield or IsTeamPlayer[playerID] or isMasked);			-- 组合2
			end
		else		-- 模式2
			uiLeader.Score:SetHide(not m_TechCivisProgress or isMasked);
			uiLeader.Group_Stock:SetHide(not m_TechCivisProgress or not m_Totalyield or isMasked);			-- 组合1
			uiLeader.Group_Rate:SetHide(not m_TechCivisProgress or m_Totalyield or isMasked);				-- 组合2
		end
		-- 科文（原 6 控件 CanHide → 组级；门槛表达式不变）
		local CanHide = m_TechCivisProgress  or ( not IsTeamPlayer[playerID] and Model ~= 2) or isMasked
		uiLeader.Group_TechCivis:SetHide(CanHide);
	end
	
	uiLeader.PlayerName:SetHide( HidePlayerInfo_PlayerName or isMasked );
	uiLeader.CivName:SetHide( HidePlayerInfo_CiviName or isMasked );
	
	--------------------------------------------------------------------------------------------------		

	uiLeader.StatStack:CalculateSize();
	local pSize_StatStack = uiLeader.StatStack:GetSize();
	local pSize_LeaderContainer = uiLeader.LeaderContainer:GetSize();
	-- 条目24优化：同值幂等守卫——全量重建高频运行时（联机事件簇）阻断冗余 SetSizeVal 引发的再布局。
	-- 观察者局（bspec_loc）再进一步：高亮高度按「视图签名」缓存——观察者条目行高全部定值（区头/按钮），
	-- 但 StatStack 测高随文本布局时序波动数像素（用户实测抖动仍存），签名未变（未切视图/未翻轮播/
	-- 未改设置）则沿用已应用高度彻底稳定；签名变化重新测高；连续两次测得缩小 ≥4px 才采纳（收敛
	-- 首测/瞬态偏大，单次抖动被 4px 死区吸收）
	local nTargetW = pSize_LeaderContainer.x + LEADER_ART_OFFSET_X;
	local nTargetH;
	if bspec_loc == true then
		local sSig = table.concat({tostring(bIsSpec), tostring(bmasterspec), tostring(isMasked),
			tostring(b_score), tostring(b_trees), tostring(b_eras), tostring(b_army), tostring(b_yield),
			tostring(b_accu), tostring(b_hide), tostring(b_hide_2), tostring(HidePlayerInfo_PlayerName),
			tostring(HidePlayerInfo_CiviName)}, "|");
		local nMeasured = pSize_StatStack.y + LEADER_ART_OFFSET_Y + 65;
		local nCached = MPT_ObserverHeightCache[sSig];
		if nCached == nil then
			nTargetH = nMeasured;
		elseif nMeasured < nCached - 4 then
			local nCnt = (MPT_ObserverShrinkCount[sSig] or 0) + 1;
			if nCnt >= 2 then
				nTargetH = nMeasured;			-- 连续两次一致缩小：真内容变化，收敛
				MPT_ObserverShrinkCount[sSig] = 0;
			else
				nTargetH = nCached;				-- 单次缩小：视为测量抖动，沿用
				MPT_ObserverShrinkCount[sSig] = nCnt;
			end
		else
			MPT_ObserverShrinkCount[sSig] = 0;	-- ≥缓存-4（含抖动性增大）：全部沿用
			nTargetH = nCached;
		end
		MPT_ObserverHeightCache[sSig] = nTargetH;
	else
		nTargetH = pSize_StatStack.y + LEADER_ART_OFFSET_Y + 65;
	end
	local nCurW, nCurH = uiLeader.ActiveLeaderAndStats:GetSizeVal();
	if nCurW ~= nTargetW or nCurH ~= nTargetH then
		uiLeader.ActiveLeaderAndStats:SetSizeVal(nTargetW, nTargetH);
	end

	if uiLeader.TPT_Control_1 ~= nil then		-- 绑定按钮
		uiLeader.TPT_Control_1:RegisterCallback( Mouse.eLClick, OnMouseClick_TPT_Control_1L)		--左键点击
		uiLeader.TPT_Control_1:RegisterCallback( Mouse.eRClick, OnMouseClick_TPT_Control_1R)		--右键点击
	end

	UpdateStatValues( playerID, uiLeader );
end

-- ===========================================================================
--	Clears leaders and re-adds them to the stack
-- ===========================================================================
function UpdateLeaders()

	ResetLeaders();	

	m_ribbonStats = Options.GetUserOption("Interface", "RibbonStats");


	-- Add entries for everyone we know (Majors only)
	local kPlayers		 = PlayerManager.GetAliveMajors();
	local kMetPlayers	 = {};
	local kUniqueLeaders = {};

	local localPlayerID = Game.GetLocalPlayer();
	local pPlayer  = PlayerConfigurations[localPlayerID];
	if localPlayerID ~= -1 then
		local localPlayer	 = Players[localPlayerID];
		local localDiplomacy = localPlayer:GetDiplomacy();
		table.sort(kPlayers, function(a,b) return localDiplomacy:GetMetTurn(a:GetID()) < localDiplomacy:GetMetTurn(b:GetID()) end);
		
		AddLeader("ICON_"..PlayerConfigurations[localPlayerID]:GetLeaderTypeName(), localPlayerID, {});		--First, add local player.

		kMetPlayers, kUniqueLeaders = GetMetPlayersAndUniqueLeaders();										--Fill table for other players.
	else
		-- No local player so assume it's auto-playing, or local player is dead and observing; show everyone.
		for _, pPlayer in ipairs(kPlayers) do
			local playerID = pPlayer:GetID();
			kMetPlayers[ playerID ] = true;
			if (kUniqueLeaders[playerID] == nil) then
				kUniqueLeaders[playerID] = true;
			else
				kUniqueLeaders[playerID] = false;
			end	
		end
	end
	
	--Then, add the leader icons.
	for _, pPlayer in ipairs(kPlayers) do
		local playerID = pPlayer:GetID();
		if(playerID ~= localPlayerID ) then
			local isMet			 = kMetPlayers[playerID];
			local pPlayerConfig	 = PlayerConfigurations[playerID];
			local isHumanMP		 = (GameConfiguration.IsAnyMultiplayer() and pPlayerConfig:IsHuman());
			if (isMet or isHumanMP) then
				local leaderName = pPlayerConfig:GetLeaderTypeName();
				local isMasked	 = (isMet==false) and isHumanMP;	-- Multiplayer human but haven't met
				local isUnique	 = kUniqueLeaders[leaderName];
				local iconName	 = "ICON_LEADER_DEFAULT";
				
				-- If in an MP game and a player leaves the name returned will be NIL.				
				if isMet and (leaderName ~= nil) then
					iconName = "ICON_"..leaderName;
				end
				
				AddLeader(iconName, playerID, { 
					isMasked=isMasked,
					isUnique=isUnique
					}
				);
			end
		end
	end

	RealizeSize();
end


-- ===========================================================================
--	Updates size and location of BG and Scroll controls
--	additionalElementsWidth, from MODS that add additional content.
-- ===========================================================================
function RealizeSize( additionalElementsWidth )
	
	if additionalElementsWidth == nil then
		additionalElementsWidth = 0;
	end

	local MIN_LEFT_HOOKS			= 260;
	local RIGHT_HOOKS_INITIAL		= 163;
	local WORLD_TRACKER_OFFSET		= 80;					-- Amount of additional space the World Tracker check-box takes up.
	local launchBarWidth		 = MIN_LEFT_HOOKS;
	local partialScreenBarWidth  = RIGHT_HOOKS_INITIAL;	--Width of the upper right-hand of screen.

	-- Loop through leaders in determining size.
	m_leaderInstanceHeight = 0;
	for _,uiLeader in ipairs(m_uiLeadersByID) do
		-- If all are shown  then use max size.
		if m_ribbonStats == RibbonHUDStats.SHOW then
			m_leaderInstanceHeight = math.max( uiLeader.LeaderContainer:GetSizeY(), m_leaderInstanceHeight );
		else
			-- just the leader portrait.
			m_leaderInstanceHeight = uiLeader.SelectButton:GetSizeY();
		end
	end


	-- When not showing stats, leaders can be pushed closer together.
	if m_ribbonStats == RibbonHUDStats.SHOW then
		Controls.LeaderStack:SetStackPadding( 0 );		
	else
		Controls.LeaderStack:SetStackPadding( -8 );
	end
	Controls.LeaderStack:CalculateSize();

	-- Obtain controls
	local uiPartialScreenHookRoot	= ContextPtr:LookUpControl( "/InGame/PartialScreenHooks/RootContainer" );
	local uiPartialScreenHookBar 	= ContextPtr:LookUpControl( "/InGame/PartialScreenHooks/ButtonStack" );
	local uiLaunchBar			 	= ContextPtr:LookUpControl( "/InGame/LaunchBar/ButtonStack" );
	
	if (uiLaunchBar ~= nil) then
			launchBarWidth = math.max(uiLaunchBar:GetSizeX() + WORLD_TRACKER_OFFSET, MIN_LEFT_HOOKS);
	end
	if (uiPartialScreenHookBar~=nil) then
		if uiPartialScreenHookRoot and uiPartialScreenHookRoot:IsVisible() then
			partialScreenBarWidth = uiPartialScreenHookBar:GetSizeX();
		else
			partialScreenBarWidth = 0;  -- There are no partial screen hooks at all; backing is invisible.
		end

	end

	local screenWidth, screenHeight = UIManager:GetScreenSizeVal(); -- Cache screen dimensions
	
	local SIZE_LEADER	 = 63;	-- Size of leader icon and border.
	local paddingLeader	 = Controls.LeaderStack:GetStackPadding();
	local maxSize		 = screenWidth - launchBarWidth - partialScreenBarWidth;	
	local size			 = maxSize;

	g_maxNumLeaders = math.floor(maxSize / (SIZE_LEADER + paddingLeader));

	if m_leadersMet > 0 then
		-- Compute size of the background shadow
		local BG_PADDING_EDGE	 = 50;		-- Account for the (tons of) alpha on edges of shadow graphic.
		local MINIMUM_BG_SIZE	 = 100;
		local bgSize			 = 0;
		if (m_leadersMet > g_maxNumLeaders) then
			bgSize = g_maxNumLeaders * (SIZE_LEADER + paddingLeader) + additionalElementsWidth + BG_PADDING_EDGE;
		else
			bgSize = m_leadersMet * (SIZE_LEADER + paddingLeader) + additionalElementsWidth + BG_PADDING_EDGE;
		end		
		bgSize = math.max(bgSize, MINIMUM_BG_SIZE);
		Controls.RibbonContainer:SetSizeX( bgSize );

		-- Compute actual size of the container
		local PADDING_EDGE		 = 8;
		size = g_maxNumLeaders * (SIZE_LEADER + paddingLeader) + PADDING_EDGE + additionalElementsWidth;
	end
	Controls.ScrollContainer:SetSizeX(size);
	Controls.ScrollContainer:SetSizeY( m_leaderInstanceHeight );
	Controls.LeaderScroll:SetSizeX(size);
	Controls.RibbonContainer:SetOffsetX(partialScreenBarWidth);	
	Controls.LeaderScroll:CalculateSize();
	RealizeScroll();
end

-- ===========================================================================
--	Updates visibility of previous and next buttons
-- ===========================================================================
function RealizeScroll()
	Controls.NextButtonContainer:SetHide( not CanScrollLeft() );
	Controls.PreviousButtonContainer:SetHide( not CanScrollRight() );	
end

-- ===========================================================================
function CanScrollLeft()
	return m_scrollIndex > 0;
end
-- ===========================================================================
function CanScrollRight()
	return m_leadersMet - m_scrollIndex > g_maxNumLeaders;
end

-- ===========================================================================
--	Initialize scroll animation in a particular direction
-- ===========================================================================
function Scroll(direction )
 
	m_scrollPercent = 0;
	m_scrollIndex = m_scrollIndex + direction;

	if(m_scrollIndex < 0) then 
		m_scrollIndex = 0; 
	end

	if(not m_isScrolling) then
		ContextPtr:SetUpdate( UpdateScroll );
		m_isScrolling = true;
	end

	RealizeScroll();
end

-- ===========================================================================
--	Update scroll animation (only called while animating)
-- ===========================================================================
function UpdateScroll(deltaTime )
	
	local start			 = Controls.LeaderScroll:GetScrollValue();
	local destination	 = 1.0 - (m_scrollIndex / (m_leadersMet - g_maxNumLeaders));

	m_scrollPercent = m_scrollPercent + (SCROLL_SPEED * deltaTime);
	if(m_scrollPercent >= 1) then
		m_scrollPercent = 1
		EndScroll();
	end

	Controls.LeaderScroll:SetScrollValue(start + (destination - start) * m_scrollPercent);
end

-- ===========================================================================
--	Cleans up scroll update callback when done scrollin
-- ===========================================================================
function EndScroll()
	ContextPtr:ClearUpdate();
	m_isScrolling = false;
	RealizeScroll();
end

-- ===========================================================================
--	SystemUpdateUI Callback
-- ===========================================================================
function OnUpdateUI(type, tag, iData1, iData2, strData1)
	if(type == SystemUpdateUI.ScreenResize) then
		RealizeSize();
	end
end

-- ===========================================================================
--	EVENT
--	Options menu changed
-- ===========================================================================
function OnUserOptionChanged( eOptionSet, hOptionKey, newOptionValue )
	local ribbonStatsHash  = DB.MakeHash("RibbonStats");
	if hOptionKey == ribbonStatsHash then
	
		RealizeYieldEvents();			-- Change subscription to events (if necessary)	
		m_kLeaderIM:DestroyInstances();	-- Look is changing, start with new instances.
		m_scrollIndex = 0;				-- Reset scroll position to start.
		UpdateLeaders();				-- Now update all the leaders.
		RealizeScroll();

		-- Play appropriate animations
		for id,_ in pairs(m_kActiveIds) do
			if Players[id] and Players[id]:IsTurnActive() then
				OnTurnBegin( id );
			end
		end
	end	
end

-- ===========================================================================
--	EVENT
--	Diplomacy Callback
-- ===========================================================================
function OnDiplomacyMeet(player1ID, player2ID)
	
	local localPlayerID = Game.GetLocalPlayer();
	-- Have a local player?
	if(localPlayerID ~= PlayerTypes.NONE) then
		-- Was the local player involved?
		if (player1ID == localPlayerID or player2ID == localPlayerID) then
			UpdateLeaders();
		end
	end
end

-- ===========================================================================
--	EVENT
--	Diplomacy Callback
-- ===========================================================================
function OnDiplomacyWarStateChange(player1ID, player2ID)
	
	local localPlayerID = Game.GetLocalPlayer();
	-- Have a local player?
	if(localPlayerID ~= PlayerTypes.NONE) then
		-- Was the local player involved?
		if (player1ID == localPlayerID or player2ID == localPlayerID) then
			UpdateLeaders();
		end
	end
end

-- ===========================================================================
--	EVENT
--	Diplomacy Callback
-- ===========================================================================
function OnDiplomacySessionClosed(sessionID)

	local localPlayerID = Game.GetLocalPlayer();
	-- Have a local player?
	if(localPlayerID ~= PlayerTypes.NONE) then
		-- Was the local player involved?
		local diplomacyInfo = DiplomacyManager.GetSessionInfo(sessionID);
		if(diplomacyInfo ~= nil and (diplomacyInfo.FromPlayer == localPlayerID or diplomacyInfo.ToPlayer == localPlayerID)) then
			UpdateLeaders();
		end
	end
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode, eNewMode)
	if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		ContextPtr:SetHide(true);
	end
	if eOldMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		ContextPtr:SetHide(false);
	end
end

-- ===========================================================================
function SetOffsetX2Center( Ctr , width )
	local sizeX = Ctr:GetSizeX();
	if sizeX < width then
		Ctr:SetOffsetX( (width-sizeX)/2 )
	else
		Ctr:SetOffsetX( 0 )
	end
end


function UpdateStatValues( playerID, uiLeader )	

	if uiLeader.PlayerName:IsVisible() then
		if PlayerConfigurations[playerID] ~= nil and PlayerConfigurations[playerID]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
			-- 条目24修复：观察者名字行改 SetOffsetX2Center 定位（用户裁决）——原 PlayerNameLen 测宽
			-- 回写偏移随文本布局时序左右游移（ScrollTextField 长名测宽不稳定，用户实测两帧名字位置不同）
			SetOffsetX2Center( uiLeader.PlayerName , 60 )
		elseif uiLeader.PlayerName:GetText() == "PlayerName" or uiLeader.PlayerName:GetText() ~= Locale.Lookup( PlayerConfigurations[playerID]:GetPlayerName() )then
			uiLeader.PlayerName:SetText( Locale.Lookup( PlayerConfigurations[playerID]:GetPlayerName() ) )
			uiLeader.PlayerNameLen:SetText( Locale.Lookup( PlayerConfigurations[playerID]:GetPlayerName() ) )
		end

		if PlayerConfigurations[playerID] == nil or PlayerConfigurations[playerID]:GetLeaderTypeName() ~= "LEADER_SPECTATOR" then
			local pSize_PlayerNameLen = uiLeader.PlayerNameLen:GetSizeX();
			if pSize_PlayerNameLen < 60 then
				uiLeader.PlayerName:SetOffsetX(	(60 - pSize_PlayerNameLen)/2 )
			else
				uiLeader.PlayerName:SetOffsetX( 0 )
			end
		end
	end
	
	if uiLeader.CivName:IsVisible() then
		-- 条目24修复：观察者条目不显示文明名行（观察者 GetCivilizationShortDescription 返回「Spectator」
		-- 多余描述，用户实测截图——观察者条目只保留 SpecTag「观察者」）；else 分支按设置回写显隐，
		-- 防实例回收复用后观察者行的隐藏态泄漏到普通玩家行
		if PlayerConfigurations[playerID] ~= nil and PlayerConfigurations[playerID]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
			uiLeader.CivName:SetHide(true);
		else
			uiLeader.CivName:SetHide(HidePlayerInfo_CiviName);
			uiLeader.CivName:SetText( Locale.Lookup( PlayerConfigurations[playerID]:GetCivilizationShortDescription() ) )
			SetOffsetX2Center( uiLeader.CivName , 60 )
		end
	end

	RefreshAccessLevel()		-- 刷新能见度
	
	-- 条目24：组可见性快照（IsVisible 取控件自身标记；组合开关走组级后，行计算门槛并查组状态，
	-- 保留原「隐藏行不计算」的性能语义）
	local bStockVis = uiLeader.Group_Stock:IsVisible();
	local bRateVis = uiLeader.Group_Rate:IsVisible();
	local bGodView = (bspec_loc == true);		-- 条目24修复：观察者全知视角——跳过全部外交能见度披露门槛（BSM 语义：观察者局一切可见，无外交渠道拿能见度等级）
	local pPlayer = Players[playerID];
	
	if uiLeader.Score:IsVisible() then 		-- 分数
		local score	 = Round( pPlayer:GetScore() );
		uiLeader.Score:SetText("[ICON_Capital]"..tostring(score));
	end
	
	--组合1
	if bStockVis and uiLeader.Military:IsVisible() then	-- 军事实力
		local Canshow = true
		-- 条目24：Model 3（默认）不走此门槛——默认=标准基础上军事实力恒显示；观察者局走 bGodView 跳过
		if Model == 0 and not bGodView then
			if not IsTeamPlayer[playerID] then
				Canshow = false
			end
		end	
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 3 then
					Canshow = false
				end
			end
		end				
		if Canshow then
			local military  = Round( Players[playerID]:GetStats():GetMilitaryStrengthWithoutTreasury() );
			uiLeader.Military:SetText( "[ICON_Strength]"..tostring(military));	
		else
			uiLeader.Military:SetText( "[ICON_Strength]"..Invisible);		
		end
	end
	if bStockVis and uiLeader.Science:IsVisible() then 		-- 科技
		local Canshow = true
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 2 then
					Canshow = false
				end
			end
		end			
		if Canshow then
			local science  = Round(pPlayer:GetTechs():GetScienceYield() );
			uiLeader.Science:SetText( "[ICON_Science]"..tostring(science));
		else
			uiLeader.Science:SetText( "[ICON_Science]"..Invisible);
		end
	end
	if bStockVis and uiLeader.Culture:IsVisible() then 		-- 文化
		local Canshow = true
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 2 then
					Canshow = false
				end
			end
		end
		if Canshow then		
			local culture  = Round(pPlayer:GetCulture():GetCultureYield() );
			uiLeader.Culture:SetText( "[ICON_Culture]"..tostring(culture));
		else
			uiLeader.Culture:SetText( "[ICON_Culture]"..Invisible);
		end
	end
	if bStockVis and uiLeader.Gold:IsVisible() then		-- 金币储备
		local Canshow = true
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 1 then
					Canshow = false
				end
			end
		end
		if Canshow then		
			local pTreasury		= pPlayer:GetTreasury();
			local gold		 = math.floor( pTreasury:GetGoldBalance() );
			uiLeader.Gold:SetText( "[ICON_Gold]"..tostring(gold));
		else
			uiLeader.Gold:SetText( "[ICON_Gold]"..Invisible);
		end
	end
	if bStockVis and uiLeader.Faith:IsVisible() then		-- 信仰储备
		local Canshow = true
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 1 then
					Canshow = false
				end
			end
		end
		if Canshow then		
			local faith	 = Round( Players[playerID]:GetReligion():GetFaithBalance() );
			uiLeader.Faith:SetText( "[ICON_Faith]"..tostring(faith));
		else
			uiLeader.Faith:SetText( "[ICON_Faith]"..Invisible);
		end
	end
	if bStockVis and uiLeader.Favor:IsVisible() then 		-- 外交支持储备
		local Canshow = true
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 1 then
					Canshow = false
				end
			end
		end
		if Canshow then		
			local favor	 = Round( Players[playerID]:GetFavor() );
			uiLeader.Favor:SetText( " [ICON_Favor] "..tostring(favor)); 
		else
			uiLeader.Favor:SetText( " [ICON_Favor] "..Invisible); 
		end
	end
	
	--组合2
	if bRateVis and uiLeader.Cities:IsVisible() then			-- 人口总量
		local Canshow = true
		if (Model == 0 or Model == 3) and not bGodView then
			if not IsTeamPlayer[playerID] then
				Canshow = false
			end
		end
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 2 then
					Canshow = false
				end
			end
		end
		if 	Canshow then
			local cities = Round(	GetPopulation(playerID) );	
			uiLeader.Cities:SetText( "[ICON_Citizen]"..tostring(cities));
		else
			uiLeader.Cities:SetText( "[ICON_Citizen]"..Invisible);
		end
	end	
	if bRateVis and uiLeader.Food_Total:IsVisible() then 		-- 食物产出总量
		local Canshow = true
		if (Model == 0 or Model == 3) and not bGodView then
			if not IsTeamPlayer[playerID] then
				Canshow = false
			end
		end
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 2 then
					Canshow = false
				end
			end
		end		
		if 	Canshow then
			local foodsurplus_Total = Round(	GetFoodSurplusTotal(playerID) );	
			uiLeader.Food_Total:SetText( "[ICON_Food]"..tostring(foodsurplus_Total));		
		else
			uiLeader.Food_Total:SetText( "[ICON_Food]"..Invisible);	
		end	
	end		
	if bRateVis and uiLeader.Production_Total:IsVisible() then 		-- 生产力总量
		local Canshow = true
		if (Model == 0 or Model == 3) and not bGodView then
			if not IsTeamPlayer[playerID] then
				Canshow = false
			end
		end
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 3 then
					Canshow = false
				end
			end
		end			
		if 	Canshow then
			local production_Total = Round(	GetProduction(playerID) );	
			uiLeader.Production_Total:SetText( "[ICON_Production]"..tostring(production_Total));		
		else
			uiLeader.Production_Total:SetText( "[ICON_Production]"..Invisible);	
		end	
	end	
	if bRateVis and uiLeader.GoldPerTurn:IsVisible() then 				-- 回合金币产出
		local Canshow = true
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 1 then
					Canshow = false
				end
			end
		end
		if Canshow then		
			local pTreasury		= pPlayer:GetTreasury();	
			local goldPerTurn = math.floor( pTreasury:GetGoldYield() - pTreasury:GetTotalMaintenance() );
			uiLeader.GoldPerTurn:SetText( "[ICON_Gold]"..tostring(goldPerTurn));
		else
			uiLeader.GoldPerTurn:SetText( "[ICON_Gold]"..Invisible);
		end
	end	
	if bRateVis and uiLeader.FaithperTurn:IsVisible() then		-- 回合信仰产出
		local Canshow = true
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 1 then
					Canshow = false
				end
			end
		end
		if Canshow then		
			local faithperTurn = Round( Players[playerID]:GetReligion():GetFaithYield());
			uiLeader.FaithperTurn:SetText( "[ICON_Faith]"..tostring(faithperTurn));
		else
			uiLeader.FaithperTurn:SetText( "[ICON_Faith]"..Invisible);
		end
	end			
	if bRateVis and uiLeader.FavorperTurn:IsVisible() then		-- 回合外交支持增量
		local Canshow = true
		if Model == 1 and not bGodView then
			if not IsTeamPlayer[playerID] then
				if g_AccessLevel[playerID] < 1 then
					Canshow = false
				end
			end
		end
		if Canshow then		
			local favorperTurn = Round( Players[playerID]:GetFavorPerTurn() );			
			uiLeader.FavorperTurn:SetText( " [ICON_Favor] "..tostring(favorperTurn));
		else
			uiLeader.FavorperTurn:SetText( " [ICON_Favor] "..Invisible);
		end
	end	
	
	-- ==== 条目24：BSM 观察者数据行（原 BSM UpdateStatValues 补充段；组不可见即不计算，性能语义与上行门槛一致）====
	if uiLeader.Group_Observer:IsVisible() then
		-- Ping。原 BSM Data 行受 1.67 MPH_ON 门控且走 "GAP_<playerID>" 平均延迟协议（依赖 1.67 MPH
		-- 写入配置，本 mod 未移植必 nil → 残留「L: na」乱数行）——条目24修复剔除 GAP 协议；条目24修复2：
		-- 「主机」标识按用户裁决移除（观察者条目只保留「观察者」），仅真实延迟存在时显示，否则整行隐藏
		--（嵌套 Stack 隐藏行自动跳过布局）
		local data = "";
		if playerID ~= Game.GetLocalPlayer() then
			local ping = Network.GetPingTime( playerID );
			if ping ~= nil and ping ~= -1 then
				data = " P:"..ping;
			end
		end
		if data == "" then
			uiLeader.SpecData:SetHide(true);
		else
			uiLeader.SpecData:SetText(data);
			uiLeader.SpecData:SetHide(false);
		end
	end

	if uiLeader.Group_Observer:IsVisible() and uiLeader.Group_SpecEras:IsVisible() then
		-- 政体（原 BSM 同名行）
		local govType = "";
		local eSelectePlayerGovernment = Players[playerID]:GetCulture():GetCurrentGovernment();
		if eSelectePlayerGovernment ~= -1 then
			govType = Locale.Lookup(GameInfo.Governments[eSelectePlayerGovernment].Name);
		else
			govType = Locale.Lookup("LOC_GOVERNMENT_ANARCHY_NAME" );
		end
		-- 条目24修复：原 string.len/string.sub 按字节截断，UTF-8 中文切在字节中间产生乱码
		--（用户实测「古典共和国」→「古典噎」）——删 Lua 截断，超宽交引擎 ReduceWidth=61 干净省略号
		uiLeader.Governement:SetText(tostring(govType));
		-- 城市数 + 人口（原 BSM Cities 行，因与 DPR 人口行 ID 冲突改名 Spec_Cities）
		local cities = Players[playerID]:GetCities();
		local numCities = 0;
		local ERD_Total_Population = 0;
		for i,city in cities:Members() do
			ERD_Total_Population = ERD_Total_Population + city:GetPopulation();
			numCities = numCities + 1;
		end
		-- 城市数 + 人口（原 BSM Cities 行，因与 DPR 人口行 ID 冲突改名 Spec_Cities）。
		-- 条目24修复： Housing/Citizen 内联图标较大，去空格紧凑防 61px 截断（行距在 XML StackPadding 加大）
		uiLeader.Spec_Cities:SetText(numCities.."[ICON_Housing]"..ERD_Total_Population.."[ICON_Citizen]");
		-- 当前时代（原 BSM 顺手修复：sEras 全局泄漏 → local）
		local pGameEras = Game.GetEras();
		local sEras = "";
		if pGameEras:HasHeroicGoldenAge(playerID) then
			sEras = Locale.Lookup("LOC_ERA_PROGRESS_HEROIC_AGE");
		elseif pGameEras:HasGoldenAge(playerID) then
			sEras = Locale.Lookup("LOC_ERA_PROGRESS_GOLDEN_AGE");
		elseif pGameEras:HasDarkAge(playerID) then
			sEras = Locale.Lookup("LOC_ERA_PROGRESS_DARK_AGE");
		else
			sEras = Locale.Lookup("LOC_ERA_PROGRESS_NORMAL_AGE");
		end
		-- 条目24修复：同上删字节截断（「普通时代」→「普鮠age」乱码），超宽交引擎省略号
		uiLeader.CurrentAge:SetText(sEras);
		-- 时代分（原 BSM 同名行）
		local gameEras = Game.GetEras();
		local eraScore	= gameEras:GetPlayerCurrentScore(playerID);
		local isFinalEra = gameEras:GetCurrentEra() == gameEras:GetFinalEra();
		local darkAgeThreshold = gameEras:GetPlayerDarkAgeThreshold(playerID);
		local goldenAgeThreshold = gameEras:GetPlayerGoldenAgeThreshold(playerID);
		local ageIconName = "[ICON_GLORY_NORMAL_AGE]";
		if eraScore >= darkAgeThreshold then
			ageIconName = gameEras:HasDarkAge(playerID) and "[ICON_GLORY_GOLDEN_AGE]" or "[ICON_GLORY_SUPER_GOLDEN_AGE]";
		else
			ageIconName = "[ICON_GLORY_DARK_AGE]";
		end
		local strEra = ageIconName .. eraScore
		if isFinalEra == false then
			strEra = strEra.." / " .. (eraScore > darkAgeThreshold and goldenAgeThreshold or darkAgeThreshold)
		end
		uiLeader.EraScore:SetText(strEra);
	end

	if uiLeader.Group_Observer:IsVisible() and uiLeader.Group_SpecArmy:IsVisible() then
		-- 陆海空单位数（原 BSM 同名行）
		local unit_land = 0
		local unit_sea = 0
		local unit_air = 0
		local pUnits = Players[playerID]:GetUnits()
		for k,kUnit in pUnits:Members() do
			local domain = GameInfo.Units[kUnit:GetUnitType()].Domain;
			if ( domain == "DOMAIN_AIR" ) then
				unit_air = unit_air + 1
			elseif ( domain == "DOMAIN_SEA" ) then
				unit_sea = unit_sea + 1
			elseif ( domain == "DOMAIN_LAND" ) then
				unit_land = unit_land + 1
			end
		end
		uiLeader.LandUnit:SetText(SpecStr_Land.. tostring(unit_land))
		uiLeader.NavyUnit:SetText(SpecStr_Navy.. tostring(unit_sea))
		uiLeader.AirUnit:SetText(SpecStr_Air.. tostring(unit_air))
		-- 核弹（原 BSM 同名行）。条目24修复：两类武器同行在 63px 列宽被 61px 截断遮挡（用户实测截图）——
		-- 拆两行 [NEWLINE]，每行约 35px 富余。条目24修复2：数字改放图标右侧（用户裁决「数字放右边」，
		-- 对齐全列 icon 左数字右的行式——原 BSM 数量前置）
		local playerWMDs  = Players[playerID]:GetWMDs()
		local strNuke = ""
		for entry in GameInfo.WMDs() do
			if (entry.WeaponType == "WMD_NUCLEAR_DEVICE") then
				strNuke = "[ICON_Nuclear] "..playerWMDs:GetWeaponCount(entry.Index)
			elseif (entry.WeaponType == "WMD_THERMONUCLEAR_DEVICE") then
				strNuke = strNuke.."[NEWLINE][ICON_ThermoNuclear] "..playerWMDs:GetWeaponCount(entry.Index)
			end
		end
		uiLeader.Nukes:SetText(strNuke)
		-- 战略资源库存（原 BSM 同名行；顺手修复 resourceText 全局泄漏、剔除未使用的累计/消耗读取）。
		-- 条目24修复：原 2 资源/行 + [NEWLINE] 折行，每行都被 ReduceWidth=61 截断成图标乱码（用户实测
		-- 截图「25 0/0 0」挤压）——改 1 资源/行，且无库存上限且无存量（未解锁科技/不在局）的资源不占行
		local pPlayerResources = Players[playerID]:GetResources();
		local tRes = {}
		for resource in GameInfo.Resources() do
			if (resource.ResourceClassType ~= nil and resource.ResourceClassType ~= "RESOURCECLASS_BONUS" and resource.ResourceClassType ~="RESOURCECLASS_LUXURY" and resource.ResourceClassType ~="RESOURCECLASS_ARTIFACT") then
				local stockpileAmount = pPlayerResources:GetResourceAmount(resource.ResourceType);
				local stockpileCap = pPlayerResources:GetResourceStockpileCap(resource.ResourceType);
				local reservedAmount = pPlayerResources:GetReservedResourceAmount(resource.ResourceType);
				local totalAmount = stockpileAmount + reservedAmount;
				if (totalAmount > stockpileCap) then
					totalAmount = stockpileCap;
				end
				if stockpileCap > 0 or totalAmount > 0 then
					table.insert(tRes, "[ICON_"..resource.ResourceType.."] ".. stockpileAmount);
				end
			end
		end
		uiLeader.Strategic1:SetText(table.concat(tRes, "[NEWLINE]"))
	end

	if uiLeader.Group_Observer:IsVisible() and uiLeader.Group_SpecYield:IsVisible() then
		-- 毛粮（原 BSM Cities_Food 行；毛产 Cities_Prod 与生产力总量恒等已移出产出视图，见 MPT_RealizeObserverView）
		local cities = Players[playerID]:GetCities();
		local ERD_Total_Food = 0;
		for i,city in cities:Members() do
			ERD_Total_Food = ERD_Total_Food + math.floor( city:GetYield( YieldTypes.FOOD )) ;
		end
		uiLeader.Cities_Food:SetText("[ICON_Food]"..ERD_Total_Food);
	end

	if uiLeader.Group_Observer:IsVisible() and uiLeader.Group_SpecTotal:IsVisible() then
		-- 累计产出（原 BSM Total_* 行，REPLAYDATASET 回放数据集求和）
		local data_gold = nil;
		local data_science = nil;
		local data_culture = nil;
		local data_faith = nil;
		local count = GameSummary.GetDataSetCount();
		for i = 0, count - 1, 1 do
			if(GameSummary.GetDataSetVisible(i) and GameSummary.HasDataSetValues(i)) then
				local name = GameSummary.GetDataSetName(i);
				if name == "REPLAYDATASET_TOTALGOLD" then
					data_gold = GameSummary.CoalesceDataSet(i, GameConfiguration.GetStartTurn(), Game.GetCurrentGameTurn());
				elseif name == "REPLAYDATASET_SCIENCEPERTURN" then
					data_science = GameSummary.CoalesceDataSet(i, GameConfiguration.GetStartTurn(), Game.GetCurrentGameTurn());
				elseif name == "REPLAYDATASET_CULTURE" then
					data_culture = GameSummary.CoalesceDataSet(i, GameConfiguration.GetStartTurn(), Game.GetCurrentGameTurn());
				elseif name == "REPLAYDATASET_FAITHPERTURN" then
					data_faith = GameSummary.CoalesceDataSet(i, GameConfiguration.GetStartTurn(), Game.GetCurrentGameTurn());
				end
			end
		end

		if data_gold ~= nil then
			for player, turnData in pairs(data_gold) do
				if(player == playerID and Players[playerID] and PlayerConfigurations[playerID]:GetLeaderTypeName() ~= "LEADER_SPECTATOR") then
					local gold = 0
					local last_gold = 0
					for turn, value in pairs(turnData) do
						if tonumber(value) ~= nil then
							if tonumber(value) >= last_gold then
								gold = gold + tonumber(value) - last_gold
							end
						end
						last_gold = tonumber(value)
					end
					uiLeader.Total_Gold:SetText( "[ICON_Gold] "..math.floor(gold))
				end
			end
		end

		if data_science ~= nil then
			for player, turnData in pairs(data_science) do
				if(player == playerID and Players[playerID] and PlayerConfigurations[playerID]:GetLeaderTypeName() ~= "LEADER_SPECTATOR") then
					local science = 0
					for turn, value in pairs(turnData) do
						if (tonumber(value)) ~= nil then
							science = science + tonumber(value)
						end
					end
					uiLeader.Total_Science:SetText( "[ICON_Science] "..math.floor(science))
				end
			end
		end

		if data_culture ~= nil then
			for player, turnData in pairs(data_culture) do
				if(player == playerID and Players[playerID] and PlayerConfigurations[playerID]:GetLeaderTypeName() ~= "LEADER_SPECTATOR") then
					local culture = 0
					for turn, value in pairs(turnData) do
						if (tonumber(value)) ~= nil then
							culture = culture + tonumber(value)
						end
					end
					uiLeader.Total_Culture:SetText( "[ICON_Culture] "..math.floor(culture))
				end
			end
		end

		if data_faith ~= nil then
			for player, turnData in pairs(data_faith) do
				if(player == playerID and Players[playerID] and PlayerConfigurations[playerID]:GetLeaderTypeName() ~= "LEADER_SPECTATOR") then
					local faith = 0
					for turn, value in pairs(turnData) do
						if (tonumber(value)) ~= nil then
							faith = faith + tonumber(value)
						end
					end
					uiLeader.Total_Faith:SetText( "[ICON_Faith] "..math.floor(faith))
				end
			end
		end
	end

	-- 仪表
	-- 条目24：刷新条件改组可见（覆盖非观察者仪表模式与观察者 Techs 视图两种来源；原条件 not m_TechCivisProgress）
	if uiLeader.Group_TechCivis:IsVisible() then
		RefreshCivisMeter(playerID, uiLeader)
		RefreshTechMeter(playerID, uiLeader)
	end
	
	-- Show or hide all stats based on options.
	if m_ribbonStats == RibbonHUDStats.SHOW then
		if uiLeader.StatStack:IsHidden() or m_isIniting then
			ShowStats( uiLeader );
		end
	elseif m_ribbonStats == RibbonHUDStats.FOCUS or m_ribbonStats == RibbonHUDStats.HIDE then
		if uiLeader.StatStack:IsVisible() or m_isIniting then			
			HideStats( uiLeader );
		end
	end
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnTurnBegin( playerID )
	local uiLeader		 = m_uiLeadersByID[playerID];
	if(uiLeader ~= nil) then
		UpdateStatValues( playerID, uiLeader );

		local localPlayerID = Game.GetLocalPlayer();
		if(localPlayerID == PlayerTypes.NONE or localPlayerID == PlayerTypes.OBSERVER)then
			return;
		end

		-- Update the approripate animation (alpha vs slide) based on what mode is being used.
		if 	m_ribbonStats == RibbonHUDStats.SHOW then
			if(not(playerID == localPlayerID or Players[localPlayerID]:GetDiplomacy():HasMet(playerID))) then
				uiLeader.LeaderContainer:SetSizeVal(63,63);
			end
			local pSize = uiLeader.LeaderContainer:GetSize();
--			uiLeader.ActiveLeaderAndStats:SetSizeVal( pSize.x + LEADER_ART_OFFSET_X, pSize.y + LEADER_ART_OFFSET_Y );		-- 不适配变化的尺寸
			uiLeader.ActiveLeaderAndStats:SetToBeginning();
			uiLeader.ActiveLeaderAndStats:Play();
		else
			uiLeader.ActiveSlide:SetToBeginning();
			uiLeader.ActiveSlide:Play();
		end
	end

	-- Kluge: autoplay layout will frequently size ribbon before other panels and place it behind them in the HUD.
	local localPlayer = Game.GetLocalPlayer();
	local isAutoPlay = (localPlayer == PlayerTypes.NONE or localPlayer == PlayerTypes.OBSERVER);
	if isAutoPlay then
		RealizeSize();
	end

	m_kActiveIds[playerID] = true;

	UpdateLeaders();
end

-- ===========================================================================
function ResetActiveAnim( playerID )
	local uiLeader  = m_uiLeadersByID[playerID];
	if(uiLeader ~= nil) then
		uiLeader.ActiveLeaderAndStats:SetToBeginning();
		uiLeader.ActiveSlide:SetToBeginning();
	end
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnTurnEnd( playerID )
	local uiLeader  = m_uiLeadersByID[playerID];
	if(uiLeader ~= nil) then
		if m_ribbonStats == RibbonHUDStats.SHOW then
			uiLeader.ActiveLeaderAndStats:Reverse();
		else
			uiLeader.ActiveSlide:Reverse();
		end
	end
	m_kActiveIds[playerID] = nil;
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnLocalTurnBegin()
	local playerID	 = Game.GetLocalPlayer();
	if playerID == PlayerTypes.NONE then return; end;
	OnTurnBegin( playerID );
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnLocalTurnEnd()
	local playerID	 = Game.GetLocalPlayer();
	if playerID == PlayerTypes.NONE then return; end;
	OnTurnEnd( playerID );
end

-- ===========================================================================
--	LUAEvent
-- ===========================================================================
function OnLaunchBarResized( width )
	RealizeSize();
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnScrollLeft()
	if CanScrollLeft() then 
		Scroll(-1); 
	end
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnScrollRight()
	if CanScrollRight() then 
		Scroll(1); 
	end
end

-- ===========================================================================
function OnChatReceived(fromPlayer, stayOnScreen)
	local instance= m_uiLeadersByID[fromPlayer];
	if instance == nil then return; end
	if stayOnScreen then
		Controls.ChatIndicatorWaitTimer:Stop();
		instance.ChatIndicatorFade:RegisterEndCallback(function() end);
		table.insert(m_uiChatIconsVisible, instance.ChatIndicatorFade);
	else
		Controls.ChatIndicatorWaitTimer:Stop();

		instance.ChatIndicatorFade:RegisterEndCallback(function() 
			Controls.ChatIndicatorWaitTimer:RegisterEndCallback(function()
				instance.ChatIndicatorFade:RegisterEndCallback(function() instance.ChatIndicatorFade:SetToBeginning(); end);
				instance.ChatIndicatorFade:Reverse();
			end);
			Controls.ChatIndicatorWaitTimer:SetToBeginning();
			Controls.ChatIndicatorWaitTimer:Play();
		end);
	end
	instance.ChatIndicatorFade:Play();
end

-- ===========================================================================
function OnChatPanelShown(fromPlayer, stayOnScreen)
	for _, chatIndicatorFade in ipairs(m_uiChatIconsVisible) do
		chatIndicatorFade:RegisterEndCallback(function() chatIndicatorFade:SetToBeginning(); end);
		chatIndicatorFade:Reverse();
	end
	chatIndicatorFade = {};
end

-- ===========================================================================
function OnLoadGameViewStateDone()
	if(GameConfiguration.IsAnyMultiplayer()) then
		for leaderID, uiLeader in pairs(m_uiLeadersByID) do
			if Players[leaderID]:IsTurnActive() then
				uiLeader.ActiveLeaderAndStats:SetToBeginning();
				uiLeader.ActiveLeaderAndStats:Play();
			end
		end
	end
end

-- ===========================================================================
--	UI Callback
--	Refresh the stats.
-- ===========================================================================
function OnRefresh()
	ContextPtr:ClearRequestRefresh();

	if table.count(g_kRefreshRequesters) > 0 then
		local localPlayerID = Game.GetLocalPlayer();
		if localPlayerID ~= PlayerTypes.NONE and localPlayerID ~= PlayerTypes.OBSERVER and Players[localPlayerID]:IsTurnActive() then 
			local uiLeader  = m_uiLeadersByID[localPlayerID];
			if uiLeader ~= nil then
				UpdateStatValues( localPlayerID, uiLeader );
			end	
		end
	else
		UI.DataError("Attempt to refresh diplomacy ribbon stats but no event triggered the refresh!");
	end
	g_kRefreshRequesters = {};	-- Clear out for next refresh
end

-- ===========================================================================
--	Event
--	Special from most other yield events as this may trigger on players other
--	than the local player for actions such as making a deal.
-- ===========================================================================
function OnTreasuryChanged( playerID, yield , balance)	
	local uiLeader  = m_uiLeadersByID[playerID];
	if uiLeader ~= nil then
		UpdateStatValues( playerID, uiLeader );
	end	

	-- If refresh is pending for local player, it can be cleared.
	if playerID == Game.GetLocalPlayer() and table.count(g_kRefreshRequesters) > 0 then
		ContextPtr:ClearRequestRefresh();
	end
end

-- ===========================================================================
--	Only the local player's yields should be update by event to prevent
--	multiplay changes that telgraph to others what is occuring.
-- ===========================================================================
function OnLocalStatUpdateRequest( eventName )
	table.insert( g_kRefreshRequesters, eventName );
	ContextPtr:RequestRefresh();
end

-- ===========================================================================
--	For use in scenarios to force show ribbon yields (i.e. PirateScenario)
-- ===========================================================================
function SetRibbonOption( option  )
	m_ribbonStats = option;
end

-- ===========================================================================
--	For use in scenarios/mods
-- ===========================================================================
function GetLeaderInstanceByID(playerID )
	return m_uiLeadersByID[playerID];
end

-- ===========================================================================
function StopRibbonAnimation(playerID)
	local uiLeader		 = m_uiLeadersByID[playerID];
	if(uiLeader ~= nil) then
		uiLeader.ActiveLeaderAndStats:SetToBeginning();
		uiLeader.ActiveSlide:SetToBeginning();
	end
end

-- ===========================================================================
function OnStartObserverMode()
	UpdateLeaders();
end

-- ===========================================================================
--	Define EVENT callback functions so they can be added/removed based on
--	whether or not yield stats are being shown.
-- ===========================================================================
OnAnarchyBegins				= function() OnLocalStatUpdateRequest( "OnAnarchyBegins" ); end
OnAnarchyEnds				= function() OnLocalStatUpdateRequest( "OnAnarchyEnds" ); end
OnCityFocusChanged			= function() OnLocalStatUpdateRequest( "OnCityFocusChanged" ); end
OnCityInitialized			= function() OnLocalStatUpdateRequest( "OnCityInitialized" ); end
OnCityProductionChanged		= function() OnLocalStatUpdateRequest( "OnCityProductionChanged" ); end
OnCityWorkerChanged			= function() OnLocalStatUpdateRequest( "OnCityWorkerChanged" ); end
OnDiplomacySessionClosed	= function() OnLocalStatUpdateRequest( "OnDiplomacySessionClosed" ); end
OnFaithChanged				= function() OnLocalStatUpdateRequest( "OnFaithChanged" ); end
OnGovernmentChanged			= function() OnLocalStatUpdateRequest( "OnGovernmentChanged" ); end
OnGovernmentPolicyChanged	= function() OnLocalStatUpdateRequest( "OnGovernmentPolicyChanged" ); end
OnGovernmentPolicyObsoleted	= function() OnLocalStatUpdateRequest( "OnGovernmentPolicyObsoleted" ); end
OnGreatWorkCreated			= function() OnLocalStatUpdateRequest( "OnGreatWorkCreated" ); end
OnImprovementAddedToMap		= function() OnLocalStatUpdateRequest( "OnImprovementAddedToMap" ); end
OnImprovementRemovedFromMap	= function() OnLocalStatUpdateRequest( "OnImprovementRemovedFromMap" ); end
OnPantheonFounded			= function() OnLocalStatUpdateRequest( "OnPantheonFounded" ); end
OnPlayerAgeChanged			= function() OnLocalStatUpdateRequest( "OnPlayerAgeChanged" ); end
OnResearchCompleted			= function() OnLocalStatUpdateRequest( "OnResearchCompleted" ); end
OnUnitAddedToMap			= function() OnLocalStatUpdateRequest( "OnUnitAddedToMap" ); end
OnUnitGreatPersonActivated	= function() OnLocalStatUpdateRequest( "OnUnitGreatPersonActivated" ); end
OnUnitKilledInCombat		= function() OnLocalStatUpdateRequest( "OnUnitKilledInCombat" ); end
OnUnitRemovedFromMap		= function() OnLocalStatUpdateRequest( "OnUnitRemovedFromMap" ); end

-- ===========================================================================
function SubscribeYieldEvents()
	m_isYieldsSubscribed = true;
	
	Events.AnarchyBegins.Add( OnAnarchyBegins );
	Events.AnarchyEnds.Add( OnAnarchyEnds );
	Events.CityFocusChanged.Add( OnCityFocusChanged );
	Events.CityInitialized.Add( OnCityInitialized );			
	Events.CityProductionChanged.Add( OnCityProductionChanged );
	Events.CityWorkerChanged.Add( OnCityWorkerChanged );	
	Events.FaithChanged.Add( OnFaithChanged );
	Events.GovernmentChanged.Add( OnGovernmentChanged );
	Events.GovernmentPolicyChanged.Add( OnGovernmentPolicyChanged );
	Events.GovernmentPolicyObsoleted.Add( OnGovernmentPolicyObsoleted );
	Events.GreatWorkCreated.Add( OnGreatWorkCreated );
	Events.ImprovementAddedToMap.Add( OnImprovementAddedToMap );
	Events.ImprovementRemovedFromMap.Add( OnImprovementRemovedFromMap );
	Events.PantheonFounded.Add( OnPantheonFounded );
	Events.PlayerAgeChanged.Add( OnPlayerAgeChanged );
	Events.ResearchCompleted.Add( OnResearchCompleted );
	Events.TreasuryChanged.Add( OnTreasuryChanged );	
	Events.UnitAddedToMap.Add( OnUnitAddedToMap );
	Events.UnitGreatPersonActivated.Add( OnUnitGreatPersonActivated );
	Events.UnitKilledInCombat.Add( OnUnitKilledInCombat );
	Events.UnitRemovedFromMap.Add( OnUnitRemovedFromMap );
end

-- ===========================================================================
function UnsubscribeYieldEvents()
	m_isYieldsSubscribed = false;

	Events.AnarchyBegins.Remove( OnAnarchyBegins );
	Events.AnarchyEnds.Remove( OnAnarchyEnds );
	Events.CityFocusChanged.Remove( OnCityFocusChanged );
	Events.CityInitialized.Remove( OnCityInitialized );			
	Events.CityProductionChanged.Remove( OnCityProductionChanged );
	Events.CityWorkerChanged.Remove( OnCityWorkerChanged );	
	Events.FaithChanged.Remove( OnFaithChanged );
	Events.GovernmentChanged.Remove( OnGovernmentChanged );
	Events.GovernmentPolicyChanged.Remove( OnGovernmentPolicyChanged );
	Events.GovernmentPolicyObsoleted.Remove( OnGovernmentPolicyObsoleted );
	Events.GreatWorkCreated.Remove( OnGreatWorkCreated );
	Events.ImprovementAddedToMap.Remove( OnImprovementAddedToMap );
	Events.ImprovementRemovedFromMap.Remove( OnImprovementRemovedFromMap );
	Events.PantheonFounded.Remove( OnPantheonFounded );
	Events.PlayerAgeChanged.Remove( OnPlayerAgeChanged );
	Events.ResearchCompleted.Remove( OnResearchCompleted );
	Events.TreasuryChanged.Remove( OnTreasuryChanged );	
	Events.UnitAddedToMap.Remove( OnUnitAddedToMap );
	Events.UnitGreatPersonActivated.Remove( OnUnitGreatPersonActivated );
	Events.UnitKilledInCombat.Remove( OnUnitKilledInCombat );
	Events.UnitRemovedFromMap.Remove( OnUnitRemovedFromMap );
end

-- ===========================================================================
--	Only listen for events related to yield updates if they are showing.
-- ===========================================================================
function RealizeYieldEvents()
	if m_ribbonStats == RibbonHUDStats.HIDE then
		if m_isYieldsSubscribed==false then 
			return;									-- Already un-subscribed.
		end
		UnsubscribeYieldEvents();
	else
		if m_isYieldsSubscribed then return; end;	-- Already subscribed.
		SubscribeYieldEvents();
	end
end


-- ===========================================================================
--	CALLBACK
-- ===========================================================================
function OnShutdown()
	if m_isYieldsSubscribed then
		UnsubscribeYieldEvents();
	end

	Events.DiplomacyDeclareWar.Remove( OnDiplomacyWarStateChange ); 
	Events.DiplomacyMakePeace.Remove( OnDiplomacyWarStateChange ); 
	Events.DiplomacyMeet.Remove( OnDiplomacyMeet );
	Events.DiplomacyRelationshipChanged.Remove( UpdateLeaders ); 
	Events.DiplomacySessionClosed.Remove( OnDiplomacySessionClosed );
	Events.InterfaceModeChanged.Remove( OnInterfaceModeChanged );
	Events.LoadGameViewStateDone.Remove( OnLoadGameViewStateDone );
	Events.LocalPlayerChanged.Remove(UpdateLeaders);
	Events.LocalPlayerTurnBegin.Remove( OnLocalTurnBegin );
	Events.LocalPlayerTurnEnd.Remove( OnLocalTurnEnd );
	Events.MultiplayerPlayerConnected.Remove(UpdateLeaders);
	Events.MultiplayerPostPlayerDisconnected.Remove(UpdateLeaders);
	Events.PlayerInfoChanged.Remove(UpdateLeaders);
	Events.PlayerDefeat.Remove(UpdateLeaders);
	Events.PlayerRestored.Remove(UpdateLeaders);
	Events.PlayerIntroduced.Remove(UpdateLeaders);
	Events.RemotePlayerTurnBegin.Remove( OnTurnBegin );
	Events.RemotePlayerTurnEnd.Remove( OnTurnEnd );
	Events.SystemUpdateUI.Remove( OnUpdateUI );
	Events.UserOptionChanged.Remove( OnUserOptionChanged );	

	LuaEvents.ChatPanel_OnChatReceived.Remove(OnChatReceived);
	LuaEvents.EndGameMenu_StartObserverMode.Remove( OnStartObserverMode );
	LuaEvents.LaunchBar_Resize.Remove( OnLaunchBarResized );
	LuaEvents.PartialScreenHooks_Realize.Remove(RealizeSize);
	LuaEvents.WorldTracker_OnChatShown.Remove(OnChatPanelShown);

	Events.GameCoreEventPublishComplete.Remove( OnTimePasses );		-- 条目24：观察者轮播（与 LateInitialize 订阅对称）
end

-- ===========================================================================
function LateInitialize()
	RealizeYieldEvents();

	ContextPtr:SetRefreshHandler( OnRefresh );

	Controls.NextButton:RegisterCallback( Mouse.eLClick, OnScrollLeft );
	Controls.PreviousButton:RegisterCallback( Mouse.eLClick, OnScrollRight );
	Controls.LeaderScroll:SetScrollValue(1);

	Events.DiplomacyDeclareWar.Add( OnDiplomacyWarStateChange ); 
	Events.DiplomacyMakePeace.Add( OnDiplomacyWarStateChange ); 
	Events.DiplomacyMeet.Add( OnDiplomacyMeet );
	Events.DiplomacyRelationshipChanged.Add( UpdateLeaders ); 
	Events.DiplomacySessionClosed.Add( OnDiplomacySessionClosed );
	Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
	Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone );
	Events.LocalPlayerChanged.Add(UpdateLeaders);
	Events.LocalPlayerTurnBegin.Add( OnLocalTurnBegin );
	Events.LocalPlayerTurnEnd.Add( OnLocalTurnEnd );
	Events.MultiplayerPlayerConnected.Add(UpdateLeaders);
	Events.MultiplayerPostPlayerDisconnected.Add(UpdateLeaders);
	Events.PlayerInfoChanged.Add(UpdateLeaders);
	Events.PlayerDefeat.Add(UpdateLeaders);
	Events.PlayerRestored.Add(UpdateLeaders);
	Events.PlayerIntroduced.Add(UpdateLeaders);
	Events.RemotePlayerTurnBegin.Add( OnTurnBegin );
	Events.RemotePlayerTurnEnd.Add( OnTurnEnd );	
	Events.SystemUpdateUI.Add( OnUpdateUI );
	Events.UserOptionChanged.Add( OnUserOptionChanged );	

	Events.ResearchChanged.Add(function(playerID)
		if not m_TechCivisProgress then
			local uiLeader  = m_uiLeadersByID[playerID];
			if uiLeader ~= nil then
				UpdateStatValues( playerID, uiLeader );
				if not m_TechCivisProgress then
					RefreshTechMeter(playerID, uiLeader)
				end
			end
		end
	end);
	
	Events.CivicChanged.Add(function(playerID)
		if not m_TechCivisProgress then
			local uiLeader  = m_uiLeadersByID[playerID];
			if uiLeader ~= nil then
				UpdateStatValues( playerID, uiLeader );
				if not m_TechCivisProgress then
					RefreshCivisMeter(playerID, uiLeader)
				end
			end
		end
	end);

	LuaEvents.ChatPanel_OnChatReceived.Add(OnChatReceived);
	LuaEvents.EndGameMenu_StartObserverMode.Add( OnStartObserverMode );
	LuaEvents.LaunchBar_Resize.Add( OnLaunchBarResized );
	LuaEvents.PartialScreenHooks_Realize.Add(RealizeSize);
	LuaEvents.WorldTracker_OnChatShown.Add(OnChatPanelShown);
		
	if not BASE_LateInitialize then	-- Only update leaders if this is the last in the call chain.
		UpdateLeaders(true);
	end
end

-- ===========================================================================
function OnInit( isReload )
	LateInitialize();
	m_isIniting = false;

	local localPlayerID = Game.GetLocalPlayer();
	if localPlayerID ~= PlayerTypes.NONE and localPlayerID ~= PlayerTypes.OBSERVER and Players[localPlayerID]:IsTurnActive() then 
		OnLocalTurnBegin();
	end
end

-- ===========================================================================
--	Main Initialize
-- ===========================================================================
function Initialize()	
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
end
Initialize();


-- ===========================================================================
-- ex1
-- ===========================================================================
BASE_AddLeader = AddLeader;

-- ===========================================================================
function AddLeader(iconName , playerID , kProps)	
	local oLeaderIcon	 = BASE_AddLeader(iconName, playerID, kProps);
	local localPlayerID	 = Game.GetLocalPlayer();

	if localPlayerID == PlayerTypes.NONE or localPlayerID == PlayerTypes.OBSERVER then
		return;
	end

	if GameCapabilities.HasCapability("CAPABILITY_DISPLAY_HUD_RIBBON_RELATIONSHIPS") then
		-- Update relationship pip tool with details about our alliance if we're in one
		local localPlayerDiplomacy = Players[localPlayerID]:GetDiplomacy();
		if localPlayerDiplomacy then
			local allianceType = localPlayerDiplomacy:GetAllianceType(playerID);
			if allianceType ~= -1 then
				local allianceName = Locale.Lookup(GameInfo.Alliances[allianceType].Name);
				local allianceLevel = localPlayerDiplomacy:GetAllianceLevel(playerID);
				oLeaderIcon.Controls.Relationship:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_ALLIANCE_FLAG_TT", allianceName, allianceLevel));
			end
		end
	end

	return oLeaderIcon;
end

include("CongressButton");


-- ===========================================================================
-- ex2
-- ===========================================================================
BASE_LateInitialize = LateInitialize;
BASE_UpdateLeaders = UpdateLeaders;
BASE_RealizeSize = RealizeSize;
BASE_FinishAddingLeader = FinishAddingLeader;
BASE_UpdateStatValues = UpdateStatValues;


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_kCongressButtonIM	 = nil;
local m_oCongressButton		 = nil;
local m_congressButtonWidth	 = 0;


-- ===========================================================================
--	FUNCTIONS
-- ===========================================================================

-- ===========================================================================
-- 条目24优化：重建节流——DiplomacyRelationshipChanged 等事件在联机回合内高频触发，全量重建
--（ResetInstances+逐条目重加+逐行 SetText+测高）随之高频运行，且测高随文本布局时序波动 →
-- 高亮/列高高频抖动（用户实测）。0.25 秒冷却合并事件簇（重建为当前状态快照，丢弃重复触发安全）；
-- 用户即时操作（视图切换/设置广播/轮播翻转/初始构建）传 true 旁路
local m_nLastRebuildTime = -1;
function UpdateLeaders(bForce)
	if bForce ~= true then
		local tNow = UI.GetElapsedTime();
		if m_nLastRebuildTime >= 0 and (tNow - m_nLastRebuildTime) < 0.25 then
			return;
		end
		m_nLastRebuildTime = tNow;
	end
	-- Create and add World Congress button if one was allocated (based on capabilities)
	if m_kCongressButtonIM then
		if Game.GetEras():GetCurrentEra() >= GlobalParameters.WORLD_CONGRESS_INITIAL_ERA then		
			m_kCongressButtonIM:ResetInstances();
			local pPlayer = PlayerConfigurations[Game.GetLocalPlayer()];
			if(pPlayer ~= nil and pPlayer:IsAlive())then
				m_oCongressButton = CongressButton:GetInstance( m_kCongressButtonIM );
				m_congressButtonWidth = m_oCongressButton.Top:GetSizeX();
			else
				m_congressButtonWidth = 0;
			end
		end
	end

	-- ==== 条目24：观察者/组队排序分支（BSM 移植）====
	-- 场上有观察者或存在组队时，丝带排序走 BSM 四象限逻辑（观察者丝带显示全部玩家等）；
	-- 普通局保持 DPR 原排序（按相遇回合）。
	if bspec_game == true or MPT_HasTeamers() then
		if Game.GetLocalPlayer() == -1 then
			return;		-- 无本地玩家（自动演算/回放）不处理（原 BSM 早退语义）
		end
		MPT_UpdateLeadersObserver();
		return;
	end

	BASE_UpdateLeaders();	
end

-- ===========================================================================
--	OVERRIDE
-- ===========================================================================
function RealizeSize( additionalElementsWidth )			
	BASE_RealizeSize( m_congressButtonWidth );
	--The Congress button takes up one leader slot, so the max num of leaders used to calculate scroll is reduced by one in XP2	
	g_maxNumLeaders = g_maxNumLeaders - 1;
end

-- ===========================================================================
function OnLeaderClicked(playerID  )
	-- Send an event to open the leader in the diplomacy view (only if they met)
	local pWorldCongress = Game.GetWorldCongress();
	local localPlayerID = Game.GetLocalPlayer();

	-- ==== 条目24：观察者 POV 切换（BSM 移植）====
	-- 三个键名为 BSM 生态协议（其 gameplay 脚本监听 UIDoObserverPlayer 切换观察目标，
	-- worldtracker 等监听 DiplomacyRibbon_Click 刷新），勿改名。
	if bspec_loc == true then
		if UIEvents ~= nil and UIEvents.UIDoObserverPlayer ~= nil then
			UIEvents.UIDoObserverPlayer(playerID);
		end
		LuaEvents.DiplomacyRibbon_Click();
		GameConfiguration.SetValue("OBSERVER_ID_"..bspec_loc_id, playerID);
		return;
	end

	if localPlayerID == -1 or localPlayerID == 1000 then
		return;
	end

	if playerID == localPlayerID or Players[localPlayerID]:GetDiplomacy():HasMet(playerID) then
		if pWorldCongress:IsInSession() then
			LuaEvents.DiplomacyActionView_OpenLite(playerID);
		else
			LuaEvents.DiplomacyRibbon_OpenDiplomacyActionView(playerID);
		end
	end
end

-- ===========================================================================
function LateInitialize()

	-- ==== 条目24：观察者检测（BSM 移植，先于 BASE 初始化）====
	-- 顺手修复：原 BSM 检测循环内误用本地玩家（PlayerConfigurations[Game.GetLocalPlayer()]）的
	-- LeaderType 判断第 i 位玩家，导致「非观察者视角的观战局」恒不置位、其四象限排序分支成死代码；
	-- 此处改查 PlayerConfigurations[i]，非观察者也能正确识别观战局（观察者条目会被隐藏）。
	bspec_loc = false;
	bspec_game = false;
	m_first_spec_id = -1;
	local localPlayerID = Game.GetLocalPlayer();
	if localPlayerID ~= -1 and localPlayerID ~= nil then
		if PlayerConfigurations[localPlayerID] ~= nil and PlayerConfigurations[localPlayerID]:GetLeaderTypeName() == "LEADER_SPECTATOR" then
			bspec_loc = true;
			bspec_loc_id = localPlayerID;
		end
	end
	for i = 0, PlayerManager.GetWasEverAliveMajorsCount() - 1 do
		if Players[i]:IsAlive() == true and PlayerConfigurations[i] ~= nil then
			if PlayerConfigurations[i]:GetLeaderTypeName() == "LEADER_SPECTATOR" and m_first_spec_id == -1 then
				m_first_spec_id = i;
				bspec_game = true;
				break;
			end
		end
	end

	-- 条目24：BSM 协议桥（其 Data/Spectator.lua gameplay 侧把共享 LuaEvents 放入 ExposedMembers）
	if ExposedMembers ~= nil and ExposedMembers.LuaEvents ~= nil then
		UIEvents = ExposedMembers.LuaEvents;
	end

	BASE_LateInitialize();

	if GameCapabilities.HasCapability("CAPABILITY_WORLD_CONGRESS") then
		m_kCongressButtonIM = InstanceManager:new("CongressButton", "Top", Controls.LeaderStack);
	end

	-- 条目24：观察者轮播订阅（BSM 移植：每发布周期驱动 20 秒视图轮播）
	if bspec_loc == true then
		Events.GameCoreEventPublishComplete.Add(OnTimePasses);
	end

	if not XP2_LateInitialize then	-- Only update leaders if this is the last in the call chain.
		UpdateLeaders(true);
	end
end


-- ===========================================================================
--	条目24 分区：观察者与引擎精确加速（新增代码集中于本区，函数 MPT_ 前缀）
-- ===========================================================================

-- ===========================================================================
--	科文加速值：引擎精确定点链（条目14 TechAndCivicSupport 的 MPT_EngineBoost，Ghidra 反编译
--	复刻、39 组实测全对）+ DPR 的按目标玩家 modifier 附加加速。
--	旧代码（DPR 原始朴素公式，兜底分支保留）：boostAmount = ((basePct + extra) * .01);
--		Estimates 增量 = math.floor(math.max(cost * boostAmount - ((cost * boostAmount % 0.5 == 0) and 0.5 or 1), 0))
--	用法：MPT_GetBoostValue(playerID, cost, row.Boost, isTech) → 返回加速的绝对进度值
-- ===========================================================================
function MPT_GetBoostValue(playerID, cost, basePct, isTech)
	local extraBoost = GetExtraBoostFromModifiers(playerID, isTech);
	if MPT_EngineBoost ~= nil then
		return MPT_EngineBoost(cost, basePct, extraBoost);
	end
	local boostAmount = ((basePct + extraBoost) * .01);
	return math.floor(math.max(cost * boostAmount - ((cost * boostAmount % 0.5 == 0) and 0.5 or 1), 0));
end

-- ===========================================================================
--	是否存在组队（存活主要文明中有人不在「队伍号=玩家号」的默认队伍上）
-- ===========================================================================
function MPT_HasTeamers()
	for i = 0, PlayerManager.GetWasEverAliveMajorsCount() - 1 do
		if Players[i]:IsAlive() == true and Players[i]:GetTeam() ~= i then
			return true;
		end
	end
	return false;
end

-- ===========================================================================
--	观察者/组队局的丝带排序（BSM UpdateLeaders 四象限逻辑移植）：
--	  组队×有观察者×本地观察者	：逐队插入（跳过观察者队），主观察者插在其队伍位置
--	  组队×有观察者×本地非观察者	：自己 → 队友 → 主观察者 → 其余队伍（观察者条目由 FinishAddingLeader 隐藏）
--	  组队×无观察者				：自己 → 队友 → 其余
--	  FFA							：观察者自己排第一（观察者丝带显示全部玩家）；非观察者 = 自己 → 其余（排除观察者）
--	原 BSM 的 Game:GetLocalPlayer() 冒号笔误、循环内重复取本地玩家已顺手修正为 localPlayerID。
-- ===========================================================================
function MPT_UpdateLeadersObserver()
	local b_teamer = false
	local max_team = 0
	for i = 0, PlayerManager.GetWasEverAliveMajorsCount() - 1 do
		if Players[i]:IsAlive() == true then
			if Players[i]:GetTeam() ~= i then
				b_teamer = true
			end
			if Players[i]:GetTeam() > max_team then
				max_team = Players[i]:GetTeam()
			end
		end
	end

	ResetLeaders();
	m_ribbonStats = Options.GetUserOption("Interface", "RibbonStats");

	local kPlayers = PlayerManager.GetAliveMajors();
	local kMetPlayers = {};
	local kUniqueLeaders = {};
	local localPlayerID = Game.GetLocalPlayer();
	if localPlayerID ~= -1 then
		kMetPlayers, kUniqueLeaders = GetMetPlayersAndUniqueLeaders();
	else
		-- No local player so assume it's auto-playing; show everyone.
		for _, pPlayer in ipairs(kPlayers) do
			local playerID = pPlayer:GetID();
			kMetPlayers[ playerID ] = true;
			if (kUniqueLeaders[playerID] == nil) then
				kUniqueLeaders[playerID] = true;
			else
				kUniqueLeaders[playerID] = false;
			end
		end
	end

	local sortedPlayers = {}
	local m_spec_team = nil
	local first_team = 0
	local b_first_added = false
	local loc_team = nil

	if b_teamer == true then
		loc_team = Players[localPlayerID]:GetTeam()
		if bspec_game == true then
			m_spec_team = Players[m_first_spec_id]:GetTeam()
			if bspec_loc == true then
				loc_team = nil
				for i = 0, max_team do
					if b_first_added == false then
						for _, pPlayer in ipairs(kPlayers) do
							if pPlayer:GetTeam() == i and i ~= m_spec_team then
								table.insert(sortedPlayers, pPlayer)
								b_first_added = true
								first_team = i
							end
						end
					end
				end
				table.insert(sortedPlayers, Players[m_first_spec_id] )
				for i = first_team + 1, max_team do
					for _, pPlayer in ipairs(kPlayers) do
						if pPlayer:GetTeam() == i and i ~= m_spec_team then
							table.insert(sortedPlayers, pPlayer)
						end
					end
				end
			else
				table.insert(sortedPlayers, Players[localPlayerID] )
				loc_team = Players[localPlayerID]:GetTeam()
				for i = 0, PlayerManager.GetWasEverAliveMajorsCount() - 1 do
					if Players[i]:IsAlive() == true and Players[i]:GetTeam() == loc_team and i ~= localPlayerID then
						table.insert(sortedPlayers, Players[i] )
					end
				end
				table.insert(sortedPlayers, Players[m_first_spec_id] )
				for i = 0, PlayerManager.GetWasEverAliveMajorsCount() - 1 do
					if Players[i]:GetTeam() ~= loc_team and PlayerConfigurations[i]:GetLeaderTypeName() ~= "LEADER_SPECTATOR" and Players[i]:IsAlive() == true then
						table.insert(sortedPlayers, Players[i] )
					end
				end
			end
		else
			table.insert(sortedPlayers, Players[localPlayerID] )
			for i = 0, PlayerManager.GetWasEverAliveMajorsCount() - 1 do
				if Players[i]:IsAlive() == true and Players[i]:GetTeam() == loc_team and i ~= localPlayerID then
					table.insert(sortedPlayers, Players[i] )
				end
			end
			for i = 0, PlayerManager.GetWasEverAliveMajorsCount() - 1 do
				if Players[i]:GetTeam() ~= loc_team and Players[i]:IsAlive() == true then
					table.insert(sortedPlayers, Players[i] )
				end
			end
		end
	else
		if bspec_loc == true then
			table.insert(sortedPlayers, Players[m_first_spec_id] )
		else
			table.insert(sortedPlayers, Players[localPlayerID] )
		end
		for i = 0, PlayerManager.GetWasEverAliveMajorsCount() - 1 do
			if PlayerConfigurations[i]:GetLeaderTypeName() ~= "LEADER_SPECTATOR" and Players[i]:IsAlive() == true and i ~= localPlayerID then
				table.insert(sortedPlayers, Players[i] )
			end
		end
	end

	--Then, add the leader icons.
	for _, pPlayer in ipairs(sortedPlayers) do
		local playerID = pPlayer:GetID();
		if playerID ~= nil and Players[playerID] ~= nil then
			if(playerID ~= localPlayerID) then
				local isMet = kMetPlayers[playerID];
				local pPlayerConfig = PlayerConfigurations[playerID];
				local isHumanMP = (GameConfiguration.IsAnyMultiplayer() and pPlayerConfig:IsHuman());
				if (isMet or isHumanMP) then
					local leaderName = pPlayerConfig:GetLeaderTypeName();
					local isMasked = (isMet==false) and isHumanMP;	-- Multiplayer human but haven't met
					local isUnique = kUniqueLeaders[leaderName];
					local iconName = "ICON_LEADER_DEFAULT";
					-- If in an MP game and a player leaves the name returned will be NIL.
					if isMet and (leaderName ~= nil) then
						iconName = "ICON_"..leaderName;
					end
					AddLeader(iconName, playerID, { isMasked=isMasked, isUnique=isUnique });
				end
			else
				AddLeader("ICON_"..PlayerConfigurations[localPlayerID]:GetLeaderTypeName(), localPlayerID, {});
			end
		end
	end

	RealizeSize();
end

-- ===========================================================================
--	六视图切换按钮回调（BSM 移植；单选语义：再点同键取消回到轮播）
-- ===========================================================================
function MPT_OnScoreMouseClick()
	UI.PlaySound("Play_UI_Click");
	if b_score == true then b_score = false;
	else b_score = true; b_trees = false; b_eras = false; b_army = false; b_yield = false; b_accu = false; end
	UpdateLeaders(true)
end
function MPT_OnTreesMouseClick()
	UI.PlaySound("Play_UI_Click");
	if b_trees == true then b_trees = false;
	else b_score = false; b_trees = true; b_eras = false; b_army = false; b_yield = false; b_accu = false; end
	UpdateLeaders(true)
end
function MPT_OnErasMouseClick()
	UI.PlaySound("Play_UI_Click");
	if b_eras == true then b_eras = false;
	else b_score = false; b_trees = false; b_eras = true; b_army = false; b_yield = false; b_accu = false; end
	UpdateLeaders(true)
end
function MPT_OnArmyMouseClick()
	UI.PlaySound("Play_UI_Click");
	if b_army == true then b_army = false;
	else b_score = false; b_trees = false; b_eras = false; b_army = true; b_yield = false; b_accu = false; end
	UpdateLeaders(true)
end
function MPT_OnYieldMouseClick()
	UI.PlaySound("Play_UI_Click");
	if b_yield == true then b_yield = false;
	else b_score = false; b_trees = false; b_eras = false; b_army = false; b_yield = true; b_accu = false; end
	UpdateLeaders(true)
end
function MPT_OnTotalMouseClick()
	UI.PlaySound("Play_UI_Click");
	if b_accu == true then b_accu = false;
	else b_score = false; b_trees = false; b_eras = false; b_army = false; b_yield = false; b_accu = true; end
	UpdateLeaders(true)
end

-- ===========================================================================
--	观察者 20 秒轮播（BSM OnTimePasses 移植；仅观察者翻转相位，非观察者恒复位为统计行视图）
-- ===========================================================================
function OnTimePasses()
	-- 条目24优化：RealizeSize 移入翻转分支——本回调挂 GameCoreEventPublishComplete（联机每秒多次），
	-- 原每 tick 全丝带布局测高为高频无效开销；非翻转期无视觉变化无需重排
	if bspec_loc == false then
		b_hide = false
		b_hide_2 = true
		return
	end

	local currentTime = Automation.GetTime()
	if math.floor(currentTime - g_lasttime) > 20 then
		if b_hide == true then
			b_hide = false
			b_hide_2 = true
		else
			b_hide = true
			b_hide_2 = false
		end
		g_lasttime = currentTime
		RealizeSize();
		UpdateLeaders(true)
	end
end

-- ===========================================================================
--	观察者基础储量行的胜利/能力门槛（原 BSM L528-534），同时复位组合1组内 6 行的个别显隐
--	（Army 视图等会个别隐藏组内行，切换回基础视图时经本函数恢复；门槛本身为整局静态）
-- ===========================================================================
function MPT_ApplyCapabilityGates(playerID, uiLeader, isMasked)
	local isHideMilitary = isMasked or (not Game.IsVictoryEnabled("VICTORY_CONQUEST") or not GameCapabilities.HasCapability("CAPABILITY_DISPLAY_TOP_PANEL_YIELDS"));
	local isHideScience = isMasked or (not GameCapabilities.HasCapability("CAPABILITY_SCIENCE") or not GameCapabilities.HasCapability("CAPABILITY_DISPLAY_TOP_PANEL_YIELDS"));
	local isHideCulture = isMasked or (not GameCapabilities.HasCapability("CAPABILITY_CULTURE") or not GameCapabilities.HasCapability("CAPABILITY_DISPLAY_TOP_PANEL_YIELDS"));
	local isHideGold = isMasked or (not GameCapabilities.HasCapability("CAPABILITY_GOLD") or not GameCapabilities.HasCapability("CAPABILITY_DISPLAY_TOP_PANEL_YIELDS"));
	local isHideFaith = isMasked or (not GameCapabilities.HasCapability("CAPABILITY_RELIGION") or not GameCapabilities.HasCapability("CAPABILITY_DISPLAY_TOP_PANEL_YIELDS"));
	local isHideFavor = isMasked or (not Game.IsVictoryEnabled("VICTORY_DIPLOMATIC"));
	uiLeader.Military:SetHide(isHideMilitary);
	uiLeader.Science:SetHide(isHideScience);
	uiLeader.Culture:SetHide(isHideCulture);
	uiLeader.Gold:SetHide(isHideGold);
	uiLeader.Faith:SetHide(isHideFaith);
	uiLeader.Favor:SetHide(isHideFavor);
end

-- ===========================================================================
--	本地观察者视角的条目显隐（BSM FinishAddingLeader L527-938 逐控件版 → 组架构映射）：
--	  六视图（主观察者条目上的 SpecControl_1..6 切换，单选）：
--	    Score → Score+组合1 | Techs → 科文仪表组 | Eras → 政体/城市/时代/时代分
--	    Army → 军力+陆海空/战略/核弹 | Yield → 组合2+毛产补充行 | Total → 累计四行
--	  无视图选中 → 20 秒轮播：b_hide（Score+组合1）↔ b_hide_2（科文仪表），恒互补
--	观察者条目（SPECTATOR，非主观察者）只显示 Observer 标识；徽记仅非观察者条目显示。
-- ===========================================================================
function MPT_RealizeObserverView(playerID, uiLeader, isMasked, bIsSpec, bmasterspec)
	-- 基线：全部行组隐藏（原 BSM 每分支重复 40+ 行 SetHide → 基线 + 按视图点亮）
	uiLeader.Score:SetHide(true);
	uiLeader.Group_Stock:SetHide(true);
	uiLeader.Group_Rate:SetHide(true);
	uiLeader.Group_TechCivis:SetHide(true);
	uiLeader.Group_SpecEras:SetHide(true);
	uiLeader.Group_SpecArmy:SetHide(true);
	uiLeader.Group_SpecYield:SetHide(true);
	uiLeader.Group_SpecTotal:SetHide(true);
	uiLeader.SpecTag:SetHide(true);
	uiLeader.SpecData:SetHide(true);

	-- 徽记（原 BSM L540-559）：观察者条目不显示
	if bIsSpec == false and PlayerConfigurations[playerID] ~= nil and PlayerConfigurations[playerID]:GetCivilizationTypeName() ~= nil then
		uiLeader.Logo:SetIcon("ICON_"..PlayerConfigurations[playerID]:GetCivilizationTypeName());
		local primaryColor, secondaryColor = UI.GetPlayerColors( playerID );
		if primaryColor == nil then
			primaryColor = UI.GetColorValueFromHexLiteral(0xff99aaaa);
		end
		if secondaryColor == nil then
			secondaryColor = UI.GetColorValueFromHexLiteral(0xffaa9999);
		end
		uiLeader.LogoCircle:SetColor(primaryColor);
		uiLeader.Logo:SetColor(secondaryColor);
		uiLeader.LogoContainer:SetHide(false);
	else
		uiLeader.LogoContainer:SetHide(true);
	end

	-- 观察者条目与其余条目：观察者组常亮（承载 SpecTag/SpecControl 与视图子组）。
	-- SpecData 显隐完全归 UpdateStatValues（每次刷新两分支都显式 SetHide）——条目24优化：删除此处的
	-- 无条件 unhide（原每轮 unhide→UpdateStatValues 再 hide 的翻转是无谓布局抖动源）
	uiLeader.Group_Observer:SetHide(false);

	-- SpecControl 六视图按钮：仅主观察者条目可点（原 BSM L588-641）；按钮文案走本地化（条目24修复）
	local bCtrlVis = bmasterspec and (not isMasked);
	if uiLeader.SpecControl_1 ~= nil then
		uiLeader.SpecControl_1:SetHide(not bCtrlVis);
		uiLeader.SpecControl_1:RegisterCallback( Mouse.eLClick, MPT_OnScoreMouseClick);
		if b_score == true then uiLeader.SpecControl_1:SetText("[COLOR_Green]"..SpecStr_Score.."[ENDCOLOR]"); else uiLeader.SpecControl_1:SetText(SpecStr_Score); end

		uiLeader.SpecControl_2:SetHide(not bCtrlVis);
		uiLeader.SpecControl_2:RegisterCallback( Mouse.eLClick, MPT_OnTreesMouseClick);
		if b_trees == true then uiLeader.SpecControl_2:SetText("[COLOR_Green]"..SpecStr_Techs.."[ENDCOLOR]"); else uiLeader.SpecControl_2:SetText(SpecStr_Techs); end

		uiLeader.SpecControl_3:SetHide(not bCtrlVis);
		uiLeader.SpecControl_3:RegisterCallback( Mouse.eLClick, MPT_OnErasMouseClick);
		if b_eras == true then uiLeader.SpecControl_3:SetText("[COLOR_Green]"..SpecStr_Eras.."[ENDCOLOR]"); else uiLeader.SpecControl_3:SetText(SpecStr_Eras); end

		uiLeader.SpecControl_4:SetHide(not bCtrlVis);
		uiLeader.SpecControl_4:RegisterCallback( Mouse.eLClick, MPT_OnArmyMouseClick);
		if b_army == true then uiLeader.SpecControl_4:SetText("[COLOR_Green]"..SpecStr_Army.."[ENDCOLOR]"); else uiLeader.SpecControl_4:SetText(SpecStr_Army); end

		uiLeader.SpecControl_5:SetHide(not bCtrlVis);
		uiLeader.SpecControl_5:RegisterCallback( Mouse.eLClick, MPT_OnYieldMouseClick);
		if b_yield == true then uiLeader.SpecControl_5:SetText("[COLOR_Green]"..SpecStr_Yield.."[ENDCOLOR]"); else uiLeader.SpecControl_5:SetText(SpecStr_Yield); end

		uiLeader.SpecControl_6:SetHide(not bCtrlVis);
		uiLeader.SpecControl_6:RegisterCallback( Mouse.eLClick, MPT_OnTotalMouseClick);
		if b_accu == true then uiLeader.SpecControl_6:SetText("[COLOR_Green]"..SpecStr_Total.."[ENDCOLOR]"); else uiLeader.SpecControl_6:SetText(SpecStr_Total); end
	end

	-- 观察者条目（SPECTATOR 槽位）：显示 Observer 标识后早退，统计行保持基线全隐。
	-- 主观察者条目本身就是观察者条目——SpecControl 绑定必须在此早退之前（见上），否则按钮永不出现。
	if bIsSpec == true then
		uiLeader.SpecTag:SetHide(false);
		return;
	end

	-- 按当前视图点亮对应组（原 BSM 六大 if 块 → 组级映射）
	if b_score == true then
		-- Score 视图：基础储量行
		uiLeader.Score:SetHide(isMasked or not Game.IsVictoryEnabled("VICTORY_SCORE") or not GameCapabilities.HasCapability("CAPABILITY_DISPLAY_SCORE"));
		uiLeader.Group_Stock:SetHide(isMasked);
		MPT_ApplyCapabilityGates(playerID, uiLeader, isMasked);
	elseif b_trees == true then
		-- Techs 视图：科文仪表
		uiLeader.Group_TechCivis:SetHide(isMasked);
	elseif b_eras == true then
		-- Eras 视图：政体/城市数人口/时代/时代分
		uiLeader.Group_SpecEras:SetHide(isMasked);
	elseif b_army == true then
		-- Army 视图：军力 + 单位组（军力行在组合1组内——亮组、隐其余 5 行，特例保留个别 SetHide）
		uiLeader.Group_Stock:SetHide(isMasked);
		uiLeader.Military:SetHide(isMasked or not Game.IsVictoryEnabled("VICTORY_CONQUEST") or not GameCapabilities.HasCapability("CAPABILITY_DISPLAY_TOP_PANEL_YIELDS"));
		uiLeader.Science:SetHide(true);
		uiLeader.Culture:SetHide(true);
		uiLeader.Gold:SetHide(true);
		uiLeader.Faith:SetHide(true);
		uiLeader.Favor:SetHide(true);
		uiLeader.Group_SpecArmy:SetHide(isMasked);
	elseif b_yield == true then
		-- Yield 视图：DPR 组合2 产出行 + 毛粮补充行（样式以 DPR 为准；原 BSM 的 Science/Culture 行由 Score 视图承担）
		-- 条目24修复：毛产 Cities_Prod 与 DPR 生产力总量（GetProduction 同 API 同求和）恒等值，产出视图重复两行
		--（用户截图「错误的显示」），移出视图只留毛粮（余粮为净剩余、毛粮为城市毛产出和，两者不同）
		uiLeader.Group_Rate:SetHide(isMasked);
		uiLeader.Group_SpecYield:SetHide(false);
		uiLeader.Cities_Prod:SetHide(true);
		uiLeader.Cities_Food:SetHide(isMasked);
	elseif b_accu == true then
		-- Total 视图：累计产出（REPLAYDATASET）
		uiLeader.Group_SpecTotal:SetHide(isMasked);
	else
		-- 默认：20 秒轮播（b_hide 基础行 ↔ b_hide_2 仪表，恒互补翻转）
		if b_hide == false then
			uiLeader.Score:SetHide(isMasked or not Game.IsVictoryEnabled("VICTORY_SCORE") or not GameCapabilities.HasCapability("CAPABILITY_DISPLAY_SCORE"));
			uiLeader.Group_Stock:SetHide(isMasked);
			MPT_ApplyCapabilityGates(playerID, uiLeader, isMasked);
		end
		if b_hide_2 == false then
			uiLeader.Group_TechCivis:SetHide(isMasked);
		end
	end
end