-- ============================================================================
-- 联机工具箱2.0 前端本地化文本（zh_Hans_CN 简体中文）
-- 规范：本 mod 所有文本更改一律采用 SQL 格式，通用文本统一存放于 FrontEnd/Text/，
--       每个语言一个文件，同语言集中，使用多行 VALUES；
--       功能专属文本随功能文件夹存放（如更新公告 FrontEnd/Changelog/）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 条目2：禁用领袖池参数
('LOC_LEADER_POOL_BAN_NAME', 'zh_Hans_CN', '禁用领袖'),
('LOC_LEADER_POOL_BAN_DESC', 'zh_Hans_CN', '被选中的领袖在本局中不可选用'),
('LOC_LEADER_POOL_BAN_TOOLTIP', 'zh_Hans_CN', '[COLOR_RED]领袖不可用[ENDCOLOR]'),
-- 虚构示例：游戏内文本占位（无任何引用）
('LOC_MPT_FE_DUMMY_TEXT', 'zh_Hans_CN', '联机工具箱 2.0 前端虚构占位文本'),
-- 条目3.2：快捷打开/关闭AI按钮
('LOC_MPT_FE_AI_SLOTS_NAME', 'zh_Hans_CN', '玩家槽位'),
('LOC_MPT_FE_AI_SLOTS_TOOLTIP', 'zh_Hans_CN', '左键：关闭所有空位与玩家槽位[NEWLINE]右键：打开所有槽位（会清除已有AI）'),
-- 条目3.3：快捷分队按钮（队伍列表头）
('LOC_MPT_FE_RANDOM_TEAM_TOOLTIP', 'zh_Hans_CN', '左键：随机平衡分队[NEWLINE]右键：按顺序1212分队[NEWLINE]仅房主可用');

-- ============================================================================
-- 条目36：modinfo 品牌文本 SQL 化（前端 mod 浏览器：名称/描述/宣传语/作者/致谢）
-- LOC_MPT_FE_NAME 由展示版本号 LOC_MPT_FE_VERSION 拼接（版本行在 ModMeta_Data.sql 早载，
-- 条目36调整：该文件单语言不设多语言，故此处不再按 Language 过滤）；描述不含版本号，每功能一行 [NEWLINE]。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text)
SELECT 'LOC_MPT_FE_NAME', 'zh_Hans_CN', 'Team PVP Toolkits [COLOR:ResGoldLabelCS]联机工具箱 ' || COALESCE((SELECT Text FROM LocalizedText WHERE Tag = 'LOC_MPT_FE_VERSION'), '') || '[ENDCOLOR]';

INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
('LOC_MPT_FE_DESCRIPTION', 'zh_Hans_CN', '[ICON_Bolt][COLOR:ResGoldLabelCS]联机工具箱[ENDCOLOR][NEWLINE][NEWLINE][icon_Exclamation]联机大厅功能[NEWLINE][icon_You]准备房间增强：槽位上限20、快捷开关AI槽位、随机平衡分队、房主修改他人队伍与领袖[NEWLINE][icon_You]模组版本一致性校验、非官方模组清单、工坊模组自动更新[NEWLINE][icon_You]玩家标记档案（大厅与游戏内互通）、图标/贴图画册查看器[NEWLINE][icon_You]更新公告与最新动态、联机游戏设置预设、玩家名长度上限提升[NEWLINE][NEWLINE][icon_Exclamation]游戏内功能[NEWLINE][icon_You]快捷操作面板：团队投降/重新开始投票、强制结束回合、游戏内设置[NEWLINE][icon_You]智能回合计时器、真实科文进度、政策卡收益显示[NEWLINE][icon_You]顶部面板扩展、外交丝带扩展、队友资源可见性[NEWLINE][icon_You]交易与外交限制、商路/城邦/伟人/万神殿界面增强[NEWLINE][icon_You]更多快捷键、清理通知、交易与伟人招募提醒、禁用地图钉、建城免确认[NEWLINE][icon_You]战败观战、显示地图角落、大将军时代提示、工人劳动力显示、拯救开拓者、禁止空过研究'),
('LOC_MPT_FE_TEASER', 'zh_Hans_CN', '[size_32][COLOR:ResGoldLabelCS]联机工具箱[ENDCOLOR]'),
('LOC_MPT_FE_AUTHORS', 'zh_Hans_CN', '[COLOR:ResGoldLabelCS]号码菌[ENDCOLOR]'),
('LOC_MPT_FE_THANKS', 'zh_Hans_CN', '千川白浪，CHS, MPH, 皮皮凯, Zpod, 红魔族首席魔法师, 336tarot, 枫叶，BBG');
