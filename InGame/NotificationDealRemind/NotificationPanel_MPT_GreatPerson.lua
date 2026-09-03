-- ===========================================================================
-- 条目26：他人招募伟人通知（移植工坊 mod 2459772036 Great Person Recruited
--   Notification，作者 Cptpuk / Yokuyin）——其他玩家招募伟人（伟人单位入场）时，
--   本地玩家收到一条「XX 招募了 <类别> <名字>」通知，点击跳转伟人界面（Activate
--   复用原版 OnClaimGreatPersonActivate），提示音 ALERT_NEUTRAL。
-- 注入机制：文件名前缀 NotificationPanel_ 被原版 NotificationPanel.lua 末尾通配
--   include("NotificationPanel_", true) 拉入同上下文（同条目7/18/19/26 DealRemind 机制）；
--   modinfo 仅 ImportFiles 导入 VFS，无需 LuaContext 注册。
-- 覆写机制：链式覆写全局 RegisterHandlers——原版在 LateInitialize（1854 行）才调用，
--   运行时晚于文件加载期的通配注入，包裹版必然生效（函数名必须保持原版全局名，
--   不可 MPT 化）。
-- 配套数据（原版没有，源 mod 三个 XML 自带，本条目同目录等价移植）：
--   GreatPersonRecruited_Data.xml（通知类型 NOTIFICATION_OTHER_PLAYER_RECRUITED_GREATPERSON，
--   UpdateDatabase）+ GreatPersonRecruited_Icons.xml（图标映射原版通知图集
--   ICON_ATLAS_NOTIFICATIONS[8] = CLAIM_GREAT_PERSON 同款，UpdateIcons）+ 文本两条
--   （UpdateText，tag 沿用源 mod 原名，中文为本 mod 补全）。
-- 相对源 mod 的差异：
--   1. 零全局污染：BASE 捕获/状态/工具函数全 chunk local + MPT_ 前缀
--   2. 增加开关（用户裁决，源 mod 无设置体系）：条目12 MPT_Settings 表加行
--      NotificationPanel_GreatPersonRecruited（自造 key，与 NotificationPanel_DealRemind
--      对称，默认开）——事件回调首行判断，handler 注册与事件订阅照常，开关即时生效
--   3. 未相遇玩家名判定补 nil 防御 + 观察者分支——源 mod 对 Players[GetLocalPlayer()]
--      直接取 GetDiplomacy，观察者模式（GetLocalPlayer()=-1）下踩空崩脚（本 mod 支持
--      BSM 观察者局，条目23/24 场景）；观察者按 BSM「一切可见」语义直接显示真名
--   4. 入栈即自动展开（用户裁决，条目26扩展）：通知入面板时经 handler.Add 包裹调
--      OnMouseEnterNotification 原版悬停路径（同条目26 DealRemind 展开机制），不加
--      提示音——DealRemind 的响铃不引入，保留源 mod AddSound=ALERT_NEUTRAL 到达音
-- 开关订阅：仅 MPT_Settings_Toggle 单通道（key 为本 mod 自造，1.67 面板无此参数，
--   TPT 通道无意义；不同于同条目 DealRemind 沿用 1.67 原 key 走双通道）
-- 与源 mod 同装注意：双方都会包裹 RegisterHandlers（BASE 链兼容）但 UnitAddedToMap
--   会被订阅两次 → 同一伟人招募弹双份通知（AlwaysUnique 不去重），建议二选一启用
-- 注册：ImportFiles(1010) 通配注入不占 LuaContext（同条目19/26 DealRemind 机制）
-- ===========================================================================

-- ===========================================================================
-- 链式捕获（chunk local，零全局污染——仅本文件回调 BASE 版本）
-- ===========================================================================
local BASE_RegisterHandlers	= RegisterHandlers;

-- ===========================================================================
-- 状态（全 local）
-- ===========================================================================
local MPT_OtherPlayerRecruitedGPHash : number = DB.MakeHash("NOTIFICATION_OTHER_PLAYER_RECRUITED_GREATPERSON");
local MPT_GreatPersonEnabled : boolean = true;	-- 开关（默认开；初值仅 LoadScreenClose 广播前生效）
local MPT_BASE_NotificationAdd = nil;	-- 条目26扩展：GPR handler 原 Add（首次 RegisterHandlers 捕获，幂等守卫防调试热载重复包裹）

-- ============================================================================
-- MPT_GetRecruiterName(playerID : number) : string——招募者名。
--   已相遇 → 玩家名字面量（调用方统一 Locale.Lookup）；未相遇 → 原版「一位未知玩家」
--   tag 字面量（同源 mod）；本地玩家无效（观察者 GetLocalPlayer()=-1，源 mod 在此踩空）
--   按 BSM 观察者「一切可见」语义显示真名
-- 用法：MPT_GetRecruiterName(playerID)
-- ============================================================================
local function MPT_GetRecruiterName(playerID : number)
	local localPlayerID : number = Game.GetLocalPlayer();
	if localPlayerID >= 0 then
		local localPlayer : table = Players[localPlayerID];
		if localPlayer ~= nil and not localPlayer:GetDiplomacy():HasMet(playerID) then
			return "LOC_GREAT_PEOPLE_RECRUITED_BY_UNKNOWN";
		end
	end
	return PlayerConfigurations[playerID]:GetPlayerName();
end

-- ============================================================================
-- MPT_CreateNotificationData(playerID : number, greatPersonID : number) : table——
--   构建通知数据。Message/Summary/图标 tag 沿用源 mod 原名；AlwaysUnique=true 告知
--   通知管理器同类型通知不合并（每条伟人招募独立展示，源 mod 同款）。
--   Summary 占位符 {1_recruiter}/{2_greatPersonType}/{3_greatPersonName} 保留：通知
--   Summary 由引擎排版、中文语序需要（源 mod 同款参数形态，运行时构造不适用「纯文本
--   tag + Lua 拼接」预加载规约场景）
-- 用法：MPT_CreateNotificationData(playerID, greatPersonID)
-- ============================================================================
local function MPT_CreateNotificationData(playerID : number, greatPersonID : number)
	local greatPersonDetails : table = GameInfo.GreatPersonIndividuals[greatPersonID];
	if greatPersonDetails == nil then
		return nil;
	end

	local recruitingPlayer	: string = Locale.Lookup(MPT_GetRecruiterName(playerID));
	local greatPersonName	: string = Locale.Lookup(greatPersonDetails.Name);
	local greatPersonType	: string = Locale.Lookup("LOC_" .. greatPersonDetails.GreatPersonClassType .. "_NAME");

	local notificationData : table = {};
	notificationData.Message = Locale.Lookup("LOC_NOTIFICATION_OTHER_PLAYER_RECRUITED_GREATPERSON_MESSAGE");
	notificationData.Summary = Locale.Lookup("LOC_NOTIFICATION_OTHER_PLAYER_RECRUITED_GREATPERSON_SUMMARY",
											 recruitingPlayer, greatPersonType, greatPersonName);
	notificationData.Icon = "ICON_NOTIFICATION_OTHER_PLAYER_RECRUITED_GREATPERSON";
	notificationData.AlwaysUnique = true;

	return notificationData;
end

-- ============================================================================
-- MPT_OnUnitAddedToMap(playerID : number, unitID : number)——伟人单位入场（招募）
--   事件回调。开关关闭/观察者（本地玩家 -1，无通知信箱）/本人招募/单位已消失/非伟人
--   均跳过；NotificationManager.SendNotification 为 UI 侧本地通知（不经 Gameplay 同步，
--   联机各端各自弹各自的，无需广播）
-- 用法：Events.UnitAddedToMap 订阅（MPT_Initialize 在 LoadGameViewStateDone 后挂载）
-- ============================================================================
local function MPT_OnUnitAddedToMap(playerID : number, unitID : number)
	if not MPT_GreatPersonEnabled then
		return;
	end
	local localPlayerID : number = Game.GetLocalPlayer();
	if localPlayerID < 0 or playerID == localPlayerID then
		return;
	end
	local player : table = Players[playerID];
	if player == nil then
		return;
	end
	local unit : table = player:GetUnits():FindID(unitID);
	if unit == nil then
		return;
	end
	-- 条目26修复同族预防：GetGreatPerson() 返回引擎接口对象（条目21 已证 Get* 家族
	--   撞 :table 赋值期类型检查），不加 :table 标注
	local greatPerson = unit:GetGreatPerson();
	if greatPerson ~= nil and greatPerson:IsGreatPerson() then
		-- nil 可疑返回值（greatPersonDetails 缺失时返回 nil），不加 :table 标注
		local notificationData = MPT_CreateNotificationData(playerID, greatPerson:GetIndividual());
		if notificationData ~= nil then
			NotificationManager.SendNotification(localPlayerID, MPT_OtherPlayerRecruitedGPHash, notificationData);
		end
	end
end

-- ============================================================================
-- RegisterHandlers()（原版全局名）：通知处理器注册表构建（原版 LateInitialize 运行时
--   调用，晚于本文件通配注入 → 包裹版生效）。先 BASE 注册全部原版/官方扩展/其他扩展
--   处理器，再挂本功能的通知类型：MakeDefaultHandlers 提供默认显隐/声音/失效行为，
--   Activate 复用原版 OnClaimGreatPersonActivate（点击跳转伟人界面，NotificationPanel.lua
--   1347 行，CLAIM_GREAT_PERSON 通知同款）；AddSound 沿用源 mod 的 ALERT_NEUTRAL。
--   条目26扩展（用户裁决）：Add 包裹——BASE 全包裹链（含条目19/DealRemind 覆写）创建
--   条目后查册并 OnMouseEnterNotification 自动展开（同 DealRemind 展开机制，无提示音；
--   GP 类型不触发 DealRemind 的外交类型门控故无双展开）
-- ============================================================================
function RegisterHandlers()
	BASE_RegisterHandlers();

	local kHandlers = MakeDefaultHandlers();
	g_notificationHandlers[MPT_OtherPlayerRecruitedGPHash] = kHandlers;
	kHandlers.AddSound = "ALERT_NEUTRAL";
	kHandlers.Activate = OnClaimGreatPersonActivate;

	if MPT_BASE_NotificationAdd == nil then
		MPT_BASE_NotificationAdd = kHandlers.Add;	-- 全包裹链最终版（含条目19/DealRemind 覆写）
	end
	local BASE_Add = MPT_BASE_NotificationAdd;
	kHandlers.Add = function(pNotification)
		BASE_Add(pNotification);
		-- 入栈即自动展开（条目26扩展）：发送侧已按开关门控，此处不再判
		local notificationEntry = GetNotificationEntry(pNotification:GetPlayerID(), pNotification:GetID());
		if notificationEntry ~= nil and notificationEntry.m_Instance ~= nil then
			OnMouseEnterNotification(notificationEntry.m_Instance);
		end
	end
end

-- ============================================================================
-- MPT_Initialize()：LoadGameViewStateDone 后才挂 UnitAddedToMap 订阅（源样——防读档时
--   地图上已存在的伟人单位逐个触发弹通知）
-- ============================================================================
local function MPT_Initialize()
	Events.LoadGameViewStateDone.Add(function()
		Events.UnitAddedToMap.Add(MPT_OnUnitAddedToMap);
	end);
end
MPT_Initialize();

-- ===========================================================================
-- 设置接入：条目12 设置面板广播 LuaEvents.MPT_Settings_Toggle(ParameterId, Value)
--   （ParameterId 为本 mod 自造 key NotificationPanel_GreatPersonRecruited，源 mod 无
--   设置体系无原 key 可沿用）；仅 MPT 单通道（见文件头说明）；初始状态由面板
--   LoadScreenClose 的 ApplyAll 全量广播送达，无需自读存档。
-- ===========================================================================
local function MPT_OnSettingsToggle(ParameterId, Value)
	if ParameterId == "NotificationPanel_GreatPersonRecruited" then
		MPT_GreatPersonEnabled = (Value == true or Value == 1);
	end
end
LuaEvents.MPT_Settings_Toggle.Add(MPT_OnSettingsToggle);
