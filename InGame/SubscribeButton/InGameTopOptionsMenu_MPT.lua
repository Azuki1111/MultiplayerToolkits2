-- ============================================================================
-- 条目36扩展：ESC 菜单「订阅」按钮（移植 1.67 TOM/UI/InGameTopOptionsMenu_TPT.lua 的订阅
-- 按钮单功能；TOM 的重开游戏按钮与「使用中模组」展开界面不移植）
-- ============================================================================
-- 引擎事实（原版取证）：本上下文无通配 include 钩子——Base 层 Lua 尾部直接自调用
-- Initialize()；装 XP1/XP2 后生效 Lua 换名为 Expansion1_InGameTopOptionsMenu.lua
-- （XP2 覆盖 XP1），生效 XML 同理逐层被 DLC Replacements 覆盖。故走 TOM 同款
-- ReplaceUIScript 整换 + 基座文件探测 include（Expansion1 → Base，命中含 Initialize
-- 定义的层即止），XML 覆盖以 XP2 生效层为底本只插一行订阅按钮。
-- 行为：点击经 Steam 覆盖层打开本 mod 创意工坊页面；本机已订阅则隐藏按钮
-- （Modding.GetSubscriptions，TOM 同语义——工坊安装户不可见，手动安装户可见可跳转订阅）。
-- 工坊 ID 单源 = ModMeta_Data.sql 的 LOC_MPT_WORKSHOP_ID（3795550166）。
-- 与 TOM 差异：①无 Disable_MPH criteria（外部 mod 让位门控已全废止）②不包裹
-- Close/SetupButtons（TOM 对应功能不移植）③工坊 ID 无 string.sub 剥前缀（自控 SQL
-- 不带前缀字符）④Base-only 环境隐藏 XML 自带的 ExpansionNewFeatures 死按钮（TOM 同款）。
-- 双跑说明：Base 层文件尾自带 Initialize() 自调用，include 时原版接线已执行一次；
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

-- 工坊页地址与本 mod 物品 ID（文本 tag 查取，ModMeta 单源；缺失时 tag 原名回传 → URL 无效但不崩）
local MPT_WorkshopUrl = "http://steamcommunity.com/sharedfiles/filedetails/?id=";
local MPT_WorkshopIdStr = Locale.Lookup("LOC_MPT_WORKSHOP_ID");

-------------------------------------------------
-- MPT_CheckSubscribed
-- 查询本机是否已订阅指定创意工坊物品（TOM CheckSubscribed 同款）。
-- 用法：Initialize 内决定 SubscribeButton 显隐；订阅列表不可得时按未订阅处理（按钮显示）。
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
-- 先执行原版基座接线（全部原版菜单按钮回调），再接订阅按钮：左键开工坊页、
-- 悬停音效、已订阅隐藏；Base-only 环境额外隐藏 XML 自带的 XP1 按钮。
-- 用法：文件尾调用一次（本上下文脚本入口语义，TOM 同款）。
-------------------------------------------------
function Initialize()
	BASE_Initialize();

	Controls.SubscribeButton:RegisterCallback(Mouse.eLClick, function()
		Steam.ActivateGameOverlayToUrl(MPT_WorkshopUrl .. MPT_WorkshopIdStr);
	end);
	Controls.SubscribeButton:RegisterCallback(Mouse.eMouseEnter, function()
		UI.PlaySound("Main_Menu_Mouse_Over");
	end);
	Controls.SubscribeButton:SetHide(MPT_CheckSubscribed(MPT_WorkshopIdStr));

	if MPT_BaseFile == "InGameTopOptionsMenu" then
		Controls.ExpansionNewFeatures:SetHide(true);	-- 无 XP1 环境：隐藏 XML 自带的原版 XP1 按钮（TOM 同款防死按钮）
	end
end
Initialize();
