-- 条目31：禁止空过研究文本（参数复选框名称/描述，FE+IG 双注册——IG Config 参数行同屏渲染，条目16 同形态先例）
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_NO_IDLE_RESEARCH_NAME',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]禁止空过研究[ENDCOLOR]'),
	('LOC_MPT_NO_IDLE_RESEARCH_DESC',	'zh_Hans_CN',	'回合开始时，为忘记选择科技/市政的玩家自动补选「可研究」中剩余研究量最大的一项');
