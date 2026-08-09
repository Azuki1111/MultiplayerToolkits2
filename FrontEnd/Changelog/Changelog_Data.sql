-- ============================================================================
-- 联机工具箱2.0 更新公告数据表（条目3.5）
-- 规范：公告数据存于本表，文本内容经 TextTag 引用 LocalizedText（多语言预留，
--       文本在同目录 Changelog_zh_Hans_CN.sql / Changelog_en_US.sql，
--       新增语言只需补充同 Tag 文本，本表零改动）。
-- 读取规则（UI 自动执行）：按 LogDate DESC, Version DESC, Seq ASC 排序展示；
--       相同 Version+LogDate 归为一组出组头，首组（最新）标记「（当前版本）」。
-- 新增公告：在下方 VALUES 按序追加行，并在同目录各语言文件补充同 Tag 文本。
-- ============================================================================
CREATE TABLE IF NOT EXISTS MPT_Changelog (
    Version TEXT NOT NULL,      -- 版本号，如 '2.0.0'
    LogDate TEXT NOT NULL,      -- 发布日期，ISO 格式 YYYY-MM-DD（字符串排序即时间排序）
    Seq     INTEGER NOT NULL,   -- 版本内条目序号（1 起，组内升序展示）
    TextTag TEXT NOT NULL,      -- 文本标签（LOC_...），经 LocalizedText 按当前语言解析
    PRIMARY KEY (Version, Seq)
);
INSERT OR REPLACE INTO MPT_Changelog (Version, LogDate, Seq, TextTag) VALUES
('2.0.0', '2026-08-10', 1, 'LOC_MPT_CHANGELOG_2_0_0_1'),
('2.0.0', '2026-08-10', 2, 'LOC_MPT_CHANGELOG_2_0_0_2'),
('2.0.0', '2026-08-10', 3, 'LOC_MPT_CHANGELOG_2_0_0_3'),
('2.0.0', '2026-08-10', 4, 'LOC_MPT_CHANGELOG_2_0_0_4'),
('2.0.0', '2026-08-10', 5, 'LOC_MPT_CHANGELOG_2_0_0_5'),
('2.0.0', '2026-08-10', 6, 'LOC_MPT_CHANGELOG_2_0_0_6');
