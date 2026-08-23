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
--   投票面板（VoteArea）独立于快捷面板：ChangeParent 到 PanelStack 作为平级子级
--   （QuickPanel 之后），显隐只由投票状态驱动，不受快捷面板展开/收起影响。
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
-- 读取投票状态（经 ExposedMembers.MPT（Gameplay 暴露）同步查询，
-- Gameplay 侧见 SurrenderVote_Gameplay.lua）
-- ============================================================================
local function MPT_ReadVoteState()
	local teamID = MPT_GetLocalTeam();
	local state = {
		teamID = teamID,
		era = -1,
		started = false,
		agreeCount = 0,
		totalCount = 0,
		passed = false,
	};
	if teamID < 0 then
		return state;
	end

	if ExposedMembers ~= nil and ExposedMembers.MPT ~= nil and ExposedMembers.MPT.GetSurrenderVoteState ~= nil then
		local gpState = ExposedMembers.MPT.GetSurrenderVoteState(teamID);
		if gpState ~= nil then
			state.era = gpState.era or -1;
			state.started = gpState.started or false;
			state.agreeCount = gpState.agreeCount or 0;
			state.totalCount = gpState.totalCount or 0;
			state.passed = gpState.passed or false;
		end
	else
		-- 兜底：直接读 Game 属性（UI 侧 Game 可读属性）
		local pGameEras = Game.GetEras();
		if pGameEras ~= nil then
			state.era = pGameEras:GetCurrentEra();
		end
		state.started = Game:GetProperty("MPT_SURRENDER_VOTE_" .. state.era .. "_" .. teamID) == 1;
		local votesStr = Game:GetProperty("MPT_SURRENDER_VOTES_" .. teamID);
		if votesStr ~= nil then
			local slash = string.find(votesStr, "/");
			if slash ~= nil then
				state.agreeCount = tonumber(string.sub(votesStr, 1, slash - 1)) or 0;
				state.totalCount = tonumber(string.sub(votesStr, slash + 1)) or 0;
			end
		end
		state.passed = Game:GetProperty("MPT_SURRENDER_TEAM_" .. teamID) == 1;
	end

	return state;
end

-- ============================================================================
-- 发起投降投票（EXECUTE_SCRIPT → 房主）
-- ============================================================================
-- forward 声明：MPT_RefreshVotePanel 定义在本文件下方（Lua local 顺序限制，
-- 声明点之前引用 local 会解析为全局 nil，见 AGENTS.md 踩坑记录）
local MPT_RefreshVotePanel;

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
	-- 请求后立即刷新一次面板（发起成功则投票区立刻显示，轮询兜底）
	MPT_RefreshVotePanel();
end

-- ============================================================================
-- 投同意/反对票（EXECUTE_SCRIPT → 房主）
-- ============================================================================
local function MPT_QuickVote(agree :boolean)
	print("[MPT_QuickVote] clicked agree=" .. tostring(agree));
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
	-- 请求后立即刷新一次面板（若 Gameplay 已记票则立即反映；未完成时轮询兜底）
	MPT_RefreshVotePanel();
end

-- ============================================================================
-- 刷新投票面板显示（赋值给上面 forward 声明的 local，勿加 local 关键字）
-- ============================================================================
function MPT_RefreshVotePanel()
	local state = MPT_ReadVoteState();
	local bShowVoteArea :boolean = false;
	local localPlayer :number = Game.GetLocalPlayer();

	-- 仅同队、多人局、本地玩家存活时参与投票判定；
	-- 投票区整体默认隐藏，只有「本时代已发起投票」或「已通过」时才显示
	if GameConfiguration.IsAnyMultiplayer()
		and localPlayer ~= nil and localPlayer >= 0
		and Players[localPlayer] ~= nil and Players[localPlayer]:IsAlive()
		and state.teamID >= 0
		and (state.started or state.passed) then
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
	else
		-- 已发起：显示进度 + 投票按钮
		Controls.VoteStatusLabel:SetText(Locale.Lookup("LOC_MPT_VOTE_TITLE"));
		Controls.VoteProgressLabel:SetText(Locale.Lookup("LOC_MPT_VOTE_PROGRESS", state.agreeCount, state.totalCount));
		Controls.VoteAgreeButton:SetHide(false);
		Controls.VoteDisagreeButton:SetHide(false);
		-- 本机已投票则禁用按钮（Gameplay 一人一票防重复；UI 读属性给明确反馈）
		local bLocalVoted :boolean = false;
		if localPlayer ~= nil and localPlayer >= 0 and state.teamID >= 0 then
			bLocalVoted = Game:GetProperty("MPT_SURRENDER_VOTED_" .. state.teamID .. "_" .. localPlayer) == 1;
		end
		Controls.VoteAgreeButton:SetDisabled(bLocalVoted);
		Controls.VoteDisagreeButton:SetDisabled(bLocalVoted);
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
		-- 展开高度固定：头部 25 + 展开区（30 偏移 + 32 按钮 + 4 + 32 按钮 + 4）≈ 102；
		-- 投票面板独立挂 PanelStack，不参与本面板高度
		Controls.QuickPanel:SetSizeY(110);
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
		-- 条目8续：投票面板独立挂载（QuickPanel 之后，作为 PanelStack 平级子级；
		-- 显隐只由投票状态驱动，QuickPanel 展开/收起不影响其显隐；Hidden 时 Stack 不占位）
		Controls.VoteArea:ChangeParent(worldTrackerPanel);
		worldTrackerPanel:AddChildAtIndex(Controls.VoteArea, 2);
		worldTrackerPanel:CalculateSize();
		worldTrackerPanel:ReprocessAnchoring();
		m_quickAttached = true;
	end
end

-- ============================================================================
-- 每帧刷新（投票状态轮询）
-- ============================================================================
local function MPT_QuickOnUpdate()
	m_votePollTimer = m_votePollTimer + UIManager:GetLastTimeDelta();
	if m_votePollTimer >= VOTE_POLL_INTERVAL then
		m_votePollTimer = 0;
		MPT_RefreshVotePanel();
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
	-- 每帧轮询（不可见 AlphaAnim 的 RegisterAnimCallback；Civ6 无 SetUpdateHandler）
	Controls.MPT_PollAnim:RegisterAnimCallback(MPT_QuickOnUpdate);
end
MPT_QuickInitialize();
