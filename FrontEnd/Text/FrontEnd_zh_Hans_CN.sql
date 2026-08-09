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
('LOC_MPT_FE_DUMMY_TEXT', 'zh_Hans_CN', '联机工具箱 2.0 前端虚构占位文本'),
-- 条目3.2：快捷打开/关闭AI按钮
('LOC_MPT_FE_AI_SLOTS_NAME', 'zh_Hans_CN', '玩家槽位'),
('LOC_MPT_FE_AI_SLOTS_TOOLTIP', 'zh_Hans_CN', '左键：关闭所有空位与玩家槽位[NEWLINE]右键：打开所有槽位（会清除已有AI）'),
-- 条目3.3：快捷分队按钮（队伍列表头）
('LOC_MPT_FE_RANDOM_TEAM_TOOLTIP', 'zh_Hans_CN', '左键：随机平衡分队[NEWLINE]右键：按顺序1212分队[NEWLINE]仅房主可用'),
-- 条目3.5：更新公告界面（按钮/标题/当前版本标记）
('LOC_MPT_FE_CHANGELOG_NAME', 'zh_Hans_CN', '更新日志'),
('LOC_MPT_FE_CHANGELOG_TOOLTIP', 'zh_Hans_CN', '查看联机工具箱更新公告'),
('LOC_MPT_FE_CHANGELOG_TITLE', 'zh_Hans_CN', '更新公告'),
('LOC_MPT_FE_CHANGELOG_CURRENT', 'zh_Hans_CN', '（当前版本）'),
-- 条目3.5：更新公告内容（2.0.0 / 2026-08-10，对应 MPT_Changelog 表种子数据）
('LOC_MPT_CHANGELOG_2_0_0_1', 'zh_Hans_CN', '联机房间玩家名长度上限由22提升至45'),
('LOC_MPT_CHANGELOG_2_0_0_2', 'zh_Hans_CN', '房间玩家槽位上限提升至20，并新增快捷打开/关闭全部AI槽位按钮'),
('LOC_MPT_CHANGELOG_2_0_0_3', 'zh_Hans_CN', '新增快捷分队功能：左键随机平衡分队，右键按顺序1212分队'),
('LOC_MPT_CHANGELOG_2_0_0_4', 'zh_Hans_CN', '房主现在可以修改其他玩家的队伍与所选领袖'),
('LOC_MPT_CHANGELOG_2_0_0_5', 'zh_Hans_CN', '单人模式可移除全部AI，支持仅1人开始游戏'),
('LOC_MPT_CHANGELOG_2_0_0_6', 'zh_Hans_CN', '新增更新公告界面（本面板），公告内容由数据库驱动并预留多语言');
