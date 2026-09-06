-- ============================================================================
-- 联机工具箱2.0 前端本地化文本（zh_Hans_CN 简体中文）
-- 规范：本 mod 所有文本更改一律采用 SQL 格式，通用文本统一存放于 FrontEnd/Text/，
--       每个语言一个文件，同语言集中，使用多行 VALUES；
--       功能专属文本随功能文件夹存放（如更新公告 FrontEnd/Changelog/）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 条目2：禁用领袖池参数
('LOC_LEADER_POOL_BAN_NAME', 'zh_Hans_CN', '禁用领袖'),
('LOC_LEADER_POOL_BAN_DESC', 'zh_Hans_CN', '被选中的领袖在本局中不可选用'),
('LOC_LEADER_POOL_BAN_TOOLTIP', 'zh_Hans_CN', '[COLOR_RED]领袖不可用[ENDCOLOR]'),
-- 虚构示例：游戏内文本占位（无任何引用）
('LOC_MPT_FE_DUMMY_TEXT', 'zh_Hans_CN', '联机工具箱 2.0 前端虚构占位文本'),
-- 条目3.2：快捷打开/关闭AI按钮
('LOC_MPT_FE_AI_SLOTS_NAME', 'zh_Hans_CN', '玩家槽位'),
('LOC_MPT_FE_AI_SLOTS_TOOLTIP', 'zh_Hans_CN', '左键：关闭所有空位与玩家槽位[NEWLINE]右键：打开所有槽位（会清除已有AI）'),
-- 条目3.3：快捷分队按钮（队伍列表头）
('LOC_MPT_FE_RANDOM_TEAM_TOOLTIP', 'zh_Hans_CN', '左键：随机平衡分队[NEWLINE]右键：按顺序1212分队[NEWLINE]仅房主可用'),
-- 条目36扩展：WorldTracker 头部名（游戏内消费，MPT_AutoUpdate.lua 与 LOC_MPT_FE_VERSION 拼接显示）
('LOC_MPT_WORLD_TRACKER_HEADER', 'zh_Hans_CN', '联机工具箱'),
-- 条目36扩展：顶栏真人玩家计数（初值为图标占位，进面板即由 Lua 刷新为真人数）
('LOC_MPT_FE_AMOUNT_NAME', 'zh_Hans_CN', '[icon_Global]'),
('LOC_MPT_FE_AMOUNT_TOOLTIP', 'zh_Hans_CN', '房间玩家数');
