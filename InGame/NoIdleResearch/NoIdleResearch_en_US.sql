-- 条目31：禁止空过研究文本（参数复选框名称/描述，FE+IG 双注册——IG Config 参数行同屏渲染，条目16 同形态先例）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_NO_IDLE_RESEARCH_NAME',	'en_US',	'[COLOR:ResGoldLabelCS]No Idle Research[ENDCOLOR]'),
	('LOC_MPT_NO_IDLE_RESEARCH_DESC',	'en_US',	'At the start of each turn, automatically picks the researchable tech/civic with the most remaining research for players who forgot to choose one');
