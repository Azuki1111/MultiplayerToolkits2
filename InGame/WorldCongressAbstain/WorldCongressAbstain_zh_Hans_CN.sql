-- 条目27：世界议会弃权选项 功能文本（zh_Hans_CN）
-- 仅游戏内消费（WorldCongressPopup 上下文），仅 IG UpdateText 注册（条目21/22 消费侧注册先例）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_WC_ABSTAIN',			'zh_Hans_CN',	'弃权'),
	('LOC_MPT_WC_ABSTAIN_ON',		'zh_Hans_CN',	'已弃权'),
	('LOC_MPT_WC_ABSTAIN_TT',		'zh_Hans_CN',	'弃权：本项不投入任何票数，确认提交时按 0 票计（再次点击可恢复投票）。'),
	('LOC_MPT_WC_ABSTAIN_SUMMARY',	'zh_Hans_CN',	'（弃权）');
