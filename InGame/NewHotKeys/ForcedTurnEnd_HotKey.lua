-- ===========================================================================
-- 条目28：强制结束回合热键（从 1.65 NHK/UI/TurnTime_HotKey.lua 拆出强制结束回合段；
-- 条目20 已移植其 ]/[ 加减时与 P++/P-- 按钮，本文件只承载 Shift+F 自动强制结束模式）
--
-- 功能：Shift+F 切换自动强制结束模式（多人局有效，1.65 原样门控 IsAnyMultiplayer）：
--   开启 → 立即 ACTION_ENDTURN(REASON="UserForced") 强制结束当前回合，屏幕四角压黑提示；
--   之后每次本地回合开始若模式仍开则高频重复强制结束（GameCoreEventPublishComplete
--   tick 计数节流），直到再按 Shift+F 关闭（ACTION_UNREADYTURN 取消结束状态）；
--   回合开始 5 tick 内被系统自动取消结束状态的（如未完成行动被打回），自动重试一次。
--   同时订阅 LuaEvents.ForcedEndTurn——条目12 FEB 按钮（ForcedEndButton.lua）右键
--   预留触发点由此对接（1.65 同一通道）。
--
-- 注入机制：AddUserInterfaces 迷你上下文（同条目12/20 机制），AlphaIn 控件
--   LateInitialize 时 ChangeParent 挂到 /InGame/WorldInput。
-- 与 1.65 差异（逐条留痕）：
--   1) 零全局污染：1.65 泄漏 OnTick/OnForcedEndTurn 等 10 余个全局，本文件全部 local
--      （条目18 同款约定）
--   2) AlphaIn 挂载加 m_attached 幂等守卫（项目条目5/12 同款惯例）
--   3) 删除 1.65 全部调试 print（每回合刷 Lua.log）
--   4) 【不移植】1.65 同文件的 ]/[ 加减时热键、P++/P-- 按钮与 TOOLS_COMMAND 门控
--      （条目20 SmartTurnTimer 已按 MPT 规范承载）
-- 注册：AddUserInterfaces(900) + ImportFiles(900)，无 criteria（条目10/28调整：不再考虑
--   与 1.65 兼容，原 Disable_TPT 让位门控废止；不受「更多快捷键」开关影响）
-- ===========================================================================

local m_ForcedTurnEndActionId : number = Input.GetActionId("HotKey_TPT_ForcedTurnEnd");

local CanForcedTurnEnd : boolean = false		-- 自动强制结束模式开关
local NeedUnReadyTurn  : boolean = false		-- 回合结束后是否需要高频取消结束状态（1.65 同款）
local IsMultiplayer    : boolean = GameConfiguration.IsAnyMultiplayer();
local m_attached       : boolean = false;		-- AlphaIn 挂载守卫（条目5/12 同款惯例）

local g_Tick          : number = 0			-- 发布周期滴答计数（GameCoreEventPublishComplete 驱动）
local g_ForcedEndTick : number = -1000		-- 最近一次强制结束的 tick（回合开始重试判定用）

-- ===========================================================================
-- 滴答驱动：每个发布周期 +1（1.65 同款轻量计数器）
-- ===========================================================================
local function OnTick()
	g_Tick = g_Tick + 1
end

-- ===========================================================================
-- 黑边提示显隐（AlphaIn 挂在 /InGame/WorldInput 上层）
-- ===========================================================================
local function OnShow()
	Controls.AlphaIn:SetHide(false);
	if not ContextPtr:IsHidden() then
		EffectsManager:PauseAllEffects();
		Controls.AlphaIn:SetToBeginning();
		Controls.AlphaIn:Play();
	end
end

local function Close()
	Controls.AlphaIn:SetHide(true);		-- 隐藏动画
end

-- ===========================================================================
-- 强制结束一次回合并标记需要取消结束状态（高频重试与模式内每回合重复共用）
-- ===========================================================================
local function OnForcedEnd()
	UI.RequestAction(ActionTypes.ACTION_ENDTURN, { REASON = "UserForced" });	-- 强制结束回合
	NeedUnReadyTurn = true		-- 玩家回合结束时，会要求取消结束状态
	g_ForcedEndTick = g_Tick
end

-- ===========================================================================
-- 高频取消结束状态（回合结束后把打回来的结束标记取消掉，进入下一回合准备）
-- ===========================================================================
local function OnUnReadyTurn()
	UI.RequestAction(ActionTypes.ACTION_UNREADYTURN)
end

-- ===========================================================================
-- 模式开关核心（Shift+F 与 FEB 右键事件共用）：开=立即结束+黑边+记录 tick；关=黑边
-- 收起+取消结束状态+退订高频订阅
-- ===========================================================================
local function ToggleForcedTurnEnd()
	CanForcedTurnEnd = not CanForcedTurnEnd
	UI.PlaySound("Play_UI_Click");
	if CanForcedTurnEnd then
		OnShow()
		UI.RequestAction(ActionTypes.ACTION_ENDTURN, { REASON = "UserForced" });	-- 强制结束回合
		g_ForcedEndTick = g_Tick
	else
		Close()
		UI.RequestAction(ActionTypes.ACTION_UNREADYTURN)		-- 取消结束回合
		Events.GameCoreEventPublishComplete.Remove(OnUnReadyTurn)
		Events.GameCoreEventPublishComplete.Remove(OnForcedEnd)
	end
end

-- ===========================================================================
-- 输入分发：Shift+F 切换自动强制结束模式（多人局有效，1.65 原样门控）
-- ===========================================================================
local function OnInputActionTriggered(actionId : number)
	if actionId == m_ForcedTurnEndActionId then
		if IsMultiplayer then
			ToggleForcedTurnEnd()
		end
		return
	end
end

-- ===========================================================================
-- 条目12 FEB 右键预留点对接（ForcedEndButton.lua 右键触发 LuaEvents.ForcedEndTurn；
-- 1.65 同一通道，事件带参无，多人局门控在 ToggleForcedTurnEnd 外层保持 1.65 原样）
-- ===========================================================================
local function OnForcedEndTurn()
	if IsMultiplayer then
		ToggleForcedTurnEnd()
	end
end

-- ===========================================================================
-- 本地回合开始：收黑边；回合开始 5 tick 内被系统自动取消结束状态的再次尝试强制结束；
-- 模式仍开则启动高频强制结束；每回合开始重置模式开关（1.65 原样语义）
-- ===========================================================================
local function OnLocalPlayerTurnBegin()
	Close()		-- 关闭黑边提示
	Events.GameCoreEventPublishComplete.Remove(OnUnReadyTurn)		-- 取消高频开始回合操作
	NeedUnReadyTurn = false

	if g_ForcedEndTick + 5 > g_Tick then		-- 系统自定取消结束回合了？再次尝试
		g_ForcedEndTick = -1000
		NeedUnReadyTurn = true
		UI.RequestAction(ActionTypes.ACTION_ENDTURN, { REASON = "UserForced" });
	end

	if CanForcedTurnEnd then		-- 回合开始时开始高频强制结束回合
		OnForcedEnd()
		Events.GameCoreEventPublishComplete.Add(OnForcedEnd)
	end
	CanForcedTurnEnd = false
end

-- ===========================================================================
-- 本地回合结束：退订高频强制结束；若需要则启动高频取消结束状态（1.65 原样语义）
-- ===========================================================================
local function OnLocalPlayerTurnEnd()
	Events.GameCoreEventPublishComplete.Remove(OnForcedEnd)
	if NeedUnReadyTurn == true then		-- 需要开始回合？
		Events.GameCoreEventPublishComplete.Add(OnUnReadyTurn)		-- 高频开始回合
	end
	NeedUnReadyTurn = false
end

-- ===========================================================================
-- 每回合末兜底退订（1.65 OnTurnEnd 原样：防模式中途关闭后订阅残留）
-- ===========================================================================
local function OnTurnEnd()
	Events.GameCoreEventPublishComplete.Remove(OnUnReadyTurn)
	Events.GameCoreEventPublishComplete.Remove(OnForcedEnd)
end

-- ===========================================================================
-- 初始化：LoadScreenClose 后挂载黑边控件并注册全部事件（WorldInput 此时已就绪）
-- ===========================================================================
local function Initialize()
	local ctr = ContextPtr:LookUpControl("/InGame/WorldInput")
	if ctr ~= nil then
		Controls.AlphaIn:ChangeParent(ctr)
		m_attached = true;
	end

	Events.InputActionTriggered.Add(OnInputActionTriggered)
	Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnBegin);
	Events.LocalPlayerTurnEnd.Add(OnLocalPlayerTurnEnd);
	Events.TurnEnd.Add(OnTurnEnd);
	Events.GameCoreEventPublishComplete.Add(OnTick)

	LuaEvents.ForcedEndTurn.Add(OnForcedEndTurn)
end
Events.LoadScreenClose.Add(Initialize)
