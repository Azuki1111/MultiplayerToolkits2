-- ============================================================================
-- 条目12：强制结束回合按钮(FEB)与游戏内设置面板文本（zh_Hans_CN 简体中文）
-- LOC_FORCEEND_TT 移植 1.67 FEB/ForcedEndButton_Text.xml；
-- LOC_SHOW_FEB_NAME/LOC_SHOW_FEB_TT 移植 1.67 Settings/TPT_Settings_Text.xml；
-- 面板标题/确认按钮复用原版 LOC_GAMESUMMARY_HISTORY_SETTINGS / LOC_AUTONARRATE_BUTTON_DONE，不新增。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_FORCEEND_TT',		'zh_Hans_CN',	'强制结束回合'),
	('LOC_SHOW_FEB_NAME',	'zh_Hans_CN',	'显示强制结束回合按钮'),
	('LOC_SHOW_FEB_TT',		'zh_Hans_CN',	'显示按钮');
