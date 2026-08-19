-- ============================================================================
-- 联机工具箱2.0 贴图查看器文本（en_US 英文）
-- 规范：本文件为条目4.6 贴图查看器功能专属文本（面板仅前端使用），
--       仅在 FrontEnd 上下文注册，不进游戏内上下文。
--       带数字的文本不用参数化 Tag，拆无参数前缀/后缀由 Lua 拼接（见 4.6 分区缓存块）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 页签标题（融合面板入口按钮文本在 IconViewer 文本文件 LOC_MPT_VIEWER_*）
('LOC_MPT_TEXTUREVIEWER_TITLE', 'en_US', 'Texture Viewer'),
-- 搜索框（占位文本/提示）
('LOC_MPT_TEXTUREVIEWER_SEARCH_NAME', 'en_US', 'Search texture name'),
('LOC_MPT_TEXTUREVIEWER_SEARCH_TT', 'en_US', 'Filter the list by texture name substring (case-insensitive)'),
-- 按来源包分组开关（文本在左、圆钮在右）
('LOC_MPT_TEXTUREVIEWER_TOGGLE_SORT', 'en_US', 'Group by Source'),
('LOC_MPT_TEXTUREVIEWER_TOGGLE_SORT_TT', 'en_US', 'Group textures by their source blp package (alphabetical by name within each package)'),
-- 状态行（无参数前缀/后缀，Lua 拼接数字）
('LOC_MPT_TEXTUREVIEWER_COUNT_PREFIX', 'en_US', 'Total: '),
('LOC_MPT_TEXTUREVIEWER_COUNT_SUFFIX', 'en_US', ' textures'),
-- 悬停预览 Tooltip：来源包前缀（Lua 拼接 blp 包名）
('LOC_MPT_TEXTUREVIEWER_TT_SOURCE', 'en_US', 'Source: ');
