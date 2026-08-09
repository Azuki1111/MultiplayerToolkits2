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
-- 公告内容（2.0.0 / 2026-08-10，对应 Changelog_Data.sql 种子数据）
('LOC_MPT_CHANGELOG_2_0_0_1', 'zh_Hans_CN', '联机房间玩家名长度上限由22提升至45'),
('LOC_MPT_CHANGELOG_2_0_0_2', 'zh_Hans_CN', '房间玩家槽位上限提升至20，并新增快捷打开/关闭全部AI槽位按钮'),
('LOC_MPT_CHANGELOG_2_0_0_3', 'zh_Hans_CN', '新增快捷分队功能：左键随机平衡分队，右键按顺序1212分队'),
('LOC_MPT_CHANGELOG_2_0_0_4', 'zh_Hans_CN', '房主现在可以修改其他玩家的队伍与所选领袖'),
('LOC_MPT_CHANGELOG_2_0_0_5', 'zh_Hans_CN', '单人模式可移除全部AI，支持仅1人开始游戏'),
('LOC_MPT_CHANGELOG_2_0_0_6', 'zh_Hans_CN', '新增更新公告界面（本面板），公告内容由数据库驱动并预留多语言'),
-- 测试文本（2.0.1，用于压测自动换行与滚动条，正式发布前移除）
('LOC_MPT_CHANGELOG_2_0_1_1', 'zh_Hans_CN', '测试条目：短文本换行检查'),
('LOC_MPT_CHANGELOG_2_0_1_2', 'zh_Hans_CN', '测试条目：第二条短文本'),
('LOC_MPT_CHANGELOG_2_0_1_3', 'zh_Hans_CN', '测试条目：较长文本——用于验证条目文本在面板宽度不足时是否能够正确自动换行，并且行高随文本高度自适应增加，确保整条公告完整显示不被截断'),
('LOC_MPT_CHANGELOG_2_0_1_4', 'zh_Hans_CN', '测试条目：图标混排检查 [ICON_Production] 生产力 [ICON_GOLD] 金币 [ICON_SCIENCE] 科技值 [ICON_CULTURE] 文化值'),
('LOC_MPT_CHANGELOG_2_0_1_5', 'zh_Hans_CN', '测试条目：滚动测试——当公告条目总高度超过面板可视区域时，右侧滚动条应当出现并可以正常滚动查看全部内容'),
('LOC_MPT_CHANGELOG_2_0_1_6', 'zh_Hans_CN', '测试条目：第六条'),
('LOC_MPT_CHANGELOG_2_0_1_7', 'zh_Hans_CN', '测试条目：第七条'),
('LOC_MPT_CHANGELOG_2_0_1_8', 'zh_Hans_CN', '测试条目：超长文本压力测试——联机工具箱2.0前端整合了联机工具箱与MPH的前端功能，包括准备房间增强、快捷AI槽位开关、随机平衡分队、房主权限提升、模组版本一致性校验与更新公告等功能；本条目专门用于检验面板在极端长文本下的自动换行表现、行高自适应是否正确计算，以及堆叠多条长文本后滚动区域的总高度是否随之正确增长'),
('LOC_MPT_CHANGELOG_2_0_1_9', 'zh_Hans_CN', '测试条目：第九条'),
('LOC_MPT_CHANGELOG_2_0_1_10', 'zh_Hans_CN', '测试条目：第十条（最后一条，滚动到底部时应能看到本行完整内容）');
