-- ============================================================================
-- 联机工具箱2.0 贴图查看器文本（zh_Hans_CN 简体中文）
-- 规范：本文件为条目4.6 贴图查看器功能专属文本（面板仅前端使用），
--       仅在 FrontEnd 上下文注册，不进游戏内上下文。
--       带数字的文本不用参数化 Tag，拆无参数前缀/后缀由 Lua 拼接（见 4.6 分区缓存块）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 页签标题（融合面板入口按钮文本在 IconViewer 文本文件 LOC_MPT_VIEWER_*）
('LOC_MPT_TEXTUREVIEWER_TITLE', 'zh_Hans_CN', '贴图查看器'),
-- 搜索框（占位文本/提示）
('LOC_MPT_TEXTUREVIEWER_SEARCH_NAME', 'zh_Hans_CN', '搜索贴图名'),
('LOC_MPT_TEXTUREVIEWER_SEARCH_TT', 'zh_Hans_CN', '按贴图名子串过滤列表（大小写不敏感）'),
-- 按来源包分组开关（文本在左、圆钮在右）
('LOC_MPT_TEXTUREVIEWER_TOGGLE_SORT', 'zh_Hans_CN', '按来源包分组'),
('LOC_MPT_TEXTUREVIEWER_TOGGLE_SORT_TT', 'zh_Hans_CN', '按照贴图所属的 blp 包分组排布（同包内按贴图名字典序）'),
-- 状态行（无参数前缀/后缀，Lua 拼接数字）
('LOC_MPT_TEXTUREVIEWER_COUNT_PREFIX', 'zh_Hans_CN', '共 '),
('LOC_MPT_TEXTUREVIEWER_COUNT_SUFFIX', 'zh_Hans_CN', ' 个贴图'),
-- 悬停预览 Tooltip：来源包前缀（Lua 拼接 blp 包名）
('LOC_MPT_TEXTUREVIEWER_TT_SOURCE', 'zh_Hans_CN', '来源包：');
