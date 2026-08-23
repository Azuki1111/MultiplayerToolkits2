-- ============================================================================
-- 条目10：交易限制与外交限制文本（en_US）
-- 移植 1.67 DDV（原作仅有中文，英文为本 mod 自译；tag 保持原名与 MPH/1.67 兼容）
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	-- Trade setting presets
	('LOC_SETTINGS_DIPLOMATIC_DEAL_NAME',			'en_US',	'Trade Settings'),
	('LOC_SETTINGS_DIPLOMATIC_DEAL_DESC',			'en_US',	'Restrict what players can trade'),
	('LOC_SETTINGS_DEAL_NORM_NAME',					'en_US',	'Normal (Recommended)'),
	('LOC_SETTINGS_DEAL_NORM_DESC',					'en_US',	'Only city trading is banned'),
	('LOC_SETTINGS_DEAL_CLASSIC_NAME',				'en_US',	'Classic [icon_Gold]'),
	('LOC_SETTINGS_DEAL_CLASSIC_DESC',				'en_US',	'Only gold and city trading is banned'),
	('LOC_SETTINGS_DEAL_ALONE_NAME',				'en_US',	'Isolated [icon_Not]'),
	('LOC_SETTINGS_DEAL_ALONE_DESC',				'en_US',	'All trading is banned except luxuries (you can still form alliances)'),
	('LOC_SETTINGS_DEAL_CUSTOM_NAME',				'en_US',	'Custom'),
	('LOC_SETTINGS_DEAL_CUSTOM_DESC',				'en_US',	'Choose which trade categories to ban'),
	-- Custom mode bans
	('LOC_TPT_NO_TRADING_CITIES_NAME',				'en_US',	'Ban City Trading'),
	('LOC_TPT_NO_TRADING_CITIES_DESC',				'en_US',	'Ban city trading'),
	('LOC_TPT_NO_TRADING_GOLD_NAME',				'en_US',	'Ban Gold Trading'),
	('LOC_TPT_NO_TRADING_GOLD_DESC',				'en_US',	'Ban gold trading'),
	('LOC_TPT_NO_TRADING_STRATEGICS_NAME',			'en_US',	'Ban Strategic Resource Trading'),
	('LOC_TPT_NO_TRADING_STRATEGICS_DESC',			'en_US',	'Ban strategic resource trading'),
	('LOC_TPT_NO_TRADING_LUXURIES_NAME',			'en_US',	'Ban Luxury Trading'),
	('LOC_TPT_NO_TRADING_LUXURIES_DESC',			'en_US',	'Ban luxury resource trading'),
	('LOC_TPT_NO_TRADING_FAVOR_NAME',				'en_US',	'Ban Diplomatic Favor Trading'),
	('LOC_TPT_NO_TRADING_FAVOR_DESC',				'en_US',	'Ban diplomatic favor trading'),
	('LOC_TPT_NO_TRADING_GREATWORKS_NAME',			'en_US',	'Ban Great Works Trading'),
	('LOC_TPT_NO_TRADING_GREATWORKS_DESC',			'en_US',	'Ban Great Works trading'),
	('LOC_TPT_NO_TRADING_CAPTIVES_NAME',			'en_US',	'Ban Captive Trading'),
	('LOC_TPT_NO_TRADING_CAPTIVES_DESC',			'en_US',	'Ban captive (spy) trading'),
	('LOC_TPT_NO_TRADING_AGREEMENTS_NAME',			'en_US',	'Ban Diplomatic Agreements'),
	('LOC_TPT_NO_TRADING_AGREEMENTS_DESC',			'en_US',	'Ban diplomatic agreements (Open Borders, Join War)'),
	-- No delegations
	('LOC_TPT_NO_DELEGATION_NAME',					'en_US',	'No Delegations'),
	('LOC_TPT_NO_DELEGATION_DESC',					'en_US',	'Cannot send delegations (embassies are still allowed)'),
	-- No friendship
	('LOC_TPT_NO_FRIENDSHIP_NAME',					'en_US',	'No Friendship'),
	('LOC_TPT_NO_FRIENDSHIP_DESC',					'en_US',	'Players cannot declare friendship when enabled'),
	-- Make peace setting
	('LOC_DIPLOMACY_WAR_MAKE_PEACE_CONFIG',			'en_US',	'Peace Settings'),
	('LOC_DIPLOMACY_WAR_NO_MAKE_PEACE_NAME',		'en_US',	'No Peace'),
	('LOC_DIPLOMACY_WAR_NO_MAKE_PEACE_DESC',		'en_US',	'Cannot make peace with civilizations or city-states after declaring war'),
	('LOC_DIPLOMACY_WAR_CAN_MAKE_PEACE_NAME',		'en_US',	'Allow Peace'),
	('LOC_DIPLOMACY_WAR_CAN_MAKE_PEACE_DESC',		'en_US',	'Peace is allowed after some turns'),
	('LOC_DIPLOMACY_WAR_DEFAULT_MAKE_PEACE_NAME',	'en_US',	'Default'),
	('LOC_DIPLOMACY_WAR_DEFAULT_MAKE_PEACE_DESC',	'en_US',	'Follow the default settings of other mods');
