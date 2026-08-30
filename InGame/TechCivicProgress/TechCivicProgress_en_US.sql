-- ============================================================================
-- 条目14：真实科文进度（TCP）文本（en_US 英文）
-- 移植自 1.67 TCP/Text_TCP.xml，tag 统一改为 MPT_TCP_ 前缀避免与 1.67 冲突；
-- 带参数 tag 已拆为无参数 PRE/SUF，由 Lua 端 .. 拼接（本 mod 文本规范）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
	('LOC_MPT_TCP_PROGRESS_PRE', 'en_US', 'Progress: '),
	('LOC_MPT_TCP_PROGRESS_SUF', 'en_US', ' / '),
	('LOC_MPT_TCP_ESTIMATES_PRE', 'en_US', '[NEWLINE]Progress after boost: '),
	('LOC_MPT_TCP_ESTIMATES_SUF', 'en_US', ' / '),
	('LOC_MPT_TCP_ENOUGH', 'en_US', '[NEWLINE][icon_You]Can be completed by gaining a boost');
