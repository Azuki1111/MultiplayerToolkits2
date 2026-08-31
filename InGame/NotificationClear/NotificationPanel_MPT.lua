-- ===========================================================================
-- 条目19：清理通知按钮（NOC）——移植自联机工具箱 1.67（工坊 3693899014 NOC 目录）
-- 功能：通知栏插入一个「垃圾桶」按钮（复用原版 ItemInstance 通知条目模板），点击
--   一键清理当前全部可手动关闭的通知（不可手动关闭的保留）。
-- 注入机制：文件名前缀 NotificationPanel_ 被原版 NotificationPanel.lua 末尾通配
--   include("NotificationPanel_", true) 拉入同上下文（官方预留钩子，同条目7/18 机制），
--   可直接使用上下文全局 m_genericItemIM 实例管理器；modinfo 仅 ImportFiles 导入
--   VFS，无需 LuaContext 注册。
-- 覆写机制：链式覆写全局 OnDefaultAddNotification / ReleaseNotificationEntry
--   （原版 MakeDefaultHandlers 对 Add 的绑定是运行时延迟求值，include 时重定义全局
--   即生效；函数名必须保持原版全局名，不可 MPT 化）。
-- 按钮位置（为何无需 StackChildren/SortChildren）：通知栈 Anchor="R,B" +
--   StackGrowth="Top"——1 号子控件渲染在最底部；本按钮在首条通知实例分配之前懒创建
--   → 恒为子控件 1 号；且原版 ClearNotifications/ReleaseNotificationEntry 只释放
--   m_notifications 登记的条目、按钮实例永不释放（实例复用只影响已释放实例）→
--   整局恒居最底部，零代码保证。SortChildren 是 O(n·logn) 重排+重布局，对固定
--   位置的按钮纯属开销（InstanceManager.lua 官方注释并警告其破坏布局依赖样式），
--   仅当需要非自然位置（如置顶）时才值得使用。
-- 相对 1.67（NotificationPanel_QuickClear.lua）的优化：
--   1. 精确存活集替代环形缓冲：[playerID][notificationID]=true 集合 + 计数器，
--      Add 增 / Release 包裹删（守卫式递减）——1.67 的 100 上限回绕会静默丢最老
--      ID、已释放 ID 永久残留重查
--   2. 显隐用自维护计数（>0 显示）——1.67 直读 m_genericItemIM.m_AllocatedInstances
--      内部字段并依赖「>1 因为按钮占 1 位」魔数
--   3. 单一清理回调注册 MouseInArea 左右键——1.67 向 MouseOutArea 重复注册 4 个
--      回调（区域重叠存在同一点击双触发隐患）
--   4. 设置广播 nil 双守卫——1.67 在任何通知出现前收到设置广播时
--      NPQC_ClearButton.Top 直接崩脚（本 mod 设置面板 LoadScreenClose 即全量广播，
--      此时按钮必为 nil，守卫为必需项而非可选）
--   5. 零全局污染：BASE_* 捕获与全部工具函数为 chunk local——1.67 泄漏
--      NPQC_*/toolTip 等 6 个全局，且设置回调全局名与同上下文 NDR 补丁同名互覆
--   6. Clear 先快照 ID 再操作——Dismiss 的释放回调若同步到达，避免遍历中改表
-- 保留 1.67 语义：开关反向语义（勾选=禁用按钮，默认 0=显示）；tooltip 沿用借用
--   tag LOC_HUD_MAP_SEARCH_CLEAR_SEARCH（1.67 同款，零文本注册）
-- 设置接入：条目12 设置面板 MPT_Settings 表加行（ParameterId 沿用 1.67 原 key
--   NotificationPanel_QuickClear），面板 LoadScreenClose 的 ApplyAll 全量广播
--   自动送达初始状态，本文件无需自读存档
-- 与 1.67 同装注意：NOC/NDR/本文件三个 NotificationPanel_* 都会被通配拉入
--   （链式覆写依次生效、功能正常），但会出现双清量按钮，建议二选一启用
-- 注册：ImportFiles(1010) 通配注入不占 LuaContext（1.67 同款机制）
-- ===========================================================================

-- ===========================================================================
-- 链式捕获（chunk local，零全局污染——仅本文件回调 BASE 版本）
-- ===========================================================================
local BASE_OnDefaultAddNotification		= OnDefaultAddNotification;
local BASE_ReleaseNotificationEntry		= ReleaseNotificationEntry;

-- ===========================================================================
-- 状态（全 local——优化5）
-- ===========================================================================
local MPT_LiveIds			: table = {};	-- 存活通知集合 [playerID] = { [notificationID] = true }（优化1）
local MPT_LiveCount			: number = 0;	-- 存活通知总数（显隐判定：>0 显示——优化2）
local MPT_ClearButton		: table = nil;	-- 垃圾桶按钮实例（懒创建）
local MPT_NotificationsDisabled : boolean = false;	-- 设置开关反向语义：true=禁用按钮（1.67 同款）

-- ============================================================================
-- MPT_UpdateClearButtonVisibility()：按 开关 + 存活计数 刷新按钮显隐
-- （MPT_ClearButton nil 守卫在首行——优化4：设置面板 LoadScreenClose 广播时按钮
--   尚未懒创建，1.67 在同场景直接崩脚）
-- 用法：MPT_UpdateClearButtonVisibility()
-- ============================================================================
local function MPT_UpdateClearButtonVisibility()
	if MPT_ClearButton == nil then return; end
	MPT_ClearButton.Top:SetHide(MPT_NotificationsDisabled or MPT_LiveCount <= 0);
end

-- ============================================================================
-- MPT_ClearNotifications()：清空全部可手动关闭的通知。
--   先快照各玩家 ID 再操作（优化6：Dismiss 的释放回调若同步到达防遍历中改表），
--   不可手动关闭的通知保留（不 Dismiss）；随后整组清空存活集并隐藏按钮——
--   之后到达的释放回调因 ID 已不在集合中被守卫式跳过，计数不会负漂。
-- 用法：MPT_ClearNotifications()（按钮点击回调）
-- ============================================================================
local function MPT_ClearNotifications()
	for playerID, idSet in pairs(MPT_LiveIds) do
		local ids : table = {};
		for id in pairs(idSet) do
			table.insert(ids, id);
		end
		for _, id in ipairs(ids) do
			local pNotification = NotificationManager.Find(playerID, id);
			if pNotification ~= nil and pNotification:CanUserDismiss() then
				NotificationManager.Dismiss(pNotification:GetPlayerID(), pNotification:GetID());
			end
		end
	end
	MPT_LiveIds = {};
	MPT_LiveCount = 0;
	MPT_UpdateClearButtonVisibility();
end

-- ============================================================================
-- MPT_CreateClearButton()：懒创建垃圾桶按钮（首条通知到达时调用，必须先于 BASE
--   分配通知实例执行——保证按钮为子控件 1 号、整局恒居栈最底部，见文件头位置论证）。
--   复用原版 ItemInstance 模板：换 QueueTrash 图标，隐藏计数/翻页箭头/页点等通知专属控件。
-- 用法：MPT_CreateClearButton()（OnDefaultAddNotification 覆写内调用）
-- ============================================================================
local function MPT_CreateClearButton()
	local playerID : number = Game.GetLocalPlayer();
	if playerID < 0 then return; end	-- 观察者（条目7 观战场景）

	MPT_ClearButton = m_genericItemIM:GetInstance();
	if MPT_ClearButton == nil then return; end

	MPT_ClearButton.Icon:SetTexture("QueueTrash");
	MPT_ClearButton.Icon:SetToolTipString(Locale.Lookup("LOC_HUD_MAP_SEARCH_CLEAR_SEARCH"));

	MPT_ClearButton.CountImage:SetHide(true);
	MPT_ClearButton.TitleCount:SetHide(true);
	MPT_ClearButton.LeftArrow:SetHide(true);
	MPT_ClearButton.RightArrow:SetHide(true);
	MPT_ClearButton.PagePipStack:SetHide(true);

	-- 仅 MouseInArea 注册左右键（优化3：1.67 向 MouseOutArea 重复注册同动作回调）
	MPT_ClearButton.MouseInArea:RegisterCallback(Mouse.eLClick, MPT_ClearNotifications);
	MPT_ClearButton.MouseInArea:RegisterCallback(Mouse.eRClick, function()
		UI.PlaySound("Play_UI_Click");
		MPT_ClearNotifications();
	end);
	MPT_UpdateClearButtonVisibility();
end

-- ===========================================================================
-- OVERRIDES（链式覆写原版全局；函数名必须保持原名——原版 MakeDefaultHandlers
--   对 handler.Add 的绑定是运行时延迟求值，此处重定义全局即生效）
-- ===========================================================================

-- ============================================================================
-- OnDefaultAddNotification(pNotification)：通知条目入栈（原版全局名）。
--   先懒创建按钮（保证子控件 1 号位）→ 调 BASE 原版逻辑 → 登记存活 ID 并刷显隐。
-- ============================================================================
function OnDefaultAddNotification(pNotification : table)
	if MPT_ClearButton == nil then
		MPT_CreateClearButton();
	end

	BASE_OnDefaultAddNotification(pNotification);

	local playerID		: number = pNotification:GetPlayerID();
	local notificationID	: number = pNotification:GetID();
	if playerID == nil or notificationID == nil then return; end

	MPT_LiveIds[playerID] = MPT_LiveIds[playerID] or {};
	if not MPT_LiveIds[playerID][notificationID] then
		MPT_LiveIds[playerID][notificationID] = true;
		MPT_LiveCount = MPT_LiveCount + 1;
	end
	MPT_UpdateClearButtonVisibility();
end

-- ============================================================================
-- ReleaseNotificationEntry(playerID, notificationID, isShuttingDown)：通知条目
--   出栈/释放（原版全局名；OnLocalPlayerChanged 换人/OnShutdown 退出时原版
--   ClearNotifications 会逐条走到这里——按钮不在其清理范围，位置与生命周期不受影响）。
--   调 BASE 原版逻辑 → 守卫式从存活集移除（ID 不在集合中跳过，计数不负漂）并刷显隐。
-- ============================================================================
function ReleaseNotificationEntry(playerID : number, notificationID : number, isShuttingDown : boolean)
	BASE_ReleaseNotificationEntry(playerID, notificationID, isShuttingDown);

	local idSet = MPT_LiveIds[playerID];
	if idSet ~= nil and idSet[notificationID] then
		idSet[notificationID] = nil;
		MPT_LiveCount = MPT_LiveCount - 1;
	end
	MPT_UpdateClearButtonVisibility();
end

-- ===========================================================================
-- 设置接入：条目12 设置面板广播 LuaEvents.MPT_Settings_Toggle(ParameterId, Value)
--   （ParameterId 沿用 1.67 原 key，反向语义同 1.67：勾选=禁用按钮）。
--   匿名闭包注册（优化5：1.67 全局回调名与同上下文 NDR 补丁同名互覆）；
--   初始状态由面板 LoadScreenClose 的 ApplyAll 全量广播送达，无需自读存档。
-- ===========================================================================
LuaEvents.MPT_Settings_Toggle.Add(function(ParameterId, Value)
	if ParameterId == "NotificationPanel_QuickClear" then
		MPT_NotificationsDisabled = (Value == true or Value == 1);
		MPT_UpdateClearButtonVisibility();
	end
end);
