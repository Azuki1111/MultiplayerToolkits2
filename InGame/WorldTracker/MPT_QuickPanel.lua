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
-- 条目11：「玩家标记」按钮 = LuaEvents.MPT_PlayerMark_Toggle() 打开/关闭游戏内
--   玩家标记面板（InGame/PlayerMark/MPT_PlayerMark，移植条目4.4 前端面板）。
-- ============================================================================

include("SupportFunctions");	-- TruncateStringWithTooltip 等

local m_quickAttached :boolean = false;
local m_quickExpanded :boolean = false;

-- 投票刷新计时（Game 属性轮询间隔）
local m_votePollTimer :number = 0;
local VOTE_POLL_INTERVAL :number = 1.0;	-- 秒

-- 投降/胜利结算已通知 EndGameMenu（只发一次，防重入；跨房间需在进房时重置）
local m_mpt_outcomeNotified :boolean = false;

-- 本时代投票已失败（全部投完未过半）：面板保留显示到「此回合结束后的下个回合结束」才隐藏
local m_mpt_voteFailed :boolean = false;		-- 本时代投票已失败
local m_mpt_voteFailedHidden :boolean = false;	-- 失败后已在 T+1 回合结束隐藏（隐藏后不再显示）
local m_mpt_voteFailTurn :number = -1;			-- 失败时的回合号（隐藏条件 = 当前回合 >= 失败回合 + 2）
-- 已处理过的投票标识（era_team）：检测新一轮投票（跨时代再发起）时重置失败隐藏标志
local m_mpt_processedVoteID :string = "";

-- 重开投票（条目8续2）相关状态
local m_mpt_restartExecuted :boolean = false;		-- 房主已执行重启（防重入）
local m_mpt_snapshotRequested :boolean = false;	-- 客户端已请求快照（防重入）
local m_mpt_restartFailed :boolean = false;		-- 重开投票已失败（复用投降失败隐藏流程）
-- 当前 VoteArea 显示的投票类型（"surrender" 投降 / "restart" 重开），投票按钮据此路由
local m_mpt_voteType :string = "surrender";
-- 重开投票通过后的 10 秒倒计时（倒计时结束才执行重启/快照）
local m_mpt_restartCountdown :number = -1;	-- -1 = 未激活；10→0 递减
local RESTART_COUNTDOWN_SEC :number = 10;
-- 客户端：倒计时结束后等待房主重载完成信号（GAME_HOST_IS_JUST_RELOADING → "N"）再请求快照
local m_mpt_snapshotArmed :boolean = false;
-- 客户端：本会话已发过同步完成标记（防重复发）
local m_mpt_syncDoneSent :boolean = false;
-- 房主：重开后等待所有客户端同步完成（全齐后取消暂停）
local m_mpt_waitingSync :boolean = false;
-- 非房主：已显示「等待房主重新开始」文本（防重复设置）
local m_mpt_waitingHostShown :boolean = false;
-- 房主：投票通过后已执行暂停（取消他人暂停+房主暂停，倒计时期间只一次）
local m_mpt_pauseDone :boolean = false;

-- ============================================================================
-- 本地玩家是否为观察者（LEADER_SPECTATOR；禁发起投降、禁投票、不弹结算）
-- ============================================================================
local function MPT_IsLocalObserver()
	return Game.GetLocalObserver() == PlayerTypes.OBSERVER;
end

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
		winTeam = nil,
		failed = false,
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
			state.winTeam = gpState.winTeam;
			state.failed = gpState.failed or false;
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
		state.winTeam = Game:GetProperty("MPT_SURRENDER_WIN_TEAM");
		state.failed = Game:GetProperty("MPT_SURRENDER_VOTE_FAILED_" .. state.era .. "_" .. teamID) == 1;
	end

	return state;
end

-- ============================================================================
-- 读取重开投票状态（经 ExposedMembers.MPT（Gameplay 暴露）同步查询，
-- Gameplay 侧见 SurrenderVote_Gameplay.lua 条目8续2 区）
-- ============================================================================
local function MPT_ReadRestartVoteState()
	local state = {
		era = -1,
		started = false,
		agreeCount = 0,
		totalCount = 0,
		passed = false,
		failed = false,
	};

	if ExposedMembers ~= nil and ExposedMembers.MPT ~= nil and ExposedMembers.MPT.GetRestartVoteState ~= nil then
		local gpState = ExposedMembers.MPT.GetRestartVoteState();
		if gpState ~= nil then
			state.era = gpState.era or -1;
			state.started = gpState.started or false;
			state.agreeCount = gpState.agreeCount or 0;
			state.totalCount = gpState.totalCount or 0;
			state.passed = gpState.passed or false;
			state.failed = gpState.failed or false;
		end
	else
		-- 兜底：直接读 Game 属性
		local pGameEras = Game.GetEras();
		if pGameEras ~= nil then
			state.era = pGameEras:GetCurrentEra();
		end
		state.started = Game:GetProperty("MPT_RESTART_VOTE_STARTED_" .. state.era) == 1;
		local votesStr = Game:GetProperty("MPT_RESTART_VOTES");
		if votesStr ~= nil then
			local slash = string.find(votesStr, "/");
			if slash ~= nil then
				state.agreeCount = tonumber(string.sub(votesStr, 1, slash - 1)) or 0;
				state.totalCount = tonumber(string.sub(votesStr, slash + 1)) or 0;
			end
		end
		state.passed = Game:GetProperty("MPT_RESTART_VOTE_PASSED") == 1;
		state.failed = Game:GetProperty("MPT_RESTART_VOTE_FAILED_" .. state.era) == 1;
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
-- 投同意/反对票（EXECUTE_SCRIPT → 房主；按当前 VoteArea 类型路由投降/重开）
-- ============================================================================
local function MPT_QuickVote(agree :boolean)
	print("[MPT_QuickVote] clicked agree=" .. tostring(agree) .. " type=" .. m_mpt_voteType);
	local localPlayer :number = Game.GetLocalPlayer();
	if localPlayer == nil or localPlayer < 0 then
		return;
	end
	local pPlayer :table = Players[localPlayer];
	if pPlayer == nil or not pPlayer:IsAlive() then
		return;
	end

	local kParameters :table = { agree = agree };
	if m_mpt_voteType == "restart" then
		local state = MPT_ReadRestartVoteState();
		if not state.started or state.passed then
			return;	-- 未发起或已通过，不能投
		end
		kParameters.OnStart = "MPT_RestartVote";
		kParameters.type = "vote";
		kParameters.voter = localPlayer;
	else
		local state = MPT_ReadVoteState();
		if not state.started or state.passed then
			return;	-- 未发起或已通过，不能投
		end
		kParameters.OnStart = "MPT_SurrenderVote";
		kParameters.type = "vote";
		kParameters.voter = localPlayer;
		kParameters.team = state.teamID;
	end

	UI.RequestPlayerOperation(Network.GetGameHostPlayerID(), PlayerOperations.EXECUTE_SCRIPT, kParameters);
	-- 请求后立即刷新一次面板（若 Gameplay 已记票则立即反映；未完成时轮询兜底）
	MPT_RefreshVotePanel();
end

-- ============================================================================
-- 刷新投降按钮（发起投票）状态与 tooltip：
--   disabled + tooltip 原因（观察者/已败亡/已投降/本时代已投过）
--   state: MPT_ReadVoteState 结果；localPlayer: 本地玩家 ID
-- ============================================================================
local function MPT_UpdateSurrenderButton(state, localPlayer)
	local bObserver :boolean = MPT_IsLocalObserver();
	local bAlive :boolean = false;
	if localPlayer ~= nil and localPlayer >= 0 and Players[localPlayer] ~= nil then
		bAlive = Players[localPlayer]:IsAlive();
	end

	local bDisabled :boolean = false;
	local tooltipTag :string = "LOC_MPT_SURRENDER_TT_DEFAULT";

	if bObserver then
		bDisabled = true;
		tooltipTag = "LOC_MPT_SURRENDER_TT_OBSERVER";
	elseif not bAlive then
		bDisabled = true;
		tooltipTag = "LOC_MPT_SURRENDER_TT_DEAD";
	elseif state.passed then
		bDisabled = true;
		tooltipTag = "LOC_MPT_SURRENDER_TT_SURRENDERED";
	elseif state.started then
		bDisabled = true;
		tooltipTag = "LOC_MPT_SURRENDER_TT_ALREADY";
	end

	Controls.SurrenderButton:SetDisabled(bDisabled);
	Controls.SurrenderButton:SetToolTipString(Locale.Lookup(tooltipTag));
end

-- ============================================================================
-- 刷新重新开始按钮（发起重开投票）状态与 tooltip
-- ============================================================================
local function MPT_UpdateRestartButton(state, localPlayer)
	local bObserver :boolean = MPT_IsLocalObserver();
	local bAlive :boolean = false;
	local bMulti :boolean = GameConfiguration.IsAnyMultiplayer();
	local bIsHost :boolean = Network.GetLocalPlayerID() == Network.GetGameHostPlayerID();
	if localPlayer ~= nil and localPlayer >= 0 and Players[localPlayer] ~= nil then
		bAlive = Players[localPlayer]:IsAlive();
	end

	local bDisabled :boolean = false;
	local tooltipTag :string = "LOC_MPT_RESTART_TT_DEFAULT";

	if not bIsHost then
		-- 仅房主可发起（非房主玩家/观察者禁用）
		bDisabled = true;
		tooltipTag = "LOC_MPT_RESTART_TT_HOST_ONLY";
	elseif not bMulti then
		bDisabled = true;
		tooltipTag = "LOC_MPT_RESTART_TT_SINGLE";
	elseif not bAlive and not bObserver then
		-- 非观察者已败亡禁用；观察者房主跳过 IsAlive（无文明）
		bDisabled = true;
		tooltipTag = "LOC_MPT_RESTART_TT_DEAD";
	elseif state.passed then
		bDisabled = true;
		tooltipTag = "LOC_MPT_RESTART_TT_PASSED";
	elseif state.started then
		bDisabled = true;
		tooltipTag = "LOC_MPT_RESTART_TT_ALREADY";
	end

	Controls.RestartButton:SetDisabled(bDisabled);
	Controls.RestartButton:SetToolTipString(Locale.Lookup(tooltipTag));
end

-- ============================================================================
-- 重开投票通过后的执行（在 MPT_RefreshVotePanel 中调用）：
--   通过后启动 10 秒倒计时（面板显示），倒计时结束调 MPT_ExecuteRestart。
-- 同种子重启 → 所有玩家重载后地图相同。
-- ============================================================================
local function MPT_ExecuteRestart()
	if m_mpt_restartExecuted and m_mpt_snapshotRequested then
		return;
	end
	local bIsHost :boolean = Network.GetLocalPlayerID() == Network.GetGameHostPlayerID();

	if bIsHost and not m_mpt_restartExecuted then
		m_mpt_restartExecuted = true;
		-- 随机化地图+游戏种子（官方 API RegenerateSeeds，1.67/MPH 同款；
		--    手动 MapConfiguration.SetValue 对引擎地图生成无效——引擎种子由
		--    RegenerateSeeds 管理，重开时地图种子才会真正随机）
		local oldGameSeed = GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED");
		local oldMapSeed = MapConfiguration.GetValue("RANDOM_SEED");
		print("[MPT_RestartVote] BEFORE RegenerateSeeds: game=" .. tostring(oldGameSeed) .. " map=" .. tostring(oldMapSeed));
		GameConfiguration.RegenerateSeeds();
		local newGameSeed = GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED");
		local newMapSeed = MapConfiguration.GetValue("RANDOM_SEED");
		print("[MPT_RestartVote] AFTER RegenerateSeeds: game=" .. tostring(newGameSeed) .. " map=" .. tostring(newMapSeed));
		Network.BroadcastGameConfig();
		-- 置重载标志并广播（房主重载完成后会置回 "N"）
		GameConfiguration.SetValue("GAME_HOST_IS_JUST_RELOADING", "Y");
		Network.BroadcastGameConfig();
		-- 重启
		print("[MPT_RestartVote] Host calling RestartGame now.");
		Network.RestartGame();
	elseif not bIsHost and not m_mpt_snapshotRequested then
		-- 客户端：不立即请求快照，置 armed 等待房主重载完成信号（GAME_HOST_IS_JUST_RELOADING → "N"）
		m_mpt_snapshotArmed = true;
	end
end

-- ============================================================================
-- 重开投票通过后的显示（每帧递减在 MPT_QuickOnUpdate）：
--   房主：10 秒倒计时（归零后执行重启）
--   其他玩家：显示「等待房主重新开始」（不显示倒计时，等待房主重载完成信号）
-- ============================================================================
local function MPT_HandleRestartExecution(restartState)
	if not restartState.passed then
		return;
	end
	if m_mpt_restartExecuted and m_mpt_snapshotRequested then
		return;
	end

	local bIsHost :boolean = Network.GetLocalPlayerID() == Network.GetGameHostPlayerID();

	-- 投票通过后立即暂停游戏（不等倒计时结束）：
	--   1) 取消其他玩家的暂停（1.67 OnReallyRestartGame 同款；SetWantsPause 本地改对方配置并广播）
	--   2) 房主暂停
	-- m_mpt_pauseDone 防重复（倒计时期间只暂停一次）
	if bIsHost and not m_mpt_pauseDone then
		m_mpt_pauseDone = true;
		-- 第一步：取消其他玩家的暂停
		if GameConfiguration.IsPaused() == true then
			local pausePlayerID = GameConfiguration.GetPausePlayer();
			if pausePlayerID ~= nil and pausePlayerID ~= Network.GetGameHostPlayerID() then
				local pauseCfg = PlayerConfigurations[pausePlayerID];
				if pauseCfg ~= nil then
					pauseCfg:SetWantsPause(false);
					Network.BroadcastPlayerInfo();
					print("[MPT_RestartVote] Step1: unpaused other player " .. tostring(pausePlayerID));
				end
			end
		end
		-- 房主暂停
		local localPlayerConfig = PlayerConfigurations[Network.GetLocalPlayerID()];
		if localPlayerConfig ~= nil then
			localPlayerConfig:SetWantsPause(true);
			Network.BroadcastPlayerInfo();
			print("[MPT_RestartVote] Step2: host paused game.");
		end
	end

	-- 通过后首次检测：隐藏投票按钮 + 显示等待/倒计时 Label
	if m_mpt_restartCountdown < 0 then
		Controls.VoteAgreeButton:SetHide(true);	-- 通过后隐藏投票按钮
		Controls.VoteDisagreeButton:SetHide(true);
		if bIsHost then
			m_mpt_restartCountdown = RESTART_COUNTDOWN_SEC;
			Controls.VoteCountdownLabel:SetHide(false);
		elseif not m_mpt_waitingHostShown then
			-- 非房主：不启动倒计时，显示等待文本（只设一次）
			m_mpt_waitingHostShown = true;
			Controls.VoteCountdownLabel:SetHide(false);
			Controls.VoteCountdownLabel:SetText(Locale.Lookup("LOC_MPT_RESTART_WAITING"));
		end
	end

	-- 房主：倒计时显示（整秒向上取整）
	if bIsHost and m_mpt_restartCountdown > 0 then
		Controls.VoteCountdownLabel:SetText(Locale.Lookup("LOC_MPT_RESTART_COUNTDOWN", math.ceil(m_mpt_restartCountdown)));
	end
end

-- ============================================================================
-- 客户端本地首回合：已加载完新游戏 → 发同步完成标记（EXECUTE_SCRIPT → 房主）
-- 房主据此统计到齐后取消暂停（第七步；不用 Chat）
-- ============================================================================
local function MPT_OnLocalTurnBegin()
	if m_mpt_syncDoneSent then
		return;
	end
	m_mpt_syncDoneSent = true;
	local localPlayer :number = Game.GetLocalPlayer();
	if localPlayer ~= nil and localPlayer >= 0 then
		local kParams :table = {
			OnStart = "MPT_SyncDone",
			player = localPlayer,
		};
		UI.RequestPlayerOperation(Network.GetGameHostPlayerID(), PlayerOperations.EXECUTE_SCRIPT, kParams);
		print("[MPT_SyncDone] Local turn begin, sent sync done for player " .. tostring(localPlayer));
	end
end

-- ============================================================================
-- 房主轮询：等待所有客户端同步完成（MPT_SYNC_DONE_<id> 全 1）→ 取消暂停（第七步）
-- 在 MPT_QuickOnUpdate 每帧调用；m_mpt_waitingSync 由房主重载完成（置 N）时置 true
-- ============================================================================
local function MPT_CheckSyncAllDone()
	if not m_mpt_waitingSync then
		return;
	end
	if Network.GetLocalPlayerID() ~= Network.GetGameHostPlayerID() then
		return;
	end

	local bAllDone :boolean = true;
	for i = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local pCfg = PlayerConfigurations[i];
		if pCfg ~= nil and pCfg:IsHuman() then
			-- 排除观察者（无需同步完成）；房主自己重载完成即视为完成
			if pCfg:GetLeaderTypeName() ~= "LEADER_SPECTATOR"
				and i ~= Network.GetGameHostPlayerID()
				and Players[i] ~= nil and Players[i]:IsAlive() then
				if Game:GetProperty("MPT_SYNC_DONE_" .. i) ~= 1 then
					bAllDone = false;
					break;
				end
			end
		end
	end

	if bAllDone then
		m_mpt_waitingSync = false;
		print("[MPT_RestartVote] Step7: all clients synced, unpausing game.");
		if GameConfiguration.IsPaused() == true then
			local pausePlayerID = GameConfiguration.GetPausePlayer();
			local pauseCfg = PlayerConfigurations[pausePlayerID];
			if pauseCfg ~= nil then
				pauseCfg:SetWantsPause(false);
				Network.BroadcastPlayerInfo();
			end
		end
		-- 清标记（防第二轮残留）
		for i = 0, PlayerManager.GetWasEverAliveCount() - 1 do
			Game:SetProperty("MPT_SYNC_DONE_" .. i, nil);
		end
	end
end

-- ============================================================================
-- 刷新投票面板显示（赋值给上面 forward 声明的 local，勿加 local 关键字）
-- 投降投票（BG3）与重开投票（BG2）共用一个 VoteArea，按状态切换类型/背景。
-- ============================================================================
function MPT_RefreshVotePanel()
	local state = MPT_ReadVoteState();
	local restartState = MPT_ReadRestartVoteState();
	local localPlayer :number = Game.GetLocalPlayer();
	local bLocalObserver :boolean = MPT_IsLocalObserver();

	-- 投降按钮状态 + tooltip（观察者/已败亡/已投降/本时代已投过）
	MPT_UpdateSurrenderButton(state, localPlayer);
	-- 重新开始按钮状态 + tooltip
	MPT_UpdateRestartButton(restartState, localPlayer);

	-- 结算通知：本队已投降 / 本队是胜队 → 通知 EndGameMenu 弹结算（只发一次）
	-- 观察者不通知（无结算）；已通知过不再重复
	if not m_mpt_outcomeNotified and not bLocalObserver
		and localPlayer ~= nil and localPlayer >= 0 then
		local pLocalPlayer = Players[localPlayer];
		local localTeam = -1;
		if pLocalPlayer ~= nil then
			localTeam = pLocalPlayer:GetTeam();
		end
		if state.passed then
			m_mpt_outcomeNotified = true;
			LuaEvents.MPT_SurrenderOutcome("defeat");
		elseif state.winTeam ~= nil and state.winTeam == localTeam then
			m_mpt_outcomeNotified = true;
			LuaEvents.MPT_SurrenderOutcome("win");
		end
	end

	-- 重开投票：房主轮询到通过 → 执行重启（同种子 → 地图相同）
	-- 客户端轮询到通过 → 请求快照同步新游戏
	MPT_HandleRestartExecution(restartState);

	-- 新一轮投票检测：跨时代/新投票发起时重置失败隐藏标志
	-- （第一次失败后 m_mpt_voteFailedHidden 置位永久隐藏；新投票应重新显示面板）
	if state.started and not state.passed then
		local voteID :string = tostring(state.era) .. "_" .. tostring(state.teamID);
		if m_mpt_processedVoteID ~= voteID then
			m_mpt_processedVoteID = voteID;
			m_mpt_voteFailed = false;
			m_mpt_voteFailedHidden = false;
			m_mpt_voteFailTurn = -1;
		end
	end

	-- 投票失败检测：全部投完未过半 → 置位，记录失败回合（面板保留到 T+1 结束才隐藏）
	if not m_mpt_voteFailed and state.failed then
		m_mpt_voteFailed = true;
		m_mpt_voteFailTurn = Game.GetCurrentGameTurn();
	end

	-- ==========================================================================
	-- 显示类型判定（优先级：重开投票 > 投降投票）
	--   - 重开投票已发起/已通过 → 显示重开投票（BG2 背景）
	--   - 否则投降投票已发起/已通过 → 显示投降投票（BG3 背景）
	-- ==========================================================================
	local bShowVoteArea :boolean = false;
	local bShowRestart :boolean = false;
	local bShowSurrender :boolean = false;

	if not bLocalObserver and GameConfiguration.IsAnyMultiplayer()
		and localPlayer ~= nil and localPlayer >= 0
		and Players[localPlayer] ~= nil and Players[localPlayer]:IsAlive() then

		-- 重开投票优先
		if restartState.started or restartState.passed then
			if restartState.failed then
				-- 重开投票失败：复用投降失败的隐藏流程（T+1 回合结束隐藏）
				if not m_mpt_restartFailed and not m_mpt_voteFailedHidden then
					m_mpt_restartFailed = true;
					m_mpt_voteFailed = true;
					m_mpt_voteFailTurn = Game.GetCurrentGameTurn();
				end
				bShowVoteArea = not m_mpt_voteFailedHidden;
			else
				bShowVoteArea = true;
			end
			if bShowVoteArea then
				bShowRestart = true;
			end
		elseif state.started or state.passed then
			bShowVoteArea = not m_mpt_voteFailedHidden;
			if bShowVoteArea then
				bShowSurrender = true;
			end
		end
	end

	Controls.VoteArea:SetHide(not bShowVoteArea);
	if not bShowVoteArea then
		return;
	end

	-- 设置投票类型与背景（重开 BG2 / 投降 BG3）
	m_mpt_voteType = bShowRestart and "restart" or "surrender";
	Controls.VoteBacking:SetTexture(bShowRestart and "EMERGENCY_BACKSTAB_BG2" or "EMERGENCY_BACKSTAB_BG3");

	local activeState = bShowRestart and restartState or state;
	if activeState.passed then
		Controls.VoteStatusLabel:SetText(Locale.Lookup(bShowRestart and "LOC_MPT_RESTART_PASSED" or "LOC_MPT_VOTE_PASSED"));
		Controls.VoteProgressLabel:SetText("");
		Controls.VoteAgreeButton:SetHide(true);
		Controls.VoteDisagreeButton:SetHide(true);
	else
		-- 已发起：显示进度 + 投票按钮
		Controls.VoteStatusLabel:SetText(Locale.Lookup(bShowRestart and "LOC_MPT_RESTART_TITLE" or "LOC_MPT_VOTE_TITLE"));
		Controls.VoteProgressLabel:SetText(Locale.Lookup("LOC_MPT_VOTE_PROGRESS", activeState.agreeCount, activeState.totalCount));
		Controls.VoteAgreeButton:SetHide(false);
		Controls.VoteDisagreeButton:SetHide(false);
		-- 本机已投票则禁用按钮（Gameplay 一人一票防重复；UI 读属性给明确反馈）
		local bLocalVoted :boolean = false;
		if localPlayer ~= nil and localPlayer >= 0 then
			if bShowRestart then
				bLocalVoted = Game:GetProperty("MPT_RESTART_VOTED_" .. localPlayer) == 1;
			elseif state.teamID >= 0 then
				bLocalVoted = Game:GetProperty("MPT_SURRENDER_VOTED_" .. state.teamID .. "_" .. localPlayer) == 1;
			end
		end
		local bDisabled :boolean = bLocalVoted or m_mpt_voteFailed;
		Controls.VoteAgreeButton:SetDisabled(bDisabled);
		Controls.VoteDisagreeButton:SetDisabled(bDisabled);
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
		-- ============================================================================
		-- 条目11：展开区新增「玩家标记」按钮（2 → 3 枚），展开高度 110 -> 146，
		-- 底部分隔线随之下移 108 -> 144
		-- 条目12：展开区新增「设置」按钮（3 → 4 枚），展开高度 146 -> 182，
		-- 底部分隔线随之下移 144 -> 180
		-- 条目34：展开区新增「反作弊监测」按钮（4 → 5 枚）；高级选项 MPT_HASH_CHECK
		-- 未勾选时该按钮隐藏（条目32 同款运行时 GetValue 门控），高度按可见枚数二选一：
		-- 5 枚 = 218 / 216，4 枚 = 182 / 180（每枚 32 按钮 + 4 间距 = 36）
		-- Controls.QuickPanel:SetSizeY(110);
		-- Controls.QuickPanel:SetSizeY(146);
		if GameConfiguration.GetValue("MPT_HASH_CHECK") then
			Controls.QuickPanel:SetSizeY(218);
			Controls.QuickSepBottom:SetOffsetY(216);
		else
			Controls.QuickPanel:SetSizeY(182);
			Controls.QuickSepBottom:SetOffsetY(180);
		end
		-- ----------------------------------------------------------------------------
		-- 投票面板独立挂 PanelStack，不参与本面板高度
		Controls.ExpandStack:SetHide(false);
		Controls.QuickSepBottom:SetHide(false);
		m_quickExpanded = true;
	end
end

-- ============================================================================
-- 重新开始按钮（条目8续2）：发起全局重开投票（仅房主可发起，观察者房主也可）
-- 点击 → EXECUTE_SCRIPT 到房主（Gameplay 侧记票/判过半/写属性）；
-- 房主轮询到通过后执行 Network.RestartGame()（换种子 +1 → 新地图）。
-- ============================================================================
local function MPT_QuickRestart()
	local localPlayer :number = Game.GetLocalPlayer();
	if localPlayer == nil or localPlayer < 0 then
		return;
	end
	-- 仅房主可发起（观察者房主也可发起——不拦截观察者）
	if Network.GetLocalPlayerID() ~= Network.GetGameHostPlayerID() then
		return;
	end
	local pPlayer :table = Players[localPlayer];
	-- 已败亡不可发起；但观察者房主无文明（IsAlive 可能 false）→ 观察者跳过 IsAlive 检查
	if pPlayer == nil or (not MPT_IsLocalObserver() and not pPlayer:IsAlive()) then
		return;
	end
	if not GameConfiguration.IsAnyMultiplayer() then
		return;	-- 单人局不可发起（重开需多人同步）
	end

	local state = MPT_ReadRestartVoteState();
	if state.passed then
		return;	-- 已通过（房主即将重启）
	end
	if state.started then
		return;	-- 本时代已发起过
	end

	-- 发起请求 → 房主（EXECUTE_SCRIPT）
	local kParameters :table = {
		OnStart = "MPT_RestartVote",
		type = "start",
		initiator = localPlayer,
	};
	UI.RequestPlayerOperation(Network.GetGameHostPlayerID(), PlayerOperations.EXECUTE_SCRIPT, kParameters);
	-- 请求后立即刷新一次面板
	MPT_RefreshVotePanel();
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

		-- 房主重载完成信号：检测到 GAME_HOST_IS_JUST_RELOADING=="Y" → 置 "N" 并广播
		-- （客户端检测到 "N" 后请求快照；房主重启后前端重建，本处每次挂载执行）
		if Network.GetLocalPlayerID() == Network.GetGameHostPlayerID()
			and GameConfiguration.GetValue("GAME_HOST_IS_JUST_RELOADING") == "Y" then
			GameConfiguration.SetValue("GAME_HOST_IS_JUST_RELOADING", "N");
			Network.BroadcastGameConfig();
			-- 重载后打印配置中的种子（排查重启后种子是否保留/被重置）
			local curGameSeed = GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED");
			local curMapSeed = MapConfiguration.GetValue("RANDOM_SEED");
			print("[MPT_RestartVote] Host reload complete, JUST_RELOADING=N. config seeds: game=" .. tostring(curGameSeed) .. " map=" .. tostring(curMapSeed));
			-- 进入等待所有客户端同步完成状态（第七步）
			m_mpt_waitingSync = true;
		end

		-- 新会话（进房）重置结算/投票失败标志（Lua 状态跨房间存续，见 AGENTS.md）
		m_mpt_outcomeNotified = false;
		m_mpt_voteFailed = false;
		m_mpt_voteFailedHidden = false;
		m_mpt_voteFailTurn = -1;
		m_mpt_processedVoteID = "";
		m_mpt_restartExecuted = false;
		m_mpt_snapshotRequested = false;
		m_mpt_restartFailed = false;
		m_mpt_voteType = "surrender";
		m_mpt_restartCountdown = -1;
		m_mpt_snapshotArmed = false;
		m_mpt_syncDoneSent = false;
		m_mpt_waitingSync = false;
		m_mpt_waitingHostShown = false;
		m_mpt_pauseDone = false;
		-- 挂载后立即刷新一次：观察者按钮禁用/投票状态/结算检测立即生效
		MPT_RefreshVotePanel();
	end
end

-- ============================================================================
-- 每帧刷新（投票状态轮询 + 回合结束隐藏失败投票面板）
-- ============================================================================
local function MPT_QuickOnUpdate()
	-- 房主：等待所有客户端同步完成 → 取消暂停（第七步）
	MPT_CheckSyncAllDone();

	-- 重开投票通过后的倒计时递减（每帧用 GetLastTimeDelta）
	if m_mpt_restartCountdown > 0 then
		m_mpt_restartCountdown = m_mpt_restartCountdown - UIManager:GetLastTimeDelta();
		-- 刷新倒计时显示（整秒）
		Controls.VoteCountdownLabel:SetText(Locale.Lookup("LOC_MPT_RESTART_COUNTDOWN", math.ceil(m_mpt_restartCountdown)));
		if m_mpt_restartCountdown <= 0 then
			m_mpt_restartCountdown = 0;
			-- 倒计时结束：执行重启（房主）/ 置 armed 等房主重载（客户端）
			MPT_ExecuteRestart();
		end
	end

	-- 客户端：倒计时结束后等房主重载完成（GAME_HOST_IS_JUST_RELOADING → "N"）再请求快照
	if m_mpt_snapshotArmed and not m_mpt_snapshotRequested then
		if GameConfiguration.GetValue("GAME_HOST_IS_JUST_RELOADING") ~= "Y" then
			m_mpt_snapshotRequested = true;
			m_mpt_snapshotArmed = false;
			print("[MPT_RestartVote] Client requesting snapshot to resync new game.");
			Network.RequestSnapshot();
		end
	end

	-- 投票失败后：当前回合 >= 失败回合 + 2（= 失败回合 T 结束后的下个回合 T+1 结束）→ 隐藏
	if m_mpt_voteFailed and not m_mpt_voteFailedHidden then
		local currentTurn :number = Game.GetCurrentGameTurn();
		if currentTurn >= m_mpt_voteFailTurn + 2 then
			m_mpt_voteFailedHidden = true;
			Controls.VoteArea:SetHide(true);
		end
	end

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

	-- 条目11：玩家标记按钮 → 打开/关闭游戏内玩家标记面板（LuaEvents 跨 Context，面板侧见 InGame/PlayerMark/MPT_PlayerMark.lua）
	Controls.PlayerMarkButton:RegisterCallback(Mouse.eLClick, function() LuaEvents.MPT_PlayerMark_Toggle(); end);
	Controls.PlayerMarkButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	-- 条目12：设置按钮 → 打开/关闭游戏内设置面板（LuaEvents 跨 Context；面板侧见 InGame/SettingsPanel/MPT_SettingsPanel.lua）
	Controls.SettingsButton:RegisterCallback(Mouse.eLClick, function() LuaEvents.MPT_SettingsPanel_Toggle(); end);
	Controls.SettingsButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	-- 条目34：反作弊监测按钮 → 打开/关闭反作弊监测面板（LuaEvents 跨 Context；面板侧见 InGame/HashCheck/MPT_HashCheckUI.lua）。
	-- 高级选项 MPT_HASH_CHECK 未勾选时按钮隐藏（条目32 同款运行时 GetValue 门控）——
	-- 此时面板上下文整个未加载（modinfo criteria 门控零加载），点击也不会有响应
	Controls.HashCheckButton:RegisterCallback(Mouse.eLClick, function() LuaEvents.MPT_HashCheck_Toggle(); end);
	Controls.HashCheckButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.HashCheckButton:SetHide(not GameConfiguration.GetValue("MPT_HASH_CHECK"));

	Controls.VoteAgreeButton:RegisterCallback(Mouse.eLClick, function() MPT_QuickVote(true); end);
	Controls.VoteAgreeButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.VoteDisagreeButton:RegisterCallback(Mouse.eLClick, function() MPT_QuickVote(false); end);
	Controls.VoteDisagreeButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	Events.LoadGameViewStateDone.Add(MPT_QuickAttach);
	-- 客户端本地首回合 → 发同步完成标记（重开第七步；不用 Chat）
	Events.LocalPlayerTurnBegin.Add(MPT_OnLocalTurnBegin);
	-- 每帧轮询（不可见 AlphaAnim 的 RegisterAnimCallback；Civ6 无 SetUpdateHandler）
	Controls.MPT_PollAnim:RegisterAnimCallback(MPT_QuickOnUpdate);
end
MPT_QuickInitialize();
