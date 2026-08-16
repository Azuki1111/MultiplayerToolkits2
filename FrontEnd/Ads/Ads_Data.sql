-- ============================================================================
-- 联机工具箱2.0 广告轮播数据表（条目3.6）
-- 规范：广告条目存于本表，UI 自动读取展示；ToolTips 文本经 ToolTipTag 引用
--       LocalizedText（多语言预留，文本在同目录 Ads_zh_Hans_CN.sql / Ads_en_US.sql，
--       新增语言只需补充同 Tag 文本，本表零改动）。
-- 读取规则（UI 自动执行）：按 rowid ASC 排序（先写的条目先展示）；
--       按本机当前日期过滤：StartDate 非空且当天早于 StartDate 不展示，
--       EndDate 非空且当天晚于 EndDate 不展示（起止当日均展示；
--       ISO 格式 YYYY-MM-DD 字符串比较即时间比较）。
-- 广告贴图标准：统一采用 400x300 的 DDS（A8R8G8B8 单 mip / ARGB8888），
--       4:3 比例，文件名 ASCII。
-- 添加广告全流程：
--   1. 准备 400x300 DDS 贴图（A8R8G8B8 单 mip，文件名 ASCII），复制到 FrontEnd/Ads/；
--   2. MultiplayerToolkits.modinfo 两处登记该贴图：
--        FE_Import_Ads action 内加 <File>FrontEnd/Ads/xxx.dds</File>（入 VFS），
--        末尾 <Files> 列表加同一行（保证打包）；
--   3. 在下方 VALUES 追加一行：TextureName 与文件名逐字一致，
--        StartDate / EndDate 留空 = 不限日期，ToolTipTag / Url 留空 = 无提示 / 点击无动作；
--   4. ToolTipTag 非空时，在同目录各语言文件补充同 Tag 文本。
-- ============================================================================
CREATE TABLE IF NOT EXISTS MPT_Ads (
    TextureName TEXT NOT NULL,            -- 贴图文件名（VFS 解析，标准 400x300）
    StartDate   TEXT NOT NULL DEFAULT '', -- 开始展示日期 YYYY-MM-DD，'' 表示不限
    EndDate     TEXT NOT NULL DEFAULT '', -- 结束展示日期 YYYY-MM-DD，'' 表示不限
    ToolTipTag  TEXT NOT NULL DEFAULT '', -- 悬停提示文本标签（LOC_...），'' 表示无提示
    Url         TEXT NOT NULL DEFAULT '', -- 点击打开的网页链接（Steam Overlay），'' 表示点击无动作
    PRIMARY KEY (TextureName, StartDate)
);
INSERT OR REPLACE INTO MPT_Ads (TextureName, StartDate, EndDate, ToolTipTag, Url) VALUES
-- 乔尔 FFA 大乱斗（两条轮换展示，Url 暂空 = 点击无动作，可按需补充）
('QiaoEr_FFA.dds', '2026-08-09', '', 'LOC_MPT_AD_QIAOER_FFA_TT', 'https://steamcommunity.com/profiles/76561198147378701/'),
('QiaoEr_FFA2.dds', '2026-08-09', '', 'LOC_MPT_AD_QIAOER_FFA_TT', 'https://steamcommunity.com/profiles/76561198147378701/myworkshopfiles/'),
('XiXueGuiTest1_.dds', '', '', '', '');
