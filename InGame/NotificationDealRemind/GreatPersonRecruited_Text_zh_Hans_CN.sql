-- ============================================================================
-- 条目26：他人招募伟人通知文本（zh_Hans_CN 简体中文）
-- tag 沿用源 mod 2459772036（Great Person Recruited Notification）原名；源 mod 仅
--   en/de 双语（作者自注 google 翻译），中文为本 mod 补全。
-- SUMMARY 占位符 {1_recruiter}/{2_greatPersonType}/{3_greatPersonName} 保留：通知
--   Summary 由引擎排版、中文语序需要（源 mod 同款参数形态，lua 侧运行时
--   Locale.Lookup(tag, args) 构造，不适用「纯文本 tag + Lua 拼接」预加载规约场景）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_NOTIFICATION_OTHER_PLAYER_RECRUITED_GREATPERSON_MESSAGE',	'zh_Hans_CN',	'伟人已被招募'),
	('LOC_NOTIFICATION_OTHER_PLAYER_RECRUITED_GREATPERSON_SUMMARY',	'zh_Hans_CN',	'{1_recruiter} 招募了 {2_greatPersonType} {3_greatPersonName}');
