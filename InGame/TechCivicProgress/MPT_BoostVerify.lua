-- ============================================================================
-- 临时验证脚本：Estimates 新公式 vs TriggerBoost 实际值对比（MPT_BoostVerify）
-- 公式（条目14 实测校准）：boost ≈ floor(realCost×pct/100) - (1 + floor(realCost/1000))
-- 验证：0 进度纯 boost + 50% 进度叠加，逐个打印估算/实际/差值。
-- 挂载：AddGameplayScripts 临时注册（测试完移除，不递增 Version）。
-- ============================================================================

local m_ran : boolean = false;

-- ============================================================================
-- 本地实现：modifier 附加 boost 百分比（同 TechAndCivicSupport.MPT_GetExtraBoostFromModifiers，
-- 中国等文明 EFFECT_ADJUST_TECHNOLOGY_BOOST Amount=10 → 40+10=50%）
-- ============================================================================
local m_cachedTurn : number = -1;
local m_cachedTechExtra : number = 0;
local m_cachedCivicExtra : number = 0;
local function MPT_GetExtraBoostFromModifiers(playerID : number, isTech : boolean)
	if GameEffects == nil then return 0; end
	local cur : number = Game.GetCurrentGameTurn();
	if playerID ~= Game.GetLocalPlayer() then return 0; end
	if cur == m_cachedTurn then
		if isTech then return m_cachedTechExtra; else return m_cachedCivicExtra; end
	end
	m_cachedTurn = cur;
	local techR : number = 0;
	local civicR : number = 0;
	for _, modifierObjID in ipairs(GameEffects.GetModifiers()) do
		local isActive : boolean = GameEffects.GetModifierActive(modifierObjID);
		local ownerObjID : number = GameEffects.GetModifierOwner(modifierObjID);
		if isActive and (GameEffects.GetObjectsPlayerId(ownerObjID) == playerID) then
			local modifierDef : table = GameEffects.GetModifierDefinition(modifierObjID);
			local modifierRow : table = modifierDef and GameInfo.Modifiers[modifierDef.Id] or nil;
			local modifierType : string = modifierRow and modifierRow.ModifierType or nil;
			if modifierType then
				local modifierTypeRow : table = GameInfo.DynamicModifiers[modifierType];
				if modifierTypeRow then
					if modifierTypeRow.EffectType == 'EFFECT_ADJUST_TECHNOLOGY_BOOST' then
						techR = techR + modifierDef.Arguments.Amount;
					end
					if modifierTypeRow.EffectType == 'EFFECT_ADJUST_CIVIC_BOOST' then
						civicR = civicR + modifierDef.Arguments.Amount;
					end
				end
			end
		end
	end
	m_cachedTechExtra = techR;
	m_cachedCivicExtra = civicR;
	if isTech then return m_cachedTechExtra; else return m_cachedCivicExtra; end
end

-- ============================================================================
-- 新公式估算（0 进度纯 boost）
-- ============================================================================
local function MPT_EstimateBoost(cost : number, pct : number)
	local boostRaw : number = math.floor(cost * pct / 100);
	local penalty : number = 1 + math.floor(cost / 1000);
	return math.max(boostRaw - penalty, 0);
end

-- ============================================================================
-- 对单个玩家执行验证
-- ============================================================================
local function MPT_BoostVerify_ForPlayer(pPlayer : table, playerID : number)
	local pTechs : table = pPlayer:GetTechs();
	local pCfg : table = PlayerConfigurations[playerID];
	local leaderType : string = pCfg and pCfg:GetLeaderTypeName() or "?";
	print(string.format("==== [MPT_Verify] Player %s leader=%s ====", tostring(playerID), tostring(leaderType)));

	if type(pTechs.SetTech) ~= "function" or type(pTechs.TriggerBoost) ~= "function" then
		print("[MPT_Verify] modify APIs unavailable, skip");
		return;
	end

	-- 采样科技（覆盖 50~3000 成本；跳过已触发 boost 的）
	local targets : table = {
		"TECH_WRITING", "TECH_MASONRY", "TECH_CURRENCY", "TECH_MATHEMATICS",
		"TECH_EDUCATION", "TECH_GUNPOWDER", "TECH_SQUARE_RIGGING",
		"TECH_INDUSTRIALIZATION", "TECH_ECONOMICS", "TECH_ELECTRICITY",
		"TECH_TELECOMMUNICATIONS", "TECH_ROBOTICS", "TECH_OFFWORLD_MISSION",
		"TECH_ASTROLOGY", "TECH_IRRIGATION", "TECH_MILITARY_TACTICS",
		"TECH_CASTLES", "TECH_PRINTING", "TECH_STEAM_POWER", "TECH_FLIGHT",
	};

	-- 1. 0 进度纯 boost 对比（估算用 实际百分比 = Boosts 表 + modifier 附加）
	print("--- [Verify-A] pure boost (progress=0) ---");
	local techExtra : number = MPT_GetExtraBoostFromModifiers(playerID, true);
	local civicExtra : number = MPT_GetExtraBoostFromModifiers(playerID, false);
	print(string.format("[Verify-A] player %s: techExtra=%s civicExtra=%s", tostring(playerID), tostring(techExtra), tostring(civicExtra)));
	local okCount : number = 0;
	local diffMax : number = 0;
	local total : number = 0;
	for _, techType in ipairs(targets) do
		local kTech : table = GameInfo.Technologies[techType];
		if kTech then
			local iTech : number = kTech.Index;
			local boostPct : number = 0;
			for row in GameInfo.Boosts() do
				if row.TechnologyType == techType then boostPct = row.Boost; break; end
			end
			local hadTech : boolean = pTechs:HasTech(iTech);
			local oldProgress : number = pTechs:GetResearchProgress(iTech);
			pTechs:SetTech(iTech, false);
			pTechs:SetResearchProgress(iTech, 0);
			if not pTechs:HasBoostBeenTriggered(iTech) then
				local realCost : number = pTechs:GetResearchCost(iTech);
				local pctEff : number = boostPct + techExtra;		-- 实际百分比（含文明修正）
				local estimate : number = MPT_EstimateBoost(realCost, pctEff);
				pTechs:TriggerBoost(iTech, 1);
				local actual : number = pTechs:GetResearchProgress(iTech);
				local diff : number = estimate - actual;
				if diff == 0 then okCount = okCount + 1; end
				if math.abs(diff) > diffMax then diffMax = math.abs(diff); end
				total = total + 1;
				print(string.format("[Verify-A] %-24s cost=%-6s pct=%s+%s est=%-6s actual=%-6s diff=%s %s",
					techType, tostring(realCost), tostring(boostPct), tostring(techExtra), tostring(estimate), tostring(actual),
					tostring(diff), diff == 0 and "OK" or "<--"));
			else
				print(string.format("[Verify-A] %-24s SKIP (already triggered)", techType));
			end
			pTechs:SetResearchProgress(iTech, oldProgress);
			pTechs:SetTech(iTech, hadTech);
		end
	end
	print(string.format("[Verify-A] 精确 %s/%s，最大误差 %s", tostring(okCount), tostring(total), tostring(diffMax)));

	-- 2. 50% 进度 + boost 对比（验证叠加 + 封顶；用新科技避免重复）
	print("--- [Verify-B] boost with 50% progress ---");
	local halfTargets : table = { "TECH_THE_WHEEL", "TECH_BRONZE_WORKING", "TECH_CELESTIAL_NAVIGATION", "TECH_APPRENTICESHIP", "TECH_STIRRUPS" };
	for _, techType in ipairs(halfTargets) do
		local kTech : table = GameInfo.Technologies[techType];
		if kTech then
			local iTech : number = kTech.Index;
			local boostPct : number = 0;
			for row in GameInfo.Boosts() do
				if row.TechnologyType == techType then boostPct = row.Boost; break; end
			end
			local hadTech : boolean = pTechs:HasTech(iTech);
			local oldProgress : number = pTechs:GetResearchProgress(iTech);
			local realCost : number = pTechs:GetResearchCost(iTech);
			pTechs:SetTech(iTech, false);
			local halfProgress : number = math.floor(realCost / 2);
			pTechs:SetResearchProgress(iTech, halfProgress);
			if not pTechs:HasBoostBeenTriggered(iTech) then
				-- 新公式：min(progress + boost, cost)（封顶），估算用实际百分比（含文明修正）
				local pctEff : number = boostPct + techExtra;
				local estimate : number = math.min(halfProgress + MPT_EstimateBoost(realCost, pctEff), realCost);
				pTechs:TriggerBoost(iTech, 1);
				local actual : number = pTechs:GetResearchProgress(iTech);
				local diff : number = estimate - actual;
				print(string.format("[Verify-B] %-24s cost=%-6s half=%-6s pct=%s+%s est=%-6s actual=%-6s diff=%s %s",
					techType, tostring(realCost), tostring(halfProgress), tostring(boostPct), tostring(techExtra),
					tostring(estimate), tostring(actual), tostring(diff), diff == 0 and "OK" or "<--"));
			else
				print(string.format("[Verify-B] %-24s SKIP (already triggered)", techType));
			end
			pTechs:SetResearchProgress(iTech, oldProgress);
			pTechs:SetTech(iTech, hadTech);
		end
	end

	print("================== [MPT_Verify] END ==================");
end

-- ============================================================================
-- 入口：首个回合自动执行（所有人类玩家各跑一遍）
-- ============================================================================
local function MPT_BoostVerify_Run()
	if m_ran then return; end
	m_ran = true;
	print("================== [MPT_Verify] START ==================");
	for i = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local pPlayer : table = Players[i];
		if pPlayer ~= nil and pPlayer:IsMajor() and pPlayer:IsHuman() then
			MPT_BoostVerify_ForPlayer(pPlayer, i);
		end
	end
	print("================== [MPT_Verify] END ==================");
end

GameEvents.OnGameTurnStarted.Add(MPT_BoostVerify_Run);
