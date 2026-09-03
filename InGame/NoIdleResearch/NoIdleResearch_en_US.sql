-- 条目31：禁止空过研究文本（参数复选框名称/描述，仅前端注册——设置界面消费，条目16 同形态先例）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_NO_IDLE_RESEARCH_NAME',	'en_US',	'[COLOR:ResGoldLabelCS]No Idle Research[ENDCOLOR]'),
	('LOC_MPT_NO_IDLE_RESEARCH_DESC',	'en_US',	'At the start of each turn, automatically picks the researchable tech/civic with the largest remaining cost for players who forgot to choose one (lobby-wide; enable in Advanced Options when creating the game, cannot be changed after game start)');
