-- ============================================================================
-- 条目12：游戏内设置面板文本（zh_Hans_CN 简体中文）
-- LOC_MPT_SETTINGS_SHOW_FEB_NAME/TT 移植 1.67 Settings/TPT_Settings_Text.xml 的
--   LOC_SHOW_FEB_NAME/TT（1.67 仅 zh），tag 统一 MPT_ 前缀避免与 1.67 冲突（项目规约）；
-- 面板标题/确认按钮复用原版 LOC_GAMESUMMARY_HISTORY_SETTINGS / LOC_AUTONARRATE_BUTTON_DONE，不新增。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_SETTINGS_SHOW_FEB_NAME',	'zh_Hans_CN',	'显示强制结束回合按钮'),
	('LOC_MPT_SETTINGS_SHOW_FEB_TT',	'zh_Hans_CN',	'显示按钮'),
	('LOC_MPT_SETTINGS_NOC_DISABLE_NAME',	'zh_Hans_CN',	'禁用清理通知按钮'),
	('LOC_MPT_SETTINGS_NOC_DISABLE_TT',	'zh_Hans_CN',	'不再显示右下角通知栏的「清理通知」按钮（条目19 NOC）'),
	('LOC_MPT_SETTINGS_BTS_PATH_NAME',	'zh_Hans_CN',	'BTS 商路：近似商路路径'),
	('LOC_MPT_SETTINGS_BTS_PATH_TT',	'zh_Hans_CN',	'用直线距离近似商路路径而非实际路径（条目22 BTS）。城市很多时商路面板打开更快，但商路回合数估算在特定情况下会严重不准'),
	('LOC_MPT_SETTINGS_BTS_SORT_NAME',	'zh_Hans_CN',	'BTS 商路：常驻排序优先级'),
	('LOC_MPT_SETTINGS_BTS_SORT_TT',	'zh_Hans_CN',	'在排序按钮上常驻显示多级排序的优先级序号（条目22 BTS），适合按食物+生产力等多产量组合排序；关闭后按住 Shift 临时显示'),
	('LOC_MPT_SETTINGS_BTS_LPATH_NAME',	'zh_Hans_CN',	'BTS 商路：显示全部商路路径'),
	('LOC_MPT_SETTINGS_BTS_LPATH_TT',	'zh_Hans_CN',	'目的地选择面板中显示全部候选商路的路径而非仅选中项（条目22 BTS）。关闭可加快面板打开'),
	('LOC_MPT_SETTINGS_BTS_TPATH_NAME',	'zh_Hans_CN',	'BTS 商路：选中商人显示路径'),
	('LOC_MPT_SETTINGS_BTS_TPATH_TT',	'zh_Hans_CN',	'选中己方商人时自动显示其在途商路路径与两端城市（条目22 BTS）'),
	('LOC_MPT_SETTINGS_DPR_PNAME_NAME',	'zh_Hans_CN',	'外交丝带：显示玩家名'),
	('LOC_MPT_SETTINGS_DPR_PNAME_TT',	'zh_Hans_CN',	'在外交丝带头像卡片顶部显示玩家名（条目24 DPR）'),
	('LOC_MPT_SETTINGS_DPR_CNAME_NAME',	'zh_Hans_CN',	'外交丝带：显示文明名'),
	('LOC_MPT_SETTINGS_DPR_CNAME_TT',	'zh_Hans_CN',	'在外交丝带头像卡片顶部显示文明简称（条目24 DPR）'),
	('LOC_MPT_SETTINGS_BER_NAME',	'zh_Hans_CN',	'固定显示大将军时代'),
	('LOC_MPT_SETTINGS_BER_TT',	'zh_Hans_CN',	'在大将军下面显示所属时代标签（条目25 BER）');
-- 条目20初版曾在此加智能计时器开关文本（LOC_MPT_SETTINGS_TIMER_ENABLE_*），条目20扩展
-- 改用四模式 Game 配置参数（文本移至 InGame/SmartTurnTimer/ 双语 SQL），已删除。
-- 条目22：BTS 4 选项文本移植自 1.67 BTS/Text/BTS_Text_EN.xml 的 LOC_BTS_SETTING_*，
-- tag 换 LOC_MPT_SETTINGS_BTS_* 前缀（项目规约），措辞有润色。
-- 条目25：BER 开关文本沿用 1.67 原文案（1.67 仅 zh 且重复注册两遍，此处补 en_US）。
