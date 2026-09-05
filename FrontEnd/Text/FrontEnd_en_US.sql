-- ============================================================================
-- 联机工具箱2.0 前端本地化文本（en_US 英文）
-- 规范：本 mod 所有文本更改一律采用 SQL 格式，通用文本统一存放于 FrontEnd/Text/，
--       每个语言一个文件，同语言集中，使用多行 VALUES；
--       功能专属文本随功能文件夹存放（如更新公告 FrontEnd/Changelog/）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 条目2：禁用领袖池参数
('LOC_LEADER_POOL_BAN_NAME', 'en_US', 'Banned Leaders'),
('LOC_LEADER_POOL_BAN_DESC', 'en_US', 'Selected leaders cannot be chosen in this game'),
('LOC_LEADER_POOL_BAN_TOOLTIP', 'en_US', '[COLOR_RED]Leader unavailable[ENDCOLOR]'),
-- 虚构示例：游戏内文本占位（无任何引用）
('LOC_MPT_FE_DUMMY_TEXT', 'en_US', 'Dummy text from Multiplayer Toolkits 2.0 FrontEnd'),
-- 条目3.2：快捷打开/关闭AI按钮
('LOC_MPT_FE_AI_SLOTS_NAME', 'en_US', 'Player Slots'),
('LOC_MPT_FE_AI_SLOTS_TOOLTIP', 'en_US', 'Left click: close all empty and AI slots[NEWLINE]Right click: open all slots (removes existing AI)'),
-- 条目3.3：快捷分队按钮（队伍列表头）
('LOC_MPT_FE_RANDOM_TEAM_TOOLTIP', 'en_US', 'Left click: random balanced teams[NEWLINE]Right click: sequential A-B-A-B teams[NEWLINE]Host only');

-- ============================================================================
-- 条目36：modinfo 品牌文本 SQL 化（前端 mod 浏览器：名称/描述/宣传语/作者/致谢）
-- 展示版本号单列 LOC_MPT_FE_VERSION（改版本只改这一行），LOC_MPT_FE_NAME 由其拼接；
-- LOC_MPT_MOD_ID 存本 mod GUID 供 Lua Locale.Lookup 查取；描述不含版本号，每功能一行 [NEWLINE]。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
('LOC_MPT_FE_VERSION', 'en_US', '2.0.2'),
('LOC_MPT_MOD_ID', 'en_US', '00000000-7369-4685-ab5f-bf77bc22b54e');

INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text)
SELECT 'LOC_MPT_FE_NAME', 'en_US', 'Multiplayer [COLOR:ResGoldLabelCS]Toolkits ' || COALESCE((SELECT Text FROM LocalizedText WHERE Tag = 'LOC_MPT_FE_VERSION' AND Language = 'en_US'), '') || '[ENDCOLOR]';

INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
('LOC_MPT_FE_DESCRIPTION', 'en_US', '[ICON_Bolt][COLOR:ResGoldLabelCS]Multiplayer Toolkits[ENDCOLOR][NEWLINE][NEWLINE][icon_Exclamation]Lobby features[NEWLINE][icon_You]Staging room enhancements: 20 slots, quick AI slot toggles, balanced random teams, host edits others'' teams and leaders[NEWLINE][icon_You]Mod version consistency check, unofficial mod list, workshop mod auto-update[NEWLINE][icon_You]Player mark profiles (shared between lobby and game), icon/texture atlas viewers[NEWLINE][icon_You]Update notes and latest news, MP game setup presets, longer player names[NEWLINE][NEWLINE][icon_Exclamation]In-game features[NEWLINE][icon_You]Quick actions panel: team surrender/restart votes, forced end turn, in-game settings[NEWLINE][icon_You]Smart turn timer, real tech/civic progress, policy card yields[NEWLINE][icon_You]Top panel and diplomacy ribbon extensions, teammate resource visibility[NEWLINE][icon_You]Trade and diplomacy restrictions, trade route/city-state/great person/pantheon UI enhancements[NEWLINE][icon_You]More hotkeys, notification clear, deal and great person recruit reminders, no map pins, instant city founding[NEWLINE][icon_You]Defeat spectator button, reveal map corners, great general era and builder charge display, save the settler, no idle research'),
('LOC_MPT_FE_TEASER', 'en_US', '[size_32][COLOR:ResGoldLabelCS]Multiplayer Toolkits[ENDCOLOR]'),
('LOC_MPT_FE_AUTHORS', 'en_US', '[COLOR:ResGoldLabelCS]Synora[ENDCOLOR]'),
('LOC_MPT_FE_THANKS', 'en_US', 'Nwflower，CHS, MPH, PPK, Zpod, 红魔族首席魔法师, 336tarot, Maple_Leaves, BBG');
