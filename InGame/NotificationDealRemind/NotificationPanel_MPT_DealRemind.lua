-- ===========================================================================
-- 条目26：交易提醒（NDR = Notification Deal Remind，移植联机工具箱 1.67 NDR 目录）
-- 功能：收到外交类通知（NOTIFICATION_DIPLOMACY_SESSION，含交易/使团/联盟/和平/开边等，
--   见 MPT_PassTextSet 九种 Message）时，通知条目自动展开（OnMouseEnterNotification
--   原版悬停路径，直接露出「前往/接受」操作钮）；命中九种请求文本时另播提示音
--   Play_MP_Game_Waiting_For_Player（3 秒冷却防连响）。
-- 注入机制：文件名前缀 NotificationPanel_ 被原版 NotificationPanel.lua 末尾通配
--   include("NotificationPanel_", true) 拉入同上下文（官方预留钩子，同条目7/18/19 机制）；
--   modinfo 仅 ImportFiles 导入 VFS，无需 LuaContext 注册。
-- 覆写机制：链式覆写全局 OnDefaultAddNotification（原版 MakeDefaultHandlers 对 Add 的
--   绑定是运行时延迟求值，include 时重定义全局即生效；函数名必须保持原版全局名，
--   不可 MPT 化）。与条目19 NotificationPanel_MPT.lua 共存：双方 chunk local 各自捕获
--   加载当时的全局值再重定义，加载先后无论次序包裹链都能串起（BASE 捕获模式天然兼容）。
-- 相对 1.67（NDR/NotificationPanel_DealRemind.lua）的差异：
--   1. 零全局污染：BASE 捕获/状态/工具函数全 chunk local + MPT_ 前缀——1.67 泄漏
--      TPT_BASE_OnDefaultAddNotification/CheckPassText/Cooldown/g_CoolDownTime 四个全局
--   2. 匹配文本预加载为查集合（规约：文本预加载缓存）——1.67 每条通知到达时对 9 个
--      tag 逐个 Locale.Lookup 线性比对（CheckPassText pairs 遍历）
--   3. 冷却时钟 os.time()（墙钟，联机挂机/跨日失真）→ UI.GetElapsedTime()（单调）——
--      条目18/20 同款修正
--   4. GetNotificationEntry 查册 nil 守卫——1.67 原样 notificationEntry.m_Instance 在
--      面板未收下该通知（原版 OnDefaultAddNotification 提前返回分支）时直接踩空崩脚
--      （条目19 修复④同款场景，本 mod 实证存在该路径）
--   5. 设置订阅改 local 回调 MPT_Settings_Toggle 单通道（条目25规范同款裁决：开关以本
--      mod 条目12 面板为准，不订阅 TPT_Settings_Toggle 通道）——1.67 的具名全局回调
--      OnTPT_Settings_Toggle 与同上下文 NOC 补丁同名互覆（条目19 头注释警告），本文件
--      绝不再用该全局名
-- 开关：条目12 设置面板 MPT_Settings 表加行（ParameterId 沿用 1.67 原 key
--   NotificationPanel_DealRemind，默认开），面板 LoadScreenClose 的 ApplyAll 全量广播
--   自动送达初始状态，本文件无需自读存档
-- 与 1.67 同装注意：其 NDR 文件与本文件都会被通配拉入（包裹链兼容、功能正常），但
--   交易提醒双响 + 双开关入口，建议二选一启用（同条目19 NOC 的共存立场）
-- 条目26修复：交易提醒完全不生效（Lua.log 实证每次通知到达 Type check failed）——移植时
--   给 notificationEntry 补的 :table 标注被引擎赋值期类型检查拒绝：GetNotificationEntry
--   返回 hmake 'NotificationType' 引擎实例而非纯 Lua 表，包裹在查册处中断，自动展开与
--   提示音永不执行（vanilla 逻辑在 BASE 内已先执行故通知显示正常）；去标注修复——同
--   条目21「引擎对象去 :table 标注」同族坑 hmake 实例类（1.67 原样此处无标注；教训：
--   移植补标注仅限 number/string/boolean 与有原版先例的 userdata 返回值）；附带
--   m_Instance nil 守卫（原版 754 行三分支：分组非首个/回合阻塞/图标不可显示时
--   entry 有册无 UI 实例，1.67 原样传 nil 给 OnMouseEnterNotification 同样撞类型检查）
-- 条目26规范（用户裁决）：删 TPT_Settings_Toggle 双通道订阅行，单通道 MPT_Settings_Toggle
--   （同条目25规范「2 行订阅不规范」裁决，1.67 面板 DealRemind 开关不再联动属预期）
-- 注册：ImportFiles(1010) 通配注入不占 LuaContext（1.67 同款机制）
-- ===========================================================================

-- ===========================================================================
-- 链式捕获（chunk local，零全局污染——仅本文件回调 BASE 版本）
-- ===========================================================================
local BASE_OnDefaultAddNotification	= OnDefaultAddNotification;

-- ===========================================================================
-- 状态（全 local）
-- ===========================================================================
local MPT_DealRemindSound	: boolean = true;	-- 提示音开关（1.67 原默认开；初值仅 LoadScreenClose 广播前生效）
local MPT_NextSoundTime		: number = 0;		-- 下次允许提示音的时刻（UI.GetElapsedTime 秒，单调时钟）

-- 外交类通知 Message 查集合：通知 Message 经 Locale.Lookup 还原后与集合比对命中
-- （O(1) 比对，替代 1.67 每条通知 9 次 Locale.Lookup 线性扫描；懒构建——首次通知到达
--   时构建一次复用，兼防文件加载期文本库未就绪把原文 tag 当键值的静默失配）
local MPT_PassTextSet = nil;
local function MPT_BuildPassTextSet()
	MPT_PassTextSet = {
		[Locale.Lookup("LOC_DIPLOMACY_MAKE_DEAL_NOTIFICATION_MESSAGE_PROPOSED")]		= true;	-- 提出交易
		[Locale.Lookup("LOC_DIPLOMACY_MAKE_DEAL_NOTIFICATION_MESSAGE_INITIAL")]			= true;	-- 交易请求
		[Locale.Lookup("LOC_DIPLOMACY_SEND_DELEGATION_NOTIFICATION_MESSAGE_INITIAL")]	= true;	-- 外交团
		[Locale.Lookup("LOC_DIPLOMACY_EMBASSY_NOTIFICATION_MESSAGE_INITIAL")]			= true;	-- 大使馆请求
		[Locale.Lookup("LOC_DIPLOMACY_MAKE_ALLIANCE_NOTIFICATION_MESSAGE_INITIAL")]		= true;	-- 联盟请求
		[Locale.Lookup("LOC_DIPLOMACY_DECLARE_FRIEND_NOTIFICATION_MESSAGE_INITIAL")]	= true;	-- 友好宣言请求
		[Locale.Lookup("LOC_DIPLOMACY_MAKE_PEACE_NOTIFICATION_MESSAGE_INITIAL")]		= true;	-- 和平请求
		[Locale.Lookup("LOC_DIPLOMACY_OPEN_BORDERS_NOTIFICATION_MESSAGE_INITIAL")]		= true;	-- 开放边界请求
		[Locale.Lookup("LOC_DIPLOMACY_MAKE_DEAL_NOTIFICATION_MESSAGE_ADJUSTED")]		= true;	-- 调整交易
	};
end

-- ============================================================================
-- OnDefaultAddNotification(pNotification)（原版全局名）：通知条目入栈。
--   调 BASE 原版逻辑（含条目19 等同上下文包裹）→ 外交通知（NOTIFICATION_DIPLOMACY_SESSION）
--   自动展开（OnMouseEnterNotification 原版悬停路径，露出操作钮；1.67 语义：展开不受
--   开关控制，仅提示音受控）→ 命中九种请求文本时播放提示音（3 秒冷却防连响）。
--   查册 nil 守卫：面板未收下该通知（BASE 提前返回分支）时 GetNotificationEntry 为
--   nil（条目19 修复④同款场景）；条目存在但无 UI 实例（原版 754 行三分支）时
--   m_Instance 为 nil——1.67 原样两种情况都会崩，此处均静默跳过
-- ============================================================================
function OnDefaultAddNotification(pNotification : table)
	BASE_OnDefaultAddNotification(pNotification);

	if pNotification:GetTypeName() ~= "NOTIFICATION_DIPLOMACY_SESSION" then
		return;
	end

	local playerID			: number = pNotification:GetPlayerID();
	local notificationID	: number = pNotification:GetID();
	-- 条目26修复：此处不得加 :table 标注——GetNotificationEntry 返回 hmake
	--   'NotificationType' 引擎实例，赋值期类型检查直接拒绝致本包裹中断（1.67 原样无标注）
	local notificationEntry = GetNotificationEntry(playerID, notificationID);
	if notificationEntry == nil or notificationEntry.m_Instance == nil then
		return;	-- 面板未收下（BASE 提前返回）或条目有册无 UI 实例（原版 754 行门槛）均无展开对象
	end
	OnMouseEnterNotification(notificationEntry.m_Instance);

	if not MPT_DealRemindSound then
		return;
	end
	if MPT_PassTextSet == nil then
		MPT_BuildPassTextSet();	-- 懒构建（首次通知到达时）
	end
	local sMessage = Locale.Lookup(pNotification:GetMessage());
	if MPT_PassTextSet[sMessage] then
		local now : number = UI.GetElapsedTime();
		if now >= MPT_NextSoundTime then
			MPT_NextSoundTime = now + 3;
			UI.PlaySound("Play_MP_Game_Waiting_For_Player");
		end
	end
end

-- ===========================================================================
-- 设置接入：条目12 设置面板广播 LuaEvents.MPT_Settings_Toggle(ParameterId, Value)
--   （ParameterId 沿用 1.67 原 key NotificationPanel_DealRemind）；单通道订阅（条目26
--   规范用户裁决删 TPT_Settings_Toggle 通道行，同条目25规范）。local 回调注册（不占
--   全局名——1.67 具名全局回调 OnTPT_Settings_Toggle 与同上下文 NOC 补丁同名互覆，
--   条目19 头注释警告，本文件规避）；初始状态由面板 LoadScreenClose 的 ApplyAll 全量
--   广播送达，无需自读存档。
-- ===========================================================================
local function MPT_OnSettingsToggle(ParameterId, Value)
	if ParameterId == "NotificationPanel_DealRemind" then
		MPT_DealRemindSound = (Value == true or Value == 1);
	end
end
LuaEvents.MPT_Settings_Toggle.Add(MPT_OnSettingsToggle);
