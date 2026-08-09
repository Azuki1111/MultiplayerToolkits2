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
('LOC_MPT_FE_AI_SLOTS_TOOLTIP', 'en_US', 'Left click: close all empty and AI slots[NEWLINE]Right click: open all slots (removes existing AI)'),
-- 条目3.3：快捷分队按钮（队伍列表头）
('LOC_MPT_FE_RANDOM_TEAM_TOOLTIP', 'en_US', 'Left click: random balanced teams[NEWLINE]Right click: sequential A-B-A-B teams[NEWLINE]Host only'),
-- 条目3.5：更新公告界面（按钮/标题/当前版本标记）
('LOC_MPT_FE_CHANGELOG_NAME', 'en_US', 'Changelog'),
('LOC_MPT_FE_CHANGELOG_TOOLTIP', 'en_US', 'View Multiplayer Toolkits update notes'),
('LOC_MPT_FE_CHANGELOG_TITLE', 'en_US', 'Update Notes'),
('LOC_MPT_FE_CHANGELOG_CURRENT', 'en_US', '(Current)'),
-- 条目3.5：更新公告内容（2.0.0 / 2026-08-10，对应 MPT_Changelog 表种子数据）
('LOC_MPT_CHANGELOG_2_0_0_1', 'en_US', 'LAN player name length limit raised from 22 to 45'),
('LOC_MPT_CHANGELOG_2_0_0_2', 'en_US', 'Room player slots raised to 20, with a new button to open/close all AI slots'),
('LOC_MPT_CHANGELOG_2_0_0_3', 'en_US', 'Quick team assignment: left click for random balanced teams, right click for sequential A-B-A-B teams'),
('LOC_MPT_CHANGELOG_2_0_0_4', 'en_US', 'The host can now edit the team and leader of other players'),
('LOC_MPT_CHANGELOG_2_0_0_5', 'en_US', 'Single player games can remove all AI and start with only 1 player'),
('LOC_MPT_CHANGELOG_2_0_0_6', 'en_US', 'Added this update notes panel, driven by a database table with multi-language support');
