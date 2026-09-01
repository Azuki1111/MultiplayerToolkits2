-- 条目21优化：政策卡收益显示（EPC）显示行的自定义措辞（无参纯文本 tag，Lua .. 拼接组装行）
-- [MPT 条目21用户裁决] 显示类型收敛后共 9 个短语（对象名/类别/时代/资源/伟人类走原版
-- LOC tag 自动本地化）；回合描述（/每回合）已按用户要求整体去除；影响力点/联盟点/建造者
-- 次数/世界议会决议返还四类显示已删（静默化）；SEPARATOR 为卡面多行收益的单行串接分隔符
-- （接缝前段以 [ICON_..] 结尾时图标天然分隔而省略；卡面 Effect 不换行，tooltip 走
-- [NEWLINE] 分行版）
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
	('LOC_MPT_EPC_PRODUCTION',			'zh_Hans_CN',	'生产力'),
	('LOC_MPT_EPC_PROJECTS',			'zh_Hans_CN',	'项目'),
	('LOC_MPT_EPC_SPACE_PROJECTS',		'zh_Hans_CN',	'太空项目'),
	('LOC_MPT_EPC_ALL_UNITS',			'zh_Hans_CN',	'全单位'),
	('LOC_MPT_EPC_WONDER',				'zh_Hans_CN',	'奇观'),
	('LOC_MPT_EPC_CS_TRADE',			'zh_Hans_CN',	'对城邦商路'),
	('LOC_MPT_EPC_PER_BUILDING',		'zh_Hans_CN',	'每座'),
	('LOC_MPT_EPC_RESOURCE_FREE',		'zh_Hans_CN',	'每城免费资源'),
	('LOC_MPT_EPC_SEPARATOR',			'zh_Hans_CN',	'，');
