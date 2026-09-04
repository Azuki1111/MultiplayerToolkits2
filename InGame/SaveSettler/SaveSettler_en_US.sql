-- 条目33：拯救开拓者文本（参数名/描述 FE 设置界面消费 + 漂浮文本 Gameplay 脚本消费，
-- 双环境注册同 FrontEnd/Text 先例；颜色 ResGoldLabelCS 沿用源 mod 的金色样式）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_SAVESETTLER_NAME',	'en_US',	'[COLOR:ResGoldLabelCS]Save the Settler[ENDCOLOR]'),
	('LOC_MPT_SAVESETTLER_DESC',	'en_US',	'Settlers are no longer captured when attacked - they retreat back to a city instead. With fewer than 3 cities the city loses 2 Population; with 3 or more cities the Settler is removed.'),
	('LOC_MPT_SAVESETTLER_RETURNED',	'en_US',	'[COLOR:ResGoldLabelCS]The Settler returned to the city[ENDCOLOR]'),
	('LOC_MPT_SAVESETTLER_POPLOSS',	'en_US',	'[COLOR:ResGoldLabelCS]City loses 2 Population[ENDCOLOR]'),
	('LOC_MPT_SAVESETTLER_DIED',	'en_US',	'[COLOR:ResGoldLabelCS]The Settler died! This is all your fault![ENDCOLOR]');
