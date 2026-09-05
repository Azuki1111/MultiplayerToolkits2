-- ============================================================================
-- 条目36调整：mod 元数据（单语言 en_US 承载，不设多语言双语文件；FE/IG_ModMeta_Text 双上下文加载 LoadOrder 10）
-- LOC_MPT_FE_VERSION = 展示版本号（当前 2.0.2，供 Lua/后续功能查取；注意 modinfo 浏览器名称为直写版本号，
--                      改展示版本须与本文件同步两处修改，条目36回退裁决废止名称 SQL 拼接）
-- LOC_MPT_MOD_ID = 本 mod GUID（供 Lua Locale.Lookup 查取，不参与显示）
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
('LOC_MPT_FE_VERSION', 'en_US', '2.0.2'),
('LOC_MPT_MOD_ID', 'en_US', '00000000-7369-4685-ab5f-bf77bc22b54e');
