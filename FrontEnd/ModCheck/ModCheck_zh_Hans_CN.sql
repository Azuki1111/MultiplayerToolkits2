-- ============================================================================
-- 联机工具箱2.0 多人游戏mod版本校验文本（条目4.1，简体中文）
-- 规范：本文件只放模组校验功能文本，与通用文本（FrontEnd/Text/）分离；
--       按钮 Tag 由 FrontEnd/UI/StagingRoom/StagingRoom.xml 引用
--       （条目4.1调整：不阻止启动后弹窗/明细废止，对应 Tag 已删除）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
('LOC_MPT_MODCHECK_RECHECK_NAME', 'zh_Hans_CN', '重新校验'),
('LOC_MPT_MODCHECK_RECHECK_TT', 'zh_Hans_CN', '强制所有玩家重新回报已登记模组的版本（仅房主可用）');
