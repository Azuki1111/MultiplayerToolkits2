-- ===========================================================================
-- 条目28：单位操作增强（移植 1.65 NHK/UI/NewUnitOperation.lua 热键部分）
--
-- 功能（动作注册见 NewHotKeys_InputActions.xml）：
--   Shift+G 晋升预清命令（ExtraHotkeysPromote）：引擎 HotkeyId 绑定执行晋升前，
--     先对选中单位下发 CANCEL 清除当前命令（移动/驻扎等占位命令会阻塞晋升），
--     间谍除外（1.65 原样排除，间谍命令不可打断）
--   Shift+W 随机晋升（HotKey_TPT_FastPromote）：取可用晋升列表随机选一项直接执行，
--     不打开晋升树；同样先清当前命令（1.65 原样）
--
-- 注入机制：AddUserInterfaces 迷你上下文（同条目12/20 机制），纯事件监听无控件。
-- 与 1.65 差异（逐条留痕）：
--   1) 零全局污染：1.65 泄漏 OnInputActionTriggered_CSA 等 6 个全局，本文件全部 local
--      （条目18 同款约定）
--   2) 【不移植】1.65 行 70-152 内嵌的反作弊搭车代码（广播镜头文本指纹/回合比对/
--      KillCheat 恶意 Modding.UpdateSubscription 死循环）——与本条目功能无关且含
--      恶意行为，整段剔除，include("PopupDialog") 亦随之删除
--   3) 【不移植】1.65 已注释停用的全体取消/全体驻扎死键位（HotKey_TPT_CancelAll/
--      FortifyAll）
-- 相对 1.65 的让位（criteria 层，modinfo 配置）：1.65 在装时本上下文不加载（其原版
--   Lua 继续服务，避免晋升预清命令双发）。
-- 注册：AddUserInterfaces(900) + ImportFiles(900)，criteria=NHK_MPT
-- ===========================================================================

local m_PromoteActionId    : number = Input.GetActionId("ExtraHotkeysPromote");
local m_FastPromoteActionId : number = Input.GetActionId("HotKey_TPT_FastPromote");

-- ===========================================================================
-- 晋升前清路：清除选中单位当前命令（间谍除外），返回是否已清（1.65 原样语义）
-- ===========================================================================
local function CancelCurrentCommand(pSelectedUnit : table)
	if pSelectedUnit ~= nil
		and UnitManager.CanStartCommand(pSelectedUnit, UnitCommandTypes.CANCEL)
		and GameInfo.Units[pSelectedUnit:GetType()].UnitType ~= "UNIT_SPY" then
		UnitManager.RequestCommand(pSelectedUnit, UnitCommandTypes.CANCEL)
		return true;
	end
	return false;
end

-- ===========================================================================
-- 输入分发（1.65 原样语义，函数名去 CSA 后缀避免与 1.65 同上下文全局撞名）
-- ===========================================================================
local function OnInputActionTriggered(actionId : number)
	-- Shift+G：晋升预清命令（晋升本身由引擎 HotkeyId 绑定执行）
	if actionId == m_PromoteActionId then
		CancelCurrentCommand(UI.GetHeadSelectedUnit());
		return
	end

	-- Shift+W：随机晋升（不开晋升树）
	if actionId == m_FastPromoteActionId then
		local pSelectedUnit : table = UI.GetHeadSelectedUnit();
		if pSelectedUnit ~= nil then
			local bCanStart, tResults = UnitManager.CanStartCommand(pSelectedUnit, UnitCommandTypes.PROMOTE, true, true);
			CancelCurrentCommand(pSelectedUnit);
			if (bCanStart and tResults) then
				if (tResults[UnitCommandResults.PROMOTIONS] ~= nil and #tResults[UnitCommandResults.PROMOTIONS] ~= 0) then
					local tPromotions : table = tResults[UnitCommandResults.PROMOTIONS];
					local item_index : number = math.random(1, #tPromotions)		-- 随机选择升级（UI 本地选择，无联机同步问题）
					local tParameters : table = {};
					tParameters[UnitCommandTypes.PARAM_PROMOTION_TYPE] = tPromotions[item_index];
					UnitManager.RequestCommand(pSelectedUnit, UnitCommandTypes.PROMOTE, tParameters);
				end
			end
		end
		return
	end
end

Events.InputActionTriggered.Add(OnInputActionTriggered)
