-- 条目34：反作弊监控文本 en_US（参数名/描述 FE 设置界面消费 + 面板文本 InGame UI 消费，
-- 同文件双环境注册 = 条目33 先例；ENTRY_TT 改无参数纯文本，Steam ID 由 Lua .. 拼接）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_HASHCHECK_NAME',			'en_US',	'Anti-Cheat Monitor'),
	('LOC_MPT_HASHCHECK_DESC',			'en_US',	'Checks that every player runs identical files in multiplayer games. Results are shown in the in-game Quick Actions panel. Enable on all players; mutually exclusive with other GameCore-hooking mods.'),
	('LOC_MPT_HASHCHECK_PANEL_TITLE',		'en_US',	'Anti-Cheat Monitor'),
	('LOC_MPT_HASHCHECK_STATUS_OK',		'en_US',	'Consistent'),
	('LOC_MPT_HASHCHECK_STATUS_MISMATCH',	'en_US',	'Mismatch'),
	('LOC_MPT_HASHCHECK_STATUS_UNKNOWN',		'en_US',	'Waiting for data...'),
	('LOC_MPT_HASHCHECK_NO_OTHER_PLAYERS',	'en_US',	'No other human players.'),
	('LOC_MPT_HASHCHECK_ENTRY_TT',			'en_US',	'Click to copy name and Steam ID'),
	('LOC_MPT_HASHCHECK_ENTRY_TT_NOID',		'en_US',	'Steam ID unavailable');
