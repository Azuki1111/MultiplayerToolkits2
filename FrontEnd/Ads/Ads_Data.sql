-- ============================================================================
-- 联机工具箱2.0 广告轮播数据表（条目3.6）
-- 规范：广告条目存于本表，UI 自动读取展示；ToolTips 文本经 ToolTipTag 引用
--       LocalizedText（多语言预留，文本在同目录 Ads_zh_Hans_CN.sql / Ads_en_US.sql，
--       新增语言只需补充同 Tag 文本，本表零改动）。
-- 读取规则（UI 自动执行）：按 rowid ASC 排序（先写的条目先展示）；
--       按本机当前日期过滤：StartDate 非空且当天早于 StartDate 不展示，
--       EndDate 非空且当天晚于 EndDate 不展示（起止当日均展示；
--       ISO 格式 YYYY-MM-DD 字符串比较即时间比较）。
-- 新增广告：在下方 VALUES 按序追加行（贴图文件需注册进 modinfo ImportFiles 入 VFS），
--       ToolTipTag 非空时在同目录各语言文件补充同 Tag 文本；ToolTipTag / Url 可为 ''。
-- ============================================================================
CREATE TABLE IF NOT EXISTS MPT_Ads (
    TextureName TEXT NOT NULL,            -- 贴图文件名（VFS 解析，建议 4:3 比例，如 400x300 / 433x328）
    StartDate   TEXT NOT NULL DEFAULT '', -- 开始展示日期 YYYY-MM-DD，'' 表示不限
    EndDate     TEXT NOT NULL DEFAULT '', -- 结束展示日期 YYYY-MM-DD，'' 表示不限
    ToolTipTag  TEXT NOT NULL DEFAULT '', -- 悬停提示文本标签（LOC_...），'' 表示无提示
    Url         TEXT NOT NULL DEFAULT '', -- 点击打开的网页链接（Steam Overlay），'' 表示点击无动作
    PRIMARY KEY (TextureName, StartDate)
);
INSERT OR REPLACE INTO MPT_Ads (TextureName, StartDate, EndDate, ToolTipTag, Url) VALUES
-- 乔尔 FFA 大乱斗（两条轮换展示，Url 暂空 = 点击无动作，可按需补充）
('QiaoEr_FFA.dds', '2026-08-09', '', 'LOC_MPT_AD_QIAOER_FFA_TT', ''),
('QiaoEr_FFA2_.dds', '2026-08-09', '', 'LOC_MPT_AD_QIAOER_FFA_TT', '');
