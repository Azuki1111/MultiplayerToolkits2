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
-- 条目32扩展：信条搜索框（移植工坊 3499859427 Team PVP 万神殿选择器 By 千川白浪）——顶部
--   搜索框按信条名/描述关键词过滤名册（大小写不敏感子串，条目3.9 同款 plain 匹配零模式转义
--   问题），命中段浅蓝高亮，无结果显示提示；原生集成（XML 直加搜索框控件 + 本文件过滤重建）
--   替代源 mod 的 LookUpControl 跨上下文注入 + 镜像列表层方案；选中实例跨过滤重建按 Index
--   重绑（IM 回收仅隐藏不销毁，旧引用安全）；恒启用（名册体验增强，不挂 NO_WAIT_PANTHEON 开关）。
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

-- ============================================================================
-- 条目32扩展：信条搜索状态（当前关键词，string.upper 归一——大小写不敏感匹配；
-- EditBox 文本变化回调更新并触发 Realize 过滤重建；占位文本为 XML String 属性不预加载）
-- ----
local MPT_SearchText:string = "";
-- ----

-- ===========================================================================
--	VARIABLES
-- ===========================================================================

local m_pSelectBeliefsIM:table = InstanceManager:new("BeliefSlot", "BeliefButton", Controls.BeliftStack);

local m_pGameReligion:table = Game.GetReligion();

local m_uiSelectedBeliefInstance:table = nil;

-- ============================================================================
-- 条目32扩展：搜索匹配与高亮（条目3.9 MPT_LeaderSearch_Highlight 同款算法移植）——
-- plain=true 字面匹配无模式转义问题（源 mod 的 string.find/gsub 裸 pattern 输入
-- %.( 等魔法字符会崩，本实现修复），匹配边界由同一字节串的 find 得出，UTF-8 多字节
-- 序列不会被截断；命中段 [COLOR_LIGHTBLUE] 浅蓝包裹，无搜索/无命中返回原文本。
-- -------------------------------------------------
-- MPT_PantheonSearch_Highlight( sText : string ) : string——按 MPT_SearchText 高亮
-- 用法：Realize 内信条名/描述文本写入前包裹
-- -------------------------------------------------
-- MPT_MatchesBeliefSearch( kBeliefDef : table ) : boolean——信条名/描述（本地化后）
-- 任一命中当前关键词即 true；空搜索恒 true（全量显示）
-- 用法：Realize 过滤条件
-- ============================================================================
function MPT_PantheonSearch_Highlight( sText:string )
	if (MPT_SearchText == "" or sText == nil or sText == "") then
		return sText;
	end
	local sNeedle:string = MPT_SearchText;
	local sHaystack:string = string.upper(sText);
	local tParts:table = {};
	local nCursor:number = 1;
	local nStart, nEnd = string.find(sHaystack, sNeedle, nCursor, true);
	while (nStart ~= nil) do
		table.insert(tParts, string.sub(sText, nCursor, nStart - 1));
		table.insert(tParts, "[COLOR_LIGHTBLUE]" .. string.sub(sText, nStart, nEnd) .. "[ENDCOLOR]");
		nCursor = nEnd + 1;
		nStart, nEnd = string.find(sHaystack, sNeedle, nCursor, true);
	end
	if (nCursor == 1) then
		return sText;
	end
	table.insert(tParts, string.sub(sText, nCursor));
	return table.concat(tParts);
end

function MPT_MatchesBeliefSearch( kBeliefDef:table )
	if MPT_SearchText == "" then
		return true;
	end
	local sName:string = string.upper(Locale.Lookup(kBeliefDef.Name) or "");
	local sDesc:string = string.upper(Locale.Lookup(kBeliefDef.Description) or "");
	return string.find(sName, MPT_SearchText, 1, true) ~= nil or string.find(sDesc, MPT_SearchText, 1, true) ~= nil;
end

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
-- 条目32扩展：过滤条件加 MPT_MatchesBeliefSearch（搜索关键词过滤），文本写入改
-- MPT_PantheonSearch_Highlight 包裹（命中段高亮）；选中实例跨重建按 Index 重绑——
-- 搜索过滤后选中信条仍在结果中则恢复选中显示，被过滤掉则保留选中数据（确认按钮仍可用，
-- 换选时对旧隐藏实例 SetSelected 安全：IM 回收仅隐藏不销毁）；重建后按结果数刷新无匹配提示。
-- ----
function Realize()

	-- Update available pantheon beliefs
	m_pSelectBeliefsIM:ResetInstances();

	-- 条目32扩展：选中实例重绑锚点（重建前记录选中 Index）
	local m_iSelectedIndex:number = nil;
	if m_uiSelectedBeliefInstance ~= nil then
		m_iSelectedIndex = m_uiSelectedBeliefInstance[DATA_FIELD_BELIEF_INDEX];
	end

	local instanceCount:number = 0;
	for row in GameInfo.Beliefs() do
		if MPT_IsBelief(row) and MPT_MatchesBeliefSearch(row) then
			local beliefInst:table = m_pSelectBeliefsIM:GetInstance();
			beliefInst[DATA_FIELD_BELIEF_INDEX] = row.Index;
			beliefInst.BeliefLabel:LocalizeAndSetText(MPT_PantheonSearch_Highlight(Locale.ToUpper(row.Name)));
			beliefInst.BeliefDescription:LocalizeAndSetText(MPT_PantheonSearch_Highlight(row.Description));
			SetBeliefIcon(beliefInst.BeliefIcon, row.BeliefType, SIZE_BELIEF_ICON_LARGE);
			if (m_iSelectedIndex ~= nil and row.Index == m_iSelectedIndex) then
				m_uiSelectedBeliefInstance = beliefInst;	-- 条目32扩展：选中信条在过滤结果中，重绑实例引用
			end
			beliefInst.BeliefButton:SetSelected(beliefInst == m_uiSelectedBeliefInstance);
			beliefInst.BeliefButton:RegisterCallback( Mouse.eLClick, function() OnBeliefSelected(beliefInst); end );
			beliefInst.BeliefButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end );
			beliefInst.BeliefButton:SetDisabled( not CanSelectBelief(row) );		-- 条目32：已被他人选走（已入某万神殿/宗教）的信条置灰禁用
			MPT_InstanceButton[row] = beliefInst;								-- 条目32：缓存实例，供 MPT_OnPantheonFounded 实时禁用
			instanceCount = instanceCount + 1;
		end
	end

	-- 条目32扩展：搜索无结果提示（仅搜索态且零结果显示；清空搜索恢复全量即隐）
	Controls.MPT_NoMatchLabel:SetHide(not (MPT_SearchText ~= "" and instanceCount == 0));

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
	-- 条目32扩展：信条搜索框接线（控件回调随面板上下文存续无需注销；占位文本显隐同
	-- 条目4.5 搜索框惯例——聚焦即隐、失焦按内容恢复；文本变化即过滤重建名册）
	Controls.MPT_SearchEditBox:RegisterStringChangedCallback(function()
		MPT_SearchText = string.upper(Controls.MPT_SearchEditBox:GetText() or "");
		Controls.MPT_SearchPlaceholder:SetHide(MPT_SearchText ~= "");
		Realize();
	end);
	Controls.MPT_SearchEditBox:RegisterHasFocusCallback(function()
		Controls.MPT_SearchPlaceholder:SetHide(true);
	end);
	Controls.MPT_SearchEditBox:RegisterLostFocusCallback(function()
		Controls.MPT_SearchPlaceholder:SetHide((Controls.MPT_SearchEditBox:GetText() or "") ~= "");
	end);
	-- ----

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
