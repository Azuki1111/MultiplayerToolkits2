-- ============================================================================
-- 条目20：智能回合计时器文本（en_US 英文，1.67 仅 zh，英文按项目规约补全）
-- Hotkey name/description: shown in Options -> Key Bindings (registered in both
--   FE and IG); button tooltips: shown on the add/reduce buttons next to the chat panel.
-- 条目20扩展：工作模式参数 MPT_TIMER_MODE 的名称/描述与四个模式值 Name/Desc。
-- 初版设置面板开关文本（LOC_MPT_SETTINGS_TIMER_ENABLE_*）已随布尔开关回退删除。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_TIMER_MODE_NAME',				'en_US',	'Turn Timer Mode (Multiplayer Toolkits)'),
	('LOC_MPT_TIMER_MODE_DESC',				'en_US',	'Working mode of the turn timer managed by this mod. The host can change it anytime via Game Options in the pause menu'),
	('LOC_MPT_TIMER_MODE_OFF',				'en_US',	'All Timers Off'),
	('LOC_MPT_TIMER_MODE_OFF_DESC',			'en_US',	'No timer management at all; turn time is decided by the vanilla turn timer parameter in game setup'),
	('LOC_MPT_TIMER_MODE_BASIC',			'en_US',	'Basic Timer'),
	('LOC_MPT_TIMER_MODE_BASIC_DESC',		'en_US',	'Chat commands only: p+ add 20s (once per turn) / p+++ no timer this turn / p-- 15s less next turn; P++/P-- buttons and [ ] hotkeys relay the commands; no automatic balancing'),
	('LOC_MPT_TIMER_MODE_SMART',			'en_US',	'Smart Timer'),
	('LOC_MPT_TIMER_MODE_SMART_DESC',		'en_US',	'Automatically balances the turn time based on most players'' turn duration; adds time on war declaration / player disconnection; fixes 120s during world congress votes; includes chat commands and quick buttons/hotkeys'),
	('LOC_MPT_TIMER_MODE_FIXED',			'en_US',	'Fixed Timer'),
	('LOC_MPT_TIMER_MODE_FIXED_DESC',		'en_US',	'Turn-based tiered curve: starts at 30s, 80s from turn 30, 120s from turn 50, 180s from turn 70 and keeps it; chat commands not included'),
	('LOC_MPT_TIMER_HOTKEY_ADD_NAME',		'en_US',	'[COLOR:ResGoldLabelCS]Add Time (Smart Timer)[ENDCOLOR]'),
	('LOC_MPT_TIMER_HOTKEY_ADD_DESC',		'en_US',	'Add 20 seconds (host applies and broadcasts directly; non-hosts send chat command p++ automatically, requires Basic/Smart Timer mode)'),
	('LOC_MPT_TIMER_HOTKEY_REDUCE_NAME',	'en_US',	'[COLOR:ResGoldLabelCS]Reduce Time (Smart Timer)[ENDCOLOR]'),
	('LOC_MPT_TIMER_HOTKEY_REDUCE_DESC',	'en_US',	'Reduce 10 seconds (floor 40s; non-hosts send chat command p-- automatically)'),
	('LOC_MPT_TIMER_ADD_BUTTON_TT',			'en_US',	'Add 20 seconds now[NEWLINE][NEWLINE]Type p+++ to disable the turn timer'),
	('LOC_MPT_TIMER_REDUCE_BUTTON_TT',		'en_US',	'15 seconds less next turn');
