-- ============================================================================
-- 条目26：他人招募伟人通知文本（en_US）
-- 照抄源 mod 2459772036（Great Person Recruited Notification）BaseGameText 原文
--   （tag 沿用原名，本 mod 统一走 LocalizedText 注册）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_NOTIFICATION_OTHER_PLAYER_RECRUITED_GREATPERSON_MESSAGE',	'en_US',	'Great person recruited'),
	('LOC_NOTIFICATION_OTHER_PLAYER_RECRUITED_GREATPERSON_SUMMARY',	'en_US',	'{1_recruiter} has recruited the {2_greatPersonType} {3_greatPersonName}');
