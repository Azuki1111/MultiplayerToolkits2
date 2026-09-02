-- ============================================================================
-- 条目20：智能回合计时器文本（en_US 英文，1.67 仅 zh，英文按项目规约补全）
-- Hotkey name/description: shown in Options -> Key Bindings (registered in both
--   FE and IG); button tooltips: shown on the add/reduce buttons next to the chat panel.
-- 条目20扩展2：两项 Game 配置的文本——工作模式（三值）+ 启用聊天指令布尔开关。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_TIMER_MODE_NAME',				'en_US',	'Turn Timer Mode (Multiplayer Toolkits)'),
	('LOC_MPT_TIMER_MODE_DESC',				'en_US',	'Working mode of the turn timer managed by this mod. The host can change it anytime via Game Options in the pause menu'),
	('LOC_MPT_TIMER_MODE_OFF',				'en_US',	'All Timers Off'),
	('LOC_MPT_TIMER_MODE_OFF_DESC',			'en_US',	'No timer management at all; turn time is decided by the vanilla turn timer parameter in game setup (chat commands disabled as well)'),
	('LOC_MPT_TIMER_MODE_SMART',			'en_US',	'Smart Timer'),
	('LOC_MPT_TIMER_MODE_SMART_DESC',		'en_US',	'Automatically balances the turn time based on most players'' turn duration; adds time on war declaration / player disconnection; fixes 120s during world congress votes'),
	('LOC_MPT_TIMER_MODE_TIERED',			'en_US',	'Tiered Timer'),
	('LOC_MPT_TIMER_MODE_TIERED_DESC',		'en_US',	'Turn time follows the turn-node table with smooth linear transitions: by default 30s through turn 30, rising to 80s by turn 50, to 180s by turn 70, then keeps 180s; nodes and seconds are customizable in SmartTurnTimer_Tiers.sql'),
	('LOC_MPT_TIMER_CHAT_NAME',				'en_US',	'Enable Chat Commands'),
	('LOC_MPT_TIMER_CHAT_DESC',				'en_US',	'When enabled, chat commands and quick controls are available: p+ add 20s (once per turn) / p+++ no timer this turn / p-- 15s less next turn; the P++/P-- buttons next to the chat panel and [ ] hotkeys follow this switch; only the host reacts to commands (no effect in All-Timers-Off mode)'),
	('LOC_MPT_TIMER_HOTKEY_ADD_NAME',		'en_US',	'[COLOR:ResGoldLabelCS]Add Time (Smart Timer)[ENDCOLOR]'),
	('LOC_MPT_TIMER_HOTKEY_ADD_DESC',		'en_US',	'Add 20 seconds (host applies and broadcasts directly; non-hosts send chat command p++ automatically, requires chat commands enabled and mode not Off)'),
	('LOC_MPT_TIMER_HOTKEY_REDUCE_NAME',	'en_US',	'[COLOR:ResGoldLabelCS]Reduce Time (Smart Timer)[ENDCOLOR]'),
	('LOC_MPT_TIMER_HOTKEY_REDUCE_DESC',	'en_US',	'Reduce 10 seconds (floor 40s; non-hosts send chat command p-- automatically)'),
	('LOC_MPT_TIMER_ADD_BUTTON_TT',			'en_US',	'Add 20 seconds now[NEWLINE][NEWLINE]Type p+++ to disable the turn timer'),
	('LOC_MPT_TIMER_REDUCE_BUTTON_TT',		'en_US',	'15 seconds less next turn');
