-- ============================================================================
-- 条目8：WorldTracker 快捷操作面板（投降 / 重新开始）
--
-- 本文件与 MPT_QuickPanel.xml 同名，经 ImportFiles 进 VFS，由引擎在空 Context
-- 下同名自动执行（RMC 已验证机制）。LoadGameViewStateDone 时把面板挂进原版
-- /InGame/WorldTracker/PanelStack（索引 1），点击标题展开/收起。
--
-- 挂载方式参考作弊面板 mod（Cheat_Panel_World_Tracker.lua）：ChangeParent +
-- AddChildAtIndex + CalculateSize。面板内容：标题「快捷操作」+ 展开后两个按钮
-- 「投降」「重新开始」——按钮响应暂不配置（空回调 + TODO），后续条目接入。
-- ============================================================================

local m_quickAttached :boolean = false;
local m_quickExpanded :boolean = false;

-- ============================================================================
-- 展开/收起面板
-- ============================================================================
local function MPT_QuickToggle()
	if m_quickExpanded then
		UI.PlaySound("Tech_Tray_Slide_Closed");
		Controls.QuickPanel:SetSizeY(25);
		Controls.ExpandStack:SetHide(true);
		m_quickExpanded = false;
	else
		UI.PlaySound("Tech_Tray_Slide_Open");
		Controls.QuickPanel:SetSizeY(71);	-- 25(标题) + 2×32(按钮) + 间距/边距
		Controls.ExpandStack:SetHide(false);
		m_quickExpanded = true;
	end
end

-- ============================================================================
-- 投降按钮（响应待配置：TODO 条目后续接入投降逻辑）
-- ============================================================================
local function MPT_QuickSurrender()
	-- TODO: 条目8后续：接入投降（Surrender）逻辑
end

-- ============================================================================
-- 重新开始按钮（响应待配置：TODO 条目后续接入重开逻辑）
-- ============================================================================
local function MPT_QuickRestart()
	-- TODO: 条目8后续：接入重新开始（Restart）逻辑
end

-- ============================================================================
-- 挂载面板到 WorldTracker.PanelStack（索引 1，紧随原版头部之后）
-- ============================================================================
local function MPT_QuickAttach()
	if m_quickAttached then
		return;
	end
	local worldTrackerPanel :table = ContextPtr:LookUpControl("/InGame/WorldTracker/PanelStack");
	if worldTrackerPanel ~= nil then
		Controls.QuickPanel:ChangeParent(worldTrackerPanel);
		worldTrackerPanel:AddChildAtIndex(Controls.QuickPanel, 1);
		worldTrackerPanel:CalculateSize();
		worldTrackerPanel:ReprocessAnchoring();
		m_quickAttached = true;
	end
end

-- ============================================================================
-- 初始化
-- ============================================================================
local function MPT_QuickInitialize()
	Controls.HeaderTitle:RegisterCallback(Mouse.eLClick, MPT_QuickToggle);
	Controls.HeaderTitle:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.SurrenderButton:RegisterCallback(Mouse.eLClick, MPT_QuickSurrender);
	Controls.SurrenderButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Controls.RestartButton:RegisterCallback(Mouse.eLClick, MPT_QuickRestart);
	Controls.RestartButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Events.LoadGameViewStateDone.Add(MPT_QuickAttach);
end
MPT_QuickInitialize();
