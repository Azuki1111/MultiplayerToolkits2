-- ============================================================================
-- 联机工具箱2.0 图标查看器文本（zh_Hans_CN 简体中文）
-- 规范：本文件为条目4.5 图标查看器功能专属文本（面板仅前端使用），
--       仅在 FrontEnd 上下文注册，不进游戏内上下文。
--       带数字的文本不用参数化 Tag，拆无参数前缀/后缀由 Lua 拼接（见 4.5 分区缓存块）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 入口按钮/面板标题
('LOC_MPT_ICONVIEWER_NAME', 'zh_Hans_CN', '图标查看器'),
('LOC_MPT_ICONVIEWER_TOOLTIP', 'zh_Hans_CN', '打开图标查看器（4975 个收集的图标，点击图标自动复制文本到剪贴板）'),
('LOC_MPT_ICONVIEWER_TITLE', 'zh_Hans_CN', '图标查看器'),
-- 搜索框（占位文本/提示）
('LOC_MPT_ICONVIEWER_SEARCH_NAME', 'zh_Hans_CN', '搜索图标名'),
('LOC_MPT_ICONVIEWER_SEARCH_TT', 'zh_Hans_CN', '按图标名子串过滤列表（大小写不敏感）'),
-- 按尺寸排序开关（文本在左、圆钮在右）
('LOC_MPT_ICONVIEWER_TOGGLE_SORT', 'zh_Hans_CN', '按尺寸排序'),
('LOC_MPT_ICONVIEWER_TOGGLE_SORT_TT', 'zh_Hans_CN', '按图标宽度从小到大排布（首轮构建完成后可用）'),
-- 状态行（无参数前缀/后缀，Lua 拼接数字）
('LOC_MPT_ICONVIEWER_COUNT_PREFIX', 'zh_Hans_CN', '共 '),
('LOC_MPT_ICONVIEWER_COUNT_SUFFIX', 'zh_Hans_CN', ' 个图标');
