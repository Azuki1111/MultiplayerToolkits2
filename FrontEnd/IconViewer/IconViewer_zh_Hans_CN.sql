-- ============================================================================
-- 联机工具箱2.0 图标查看器文本（zh_Hans_CN 简体中文）
-- 规范：本文件为条目4.5 图标查看器功能专属文本（面板仅前端使用），
--       仅在 FrontEnd 上下文注册，不进游戏内上下文。
--       带数字的文本不用参数化 Tag，拆无参数前缀/后缀由 Lua 拼接（见 4.5 分区缓存块）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 融合面板入口按钮（条目4.5/4.6 融合：单按钮打开，面板顶部页签切换）
('LOC_MPT_VIEWER_NAME', 'zh_Hans_CN', '画册列表'),
('LOC_MPT_VIEWER_TOOLTIP', 'zh_Hans_CN', '打开画册列表（4975 个图标 / 5017 个贴图，面板顶部页签切换；点击格子复制名称到剪贴板）'),
-- 页签标题
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
