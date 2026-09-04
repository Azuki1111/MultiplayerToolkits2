-- 条目32：万神殿面板增强文本（高级选项「万神殿不排队」名称/描述；tag 沿用 1.65 BPC 原名，仅前端注册——设置界面消费，条目16/31 同形态先例）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_NO_WAIT_PANTHEON_NAME',	'en_US',	'[COLOR:ResGoldLabelCS][ICON_FAITH]No-Wait Pantheon[ENDCOLOR]'),
	('LOC_NO_WAIT_PANTHEON_DESC',	'en_US',	'Opens the Pantheon chooser as soon as you have enough Faith instead of waiting for the founding queue; the roster also shows beliefs already taken by others (grayed out)');
