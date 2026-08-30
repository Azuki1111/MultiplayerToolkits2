-- ============================================================================
-- 条目13：游戏内自动更新（移植 1.67 Update/UI/AutoUpdate.lua 纯逻辑部分，变量名 TPT→MPT 优化）
-- ============================================================================
-- 用法：空 Context 同名 Lua 自动执行（AddUserInterfaces Context=InGame），进游戏即触发一次；
--      退出到主菜单（Events.ExitToMainMenu）时再触发本 mod 更新检查。
--   1) MPT_AutoUpdate_UpdateAll()  进游戏时对本局已启用的非官方创意工坊 mod 触发工坊更新检查
--      （复用条目4.7 优化：单次遍历建 [modId]=SubscriptionId 映射 + nil 防御 + 非官方过滤 +
--      日志留痕，替代 1.67 O(n²) 双重循环）；
--   2) MPT_AutoUpdate_EnableSelf() 确保本 mod 已启用（按 MPT_MOD_ID 匹配 Handle；本地 mod 无
--      订阅 ID，1.67 按 SubscriptionId 匹配的 EnableMods 不适用）；
--   3) MPT_AutoUpdate_UpdateSelf() 退出到主菜单时触发本 mod 工坊更新（按 MPT_MOD_ID 匹配安装
--      列表取工坊订阅 ID，本 mod 发布到创意工坊后自动生效，无需改代码；无订阅 ID 则跳过）。
-- 不移植：更新内容 Tooltip 展示（Get_TPT_Update_Text/Creat_TPT_Update/OnLoadScreenClose，
--      本 mod 条目3.5 前端更新公告面板已有，且不覆盖 WorldTracker 标题控件）、
--      固定订阅列表更新（OnMods 的 UpdateMods(3041524474) 等，1.67 特有配置）。
-- ============================================================================

-- 本 mod 模组 ID（GUID，与 modinfo 一致；启用/更新本 mod 均按此定位，不依赖订阅 ID 常量）
local MPT_MOD_ID : string = "00000000-7369-4685-ab5f-bf77bc22b54e";

-- ============================================================================
-- MPT_AutoUpdate_FindSelf()
-- 在已安装 mod 中按 MPT_MOD_ID（GUID）定位本 mod 条目（含 Handle/SubscriptionId）。
-- 返回 nil 表示未找到（本地未安装/未登记）。
-- ============================================================================
local function MPT_AutoUpdate_FindSelf()
	local mods = Modding.GetInstalledMods();
	if mods == nil then
		return nil;
	end
	for _, mod in ipairs(mods) do
		if mod.Id == MPT_MOD_ID then
			return mod;
		end
	end
	return nil;
end

-- ============================================================================
-- MPT_AutoUpdate_EnableSelf()
-- 确保本 mod 处于启用状态：按 MPT_MOD_ID 定位本 mod → Modding.EnableMod(handle, true)。
-- 已在启用状态时调用无副作用（1.67 EnableMods 同款语义；1.67 按 SubscriptionId 匹配，
-- 本 mod 为本地 mod 无订阅 ID，改为按 modId 匹配）。
-- ============================================================================
local function MPT_AutoUpdate_EnableSelf()
	local mod = MPT_AutoUpdate_FindSelf();
	if mod == nil then
		print("MPT 条目13：未找到本 mod（Id=" .. MPT_MOD_ID .. "），跳过启用");
		return;
	end
	Modding.EnableMod(mod.Handle, true);
	print("MPT 条目13：确保本 mod 已启用 (Handle=" .. tostring(mod.Handle) .. ")");
end

-- ============================================================================
-- MPT_AutoUpdate_UpdateAll()
-- 对本局已启用（GameConfiguration.GetEnabledMods）的非官方创意工坊 mod 触发工坊更新检查。
-- 静默执行，仅 print 到 Lua.log 留痕；空 Context Lua 每次进游戏只加载执行一次（天然幂等，
-- 无需条目4.7 的会话 ID 守卫）。
-- ============================================================================
local function MPT_AutoUpdate_UpdateAll()
	-- 单次遍历已安装 mod 建 [modId]=SubscriptionId 映射（替代 1.67 双重循环）
	local subscriptionMap : table = {};
	local installedMods = Modding.GetInstalledMods();
	if installedMods == nil then
		return;
	end
	for _, mod in ipairs(installedMods) do
		if mod.SubscriptionId ~= nil and mod.SubscriptionId ~= "" then
			subscriptionMap[mod.Id] = mod.SubscriptionId;
		end
	end

	-- 遍历本局已启用 mod：非官方且有工坊订阅的触发更新
	local updateCount : number = 0;
	local enabledMods = GameConfiguration.GetEnabledMods();
	if enabledMods == nil then
		return;
	end
	for _, curMod in ipairs(enabledMods) do
		if not curMod.Official then
			local subscriptionId = subscriptionMap[curMod.Id];
			if subscriptionId ~= nil then
				Modding.UpdateSubscription(subscriptionId);		-- 触发工坊更新检查
				updateCount = updateCount + 1;
				print("MPT 条目13：检查工坊更新 " .. tostring(curMod.Title) .. " (SubscriptionId=" .. tostring(subscriptionId) .. ")");
			end
		end
	end
	print("MPT 条目13：自动更新检查完成，共触发 " .. updateCount .. " 个非官方创意工坊mod");
end

-- ============================================================================
-- MPT_AutoUpdate_UpdateSelf()
-- 退出到主菜单时触发本 mod 的工坊更新检查（1.67 ExitToMainMenu 分支）。
-- 按 MPT_MOD_ID 定位本 mod 后取其 SubscriptionId 触发更新——本 mod 发布到创意工坊后
-- 运行时自动生效，无需改代码；未发布（无订阅 ID）则跳过。
-- ============================================================================
local function MPT_AutoUpdate_UpdateSelf()
	local mod = MPT_AutoUpdate_FindSelf();
	if mod == nil then
		print("MPT 条目13：未找到本 mod（Id=" .. MPT_MOD_ID .. "），跳过更新检查");
		return;
	end
	if mod.SubscriptionId == nil or mod.SubscriptionId == "" then
		print("MPT 条目13：本 mod 无工坊订阅 ID，退出时跳过更新检查");
		return;
	end
	Modding.UpdateSubscription(mod.SubscriptionId);
	print("MPT 条目13：退出时触发本 mod 更新检查 (SubscriptionId=" .. tostring(mod.SubscriptionId) .. ")");
end

-- ============================================================================
-- 初始化（空 Context 同名 Lua 加载即执行，= 进入游戏）
-- ============================================================================
local function MPT_AutoUpdate_Initialize()
	MPT_AutoUpdate_UpdateAll();		-- 1) 更新所有已启用的非官方工坊 mod
	MPT_AutoUpdate_EnableSelf();	-- 2) 确保本 mod 已启用
	Events.ExitToMainMenu.Add(MPT_AutoUpdate_UpdateSelf);	-- 3) 退出游戏时更新本 mod
end
MPT_AutoUpdate_Initialize();
