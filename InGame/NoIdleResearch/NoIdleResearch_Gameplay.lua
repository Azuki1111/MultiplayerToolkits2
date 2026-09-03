-- ============================================================================
-- 条目31：禁止空过研究（Gameplay 侧）
--
-- 移植工坊 3475004450（Team PVP Balanced mod）exploits/culture_fix.lua：
-- 回合开始时，为忘记选择科技/市政的玩家自动选择一个，避免空过回合浪费产出。
--
-- 相对源实现的三项用户裁决与优化：
--   1. 选择算法：源实现选「id 最小的未研究项」（无视前置，会把前置未达成的项塞进
--      研究队列）；本版在「可研究」（前置已达成）的候选中选「剩余研究量最大」者
--      （剩余 = 费用 - 已积累进度，科技按瓶、市政按琴；空过期间积攒的产出会在选中
--      时一次性灌入，选剩余量最大者溢出浪费最少）；并列取 Index 小者（确定性）。
--   2. 作用范围仅真人玩家（源实现遍历全部主要文明含 AI，AI 由引擎决策不会空过），
--      排除 LEADER_SPECTATOR 观察者；不做任何难度排除（源实现排除特定
--      HandicapID 2021024770，属其联机环境特有设置，用户裁决不移植）。
--   3. 开关 = 开局高级选项参数 MPT_NO_IDLE_RESEARCH（modinfo 同名 criteria 门控本
--      文件加载，默认关零开销）。不放条目12游内设置面板：本功能是 Gameplay 模拟
--      行为须全房一致，面板开关写每机本地 Configuration 值会引入 OOS 风险。
--
-- 条目31修复一：「可研究」判定重建（用户实测前置未解锁的未来科技被自动选中）——
--   Technologies/Civics 主表并无 PrereqTech/PrereqCivic 列（v1 误读恒为 nil → 全体
--   判为无前置可研究），前置关系在 TechnologyPrereqs/CivicPrereqs 邻接表，多前置行
--   为 AND。修复 = 原版面板同款约束 API：PlayerTechs:CanResearch(Index)（TechTree.lua
--   L1107 / ResearchChooser.lua L71）与 PlayerCulture:CanProgress(Index)
--  （CivicsChooser.lua L68），Gameplay 侧首次补选探测，nil 则回退手写邻接表 AND 判定
--  （实测：CanResearch 在 Gameplay 侧可用（mode=1），CanProgress 为 nil（mode=2））。
--
-- 条目31修复二：随机前置节点排除（用户实测市政 mode=2 仍误选 CIVIC_SMART_POWER_
--   DOCTRINE）——GS 对未来时代节点采用「随机前置」机制：Civics_XP2/Technologies_XP2
--   表 RandomPrereqs="true" 的行（市政 6 项：智能权力教义/全球变暖缓解/信息战/出走
--   imperative/文化霸权/未来市政；科技 8 项：海上家园/高级AI/高级能源电池等）的
--   前置由引擎每局随机抽定，邻接表中合法地没有行，手动图永远验证不了 → v2 判成
--   「无前置根节点」→ argmax 剩余量恒选最贵者。修复 = mode2 判定追加两条硬约束：
--   ①命中随机前置集合 → 不自动补选（交还玩家手选）；②无前置行且非远古根节点
--  （合法根 = 陶术/畜牧/采矿/法典，EraType=ERA_ANCIENT）→ 不自动补选（对同机制的
--   其他 mod 内容也保守兜底）。mode1 引擎判定天然知道随机前置，不受影响。
--
-- 其余不移植项：源实现 next(pPlayerCulture)==nil 的死代码检查丢弃；硬编码
-- 0..58 / 0..73 循环（全 DLC 下后期科技/市政索引越界遗漏）改为 GameInfo 全量遍历。
--
-- 确定性（联机无 OOS）：候选枚举/前置判定/费用进度/产出全部为模拟层确定性状态
--（随机前置集合来自静态数据表，同样确定），GameInfo 静态表按行序（Index 升序）
-- 遍历，并列取 Index 小者，全部客户端同回合得出同一选择；判定方式探测结果仅取决
-- 于上下文（全机同 context 同结果）；全房需同装本 mod（条目4.1 模组校验保证）。
-- ============================================================================

-- 静态候选表：Index 升序数组（GameInfo 行序即 Index 序）、前置邻接图（Index → 前置
-- Index 数组）、远古根节点标记（无前置行时唯一可补选的合法形态）、随机前置集合
--（Civics_XP2/Technologies_XP2 的 RandomPrereqs 行，前置由引擎随机抽定无法本地验证）
local m_techList :table = {};
local m_civicList :table = {};
local m_techPrereqs :table = {};
local m_civicPrereqs :table = {};
local m_techNoEdgeOk :table = {};
local m_civicNoEdgeOk :table = {};
local m_techRandom :table = {};
local m_civicRandom :table = {};
-- 可研究判定方式（首次补选时探测一次并缓存）：1=引擎 API（原版面板同款）
-- 2=手动邻接表 AND 回退（引擎 API 在 Gameplay 侧为 nil 时）
local m_techCheckMode :number = 0;
local m_civicCheckMode :number = 0;
-- 市政进度读取方式（首次补选时探测一次并缓存）：技能库实测 GetCulturalProgress 在
-- Gameplay 侧为 nil（UI 侧才有），按可用性三级回退
local m_civicProgressMode :number = 0;	-- 0=未探测 1=GetCulturalProgress 2=GetTurnsToProgressCivic×每回合琴 3=纯费用排序

-- ============================================================================
-- 构建静态候选表与前置邻接图：前置在 TechnologyPrereqs（Technology/PrereqTech 两列）
-- 与 CivicPrereqs（Civic/PrereqCivic）邻接表，多前置行为 AND（如 TECH_COMPUTERS 前置
-- Electricity+Radio）；主表的 PrereqTech/PrereqCivic 列不存在（修复一根因）。
-- GameInfo 行序即 Index 升序，table.insert 保序，ipairs 天然确定
-- ============================================================================
local function MPT_NoIdleResearch_BuildStaticTables()
	local techTypeToIndex = {};
	local civicTypeToIndex = {};
	for row in GameInfo.Technologies() do
		if row.TechnologyType ~= nil and row.Index ~= nil then
			techTypeToIndex[row.TechnologyType] = row.Index;
			table.insert(m_techList, row.Index);
			if row.EraType == "ERA_ANCIENT" then
				m_techNoEdgeOk[row.Index] = true;
			end
		end
	end
	for row in GameInfo.Civics() do
		if row.CivicType ~= nil and row.Index ~= nil then
			civicTypeToIndex[row.CivicType] = row.Index;
			table.insert(m_civicList, row.Index);
			if row.EraType == "ERA_ANCIENT" then
				m_civicNoEdgeOk[row.Index] = true;
			end
		end
	end
	for row in GameInfo.TechnologyPrereqs() do
		local iTech = techTypeToIndex[row.Technology];
		local iPrereq = techTypeToIndex[row.PrereqTech];
		if iTech ~= nil and iPrereq ~= nil then
			local list = m_techPrereqs[iTech];
			if list == nil then
				list = {};
				m_techPrereqs[iTech] = list;
			end
			table.insert(list, iPrereq);
		end
	end
	for row in GameInfo.CivicPrereqs() do
		local iCivic = civicTypeToIndex[row.Civic];
		local iPrereq = civicTypeToIndex[row.PrereqCivic];
		if iCivic ~= nil and iPrereq ~= nil then
			local list = m_civicPrereqs[iCivic];
			if list == nil then
				list = {};
				m_civicPrereqs[iCivic] = list;
			end
			table.insert(list, iPrereq);
		end
	end
	-- GS 随机前置集合（表仅 GS 环境存在，nil 守卫；RandomPrereqs 兼容布尔/字符串两种暴露形态）
	if GameInfo.Civics_XP2 ~= nil then
		for row in GameInfo.Civics_XP2() do
			if row.CivicType ~= nil and (row.RandomPrereqs == true or row.RandomPrereqs == "true") then
				local iCivic = civicTypeToIndex[row.CivicType];
				if iCivic ~= nil then
					m_civicRandom[iCivic] = true;
				end
			end
		end
	end
	if GameInfo.Technologies_XP2 ~= nil then
		for row in GameInfo.Technologies_XP2() do
			if row.TechnologyType ~= nil and (row.RandomPrereqs == true or row.RandomPrereqs == "true") then
				local iTech = techTypeToIndex[row.TechnologyType];
				if iTech ~= nil then
					m_techRandom[iTech] = true;
				end
			end
		end
	end
end

-- ============================================================================
-- 探测可研究判定方式（科技/市政各自独立，首次使用时调用一次，结果缓存全局面复用；
-- 结果仅取决于 Lua 上下文，全机一致不影响确定性）
-- ============================================================================
local function MPT_NoIdleResearch_ProbeTechCheckMode(pTechs :table)
	if pTechs.CanResearch ~= nil then
		m_techCheckMode = 1;
	else
		m_techCheckMode = 2;
	end
	print("[MPT_NoIdleResearch] tech researchable-check mode = " .. ((m_techCheckMode == 1) and "1 (engine CanResearch, vanilla TechTree panel same)" or "2 (manual TechnologyPrereqs graph fallback)"));
end

local function MPT_NoIdleResearch_ProbeCivicCheckMode(pCulture :table)
	if pCulture.CanProgress ~= nil then
		m_civicCheckMode = 1;
	else
		m_civicCheckMode = 2;
	end
	print("[MPT_NoIdleResearch] civic researchable-check mode = " .. ((m_civicCheckMode == 1) and "1 (engine CanProgress, vanilla CivicsChooser panel same)" or "2 (manual CivicPrereqs graph fallback)"));
end

-- ============================================================================
-- 「可研究」判定（未研究的过滤在外层候选循环）：优先原版面板同款约束 API
--（TechTree.lua L1107 READY 判定 / CivicsChooser.lua L68 入选条件），引擎 API 在
-- Gameplay 侧不可用时回退手写判定：随机前置集合成员直接排除（前置由引擎随机抽定
-- 无法本地验证）；邻接表 AND 全部前置已研究；无前置行仅远古根节点放行
-- ============================================================================
local function MPT_NoIdleResearch_IsTechResearchable(pTechs :table, techIndex :number)
	if m_techCheckMode == 0 then
		MPT_NoIdleResearch_ProbeTechCheckMode(pTechs);
	end
	if m_techCheckMode == 1 then
		return pTechs:CanResearch(techIndex);
	end
	if m_techRandom[techIndex] then
		return false;
	end
	local prereqs = m_techPrereqs[techIndex];
	if prereqs ~= nil then
		for _, prereqIndex in ipairs(prereqs) do
			if not pTechs:HasTech(prereqIndex) then
				return false;
			end
		end
	elseif not m_techNoEdgeOk[techIndex] then
		return false;
	end
	return true;
end

local function MPT_NoIdleResearch_IsCivicResearchable(pCulture :table, civicIndex :number)
	if m_civicCheckMode == 0 then
		MPT_NoIdleResearch_ProbeCivicCheckMode(pCulture);
	end
	if m_civicCheckMode == 1 then
		return pCulture:CanProgress(civicIndex);
	end
	if m_civicRandom[civicIndex] then
		return false;
	end
	local prereqs = m_civicPrereqs[civicIndex];
	if prereqs ~= nil then
		for _, prereqIndex in ipairs(prereqs) do
			if not pCulture:HasCivic(prereqIndex) then
				return false;
			end
		end
	elseif not m_civicNoEdgeOk[civicIndex] then
		return false;
	end
	return true;
end

-- ============================================================================
-- 探测市政进度读取方式（首次补选时调用一次，结果缓存全局面复用）
-- ============================================================================
local function MPT_NoIdleResearch_ProbeCivicMode(pCulture :table)
	if pCulture.GetCulturalProgress ~= nil then
		m_civicProgressMode = 1;
	elseif pCulture.GetTurnsToProgressCivic ~= nil then
		m_civicProgressMode = 2;
	else
		m_civicProgressMode = 3;
	end
end

-- ============================================================================
-- 在「可研究」的科技中选剩余研究量（费用-进度）最大者，无候选返回 -1。
-- GetResearchCost 含游戏速度/时代全部修正、GetResearchProgress 为 Gameplay 侧可用 API
--（条目14 技能库实测背书）
-- ============================================================================
local function MPT_NoIdleResearch_PickTech(pTechs :table)
	local bestIndex :number = -1;
	local bestRemaining :number = -1;
	for _, techIndex in ipairs(m_techList) do
		if not pTechs:HasTech(techIndex) and MPT_NoIdleResearch_IsTechResearchable(pTechs, techIndex) then
			local remaining :number = pTechs:GetResearchCost(techIndex) - pTechs:GetResearchProgress(techIndex);
			if remaining > bestRemaining then
				bestRemaining = remaining;
				bestIndex = techIndex;
			end
		end
	end
	return bestIndex;
end

-- ============================================================================
-- 在「可研究」的市政中选剩余研究量（费用-进度）最大者，无候选返回 -1。
-- 进度读取按 m_civicProgressMode 三级回退：GetCultureCost 为 Gameplay 侧可用 API
--（技能库实测）；回退 2 的「剩余回合×每回合琴」≥ 真实剩余量（向上取整），同一玩家
-- 每回合琴相同故排序等价；回退 3 纯费用排序（鼓舞进度与费用成正比，绝大多数场景
-- 与剩余量排序一致）
-- ============================================================================
local function MPT_NoIdleResearch_PickCivic(pCulture :table)
	if m_civicProgressMode == 0 then
		MPT_NoIdleResearch_ProbeCivicMode(pCulture);
	end
	local culturePerTurn :number = pCulture:GetCultureYield();
	local bestIndex :number = -1;
	local bestRemaining :number = -1;
	for _, civicIndex in ipairs(m_civicList) do
		if not pCulture:HasCivic(civicIndex) and MPT_NoIdleResearch_IsCivicResearchable(pCulture, civicIndex) then
			local remaining :number = pCulture:GetCultureCost(civicIndex);
			if m_civicProgressMode == 1 then
				remaining = remaining - pCulture:GetCulturalProgress(civicIndex);
			elseif m_civicProgressMode == 2 then
				remaining = pCulture:GetTurnsToProgressCivic(civicIndex) * culturePerTurn;
			end
			if remaining > bestRemaining then
				bestRemaining = remaining;
				bestIndex = civicIndex;
			end
		end
	end
	return bestIndex;
end

-- ============================================================================
-- 回合开始主逻辑：跳过开局回合（此时所有玩家都未选，补选会剥夺玩家自主选择，
-- 同源实现）；遍历存活主要文明中的真人（排除观察者/AI，无难度排除）；科技/市政
-- 任一为空（-1）且对应产出 >0（无城定居者阶段产出为 0，不补选，同源实现）时补选
-- ============================================================================
local function MPT_NoIdleResearch_OnGameTurnStarted()
	local currentTurn :number = Game.GetCurrentGameTurn();
	if currentTurn == GameConfiguration.GetStartTurn() then
		return;
	end
	for _, iPlayerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
		local pPlayer = Players[iPlayerID];
		local pCfg = PlayerConfigurations[iPlayerID];
		if pPlayer ~= nil and pCfg ~= nil
			and pCfg:GetLeaderTypeName() ~= "LEADER_SPECTATOR"
			and pPlayer:IsHuman() then

			-- 市政：未选且有琴产出 → 补选
			local pCulture :table = pPlayer:GetCulture();
			if pCulture ~= nil and pCulture:GetProgressingCivic() == -1 and pCulture:GetCultureYield() > 0 then
				local iCivic :number = MPT_NoIdleResearch_PickCivic(pCulture);
				if iCivic ~= -1 then
					pCulture:SetProgressingCivic(iCivic);
					print("[MPT_NoIdleResearch] player " .. iPlayerID .. " forgot to pick a civic, auto-picked " .. GameInfo.Civics[iCivic].CivicType);
				end
			end

			-- 科技：未选且有瓶产出 → 补选
			local pTechs :table = pPlayer:GetTechs();
			if pTechs ~= nil and pTechs:GetResearchingTech() == -1 and pTechs:GetScienceYield() > 0 then
				local iTech :number = MPT_NoIdleResearch_PickTech(pTechs);
				if iTech ~= -1 then
					pTechs:SetResearchingTech(iTech);
					print("[MPT_NoIdleResearch] player " .. iPlayerID .. " forgot to pick a tech, auto-picked " .. GameInfo.Technologies[iTech].TechnologyType);
				end
			end
		end
	end
end

GameEvents.OnGameTurnStarted.Add(MPT_NoIdleResearch_OnGameTurnStarted);

-- 静态候选表与前置邻接图构建（GameInfo 只读静态数据，脚本载入时已就绪）
MPT_NoIdleResearch_BuildStaticTables();
local mpt_techEdges :number = 0;
for _, list in pairs(m_techPrereqs) do
	mpt_techEdges = mpt_techEdges + #list;
end
local mpt_civicEdges :number = 0;
for _, list in pairs(m_civicPrereqs) do
	mpt_civicEdges = mpt_civicEdges + #list;
end
local mpt_techRandomCount :number = 0;
for _ in pairs(m_techRandom) do
	mpt_techRandomCount = mpt_techRandomCount + 1;
end
local mpt_civicRandomCount :number = 0;
for _ in pairs(m_civicRandom) do
	mpt_civicRandomCount = mpt_civicRandomCount + 1;
end
print("[MPT_NoIdleResearch] Gameplay script initialized (techs " .. #m_techList .. ", tech-prereq-edges " .. mpt_techEdges .. ", tech-random-prereqs " .. mpt_techRandomCount .. ", civics " .. #m_civicList .. ", civic-prereq-edges " .. mpt_civicEdges .. ", civic-random-prereqs " .. mpt_civicRandomCount .. ").");
