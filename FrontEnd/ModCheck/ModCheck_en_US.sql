-- ============================================================================
-- 联机工具箱2.0 多人游戏mod版本校验文本（条目4.1，English）
-- 规范：本文件只放模组校验功能文本，与通用文本（FrontEnd/Text/）分离；
--       按钮 Tag 由 FrontEnd/UI/StagingRoom/StagingRoom.xml 引用
--       （条目4.1调整：不阻止启动后弹窗/明细废止，对应 Tag 已删除）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
('LOC_MPT_MODCHECK_RECHECK_NAME', 'en_US', 'Recheck'),
('LOC_MPT_MODCHECK_RECHECK_TT', 'en_US', 'Force all players to report the versions of the registered mods again (host only)');
