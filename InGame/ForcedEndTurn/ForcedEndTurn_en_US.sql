-- ============================================================================
-- 条目12：Forced End Turn Button (FEB) & In-Game Settings Panel Text (en_US)
-- LOC_FORCEEND_TT ported from 1.67 FEB/ForcedEndButton_Text.xml;
-- LOC_SHOW_FEB_NAME/LOC_SHOW_FEB_TT ported from 1.67 Settings/TPT_Settings_Text.xml
-- (1.67 had zh only — en_US added per project convention);
-- Panel title / confirm button reuse vanilla LOC_GAMESUMMARY_HISTORY_SETTINGS / LOC_AUTONARRATE_BUTTON_DONE.
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_FORCEEND_TT',		'en_US',	'Force End of Turn'),
	('LOC_SHOW_FEB_NAME',	'en_US',	'Show Forced End Turn Button'),
	('LOC_SHOW_FEB_TT',		'en_US',	'Show the button');
