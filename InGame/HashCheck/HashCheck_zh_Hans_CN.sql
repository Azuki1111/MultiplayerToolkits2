-- 条目34：反作弊监控文本 zh_Hans_CN（参数名/描述 FE 设置界面消费 + 面板文本 InGame UI 消费，
-- 同文件双环境注册 = 条目33 先例；ENTRY_TT 改无参数纯文本，Steam ID 由 Lua .. 拼接）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_HASHCHECK_NAME',			'zh_Hans_CN',	'反作弊监控'),
	('LOC_MPT_HASHCHECK_DESC',			'zh_Hans_CN',	'检查联机对局中各玩家的游戏文件是否一致（模组完整性反作弊），结果在游戏内「快捷操作」面板显示；需在所有玩家处勾选，与替换游戏核心的其他钩子类模组互斥'),
	('LOC_MPT_HASHCHECK_PANEL_TITLE',		'zh_Hans_CN',	'反作弊监测'),
	('LOC_MPT_HASHCHECK_STATUS_OK',		'zh_Hans_CN',	'一致'),
	('LOC_MPT_HASHCHECK_STATUS_MISMATCH',	'zh_Hans_CN',	'不一致'),
	('LOC_MPT_HASHCHECK_STATUS_UNKNOWN',		'zh_Hans_CN',	'等待数据...'),
	('LOC_MPT_HASHCHECK_NO_OTHER_PLAYERS',	'zh_Hans_CN',	'没有其他人类玩家。'),
	('LOC_MPT_HASHCHECK_ENTRY_TT',			'zh_Hans_CN',	'点击复制玩家名称和 Steam ID'),
	('LOC_MPT_HASHCHECK_ENTRY_TT_NOID',		'zh_Hans_CN',	'无法获取 Steam ID');
