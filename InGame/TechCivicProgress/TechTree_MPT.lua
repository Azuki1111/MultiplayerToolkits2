-- ===========================================================================
-- 条目14：真实科文进度（TCP）——TechTree 科技树增强（移植自联机工具箱 1.67 TCP/UI/TechTree_TPT.lua）
-- 功能：
--   1. 真实进度：可凭 boost 完成的科技节点名追加 [icon_You]；BLOCKED 状态回合数按实际产出重算；
--      boost 进度条百分比显示「boost 后预估完成度」（Estimates/Cost）而非「当前+boost」。
--   2. modifier 附加科技加速计入预估（GetExtraBoostFromModifiers，与 TechAndCivicSupport.lua 共用）。
-- 相对 1.67 的优化：
--   - 不复制官方 2083 行整文件，改为 include 探测官方最高版本（Exp2→Exp1→Base）后覆盖 2 个函数；
--   - 官方 Exp2 的 IsSearchable（仅已揭示可搜）与 Exp1 的联盟研究图标随探测自动获得，无需复制（1.67 逐字抄官方）；
--   - 1.67 需改 PopulateItemData + OnOpen 刷新静态 boost 数据；本文件在 GetCurrentData 动态注入
--     modifier 额外加速（MPT_BoostMap 静态表 + 每回合缓存），无需覆盖 PopulateItemData/OnOpen；
--   - boost 数据用顶层 MPT_BoostMap 一次构建（O(1) 查表），替代 1.67 在 GetCurrentData 循环内查 GameInfo.Boosts。
-- 注册：ReplaceUIScript(LuaContext=TechTree, LoadOrder 100000) 投递本文件；ImportFiles(100010) 入 VFS 供 include 探测。
-- ===========================================================================

-- ===========================================================================
-- INCLUDES（基类探测：Exp2 优先，退 Exp1，再退 Base；仅当 Initialize 存在即视为基类）
-- ===========================================================================
print("MPT_TCP(TechTree): script start");
local files = {
	"TechTree_Expansion2",
	"TechTree_Expansion1",
	"TechTree",
}

for _, file in ipairs(files) do
	include(file)
	if Initialize then
		print("MPT_TCP(TechTree): base loaded = " .. file);
		break
	end
end

-- ===========================================================================
-- 条目14 分区：文本与常量
-- ===========================================================================
local MPT_IconEnough : string = "[icon_You]";		-- 可凭 boost 完成时追加的图标标记（与 TechAndCivicSupport.lua 一致）

-- ===========================================================================
-- 条目14 分区：boost 百分比静态表（[TechnologyType] = Boost 百分比绝对值，如 40 表示 40%）
-- GameInfo 静态数据一次构建，GetCurrentData 循环内 O(1) 查表
-- ===========================================================================
local MPT_BoostMap : table = {};
for row in GameInfo.Boosts() do
	if row.TechnologyType ~= nil then
		MPT_BoostMap[row.TechnologyType] = row.Boost;
	end
end

-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- 注意：必须用 MPT_ 前缀独立命名，不能覆盖官方 Exp1 已定义的 BASE_PopulateNode 全局
--（Exp1 的 PopulateNode 内部动态查找 BASE_PopulateNode；若被本 mod 同名覆盖为 Exp1 版
-- 自身将无限递归 → 栈溢出崩溃。CivicsTree 无 Exp1 替换所以此前未暴露此问题）
-- ===========================================================================
MPT_BASE_GetCurrentData = GetCurrentData;
MPT_BASE_PopulateNode = PopulateNode;

-- ===========================================================================
--	OVERRIDE UpdateAllianceIcon（官方 Exp1 版 + nil 防御）：
-- Alliance 控件仅在官方 Exp1 的 TechTreeNode.xml 替换中存在；无该替换（或未来 DLC
-- 缺失）时返回，避免 nil 索引导致整棵科技树渲染崩溃（本 mod 覆盖层保证）。
-- ===========================================================================
function UpdateAllianceIcon(node:table)
	if node == nil or node.AllianceIcon == nil or node.Alliance == nil then
		return;
	end
	local techID : number = GameInfo.Technologies[node.Type].Index;
	if AllyHasOrIsResearchingTech(techID) then
		node.AllianceIcon:SetToolTipString(GetAllianceIconToolTip());
		node.AllianceIcon:SetColor(GetAllianceIconColor());
		node.Alliance:SetHide(false);
	else
		node.Alliance:SetHide(true);
	end
end

-- ===========================================================================
--	OVERRIDE GetCurrentData：为 live 数据追加真实进度字段（BoostAmount/Estimates/Enough）
-- 调用 Base 后再处理返回值：base 构建的 live 表追加三个字段并计算预估，
-- BoostAmount = 官方 boost 百分比 + modifier 附加加速（动态注入，替代 1.67 刷新静态数据）。
-- ===========================================================================
function GetCurrentData(ePlayer:number, eCompletedTech:number)
	local data : table = MPT_BASE_GetCurrentData(ePlayer, eCompletedTech);
	if data == nil then
		return nil;
	end
	local liveData : table = data[DATA_FIELD_LIVEDATA];
	if liveData == nil then
		return data;
	end

	local extraBoost : number = MPT_GetExtraBoostFromModifiers(Game.GetLocalPlayer(), true);	-- 本回合 modifier 附加科技加速（内部缓存）

	for type, live in pairs(liveData) do
		local boostPercent : number = (MPT_BoostMap[type] or 0) + extraBoost;
		live.BoostAmount = boostPercent;		-- 百分比绝对值（含附加加速），供 Estimates 计算
		live.Enough = false;
		if live.Cost ~= nil and live.Progress ~= nil then
			if not live.IsBoosted then			-- 未触发 boost：修正预估（实测校准公式，同 TechAndCivicSupport）
				local boostRaw : number = math.floor(live.Cost * boostPercent / 100);
				local penalty : number = 1 + math.floor(live.Cost / 1000);		-- 引擎取整损失（13 采样拟合，误差 ≤1 点）
				local boostValue : number = math.max(boostRaw - penalty, 0);
				live.Estimates = math.min(live.Progress + boostValue, live.Cost);
			else								-- 已触发 boost：预估 = 当前进度
				live.Estimates = live.Progress;
			end
			if live.Estimates == live.Cost then
				live.Enough = true;
			end
		end
	end

	return data;
end

-- ===========================================================================
--	OVERRIDE PopulateNode：真实进度显示增强（Base 已完成常规渲染，此处追加/修正）
--  1. NodeName 追加 [icon_You]（可凭 boost 完成）
--  2. BLOCKED 状态回合数按实际产出重算（引擎对不可研究项给出不可信回合数）
--  3. BoostMeter 百分比改为「boost 后预估完成度」（Estimates/Cost）
-- ===========================================================================
function PopulateNode(uiNode:table, playerTechData:table)
	MPT_BASE_PopulateNode(uiNode, playerTechData);

	local item : table = g_kItemDefaults[uiNode.Type];		-- static item data
	local live : table = playerTechData[DATA_FIELD_LIVEDATA][uiNode.Type];	-- live (changing) data
	if item == nil or live == nil then
		return;
	end

	local status : number = live.IsRevealed and live.Status or ITEM_STATUS.UNREVEALED;

	-- 1. NodeName 图标（可凭 boost 完成）
	if live.Enough then
		local nodeName : string = (status == ITEM_STATUS.UNREVEALED) and Locale.Lookup("LOC_TECH_TREE_NOT_REVEALED_TECH") or Locale.Lookup(item.Name);
		uiNode.NodeName:SetText(Locale.ToUpper(nodeName)..MPT_IconEnough);
	end

	-- 2. BLOCKED 回合数修正（按实际科学产出重算，防引擎对不可研究项给不可信值）
	if live.Status == ITEM_STATUS.BLOCKED then
		local pPlayerTechs : table = Players[Game.GetLocalPlayer()]:GetTechs();
		local scienceYield : number = pPlayerTechs:GetScienceYield();
		if scienceYield ~= nil and scienceYield > 0 then
			live.Turns = math.floor(math.max((live.Cost - live.Progress) / scienceYield, 1) + 0.5);
			uiNode.Turns:SetHide(false);
			uiNode.Turns:SetText(Locale.Lookup("LOC_TECH_TREE_TURNS", live.Turns));
		end
	end

	-- 3. BoostMeter 百分比修正（Base 已决定显隐，此处仅在显示 boost 进度条时改百分比）
	if item.IsBoostable and status ~= ITEM_STATUS.RESEARCHED and status ~= ITEM_STATUS.UNREVEALED and not live.IsBoosted then
		if live.Estimates ~= nil and live.Cost ~= nil and live.Cost > 0 then
			uiNode.BoostMeter:SetPercent(live.Estimates / live.Cost);
		end
	end
end
