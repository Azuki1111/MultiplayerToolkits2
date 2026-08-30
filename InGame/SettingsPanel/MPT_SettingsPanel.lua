-- ============================================================================
-- 条目12：游戏内设置面板（移植 1.67 Settings/UI/TPT_SettingsPanel.lua 简化版）
--
-- 功能：游戏内选项设置（当前仅「显示强制结束回合按钮」FEB 开关）。参数行来自
--   GameInfo.MPT_Settings 数据表；打开入口 = QuickPanel（条目8）展开区「设置」
--   按钮 → LuaEvents.MPT_Settings_Toggle() 开关面板；选项修改后广播
--   LuaEvents.MPT_Settings_Toggle(ParameterId, Value)（本 mod 自有事件名，MPT 前缀
--   规范；FEB 按钮等各功能监听响应），并持久化到本地存档。
--
-- 与 1.67 差异（逐条注释留痕）：
--   1) 存档走本 mod 条目4.3 存储管线 MPT_DataStorage（游戏内 include 可靠，
--      条目11 实证），条目4.3重构后为**统一多表存储**：与前端 4.4/条目11
--      玩家标记同一命名空间 MPT_PlayerInfo 的单一复合组行，**表名 = 参数
--      ParameterId**（ForcedEndButton_Show），与 Players / HiddenSqlMark
--      等表同组承载互不覆盖——「所有数据同一 ModGroupName，按表名分键」；
--      替代 1.67 的 serialize/deserialize + ModGroup 组名 [size_0][TPTsettings]
--      手工存档（与 1.67 存档隔离）；
--   2) 删 1.67 齿轮入口 TPTSettingButton（ChangeParent 到 WorldTrackerHeader），
--      入口改 LuaEvents.MPT_Settings_Toggle 监听（QuickPanel「设置」按钮触发）；
--   3) 参数表读 GameInfo.MPT_Settings（本 mod 表名，避免与 1.67 TPT_Settings 共存冲突）；
--   4) 删 1.67 Initializedata 的「存档行本局未使用存回去」分支（本 mod 参数
--      全部常驻 MPT_Settings 表，无此场景）；
--   5) 存档读写用 SaveTables/LoadAll（条目4.3重构）：SaveTables 内部自动读回
--      整组合并、仅按表名覆盖，调用方无需手动读回合并（旧 SaveComposite 为
--      全量覆盖语义需调用方 merge）；
--   6) 不在点击时立即落盘（1.67 同款，仅关闭面板时保存）——点击即存会触发
--      StorageCreateCleanGroup 批量禁用/启用全部 mod，造成点复选框卡顿；
--   7) 命名规范化（条目12优化）：1.67 遗留的 TPT_/无前缀命名改为 MPT_ 前缀
--      （TPT_Settings_CheckBoxs→MPT_Settings_CheckBoxs、CreatCheckBoxStack→
--      MPT_SettingsPanel_CreateCheckboxes、OnCheckBoxs→MPT_SettingsPanel_OnToggle、
--      SetCheck→MPT_SettingsPanel_ApplyAll、storageData→MPT_SettingsPanel_Save、
--      Initializedata→MPT_SettingsPanel_Load、OnShow/OnClose/OnSettingButton→
--      MPT_SettingsPanel_Show/Close/OnOpen、事件 TPT_Settings_Toggle→
--      MPT_Settings_Toggle）。
--
-- 注册：AddUserInterfaces(Context=InGame) + ImportFiles 同名 Lua 自动执行。
-- ============================================================================

include("InstanceManager");
include("MPT_DataStorage");	-- 条目4.3 存储管线（自带 include("MPT_Serialize") 与幂等守卫）

-- ============================================================================
-- 复合组命名空间：与前端 4.4/条目11 玩家标记同一 ModGroupName（所有数据同组承载）
-- ============================================================================
local PLAYERMARK_STORAGE_FILE : string = "MPT_PlayerInfo";

-- ============================================================================
-- 复选框实例管理与状态表（下标即参数行序，SetVoid1 传下标）
-- ============================================================================
local m_CheckBoxsIM : table = InstanceManager:new("CheckboxInstance", "ButtonRoot", Controls.CheckBoxStack);
local m_CheckBoxsControls : table = {};
local MPT_Settings_CheckBoxs : table = {};

-- ============================================================================
-- 创建复选框列表（按 MPT_Settings 表参数行逐个建实例；
-- 名称/Tooltip 为数据驱动的动态 key（idata.String/idata.ToolTip），运行时 Locale.Lookup，不预加载）
-- ============================================================================
function MPT_SettingsPanel_CreateCheckboxes()
	m_CheckBoxsIM:ResetInstances();
	for i, idata in pairs(MPT_Settings_CheckBoxs) do
		local CheckBoxsControl = m_CheckBoxsIM:GetInstance();
		m_CheckBoxsControls[i] = CheckBoxsControl;

		CheckBoxsControl.Settings_Box:SetText(Locale.Lookup(idata.String));
		if idata.ToolTip then
			CheckBoxsControl.Settings_Box:SetToolTipString(Locale.Lookup(idata.ToolTip));
		end
		CheckBoxsControl.Settings_Box:SetSelected(idata.Value);
		CheckBoxsControl.Settings_Box:SetVoid1(i);
		CheckBoxsControl.Settings_Box:RegisterCallback(Mouse.eLClick, MPT_SettingsPanel_OnToggle);
	end
	Controls.CheckBoxStack:CalculateSize();
	Controls.Listings:CalculateSize();
end

-- ============================================================================
-- 初始化：按当前值刷新复选框 + 广播全部参数（各功能据此初始化显隐/状态）
-- ============================================================================
function MPT_SettingsPanel_ApplyAll()
	for i, iControl in ipairs(m_CheckBoxsControls) do
		iControl.Settings_Box:SetSelected(MPT_Settings_CheckBoxs[i].Value);
		LuaEvents.MPT_Settings_Toggle(MPT_Settings_CheckBoxs[i].ParameterId, MPT_Settings_CheckBoxs[i].Value);
	end
end

-- ============================================================================
-- 复选框点击：翻转值 → 刷新勾选态 → 广播（对应功能响应）。
-- 不立即落盘：点击即存会触发 StorageCreateCleanGroup 批量禁用/启用全部 mod 造成卡顿
-- （1.67 同款，仅在关闭面板时保存；面板只有 Confirm 一条关闭路径，无丢失场景）
-- ============================================================================
function MPT_SettingsPanel_OnToggle(i)
	local CheckBoxsControl = m_CheckBoxsIM:GetAllocatedInstance(i);
	MPT_Settings_CheckBoxs[i].Value = not MPT_Settings_CheckBoxs[i].Value;

	CheckBoxsControl.Settings_Box:SetSelected(MPT_Settings_CheckBoxs[i].Value);
	LuaEvents.MPT_Settings_Toggle(MPT_Settings_CheckBoxs[i].ParameterId, MPT_Settings_CheckBoxs[i].Value);
end

-- ============================================================================
-- 显示/隐藏面板（QuickPanel「设置」按钮 → LuaEvents.MPT_Settings_Toggle 触发）
-- ============================================================================
function MPT_SettingsPanel_Show()
	ContextPtr:SetHide(false);
end

function MPT_SettingsPanel_Close()
	ContextPtr:SetHide(true);
	MPT_SettingsPanel_Save();
end

function MPT_SettingsPanel_OnOpen()
	if ContextPtr:IsHidden() then
		MPT_SettingsPanel_Show();
	else
		MPT_SettingsPanel_Close();
	end
end

-- ============================================================================
-- 储存数据：按表名覆盖写（SaveTables 内部自动读回合并，Players 等其它表保留——
-- 无需手动读回；表名 = 参数 ParameterId，未来新增参数零改动）。
-- 组名 [MPT_DS][MPT_PlayerInfo][len]return { ForcedEndButton_Show=..., Players=..., ... }
-- ============================================================================
function MPT_SettingsPanel_Save()
	local tables : table = {};
	for i, idata in pairs(MPT_Settings_CheckBoxs) do
		tables[idata.ParameterId] = idata.Value;
	end
	MPT_Storage_SaveTables(PLAYERMARK_STORAGE_FILE, tables);
end

-- ============================================================================
-- 读取存档：按表名（ParameterId）读各参数值覆盖默认值（整组读回，表名 = 参数 id）；
-- 无存档/表缺失 → 保持表默认 0
-- ============================================================================
function MPT_SettingsPanel_Load()
	MPT_Storage_LoadAll(PLAYERMARK_STORAGE_FILE, function(all)
		for i, idata in pairs(MPT_Settings_CheckBoxs) do
			local v = all[idata.ParameterId];
			if v ~= nil then
				MPT_Settings_CheckBoxs[i].Value = v;
			end
		end
	end);
end

-- ============================================================================
-- LoadScreenClose：广播当前值（各功能初始化显隐）+ 绑定确认按钮
-- （条目12修复：删 1.67「无存档首次自动弹出」——本 mod 有 QuickPanel「设置」
--   按钮明确入口；自动弹窗依赖本地存档判定且游戏内不可靠，此前每次进游戏都弹）
-- ============================================================================
function LateInitialize()
	MPT_SettingsPanel_ApplyAll();
	-- 确认按钮：保存并关闭（String 已在 XML 指定 LOC_AUTONARRATE_BUTTON_DONE）
	Controls.ConfirmButton:RegisterCallback(Mouse.eLClick, MPT_SettingsPanel_Close);
	Controls.ConfirmButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
end

-- ============================================================================
-- 初始化
-- ============================================================================
function Initialize()
	for kData in GameInfo.MPT_Settings() do
		local idata : table = {
			ParameterId = kData.ParameterId,
			Value = kData.DefaultValue,
			String = kData.String,
			ToolTip = kData.ToolTip,
		};
		table.insert(MPT_Settings_CheckBoxs, idata);
	end
	MPT_SettingsPanel_CreateCheckboxes();	-- 创建复选框列
	MPT_SettingsPanel_Load();				-- 读取用户存档覆盖默认值

	-- 入口：QuickPanel（条目8）展开区「设置」按钮 → LuaEvents.MPT_Settings_Toggle 开关面板
	LuaEvents.MPT_Settings_Toggle.Add(MPT_SettingsPanel_OnOpen);
	Events.LoadScreenClose.Add(LateInitialize);
end
Initialize();
