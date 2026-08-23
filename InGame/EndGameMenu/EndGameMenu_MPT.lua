-- ============================================================================
-- 条目7：战败后观战按钮（移植 联机工具箱 1.67 EGM，修复反复弹出 bug）
--
-- 本文件经原版 EndGameMenu.lua 末尾的 include("EndGameMenu_", true) 通配符
-- 自动注入 EndGameMenu 上下文，可与原版脚本共享全局（Close/View/OnShow/
-- m_isFadeOutGame 等）。文件命名须以 EndGameMenu_ 前缀（VFS 通配符匹配）。
--
-- 与 1.67 原版差异（bug 修复）：
--   1.67 点击「观战」仅 SetHide 隐藏界面，未释放暂停事件（UI.SetPauseEventID
--   在 OnPlayerDefeat/OnTeamVictory 中设置）也未解除 m_isFadeOutGame /
--   m_waitingForShow，引擎的战败/胜利事件仍持续触发，导致画面反复弹出。
--   本实现点击「观战」：真正切换本地玩家为观察者（PlayerManager.SetLocalObserverTo）
--   + 完整 Close()（内含 UI.ReleasePauseEvent 释放暂停、UIManager:DequeuePopup
--   移除本弹窗、HandlePauseGame(true) 恢复游戏暂停管理），彻底解除 EndGame 状态。
--
-- 观察者按钮仅在「本局为多人、本地玩家已败亡（IsAlive=false）」时显示，
-- 幸存玩家不显示（避免误点）。
-- ============================================================================

-- ============================================================================
-- 初始化：注册观察按钮回调（原版 include 在本文件之后调用 Initialize，
-- 此处顶层执行时机在 Initialize 之前，但 LateInitialize 已在 OnInit 中调用过
-- EndGameMenu 自己的初始化；直接在此注册控件回调即可，控件树此时已就绪）
-- ============================================================================
local function MPT_OnObserveClick()
	-- 切到全局观察者（PlayerTypes.OBSERVER）
	PlayerManager.SetLocalObserverTo(PlayerTypes.OBSERVER);

	-- 完整关闭 EndGame 界面：释放暂停事件 + 移除弹窗 + 恢复暂停管理
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
