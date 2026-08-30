-- ============================================================================
-- 条目14：真实科文进度（TCP）文本（zh_Hans_CN 简体中文）
-- 移植自 1.67 TCP/Text_TCP.xml，tag 统一改为 MPT_TCP_ 前缀避免与 1.67 冲突；
-- 带参数 tag 已拆为无参数 PRE/SUF，由 Lua 端 .. 拼接（本 mod 文本规范）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
	('LOC_MPT_TCP_PROGRESS_PRE', 'zh_Hans_CN', '研究进度：'),
	('LOC_MPT_TCP_PROGRESS_SUF', 'zh_Hans_CN', ' / '),
	('LOC_MPT_TCP_ESTIMATES_PRE', 'zh_Hans_CN', '[NEWLINE]获得提升后：'),
	('LOC_MPT_TCP_ESTIMATES_SUF', 'zh_Hans_CN', ' / '),
	('LOC_MPT_TCP_ENOUGH', 'zh_Hans_CN', '[NEWLINE][icon_You]可通过获得提升而完成');
