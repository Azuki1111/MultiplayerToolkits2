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

-- ============================================================================
-- 条目8续：投降投票结算弹窗（判负 + 判胜 + 观察者排除）
--
-- 投降投票过半通过后 Gameplay 侧写属性（MPT_SURRENDER_TEAM_<team> / 
-- MPT_SURRENDER_WIN_TEAM），引擎不会判负，需手动弹结算：
--   - 本地玩家队伍已投降 → PlayerDefeatedData 战败结算（DEFEAT_DEFAULT + 观战按钮）
--   - 本地玩家队伍是胜队（所有其他队伍都已投降）→ TeamVictoryData 胜利结算
-- 观察者（LEADER_SPECTATOR）不弹任何结算；已点击观战（条目7 m_mpt_observed）
-- 也不再弹。
--
-- 触发：QuickPanel 1 秒轮询检测到结局后经 LuaEvents.MPT_SurrenderOutcome 通知
--（标准跨 Context 机制，避免 GameCoreEventPublishComplete 高频回调）；
-- Events.LocalPlayerTurnBegin 回合边界兜底（直接查属性）。
-- 防重入：m_mpt_surrenderShown / m_mpt_surrenderWinShown 置位后不再触发。
-- EndGameMenu Context 每次进游戏会话重建，local 标志自然重置，无需显式跨房间重置。
-- ============================================================================
local m_mpt_surrenderShown :boolean = false;		-- 战败结算已弹
local m_mpt_surrenderWinShown :boolean = false;	-- 胜利结算已弹

local function MPT_IsObserver(playerID)
	if playerID == nil or playerID < 0 then
		return false;
	end
	local pCfg = PlayerConfigurations[playerID];
	if pCfg == nil then
		return false;
	end
	return pCfg:GetLeaderTypeName() == "LEADER_SPECTATOR";
end

-- ============================================================================
-- 收到 QuickPanel 的结局通知 → 弹结算
-- ============================================================================
local function MPT_OnSurrenderOutcome(outcome)
	if m_mpt_observed then
		return;	-- 已点击观战，不再弹
	end
	local localPlayer :number = Game.GetLocalPlayer();
	if localPlayer == nil or localPlayer < 0 then
		return;
	end
	if MPT_IsObserver(localPlayer) then
		-- 观察者不弹结算（吸掉标志，避免后续兜底重复检测）
		m_mpt_surrenderShown = true;
		m_mpt_surrenderWinShown = true;
		return;
	end

	if outcome == "defeat" and not m_mpt_surrenderShown then
		m_mpt_surrenderShown = true;
		m_isFadeOutGame = true;
		View(PlayerDefeatedData(localPlayer, "DEFEAT_DEFAULT"));
	elseif outcome == "win" and not m_mpt_surrenderWinShown then
		m_mpt_surrenderWinShown = true;
		m_isFadeOutGame = true;
		View(TeamVictoryData(Players[localPlayer]:GetTeam(), "VICTORY_DEFAULT"));
	end
end

-- ============================================================================
-- 回合边界兜底：直接查属性（QuickPanel 轮询万一未检测到，回合切换时补弹）
-- ============================================================================
local function MPT_CheckSurrenderOutcome()
	if m_mpt_observed then
		return;
	end
	local localPlayer :number = Game.GetLocalPlayer();
	if localPlayer == nil or localPlayer < 0 then
		return;
	end
	if MPT_IsObserver(localPlayer) then
		m_mpt_surrenderShown = true;
		m_mpt_surrenderWinShown = true;
		return;
	end
	local localTeam :number = Players[localPlayer]:GetTeam();

	-- 胜利：本队是胜队
	if not m_mpt_surrenderWinShown then
		local winTeam = Game:GetProperty("MPT_SURRENDER_WIN_TEAM");
		if winTeam ~= nil and winTeam == localTeam then
			m_mpt_surrenderWinShown = true;
			m_isFadeOutGame = true;
			View(TeamVictoryData(localTeam, "VICTORY_DEFAULT"));
			return;
		end
	end

	-- 战败：本队已投降
	if not m_mpt_surrenderShown then
		if Game:GetProperty("MPT_SURRENDER_TEAM_" .. localTeam) == 1 then
			m_mpt_surrenderShown = true;
			m_isFadeOutGame = true;
			View(PlayerDefeatedData(localPlayer, "DEFEAT_DEFAULT"));
		end
	end
end

-- 注册：QuickPanel 通知 + 回合边界兜底
LuaEvents.MPT_SurrenderOutcome.Add(MPT_OnSurrenderOutcome);
Events.LocalPlayerTurnBegin.Add(MPT_CheckSurrenderOutcome);
