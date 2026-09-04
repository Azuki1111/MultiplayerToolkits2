-- 条目33：拯救开拓者文本（参数名/描述 FE 设置界面消费 + 漂浮文本 Gameplay 脚本消费，
-- 双环境注册同 FrontEnd/Text 先例；颜色 ResGoldLabelCS 沿用源 mod 的金色样式）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_SAVESETTLER_NAME',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]拯救开拓者[ENDCOLOR]'),
	('LOC_MPT_SAVESETTLER_DESC',	'zh_Hans_CN',	'开拓者被敌军擒获时不再被抢走，而是撤退回城：所在城市人口-2'),
	('LOC_MPT_SAVESETTLER_RETURNED',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]开拓者返回了城市[ENDCOLOR]'),
	('LOC_MPT_SAVESETTLER_POPLOSS',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]城市人口-2[ENDCOLOR]');
