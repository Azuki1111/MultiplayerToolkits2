-- ============================================================================
-- 条目12：游戏内设置参数表 MPT_Settings（移植 1.67 Settings/TPT_Settings.sql 简化版）
-- 仅保留本 mod 已移植功能的参数行（当前：FEB 强制结束回合按钮开关）；
-- 表名用 MPT_Settings（本 mod 数据表 MPT_ 前缀规约）——1.67 的 TPT_Settings 建表
-- 无 IF NOT EXISTS，同名表两 mod 共存时后加载者报错，故隔离；
-- ParameterId 保留 1.67 原 key（ForcedEndButton_Show，无 TPT 前缀的语义名）：
--   广播事件为本 mod 自有 MPT_Settings_Toggle（条目12优化命名规范化），
--   与 1.67 的 TPT_Settings_Toggle 互不联动，共存时各自控制各自功能。
-- String/ToolTip 文本 tag 统一 MPT_ 前缀（LOC_MPT_SETTINGS_SHOW_FEB_*，
--   项目规约避免与 1.67 冲突），见同目录 SettingsPanel_zh_Hans_CN.sql / en_US.sql。
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
		("ForcedEndButton_Show",					"LOC_MPT_SETTINGS_SHOW_FEB_NAME",	"LOC_MPT_SETTINGS_SHOW_FEB_TT",			0);
