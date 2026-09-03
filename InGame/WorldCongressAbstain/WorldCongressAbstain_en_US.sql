-- 条目27：世界议会弃权选项 功能文本（en_US）
-- 仅游戏内消费（WorldCongressPopup 上下文），仅 IG UpdateText 注册（条目21/22 消费侧注册先例）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_WC_ABSTAIN',			'en_US',	'Abstain'),
	('LOC_MPT_WC_ABSTAIN_ON',		'en_US',	'Abstained'),
	('LOC_MPT_WC_ABSTAIN_TT',		'en_US',	'Abstain: cast no votes on this item. It will count as zero votes when submitted (click again to vote).'),
	('LOC_MPT_WC_ABSTAIN_SUMMARY',	'en_US',	'(Abstained)');
