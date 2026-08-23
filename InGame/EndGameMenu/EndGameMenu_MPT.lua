-- ============================================================================
-- 条目7：战败后观战按钮（移植 联机工具箱 1.67 EGM，修复反复弹出 bug）
--
-- 本文件经原版 EndGameMenu.lua 末尾的 include("EndGameMenu_", true) 通配符
-- 自动注入 EndGameMenu 上下文，可与原版脚本共享全局（Close/View/OnShow/
-- m_isFadeOutGame 等）。文件命名须以 EndGameMenu_ 前缀（VFS 通配符匹配）。
--
-- 与 1.67 原版差异（bug 修复）：
--   1.67 点击「观战」仅 SetHide 隐藏界面，隐藏后 ContextPtr:IsHidden() 变回
--   true 且 m_waitingForShow=false，原版 OnPlayerDefeat 的防重入守卫
--   (IsHidden==false or m_waitingForShow) 失效，战败事件再次触发时重新走
--   View() -> QueuePopup，画面反复弹出；且暂停事件（UI.SetPauseEventID）
--   一直未释放，游戏保持暂停卡死。
--   本实现点击「观战」：置本地屏蔽标志 -> 调原版 Close()（内含
--   UI.ReleasePauseEvent 释放暂停、UIManager:DequeuePopup 移除本弹窗、
--   HandlePauseGame(true) 恢复暂停管理），并替换 OnPlayerDefeat 使其在
--   屏蔽后不再弹界面，彻底解决反复弹出。
--
-- 观察按钮仅在「本局为多人、本地玩家已败亡（IsAlive=false）」时显示，
-- 幸存玩家不显示（避免误点）。
-- ============================================================================

-- 本地屏蔽标志：点击「观战」后置位，永久拦截后续战败事件弹窗
local m_mpt_observed :boolean = false;

-- ============================================================================
-- 观察按钮点击：彻底关闭战败界面且不再弹出
-- ============================================================================
local function MPT_OnObserveClick()
	-- 屏蔽后续战败弹窗（必须先于 Close，防止 Close 触发的状态变化被重入）
	m_mpt_observed = true;

	-- 完整关闭 EndGame 界面：DequeuePopup 移除弹窗 + 释放暂停事件 + 恢复暂停管理
	Close();

	-- 清残留状态：m_isFadeOutGame 置 false 防止 OnShow 走淡出分支、
	-- m_waitingForShow 置 false 防止 View() 再排弹窗
	m_isFadeOutGame = false;
	m_waitingForShow = false;
end

local function MPT_OnObserveEnter()
	UI.PlaySound("Main_Menu_Mouse_Over");
end

-- 注册按钮回调；按钮在覆盖版 EndGameMenu.xml 的 ButtonStack 中新增
local ObserveButton = Controls.ObserveButton;
if ObserveButton then
	ObserveButton:RegisterCallback(Mouse.eLClick, MPT_OnObserveClick);
	ObserveButton:RegisterCallback(Mouse.eMouseEnter, MPT_OnObserveEnter);
	ObserveButton:SetHide(true);	-- 初始隐藏，按存活状态在 UpdateButtonStates 中显隐
end

-- ============================================================================
-- 钩住 UpdateButtonStates：根据本地玩家是否败亡显隐观察按钮。
-- 原版 UpdateButtonStates(data) 是全局函数，替换引用即可（1.67/Exp 补丁同款手法）。
-- ============================================================================
local MPT_BASE_UpdateButtonStates = UpdateButtonStates;

function UpdateButtonStates(data)
	MPT_BASE_UpdateButtonStates(data);

	if ObserveButton then
		local bShowObserve :boolean = false;
		if GameConfiguration.IsAnyMultiplayer() then
			local localPlayer :number = Game.GetLocalPlayer();
			local pLocalPlayer :table = Players[localPlayer];
			-- 仅败亡玩家可见观战按钮（观察者模式下亦无意义）
			if pLocalPlayer and not pLocalPlayer:IsAlive() then
				bShowObserve = true;
			end
		end
		ObserveButton:SetHide(not bShowObserve);
		Controls.ButtonStack:CalculateSize();
	end
end

-- ============================================================================
-- 钩住 OnPlayerDefeat：点击「观战」后不再弹战败界面。
-- 原版在 Initialize() 中 Events.PlayerDefeat.Add(OnPlayerDefeat)，Add 时取值，
-- 本文件在 Initialize() 之前执行，替换全局函数名即可让原版注册到新函数。
-- ============================================================================
local MPT_BASE_OnPlayerDefeat = OnPlayerDefeat;

function OnPlayerDefeat(player, defeat, eventID)
	if m_mpt_observed then
		-- 已点击「观战」，忽略后续战败事件，避免界面反复弹出
		return;
	end
	MPT_BASE_OnPlayerDefeat(player, defeat, eventID);
end
