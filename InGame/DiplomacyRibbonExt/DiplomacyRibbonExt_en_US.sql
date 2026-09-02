-- ============================================================================
-- 条目24：外交丝带扩展（DPR）英文文本——tag 与中文版一一对应（同 1.67 原 tag）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_SETTINGS_DIPLOMACYRIBBON_NAME',	'en_US',	'Hide Stats Evolved'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_DESC',	'en_US',	'Set up Hide Stats Evolved'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_NORM_NAME',	'en_US',	'Standard(Recommend)'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_NORM_DESC',	'en_US',	'Standard Rules[NEWLINE][NEWLINE][icon_You]Does not show the military strength, total population, total productivity, and total food of players who are not on your team'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_DEFAULT_NAME',	'en_US',	'Default'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_DEFAULT_DESC',	'en_US',	'Based on Standard (Recommend), but also shows the military strength of all players[NEWLINE][NEWLINE][icon_You]Still hides the total population, total productivity, and total food of players who are not on your team'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_VISIBILITY_TEAM_NAME',	'en_US',	'Hide Stats Evolved Mode([COLOR:ResGoldLabelCS]Team[ENDCOLOR])'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_VISIBILITY_TEAM_DESC',	'en_US',	'Hide Stats Evolved Mode[NEWLINE][NEWLINE][icon_You]Team members share information with each other, and other players need a higher visibility level to view it'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_PUBLIC_NAME',	'en_US',	'Public(Fully Visible)'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_PUBLIC_DESC',	'en_US',	'All players'' information is public[NEWLINE][NEWLINE][icon_You]Open cautiously, suitable for PVE games'),
	('LOC_DPR_TECHCIVIS_NAME',	'en_US',	'[COLOR:ResGoldLabelCS]Show/hide researching progress[ENDCOLOR]'),
	('LOC_DPR_TECHCIVIS_DESC',	'en_US',	'Shows the Tech Civic Progress of other players'),
	('LOC_DPR_TOTALYIELD_NAME',	'en_US',	'[COLOR:ResGoldLabelCS]Toggle the stats display[ENDCOLOR]'),
	('LOC_DPR_TOTALYIELD_DESC',	'en_US',	'Toggle between general stats and other stats'),
	('LOC_DPR_TOTAL_POPULATION',	'en_US',	'Total population'),
	('LOC_DPR_FOOD_SURPLUS_YIELD',	'en_US',	'Food Surplus per Turn'),
	('LOC_DPR_PRODUCTION_YIELD',	'en_US',	'Production per Turn'),
	('LOC_DPR_GOLD_PERTURN',	'en_US',	'Gold per Turn'),
	('LOC_DPR_FAITH_PERTURN',	'en_US',	'Faith per Turn'),
	('LOC_DPR_FAVOR_PERTURN',	'en_US',	'Favor per Turn'),
	-- Entry 24 fix: observer UI (BSM port) text localization (BSM hardcoded English)
	('LOC_MPT_DPR_SPEC_OBSERVER',	'en_US',	'Observer'),
	('LOC_MPT_DPR_SPEC_HOST',	'en_US',	'Host'),
	('LOC_MPT_DPR_SPEC_CURRENT',	'en_US',	'Current:'),
	('LOC_MPT_DPR_SPEC_NEXT',	'en_US',	'Next:'),
	('LOC_MPT_DPR_SPEC_SCORE',	'en_US',	'Score'),
	('LOC_MPT_DPR_SPEC_YIELD',	'en_US',	'Yield'),
	('LOC_MPT_DPR_SPEC_TOTAL',	'en_US',	'Total'),
	('LOC_MPT_DPR_SPEC_TECHS',	'en_US',	'Techs'),
	('LOC_MPT_DPR_SPEC_ERAS',	'en_US',	'Eras'),
	('LOC_MPT_DPR_SPEC_ARMY',	'en_US',	'Army'),
	('LOC_MPT_DPR_SPEC_LAND',	'en_US',	'Land: '),
	('LOC_MPT_DPR_SPEC_NAVY',	'en_US',	'Navy: '),
	('LOC_MPT_DPR_SPEC_AIR',	'en_US',	'Air: ');
