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
('LOC_MPT_CHANGELOG_2_0_0_6', 'en_US', 'Added this update notes panel, driven by a database table with multi-language support'),
-- 测试文本（2.0.1，用于压测自动换行与滚动条，正式发布前移除）
('LOC_MPT_CHANGELOG_2_0_1_1', 'en_US', 'Test entry: short text wrap check'),
('LOC_MPT_CHANGELOG_2_0_1_2', 'en_US', 'Test entry: second short text'),
('LOC_MPT_CHANGELOG_2_0_1_3', 'en_US', 'Test entry: long text — verifies that entry text wraps correctly when it exceeds the panel width, and that the row height grows with the text so the full entry stays visible'),
('LOC_MPT_CHANGELOG_2_0_1_4', 'en_US', 'Test entry: inline icons [ICON_Production] Production [ICON_GOLD] Gold [ICON_SCIENCE] Science [ICON_CULTURE] Culture'),
('LOC_MPT_CHANGELOG_2_0_1_5', 'en_US', 'Test entry: scroll test — when the total height of entries exceeds the visible area, the scrollbar should appear and scroll through all content'),
('LOC_MPT_CHANGELOG_2_0_1_6', 'en_US', 'Test entry: sixth'),
('LOC_MPT_CHANGELOG_2_0_1_7', 'en_US', 'Test entry: seventh'),
('LOC_MPT_CHANGELOG_2_0_1_8', 'en_US', 'Test entry: extra-long stress text — Multiplayer Toolkits 2.0 FrontEnd combines the frontend features of Team PVP Tools and MPH, including staging room enhancements, quick AI slot toggles, balanced random teams, host permission upgrades, mod version checks and update notes; this entry exists to verify wrapping under extreme text length, correct row-height growth, and correct total scroll height with many long entries stacked'),
('LOC_MPT_CHANGELOG_2_0_1_9', 'en_US', 'Test entry: ninth'),
('LOC_MPT_CHANGELOG_2_0_1_10', 'en_US', 'Test entry: tenth (the last one — it should be fully visible after scrolling to the bottom)'),
-- 测试文本（2.0.2，验证多版本堆叠与排序，正式发布前移除）
('LOC_MPT_CHANGELOG_2_0_2_1', 'en_US', 'Test entry: first of the new version'),
('LOC_MPT_CHANGELOG_2_0_2_2', 'en_US', 'Test entry: short text'),
('LOC_MPT_CHANGELOG_2_0_2_3', 'en_US', 'Test entry: long text — verifies the entry layout still reads cleanly with wrapping after removing the divider line, and the row height grows correctly'),
('LOC_MPT_CHANGELOG_2_0_2_4', 'en_US', 'Test entry: fourth'),
('LOC_MPT_CHANGELOG_2_0_2_5', 'en_US', 'Test entry: fifth (last of the new version)');
