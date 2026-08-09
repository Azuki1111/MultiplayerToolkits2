-- ============================================================================
-- 联机工具箱2.0 更新公告数据表（条目3.5）
-- 规范：公告数据存于本表，文本内容经 TextTag 引用 LocalizedText（多语言预留，
--       文本在同目录 Changelog_zh_Hans_CN.sql / Changelog_en_US.sql，
--       新增语言只需补充同 Tag 文本，本表零改动）。
-- 读取规则（UI 自动执行）：按 LogDate DESC, Version DESC, rowid ASC 排序（最新公告排最上，最老排最下）；
--       相同 Version+LogDate 归为一组（同版本一个实例），组内条目行首统一 [icon_You] 图标，
--       首组（最新）版本号后标记「（当前版本）」。
-- 新增公告：在下方 VALUES 按序追加行，并在同目录各语言文件补充同 Tag 文本。
-- ============================================================================
CREATE TABLE IF NOT EXISTS MPT_Changelog (
    Version TEXT NOT NULL,      -- 版本号，如 '2.0.0'
    LogDate TEXT NOT NULL,      -- 发布日期，ISO 格式 YYYY-MM-DD（字符串排序即时间排序）
    TextTag TEXT NOT NULL,      -- 文本标签（LOC_...），经 LocalizedText 按当前语言解析
    PRIMARY KEY (Version, TextTag)
);
INSERT OR REPLACE INTO MPT_Changelog (Version, LogDate, TextTag) VALUES
('2.0.0', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_0_1'),
('2.0.0', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_0_2'),
('2.0.0', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_0_3'),
('2.0.0', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_0_4'),
('2.0.0', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_0_5'),
('2.0.0', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_0_6'),
-- 测试版本：10 条测试文本（含长文本），用于压测自动换行与滚动条
('2.0.1', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_1_1'),
('2.0.1', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_1_2'),
('2.0.1', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_1_3'),
('2.0.1', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_1_4'),
('2.0.1', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_1_5'),
('2.0.1', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_1_6'),
('2.0.1', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_1_7'),
('2.0.1', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_1_8'),
('2.0.1', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_1_9'),
('2.0.1', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_1_10'),
-- 测试版本2：5 条测试文本（验证多版本堆叠与排序）
('2.0.2', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_2_1'),
('2.0.2', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_2_2'),
('2.0.2', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_2_3'),
('2.0.2', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_2_4'),
('2.0.2', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_2_5');
