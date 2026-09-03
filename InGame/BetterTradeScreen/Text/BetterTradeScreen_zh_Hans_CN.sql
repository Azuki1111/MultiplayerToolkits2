-- ============================================================================
-- 条目22：商路界面增强（BTS）文本（zh_Hans_CN 简体中文）
-- 移植 1.67 BTS/Text/BTS_Text_Hans_CN.xml（XML → SQL 本地化管线，项目规约）；
-- LOC_TRADE_* 为覆盖原版同名 tag 或 BTS 新增 tag，字符串与 1.67 一致（同装无冲突）。
-- 裁剪（随代码剔除不携带）：商人自动化 4 tag（LOC_TRADE_REPEAT_ROUTE_* /
--   LOC_TRADE_FROM_TOP_SORT_ENTRY_* / LOC_TRADE_CANCEL_AUTOMATION_TOOLTIP）、
--   BTS 独立设置面板 8 tag（LOC_BTS_*，条目22调整按用户裁决 4 选项不开放配置、
--   硬编码 1.67 默认值，设置面板文本不携带）。
-- 仅游戏内消费 → 仅 IG UpdateText 注册（同条目21 先例）。
-- 1.67 中文文件相对英文的缺项（LOC_TRADE_OVERVIEW_ORIGIN_AZ 等 4 个 A-Z/Z-A 分组
--   tag，1.67 Lua 已注释禁用对应分组项）回落英文，维持 1.67 现状。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_TRADE_GROUP_SETTINGS',	'zh_Hans_CN',	'设置分组筛选'),
	('LOC_TRADE_FILTER_SETTINGS',	'zh_Hans_CN',	'设置过滤条件'),
	('LOC_TRADE_SORT_BY_FOOD_TOOLTIP',	'zh_Hans_CN',	'按 [ICON_Food] 食物排序'),
	('LOC_TRADE_SORT_BY_PRODUCTION_TOOLTIP',	'zh_Hans_CN',	'按 [ICON_Production] 生产力排序'),
	('LOC_TRADE_SORT_BY_GOLD_TOOLTIP',	'zh_Hans_CN',	'按 [ICON_Gold] 金币排序'),
	('LOC_TRADE_SORT_BY_SCIENCE_TOOLTIP',	'zh_Hans_CN',	'按 [ICON_Science] 科技值排序'),
	('LOC_TRADE_SORT_BY_CULTURE_TOOLTIP',	'zh_Hans_CN',	'按 [ICON_Culture] 文化值排序'),
	('LOC_TRADE_SORT_BY_FAITH_TOOLTIP',	'zh_Hans_CN',	'按 [ICON_Faith] 信仰值排序'),
	('LOC_TRADE_SORT_BY_TURNS_REMAINING_TOOLTIP',	'zh_Hans_CN',	'按 [ICON_Turn] 剩余回合数排序'),
	('LOC_TRADE_FILTER_INTERNATIONAL_ROUTES_TEXT',	'zh_Hans_CN',	'国际贸易路线'),
	('LOC_TRADE_FILTER_CS_WITH_QUEST_TOOLTIP',	'zh_Hans_CN',	'有贸易路线请求的城邦'),
	('LOC_TRADE_NO_BENEFIT_TEXT',	'zh_Hans_CN',	'不会从此贸易路线获得收益'),
	('LOC_TRADE_SORT_BY_TEXT',	'zh_Hans_CN',	'排序：'),
	('LOC_TRADE_EXPAND_ALL_BUTTON_TEXT',	'zh_Hans_CN',	'展开'),
	('LOC_TRADE_COLLAPSE_ALL_BUTTON_TEXT',	'zh_Hans_CN',	'折叠'),
	('LOC_TRADE_TURNS_REMAINING_HELP_TOOLTIP',	'zh_Hans_CN',	'贸易路线剩余 [ICON_Turn] 回合数'),
	('LOC_TRADE_TURNS_REMAINING_ALT_HELP_TOOLTIP',	'zh_Hans_CN',	'此贸易路线将在 {1_TurnsRemaining}[Icon_Turn] 后完成'),
	('LOC_TRADE_TURNS_REMAINING_ALT2_HELP_TOOLTIP',	'zh_Hans_CN',	'此贸易路线将在 {1_TurnsRemaining}[Icon_Turn] 内完成'),
	('LOC_TRADE_TURNS_REMAINING_TOOLTIP_BREAKER',	'zh_Hans_CN',	'----------------------------'),
	('LOC_TRADE_TURNS_REMAINING_ROUTE_LENGTH_TOOLTIP',	'zh_Hans_CN',	'贸易路线 [ICON_Movement]: {1_TripsToDestination}'),
	('LOC_TRADE_TURNS_REMAINING_TRIPS_COUNT_TOOLTIP',	'zh_Hans_CN',	'到目的地: {1_TripsToDestination}'),
	('LOC_TRADE_TURNS_REMAINING_TURN_COMPLETION_TOOLTIP',	'zh_Hans_CN',	'贸易路线将在 [ICON_Turn]{1_TurnWhenCompleted} 时完成'),
	('LOC_TRADE_TURNS_REMAINING_TURN_COMPLETION_ALT_TOOLTIP',	'zh_Hans_CN',	'如果此时出发，贸易路线将在 [ICON_Turn]{1_TurnWhenCompleted} 时完成'),
	('LOC_ORIGIN_CHOOSER_HEADER_BACKGROUND_TEXT',	'zh_Hans_CN',	'选择一个城市'),
	('LOC_TRADE_ORIGIN_CHOOSER_HEADER_LABEL_TEXT',	'zh_Hans_CN',	'转移商队至'),
	('LOC_ORIGIN_CHOOSER_CHANGE_DESTINATION_BUTTON',	'zh_Hans_CN',	'确认');
