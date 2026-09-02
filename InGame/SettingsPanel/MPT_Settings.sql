-- ============================================================================
-- 条目12：游戏内设置参数表 MPT_Settings（移植 1.67 Settings/TPT_Settings.sql 简化版）
-- 仅保留本 mod 已移植功能的参数行（当前：FEB 强制结束回合按钮 / 条目19 NOC 禁用
--   清理通知按钮 / 条目22 BTS 商路界面增强 4 选项）；条目25 增 BER 大将军时代提示行
--   （GreatGeneralEraReminder_Show 沿用 1.67 原 key，默认开）；
-- 表名用 MPT_Settings（本 mod 数据表 MPT_ 前缀规约）——1.67 的 TPT_Settings 建表
-- 无 IF NOT EXISTS，同名表两 mod 共存时后加载者报错，故隔离；
-- ParameterId 保留 1.67 原 key（ForcedEndButton_Show / NotificationPanel_QuickClear，
--   无 TPT 前缀的语义名；条目22 BTS_ 四行沿用 1.67 BTS_Settings.sql 原 key 与默认值）：
--   广播事件为本 mod 自有 MPT_Settings_Toggle（条目12优化命名规范化），
--   与 1.67 的 TPT_Settings_Toggle 互不联动，共存时各自控制各自功能。
-- String/ToolTip 文本 tag 统一 MPT_ 前缀（LOC_MPT_SETTINGS_SHOW_FEB_* /
--   LOC_MPT_SETTINGS_NOC_DISABLE_* / LOC_MPT_SETTINGS_BTS_*，项目规约避免与 1.67
--   冲突），见同目录 SettingsPanel_zh_Hans_CN.sql / en_US.sql。
-- 条目20初版曾在此加 TOOLS_COMMAND（智能计时器）行，条目20扩展改用四模式 Game
--   配置参数 MPT_TIMER_MODE（见 InGame/SmartTurnTimer/Config_SmartTimer.xml），
--   布尔行已移除（布尔无法表达四模式，两套开关并存会互相打架）。
-- 条目22语义差异留痕：1.67 BTS 设置存 GameConfiguration 配置库（BTS_Settings 表 +
--   BTS_SettingsUpdate 事件 + 独立设置面板），本 mod 收编 MPT_Settings 行 +
--   MPT_Settings_Toggle 广播；与 1.67 同装时设置互不相通（商路 UI 文件由本 mod
--   ImportFiles 100010 压制 1.67 的 11011 生效，1.67 配置值无人读取）。
-- ============================================================================
CREATE TABLE IF NOT EXISTS MPT_Settings (
	ParameterId TEXT NOT NULL,
	String TEXT NOT NULL,
	ToolTip TEXT,
	DefaultValue BOOLEAN DEFAULT 0,
	PRIMARY KEY(ParameterId)
);

INSERT OR REPLACE INTO MPT_Settings
		(ParameterId,								String,								ToolTip,								DefaultValue)
VALUES
		("ForcedEndButton_Show",					"LOC_MPT_SETTINGS_SHOW_FEB_NAME",	"LOC_MPT_SETTINGS_SHOW_FEB_TT",			0),
		("NotificationPanel_QuickClear",			"LOC_MPT_SETTINGS_NOC_DISABLE_NAME",	"LOC_MPT_SETTINGS_NOC_DISABLE_TT",		0),
		("BTS_ApproximateTraderPath",				"LOC_MPT_SETTINGS_BTS_PATH_NAME",	"LOC_MPT_SETTINGS_BTS_PATH_TT",			0),
		("BTS_ShowSortPriorities",					"LOC_MPT_SETTINGS_BTS_SORT_NAME",	"LOC_MPT_SETTINGS_BTS_SORT_TT",			0),
		("BTS_ShowAllRoutePaths",					"LOC_MPT_SETTINGS_BTS_LPATH_NAME",	"LOC_MPT_SETTINGS_BTS_LPATH_TT",		1),
		("BTS_ShowTraderPathOnSelection",			"LOC_MPT_SETTINGS_BTS_TPATH_NAME",	"LOC_MPT_SETTINGS_BTS_TPATH_TT",		1),
		("DiplomacyRibbon_PlayerInfo_PlayerName",	"LOC_MPT_SETTINGS_DPR_PNAME_NAME",	"LOC_MPT_SETTINGS_DPR_PNAME_TT",		1),
		("DiplomacyRibbon_PlayerInfo_CiviName",		"LOC_MPT_SETTINGS_DPR_CNAME_NAME",	"LOC_MPT_SETTINGS_DPR_CNAME_TT",		1),
		("GreatGeneralEraReminder_Show",			"LOC_MPT_SETTINGS_BER_NAME",		"LOC_MPT_SETTINGS_BER_TT",			1);
