-- ============================================================================
-- 条目8：WorldTracker 快捷操作面板文本（zh_Hans_CN）
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_QUICK_HEADER',	'zh_Hans_CN',	'快捷操作'),
	('LOC_MPT_QUICK_SURRENDER',	'zh_Hans_CN',	'投降'),
	('LOC_MPT_QUICK_RESTART',	'zh_Hans_CN',	'重新开始'),
	-- 条目11：游戏内玩家标记面板打开按钮（点击经 LuaEvents.MPT_PlayerMark_Toggle 打开/关闭面板）
	('LOC_MPT_QUICK_PLAYERMARK',	'zh_Hans_CN',	'玩家标记'),
	('LOC_MPT_QUICK_PLAYERMARK_TT',	'zh_Hans_CN',	'打开玩家标记管理面板（本地玩家档案：好友/一般/黑名单标记与记事本，与准备房间同一份存档）'),
	-- 条目12：游戏内设置面板打开按钮（点击经 LuaEvents.MPT_Settings_Toggle 打开/关闭面板，见 InGame/ForcedEndTurn/）
	('LOC_MPT_QUICK_SETTINGS',	'zh_Hans_CN',	'设置');
