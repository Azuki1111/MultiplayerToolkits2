-- ============================================================================
-- 条目20：智能回合计时器文本（zh_Hans_CN 简体中文）
-- 热键名/描述：设置→按键绑定列表显示（前后端各注册，主菜单也要显示）；
-- 按钮 tooltip：聊天框旁快捷按钮悬停显示。
-- 条目20扩展2：两项 Game 配置的文本——工作模式（三值：OFF/SMART/TIERED，原 BASIC
--   拆出为独立布尔、FIXED 改名 TIERED 平滑曲线）+ 启用聊天指令布尔开关。
-- 条目20优化10：1.67 减时按钮 tooltip「下回合减少20秒」与实际 p-- 的 -15 秒不符，
--   本 mod 文本按实际值写。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_TIMER_MODE_NAME',				'zh_Hans_CN',	'回合计时器模式（联机工具箱）'),
	('LOC_MPT_TIMER_MODE_DESC',				'zh_Hans_CN',	'本 mod 的回合计时器工作模式，房主可在开局后暂停菜单的游戏选项中修改'),
	('LOC_MPT_TIMER_MODE_OFF',				'zh_Hans_CN',	'关闭所有计时器'),
	('LOC_MPT_TIMER_MODE_OFF_DESC',			'zh_Hans_CN',	'不启用任何计时器管理，回合时间由游戏设置中的原版计时器参数决定（聊天指令同时停用）'),
	('LOC_MPT_TIMER_MODE_SMART',			'zh_Hans_CN',	'智能计时器'),
	('LOC_MPT_TIMER_MODE_SMART_DESC',		'zh_Hans_CN',	'根据多数玩家回合用时自动平衡回合时间，宣战/玩家掉线时自动加时，议会投票阶段固定120秒'),
	('LOC_MPT_TIMER_MODE_TIERED',			'zh_Hans_CN',	'阶段计时器'),
	('LOC_MPT_TIMER_MODE_TIERED_DESC',		'zh_Hans_CN',	'回合时间按回合节点表平滑线性过渡：默认 1~30 回合保持30秒，30~50 回合升至80秒，50~70 回合升至180秒，之后保持；节点与秒数可在 SmartTurnTimer_Tiers.sql 数据表中自定义'),
	('LOC_MPT_TIMER_CHAT_NAME',				'zh_Hans_CN',	'启用聊天指令'),
	('LOC_MPT_TIMER_CHAT_DESC',				'zh_Hans_CN',	'开启后聊天指令与快捷入口可用：p+ 加时20秒(每回合1次) / p+++ 本回合无回合时间 / p-- 下回合减时15秒；聊天框旁 P++/P-- 按钮与 [ ] 热键同步显隐；仅房主响应指令（关闭所有计时器模式下不生效）'),
	('LOC_MPT_TIMER_HOTKEY_ADD_NAME',		'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]快捷加时（智能计时器）[ENDCOLOR]'),
	('LOC_MPT_TIMER_HOTKEY_ADD_DESC',		'zh_Hans_CN',	'加时20秒（房主直接生效并广播；非房主自动代发聊天指令 p++，需房主启用聊天指令且模式非关闭）'),
	('LOC_MPT_TIMER_HOTKEY_REDUCE_NAME',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]快捷减时（智能计时器）[ENDCOLOR]'),
	('LOC_MPT_TIMER_HOTKEY_REDUCE_DESC',	'zh_Hans_CN',	'减时10秒（下限40秒；非房主自动代发聊天指令 p--）'),
	('LOC_MPT_TIMER_ADD_BUTTON_TT',			'zh_Hans_CN',	'立即加时20秒[NEWLINE][NEWLINE]输入 p+++ 可以无回合时间'),
	('LOC_MPT_TIMER_REDUCE_BUTTON_TT',		'zh_Hans_CN',	'下回合减少15秒');
