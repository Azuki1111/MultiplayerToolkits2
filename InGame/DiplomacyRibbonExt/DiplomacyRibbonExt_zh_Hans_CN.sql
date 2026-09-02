-- ============================================================================
-- 条目24：外交丝带扩展（DPR）中文文本——移植 1.67 DPR 的 Config_DPR_Text.xml 与
--   DiplomacyRibbon_Text.xml，tag 原样沿用 LOC_DPR_* / LOC_SETTINGS_DIPLOMACYRIBBON_*
--   （与 1.67 同装时同 tag 同内容幂等覆盖，无冲突）。
-- FE+IG 双注册：参数/热键文本前端可见（大厅高级选项 + 按键绑定界面），
--   丝带 tooltip 文本游戏内可见。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	-- 高级选项：外交能见度三档
	('LOC_SETTINGS_DIPLOMACYRIBBON_NAME',	'zh_Hans_CN',	'外交能见度'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_DESC',	'zh_Hans_CN',	'设置外交信息能见度'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_NORM_NAME',	'zh_Hans_CN',	'标准(推荐)'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_NORM_DESC',	'zh_Hans_CN',	'标准的规则[NEWLINE][NEWLINE][icon_You]不显示非团队玩家的军事实力、总人口、总生产力、总粮食'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_VISIBILITY_TEAM_NAME',	'zh_Hans_CN',	'外交能见度模式([COLOR:ResGoldLabelCS]团队[ENDCOLOR])'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_VISIBILITY_TEAM_DESC',	'zh_Hans_CN',	'外交能见度模式[NEWLINE][NEWLINE][icon_You]团队成员之间互相公开信息，非团队玩家需要更高能见度才能查看'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_PUBLIC_NAME',	'zh_Hans_CN',	'公开(完全透明)'),
	('LOC_SETTINGS_DIPLOMACYRIBBON_PUBLIC_DESC',	'zh_Hans_CN',	'所有玩家的信息都是公开的[NEWLINE][NEWLINE][icon_You]谨慎开启，适合PVE种地'),
	-- 快捷键（; 与 '）
	('LOC_DPR_TECHCIVIS_NAME',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]显示/隐藏研究进度[ENDCOLOR]'),
	('LOC_DPR_TECHCIVIS_DESC',	'zh_Hans_CN',	'显示其他玩家正在研究的科技与市政的进度'),
	('LOC_DPR_TOTALYIELD_NAME',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]切换统计显示[ENDCOLOR]'),
	('LOC_DPR_TOTALYIELD_DESC',	'zh_Hans_CN',	'切换常规数据和其他统计数据'),
	-- 丝带统计行 tooltip
	('LOC_DPR_TOTAL_POPULATION',	'zh_Hans_CN',	'人口总量'),
	('LOC_DPR_FOOD_SURPLUS_YIELD',	'zh_Hans_CN',	'每回合余粮累积'),
	('LOC_DPR_PRODUCTION_YIELD',	'zh_Hans_CN',	'每回合生产力'),
	('LOC_DPR_GOLD_PERTURN',	'zh_Hans_CN',	'每回合金币产出'),
	('LOC_DPR_FAITH_PERTURN',	'zh_Hans_CN',	'每回合信仰产出'),
	('LOC_DPR_FAVOR_PERTURN',	'zh_Hans_CN',	'每回合外交支持');
