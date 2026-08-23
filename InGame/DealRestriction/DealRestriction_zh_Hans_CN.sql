-- ============================================================================
-- 条目10：交易限制与外交限制文本（zh_Hans_CN）
-- 移植 1.67 DDV/Comfig_Deal_Text.xml + Comfig_Friendship_Text.xml + Config_MakePeace_Text.xml
-- （tag 全部保持原名，与 MPH/1.67 兼容）
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	-- 交易设置四模式
	('LOC_SETTINGS_DIPLOMATIC_DEAL_NAME',			'zh_Hans_CN',	'交易设置'),
	('LOC_SETTINGS_DIPLOMATIC_DEAL_DESC',			'zh_Hans_CN',	'可禁止玩家交易'),
	('LOC_SETTINGS_DEAL_NORM_NAME',					'zh_Hans_CN',	'常规(推荐)'),
	('LOC_SETTINGS_DEAL_NORM_DESC',					'zh_Hans_CN',	'仅禁止交易城市'),
	('LOC_SETTINGS_DEAL_CLASSIC_NAME',				'zh_Hans_CN',	'经典[icon_Gold]'),
	('LOC_SETTINGS_DEAL_CLASSIC_DESC',				'zh_Hans_CN',	'仅禁止交易金币和城市'),
	('LOC_SETTINGS_DEAL_ALONE_NAME',				'zh_Hans_CN',	'独立[icon_Not]'),
	('LOC_SETTINGS_DEAL_ALONE_DESC',				'zh_Hans_CN',	'禁止所有交易，除了奢侈品(你仍然可以同盟)'),
	('LOC_SETTINGS_DEAL_CUSTOM_NAME',				'zh_Hans_CN',	'自定义'),
	('LOC_SETTINGS_DEAL_CUSTOM_DESC',				'zh_Hans_CN',	'选择要禁用的交易内容'),
	-- 自定义模式下的 8 个禁止项
	('LOC_TPT_NO_TRADING_CITIES_NAME',				'zh_Hans_CN',	'禁止交易城市'),
	('LOC_TPT_NO_TRADING_CITIES_DESC',				'zh_Hans_CN',	'禁止交易城市'),
	('LOC_TPT_NO_TRADING_GOLD_NAME',				'zh_Hans_CN',	'禁止交易金币'),
	('LOC_TPT_NO_TRADING_GOLD_DESC',				'zh_Hans_CN',	'禁止交易金币'),
	('LOC_TPT_NO_TRADING_STRATEGICS_NAME',			'zh_Hans_CN',	'禁止交易战略资源'),
	('LOC_TPT_NO_TRADING_STRATEGICS_DESC',			'zh_Hans_CN',	'禁止交易战略资源'),
	('LOC_TPT_NO_TRADING_LUXURIES_NAME',			'zh_Hans_CN',	'禁止交易奢侈品'),
	('LOC_TPT_NO_TRADING_LUXURIES_DESC',			'zh_Hans_CN',	'禁止交易奢侈品'),
	('LOC_TPT_NO_TRADING_FAVOR_NAME',				'zh_Hans_CN',	'禁止交易外交支持'),
	('LOC_TPT_NO_TRADING_FAVOR_DESC',				'zh_Hans_CN',	'禁止交易外交支持'),
	('LOC_TPT_NO_TRADING_GREATWORKS_NAME',			'zh_Hans_CN',	'禁止交易巨作'),
	('LOC_TPT_NO_TRADING_GREATWORKS_DESC',			'zh_Hans_CN',	'禁止交易巨作'),
	('LOC_TPT_NO_TRADING_CAPTIVES_NAME',			'zh_Hans_CN',	'禁止交易俘虏'),
	('LOC_TPT_NO_TRADING_CAPTIVES_DESC',			'zh_Hans_CN',	'禁止交易俘虏(间谍)'),
	('LOC_TPT_NO_TRADING_AGREEMENTS_NAME',			'zh_Hans_CN',	'禁止外交协议'),
	('LOC_TPT_NO_TRADING_AGREEMENTS_DESC',			'zh_Hans_CN',	'禁止外交协议(开放边界,加入战争)'),
	-- 无代表团
	('LOC_TPT_NO_DELEGATION_NAME',					'zh_Hans_CN',	'无代表团'),
	('LOC_TPT_NO_DELEGATION_DESC',					'zh_Hans_CN',	'无法派遣代表团（仍然可以建立大使馆）'),
	-- 无友谊
	('LOC_TPT_NO_FRIENDSHIP_NAME',					'zh_Hans_CN',	'无友谊'),
	('LOC_TPT_NO_FRIENDSHIP_DESC',					'zh_Hans_CN',	'启用此选项后无法宣布友谊'),
	-- 和解设置
	('LOC_DIPLOMACY_WAR_MAKE_PEACE_CONFIG',			'zh_Hans_CN',	'和解设置'),
	('LOC_DIPLOMACY_WAR_NO_MAKE_PEACE_NAME',		'zh_Hans_CN',	'无法和解'),
	('LOC_DIPLOMACY_WAR_NO_MAKE_PEACE_DESC',		'zh_Hans_CN',	'宣战后无法与其他文明或城邦和解'),
	('LOC_DIPLOMACY_WAR_CAN_MAKE_PEACE_NAME',		'zh_Hans_CN',	'允许和解'),
	('LOC_DIPLOMACY_WAR_CAN_MAKE_PEACE_DESC',		'zh_Hans_CN',	'允许在一段时间后和解'),
	('LOC_DIPLOMACY_WAR_DEFAULT_MAKE_PEACE_NAME',	'zh_Hans_CN',	'默认'),
	('LOC_DIPLOMACY_WAR_DEFAULT_MAKE_PEACE_DESC',	'zh_Hans_CN',	'根据其他模组的默认设置');
