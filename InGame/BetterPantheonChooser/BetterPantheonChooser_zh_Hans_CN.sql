-- 条目32：万神殿面板增强文本（高级选项「万神殿不排队」名称/描述；tag 沿用 1.65 BPC 原名，仅前端注册——设置界面消费，条目16/31 同形态先例）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_NO_WAIT_PANTHEON_NAME',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS][ICON_FAITH]万神殿不排队[ENDCOLOR]'),
	('LOC_NO_WAIT_PANTHEON_DESC',	'zh_Hans_CN',	'启用后当信仰一够即自动弹出选万神殿面板，无需等待按玩家顺序排队放行；万神殿名册同时显示已被他人选走的信条（置灰）');
