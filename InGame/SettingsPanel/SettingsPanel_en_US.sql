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
	('LOC_MPT_SETTINGS_BTS_PATH_NAME',	'en_US',	'BTS Trade: Approximate trader path'),
	('LOC_MPT_SETTINGS_BTS_PATH_TT',	'en_US',	'Use absolute distance to approximate the trader path rather than the actual path (item 22 BTS). Makes the trade panels open faster with many cities, but trade route duration in turns can be very inaccurate in some cases'),
	('LOC_MPT_SETTINGS_BTS_SORT_NAME',	'en_US',	'BTS Trade: Show sort priorities'),
	('LOC_MPT_SETTINGS_BTS_SORT_TT',	'en_US',	'Always show priorities of multi-level sorting on the sort buttons (item 22 BTS). Useful when sorting by multiple yields like food + production; hold Shift to show temporarily when off'),
	('LOC_MPT_SETTINGS_BTS_LPATH_NAME',	'en_US',	'BTS Trade: Show all route paths'),
	('LOC_MPT_SETTINGS_BTS_LPATH_TT',	'en_US',	'Show all candidate route paths in the route chooser panel, not just the selected one (item 22 BTS). Disabling speeds up panel opening'),
	('LOC_MPT_SETTINGS_BTS_TPATH_NAME',	'en_US',	'BTS Trade: Show trader path on selection'),
	('LOC_MPT_SETTINGS_BTS_TPATH_TT',	'en_US',	'Automatically show the running route path and its origin/destination cities when selecting your trader (item 22 BTS)');
-- The initial item-20 smart timer switch texts (LOC_MPT_SETTINGS_TIMER_ENABLE_*) were
-- replaced by the 4-mode Game config parameter in the item-20 extension; texts moved to
-- InGame/SmartTurnTimer/ localized SQL files.
-- Item 22: the 4 BTS option texts are ported from 1.67 BTS/Text/BTS_Text_EN.xml
-- (LOC_BTS_SETTING_*), retagged to LOC_MPT_SETTINGS_BTS_* per project convention.
