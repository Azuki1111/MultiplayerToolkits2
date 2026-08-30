-- ============================================================================
-- 条目12：游戏内设置面板文本（zh_Hans_CN 简体中文）
-- LOC_MPT_SETTINGS_SHOW_FEB_NAME/TT 移植 1.67 Settings/TPT_Settings_Text.xml 的
--   LOC_SHOW_FEB_NAME/TT（1.67 仅 zh），tag 统一 MPT_ 前缀避免与 1.67 冲突（项目规约）；
-- 面板标题/确认按钮复用原版 LOC_GAMESUMMARY_HISTORY_SETTINGS / LOC_AUTONARRATE_BUTTON_DONE，不新增。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_SETTINGS_SHOW_FEB_NAME',	'zh_Hans_CN',	'显示强制结束回合按钮'),
	('LOC_MPT_SETTINGS_SHOW_FEB_TT',	'zh_Hans_CN',	'显示按钮');
