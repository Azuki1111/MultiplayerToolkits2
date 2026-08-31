-- ============================================================================
-- 条目12：In-Game Settings Panel Text (en_US)
-- LOC_MPT_SETTINGS_SHOW_FEB_NAME/TT ported from 1.67 Settings/TPT_Settings_Text.xml
--   (1.67 had zh only; en added per project convention), tag renamed to MPT_ prefix;
-- Panel title / confirm button reuse vanilla LOC_GAMESUMMARY_HISTORY_SETTINGS / LOC_AUTONARRATE_BUTTON_DONE.
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_SETTINGS_SHOW_FEB_NAME',	'en_US',	'Show Forced End Turn Button'),
	('LOC_MPT_SETTINGS_SHOW_FEB_TT',	'en_US',	'Show the button'),
	('LOC_MPT_SETTINGS_NOC_DISABLE_NAME',	'en_US',	'Disable Notification Clear Button'),
	('LOC_MPT_SETTINGS_NOC_DISABLE_TT',	'en_US',	'Hide the notification clear button at the bottom-right notification panel (item 19 NOC)'),
	('LOC_MPT_SETTINGS_TIMER_ENABLE_NAME',	'en_US',	'[COLOR:ResGoldLabelCS]Smart Turn Timer[ENDCOLOR]'),
	('LOC_MPT_SETTINGS_TIMER_ENABLE_TT',	'en_US',	'The host automatically balances the turn timer based on most players'' turn time; adds time on war declaration / player disconnection; fixes 120s during world congress votes[NEWLINE]Chat commands: p+ add 20s (once per turn) / p+++ no timer this turn / p-- 15s less next turn[NEWLINE]P++/P-- buttons next to the chat panel and [ ] hotkeys add/reduce time quickly (non-hosts relay the command automatically); this switch is local per player');
