-- ============================================================================
-- 条目20：智能回合计时器文本（en_US 英文，1.67 仅 zh，英文按项目规约补全）
-- Hotkey name/description: shown in Options -> Key Bindings (registered in both
--   FE and IG); button tooltips: shown on the P++/P-- buttons next to the chat panel.
-- Settings switch name/TT live in the SettingsPanel text files (LOC_MPT_SETTINGS_TIMER_ENABLE_*).
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_TIMER_HOTKEY_ADD_NAME',		'en_US',	'[COLOR:ResGoldLabelCS]Add Time (Smart Timer)[ENDCOLOR]'),
	('LOC_MPT_TIMER_HOTKEY_ADD_DESC',		'en_US',	'Add 20 seconds (host applies and broadcasts directly; non-hosts send chat command p++ automatically, requires the host to enable Smart Timer)'),
	('LOC_MPT_TIMER_HOTKEY_REDUCE_NAME',	'en_US',	'[COLOR:ResGoldLabelCS]Reduce Time (Smart Timer)[ENDCOLOR]'),
	('LOC_MPT_TIMER_HOTKEY_REDUCE_DESC',	'en_US',	'Reduce 10 seconds (floor 40s; non-hosts send chat command p-- automatically)'),
	('LOC_MPT_TIMER_ADD_BUTTON_TT',			'en_US',	'Add 20 seconds now[NEWLINE][NEWLINE]Type p+++ to disable the turn timer'),
	('LOC_MPT_TIMER_REDUCE_BUTTON_TT',		'en_US',	'15 seconds less next turn');
