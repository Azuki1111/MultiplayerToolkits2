-- 条目21优化：政策卡收益显示（EPC）显示行的自定义措辞（无参纯文本 tag，Lua .. 拼接组装行）
-- [MPT 条目21用户裁决] 显示类型收敛后仅余 12 个短语（对象名/类别/时代/资源/伟人类走原版
-- LOC tag 自动本地化）；回合描述（/每回合）已按用户要求整体去除
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
	('LOC_MPT_EPC_PRODUCTION',			'zh_Hans_CN',	'生产力'),
	('LOC_MPT_EPC_PROJECTS',			'zh_Hans_CN',	'项目'),
	('LOC_MPT_EPC_SPACE_PROJECTS',		'zh_Hans_CN',	'太空项目'),
	('LOC_MPT_EPC_ALL_UNITS',			'zh_Hans_CN',	'全单位'),
	('LOC_MPT_EPC_WONDER',				'zh_Hans_CN',	'奇观'),
	('LOC_MPT_EPC_CS_TRADE',			'zh_Hans_CN',	'对城邦商路'),
	('LOC_MPT_EPC_PER_BUILDING',		'zh_Hans_CN',	'每座'),
	('LOC_MPT_EPC_RESOLUTION',			'zh_Hans_CN',	'世界议会决议'),
	('LOC_MPT_EPC_RESOURCE_FREE',		'zh_Hans_CN',	'每城免费资源'),
	('LOC_MPT_EPC_INFLUENCE',			'zh_Hans_CN',	'影响力点'),
	('LOC_MPT_EPC_ALLIANCE',			'zh_Hans_CN',	'联盟点'),
	('LOC_MPT_EPC_BUILD_CHARGES',		'zh_Hans_CN',	'建造者次数');
