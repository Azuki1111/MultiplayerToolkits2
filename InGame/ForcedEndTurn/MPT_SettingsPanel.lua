-- ============================================================================
-- 条目12：游戏内设置面板（移植 1.67 Settings/UI/TPT_SettingsPanel.lua 简化版）
--
-- 功能：游戏内选项设置（当前仅「显示强制结束回合按钮」FEB 开关）。参数行来自
--   GameInfo.MPT_Settings 数据表；打开入口 = QuickPanel（条目8）展开区「设置」
--   按钮 → LuaEvents.MPT_Settings_Toggle() 开关面板；选项修改后广播
--   LuaEvents.TPT_Settings_Toggle(ParameterId, Value)（1.67 兼容事件名与 key，
--   FEB 按钮等各功能监听响应），并持久化到本地存档。
--
-- 与 1.67 差异（逐条注释留痕）：
--   1) 存档改走本 mod 条目4.3 存储管线 MPT_DataStorage（游戏内 include 可靠，
--      条目11 实证）：MPT_Storage_LoadComposite/SaveComposite("MPT_Settings",
--      {ForcedEndButton_Show})——替代 1.67 的 serialize/deserialize +
--      ModGroup 组名 [size_0][TPTsettings] 手工存档（与 1.67 存档隔离）；
--   2) 删 1.67 齿轮入口 TPTSettingButton（ChangeParent 到 WorldTrackerHeader），
--      入口改 LuaEvents.MPT_Settings_Toggle 监听（QuickPanel「设置」按钮触发）；
--   3) 参数表读 GameInfo.MPT_Settings（本 mod 表名，避免与 1.67 TPT_Settings 共存冲突）；
--   4) 删 1.67 Initializedata 的「存档行本局未使用存回去」分支（本 mod 参数
--      全部常驻 MPT_Settings 表，无此场景）；
--   5) 复选框点击即落盘（1.67 仅在 OnClose 保存——防改了不点确认关面板丢配置）。
--
-- 注册：AddUserInterfaces(Context=InGame) + ImportFiles 同名 Lua 自动执行。
-- ============================================================================

include("InstanceManager");
include("MPT_DataStorage");	-- 条目4.3 存储管线（自带 include("MPT_Serialize") 与幂等守卫）

-- ============================================================================
-- 复选框实例管理与状态表（下标即参数行序，SetVoid1 传下标）
-- ============================================================================
local m_CheckBoxsIM : table = InstanceManager:new("CheckboxInstance", "ButtonRoot", Controls.CheckBoxStack);
local m_CheckBoxsControls : table = {};
local TPT_Settings_CheckBoxs : table = {};

local First_Use : boolean = true;	-- 无本地存档时的首次使用（LoadScreenClose 后自动弹出面板）

-- ============================================================================
-- 创建复选框列表（按 MPT_Settings 表参数行逐个建实例；
-- 名称/Tooltip 为数据驱动的动态 key（idata.String/idata.ToolTip），运行时 Locale.Lookup，不预加载）
-- ============================================================================
function CreatCheckBoxStack()
	m_CheckBoxsIM:ResetInstances();
	for i, idata in pairs(TPT_Settings_CheckBoxs) do
		local CheckBoxsControl = m_CheckBoxsIM:GetInstance();
		m_CheckBoxsControls[i] = CheckBoxsControl;

		CheckBoxsControl.Settings_Box:SetText(Locale.Lookup(idata.String));
		if idata.ToolTip then
			CheckBoxsControl.Settings_Box:SetToolTipString(Locale.Lookup(idata.ToolTip));
		end
		CheckBoxsControl.Settings_Box:SetSelected(idata.Value);
		CheckBoxsControl.Settings_Box:SetVoid1(i);
		CheckBoxsControl.Settings_Box:RegisterCallback(Mouse.eLClick, OnCheckBoxs);
	end
	Controls.CheckBoxStack:CalculateSize();
	Controls.Listings:CalculateSize();
end

-- ============================================================================
-- 初始化：按当前值刷新复选框 + 广播全部参数（各功能据此初始化显隐/状态）
-- ============================================================================
function SetCheck()
	for i, iControl in ipairs(m_CheckBoxsControls) do
		iControl.Settings_Box:SetSelected(TPT_Settings_CheckBoxs[i].Value);
		LuaEvents.TPT_Settings_Toggle(TPT_Settings_CheckBoxs[i].ParameterId, TPT_Settings_CheckBoxs[i].Value);
	end
end

-- ============================================================================
-- 复选框点击：翻转值 → 刷新勾选态 → 广播（对应功能响应）→ 立即落盘
-- ============================================================================
function OnCheckBoxs(i)
	local CheckBoxsControl = m_CheckBoxsIM:GetAllocatedInstance(i);
	TPT_Settings_CheckBoxs[i].Value = not TPT_Settings_CheckBoxs[i].Value;

	CheckBoxsControl.Settings_Box:SetSelected(TPT_Settings_CheckBoxs[i].Value);
	LuaEvents.TPT_Settings_Toggle(TPT_Settings_CheckBoxs[i].ParameterId, TPT_Settings_CheckBoxs[i].Value);
	storageData();
end

-- ============================================================================
-- 显示/隐藏面板（QuickPanel「设置」按钮 → LuaEvents.MPT_Settings_Toggle 触发）
-- ============================================================================
function OnShow()
	ContextPtr:SetHide(false);
end

function OnClose()
	ContextPtr:SetHide(true);
	storageData();
end

function OnSettingButton()
	if ContextPtr:IsHidden() then
		OnShow();
	else
		OnClose();
	end
end

-- ============================================================================
-- 储存数据：收集全部参数当前值 → 复合存档（条目4.3 管线，组名 [MPT_DS][MPT_Settings]）
-- ============================================================================
function storageData()
	local t : table = {};
	for i, idata in pairs(TPT_Settings_CheckBoxs) do
		t[idata.ParameterId] = idata.Value;
	end
	MPT_Storage_SaveComposite("MPT_Settings", t);
end

-- ============================================================================
-- 读取存档：覆盖默认值（有存档 → First_Use 置 false；无存档保持 true，首次自动弹窗）
-- ============================================================================
function Initializedata()
	MPT_Storage_LoadComposite("MPT_Settings", { "ForcedEndButton_Show" }, function(savedValue)
		if savedValue ~= nil then
			First_Use = false;
			for i, idata in pairs(TPT_Settings_CheckBoxs) do
				if idata.ParameterId == "ForcedEndButton_Show" then
					TPT_Settings_CheckBoxs[i].Value = savedValue;
				end
			end
		end
	end);
end

-- ============================================================================
-- LoadScreenClose：广播当前值（各功能初始化显隐）+ 绑定确认按钮 + 首次自动弹出
-- ============================================================================
function LateInitialize()
	SetCheck();
	-- 确认按钮：保存并关闭（String 已在 XML 指定 LOC_AUTONARRATE_BUTTON_DONE）
	Controls.ConfirmButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.ConfirmButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	if First_Use then	-- 初次使用（无本地存档）：弹出面板提示设置入口
		OnShow();
	end
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
		table.insert(TPT_Settings_CheckBoxs, idata);
	end
	CreatCheckBoxStack();	-- 创建复选框列
	Initializedata();		-- 读取用户存档覆盖默认值

	-- 入口：QuickPanel（条目8）展开区「设置」按钮 → LuaEvents.MPT_Settings_Toggle 开关面板
	LuaEvents.MPT_Settings_Toggle.Add(OnSettingButton);
	Events.LoadScreenClose.Add(LateInitialize);
end
Initialize();
