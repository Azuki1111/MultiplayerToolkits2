-- ============================================================================
-- 联机工具箱2.0 图标查看器文本（en_US 英文）
-- 规范：本文件为条目4.5 图标查看器功能专属文本（面板仅前端使用），
--       仅在 FrontEnd 上下文注册，不进游戏内上下文。
--       带数字的文本不用参数化 Tag，拆无参数前缀/后缀由 Lua 拼接（见 4.5 分区缓存块）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 入口按钮/面板标题
('LOC_MPT_ICONVIEWER_NAME', 'en_US', 'Icon Viewer'),
('LOC_MPT_ICONVIEWER_TOOLTIP', 'en_US', 'Open Icon Viewer (4975 collected icons; click an icon to copy its text to clipboard)'),
('LOC_MPT_ICONVIEWER_TITLE', 'en_US', 'Icon Viewer'),
-- 搜索框（占位文本/提示）
('LOC_MPT_ICONVIEWER_SEARCH_NAME', 'en_US', 'Search icon name'),
('LOC_MPT_ICONVIEWER_SEARCH_TT', 'en_US', 'Filter the list by icon name substring (case-insensitive)'),
-- 按尺寸排序开关（文本在左、圆钮在右）
('LOC_MPT_ICONVIEWER_TOGGLE_SORT', 'en_US', 'Sort by size'),
('LOC_MPT_ICONVIEWER_TOGGLE_SORT_TT', 'en_US', 'Sort icons by width, smallest first (available after the first build completes)'),
-- 状态行（无参数前缀/后缀，Lua 拼接数字）
('LOC_MPT_ICONVIEWER_COUNT_PREFIX', 'en_US', ''),
('LOC_MPT_ICONVIEWER_COUNT_SUFFIX', 'en_US', ' icons in total');
