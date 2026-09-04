-- ============================================================================
-- 条目28：更多快捷键（NHK）文本（en_US 英文，本 mod 补全——1.65 NHK 仅中文）
-- tag 与 zh 文件一一对应；沿用 1.65/DMT 原 tag 与原版现成 tag 的动作不在此登记，
-- 仅登记本 mod 自造（LOC_MPT_NHK_*）与 1.65/DMT 原 tag（补 en）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_NEW_HOTKEYS_NAME',							'en_US',	'[COLOR:ResGoldLabelCS]More Hotkeys[ENDCOLOR]'),
	('LOC_MPT_NEW_HOTKEYS_DESC',							'en_US',	'Enables the unit hotkeys in this mod: 13 unit command hotkeys such as Pillage/Upgrade/Promote/Cancel (incl. CHS-PVP extensions) and random promotion[newline][newline]Auto recruit great person, forced turn end, map pins and city ranged attack are not affected by this option'),
	('LOC_TPT_UNITCOMMAND_PROMOTE_OR_REPAIR_NAME',			'en_US',	'Pillage'),
	('LOC_TPT_UNITCOMMAND_PROMOTE_OR_REPAIR_DESC',			'en_US',	'Pillage or repair a tile'),
	('LOC_FAST_PROMOTE_NAME',								'en_US',	'Random Promotion'),
	('LOC_FAST_PROMOTE_DESC',								'en_US',	'Randomly pick an available promotion without opening the promotion tree'),
	('LOC_TURNTIME_FORCED_TURNEND_NAME',					'en_US',	'[COLOR:ResGoldLabelCS]Force End Turn[ENDCOLOR]'),
	('LOC_TURNTIME_FORCED_TURNEND_DESCRIPTION',				'en_US',	'End the turn immediately and keep force-ending every turn until pressed again'),
	('LOC_HOTKEY_AUTO_RECRUIT_NAME',						'en_US',	'[COLOR:ResGoldLabelCS]Toggle Auto Recruit Great Person[ENDCOLOR]'),
	('LOC_HOTKEY_AUTO_RECRUIT_DESCRIPTION',					'en_US',	'Toggle auto recruit mode: automatically recruit great people when eligible[newline][newline]You are the only one who can recruit, or you have the most points'),
	('LOC_DMT_OPTIONS_HOTKEY_CATEGORY',						'en_US',	'Map Pins'),
	('LOC_DMT_OPTIONS_HOTKEY_ADD_MESSAGE_TACK',				'en_US',	'[COLOR:ResGoldLabelCS]Send Chat Pin[ENDCOLOR]'),
	('LOC_DMT_OPTIONS_HOTKEY_ADD_MAP_TACK',					'en_US',	'[COLOR:ResGoldLabelCS]Add Map Pin[ENDCOLOR]'),
	('LOC_DMT_OPTIONS_HOTKEY_DELETE_MAP_TACK',				'en_US',	'[COLOR:ResGoldLabelCS]Delete Map Pin[ENDCOLOR]'),
	('LOC_DMT_OPTIONS_HOTKEY_TOGGLE_MAP_TACK_VISIBILITY_NAME',	'en_US',	'[COLOR:ResGoldLabelCS]Show/Hide All Map Pins[ENDCOLOR]'),
	('LOC_DMT_OPTIONS_HOTKEY_TOGGLE_MAP_TACK_VISIBILITY_DESC',	'en_US',	'Show or hide all map pins'),
	('LOC_MPT_NHK_PILLAGE_ROAD_NAME',						'en_US',	'Pillage/Repair Route'),
	('LOC_MPT_NHK_PILLAGE_ROAD_DESC',						'en_US',	'Pillage or repair a route, or create a trade route'),
	('LOC_MPT_NHK_PLUNDER_ROUTE_NAME',						'en_US',	'Plunder Trade Route'),
	('LOC_MPT_NHK_PLUNDER_ROUTE_DESC',						'en_US',	'Plunder a trade route'),
	('LOC_MPT_NHK_FORMATION_NAME',							'en_US',	'Enter/Exit Formation'),
	('LOC_MPT_NHK_FORMATION_DESC',							'en_US',	'Bind or unbind units (form or dissolve a formation)'),
	('LOC_MPT_NHK_REMOVE_FEATURE_NAME',						'en_US',	'Remove Feature'),
	('LOC_MPT_NHK_REMOVE_FEATURE_DESC',						'en_US',	'Remove the feature on this tile (chop forest, drain marsh, etc.) for its yields'),
	('LOC_MPT_NHK_HARVEST_NAME',							'en_US',	'Harvest Resource'),
	('LOC_MPT_NHK_HARVEST_DESC',							'en_US',	'Harvest the harvestable resource on this tile (deer, stone, etc.) for its yields');
