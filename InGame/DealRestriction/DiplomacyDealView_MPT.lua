-- ===========================================================================
-- 条目10：交易限制执行层（移植自联机工具箱 1.67 DDV/UI/DiplomacyDealView_TPT.lua）
--
-- 注入方式：经原版 DiplomacyDealView.lua 末尾 include("DiplomacyDealView_", true)
-- 通配符包含进本上下文（Base:3177 / Exp2:3229 均有），ImportFiles 入 VFS 即生效。
--
-- 相对 1.67 的优化：
--   1. 变量名优化——8 个松散全局 isXxxTradingAllowed 合并为单表 tradeRules，
--      规则解析统一走 MPT_TradeRules.lua 的 MPT_ResolveTradeRules()（与条目9
--      TopPanel 共用同一解析器，保证交易界面强制结果与顶部面板显示一致）；
--   2. 8 个逐函数覆盖改工厂生成（行为与 1.67 完全一致：被禁类别返回 1 防止
--      无可交易项导致无法签同盟；Favor/Gold 不隐藏顶层容器，其余 6 类隐藏）。
-- ===========================================================================

include("MPT_TradeRules");

-- 当前局交易限制规则（配置开局后不可改，上下文加载时解析一次）
local tradeRules : table = MPT_ResolveTradeRules();

-- ===========================================================================
-- CACHE BASE FUNCTIONS
-- ===========================================================================

BASE_PopulateAvailableGold = PopulateAvailableGold;
BASE_PopulateAvailableLuxuryResources = PopulateAvailableLuxuryResources;
BASE_PopulateAvailableStrategicResources = PopulateAvailableStrategicResources;
BASE_PopulateAvailableCaptives = PopulateAvailableCaptives;
BASE_PopulateAvailableGreatWorks = PopulateAvailableGreatWorks;
BASE_PopulateAvailableCities = PopulateAvailableCities;
BASE_PopulateAvailableAgreements = PopulateAvailableAgreements;
BASE_PopulateAvailableFavor = PopulateAvailableFavor;

-- ===========================================================================
--	OVERRIDE（工厂生成：isAllowed==false 时返回 1，hideTop 时隐藏类别顶层容器）
-- ===========================================================================

local function MakeCategoryOverride(baseFn, isAllowed, hideTop)
	return function(player : table, iconList : table)
		if isAllowed == false then
			if hideTop then
				iconList.GetTopControl():SetHide(true);
			end
			return 1;		-- 防止因为没有可交易选项，导致无法签同盟
		end
		return baseFn(player, iconList);
	end
end

PopulateAvailableFavor = MakeCategoryOverride(BASE_PopulateAvailableFavor, tradeRules.Favor, false);
PopulateAvailableGold = MakeCategoryOverride(BASE_PopulateAvailableGold, tradeRules.Gold, false);
PopulateAvailableStrategicResources = MakeCategoryOverride(BASE_PopulateAvailableStrategicResources, tradeRules.Strategics, true);
PopulateAvailableLuxuryResources = MakeCategoryOverride(BASE_PopulateAvailableLuxuryResources, tradeRules.Luxuries, true);
PopulateAvailableAgreements = MakeCategoryOverride(BASE_PopulateAvailableAgreements, tradeRules.Agreements, true);
PopulateAvailableCities = MakeCategoryOverride(BASE_PopulateAvailableCities, tradeRules.Cities, true);
PopulateAvailableGreatWorks = MakeCategoryOverride(BASE_PopulateAvailableGreatWorks, tradeRules.GreatWorks, true);
PopulateAvailableCaptives = MakeCategoryOverride(BASE_PopulateAvailableCaptives, tradeRules.Captives, true);

print("MPT_DDV: trade rules applied");
