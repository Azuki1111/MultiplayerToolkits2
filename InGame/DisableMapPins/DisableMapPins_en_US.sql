-- ============================================================================
-- 条目16：禁用地图钉文本（en_US）
-- 1.67 RMP 仅有中文，英文翻译为本 mod 补全（tag 保持原名，与 1.67 同装时共用同一份文本）
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('CPL_NO_PINS_NAME',	'en_US',	'[COLOR:ResGoldLabelCS]Disable Map Pins[ENDCOLOR]'),
	('CPL_NO_PINS_DESC',	'en_US',	'Map pins will be disabled when this option is enabled.');
