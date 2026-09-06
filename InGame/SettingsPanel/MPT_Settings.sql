-- ============================================================================
-- 条目12：游戏内设置参数表 MPT_Settings（移植 1.67 Settings/TPT_Settings.sql 简化版）
-- 仅保留本 mod 已移植功能的参数行（当前：FEB 强制结束回合按钮 / 条目19 NOC 禁用
--   清理通知按钮）；条目25 增 BER 大将军时代提示行
--   （GreatGeneralEraReminder_Show 沿用 1.67 原 key，默认开）；
-- 表名用 MPT_Settings（本 mod 数据表 MPT_ 前缀规约）——1.67 的 TPT_Settings 建表
-- 无 IF NOT EXISTS，同名表两 mod 共存时后加载者报错，故隔离；
-- ParameterId 保留 1.67 原 key（ForcedEndButton_Show / NotificationPanel_QuickClear，
--   无 TPT 前缀的语义名）：
--   广播事件为本 mod 自有 MPT_Settings_Toggle（条目12优化命名规范化），
--   与 1.67 的 TPT_Settings_Toggle 互不联动，共存时各自控制各自功能。
-- String/ToolTip 文本 tag 统一 MPT_ 前缀（LOC_MPT_SETTINGS_SHOW_FEB_* /
--   LOC_MPT_SETTINGS_NOC_DISABLE_*，项目规约避免与 1.67 冲突），
--   见同目录 SettingsPanel_zh_Hans_CN.sql / en_US.sql。
-- 条目20初版曾在此加 TOOLS_COMMAND（智能计时器）行，条目20扩展改用四模式 Game
--   配置参数 MPT_TIMER_MODE（见 InGame/SmartTurnTimer/Config_SmartTimer.xml），
--   布尔行已移除（布尔无法表达四模式，两套开关并存会互相打架）。
-- 条目22 曾加 BTS 商路界面 4 选项行（BTS_* 沿用 1.67 原 key），条目22调整按用户裁决
--   回退——4 选项不开放配置，硬编码 1.67 BTS_Settings.sql 默认值（近似路径 0/排序
--   序号 0/全部路径 1/选中显示路径 1，见 InGame/BetterTradeScreen/ 各 Lua 文件头）。
-- 条目26 增两行：NDR 交易提醒（NotificationPanel_DealRemind 沿用 1.67 原 key，默认开，
--   开关语义同 1.67 仅控提示音、自动展开不受控）+ GPR 他人招募伟人通知
--   （NotificationPanel_GreatPersonRecruited 自造 key——源 mod 2459772036 无设置体系，
--   命名与 NotificationPanel_DealRemind 对称，默认开）。
-- 条目27 世界议会弃权选项行已随功能移除（用户裁决：引擎对未投票决议强制随机代投，
--   弃权引擎层不可实现，详见 计划.md 条目27移除段）。
-- 条目29 曾增 BGP 伟人界面增强行，同日修订去除（用户裁决：默认增强即可恒启用
--   无开关，消费侧 InGame/BetterGreatPeople/GreatPeoplePopup.lua 不再监听
--   MPT_Settings_Toggle）。
-- 条目35 增一行：CSB 城墙射击按钮收回（CityStrikeButton_Back 沿用 1.67 原 key，
--   默认关——默认态按钮挪横幅右侧，勾选收回原版底部中央坐标，
--   消费侧 InGame/CityBannerEnhance/CityBannerManager_CSB_MPT.lua）。
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
		("ForcedEndButton_Show",					"LOC_MPT_SETTINGS_SHOW_FEB_NAME",	"LOC_MPT_SETTINGS_SHOW_FEB_TT",				1),
		("NotificationPanel_QuickClear",			"LOC_MPT_SETTINGS_NOC_DISABLE_NAME",	"LOC_MPT_SETTINGS_NOC_DISABLE_TT",		0),
		("DiplomacyRibbon_PlayerInfo_PlayerName",	"LOC_MPT_SETTINGS_DPR_PNAME_NAME",	"LOC_MPT_SETTINGS_DPR_PNAME_TT",			1),
		("DiplomacyRibbon_PlayerInfo_CiviName",		"LOC_MPT_SETTINGS_DPR_CNAME_NAME",	"LOC_MPT_SETTINGS_DPR_CNAME_TT",			1),
		("GreatGeneralEraReminder_Show",			"LOC_MPT_SETTINGS_BER_NAME",		"LOC_MPT_SETTINGS_BER_TT",					1),
		("NotificationPanel_DealRemind",			"LOC_MPT_SETTINGS_NDR_NAME",		"LOC_MPT_SETTINGS_NDR_TT",					1),
		("NotificationPanel_GreatPersonRecruited",	"LOC_MPT_SETTINGS_GPR_NAME",		"LOC_MPT_SETTINGS_GPR_TT",					1),
		("CityStrikeButton_Back",					"LOC_MPT_SETTINGS_CSB_NAME",		"LOC_MPT_SETTINGS_CSB_TT",					0);
