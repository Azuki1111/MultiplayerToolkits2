-- ============================================================================
-- 条目36扩展：ESC 菜单「订阅」按钮（移植 1.67 TOM/UI/InGameTopOptionsMenu_TPT.lua 的订阅
-- 按钮单功能；TOM 的重开游戏按钮与「使用中模组」展开界面不移植）
-- ============================================================================
-- 行为（用户裁决：订阅按钮只订阅当前联机工具箱 mod）：采用 LOC_MPT_MOD_ID 反推本 mod
-- 的订阅 ID——mod GUID 文本 tag 查取 → 本房间启用列表（GetEnabledMods）中定位自己 →
-- 经 Modding.GetInstalledMods 的 [modId]=SubscriptionId 映射反查（AutoUpdate FindSelf
-- 同款 GUID 反查模式）。不再使用静态工坊 ID tag（LOC_MPT_WORKSHOP_ID 已废止）：
-- 本地开发版与工坊发布版 GUID 恒同，反推天然跟随实际发布物品。
-- 按钮语义：反推出订阅 ID 且本机未订阅才显示；点击打开本 mod 工坊页（TOM 同款，
-- 已订阅隐藏）。纯查询零副作用：不触发 Modding.UpdateSubscription（条目13 崩溃机理隔离）。
-- 引擎事实（原版取证）：本上下文无通配 include 钩子——Base 层 Lua 尾部直接自调用
-- Initialize()；装 XP1/XP2 后生效 Lua 换名为 Expansion1_InGameTopOptionsMenu.lua
-- （XP2 覆盖 XP1），生效 XML 同理逐层被 DLC Replacements 覆盖。故走 TOM 同款
-- ReplaceUIScript 整换 + 基座文件探测 include（Expansion1 → Base，命中含 Initialize
-- 定义的层即止），XML 覆盖以 XP2 生效层为底本只插一行订阅按钮。
-- 与 TOM 差异：①无 Disable_MPH criteria（外部 mod 让位门控已全废止）②不包裹
-- Close/SetupButtons（TOM 对应功能不移植）③订阅 ID 由 GUID 反推取代其静态文本 tag
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

-- 本 mod GUID（ModMeta_Data.sql 单源；tag 缺失时 Locale.Lookup 回传原名，^LOC_ 前缀识别置空）
local MPT_MOD_ID = Locale.Lookup("LOC_MPT_MOD_ID");
if MPT_MOD_ID == nil or string.find(MPT_MOD_ID, "^LOC_") ~= nil then
	print("MPT 条目36扩展：LOC_MPT_MOD_ID 文本缺失（ModMeta_Data.sql 未加载？），订阅按钮将隐藏");
	MPT_MOD_ID = "";
end

local MPT_WorkshopUrl = "http://steamcommunity.com/sharedfiles/filedetails/?id=";

-------------------------------------------------
-- MPT_CheckSubscribed
-- 查询本机是否已订阅指定创意工坊物品（TOM CheckSubscribed 同款）。
-- 用法：Initialize 内决定 SubscribeButton 显隐；订阅列表不可得时按未订阅处理（按钮保持显示）。
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
-- MPT_DeriveSelfSubscriptionId
-- 反推本 mod（LOC_MPT_MOD_ID）的订阅 ID：先在本房间启用列表定位自己，再经已安装表
-- [modId]=SubscriptionId 映射反查（AutoUpdate FindSelf 同款 GUID 反查）。
-- 返回订阅 ID；本地安装（无订阅）或未启用/未找到返回 nil（按钮届时隐藏）。
-- 纯查询零副作用：不触发 Modding.UpdateSubscription（条目13 崩溃机理隔离）。
-------------------------------------------------
local function MPT_DeriveSelfSubscriptionId()
	local installedMods = Modding.GetInstalledMods();
	if installedMods == nil then
		return nil;
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
			if curMod.Id == MPT_MOD_ID then
				return subscriptionMap[curMod.Id];
			end
		end
	end
	return nil;
end

-------------------------------------------------
-- Initialize（覆写）
-- 先执行原版基座接线（全部原版菜单按钮回调），再反推本 mod 订阅 ID 并接订阅按钮：
-- 点击打开本 mod 工坊页、悬停音效；已订阅或反推失败（本地安装）时隐藏；
-- Base-only 环境额外隐藏 XML 自带的 XP1 按钮。
-- 用法：文件尾调用一次（本上下文脚本入口语义，TOM 同款）。
-------------------------------------------------
function Initialize()
	BASE_Initialize();

	local selfSubscriptionId = MPT_DeriveSelfSubscriptionId();
	if selfSubscriptionId ~= nil then
		print("MPT 条目36扩展：本 mod 订阅 ID 反推成功 (" .. selfSubscriptionId .. ")");
	else
		print("MPT 条目36扩展：本 mod 无工坊订阅 ID（本地安装），订阅按钮隐藏");
	end

	Controls.SubscribeButton:RegisterCallback(Mouse.eLClick, function()
		if selfSubscriptionId ~= nil then
			Steam.ActivateGameOverlayToUrl(MPT_WorkshopUrl .. selfSubscriptionId);
		end
	end);
	Controls.SubscribeButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	-- 反推失败（本地安装）或已订阅 = 隐藏（TOM 同语义）
	Controls.SubscribeButton:SetHide(selfSubscriptionId == nil or MPT_CheckSubscribed(selfSubscriptionId));

	if MPT_BaseFile == "InGameTopOptionsMenu" then
		Controls.ExpansionNewFeatures:SetHide(true);	-- 无 XP1 环境：隐藏 XML 自带的原版 XP1 按钮（TOM 同款防死按钮）
	end
end
Initialize();
