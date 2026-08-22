-- ============================================================================
-- 联机工具箱2.0 准备房间非官方模组清单文本（条目4.2，简体中文）
-- 规范：本文件只放模组清单功能文本，与通用文本（FrontEnd/Text/）分离；
--       按钮 / 面板 / 行状态 Tag 由 FrontEnd/UI/StagingRoom/StagingRoom.xml 与 StagingRoom.lua 引用。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
('LOC_MPT_MODLIST_OPEN_NAME', 'zh_Hans_CN', '模组清单'),
('LOC_MPT_MODLIST_OPEN_TT', 'zh_Hans_CN', '查看本房间启用的非官方模组及其订阅状态'),
('LOC_MPT_MODLIST_TITLE', 'zh_Hans_CN', '模组清单'),
('LOC_MPT_MODLIST_SUBSCRIBED', 'zh_Hans_CN', '已订阅'),
('LOC_MPT_MODLIST_UNSUBSCRIBED', 'zh_Hans_CN', '未订阅'),
('LOC_MPT_MODLIST_LOCAL', 'zh_Hans_CN', '本地'),
('LOC_MPT_MODLIST_EMPTY', 'zh_Hans_CN', '本房间没有启用非官方模组');
