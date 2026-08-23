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
-- 某队当前存活的「主要文明玩家 ID」列表（含观察者过滤；AI 不算投票人）
-- ============================================================================
local function MPT_GetTeamHumanAliveMajorIDs(teamID)
	local result = {};
	for i = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local pPlayer = Players[i];
		if pPlayer ~= nil and pPlayer:IsMajor() and pPlayer:IsAlive()
			and pPlayer:GetTeam() == teamID
			and PlayerConfigurations[i] ~= nil
			and not PlayerConfigurations[i]:IsAIPlayer() then
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
-- 执行投降：该队所有存活的非自由城城市叛变为自由城市，并标记该队判负。
-- 仿乔尔mod MarkTeamLost（不做引擎判负，只写属性 + 城市叛变）。
-- ============================================================================
local function MPT_SurrenderExecute(teamID)
	if Game:GetProperty(MPT_SurrenderedKey(teamID)) == 1 then
		return; -- 已投降，幂等
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
		-- 校验发起人：同队、存活、人类、非观察者
		local pInitiator = Players[initiator];
		if pInitiator == nil or not pInitiator:IsMajor() or not pInitiator:IsAlive()
			or pInitiator:GetTeam() ~= teamID then
			return;
		end

		-- 标记本时代已发起；投票者列表置空累计
		Game:SetProperty(startedKey, 1);
		Game:SetProperty(MPT_VotesKey(teamID), "0/" .. tostring(#MPT_GetTeamHumanAliveMajorIDs(teamID)));
		print("[MPT_SurrenderVote] Vote started by player " .. tostring(initiator) .. " for team " .. tostring(teamID) .. " era " .. tostring(era));
		return;
	end

	if params.type == "vote" then
		-- 投票：必须已发起过
		if Game:GetProperty(startedKey) ~= 1 then
			return;
		end
		local voter = params.voter;
		if voter == nil then
			return;
		end
		-- 校验投票者：同队、存活、人类
		local pVoter = Players[voter];
		if pVoter == nil or not pVoter:IsMajor() or not pVoter:IsAlive()
			or pVoter:GetTeam() ~= teamID then
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
		end
		return;
	end
end

GameEvents.MPT_SurrenderVote.Add(OnMPT_SurrenderVoteGameEvent);

-- ============================================================================
-- ExposedMembers 暴露：UI 侧同步查询投票状态（Gameplay 定义、UI 读取，
-- 参考 3417070280 GameBasicSupport.lua 的 ExposedMembers.PKUI 写法）
-- ============================================================================
ExposedMembers.MPT = ExposedMembers.MPT or {};
ExposedMembers.MPT.GetSurrenderVoteState = MPT_GetSurrenderVoteState;
ExposedMembers.MPT.IsTeamSurrendered = MPT_IsTeamSurrendered;

print("[MPT_SurrenderVote] Gameplay script initialized.");
