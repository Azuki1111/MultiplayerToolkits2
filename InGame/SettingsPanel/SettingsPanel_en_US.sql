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
	('LOC_MPT_SETTINGS_DPR_PNAME_NAME',	'en_US',	'Diplomacy Ribbon: Show player name'),
	('LOC_MPT_SETTINGS_DPR_PNAME_TT',	'en_US',	'Show the player name at the top of each ribbon card (item 24 DPR)'),
	('LOC_MPT_SETTINGS_DPR_CNAME_NAME',	'en_US',	'Diplomacy Ribbon: Show civilization name'),
	('LOC_MPT_SETTINGS_DPR_CNAME_TT',	'en_US',	'Show the civilization short name at the top of each ribbon card (item 24 DPR)'),
	('LOC_MPT_SETTINGS_BER_NAME',	'en_US',	'Always Show Great General Era'),
	('LOC_MPT_SETTINGS_BER_TT',	'en_US',	'Show the era label below Great General unit flags (item 25 BER)'),
	('LOC_MPT_SETTINGS_NDR_NAME',	'en_US',	'Deal Sound Reminder'),
	('LOC_MPT_SETTINGS_NDR_TT',	'en_US',	'Plays a sound when another player sends you a deal or diplomatic request (item 26 NDR; notification auto-expand is not affected by this switch, same as 1.67)'),
	('LOC_MPT_SETTINGS_GPR_NAME',	'en_US',	'Great Person Recruited Notification'),
	('LOC_MPT_SETTINGS_GPR_TT',	'en_US',	'Sends you a notification when another player recruits a Great Person (item 26)');
-- The initial item-20 smart timer switch texts (LOC_MPT_SETTINGS_TIMER_ENABLE_*) were
-- replaced by the 4-mode Game config parameter in the item-20 extension; texts moved to
-- InGame/SmartTurnTimer/ localized SQL files.
-- Item 22: the 4 BTS option texts (LOC_MPT_SETTINGS_BTS_*) were removed in the
-- item-22 adjustment per user verdict — the 4 options are not user-configurable and
-- are hardcoded to the 1.67 BTS_Settings.sql defaults (parameter rows removed too).
-- Item 25: BER switch texts follow the 1.67 wording (1.67 shipped zh only, registered
-- twice by mistake; en_US added here per project convention).
-- Item 26: NDR switch texts follow the 1.67 wording (1.67 shipped zh only; en added
-- here); GPR switch texts are self-written (source mod 2459772036 has no settings system).
-- Item 27 WCABSTAIN switch texts were removed along with the feature (user verdict:
-- the engine gives no way to skip a vote, abstain is not implementable).
