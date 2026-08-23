-- ============================================================================
-- 条目9：顶部面板扩展（TPE）文本（zh_Hans_CN 简体中文）
-- 移植自 1.67 TPE/TopPanel_Text.xml，tag 统一改为 MPT_TPE_ 前缀避免与 1.67 冲突；
-- 带参数 tag 已拆为无参数 PRE/SUF，由 Lua 端 .. 拼接。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
	('LOC_MPT_TPE_LUXURY_RESOURCES_PRE', 'zh_Hans_CN', '[ICON_RESOURCE_TOYS] 拥有的奢侈品:('),
	('LOC_MPT_TPE_LUXURY_RESOURCES_SUF', 'zh_Hans_CN', ' 种类)'),
	('LOC_MPT_TPE_MORE_LUXURY_NAME', 'zh_Hans_CN', '[NEWLINE][NEWLINE]自己的额外奢侈品[NEWLINE]'),
	('LOC_MPT_TPE_TEAM_MORE_LUXURY_NAME', 'zh_Hans_CN', '[NEWLINE][NEWLINE]其他玩家的重复奢侈品'),
	('LOC_MPT_TPE_TEAM_MORE_STRATEGIC_NAME', 'zh_Hans_CN', '[NEWLINE]队友可用的战略[NEWLINE]'),
	('LOC_MPT_TPE_TOOLTIP_PRODUCTION_HEADER_PRE', 'zh_Hans_CN', '+'),
	('LOC_MPT_TPE_TOOLTIP_PRODUCTION_HEADER_SUF', 'zh_Hans_CN', ' [Icon_ProductionLarge] 生产力'),
	('LOC_MPT_TPE_TOOLTIP_FOOD_HEADER_PRE', 'zh_Hans_CN', '+'),
	('LOC_MPT_TPE_TOOLTIP_FOOD_HEADER_SUF', 'zh_Hans_CN', ' [Icon_FoodLarge] 食物'),
	('LOC_MPT_TPE_TOOLTIP_POPULATION_HEADER_PRE', 'zh_Hans_CN', ''),
	('LOC_MPT_TPE_TOOLTIP_POPULATION_HEADER_SUF', 'zh_Hans_CN', ' [Icon_Citizen] 人口'),
	-- 条目9续：战略资源点击发送交易弹窗
	('LOC_MPT_TPE_SEND_TITLE_PRE', 'zh_Hans_CN', '发送 '),
	('LOC_MPT_TPE_SEND_TITLE_SUF', 'zh_Hans_CN', ' 给队友'),
	('LOC_MPT_TPE_SEND_YOUR_AMOUNT_PRE', 'zh_Hans_CN', '我方持有: '),
	('LOC_MPT_TPE_SEND_YOUR_AMOUNT_SUF', 'zh_Hans_CN', ''),
	('LOC_MPT_TPE_SEND_SPACE_PRE', 'zh_Hans_CN', '空余 '),
	('LOC_MPT_TPE_SEND_SPACE_SUF', 'zh_Hans_CN', ''),
	('LOC_MPT_TPE_SEND_TOTAL_PRE', 'zh_Hans_CN', '合计可发送: '),
	('LOC_MPT_TPE_SEND_TOTAL_SUF', 'zh_Hans_CN', ''),
	('LOC_MPT_TPE_SEND_CONFIRM', 'zh_Hans_CN', '确认发送'),
	('LOC_MPT_TPE_SEND_CANCEL', 'zh_Hans_CN', '取消'),
	('LOC_MPT_TPE_SEND_TRADE_BANNED', 'zh_Hans_CN', '禁止交易模式：无法发送资源'),
	('LOC_MPT_TPE_SEND_NO_TEAMMATE', 'zh_Hans_CN', '没有可接收的队友');
