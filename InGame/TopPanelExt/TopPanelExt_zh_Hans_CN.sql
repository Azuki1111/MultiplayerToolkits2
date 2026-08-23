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
	('LOC_MPT_TPE_TOOLTIP_POPULATION_HEADER_SUF', 'zh_Hans_CN', ' [Icon_Citizen] 人口');
