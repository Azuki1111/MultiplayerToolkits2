-- ============================================================================
-- 条目5：显示地图角落（移植 1.67 RMC）——实验：单独控制两个 pin 实例并设置偏移
-- 目的：验证能否定位 MapPinManager 创建的两个极地 pin 的 UI 实例（GetMapPinFlag），
--       并单独对序号最小（首格）的 pin 的 FlagRoot 子容器设置向上偏移。
-- 原理：GetMapPinFlag(playerID, pinID) 是 MapPinManager 的全局函数，返回实例对象；
--       实例 m_Instance.FlagRoot 是 WorldAnchor(Anchor) 的直接子容器（屏幕空间），
--       SetOffsetVal 以屏幕像素偏移，负 Y = 向上。
-- 注意：MapPinManager 在 PlayerInfoChanged/Refresh 时会 ResetInstances 重建 flag，
--       子控件 offset 会丢失——本实验仅验证「能单独控制并偏移」，持久化方案看结果再定。
-- 用法：本文件经 AddUserInterfaces 注册的空 Context 自动执行，无外部接口。
-- 调试：保留 print 日志供实验观测，定稿后按需移除。
-- ============================================================================
print( "[MPT_RMC] RevealMapCorners.lua 顶层执行（实验版：单独控制 pin 实例）" );

-- 幂等守卫：进游戏只打一次钉（Lua 状态跨房间存续，防止反复创建）
local m_anchored : boolean = false;
-- 偏移只应用一次
local m_offsetDone : boolean = false;
-- 轮询兜底：等 MapPinManager 建好 flag（pin 创建后 PlayerInfoChanged 触发 Refresh 才建）
local m_retryCount : number = 0;
local MAX_RETRY : number = 120;
local UP_OFFSET_PX : number = 30;   -- 向上偏移像素

-- ============================================================================
-- 按坐标查找 pin 的 UI flag 实例（MapPinManager 全局函数）
-- RETURNS: flag 实例（若 flag 已创建），否则 nil
function FindPinFlag( hexX : number, hexY : number )
	local playerID : number = Game.GetLocalPlayer();
	if playerID < 0 then return nil; end
	local playerCfg : table = PlayerConfigurations[playerID];
	if playerCfg == nil then return nil; end
	for id, pin in pairs( playerCfg:GetMapPins() ) do
		if pin:GetHexX() == hexX and pin:GetHexY() == hexY then
			return GetMapPinFlag( playerID, id ), id;
		end
	end
	return nil, nil;
end

-- ============================================================================
-- 打印两个 pin 的状态（验证可单独定位）
function DumpPinState( plotFirst : table, plotLast : table )
	local flag1, id1 = FindPinFlag( plotFirst:GetX(), plotFirst:GetY() );
	local flag2, id2 = FindPinFlag( plotLast:GetX(), plotLast:GetY() );
	print( "[MPT_RMC] 首格 pin id=" .. tostring(id1) .. " flag=" .. tostring(flag1) );
	print( "[MPT_RMC] 末格 pin id=" .. tostring(id2) .. " flag=" .. tostring(flag2) );
end

-- ============================================================================
-- 对首格 pin 的 FlagRoot 向上偏移
-- RETURNS: 成功 true / 失败 false（flag 未创建或控件缺失）
function OffsetFirstPin()
	local plotFirst : table = Map.GetPlotByIndex( 0 );
	local flag, pinID = FindPinFlag( plotFirst:GetX(), plotFirst:GetY() );
	if flag == nil or flag.m_Instance == nil then
		print( "[MPT_RMC] 首格 pin flag 尚未创建（重试 " .. m_retryCount .. "）" );
		return false;
	end
	local root : table = flag.m_Instance.FlagRoot;
	if root == nil then
		print( "[MPT_RMC] 【异常】首格 pin 实例无 FlagRoot 控件" );
		return false;
	end
	local ox, oy = root:GetOffsetVal();
	root:SetOffsetVal( ox, oy - UP_OFFSET_PX );   -- 屏幕坐标负 Y = 向上
	print( "[MPT_RMC] 已对首格 pin (id=" .. tostring(pinID) .. ") FlagRoot 向上偏移 " .. UP_OFFSET_PX .. "px（原 offset=" .. tostring(ox) .. "," .. tostring(oy) .. "）" );
	m_offsetDone = true;
	return true;
end

-- ============================================================================
-- PlayerInfoChanged 触发（MapPinManager 刷新建 flag 的时机）：尝试应用偏移
function OnPlayerInfoChanged()
	Events.PlayerInfoChanged.Remove( OnPlayerInfoChanged );
	print( "[MPT_RMC] PlayerInfoChanged 触发，尝试偏移首格 pin" );
	if not OffsetFirstPin() then
		Events.UIIdle.Add( OnUIIdleRetry );   -- 兜底轮询
	end
end

-- ============================================================================
-- 每帧轮询兜底：等 flag 建好后应用偏移
function OnUIIdleRetry()
	if m_offsetDone then
		Events.UIIdle.Remove( OnUIIdleRetry );
		return;
	end
	m_retryCount = m_retryCount + 1;
	if m_retryCount > MAX_RETRY then
		print( "[MPT_RMC] 轮询 " .. MAX_RETRY .. " 帧仍未找到首格 pin flag，放弃" );
		Events.UIIdle.Remove( OnUIIdleRetry );
		return;
	end
	if OffsetFirstPin() then
		Events.UIIdle.Remove( OnUIIdleRetry );
	end
end

-- ============================================================================
-- 进游戏读盘完成：创建两极 pin，弹掉编辑弹窗，随后尝试定位并偏移首格
function OnLoadScreenClose()
	if m_anchored then return; end
	m_anchored = true;
	local plotFirst : table = Map.GetPlotByIndex( 0 );
	local plotLast  : table = Map.GetPlotByIndex( Map.GetPlotCount() - 1 );
	if plotFirst ~= nil and plotLast ~= nil then
		-- RequestMapPin 内部 GetMapPin(x,y) 为 create-or-get，创建 pin 数据（引擎层）
		LuaEvents.MapPinPopup_RequestMapPin( plotFirst:GetX(), plotFirst:GetY() );
		LuaEvents.MapPinPopup_RequestMapPin( plotLast:GetX(), plotLast:GetY() );
		-- 立即弹掉地图钉编辑弹窗（原版 RMC 手法）
		local popup : table = ContextPtr:LookUpControl( "/InGame/MapPinPopup" );
		if popup ~= nil then
			UIManager:DequeuePopup( popup );
		end
		print( "[MPT_RMC] 两个 pin 已创建，注册 PlayerInfoChanged 等待 flag 实例" );
		DumpPinState( plotFirst, plotLast );   -- 此时 flag 多半还没建
		Events.PlayerInfoChanged.Remove( OnPlayerInfoChanged );
		Events.PlayerInfoChanged.Add( OnPlayerInfoChanged );
	end
end
Events.LoadScreenClose.Add( OnLoadScreenClose );
