-- 条目32：万神殿面板增强文本（参数名称/描述 + 条目32优化 万神殿信仰够通知 Message/Summary；tag 沿用 1.65 BPC 原名）
-- 注册：FE_BPC_Text（参数文案，设置界面消费）+ IG_BPC_Text（通知文案，通知栏消费）同文件双注册（条目24 先例）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_NO_WAIT_PANTHEON_NAME',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS][ICON_FAITH]万神殿不排队[ENDCOLOR]'),
	('LOC_NO_WAIT_PANTHEON_DESC',	'zh_Hans_CN',	'启用后当信仰一够立即在通知栏提醒「可以创立万神殿」，点击打开选择面板，无需等待按玩家顺序排队放行；万神殿名册同时显示已被他人选走的信条（置灰）'),
	('LOC_NOTIFICATION_MPT_PANTHEON_FAITH_READY_SUMMARY',	'zh_Hans_CN',	'可以创立万神殿'),
	('LOC_NOTIFICATION_MPT_PANTHEON_FAITH_READY_MESSAGE',	'zh_Hans_CN',	'信仰已足够创立万神殿，点击打开面板选择信条');
