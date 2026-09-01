-- ============================================================================
-- 条目22：商路界面增强（BTS）文本（en_US 英文）
-- 移植 1.67 BTS/Text/BTS_Text_EN.xml（XML → SQL 本地化管线，项目规约）；
-- 裁剪范围与中文文件相同（自动化 4 tag + BTS 设置面板 8 tag），见中文文件头注释。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_TRADE_GROUP_SETTINGS',	'en_US',	'Group Settings'),
	('LOC_TRADE_FILTER_SETTINGS',	'en_US',	'Filter Settings'),
	('LOC_TRADE_SORT_BY_FOOD_TOOLTIP',	'en_US',	'Sort by [ICON_Food]Food.'),
	('LOC_TRADE_SORT_BY_PRODUCTION_TOOLTIP',	'en_US',	'Sort by [ICON_Production]Production.'),
	('LOC_TRADE_SORT_BY_GOLD_TOOLTIP',	'en_US',	'Sort by [ICON_Gold]Gold.'),
	('LOC_TRADE_SORT_BY_SCIENCE_TOOLTIP',	'en_US',	'Sort by [ICON_Science]Science.'),
	('LOC_TRADE_SORT_BY_CULTURE_TOOLTIP',	'en_US',	'Sort by [ICON_Culture]Culture.'),
	('LOC_TRADE_SORT_BY_FAITH_TOOLTIP',	'en_US',	'Sort by [ICON_Faith]Faith.'),
	('LOC_TRADE_SORT_BY_TURNS_REMAINING_TOOLTIP',	'en_US',	'Sort by [ICON_Turn]Turns to complete route.'),
	('LOC_TRADE_FILTER_INTERNATIONAL_ROUTES_TEXT',	'en_US',	'International Routes'),
	('LOC_TRADE_FILTER_CS_WITH_QUEST_TOOLTIP',	'en_US',	'City-States with Trade Quest'),
	('LOC_TRADE_NO_BENEFIT_TEXT',	'en_US',	'gains no benefits from this Route.'),
	('LOC_TRADE_SORT_BY_TEXT',	'en_US',	'Sort by:'),
	('LOC_TRADE_OVERVIEW_ORIGIN_AZ',	'en_US',	'Origin A-Z'),
	('LOC_TRADE_OVERVIEW_ORIGIN_ZA',	'en_US',	'Origin Z-A'),
	('LOC_TRADE_OVERVIEW_DESTINATION_AZ',	'en_US',	'Destination A-Z'),
	('LOC_TRADE_OVERVIEW_DESTINATION_ZA',	'en_US',	'Destination Z-A'),
	('LOC_TRADE_EXPAND_ALL_BUTTON_TEXT',	'en_US',	'Exp:'),
	('LOC_TRADE_COLLAPSE_ALL_BUTTON_TEXT',	'en_US',	'Col:'),
	('LOC_TRADE_TURNS_REMAINING_HELP_TOOLTIP',	'en_US',	'Total amount of[ICON_Turn]to complete this trade route'),
	('LOC_TRADE_TURNS_REMAINING_ALT_HELP_TOOLTIP',	'en_US',	'This route will take {1_TurnsRemaining}[Icon_Turn] to complete.'),
	('LOC_TRADE_TURNS_REMAINING_TOOLTIP_BREAKER',	'en_US',	'----------------------------'),
	('LOC_TRADE_TURNS_REMAINING_ROUTE_LENGTH_TOOLTIP',	'en_US',	'Trade Route[ICON_Movement]: {1_TripsToDestination}'),
	('LOC_TRADE_TURNS_REMAINING_TRIPS_COUNT_TOOLTIP',	'en_US',	'Trips to destination: {1_TripsToDestination}'),
	('LOC_TRADE_TURNS_REMAINING_TURN_COMPLETION_TOOLTIP',	'en_US',	'Route will complete in [ICON_Turn]{1_TurnWhenCompleted}'),
	('LOC_TRADE_TURNS_REMAINING_TURN_COMPLETION_ALT_TOOLTIP',	'en_US',	'If started, route will take {1_TurnsToComplete} turns and will complete on turn {2_TurnWhenCompleted}'),
	('LOC_ORIGIN_CHOOSER_HEADER_BACKGROUND_TEXT',	'en_US',	'Choose a city'),
	('LOC_TRADE_ORIGIN_CHOOSER_HEADER_LABEL_TEXT',	'en_US',	'TRANSFER TRADER TO...'),
	('LOC_ORIGIN_CHOOSER_CHANGE_DESTINATION_BUTTON',	'en_US',	'CONFIRM');
