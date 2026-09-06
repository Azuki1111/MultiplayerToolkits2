-- ============================================================================
-- 条目8：WorldTracker 快捷操作面板文本（en_US）
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_QUICK_HEADER',	'en_US',	'Quick Actions'),
	('LOC_MPT_QUICK_SURRENDER',	'en_US',	'Surrender'),
	('LOC_MPT_QUICK_RESTART',	'en_US',	'Restart'),
	-- 条目11：游戏内玩家标记面板打开按钮（点击经 LuaEvents.MPT_PlayerMark_Toggle 打开/关闭面板）
	('LOC_MPT_QUICK_PLAYERMARK',	'en_US',	'Player Marks'),
	('LOC_MPT_QUICK_PLAYERMARK_TT',	'en_US',	'Open the player mark manager'),
	-- 条目12：游戏内设置面板打开按钮（点击经 LuaEvents.MPT_SettingsPanel_Toggle 打开/关闭面板，见 InGame/SettingsPanel/）
	('LOC_MPT_QUICK_SETTINGS',	'en_US',	'Settings'),
	-- 条目34：反作弊监测面板打开按钮（点击经 LuaEvents.MPT_HashCheck_Toggle 打开/关闭面板，见 InGame/HashCheck/；
	-- 高级选项 MPT_HASH_CHECK 未勾选时按钮整个隐藏）
	('LOC_MPT_QUICK_HASHCHECK',	'en_US',	'Anti-Cheat Monitor'),
	('LOC_MPT_QUICK_HASHCHECK_TT',	'en_US',	'Open the anti-cheat monitor panel');
