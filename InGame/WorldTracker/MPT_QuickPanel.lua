-- ============================================================================
-- 条目8：WorldTracker 快捷操作面板（投降 / 重新开始）
--
-- 本文件与 MPT_QuickPanel.xml 同名，经 ImportFiles 进 VFS，由引擎在空 Context
-- 下同名自动执行（RMC 已验证机制）。LoadGameViewStateDone 时把面板挂进原版
-- /InGame/WorldTracker/PanelStack（索引 1），点击标题展开/收起。
--
-- 条目8续：投降投票
--   「投降」按钮 = 发起本队投降投票（仅同队人类玩家可见/可投）。
--   通信走 UI.RequestPlayerOperation(hostID, EXECUTE_SCRIPT, {OnStart="MPT_SurrenderVote",...})
--   （不用 Chat 指令；Gameplay 侧见 SurrenderVote_Gameplay.lua）。
--   投票状态存 Game:SetProperty（跨端同步+持久化）；本面板定期轮询刷新。
--   频率限制：每游戏时代每队仅可发起一次（SetProperty 记录）。
--   「重新开始」按钮响应暂未配置（TODO）。
-- ============================================================================

include("SupportFunctions");	-- TruncateStringWithTooltip 等

local m_quickAttached :boolean = false;
local m_quickExpanded :boolean = false;

-- 投票刷新计时（Game 属性轮询间隔）
local m_votePollTimer :number = 0;
local VOTE_POLL_INTERVAL :number = 1.0;	-- 秒

-- ============================================================================
-- 当前本地玩家与本队信息
-- ============================================================================
local function MPT_GetLocalTeam()
	local localPlayer :number = Game.GetLocalPlayer();
	if localPlayer == nil or localPlayer < 0 then
		return -1;
	end
	local pPlayer :table = Players[localPlayer];
	if pPlayer == nil then
		return -1;
	end
	return pPlayer:GetTeam();
end

-- ============================================================================
-- 本队当前存活的同队人类玩家数（投票分母）
-- ============================================================================
local function MPT_GetTeamHumanAliveCount(teamID)
	local count = 0;
	for i = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local pPlayer = Players[i];
		if pPlayer ~= nil and pPlayer:IsMajor() and pPlayer:IsAlive()
			and pPlayer:GetTeam() == teamID
			and PlayerConfigurations[i] ~= nil
			and not PlayerConfigurations[i]:IsAIPlayer() then
			count = count + 1;
		end
	end
	return count;
end

-- ============================================================================
-- 读取投票状态（Game 属性，UI 可直接读）
-- ============================================================================
local function MPT_ReadVoteState()
	local teamID = MPT_GetLocalTeam();
	local era = -1;
	local started = false;
	local agreeCount = 0;
	local totalCount = 0;
	local passed = false;

	local pGameEras = Game.GetEras();
	if pGameEras ~= nil then
		era = pGameEras:GetCurrentEra();
	end

	started = Game:GetProperty("MPT_SURRENDER_VOTE_" .. era .. "_" .. teamID) == 1;
	local votesStr = Game:GetProperty("MPT_SURRENDER_VOTES_" .. teamID);
	if votesStr ~= nil then
		local slash = string.find(votesStr, "/");
		if slash ~= nil then
			agreeCount = tonumber(string.sub(votesStr, 1, slash - 1)) or 0;
			totalCount = tonumber(string.sub(votesStr, slash + 1)) or 0;
		end
	end
	passed = Game:GetProperty("MPT_SURRENDER_TEAM_" .. teamID) == 1;

	return { teamID = teamID, era = era, started = started, agreeCount = agreeCount, totalCount = totalCount, passed = passed };
end

-- ============================================================================
-- 发起投降投票（EXECUTE_SCRIPT → 房主）
-- ============================================================================
local function MPT_QuickSurrender()
	local localPlayer :number = Game.GetLocalPlayer();
	if localPlayer == nil or localPlayer < 0 then
		return;
	end
	local pPlayer :table = Players[localPlayer];
	if pPlayer == nil or not pPlayer:IsAlive() then
		return;	-- 已败亡不可发起
	end
	if Game.GetLocalObserver() == PlayerTypes.OBSERVER then
		return;	-- 观察者不可发起
	end

	local state = MPT_ReadVoteState();
	if state.passed then
		return;	-- 本队已投降
	end
	if state.started then
		return;	-- 本时代本队已发起过（其他人发起的也不能再发起）
	end

	-- 发起请求 → 房主（EXECUTE_SCRIPT）
	local kParameters :table = {
		OnStart = "MPT_SurrenderVote",
		type = "start",
		initiator = localPlayer,
		team = state.teamID,
	};
	UI.RequestPlayerOperation(Network.GetGameHostPlayerID(), PlayerOperations.EXECUTE_SCRIPT, kParameters);
end

-- ============================================================================
-- 投同意/反对票（EXECUTE_SCRIPT → 房主）
-- ============================================================================
local function MPT_QuickVote(agree :boolean)
	local localPlayer :number = Game.GetLocalPlayer();
	if localPlayer == nil or localPlayer < 0 then
		return;
	end
	local pPlayer :table = Players[localPlayer];
	if pPlayer == nil or not pPlayer:IsAlive() then
		return;
	end

	local state = MPT_ReadVoteState();
	if not state.started or state.passed then
		return;	-- 未发起或已通过，不能投
	end

	local kParameters :table = {
		OnStart = "MPT_SurrenderVote",
		type = "vote",
		voter = localPlayer,
		team = state.teamID,
		agree = agree,
	};
	UI.RequestPlayerOperation(Network.GetGameHostPlayerID(), PlayerOperations.EXECUTE_SCRIPT, kParameters);
end

-- ============================================================================
-- 刷新投票面板显示
-- ============================================================================
local function MPT_RefreshVotePanel()
	local localPlayer :number = Game.GetLocalPlayer();
	local state = MPT_ReadVoteState();
	local bShowVoteArea :boolean = false;

	-- 仅同队、多人局、本地玩家存活时显示投票区
	if GameConfiguration.IsAnyMultiplayer()
		and localPlayer ~= nil and localPlayer >= 0
		and Players[localPlayer] ~= nil and Players[localPlayer]:IsAlive()
		and state.teamID >= 0 then
		bShowVoteArea = true;
	end

	Controls.VoteArea:SetHide(not bShowVoteArea);
	if not bShowVoteArea then
		return;
	end

	if state.passed then
		Controls.VoteStatusLabel:SetText(Locale.Lookup("LOC_MPT_VOTE_PASSED"));
		Controls.VoteProgressLabel:SetText("");
		Controls.VoteAgreeButton:SetHide(true);
		Controls.VoteDisagreeButton:SetHide(true);
	elseif state.started then
		-- 已发起：显示进度 + 投票按钮
		Controls.VoteStatusLabel:SetText(Locale.Lookup("LOC_MPT_VOTE_TITLE"));
		Controls.VoteProgressLabel:SetText(Locale.Lookup("LOC_MPT_VOTE_PROGRESS", state.agreeCount, state.totalCount));
		Controls.VoteAgreeButton:SetHide(false);
		Controls.VoteDisagreeButton:SetHide(false);
	else
		-- 未发起：显示提示（本时代可发起）
		Controls.VoteStatusLabel:SetText(Locale.Lookup("LOC_MPT_VOTE_TITLE"));
		Controls.VoteProgressLabel:SetText(Locale.Lookup("LOC_MPT_VOTE_NOT_STARTED"));
		Controls.VoteAgreeButton:SetHide(true);
		Controls.VoteDisagreeButton:SetHide(true);
	end
end

-- ============================================================================
-- 展开/收起面板
-- ============================================================================
local function MPT_QuickToggle()
	if m_quickExpanded then
		UI.PlaySound("Tech_Tray_Slide_Closed");
		Controls.QuickPanel:SetSizeY(25);
		Controls.ExpandStack:SetHide(true);
		Controls.QuickSepBottom:SetHide(true);
		m_quickExpanded = false;
	else
		UI.PlaySound("Tech_Tray_Slide_Open");
		-- 展开高度动态：投票区可见时更高（头部 25 + 按钮 32*2 + 投票区）
		local height = 110;
		if not Controls.VoteArea:IsHidden() then
			height = 196;
		end
		Controls.QuickPanel:SetSizeY(height);
		Controls.ExpandStack:SetHide(false);
		Controls.QuickSepBottom:SetHide(false);
		m_quickExpanded = true;
	end
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
-- 每帧刷新（投票状态轮询 + 展开高度重算）
-- ============================================================================
local function MPT_QuickOnUpdate()
	m_votePollTimer = m_votePollTimer + UIManager:GetLastTimeDelta();
	if m_votePollTimer >= VOTE_POLL_INTERVAL then
		m_votePollTimer = 0;
		MPT_RefreshVotePanel();
		-- 投票状态变化后重算展开高度
		if m_quickExpanded and not Controls.VoteArea:IsHidden() then
			Controls.QuickPanel:SetSizeY(196);
		end
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

	Controls.VoteAgreeButton:RegisterCallback(Mouse.eLClick, function() MPT_QuickVote(true); end);
	Controls.VoteAgreeButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.VoteDisagreeButton:RegisterCallback(Mouse.eLClick, function() MPT_QuickVote(false); end);
	Controls.VoteDisagreeButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Events.LoadGameViewStateDone.Add(MPT_QuickAttach);
	ContextPtr:SetUpdateHandler(MPT_QuickOnUpdate);
end
MPT_QuickInitialize();
