-- ============================================================================
-- 条目24：外交丝带扩展（DPR）英文文本——tag 与中文版一一对应（同 1.67 原 tag）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_SETTINGS_DIPLOMACYRIBBON_NAME',	'en_US',	'Hide Stats Evolved'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_DESC',	'en_US',	'Set up Hide Stats Evolved'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_NORM_NAME',	'en_US',	'Standard(Recommend)'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_NORM_DESC',	'en_US',	'Standard Rules[NEWLINE][NEWLINE][icon_You]Does not show the military strength, total population, total productivity, and total food of players who are not on your team'),
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
	('LOC_DPR_FAVOR_PERTURN',	'en_US',	'Favor per Turn');
