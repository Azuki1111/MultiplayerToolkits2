-- ============================================================================
-- 联机工具箱2.0 多人游戏mod版本校验文本（条目4.1，简体中文）
-- 规范：本文件只放模组校验功能文本，与通用文本（FrontEnd/Text/）分离；
--       按钮 Tag 由 FrontEnd/UI/StagingRoom/StagingRoom.xml 引用，弹窗/明细 Tag 由 StagingRoom.lua 引用。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
('LOC_MPT_MODCHECK_RECHECK_NAME', 'zh_Hans_CN', '重新校验'),
('LOC_MPT_MODCHECK_RECHECK_TT', 'zh_Hans_CN', '强制所有玩家重新回报已登记模组的版本（仅房主可用）'),
('LOC_MPT_MODCHECK_POPUP_TITLE', 'zh_Hans_CN', '模组版本不一致'),
('LOC_MPT_MODCHECK_POPUP_TEXT', 'zh_Hans_CN', '所选模组的版本校验未通过：'),
('LOC_MPT_MODCHECK_POPUP_RECHECK', 'zh_Hans_CN', '返回重新验证'),
('LOC_MPT_MODCHECK_POPUP_SKIP', 'zh_Hans_CN', '放弃验证'),
('LOC_MPT_MODCHECK_DETAIL_NOREPORT', 'zh_Hans_CN', '：未回报（可能未安装本模组）'),
('LOC_MPT_MODCHECK_DETAIL_PENDING', 'zh_Hans_CN', '：正在等待回报……'),
('LOC_MPT_MODCHECK_DETAIL_MISMATCH_PREFIX', 'zh_Hans_CN', '：'),
('LOC_MPT_MODCHECK_DETAIL_MISMATCH_SUFFIX', 'zh_Hans_CN', ' 版本不一致');
