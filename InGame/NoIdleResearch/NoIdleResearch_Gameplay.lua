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
-- 其余不移植项：源实现 next(pPlayerCulture)==nil 的死代码检查丢弃；硬编码
-- 0..58 / 0..73 循环（全 DLC 下后期科技/市政索引越界遗漏）改为 GameInfo 全量遍历。
--
-- 确定性（联机无 OOS）：候选枚举/前置判定/费用进度/产出全部为模拟层确定性状态，
-- GameInfo 静态表按行序（Index 升序）遍历，并列取 Index 小者，全部客户端同回合
-- 得出同一选择；全房需同装本 mod（条目4.1 模组校验保证）。
-- ============================================================================

-- 科技/市政静态候选表：{ {Index=行Index, Prereq=前置Index 或 -1} ... } 按 Index 升序
local m_techList :table = {};
local m_civicList :table = {};
-- 市政进度读取方式（首次补选时探测一次并缓存）：技能库实测 GetCulturalProgress 在
-- Gameplay 侧为 nil（UI 侧才有），按可用性三级回退
local m_civicProgressMode :number = 0;	-- 0=未探测 1=GetCulturalProgress 2=GetTurnsToProgressCivic×每回合琴 3=纯费用排序

-- ============================================================================
-- 构建静态候选表：PrereqTech/PrereqCivic 列存前置类型名（原版 MapTacks.lua 同款
-- 字符串语义），先建 type 名 → Index 映射再回填前置 Index；GameInfo 行序即 Index
-- 升序，table.insert 保序，ipairs 遍历天然确定
-- ============================================================================
local function MPT_NoIdleResearch_BuildStaticTables()
	local techTypeToIndex :table = {};
	local civicTypeToIndex :table = {};
	for row in GameInfo.Technologies() do
		techTypeToIndex[row.TechnologyType] = row.Index;
	end
	for row in GameInfo.Civics() do
		civicTypeToIndex[row.CivicType] = row.Index;
	end
	for row in GameInfo.Technologies() do
		local prereq :number = -1;
		if row.PrereqTech ~= nil and techTypeToIndex[row.PrereqTech] ~= nil then
			prereq = techTypeToIndex[row.PrereqTech];
		end
		table.insert(m_techList, { Index = row.Index, Prereq = prereq });
	end
	for row in GameInfo.Civics() do
		local prereq :number = -1;
		if row.PrereqCivic ~= nil and civicTypeToIndex[row.PrereqCivic] ~= nil then
			prereq = civicTypeToIndex[row.PrereqCivic];
		end
		table.insert(m_civicList, { Index = row.Index, Prereq = prereq });
	end
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
-- 在「可研究」（未研究且前置已达成）的科技中选剩余研究量（费用-进度）最大者，
-- 无候选返回 -1。GetResearchCost 含游戏速度/时代全部修正、GetResearchProgress
-- 为 Gameplay 侧可用 API（条目14 技能库实测背书）
-- ============================================================================
local function MPT_NoIdleResearch_PickTech(pTechs :table)
	local bestIndex :number = -1;
	local bestRemaining :number = -1;
	for _, entry in ipairs(m_techList) do
		local techIndex :number = entry.Index;
		if not pTechs:HasTech(techIndex) and (entry.Prereq == -1 or pTechs:HasTech(entry.Prereq)) then
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
	for _, entry in ipairs(m_civicList) do
		local civicIndex :number = entry.Index;
		if not pCulture:HasCivic(civicIndex) and (entry.Prereq == -1 or pCulture:HasCivic(entry.Prereq)) then
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

-- 静态候选表构建（GameInfo 只读静态数据，脚本载入时已就绪）
MPT_NoIdleResearch_BuildStaticTables();
print("[MPT_NoIdleResearch] Gameplay script initialized (techs " .. #m_techList .. ", civics " .. #m_civicList .. ").");
