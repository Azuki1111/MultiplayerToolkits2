-- ============================================================================
-- 条目9：顶部面板扩展（TPE）文本（en_US）
-- 移植自 1.67 TPE/TopPanel_Text.xml，tag 统一改为 MPT_TPE_ 前缀避免与 1.67 冲突；
-- 带参数 tag 已拆为无参数 PRE/SUF，由 Lua 端 .. 拼接。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
	('LOC_MPT_TPE_LUXURY_RESOURCES_PRE', 'en_US', '[ICON_RESOURCE_TOYS] Number of Luxury Resources Owned: ('),
	('LOC_MPT_TPE_LUXURY_RESOURCES_SUF', 'en_US', ' type)'),
	('LOC_MPT_TPE_MORE_LUXURY_NAME', 'en_US', '[NEWLINE][NEWLINE]Own Extra Luxury Resources[NEWLINE]'),
	('LOC_MPT_TPE_TEAM_MORE_LUXURY_NAME', 'en_US', '[NEWLINE][NEWLINE]Surplus luxury resources of other players'),
	('LOC_MPT_TPE_TEAM_MORE_STRATEGIC_NAME', 'en_US', '[NEWLINE][NEWLINE]Team Strategic Resources'),
	('LOC_MPT_TPE_TOOLTIP_PRODUCTION_HEADER_PRE', 'en_US', '+'),
	('LOC_MPT_TPE_TOOLTIP_PRODUCTION_HEADER_SUF', 'en_US', ' [Icon_ProductionLarge] Production'),
	('LOC_MPT_TPE_TOOLTIP_FOOD_HEADER_PRE', 'en_US', '+'),
	('LOC_MPT_TPE_TOOLTIP_FOOD_HEADER_SUF', 'en_US', ' [Icon_FoodLarge] Food'),
	('LOC_MPT_TPE_TOOLTIP_POPULATION_HEADER_PRE', 'en_US', ''),
	('LOC_MPT_TPE_TOOLTIP_POPULATION_HEADER_SUF', 'en_US', ' [Icon_Citizen] Population'),
	-- 条目9续：战略资源点击发送交易弹窗
	('LOC_MPT_TPE_SEND_TITLE_PRE', 'en_US', 'Send '),
	('LOC_MPT_TPE_SEND_TITLE_SUF', 'en_US', ' to Teammates'),
	('LOC_MPT_TPE_SEND_YOUR_AMOUNT_PRE', 'en_US', 'You have: '),
	('LOC_MPT_TPE_SEND_YOUR_AMOUNT_SUF', 'en_US', ''),
	('LOC_MPT_TPE_SEND_SPACE_PRE', 'en_US', 'Space: '),
	('LOC_MPT_TPE_SEND_SPACE_SUF', 'en_US', ''),
	('LOC_MPT_TPE_SEND_TOTAL_PRE', 'en_US', 'Total Sendable: '),
	('LOC_MPT_TPE_SEND_TOTAL_SUF', 'en_US', ''),
	('LOC_MPT_TPE_SEND_CONFIRM', 'en_US', 'Send'),
	('LOC_MPT_TPE_SEND_CANCEL', 'en_US', 'Cancel'),
	('LOC_MPT_TPE_SEND_TRADE_BANNED', 'en_US', 'Trading is banned: cannot send resources'),
	('LOC_MPT_TPE_SEND_NO_TEAMMATE', 'en_US', 'No teammate can receive');
