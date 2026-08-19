-- ============================================================================
-- 联机工具箱2.0 图标查看器文本（en_US 英文）
-- 规范：本文件为条目4.5 图标查看器功能专属文本（面板仅前端使用），
--       仅在 FrontEnd 上下文注册，不进游戏内上下文。
--       带数字的文本不用参数化 Tag，拆无参数前缀/后缀由 Lua 拼接（见 4.5 分区缓存块）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 融合面板入口按钮（条目4.5/4.6 融合：单按钮打开，面板顶部页签切换）
('LOC_MPT_VIEWER_NAME', 'en_US', 'Atlas List'),
('LOC_MPT_VIEWER_TOOLTIP', 'en_US', 'Open Atlas List (4975 icons / 5017 textures, switch tabs at the top of the panel; click a tile to copy its name to clipboard)'),
-- 页签标题
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
