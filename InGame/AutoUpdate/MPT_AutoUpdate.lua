-- ============================================================================
-- 条目13：游戏内自动更新（移植 1.67 Update/UI/AutoUpdate.lua 纯逻辑部分，变量名 TPT→MPT 优化）
-- ============================================================================
-- 【条目13调整（用户裁决）：更新功能整体禁用，仅保留 EnsureSelf——见 Initialize 内注释与下方机理】
-- 禁用机理（2026-09-05 实测取证）：本 mod 带工坊订阅 3795550166 且本地开发版与工坊快照
-- 永不同步，UpdateSubscription 每次核对都触发 Steam 真实下载替换本 mod 文件（一局实测
-- 7 次 DownloadItemResult），运行中换血致「开一局退出后再开第二局崩溃」。对照 1.65
-- AutoUpdate 同款代码从不崩溃 = 其本地与工坊恒等，核对即通过零下载——雷不在 API 调用，
-- 在「对永远不同步的自己订阅反复触发更新」。恢复方式：取消下方调用行注释（建议同时
-- 退订工坊 3795550166 或在 UpdateAll 内排除 MPT_MOD_ID 后再恢复）。
-- ============================================================================
-- 用法：空 Context 同名 Lua 自动执行（AddUserInterfaces Context=InGame），进游戏即触发一次；
--      退出到主菜单（Events.ExitToMainMenu）时再触发本 mod 更新检查。
--   1) MPT_AutoUpdate_UpdateAll()  进游戏时对本局已启用的非官方创意工坊 mod 触发工坊更新检查
--      （复用条目4.7 优化：单次遍历建 [modId]=SubscriptionId 映射 + nil 防御 + 非官方过滤 +
--      日志留痕，替代 1.67 O(n²) 双重循环）【已禁用，见顶部禁用机理】；
--   2) MPT_AutoUpdate_EnableSelf() 确保本 mod 已启用（按 MPT_MOD_ID 匹配 Handle；本地 mod 无
--      订阅 ID，1.67 按 SubscriptionId 匹配的 EnableMods 不适用）【唯一保留】；
--   3) MPT_AutoUpdate_UpdateSelf() 退出到主菜单时触发本 mod 工坊更新（按 MPT_MOD_ID 匹配安装
--      列表取工坊订阅 ID，本 mod 发布到创意工坊后自动生效，无需改代码；无订阅 ID 则跳过）
--      【已禁用，见顶部禁用机理】；
--   4) MPT_AutoUpdate_OnLoadScreenClose() 进局把 WorldTracker 头部改为「mod 名 + 展示版本」
--      （条目36扩展）。
-- 不移植：更新内容 Tooltip 展示（Get_TPT_Update_Text/Creat_TPT_Update，本 mod 条目3.5 前端
--      更新公告面板已有）、固定订阅列表更新（OnMods 的 UpdateMods(3041524474) 等，1.67 特有配置）。
-- 条目36扩展（用户指示推翻原「不覆盖 WorldTracker 标题控件」裁决）：OnLoadScreenClose 头部
--      改写移植为下方 MPT_AutoUpdate_OnLoadScreenClose（仅改文本，不带 1.67 的更新 Tooltip）。
-- ============================================================================

-- 本 mod 模组 ID：从 ModMeta_Data.sql 的 LOC_MPT_MOD_ID 文本 tag 查取（条目36扩展收编，
-- Lua 侧硬编码 GUID 废止 → GUID 单源 = modinfo id 属性 + ModMeta_Data.sql 数据行）。
-- 文件级查取时机安全（IG_ModMeta_Text LoadOrder 10 先于本上下文加载，1.67 同文件
-- 文件级 Locale.Lookup 取订阅 ID 先例）；tag 缺失时 Locale.Lookup 回传原 tag 名，
-- 依 ^LOC_ 前缀识别并置空 → FindSelf 必不匹配，Enable/UpdateSelf 走「未找到」分支
-- 打印跳过，不影响其余功能。
local MPT_MOD_ID : string = Locale.Lookup("LOC_MPT_MOD_ID");
if MPT_MOD_ID == nil or string.find(MPT_MOD_ID, "^LOC_") ~= nil then
	print("MPT 条目13：LOC_MPT_MOD_ID 文本缺失（ModMeta_Data.sql 未加载？），本 mod 启用/更新定位将跳过");
	MPT_MOD_ID = "";
end

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
-- 条目36扩展：反推本房间启用 mod 的订阅 ID（用户指示；FindSelf 的「GUID 经已安装表
-- 反查」模式推广到房间全量启用 mod——GameConfiguration.GetEnabledMods 条目只含
-- mod GUID，订阅 ID 必须经 Modding.GetInstalledMods 反查才能拿到）
-- ============================================================================

-------------------------------------------------
-- MPT_AutoUpdate_GetRoomSubscriptionIds
-- 反推本房间启用 mod 的订阅 ID：启用列表逐个取 GUID → 已安装表 [modId]=SubscriptionId
-- 映射反查（FindSelf 同款匹配推广到全量；映射建表法复用 UpdateAll）。
-- 仅非官方且有订阅者入表：官方 mod 与本地无订阅 mod（订阅 ID 空串/缺失）天然缺席。
-- 用法：local roomSubs = MPT_AutoUpdate_GetRoomSubscriptionIds();  roomSubs[modId] = 订阅ID。
-- 纯查询零副作用：只读数据、不触发 Modding.UpdateSubscription（条目13 崩溃机理隔离），可安全复用。
-- -------------------------------------------------
local function MPT_AutoUpdate_GetRoomSubscriptionIds()
	local roomSubs : table = {};
	local derivedCount : number = 0;
	local installedMods = Modding.GetInstalledMods();
	if installedMods == nil then
		return roomSubs;
	end
	local subscriptionMap : table = {};
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
					roomSubs[curMod.Id] = subscriptionId;
					derivedCount = derivedCount + 1;
					print("MPT 条目36扩展：房间启用 mod「" .. tostring(curMod.Title) .. "」订阅 ID=" .. subscriptionId);
				end
			end
		end
	end
	print("MPT 条目36扩展：房间启用 mod 订阅 ID 反推完成，共 " .. derivedCount .. " 个有订阅的启用 mod");
	return roomSubs;
end

-- ============================================================================
-- 条目36扩展：WorldTracker 头部显示「本 mod 名 + 展示版本」（用户指示移植 1.67 AutoUpdate
-- OnLoadScreenClose 同款，推翻本文件原「不覆盖 WorldTracker 标题控件」不移植裁决）
-- 时机 = Events.LoadScreenClose（游戏 UI 全载入后，1.67 同款时机）；跨上下文
-- ContextPtr:LookUpControl("/InGame/WorldTracker/WorldTracker") 只读定位原版头部 Label
-- （Base/Assets/UI/WorldTracker.xml 唯一 Label ID=WorldTracker，String=LOC_WORLD_TRACKER_HEADER）
-- 后 SetText 改文本——只读跨上下文可达，与条目25 技能库「注入不可行」结论不冲突；
-- 不带 1.67 的 SetToolTipType/Creat_TPT_Update（用户裁决不要 tooltip）。
-- 文本：LOC_MPT_WORLD_TRACKER_HEADER（FrontEnd/Text/ 双语通用文本）+ LOC_MPT_FE_VERSION
-- （ModMeta_Data.sql 展示版本行，IG_ModMeta_Text 已游戏内注册）。
-- ============================================================================
local WorldTrackerHeaderStr = Locale.Lookup("LOC_MPT_WORLD_TRACKER_HEADER");	-- 头部名（联机工具箱 / Multiplayer Toolkits）
local WorldTrackerVersionStr = Locale.Lookup("LOC_MPT_FE_VERSION");		-- 展示版本号（如 2.0.2）

-- ============================================================================
-- MPT_AutoUpdate_OnLoadScreenClose()
-- 进局（LoadScreenClose）时把 WorldTracker 头部文本改为「mod 名 + 展示版本」。
-- 用法：Initialize 内订阅 Events.LoadScreenClose，每局触发一次；控件缺失则 print 跳过。
-- ============================================================================
local function MPT_AutoUpdate_OnLoadScreenClose()
	local worldTracker = ContextPtr:LookUpControl("/InGame/WorldTracker/WorldTracker");
	if worldTracker == nil then
		print("MPT 条目36扩展：未找到 /InGame/WorldTracker/WorldTracker 控件，跳过头部版本显示");
		return;
	end
	worldTracker:SetText(WorldTrackerHeaderStr .. " " .. WorldTrackerVersionStr);
	print("MPT 条目36扩展：WorldTracker 头部已设为「" .. WorldTrackerHeaderStr .. " " .. WorldTrackerVersionStr .. "」");
end

-- ============================================================================
-- 初始化（空 Context 同名 Lua 加载即执行，= 进入游戏）
-- ============================================================================
local function MPT_AutoUpdate_Initialize()
	-- MPT_AutoUpdate_UpdateAll();		-- 1) 更新所有已启用的非官方工坊 mod【条目13调整禁用：运行中触发工坊下载替换本 mod 文件致第二局崩溃，见顶部禁用机理】
	MPT_AutoUpdate_EnableSelf();	-- 2) 确保本 mod 已启用（唯一保留）
	MPT_AutoUpdate_GetRoomSubscriptionIds();	-- 条目36扩展：进局反推本房间启用 mod 订阅 ID（纯查询，Lua.log 留痕）
	--Events.ExitToMainMenu.Add(MPT_AutoUpdate_UpdateSelf);	-- 3) 退出游戏时更新本 mod【条目13调整禁用：同上】
	Events.LoadScreenClose.Add(MPT_AutoUpdate_OnLoadScreenClose);	-- 4) 条目36扩展：WorldTracker 头部显示 mod 名 + 展示版本
end
MPT_AutoUpdate_Initialize();
