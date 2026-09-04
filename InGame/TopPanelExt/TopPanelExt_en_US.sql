-- ============================================================================
-- 条目9：顶部面板扩展（TPE）文本（en_US）
-- 移植自 1.67 TPE/TopPanel_Text.xml，tag 统一改为 MPT_TPE_ 前缀避免与 1.67 冲突；
-- 带参数 tag 已拆为无参数 PRE/SUF，由 Lua 端 .. 拼接。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
	('LOC_MPT_TPE_LUXURY_RESOURCES_PRE', 'en_US', '[ICON_RESOURCE_TOYS] Number of Luxury Resources Owned: ('),
	('LOC_MPT_TPE_LUXURY_RESOURCES_SUF', 'en_US', ' type)'),
	('LOC_MPT_TPE_MORE_LUXURY_NAME', 'en_US', '[NEWLINE][NEWLINE]Your extra luxury resources[NEWLINE]'),
	('LOC_MPT_TPE_TEAM_MORE_LUXURY_NAME', 'en_US', '[NEWLINE][NEWLINE]Surplus luxury resources of other players'),
	('LOC_MPT_TPE_TEAM_MORE_STRATEGIC_NAME', 'en_US', '[NEWLINE]Strategic resources available from teammates[NEWLINE]'),
	('LOC_MPT_TPE_TOOLTIP_PRODUCTION_HEADER_PRE', 'en_US', '+'),
	('LOC_MPT_TPE_TOOLTIP_PRODUCTION_HEADER_SUF', 'en_US', ' [Icon_ProductionLarge] Production'),
	('LOC_MPT_TPE_TOOLTIP_FOOD_HEADER_PRE', 'en_US', '+'),
	('LOC_MPT_TPE_TOOLTIP_FOOD_HEADER_SUF', 'en_US', ' [Icon_FoodLarge] Food'),
	('LOC_MPT_TPE_TOOLTIP_POPULATION_HEADER_PRE', 'en_US', ''),
	('LOC_MPT_TPE_TOOLTIP_POPULATION_HEADER_SUF', 'en_US', ' [Icon_Citizen] Population');
