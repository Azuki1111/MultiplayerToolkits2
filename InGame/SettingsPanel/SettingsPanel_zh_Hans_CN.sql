-- ============================================================================
-- 条目12：游戏内设置面板文本（zh_Hans_CN 简体中文）
-- LOC_MPT_SETTINGS_SHOW_FEB_NAME/TT 移植 1.67 Settings/TPT_Settings_Text.xml 的
--   LOC_SHOW_FEB_NAME/TT（1.67 仅 zh），tag 统一 MPT_ 前缀避免与 1.67 冲突（项目规约）；
-- 面板标题/确认按钮复用原版 LOC_GAMESUMMARY_HISTORY_SETTINGS / LOC_AUTONARRATE_BUTTON_DONE，不新增。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_SETTINGS_SHOW_FEB_NAME',	'zh_Hans_CN',	'显示强制结束回合按钮'),
	('LOC_MPT_SETTINGS_SHOW_FEB_TT',	'zh_Hans_CN',	'显示按钮'),
	('LOC_MPT_SETTINGS_NOC_DISABLE_NAME',	'zh_Hans_CN',	'禁用清理通知按钮'),
	('LOC_MPT_SETTINGS_NOC_DISABLE_TT',	'zh_Hans_CN',	'不再显示右下角通知栏的「清理通知」按钮（条目19 NOC）'),
	('LOC_MPT_SETTINGS_TIMER_ENABLE_NAME',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]智能计时器[ENDCOLOR]'),
	('LOC_MPT_SETTINGS_TIMER_ENABLE_TT',	'zh_Hans_CN',	'房主根据多数玩家回合用时自动平衡回合时间，宣战/玩家掉线时自动加时，议会投票阶段固定120秒[NEWLINE]聊天指令：p+ 加时20秒(每回合1次) / p+++ 本回合无回合时间 / p-- 下回合减时15秒[NEWLINE]聊天框旁 P++/P-- 按钮与 [ ] 热键可快捷加/减时（非房主自动代发指令）；本开关为每玩家本地开关');
