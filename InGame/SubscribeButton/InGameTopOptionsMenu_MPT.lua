-- ============================================================================
-- 条目36扩展：ESC 菜单「订阅」按钮（移植 1.67 TOM/UI/InGameTopOptionsMenu_TPT.lua 的订阅
-- 按钮单功能；TOM 的重开游戏按钮与「使用中模组」展开界面不移植）
-- ============================================================================
-- 行为改版（用户指示）：不再静态打开本 mod 工坊页，改为反推本房间启用 mod 的订阅 ID——
-- 采用 LOC_MPT_MOD_ID 同款「GUID 经已安装表反查」模式（AutoUpdate FindSelf 全量化）：
-- GameConfiguration.GetEnabledMods 条目仅含 mod GUID，须经 Modding.GetInstalledMods
-- 预建 [modId]=SubscriptionId 映射反查。仅非官方且有订阅者可派生（官方 mod 与本地
-- 无订阅 mod 天然缺席）。
-- 按钮语义：存在「未订阅」的房间启用 mod 才显示；点击打开第一个未订阅者的工坊页
-- （逐个订阅流程：订完一个，下次进局按钮自动指向下一个；Steam 覆盖层多次调用只会
-- 导航到最后一页，故每次点击只开一页）。全部已订阅或无可派生项 = 隐藏（TOM 逐 mod
-- 语义的推广）。纯查询零副作用：不触发 Modding.UpdateSubscription（条目13 崩溃机理隔离）。
-- 引擎事实（原版取证）：本上下文无通配 include 钩子——Base 层 Lua 尾部直接自调用
-- Initialize()；装 XP1/XP2 后生效 Lua 换名为 Expansion1_InGameTopOptionsMenu.lua
-- （XP2 覆盖 XP1），生效 XML 同理逐层被 DLC Replacements 覆盖。故走 TOM 同款
-- ReplaceUIScript 整换 + 基座文件探测 include（Expansion1 → Base，命中含 Initialize
-- 定义的层即止），XML 覆盖以 XP2 生效层为底本只插一行订阅按钮。
-- 与 TOM 差异：①无 Disable_MPH criteria（外部 mod 让位门控已全废止）②不包裹
-- Close/SetupButtons（TOM 对应功能不移植）③动态反推取代其静态订阅 ID 文本 tag
-- ④Base-only 环境隐藏 XML 自带的 ExpansionNewFeatures 死按钮（TOM 同款）。
-- 双跑说明：Base 层文件尾自带 Initialize() 自调用，include 时原版接线已执行过一次；
-- 下方覆写 Initialize 再跑一次 BASE_Initialize 属重复等价回调注册（引擎 RegisterCallback
-- 同名覆写语义），TOM 同款处理、线上多年验证无害。
-- ============================================================================

-- 基座探测：按 DLC 存在性从高到低 include，命中含 Initialize 定义的层即为本环境生效层
local files = {
	"Expansion1_InGameTopOptionsMenu",
	"InGameTopOptionsMenu",
}
local MPT_BaseFile = "";
for _, file in ipairs(files) do
	include(file);
	if Initialize ~= nil then
		MPT_BaseFile = file;
		break;
	end
end

BASE_Initialize = Initialize;

local MPT_WorkshopUrl = "http://steamcommunity.com/sharedfiles/filedetails/?id=";

-------------------------------------------------
-- MPT_DeriveRoomSubscriptionMods
-- 反推本房间启用 mod 的订阅 ID：启用列表逐个取 GUID → 已安装表 [modId]=SubscriptionId
-- 映射反查（AutoUpdate LOC_MPT_MOD_ID 反推同款模式，本上下文自包含实现）。
-- 返回按启用顺序的数组：{ Id=, Title=, SubscriptionId= }（仅非官方且有订阅者）。
-- 纯查询零副作用：只读数据、不触发 Modding.UpdateSubscription（条目13 崩溃机理隔离）。
-------------------------------------------------
local function MPT_DeriveRoomSubscriptionMods()
	local result = {};
	local installedMods = Modding.GetInstalledMods();
	if installedMods == nil then
		return result;
	end
	local subscriptionMap = {};
	for _, mod in ipairs(installedMods) do
		if mod.SubscriptionId ~= nil and mod.SubscriptionId ~= "" then
			subscriptionMap[mod.Id] = mod.SubscriptionId;
		end
	end
	local enabledMods = GameConfiguration.GetEnabledMods();
	if enabledMods ~= nil then
		for _, curMod in ipairs(enabledMods) do
			if not curMod.Official then
				local subscriptionId = subscriptionMap[curMod.Id];
				if subscriptionId ~= nil then
					table.insert(result, { Id = curMod.Id, Title = tostring(curMod.Title), SubscriptionId = subscriptionId });
				end
			end
		end
	end
	return result;
end

-------------------------------------------------
-- MPT_CheckSubscribed
-- 查询本机是否已订阅指定创意工坊物品（TOM CheckSubscribed 同款）。
-- 用法：判定房间启用 mod 的订阅状态；订阅列表不可得时按未订阅处理（按钮保持显示）。
-------------------------------------------------
local function MPT_CheckSubscribed(workshopId)
	local subs = Modding.GetSubscriptions();
	if subs ~= nil then
		for _, v in ipairs(subs) do
			if v == tostring(workshopId) then
				return true;
			end
		end
	end
	return false;
end

-------------------------------------------------
-- Initialize（覆写）
-- 先执行原版基座接线（全部原版菜单按钮回调），再反推房间启用 mod 订阅 ID 并接订阅
-- 按钮：点击打开第一个未订阅者的工坊页、悬停音效；无未订阅项时隐藏；
-- Base-only 环境额外隐藏 XML 自带的 XP1 按钮。
-- 用法：文件尾调用一次（本上下文脚本入口语义，TOM 同款）。
-------------------------------------------------
function Initialize()
	BASE_Initialize();

	-- 反推房间启用 mod 订阅 ID，锁定第一个未订阅者（含本 mod 自身——手动安装户点按钮
	-- 即订阅本 mod，工坊安装户已订阅自动跳过，历史静态行为为其特例）
	local roomMods = MPT_DeriveRoomSubscriptionMods();
	local unsubscribed = nil;
	for _, mod in ipairs(roomMods) do
		if not MPT_CheckSubscribed(mod.SubscriptionId) then
			unsubscribed = mod;
			break;
		end
	end
	print("MPT 条目36扩展：房间启用 mod 可派生订阅 ID 共 " .. #roomMods .. " 个，未订阅 "
		.. (unsubscribed ~= nil and ("，首个待订阅=" .. unsubscribed.Title) or "，全部已订阅"));

	Controls.SubscribeButton:RegisterCallback(Mouse.eLClick, function()
		if unsubscribed ~= nil then
			Steam.ActivateGameOverlayToUrl(MPT_WorkshopUrl .. unsubscribed.SubscriptionId);
		end
	end);
	Controls.SubscribeButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.SubscribeButton:SetHide(unsubscribed == nil);

	if MPT_BaseFile == "InGameTopOptionsMenu" then
		Controls.ExpansionNewFeatures:SetHide(true);	-- 无 XP1 环境：隐藏 XML 自带的原版 XP1 按钮（TOM 同款防死按钮）
	end
end
Initialize();
