-- ============================================================================
-- 联机工具箱2.0 更新公告文本（en_US 英文）
-- 规范：本文件为更新公告功能专属文本（数据表见同目录 Changelog_Data.sql），
--       仅在 FrontEnd 上下文注册（公告面板仅前端使用），不进游戏内上下文。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 按钮/标题/提示/当前版本标记
('LOC_MPT_FE_CHANGELOG_NAME', 'en_US', 'Changelog'),
('LOC_MPT_FE_CHANGELOG_TOOLTIP', 'en_US', 'View Multiplayer Toolkits update notes'),
('LOC_MPT_FE_CHANGELOG_TITLE', 'en_US', 'Update Notes'),
('LOC_MPT_FE_CHANGELOG_CURRENT', 'en_US', '(Current)'),
-- 公告内容（2.0.0 / 2026-08-10，对应 Changelog_Data.sql 种子数据）
('LOC_MPT_CHANGELOG_2_0_0_1', 'en_US', 'LAN player name length limit raised from 22 to 45'),
('LOC_MPT_CHANGELOG_2_0_0_2', 'en_US', 'Room player slots raised to 20, with a new button to open/close all AI slots'),
('LOC_MPT_CHANGELOG_2_0_0_3', 'en_US', 'Quick team assignment: left click for random balanced teams, right click for sequential A-B-A-B teams'),
('LOC_MPT_CHANGELOG_2_0_0_4', 'en_US', 'The host can now edit the team and leader of other players'),
('LOC_MPT_CHANGELOG_2_0_0_5', 'en_US', 'Single player games can remove all AI and start with only 1 player'),
('LOC_MPT_CHANGELOG_2_0_0_6', 'en_US', 'Added this update notes panel, driven by a database table with multi-language support');
