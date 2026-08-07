-- ============================================================================
-- 联机工具箱2.0 前端本地化文本（en_US 英文）
-- 规范：本 mod 所有文本更改一律采用 SQL 格式，统一存放于 FrontEnd/Text/，
--       每个语言一个文件，同语言集中，使用多行 VALUES。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 条目2：禁用领袖池参数
('LOC_LEADER_POOL_BAN_NAME', 'en_US', 'Banned Leaders'),
('LOC_LEADER_POOL_BAN_DESC', 'en_US', 'Selected leaders cannot be chosen in this game'),
('LOC_LEADER_POOL_BAN_TOOLTIP', 'en_US', '[COLOR_RED]Leader unavailable[ENDCOLOR]'),
-- 虚构示例：游戏内文本占位（无任何引用）
('LOC_MPT_FE_DUMMY_TEXT', 'en_US', 'Dummy text from Multiplayer Toolkits 2.0 FrontEnd'),
-- 条目3.2：快捷打开/关闭AI按钮
('LOC_MPT_FE_AI_SLOTS_NAME', 'en_US', 'AI Slots'),
('LOC_MPT_FE_AI_SLOTS_TOOLTIP', 'en_US', 'Left click: close all empty and AI slots[NEWLINE]Right click: open all slots (removes existing AI)');
