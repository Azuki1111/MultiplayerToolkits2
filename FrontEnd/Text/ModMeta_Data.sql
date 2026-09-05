-- ============================================================================
-- 条目36调整：mod 元数据早载单文件（单语言 en_US 承载，不设多语言双语文件）
-- LOC_MPT_FE_VERSION = 展示版本号（改展示版本只改这一行，当前 2.0.2）
-- LOC_MPT_MOD_ID = 本 mod GUID（供 Lua Locale.Lookup 查取，不参与显示）
-- LoadOrder 10 先于同目录品牌文本区（100）执行，保证 LOC_MPT_FE_NAME 拼接时版本行已就位。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
('LOC_MPT_FE_VERSION', 'en_US', '2.0.2'),
('LOC_MPT_MOD_ID', 'en_US', '00000000-7369-4685-ab5f-bf77bc22b54e');
