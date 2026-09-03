-- ===========================================================================
-- 条目28：地图钉快捷键（移植 1.65 NHK/UI/MapPin_HotKey.lua）
--
-- 功能（四键，动作注册见 NewHotKeys_InputActions.xml）：
--   Shift+Y 发送聊天坐标：光标地块建钉并发送到聊天，随后删除本地钉，聊天里只留
--     pin 图标消息（监听自己发出的 MultiplayerChat pin 串立即删钉）
--   Shift+A 添加地图钉：先展开地图钉显示再请求建钉（弹出门被隐藏时先恢复）
--   Shift+D 删除地图钉：删除光标处地图钉并 BroadcastPlayerInfo 联机同步；
--     钉隐藏状态时先展开（先见后删）
--   Shift+M 显隐全部地图钉：地图钉列表按钮选中（正在添加钉）时不切换
--
-- 注入机制：AddUserInterfaces 迷你上下文（同条目12/20 机制），控件按路径
--   LookUpControl 惰性解析（/InGame/MapPinManager/MapPinFlags、
--   /InGame/MinimapPanel/MapPinListButton），事件经 LuaEvents 跨上下文通信。
-- 与 1.65 差异（逐条留痕）：
--   1) 零全局污染：1.65 泄漏 8 个全局函数（OnInputActionTriggered/AddMapMessage/
--      HideMapPins 等），本文件全部 local（条目18 同款约定）
--   2) 惰性解析的控件句柄 nil 防御（面板未加载时按键静默跳过，1.65 直接踩空崩脚）
--   3) 保留 1.65 运行时门控：CPL_NO_PINS（条目16「禁用地图钉」开关）勾选时四键失效
-- 相对 1.65 的让位（criteria 层，modinfo 配置）：1.65 在装时本上下文不加载（其原版
--   Lua 继续服务，避免双建钉/显隐双翻转互相抵消）；DMT 类地图钉 mod 在装时同样让位。
-- 注册：AddUserInterfaces(900) + ImportFiles(900)，criteria=Disable_TPT_DMT（条目28调整：不受
-- 「更多快捷键」开关影响，仅 1.65/DMT 同装让位）
-- ===========================================================================

local m_AddMapMessageId      : number = Input.GetActionId("AddMapMessage");
local m_AddMapTackId         : number = Input.GetActionId("AddMapTack");
local m_DeleteMapTackId      : number = Input.GetActionId("DeleteMapTack");
local m_ToggleVisibilityId   : number = Input.GetActionId("ToggleMapTackVisibility");
local m_MapPinListBtn        : table  = nil;	-- /InGame/MinimapPanel/MapPinListButton 惰性解析缓存
local m_MapPinFlags          : table  = nil;	-- /InGame/MapPinManager/MapPinFlags 惰性解析缓存

-- Shift+Y 发出的 pin 串与坐标（MultiplayerChat 回声比对用，1.65 同款单槽）
local g_mapPinStr            : string = nil;
local g_X                    : number = nil;
local g_Y                    : number = nil;

-- ===========================================================================
-- 惰性解析控件（各自 nil 防御：目标面板未加载时返回 false 由调用方跳过）
-- ===========================================================================
local function GetMapPinFlags()
	if m_MapPinFlags == nil then
		m_MapPinFlags = ContextPtr:LookUpControl("/InGame/MapPinManager/MapPinFlags");
	end
	return m_MapPinFlags;
end

-- ===========================================================================
-- 删除指定玩家在指定地块的地图钉并广播联机同步（AddMapMessage 自删与 Shift+D 共用）
-- 1.65 原样保留 DMT_MapPinRemoved 广播：供 DMT 类 mod 清理其 tack 数据（本 mod 无监听者，无害）
-- ===========================================================================
local function DeleteMapPinAtPlot(playerID : number, plotX : number, plotY : number)
	local playerCfg : table = PlayerConfigurations[playerID];
	local mapPin : table = playerCfg and playerCfg:GetMapPin(plotX, plotY);
	if mapPin then
		-- Update map pin yields.
		LuaEvents.DMT_MapPinRemoved(mapPin);
		-- Delete the pin.
		playerCfg:DeleteMapPin(mapPin:GetID());
		Network.BroadcastPlayerInfo();
		UI.PlaySound("Map_Pin_Remove");
	end
end

-- ===========================================================================
-- Shift+Y：光标地块建钉 → 发送到聊天 → 删除本地钉（聊天里只留 pin 图标）
-- MapPinPopup 弹窗随建钉请求弹出，此处 DequeuePopup 弹掉（1.65 同款，不误触弹窗）
-- ===========================================================================
local function AddMapMessage()
	local plotX, plotY = UI.GetCursorPlotCoord();
	if plotX and plotY then
		LuaEvents.MapPinPopup_RequestMapPin(plotX, plotY);
		local Ctr = ContextPtr:LookUpControl("/InGame/MapPinPopup");
		if Ctr ~= nil then
			UIManager:DequeuePopup(Ctr);
		end

		local pPlayerCfg : table = PlayerConfigurations[Game.GetLocalPlayer()];
		local pMapPin : table = pPlayerCfg and pPlayerCfg:GetMapPin(plotX, plotY);
		if pMapPin ~= nil then
			LuaEvents.MapPinPopup_SendPinToChat(Game.GetLocalPlayer(), pMapPin:GetID());
			g_mapPinStr = "[pin:" .. Game.GetLocalPlayer() .. "," .. pMapPin:GetID() .. "]";
			g_X, g_Y = plotX, plotY;
		end
	end
end

-- ===========================================================================
-- Shift+A：先展开地图钉显示再请求建钉
-- ===========================================================================
local function AddMapPin()
	local pinFlags : table = GetMapPinFlags();
	if pinFlags == nil then
		return;
	end
	-- Make sure the map pins are shown before adding.
	pinFlags:SetHide(false);
	local plotX, plotY = UI.GetCursorPlotCoord();
	LuaEvents.MapPinPopup_RequestMapPin(plotX, plotY);
end

-- ===========================================================================
-- Shift+D：删除光标处地图钉；钉隐藏状态时先展开（先见后删）
-- ===========================================================================
local function DeleteMapPin()
	local pinFlags : table = GetMapPinFlags();
	if pinFlags == nil then
		return;
	end
	if not pinFlags:IsHidden() then
		-- Only delete if the map pins are not hidden.
		local plotX, plotY = UI.GetCursorPlotCoord();
		DeleteMapPinAtPlot(Game.GetLocalPlayer(), plotX, plotY);
	else
		pinFlags:SetHide(false)
	end
end

-- ===========================================================================
-- Shift+M：显隐全部地图钉；地图钉列表按钮选中（正在放置新钉）时不切换
-- ===========================================================================
local function HideMapPins()
	UI.PlaySound("Play_UI_Click");
	if m_MapPinListBtn == nil then
		m_MapPinListBtn = ContextPtr:LookUpControl("/InGame/MinimapPanel/MapPinListButton");
	end
	if m_MapPinListBtn == nil then
		return;
	end
	if not m_MapPinListBtn:IsSelected() then
		local pinFlags : table = GetMapPinFlags();
		if pinFlags == nil then
			return;
		end
		-- Only toggle the map pin visibility if MapPinListButton is not selected. i.e. not trying to add new pins.
		pinFlags:SetHide(not pinFlags:IsHidden());
	end
end

-- ===========================================================================
-- 输入分发（运行时门控保留 1.65 原样：条目16「禁用地图钉」勾选时四键失效）
-- ===========================================================================
local function OnInputActionTriggered(actionId : number)
	if GameConfiguration.GetValue("CPL_NO_PINS") == true then
		return
	end
	if actionId == m_ToggleVisibilityId then
		HideMapPins()
	elseif actionId == m_DeleteMapTackId then
		DeleteMapPin();
	elseif actionId == m_AddMapTackId then
		AddMapPin();
	elseif actionId == m_AddMapMessageId then
		AddMapMessage();
	end
end

-- ===========================================================================
-- Shift+Y 回声自删：自己发出的 pin 聊天消息到达即删除本地钉（聊天里只留 pin 图标）
-- ===========================================================================
local function OnMultiplayerChat(fromPlayer : number, toPlayer : number, text : string, eTargetType : number)
	if fromPlayer == Game.GetLocalPlayer() and text == g_mapPinStr then
		DeleteMapPinAtPlot(Game.GetLocalPlayer(), g_X, g_Y);
	end
end

-- ===========================================================================
-- 初始化（1.65 原样：文件加载即注册事件，控件访问全部惰性）
-- ===========================================================================
local function Initialize()
	Events.InputActionTriggered.Add(OnInputActionTriggered);
	Events.MultiplayerChat.Add(OnMultiplayerChat)
end
Initialize()
