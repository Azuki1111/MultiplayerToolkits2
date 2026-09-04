-- 条目32：万神殿面板增强文本（参数名称/描述 + 条目32优化 万神殿信仰够通知 Message/Summary；tag 沿用 1.65 BPC 原名）
-- 注册：FE_BPC_Text（参数文案，设置界面消费）+ IG_BPC_Text（通知文案，通知栏消费）同文件双注册（条目24 先例）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_NO_WAIT_PANTHEON_NAME',	'en_US',	'[COLOR:ResGoldLabelCS][ICON_FAITH]No-Wait Pantheon[ENDCOLOR]'),
	('LOC_NO_WAIT_PANTHEON_DESC',	'en_US',	'Reminds you via a notification the moment you have enough Faith to found a Pantheon (click it to open the chooser) instead of waiting for the founding queue; the roster also shows beliefs already taken by others (grayed out)'),
	('LOC_NOTIFICATION_MPT_PANTHEON_FAITH_READY_SUMMARY',	'en_US',	'Pantheon Available'),
	('LOC_NOTIFICATION_MPT_PANTHEON_FAITH_READY_MESSAGE',	'en_US',	'You have enough Faith to found a Pantheon. Click to open the chooser and pick a belief.');
