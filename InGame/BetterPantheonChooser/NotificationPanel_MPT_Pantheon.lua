-- ===========================================================================
-- 条目32优化：万神殿信仰够通知提醒（「万神殿不排队」的提醒形态）——高级选项
--   NO_WAIT_PANTHEON 开启时，本地玩家信仰一够（无万神殿 且 余额 ≥ 实时底价）立即从
--   通知栏弹「可以创立万神殿」提醒，点击打开万神殿选择面板；替代初版的自动弹面板
--   （用户裁决废止——模仿原版 NOTIFICATION_CHOOSE_PANTHEON 的提醒形态）。
-- 注入机制：文件名前缀 NotificationPanel_ 被原版 NotificationPanel.lua 末尾通配
--   include("NotificationPanel_", true) 拉入同上下文（同条目19/26 机制）；
--   modinfo 仅 ImportFiles 导入 VFS，无需 LuaContext 注册。
-- 通知机制：自定义类型 NOTIFICATION_MPT_PANTHEON_FAITH_READY（数据表同目录
--   PantheonNotification_Data.xml，条目26 GPR 全套先例），UI 侧
--   NotificationManager.SendNotification 本地发送（不经 Gameplay 同步，联机各端
--   各自弹，无需广播）；图标直接复用原版 ICON_NOTIFICATION_CHOOSE_PANTHEON
--   （ICON_ATLAS_NOTIFICATIONS[5]，零新增图集映射）；Activate 仿原版
--   OnChoosePantheonActivate 本体 raise NotificationPanel_OpenPantheonChooser
--   （原版 Choosers/PantheonChooser.lua 已订阅 Open）；Add 包裹入栈自动展开
--   （条目26扩展同款，GetNotificationEntry 返回 hmake 引擎实例禁加 :table 标注）。
-- 提醒时机：上升沿一次性——FaithChanged + PantheonFounded 双事件重估（他人成立
--   万神殿抬高底价可能使「已够」回落为「不够」，回落后再够会再次提醒）；
--   LoadGameViewStateDone 补一次初始检查（读档时信仰已够也提醒）。
--   信仰未创立万神殿前只涨不跌、底价只升不降，实际效果 ≈ 每次攒够提醒一次，
--   与 1.65 自动弹面板的一次性语义对齐。
-- 与引擎自带通知的关系：引擎排队版 NOTIFICATION_CHOOSE_PANTHEON 轮到本地玩家时
--   照常出现（同原版，不干预不吞并），本提醒只是把「时机」提前到信仰达标瞬间。
-- 规约：原版全局函数名不可 MPT 化（RegisterHandlers 链式覆写）；本 mod 新增
--   标识符 MPT_ 前缀 + chunk local 零全局污染；开关走条目32 高级选项原 key
--   NO_WAIT_PANTHEON（GameConfiguration 运行时读取，纯本地 UI 行为不走 criteria）。
-- 注册：ImportFiles(1010) 通配注入不占 LuaContext（同条目19/26 机制）
-- ===========================================================================

-- ===========================================================================
-- 链式捕获（chunk local，零全局污染——仅本文件回调 BASE 版本）
-- ===========================================================================
local BASE_RegisterHandlers	= RegisterHandlers;

-- ===========================================================================
-- 状态与文本预加载（全 local；无参数纯文本 tag 预加载规约）
-- ===========================================================================
local MPT_PantheonFaithReadyHash : number = DB.MakeHash("NOTIFICATION_MPT_PANTHEON_FAITH_READY");
local MPT_NoWaitPantheonInUse : boolean = GameConfiguration.GetValue("NO_WAIT_PANTHEON");
local MPT_StrReadyMessage : string = Locale.Lookup("LOC_NOTIFICATION_MPT_PANTHEON_FAITH_READY_MESSAGE");
local MPT_StrReadySummary : string = Locale.Lookup("LOC_NOTIFICATION_MPT_PANTHEON_FAITH_READY_SUMMARY");
local MPT_WasFaithReady : boolean = false;		-- 上升沿跟踪：上一轮评估是否「信仰已够」
local MPT_IsGameViewReady : boolean = false;	-- LoadGameViewStateDone 前不评估（读档期事件不弹）

-- ============================================================================
-- MPT_CreateNotificationData() : table——构建通知数据。图标复用原版万神殿通知图标；
--   AlwaysUnique=true 同类型不合并（与引擎稍后排队送达的 CHOOSE_PANTHEON 通知互不
--   干扰，本提醒消失后不并入引擎通知条目）
-- 用法：MPT_EvaluatePantheonReminder 内发送前构建
-- ============================================================================
local function MPT_CreateNotificationData()
	local notificationData : table = {};
	notificationData.Message = MPT_StrReadyMessage;
	notificationData.Summary = MPT_StrReadySummary;
	notificationData.Icon = "ICON_NOTIFICATION_CHOOSE_PANTHEON";
	notificationData.AlwaysUnique = true;
	return notificationData;
end

-- ============================================================================
-- MPT_IsFaithReady() : boolean——本地玩家当前是否「可创立万神殿」：无万神殿 且
--   信仰余额 ≥ 下一座万神殿底价（实时查询，条目32修复口径——底价随他人成立万神殿
--   上涨，快照会失真）。观察者（GetLocalPlayer()=-1）/本地玩家无宗教数据返回 false
-- 用法：MPT_EvaluatePantheonReminder
-- ============================================================================
local function MPT_IsFaithReady()
	local localPlayerID : number = Game.GetLocalPlayer();
	if localPlayerID < 0 then
		return false;
	end
	local playerReligion = Players[localPlayerID]:GetReligion();
	if playerReligion == nil then
		return false;
	end
	if playerReligion:GetPantheon() >= 0 then
		return false;
	end
	return playerReligion:GetFaithBalance() >= Game.GetReligion():GetMinimumFaithNextPantheon();
end

-- ============================================================================
-- MPT_EvaluatePantheonReminder()——提醒重估（上升沿发送）：开关关闭/读档期未就绪
--   只更新沿状态不发通知；「不够→够」跨越瞬间 SendNotification 一条提醒。
-- 用法：Events.FaithChanged / Events.PantheonFounded / LoadGameViewStateDone 订阅
-- ============================================================================
local function MPT_EvaluatePantheonReminder()
	local isFaithReady : boolean = MPT_IsFaithReady();
	if MPT_NoWaitPantheonInUse and MPT_IsGameViewReady and isFaithReady and not MPT_WasFaithReady then
		NotificationManager.SendNotification(Game.GetLocalPlayer(), MPT_PantheonFaithReadyHash, MPT_CreateNotificationData());
	end
	MPT_WasFaithReady = isFaithReady;
end

-- ============================================================================
-- RegisterHandlers()（原版全局名，LateInitialize 运行时调用晚于通配注入 → 包裹版
--   生效）：先 BASE 注册全部原版/官方扩展/其他 mod 覆写处理器，再挂本功能通知类型。
--   Activate 仿原版 OnChoosePantheonActivate 本体（NotificationPanel.lua 1311 行）：
--   本地玩家则 raise NotificationPanel_OpenPantheonChooser → 万神殿面板 Open；
--   AddSound 到达音沿用条目26 的 ALERT_NEUTRAL；Add 包裹入栈自动展开（条目26扩展
--   同款：查册 + m_Instance 双 nil 守卫，防面板未就绪踩空）
-- ============================================================================
function RegisterHandlers()
	BASE_RegisterHandlers();

	local kHandlers = MakeDefaultHandlers();
	g_notificationHandlers[MPT_PantheonFaithReadyHash] = kHandlers;
	kHandlers.AddSound = "ALERT_NEUTRAL";
	kHandlers.Activate = function( notificationEntry )
		if (notificationEntry ~= nil and notificationEntry.m_PlayerID == Game.GetLocalPlayer()) then
			LuaEvents.NotificationPanel_OpenPantheonChooser();
		end
	end;

	local BASE_Add = kHandlers.Add;		-- 全包裹链最终版（含条目19/26 覆写，注册期已定型）
	kHandlers.Add = function(pNotification)
		BASE_Add(pNotification);
		local notificationEntry = GetNotificationEntry(pNotification:GetPlayerID(), pNotification:GetID());
		if notificationEntry ~= nil and notificationEntry.m_Instance ~= nil then
			OnMouseEnterNotification(notificationEntry.m_Instance);
		end
	end
end

-- ===========================================================================
-- MPT_Initialize()：事件订阅（LoadGameViewStateDone 置就绪并补初始评估；
--   FaithChanged/PantheonFounded 驱动重估。GPR 同款不挂钩 Shutdown——通配文件与
--   NotificationPanel 上下文同生命周期，二次 SetShutdown 会覆盖原版钩子故不加）
-- ===========================================================================
local function MPT_Initialize()
	Events.LoadGameViewStateDone.Add(function()
		MPT_IsGameViewReady = true;
		MPT_EvaluatePantheonReminder();
	end);
	Events.FaithChanged.Add(MPT_EvaluatePantheonReminder);
	Events.PantheonFounded.Add(MPT_EvaluatePantheonReminder);
end
MPT_Initialize();
