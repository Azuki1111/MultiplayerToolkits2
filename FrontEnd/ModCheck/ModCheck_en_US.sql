-- ============================================================================
-- 联机工具箱2.0 多人游戏mod版本校验文本（条目4.1，English）
-- 规范：本文件只放模组校验功能文本，与通用文本（FrontEnd/Text/）分离；
--       按钮/面板 Tag 由 UI/StagingRoom/StagingRoom.xml 引用，弹窗/明细 Tag 由 StagingRoom.lua 引用。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
('LOC_MPT_MODCHECK_BUTTON_NAME', 'en_US', 'Mod Check'),
('LOC_MPT_MODCHECK_BUTTON_TT', 'en_US', 'Open the mod check panel to choose which mods to compare versions with all players in the room (host only)'),
('LOC_MPT_MODCHECK_RECHECK_NAME', 'en_US', 'Recheck'),
('LOC_MPT_MODCHECK_RECHECK_TT', 'en_US', 'Force all players to report the versions of the selected mods again (host only)'),
('LOC_MPT_MODCHECK_PANEL_TITLE', 'en_US', 'Mod Check'),
('LOC_MPT_MODCHECK_POPUP_TITLE', 'en_US', 'MOD VERSION MISMATCH'),
('LOC_MPT_MODCHECK_POPUP_TEXT', 'en_US', 'Version check failed for the selected mods:'),
('LOC_MPT_MODCHECK_POPUP_RECHECK', 'en_US', 'Back and Recheck'),
('LOC_MPT_MODCHECK_POPUP_SKIP', 'en_US', 'Skip Check'),
('LOC_MPT_MODCHECK_DETAIL_NOREPORT', 'en_US', '{1_Name}: no report (this mod may not be installed)'),
('LOC_MPT_MODCHECK_DETAIL_PENDING', 'en_US', '{1_Name}: waiting for report...'),
('LOC_MPT_MODCHECK_DETAIL_MISMATCH', 'en_US', '{1_Name}: {2_Mod} version mismatch (host {3_Host} / player {4_Player})');
