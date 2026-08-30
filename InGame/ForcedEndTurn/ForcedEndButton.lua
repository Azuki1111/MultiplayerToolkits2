-- ============================================================================
-- 条目12：强制结束回合按钮（FEB，移植 1.67 FEB/UI/ForcedEndButton.lua）
--
-- 功能：ActionPanel 右下角小按钮，左键无视未完成行动直接请求结束回合；
--   显隐默认隐藏（同 1.67），由游戏内设置面板（MPT_SettingsPanel）经
--   LuaEvents.MPT_Settings_Toggle("ForcedEndButton_Show", Value) 广播控制。
-- 挂载：LoadScreenClose 时 ChangeParent 到 /InGame/ActionPanel（R,B 0,0）。
--
-- 与 1.67 差异（逐条注释留痕）：
--   1) 加 m_attached 幂等守卫：防 LoadScreenClose 多次触发重复 ChangeParent
--      （项目条目5 RMC 同款惯例；1.67 无守卫）；
--   2) Tooltip 文本预加载缓存（项目规范：Lua 内使用前预加载为 local）。
--
-- 注册：AddUserInterfaces(Context=InGame) + ImportFiles 同名 Lua 自动执行。
-- ============================================================================

-- 文本预加载缓存（项目规范：分区头后集中预加载）
local ForcedEndTTStr : string = Locale.Lookup("LOC_FORCEEND_TT");

-- 按钮显隐状态（默认隐藏，等设置面板广播；1.67 同款）
local Show_FEB : boolean = false;
-- 已挂载守卫（防 LoadScreenClose 多次触发重复 ChangeParent）
local m_attached : boolean = false;

-- ============================================================================
-- 设置广播响应：ForcedEndButton_Show 控制按钮显隐（事件名 MPT_Settings_Toggle，
-- 本 mod 自有命名规范，由游戏内设置面板 MPT_SettingsPanel 广播）
-- ============================================================================
function OnMPT_Settings_Toggle(ParameterId, Value)
	if ParameterId == "ForcedEndButton_Show" then
		Show_FEB = Value;
		Controls.ForcedEnd_Button:SetHide(not Show_FEB);
		return;
	end
end

-- ============================================================================
-- 挂载到 ActionPanel 右下角并注册点击
-- 左键：REQUEST_ENDTURN（REASON=UserForced 强制，绕过行动检查）
-- 右键：LuaEvents.ForcedEndTurn 触发点——1.67 由 NHK 热键系统（回合超时）消费，
--   本 mod 未移植 NHK，当前无消费者（点击无操作）；保留触发点，将来移植 NHK 自动对接
-- ============================================================================
function LateInitialize()
	if m_attached then
		return;
	end
	local ctr = ContextPtr:LookUpControl("/InGame/ActionPanel");
	if ctr ~= nil then
		Controls.ForcedEnd_Button:ChangeParent(ctr);
		m_attached = true;
	end
	Controls.ForcedEnd_Button:SetToolTipString(ForcedEndTTStr);
	Controls.ForcedEnd_Button:RegisterCallback(Mouse.eLClick, function() UI.RequestAction(ActionTypes.ACTION_ENDTURN, { REASON = "UserForced" }); end);
	Controls.ForcedEnd_Button:RegisterCallback(Mouse.eRClick, function() LuaEvents.ForcedEndTurn(); end);
	Controls.ForcedEnd_Button:SetHide(not Show_FEB);
end

-- ============================================================================
-- 初始化
-- ============================================================================
function Initialize()
	Events.LoadScreenClose.Add(LateInitialize);
	LuaEvents.MPT_Settings_Toggle.Add(OnMPT_Settings_Toggle);
end
Initialize();
