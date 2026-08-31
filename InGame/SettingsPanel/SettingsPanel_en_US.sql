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
	('LOC_MPT_SETTINGS_NOC_DISABLE_TT',	'en_US',	'Hide the notification clear button at the bottom-right notification panel (item 19 NOC)');
