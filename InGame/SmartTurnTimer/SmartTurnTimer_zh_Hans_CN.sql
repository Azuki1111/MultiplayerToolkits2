-- ============================================================================
-- 条目20：智能回合计时器文本（zh_Hans_CN 简体中文）
-- 热键名/描述：设置→按键绑定列表显示（前后端各注册，主菜单也要显示）；
-- 按钮 tooltip：聊天框旁快捷按钮悬停显示。
-- 条目20优化10：1.67 减时按钮 tooltip「下回合减少20秒」与实际 p-- 的 -15 秒不符，
--   本 mod 文本按实际值写；开关 Name/TT 在 SettingsPanel 双语文件（LOC_MPT_SETTINGS_TIMER_ENABLE_*）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_TIMER_HOTKEY_ADD_NAME',		'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]快捷加时（智能计时器）[ENDCOLOR]'),
	('LOC_MPT_TIMER_HOTKEY_ADD_DESC',		'zh_Hans_CN',	'加时20秒（房主直接生效并广播；非房主自动代发聊天指令 p++，需房主开启智能计时器）'),
	('LOC_MPT_TIMER_HOTKEY_REDUCE_NAME',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]快捷减时（智能计时器）[ENDCOLOR]'),
	('LOC_MPT_TIMER_HOTKEY_REDUCE_DESC',	'zh_Hans_CN',	'减时10秒（下限40秒；非房主自动代发聊天指令 p--）'),
	('LOC_MPT_TIMER_ADD_BUTTON_TT',			'zh_Hans_CN',	'立即加时20秒[NEWLINE][NEWLINE]输入 p+++ 可以无回合时间'),
	('LOC_MPT_TIMER_REDUCE_BUTTON_TT',		'zh_Hans_CN',	'下回合减少15秒');
