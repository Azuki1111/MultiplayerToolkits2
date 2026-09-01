-- Entry 21 optimization: custom phrases for policy card effect lines (no-arg tags, Lua .. concatenation)
-- [MPT user decision] 13 phrases after narrowing display types; card lines are joined with LOC_MPT_EPC_SEPARATOR
-- (omitted when the seam ends with an [ICON_..] token - icons separate naturally; no line breaks on cards,
-- tooltips use the [NEWLINE] variant); turn descriptions ("/per turn") removed entirely
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
	('LOC_MPT_EPC_PRODUCTION',			'en_US',	' Production'),
	('LOC_MPT_EPC_PROJECTS',			'en_US',	'projects'),
	('LOC_MPT_EPC_SPACE_PROJECTS',		'en_US',	'Space Race projects'),
	('LOC_MPT_EPC_ALL_UNITS',			'en_US',	'all units'),
	('LOC_MPT_EPC_WONDER',				'en_US',	'Wonder'),
	('LOC_MPT_EPC_CS_TRADE',			'en_US',	'trade with city-states'),
	('LOC_MPT_EPC_PER_BUILDING',		'en_US',	'per '),
	('LOC_MPT_EPC_RESOLUTION',			'en_US',	'world resolution'),
	('LOC_MPT_EPC_RESOURCE_FREE',		'en_US',	'free resource per city'),
	('LOC_MPT_EPC_INFLUENCE',			'en_US',	'influence points'),
	('LOC_MPT_EPC_ALLIANCE',			'en_US',	'alliance points'),
	('LOC_MPT_EPC_BUILD_CHARGES',		'en_US',	'builder charges'),
	('LOC_MPT_EPC_SEPARATOR',			'en_US',	', ');
