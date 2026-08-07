-- ============================================================================
-- 联机工具箱2.0 前端本地化文本（zh_Hans_CN 简体中文）
-- 规范：本 mod 所有文本更改一律采用 SQL 格式，统一存放于 FrontEnd/Text/，
--       每个语言一个文件，同语言集中，使用多行 VALUES。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 条目2：禁用领袖池参数
('LOC_LEADER_POOL_BAN_NAME', 'zh_Hans_CN', '禁用领袖'),
('LOC_LEADER_POOL_BAN_DESC', 'zh_Hans_CN', '被选中的领袖在本局中不可选用'),
('LOC_LEADER_POOL_BAN_TOOLTIP', 'zh_Hans_CN', '[COLOR_RED]领袖不可用[ENDCOLOR]'),
-- 虚构示例：游戏内文本占位（无任何引用）
('LOC_MPT_FE_DUMMY_TEXT', 'zh_Hans_CN', '联机工具箱 2.0 前端虚构占位文本');
