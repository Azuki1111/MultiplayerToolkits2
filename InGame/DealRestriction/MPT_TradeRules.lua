-- ===========================================================================
-- 条目10：交易限制规则统一解析器（移植 1.67 DDV 限制语义，供多 Lua 上下文共用）
--
-- 用法：include("MPT_TradeRules") 后 local tradeRules = MPT_ResolveTradeRules();
-- 返回八键布尔表（true=允许交易）：
--   Gold / Favor / Strategics / Luxuries / Cities / Captives / GreatWorks / Agreements
--
-- 语义（与 1.67 DDV/UI/DiplomacyDealView_TPT.lua 完全一致）：预设优先于自定义布尔——
--   常规   SETTINGS_DEAL_NORM    仅禁城市
--   经典   SETTINGS_DEAL_CLASSIC 禁金币+城市
--   独立   SETTINGS_DEAL_ALONE   全禁仅放行奢侈品
--   自定义 SETTINGS_DEAL_CUSTOM（或参数缺失时的兜底）读 8 个 TPT_NO_TRADING_* 布尔
--
-- 注意：跨 Lua 上下文不能共享状态，TopPanel（条目9）与 DiplomacyDealView（条目10）
-- 各自 include 本文件并解析一次，结果一致。配置开局后不可改（ChangeableAfterGameStart=0），
-- 上下文加载时解析一次即可，无需反复调用。
-- ===========================================================================

function MPT_ResolveTradeRules()
	local preset = GameConfiguration.GetValue("SETTINGS_DIPLOMATIC_DEAL");
	if preset == "SETTINGS_DEAL_NORM" then
		return { Gold=true,  Favor=true,  Strategics=true,  Luxuries=true, Cities=false, Captives=true,  GreatWorks=true,  Agreements=true  };
	elseif preset == "SETTINGS_DEAL_CLASSIC" then
		return { Gold=false, Favor=true,  Strategics=true,  Luxuries=true, Cities=false, Captives=true,  GreatWorks=true,  Agreements=true  };
	elseif preset == "SETTINGS_DEAL_ALONE" then
		return { Gold=false, Favor=false, Strategics=false, Luxuries=true, Cities=false, Captives=false, GreatWorks=false, Agreements=false };
	end
	-- 自定义模式：按各禁止项布尔值（== true 判定，与 1.67 一致；参数缺失时 GetValue 返回 nil 视为允许）
	return {
		Gold		= GameConfiguration.GetValue("TPT_NO_TRADING_GOLD") ~= true,
		Favor		= GameConfiguration.GetValue("TPT_NO_TRADING_FAVOR") ~= true,
		Strategics	= GameConfiguration.GetValue("TPT_NO_TRADING_STRATEGICS") ~= true,
		Luxuries	= GameConfiguration.GetValue("TPT_NO_TRADING_LUXURIES") ~= true,
		Cities		= GameConfiguration.GetValue("TPT_NO_TRADING_CITIES") ~= true,
		Captives	= GameConfiguration.GetValue("TPT_NO_TRADING_CAPTIVES") ~= true,
		GreatWorks	= GameConfiguration.GetValue("TPT_NO_TRADING_GREATWORKS") ~= true,
		Agreements	= GameConfiguration.GetValue("TPT_NO_TRADING_AGREEMENTS") ~= true,
	};
end
