-- ===========================================================================
-- 条目14：真实科文进度（TCP）——CivicsTree 市政树增强（移植自联机工具箱 1.67 TCP/UI/CivicsTree_TPT.lua）
-- 功能与优化同 TechTree_MPT.lua（真实进度 + BLOCKED 回合修正 + BoostMeter 预估），
-- 差异：探测表无 Exp1（官方 Exp1 无 CivicsTree 替换，Exp2 有）、产出用文化（GetCultureYield）、
-- boost 静态表键为 CivicType、未揭示文本 tag 为 LOC_CIVICS_TREE_NOT_REVEALED_CIVIC。
-- 注册：ReplaceUIScript(LuaContext=CivicsTree, LoadOrder 100000) 投递本文件；ImportFiles(100010) 入 VFS。
-- ===========================================================================

-- ===========================================================================
-- INCLUDES（基类探测：Exp2 优先，退 Base；仅当 Initialize 存在即视为基类）
-- ===========================================================================
print("MPT_TCP(CivicsTree): script start");
local files = {
	"CivicsTree_Expansion2",
	"CivicsTree",
}

for _, file in ipairs(files) do
	include(file)
	if Initialize then
		print("MPT_TCP(CivicsTree): base loaded = " .. file);
		break
	end
end

-- ===========================================================================
-- 条目14 分区：文本与常量
-- ===========================================================================
local MPT_IconEnough : string = "[icon_You]";		-- 可凭 boost 完成时追加的图标标记（与 TechAndCivicSupport.lua 一致）

-- ===========================================================================
-- 条目14 分区：boost 百分比静态表（[CivicType] = Boost 百分比绝对值，如 40 表示 40%）
-- GameInfo 静态数据一次构建，GetCurrentData 循环内 O(1) 查表
-- ===========================================================================
local MPT_BoostMap : table = {};
for row in GameInfo.Boosts() do
	if row.CivicType ~= nil then
		MPT_BoostMap[row.CivicType] = row.Boost;
	end
end

-- ===========================================================================
--	CACHE BASE FUNCTIONS
-- 注意：MPT_ 前缀独立命名（同 TechTree_MPT.lua——官方 DLC 替换文件可能定义同名 BASE_
-- 全局，覆盖会导致官方覆盖层内部递归；本 mod 统一用 MPT_BASE_ 前缀规避）
-- ===========================================================================
MPT_BASE_GetCurrentData = GetCurrentData;
MPT_BASE_PopulateNode = PopulateNode;

-- ===========================================================================
--	OVERRIDE GetCurrentData：为 live 数据追加真实进度字段（BoostAmount/Estimates/Enough）
-- 调用 Base 后再处理返回值：base 构建的 live 表追加三个字段并计算预估，
-- BoostAmount = 官方 boost 百分比 + modifier 附加加速（动态注入，替代 1.67 刷新静态数据）。
-- ===========================================================================
function GetCurrentData(ePlayer:number)
	local data : table = MPT_BASE_GetCurrentData(ePlayer);
	if data == nil then
		return nil;
	end
	local liveData : table = data[DATA_FIELD_LIVEDATA];
	if liveData == nil then
		return data;
	end

	local extraBoost : number = MPT_GetExtraBoostFromModifiers(Game.GetLocalPlayer(), false);	-- 本回合 modifier 附加文化加速（内部缓存）

	for type, live in pairs(liveData) do
		local boostPercent : number = (MPT_BoostMap[type] or 0) + extraBoost;
		live.BoostAmount = boostPercent;		-- 百分比绝对值（含附加加速），供 Estimates 计算
		live.Enough = false;
		if live.Cost ~= nil and live.Progress ~= nil then
			if not live.IsBoosted then			-- 未触发 boost：修正预估（0.5 步进取整补偿，见 TechAndCivicSupport.lua 注释）
				live.Estimates = math.min(live.Progress + math.floor(math.max(live.Cost * boostPercent / 100 - ((live.Cost * boostPercent / 100 % 0.5 == 0) and 0.5 or 1), 0)), live.Cost);
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
		local techName : string = (status == ITEM_STATUS.UNREVEALED) and Locale.Lookup("LOC_CIVICS_TREE_NOT_REVEALED_CIVIC") or Locale.Lookup(item.Name);
		uiNode.NodeName:SetText(Locale.ToUpper(techName)..MPT_IconEnough);
	end

	-- 2. BLOCKED 回合数修正（按实际文化产出重算，防引擎对不可研究项给不可信值）
	if live.Status == ITEM_STATUS.BLOCKED then
		local pPlayerCulture : table = Players[Game.GetLocalPlayer()]:GetCulture();
		local cultureYield : number = pPlayerCulture:GetCultureYield();
		if cultureYield ~= nil and cultureYield > 0 then
			live.Turns = math.floor(math.max((live.Cost - live.Progress) / cultureYield, 1) + 0.5);
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
