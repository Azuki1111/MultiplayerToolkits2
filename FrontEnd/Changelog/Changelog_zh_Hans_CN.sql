-- ============================================================================
-- 联机工具箱2.0 更新公告文本（zh_Hans_CN 简体中文）
-- 规范：本文件为更新公告功能专属文本（数据表见同目录 Changelog_Data.sql），
--       仅在 FrontEnd 上下文注册（公告面板仅前端使用），不进游戏内上下文。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 按钮/标题/提示/当前版本标记
('LOC_MPT_FE_CHANGELOG_NAME', 'zh_Hans_CN', '更新日志'),
('LOC_MPT_FE_CHANGELOG_TOOLTIP', 'zh_Hans_CN', '查看联机工具箱更新公告'),
('LOC_MPT_FE_CHANGELOG_TITLE', 'zh_Hans_CN', '更新公告'),
('LOC_MPT_FE_CHANGELOG_CURRENT', 'zh_Hans_CN', '（当前版本）'),
-- 公告内容（2.0.1 / 2026-09-05 与 2.0.0 / 2026-08-10，对应 Changelog_Data.sql 种子数据）
('LOC_MPT_CHANGELOG_2_0_1_1', 'zh_Hans_CN', '模组版本不一致不再影响玩家准备与开局，仅显示红底提示（房主可用「重新校验」按钮强制全员重新回报）'),
('LOC_MPT_CHANGELOG_2_0_0_1', 'zh_Hans_CN', '联机房间玩家名长度上限由22提升至45'),
('LOC_MPT_CHANGELOG_2_0_0_2', 'zh_Hans_CN', '房间玩家槽位上限提升至20，并新增快捷打开/关闭全部AI槽位按钮'),
('LOC_MPT_CHANGELOG_2_0_0_3', 'zh_Hans_CN', '新增快捷分队功能：左键随机平衡分队，右键按顺序1212分队'),
('LOC_MPT_CHANGELOG_2_0_0_4', 'zh_Hans_CN', '房主现在可以修改其他玩家的队伍与所选领袖'),
('LOC_MPT_CHANGELOG_2_0_0_5', 'zh_Hans_CN', '单人模式可移除全部AI，支持仅1人开始游戏'),
('LOC_MPT_CHANGELOG_2_0_0_6', 'zh_Hans_CN', '新增更新公告界面（本面板），公告内容由数据库驱动并预留多语言');
