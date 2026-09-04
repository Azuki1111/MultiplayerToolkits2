-- Copyright 2019, Firaxis Games
-- ============================================================================
-- 条目32：万神殿面板增强（BPC，移植 1.65 BPC/UI/PantheonChooser_TPT.lua）
-- 整文件替换原版 Choosers/PantheonChooser.lua（ReplaceUIScript 100000 + ImportFiles 100010，XML 同名覆盖）。
-- 相对原版两点增强：
--   ①名册全量列出 + 被抢信条置灰：原版只列「当前可选」信条，联机中他人先选走的完全不可见；
--     现全量列出万神殿信条，已入某万神殿/宗教的置灰禁用，且他人成立万神殿瞬间（Events.PantheonFounded）
--     实时禁用对应按钮——正选中的信条被抢则取消选中并收缩回未选状态。
--   ②「万神殿不排队」（高级选项 NO_WAIT_PANTHEON，沿用 1.65 原 key，默认关）：信仰一够立即从
--     通知栏弹「可以创立万神殿」提醒，点击打开本面板（条目32优化，用户裁决废止自动弹面板——
--     改从 NotificationPanel 提醒，见同目录 NotificationPanel_MPT_Pantheon.lua）；本文件仅保留
--     宗教按钮点击时的直接重定向（点击属显式意图，绕过原版 LaunchBar 的 CanCreatePantheon() 排队门控）。
-- 相对 1.65 三处修复/规约：
--   ①MPT_OnPantheonFounded 补实例缓存 nil 守卫（面板从未打开时事件先到，1.65 直接索引缓存表会报错）；
--   ②万神殿底价 GetMinimumFaithNextPantheon 改判定时实时查询（1.65 在文件载入时快照——联机中他人
--     陆续成立万神殿会抬高底价，快照失真导致信仰不足也误弹面板）；
--   ③OnShutdown 补齐 PantheonFounded/FaithChanged/LaunchBar_OpenReligionPanel 注销（1.65 泄漏）；
--     新增标识符一律 MPT_ 前缀，原版函数名保持原名（整文件替换，按原名解析）。
-- ============================================================================

include("InstanceManager");

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================

local SIZE_BELIEF_ICON_LARGE					:number = 64;
local BELIEFS_PANEL_RELATIVE_SIZE_UNSELECTED	:number = -236;
local BELIEFS_PANEL_RELATIVE_SIZE_SELECTED		:number = -326;

local DATA_FIELD_BELIEF_INDEX:string = "DataField_BeliefIndex";

-- ============================================================================
-- 条目32：万神殿不排队开关（高级选项 NO_WAIT_PANTHEON，沿用 1.65 原 key，默认关；
-- 仅门控「不排队」——条目32优化后本文件仅宗教按钮重定向，信仰够的通知提醒见同目录
-- NotificationPanel_MPT_Pantheon.lua；名册全量+被抢置灰恒启用）与信条按钮实例缓存
-- （row → instance，供 MPT_OnPantheonFounded 实时禁用，每次 Realize 全量重建）。
-- 旧代码：无（1.65 的 iPantheonFaith 载入时快照已废，改 MPT_CheckPantheon 判定时实时查询）
-- ----
local MPT_NoWaitPantheonInUse:boolean = GameConfiguration.GetValue("NO_WAIT_PANTHEON");
local MPT_InstanceButton:table = {};

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_pSelectBeliefsIM:table = InstanceManager:new("BeliefSlot", "BeliefButton", Controls.BeliftStack);

local m_pGameReligion:table = Game.GetReligion();

local m_uiSelectedBeliefInstance:table = nil;

-- ============================================================================
-- 条目32：原版 Realize 只列「当前可选」信条（旧代码整块保留）：
-- for row in GameInfo.Beliefs() do
-- 	if CanSelectBelief(row) then
-- 		local beliefInst:table = m_pSelectBeliefsIM:GetInstance();
-- 		beliefInst[DATA_FIELD_BELIEF_INDEX] = row.Index;
-- 		beliefInst.BeliefLabel:LocalizeAndSetText(Locale.ToUpper(row.Name));
-- 		beliefInst.BeliefDescription:LocalizeAndSetText(row.Description);
-- 		SetBeliefIcon(beliefInst.BeliefIcon, row.BeliefType, SIZE_BELIEF_ICON_LARGE);
-- 		beliefInst.BeliefButton:SetSelected(beliefInst == m_uiSelectedBeliefInstance);
-- 		beliefInst.BeliefButton:RegisterCallback( Mouse.eLClick, function() OnBeliefSelected(beliefInst); end );
-- 		beliefInst.BeliefButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end );
-- 	end
-- end
-- 现全量列出万神殿信条（MPT_IsBelief 过滤类别），已被选走（已入某万神殿/宗教）的保留占位并
-- 置灰禁用，同时缓存实例供 MPT_OnPantheonFounded 在他人成立万神殿时实时禁用。
-- ----
function Realize()

	-- Update available pantheon beliefs
	m_pSelectBeliefsIM:ResetInstances();
	for row in GameInfo.Beliefs() do
		if MPT_IsBelief(row) then
			local beliefInst:table = m_pSelectBeliefsIM:GetInstance();
			beliefInst[DATA_FIELD_BELIEF_INDEX] = row.Index;
			beliefInst.BeliefLabel:LocalizeAndSetText(Locale.ToUpper(row.Name));
			beliefInst.BeliefDescription:LocalizeAndSetText(row.Description);
			SetBeliefIcon(beliefInst.BeliefIcon, row.BeliefType, SIZE_BELIEF_ICON_LARGE);
			beliefInst.BeliefButton:SetSelected(beliefInst == m_uiSelectedBeliefInstance);
			beliefInst.BeliefButton:RegisterCallback( Mouse.eLClick, function() OnBeliefSelected(beliefInst); end );
			beliefInst.BeliefButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end );
			beliefInst.BeliefButton:SetDisabled( not CanSelectBelief(row) );		-- 条目32：已被他人选走（已入某万神殿/宗教）的信条置灰禁用
			MPT_InstanceButton[row] = beliefInst;								-- 条目32：缓存实例，供 MPT_OnPantheonFounded 实时禁用
		end
	end

	RealizeCurrentSelection();
end

-- ===========================================================================
function RealizeCurrentSelection()
	if m_uiSelectedBeliefInstance == nil then
		Controls.ReligionOrPatheonTitle:SetText(Locale.ToUpper("LOC_UI_RELIGION_CHOOSING_PANTHEON"));
		Controls.SelectedBeliefGrid:SetHide(true);

		Controls.ConfirmGrid:SetHide(true);
		Controls.BottomGrid:SetParentRelativeSizeY(BELIEFS_PANEL_RELATIVE_SIZE_UNSELECTED);
	else
		local kBeliefDef:table = GameInfo.Beliefs[m_uiSelectedBeliefInstance[DATA_FIELD_BELIEF_INDEX]];
		Controls.ReligionOrPatheonTitle:SetText(Locale.ToUpper(Locale.Lookup("LOC_UI_RELIGION_PANTHEON_NAME", kBeliefDef.Name)));
	
		-- Show selected belief
		Controls.SelectedBeliefLabel:LocalizeAndSetText(Locale.ToUpper(kBeliefDef.Name));
		Controls.SelectedBeliefDescription:LocalizeAndSetText(kBeliefDef.Description);
		SetBeliefIcon(Controls.SelectedBeliefIcon, kBeliefDef.BeliefType, SIZE_BELIEF_ICON_LARGE);
		Controls.SelectedBeliefGrid:SetHide(false);

		Controls.ConfirmGrid:SetHide(false);
		Controls.BottomGrid:SetParentRelativeSizeY(BELIEFS_PANEL_RELATIVE_SIZE_SELECTED);
	end
end

-- ============================================================================
-- 条目32：万神殿信条类别过滤（从原版 CanSelectBelief 拆出——Realize 需全量列出万神殿信条，
-- CanSelectBelief 只答「当前可选」（额外排除已入万神殿/宗教），两判定语义不同不可混用）
function MPT_IsBelief( kBeliefDef:table )
	if kBeliefDef.BeliefClassType == "BELIEF_CLASS_PANTHEON" then
		return true;
	end
	return false;
end

-- ===========================================================================
function CanSelectBelief( kBeliefDef:table )
	if (not m_pGameReligion:IsInSomePantheon(kBeliefDef.Index) and
		not m_pGameReligion:IsInSomeReligion(kBeliefDef.Index) and
		kBeliefDef.BeliefClassType == "BELIEF_CLASS_PANTHEON") then
		return true;
	end

	return false;
end

-- ============================================================================
-- 条目32：他人成立万神殿瞬间实时刷新名册（联机核心——面板开着时信条可能刚被别人选走，
-- 原版开面板期间名册永不更新，点被抢信条=操作静默失败须重开面板）。
-- 被抢信条按钮置灰禁用；正选中的信条被抢则 ClearBeliefSelection 取消选中并收缩回未选状态。
-- 1.65 修复：补 MPT_InstanceButton[row] nil 守卫——面板从未打开（Realize 未执行）时事件先到，
-- 1.65 直接索引缓存表会报错中断本处理器。
function MPT_OnPantheonFounded()
	for row in GameInfo.Beliefs() do
		if MPT_IsBelief(row) and not CanSelectBelief(row) then
			local beliefInst:table = MPT_InstanceButton[row];
			if beliefInst ~= nil then
				if m_uiSelectedBeliefInstance == beliefInst then
					ClearBeliefSelection();
				end
				beliefInst.BeliefButton:SetDisabled(true);
			end
		end
	end
end

-- ===========================================================================
function SetBeliefIcon(targetControl:table, beliefType:string, iconSize:number)
	local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas("ICON_" .. beliefType, iconSize);
	if(textureSheet == nil or textureSheet == "") then
		error("Could not find icon in SetBeliefIcon: beliefType=\""..beliefType.."\", iconSize="..tostring(iconSize) );
	else
		targetControl:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
		targetControl:SetSizeVal(iconSize, iconSize);
	end
end

-- ===========================================================================
function OnBeliefSelected( instance:table )
	-- Ignore select if this belief is already selected
	if m_uiSelectedBeliefInstance == instance then
		return;
	end
	
	SetSelectedBeliefInstance(instance);
end

-- ===========================================================================
function SetSelectedBeliefInstance( instance:table )
	-- Unselect the previous selection
	if m_uiSelectedBeliefInstance ~= nil then
		m_uiSelectedBeliefInstance.BeliefButton:SetSelected(false);
	end

	-- Select new belief instance
	m_uiSelectedBeliefInstance = instance;
	m_uiSelectedBeliefInstance.BeliefButton:SetSelected(true);

	RealizeCurrentSelection();
end

-- ===========================================================================
function ClearBeliefSelection()
	if m_uiSelectedBeliefInstance ~= nil then
		m_uiSelectedBeliefInstance.BeliefButton:SetSelected(false);
		m_uiSelectedBeliefInstance = nil;
	end

	RealizeCurrentSelection();
end

-- ===========================================================================
function ConfirmPantheon()
	if m_uiSelectedBeliefInstance ~= nil then
		local beliefIndex:number = m_uiSelectedBeliefInstance[DATA_FIELD_BELIEF_INDEX];

		local tParameters:table = {};
		tParameters[PlayerOperations.PARAM_BELIEF_TYPE] = GameInfo.Beliefs[beliefIndex].Hash;
		tParameters[PlayerOperations.PARAM_INSERT_MODE] = PlayerOperations.VALUE_EXCLUSIVE;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.FOUND_PANTHEON, tParameters);
		UI.PlaySound("Confirm_Religion");

		Close();

		LuaEvents.PantheonChooser_OpenReligionPanel();
	end
end

-- ===========================================================================
function Close()
	if not ContextPtr:IsHidden() and not Controls.PantheonChooserSlideAnim:IsReversing() then
		Controls.PantheonChooserSlideAnim:SetToEnd();
        Controls.PantheonChooserSlideAnim:Reverse();

		UI.PlaySound("Tech_Tray_Slide_Closed");

        LuaEvents.PantheonChooser_CloseReligion();
	end
end

-- ===========================================================================
function Open()
	if ContextPtr:IsHidden() then
		ContextPtr:SetHide(false);
        m_uiSelectedBeliefInstance = nil;

        LuaEvents.PantheonChooser_OpenReligion();

		-- Play Open Animation
		Controls.PantheonChooserSlideAnim:SetToBeginning();
		Controls.PantheonChooserSlideAnim:Play();

		UI.PlaySound("Tech_Tray_Slide_Open");

		Realize();
	end
end

-- ============================================================================
-- 条目32：万神殿不排队——条目32优化后仅剩宗教按钮点击重定向：信仰够时点宗教按钮直接
-- 打开本面板（点击属显式意图，绕过引擎排队门控）；信仰够的「通知提醒」见同目录
-- NotificationPanel_MPT_Pantheon.lua（自动弹面板已按用户裁决废止）。
-- 触发源：仅 LuaEvents.LaunchBar_OpenReligionPanel；本地已成立万神殿后注销。
-- 1.65 修复保留：底价改判定时实时查询——1.65 在文件载入时快照 GetMinimumFaithNextPantheon，
-- 联机中他人陆续成立万神殿会抬高底价，快照失真导致信仰不足也误重定向。
function MPT_CheckPantheon()
	local localPlayer:number = Game.GetLocalPlayer();
	if localPlayer < 0 then
		return;
	end
	local playerReligion:table = Players[localPlayer]:GetReligion();
	if playerReligion == nil then
		return;
	end
	if playerReligion:GetPantheon() >= 0 then
		-- 已成立万神殿：注销触发源
		LuaEvents.LaunchBar_OpenReligionPanel.Remove( MPT_CheckPantheon );
		return;
	end
	if playerReligion:GetFaithBalance() >= Game.GetReligion():GetMinimumFaithNextPantheon() then
		LuaEvents.LaunchBar_CloseReligionPanel();
		LuaEvents.LaunchBar_OpenPantheonChooser();
	end
end
-- ----

-- ===========================================================================
-- Context Event
-- ===========================================================================
function OnInit( isReload:boolean )
	LateInitialize();

	if isReload and not ContextPtr:IsHidden() then
		Realize();
	end
end

-- ===========================================================================
-- Context Event
-- ===========================================================================
function OnInputHandler( pInputStruct:table )
	if pInputStruct:GetMessageType() == KeyEvents.KeyUp and pInputStruct:GetKey() == Keys.VK_ESCAPE then 
		Close();
		return true;
	end
	return false;
end

-- ===========================================================================
-- Context Event
-- ===========================================================================
function OnShutdown()
	LuaEvents.NotificationPanel_OpenPantheonChooser.Remove( Open );
	LuaEvents.LaunchBar_OpenPantheonChooser.Remove( Open );
	LuaEvents.LaunchBar_ClosePantheonChooser.Remove( Close );

	-- ============================================================================
	-- 条目32：注销名册实时禁用与宗教按钮重定向处理器（1.65 泄漏未注销；
	-- FaithChanged 订阅已随条目32优化废止——通知提醒改在 NotificationPanel 上下文）
	Events.PantheonFounded.Remove( MPT_OnPantheonFounded );
	LuaEvents.LaunchBar_OpenReligionPanel.Remove( MPT_CheckPantheon );
	-- ----
end

-- ===========================================================================
function OnAnimEnd()
	if Controls.PantheonChooserSlideAnim:IsReversing() then
		-- If we're reversing due to closing the panel then hide the context after that anim ends
		ContextPtr:SetHide(true);
	end
end

-- ===========================================================================
function LateInitialize()
	LuaEvents.NotificationPanel_OpenPantheonChooser.Add( Open );
	LuaEvents.LaunchBar_OpenPantheonChooser.Add( Open );
	LuaEvents.LaunchBar_ClosePantheonChooser.Add( Close );

	Controls.Header_CloseButton:RegisterCallback( Mouse.eLClick, Close );

	Controls.SelectedBeliefGrid:RegisterCallback( Mouse.eLClick, ClearBeliefSelection );
	Controls.ConfirmPantheonButton:RegisterCallback( Mouse.eLClick, ConfirmPantheon );
	Controls.ConfirmPantheonButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end); 
	Controls.CancelButton:RegisterCallback( Mouse.eLClick, ClearBeliefSelection );
	Controls.CancelButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end); 

	Controls.PantheonChooserSlideAnim:RegisterEndCallback( OnAnimEnd );

	-- ============================================================================
	-- 条目32：他人成立万神殿 → 实时禁用被抢信条；「万神殿不排队」开启时挂宗教按钮点击
	-- 重定向（信仰够的自动评估已随条目32优化移出——通知提醒见 NotificationPanel_MPT_Pantheon.lua）
	Events.PantheonFounded.Add( MPT_OnPantheonFounded );
	if MPT_NoWaitPantheonInUse then
		LuaEvents.LaunchBar_OpenReligionPanel.Add( MPT_CheckPantheon );
	end
	-- ----
end

-- ===========================================================================
function Initialize()
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );
	ContextPtr:SetInputHandler( OnInputHandler, true );
end
Initialize();
