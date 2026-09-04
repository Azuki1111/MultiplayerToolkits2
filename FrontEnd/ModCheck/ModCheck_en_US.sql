-- ============================================================================
-- 联机工具箱2.0 多人游戏mod版本校验文本（条目4.1，English）
-- 规范：本文件只放模组校验功能文本，与通用文本（FrontEnd/Text/）分离；
--       按钮 Tag 由 FrontEnd/UI/StagingRoom/StagingRoom.xml 引用，弹窗/明细 Tag 由 StagingRoom.lua 引用。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
('LOC_MPT_MODCHECK_RECHECK_NAME', 'en_US', 'Recheck'),
('LOC_MPT_MODCHECK_RECHECK_TT', 'en_US', 'Force all players to report the versions of the registered mods again (host only)'),
('LOC_MPT_MODCHECK_POPUP_TITLE', 'en_US', 'Mod Version Mismatch'),
('LOC_MPT_MODCHECK_POPUP_TEXT', 'en_US', 'Version check failed for the selected mods:'),
('LOC_MPT_MODCHECK_POPUP_RECHECK', 'en_US', 'Back and Recheck'),
('LOC_MPT_MODCHECK_POPUP_SKIP', 'en_US', 'Skip Check'),
('LOC_MPT_MODCHECK_DETAIL_NOREPORT', 'en_US', ': no report (this mod may not be installed)'),
('LOC_MPT_MODCHECK_DETAIL_PENDING', 'en_US', ': waiting for report...'),
('LOC_MPT_MODCHECK_DETAIL_MISMATCH_PREFIX', 'en_US', ': '),
('LOC_MPT_MODCHECK_DETAIL_MISMATCH_SUFFIX', 'en_US', ' version mismatch');
