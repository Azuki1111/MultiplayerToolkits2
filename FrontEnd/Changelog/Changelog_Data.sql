-- ============================================================================
-- 联机工具箱2.0 更新公告数据表（条目3.5）
-- 规范：公告数据存于本表，文本内容经 TextTag 引用 LocalizedText（多语言预留，
--       文本在同目录 Changelog_zh_Hans_CN.sql / Changelog_en_US.sql，
--       新增语言只需补充同 Tag 文本，本表零改动）。
--       表先 DROP 再建（条目3.6 广告表同款机制）：FE Configuration 库跨次启动
--       持久，INSERT OR REPLACE 不会删除文件中已移除的行，先 DROP 使本文件
--       成为唯一事实，删行/清空下次启动立即生效无残留。
-- 读取规则（UI 自动执行）：按 LogDate DESC, Version DESC, rowid ASC 排序（最新公告排最上，最老排最下）；
--       相同 Version+LogDate 归为一组（同版本一个实例），组内条目行首统一 [icon_You] 图标，
--       首组（最新）版本号后标记「（当前版本）」。
-- 新增公告：在下方 VALUES 按序追加行，并在同目录各语言文件补充同 Tag 文本。
-- ============================================================================
DROP TABLE IF EXISTS MPT_Changelog;
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
('2.0.0', '2026-08-10', 'LOC_MPT_CHANGELOG_2_0_0_6');
