-- ============================================================================
-- 条目8续：WorldTracker 团队投降投票（Gameplay 侧）
--
-- 接收 UI（MPT_QuickPanel.lua）经 UI.RequestPlayerOperation(EXECUTE_SCRIPT)
-- 发来的 OnStart="MPT_SurrenderVote" 请求，汇总投票并执行投降。
-- 通信完全走 EXECUTE_SCRIPT（不用 Chat 指令）；GameEvents 事件跨端同步执行，
-- 记票/判定/写属性在模拟层天然同步，无需房主分支。
--
-- 流程：
--   type="start"  ：校验（本时代本队未发起过）→ Game:SetProperty 置发起标志
--   type="vote"   ：校验（已发起、投票者同队未投过）→ 记票 → 达 >= 半数
--                   → 执行 MPT_SurrenderExecute（该队城市叛变自由城 + 标记判负）
--
-- 频率限制：每个游戏时代每队仅可发起一次投票（SetProperty 记录，跨端同步+持久化）。
-- 自定义战败范式参考乔尔定制玩法mod（RegicideVictory.lua）：不销毁城市/单位、
-- 不做引擎判负，只写 Game 属性 + 城市叛变自由城，由 UI 轮询属性显示状态。
--
-- UI 侧状态查询经 ExposedMembers.MPT.GetSurrenderVoteState（Gameplay 暴露、
-- UI 同步调用，参考 3417070280 GameBasicSupport.lua 的 ExposedMembers.PKUI 写法）。
-- ============================================================================

-- 属性键（Game 属性：跨客户端同步、随存档持久化）
-- 本时代本队已发起过投票：MPT_SURRENDER_VOTE_<era>_<team> = 1
local function MPT_VoteStartedKey(era, team) return "MPT_SURRENDER_VOTE_" .. era .. "_" .. team; end
-- 投票累计：MPT_SURRENDER_VOTES_<team> = "agreeCount/totalCount"（房主维护）
local function MPT_VotesKey(team) return "MPT_SURRENDER_VOTES_" .. team; end
-- 该队已投降：MPT_SURRENDER_TEAM_<team> = 1
local function MPT_SurrenderedKey(team) return "MPT_SURRENDER_TEAM_" .. team; end
-- 胜利队伍：全部其他队伍投降后仅剩一队 → MPT_SURRENDER_WIN_TEAM = 胜队ID
local function MPT_WinTeamKey() return "MPT_SURRENDER_WIN_TEAM"; end
-- 本时代本队投票已失败（全部投完仍未过半）：MPT_SURRENDER_VOTE_FAILED_<era>_<team> = 1
local function MPT_VoteFailedKey(era, team) return "MPT_SURRENDER_VOTE_FAILED_" .. era .. "_" .. team; end
-- 已投票人数累计：MPT_SURRENDER_VOTECOUNT_<team>（判定"全部投完"用）
local function MPT_VoteCountKey(team) return "MPT_SURRENDER_VOTECOUNT_" .. team; end
-- 投票发起时的回合号：MPT_SURRENDER_VOTE_TURN_<team>（时限判定用）
local function MPT_VoteStartTurnKey(team) return "MPT_SURRENDER_VOTE_TURN_" .. team; end

-- ============================================================================
-- 该玩家是否为观察者（LEADER_SPECTATOR，无文明；不参与投票/不计入真人总数/不弹结算）
-- ============================================================================
local function MPT_IsObserverPlayer(playerID)
	if playerID == nil or playerID < 0 then
		return false;
	end
	local pCfg = PlayerConfigurations[playerID];
	if pCfg == nil then
		return false;
	end
	return pCfg:GetLeaderTypeName() == "LEADER_SPECTATOR";
end

-- ============================================================================
-- 当前时代号（发起/查询频率限制用）
-- ============================================================================
local function MPT_GetCurrentEra()
	local pGameEras :table = Game.GetEras();
	if pGameEras == nil then
		return -1;
	end
	return pGameEras:GetCurrentEra();
end

-- ============================================================================
-- 某队当前存活的「主要文明玩家 ID」列表（观察者/AI 不算投票人）
-- ============================================================================
local function MPT_GetTeamHumanAliveMajorIDs(teamID)
	local result = {};
	for i = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local pPlayer = Players[i];
		if pPlayer ~= nil and pPlayer:IsMajor() and pPlayer:IsAlive()
			and pPlayer:GetTeam() == teamID
			and pPlayer:IsHuman()
			and not MPT_IsObserverPlayer(i) then
			table.insert(result, i);
		end
	end
	return result;
end

-- ============================================================================
-- 该队是否已投降
-- ============================================================================
function MPT_IsTeamSurrendered(teamID)
	return Game:GetProperty(MPT_SurrenderedKey(teamID)) == 1;
end

-- ============================================================================
-- 执行投降：先消灭该队所有单位的存活者，再将该队所有存活城市叛变为自由城市，
-- 最后标记该队判负。仿乔尔mod MarkTeamLost（不做引擎判负，只写属性 + 单位消灭 + 城市叛变）。
-- ============================================================================
local function MPT_SurrenderExecute(teamID)
	if Game:GetProperty(MPT_SurrenderedKey(teamID)) == 1 then
		return; -- 已投降，幂等
	end

	-- 先消灭该队所有存活玩家（主要文明）的全部单位
	for i = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local pPlayer = Players[i];
		if pPlayer ~= nil and pPlayer:IsMajor() and pPlayer:IsAlive() and pPlayer:GetTeam() == teamID then
			for _, pUnit in pPlayer:GetUnits():Members() do
				if pUnit ~= nil then
					pUnit:Kill();
				end
			end
		end
	end

	-- 城市全部叛变为自由城市
	for i = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local pPlayer = Players[i];
		if pPlayer ~= nil and pPlayer:IsMajor() and pPlayer:IsAlive() and pPlayer:GetTeam() == teamID then
			for _, pCity in pPlayer:GetCities():Members() do
				if pCity ~= nil then
					CityManager.TransferCityToFreeCities(pCity);
				end
			end
		end
	end

	Game:SetProperty(MPT_SurrenderedKey(teamID), 1);
	print("[MPT_SurrenderVote] Team " .. tostring(teamID) .. " has surrendered.");

	-- 胜利判定：统计所有「存活主要队伍」中尚未投降的队伍数
	-- 观察者/次要文明/AI 不算队伍；恰好剩 1 个未投降队伍 → 判胜
	-- （2 队局 A 投降后剩 B → 判 B 胜；3 队局须前两队都投降后剩第三队才判胜）
	if Game:GetProperty(MPT_WinTeamKey()) == nil then
		local remainingTeams = {};
		for i = 0, PlayerManager.GetWasEverAliveCount() - 1 do
			local pPlayer = Players[i];
			if pPlayer ~= nil and pPlayer:IsMajor() and pPlayer:IsAlive() then
				local t = pPlayer:GetTeam();
				if t >= 0 then
					remainingTeams[t] = true;
				end
			end
		end
		local notSurrenderedCount = 0;
		local lastTeam = nil;
		for t in pairs(remainingTeams) do
			if Game:GetProperty(MPT_SurrenderedKey(t)) ~= 1 then
				notSurrenderedCount = notSurrenderedCount + 1;
				lastTeam = t;
			end
		end
		if notSurrenderedCount == 1 and lastTeam ~= nil and notSurrenderedCount < #remainingTeams then
			Game:SetProperty(MPT_WinTeamKey(), lastTeam);
			print("[MPT_SurrenderVote] Team " .. tostring(lastTeam) .. " has won (all others surrendered).");
		end
	end
end

-- ============================================================================
-- 供 UI 查询的当前投票状态（Gameplay 侧全局函数；UI 经 ExposedMembers 或
-- 直接 Game:GetProperty 读取，无需跨端 RPC）
-- ============================================================================
function MPT_GetSurrenderVoteState(teamID)
	local era = MPT_GetCurrentEra();
	local started = Game:GetProperty(MPT_VoteStartedKey(era, teamID)) == 1;
	local votesStr = Game:GetProperty(MPT_VotesKey(teamID));
	local agreeCount = 0;
	local totalCount = 0;
	if votesStr ~= nil then
		local slash = string.find(votesStr, "/");
		if slash ~= nil then
			agreeCount = tonumber(string.sub(votesStr, 1, slash - 1)) or 0;
			totalCount = tonumber(string.sub(votesStr, slash + 1)) or 0;
		end
	end
	return {
		era = era,
		started = started,
		agreeCount = agreeCount,
		totalCount = totalCount,
		passed = MPT_IsTeamSurrendered(teamID),
		winTeam = Game:GetProperty(MPT_WinTeamKey()),
		failed = Game:GetProperty(MPT_VoteFailedKey(era, teamID)) == 1,
	};
end

-- ============================================================================
-- EXECUTE_SCRIPT 入口（GameEvents 注册名 = OnStart 传入的 "MPT_SurrenderVote"）
-- 所有客户端同步执行（GameEvents 为同步事件），记票/判定/写属性天然跨端同步，
-- 无需房主分支；Game:SetProperty 在模拟层同步并随存档持久化。
-- 防重复靠「每投票者一键」+「本时代发起标志」的幂等校验。
-- params: { type="start"|"vote", initiator, voter, team, agree }
-- ============================================================================
function OnMPT_SurrenderVoteGameEvent(localPlayerID, params)
	if params == nil or params.type == nil then
		return;
	end

	local teamID = params.team;
	if teamID == nil or teamID < 0 then
		return;
	end

	-- 该队已投降则忽略
	if MPT_IsTeamSurrendered(teamID) then
		return;
	end

	local era = MPT_GetCurrentEra();
	local startedKey = MPT_VoteStartedKey(era, teamID);

	if params.type == "start" then
		-- 发起投票：本时代本队未发起过才允许
		if Game:GetProperty(startedKey) == 1 then
			return; -- 本时代已投过（本队任何人发起过），拒绝
		end
		local initiator = params.initiator;
		if initiator == nil then
			return;
		end
		-- 校验发起人：同队、存活、人类（主要文明）、非观察者
		local pInitiator = Players[initiator];
		if pInitiator == nil or not pInitiator:IsMajor() or not pInitiator:IsAlive()
			or not pInitiator:IsHuman() or pInitiator:GetTeam() ~= teamID
			or MPT_IsObserverPlayer(initiator) then
			return;
		end

		-- 标记本时代已发起；投票者列表置空累计；记录发起回合（时限判定）
		Game:SetProperty(startedKey, 1);
		Game:SetProperty(MPT_VotesKey(teamID), "0/" .. tostring(#MPT_GetTeamHumanAliveMajorIDs(teamID)));
		Game:SetProperty(MPT_VoteCountKey(teamID), 0);
		Game:SetProperty(MPT_VoteStartTurnKey(teamID), Game.GetCurrentGameTurn());
		print("[MPT_SurrenderVote] Vote started by player " .. tostring(initiator) .. " for team " .. tostring(teamID) .. " era " .. tostring(era) .. " turn " .. tostring(Game.GetCurrentGameTurn()));
		return;
	end

	if params.type == "vote" then
		-- 投票：必须已发起过；本时代已失败则不再接受投票
		if Game:GetProperty(startedKey) ~= 1 then
			return;
		end
		if Game:GetProperty(MPT_VoteFailedKey(era, teamID)) == 1 then
			return;
		end
		local voter = params.voter;
		if voter == nil then
			return;
		end
		-- 校验投票者：同队、存活、人类（主要文明）、非观察者
		local pVoter = Players[voter];
		if pVoter == nil or not pVoter:IsMajor() or not pVoter:IsAlive()
			or not pVoter:IsHuman() or pVoter:GetTeam() ~= teamID
			or MPT_IsObserverPlayer(voter) then
			return;
		end

		-- 记录该投票者已投（防止重复投票：每个投票者一键）
		local voterKey = "MPT_SURRENDER_VOTED_" .. teamID .. "_" .. voter;
		if Game:GetProperty(voterKey) == 1 then
			return; -- 已投过，忽略
		end
		Game:SetProperty(voterKey, 1);

		-- 累计票数
		local votesStr = Game:GetProperty(MPT_VotesKey(teamID));
		local agreeCount = 0;
		local totalCount = 0;
		if votesStr ~= nil then
			local slash = string.find(votesStr, "/");
			if slash ~= nil then
				agreeCount = tonumber(string.sub(votesStr, 1, slash - 1)) or 0;
				totalCount = tonumber(string.sub(votesStr, slash + 1)) or 0;
			end
		end
		if params.agree == true then
			agreeCount = agreeCount + 1;
		end
		Game:SetProperty(MPT_VotesKey(teamID), tostring(agreeCount) .. "/" .. tostring(totalCount));
		print("[MPT_SurrenderVote] Player " .. tostring(voter) .. " voted agree=" .. tostring(params.agree) .. " (" .. agreeCount .. "/" .. totalCount .. ")");

		-- 过半判定：agreeCount >= totalCount/2 且至少 1 票
		if totalCount > 0 and agreeCount >= totalCount / 2 then
			MPT_SurrenderExecute(teamID);
			return;
		end

		-- 失败判定：全部应投者投完仍未过半 → 本时代本队投票失败
		-- （UI 侧检测到失败后保留面板到回合结束再隐藏）
		local voteCount = (Game:GetProperty(MPT_VoteCountKey(teamID)) or 0) + 1;
		Game:SetProperty(MPT_VoteCountKey(teamID), voteCount);
		if totalCount > 0 and voteCount >= totalCount
			and Game:GetProperty(MPT_VoteFailedKey(era, teamID)) ~= 1 then
			Game:SetProperty(MPT_VoteFailedKey(era, teamID), 1);
			print("[MPT_SurrenderVote] Vote failed for team " .. tostring(teamID) .. " era " .. tostring(era) .. " (agree " .. agreeCount .. "/" .. totalCount .. " not majority).");
		end
		return;
	end
end

GameEvents.MPT_SurrenderVote.Add(OnMPT_SurrenderVoteGameEvent);

-- ============================================================================
-- 投票时限：当前回合结束后的下一个回合结束时（约跨 2 个回合）关闭投票，
-- 未过半则按「拒绝」结果处理（写 failed 属性，UI 检测后隐藏投票面板）。
-- 发起回合 T：T 结束（边界1）→ T+1 期间仍可投 → T+1 结束（边界2）关闭。
-- 即当前回合号 >= 发起回合号 + 2 时关闭。
-- ============================================================================
local function MPT_CheckVoteTimeouts()
	local currentTurn :number = Game.GetCurrentGameTurn();
	local era = MPT_GetCurrentEra();

	-- 遍历所有曾存在的队伍，检查有活跃投票（本时代已发起、未失败、未投降）的超时
	local checkedTeams = {};
	for i = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local pPlayer = Players[i];
		if pPlayer ~= nil and pPlayer:IsMajor() then
			local teamID = pPlayer:GetTeam();
			if teamID ~= nil and teamID >= 0 and checkedTeams[teamID] ~= true then
				checkedTeams[teamID] = true;
				if Game:GetProperty(MPT_VoteStartedKey(era, teamID)) == 1
					and Game:GetProperty(MPT_VoteFailedKey(era, teamID)) ~= 1
					and not MPT_IsTeamSurrendered(teamID) then
					local startTurn = Game:GetProperty(MPT_VoteStartTurnKey(teamID));
					if startTurn ~= nil and currentTurn >= startTurn + 2 then
						Game:SetProperty(MPT_VoteFailedKey(era, teamID), 1);
						print("[MPT_SurrenderVote] Vote timed out for team " .. tostring(teamID) .. " era " .. tostring(era) .. " (rejected, started turn " .. tostring(startTurn) .. " now " .. tostring(currentTurn) .. ").");
					end
				end
			end
		end
	end
end

GameEvents.OnGameTurnStarted.Add(MPT_CheckVoteTimeouts);

-- ============================================================================
-- ExposedMembers 暴露：UI 侧同步查询投票状态（Gameplay 定义、UI 读取，
-- 参考 3417070280 GameBasicSupport.lua 的 ExposedMembers.PKUI 写法）
-- ============================================================================
ExposedMembers.MPT = ExposedMembers.MPT or {};
ExposedMembers.MPT.GetSurrenderVoteState = MPT_GetSurrenderVoteState;
ExposedMembers.MPT.IsTeamSurrendered = MPT_IsTeamSurrendered;

print("[MPT_SurrenderVote] Gameplay script initialized.");
