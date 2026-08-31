-- ============================================================================
-- 条目16：禁用地图钉文本（zh_Hans_CN）
-- 移植 1.67 RMP/Config_Text.xml（tag 保持原名，与 1.67 同装时共用同一份文本，INSERT OR REPLACE 幂等）
-- 仅前端注册：设置界面复选框的名称与描述，游戏内无本条目文本
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('CPL_NO_PINS_NAME',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]禁用地图钉[ENDCOLOR]'),
	('CPL_NO_PINS_DESC',	'zh_Hans_CN',	'启用此选项后地图钉将被禁用');
