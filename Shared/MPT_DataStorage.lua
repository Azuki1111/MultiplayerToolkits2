-- ============================================================================
-- MPT_DataStorage.lua
-- 联机工具箱 2.0：极简本地数据读写工具（条目4.3预备重构）
--
-- 定位：纯读写工具。**统一多表存储**：调用方自选命名空间段（fileName），
--   数据经 MPT_Serialize 序列化后整体承载于**单一 ModGroup 组名**（同一
--   ModGroupName），组内按「表名」分键存储——所有数据同组、互不覆盖。
--
-- 原理：Modding.CreateModGroup(name, group) 创建 Mod 组，组名长度 >64MB 未触顶、
--   创建即落库 Mods.sqlite（ModGroups 表）、跨进程冷启动 Modding.GetModGroups()
--   读回完整（条目4.4 存储回归探路三轮实测，详见 AGENTS.md「ModGroup 组名存储实测定论」）。
--
-- 组名格式：[size_0][color:0,0,0,0][MPT_DS][fileName][len]return { 表名=数据, ... }
--   · [size_0][color:0,0,0,0] 隐形前缀（Civ6 Label 文本标签：字号0+全透明）——
--     数据组在前端 Mods 界面组列表不可见（1.67 [size_0] 前缀同款思路 + 透明色强化）；
--   · len = 数据字符数，读取时校验完整性（截断/损坏 → 空表）；
--   · 单组名直存不切块（实测上限 64MB 远超实际数据量；1.67 的 2000 切块为保守设计）。
--
-- 干净组：建组前批量禁用全部已启用 mod（官方 DisableAllMods 模式：
--   GetInstalledMods 条目 .Enabled 筛选、DisableMod/EnableMod 表参数批量操作），
--   建组后即恢复——数据组不含任何 mod，玩家在前端误切到数据组不会改变 mod 启用状态。
--
-- 用法（任意前端/游戏内上下文 include 后直接调用；同步执行，结果经回调返回）：
--   MPT_Storage_LoadAll("MPT_PlayerInfo", function(all) ... end);   -- 读整组全部表
--   MPT_Storage_GetTable("MPT_PlayerInfo", "Players", function(t) end);  -- 读单表
--   MPT_Storage_SaveTables("MPT_PlayerInfo", { Players=t, HiddenSqlMark=true }, function(ok) end);
--     -- 写多表：读回整组 → 按表名覆盖传入的表（其它表自动保留）→ 写回同一组行。
--     -- 调用方无需读回合并；未来新功能 = 新增表名，天然同组共存。
--
-- 注意事项：
--   · fileName/表名仅限字母数字下划线（要拼进组名前缀做定界解析）；
--   · 全同步执行：Modding 组管理 API 均同步返回，无事件等待、无队列；
--   · 禁用→建组→恢复窗口内崩溃会残留 mod 全禁状态（概率极低，Mods 界面可手动恢复）；
--   · 写操作每次全组重写（读回→合并→序列化→删旧组→建组）：写频率低（保存按钮/
--     Confirm 才写）时开销可接受；旧版 SaveComposite 的「全量覆盖需调用方读回合并」
--     语义已由 SaveTables 内部自动读回合并取代。
-- ============================================================================

-- 幂等守卫：重复 include（本文件可能被多个上下文引入）直接返回，互不影响。
-- MPT_Storage_Loaded 在文件末尾全部定义完成后才置位：若顶层中途夭折（错误被吞等），
-- 守卫不置位，下次 include 重新完整执行可自愈。
if MPT_Storage_Loaded then return; end

include("MPT_Serialize");

-- ============================================================================
-- 常量
-- ============================================================================
local STORAGE_GROUP_PREFIX : string = "[size_0][color:0,0,0,0][MPT_DS][";	-- 数据组名公共前缀（隐形标签 + 命名空间）

-- ============================================================================
-- StorageValidateName：fileName/表名仅限字母数字下划线（要拼进组名前缀做定界解析）
-- ============================================================================
local function StorageValidateName(name)
	return type(name) == "string" and string.match(name, "^[%w_]+$") ~= nil;
end

-- ============================================================================
-- 内部：按前缀删除本 mod 的数据组（1.67 同款：写前清旧，防同 key 多组堆积）。
-- 返回是否有组被删。
-- ============================================================================
local function StorageDeleteGroupsByPrefix(prefix : string)
	local found = false;
	for i, v in ipairs(Modding.GetModGroups()) do
		if string.sub(v.Name, 1, #prefix) == prefix then
			Modding.DeleteModGroup(v.Handle);
			found = true;
		end
	end
	return found;
end

-- ============================================================================
-- 内部：建干净组——①记录并批量禁用全部已启用 mod（官方 DisableAllMods 模式：
-- GetInstalledMods 条目 .Enabled 筛选、DisableMod/EnableMod 表参数批量操作）
-- → ②1.67 序列建组（GetCurrentModGroup → CreateModGroup → SetCurrentModGroup 还原）
-- → ③批量恢复启用。pcall 包裹建组段：任何失败都保证恢复玩家的 mod 启用状态。
-- ============================================================================
local function StorageCreateCleanGroup(name : string)
	local enabledHandles : table = {};
	for i, v in ipairs(Modding.GetInstalledMods()) do
		if v.Enabled then
			table.insert(enabledHandles, v.Handle);
		end
	end
	if #enabledHandles > 0 then
		Modding.DisableMod(enabledHandles);
	end
	pcall(function()
		local g = Modding.GetCurrentModGroup();
		Modding.CreateModGroup(name, g);
		Modding.SetCurrentModGroup(g);
	end);
	if #enabledHandles > 0 then
		Modding.EnableMod(enabledHandles);
	end
end

-- ============================================================================
-- 对外：读整组——读回命名空间下全部表（单一复合组行，同组承载）。
--   callback(all) 必填，同步调用；无组/损坏/非表 → callback({})（空表字典）。
--   旧格式单 key 组（首段是表名、tonumber=nil）跳过不读（条目4.3重构不兼容旧存档）。
-- ============================================================================
function MPT_Storage_LoadAll(fileName : string, callback)
	if not StorageValidateName(fileName) then
		print("MPT_DS: 非法 fileName", tostring(fileName));
		if callback ~= nil then pcall(callback, {}); end
		return;
	end
	if type(callback) ~= "function" then
		print("MPT_DS: LoadAll 缺少 callback", fileName);
		return;
	end
	local prefix : string = STORAGE_GROUP_PREFIX .. fileName .. "][";
	local data : table = {};
	for i, v in ipairs(Modding.GetModGroups()) do
		if string.sub(v.Name, 1, #prefix) == prefix then
			local rest : string = string.sub(v.Name, #prefix + 1);
			local closePos = string.find(rest, "]", 1, true);	-- len 定界符（plain find：] 是模式魔法字符）
			if closePos ~= nil then
				local len = tonumber(string.sub(rest, 1, closePos - 1));
				if len ~= nil then	-- len 为纯数字：复合组（旧单 key 组首段是表名，tonumber=nil，跳过）
					local encoded : string = string.sub(rest, closePos + 1);
					if len == #encoded then
						local d = MPT_Deserialize(encoded);
						if type(d) == "table" then
							data = d;
							break;
						end
					else
						print("MPT_DS: 数据组长度校验失败", fileName);
					end
				end
			end
		end
	end
	local ok, err = pcall(callback, data);
	if not ok and err ~= nil then print("MPT_DS: LoadAll 回调错误", fileName, tostring(err)); end
end

-- ============================================================================
-- 对外：读单表——读回整组后取指定表名。
--   callback(data) 必填；表不存在/无组 → nil。
-- ============================================================================
function MPT_Storage_GetTable(fileName : string, tableName : string, callback)
	if not StorageValidateName(fileName) or not StorageValidateName(tableName) then
		print("MPT_DS: 非法 fileName/tableName", tostring(fileName), tostring(tableName));
		if callback ~= nil then pcall(callback, nil); end
		return;
	end
	if type(callback) ~= "function" then
		print("MPT_DS: GetTable 缺少 callback", tableName);
		return;
	end
	MPT_Storage_LoadAll(fileName, function(all)
		local ok, err = pcall(callback, all[tableName]);
		if not ok and err ~= nil then print("MPT_DS: GetTable 回调错误", tableName, tostring(err)); end
	end);
end

-- ============================================================================
-- 对外：写多表——读回整组 → 按表名覆盖传入的表（其它表自动保留）→ 写回同一组行。
--   tables = { 表名1=数据1, 表名2=数据2, ... }；callback(success:boolean) 可选，同步调用。
--   调用方无需读回合并：SaveTables 内部自动读回旧组合并，仅覆盖传入表名。
-- ============================================================================
function MPT_Storage_SaveTables(fileName : string, tables : table, callback)
	if not StorageValidateName(fileName) then
		print("MPT_DS: 非法 fileName", tostring(fileName));
		if callback ~= nil then pcall(callback, false); end
		return;
	end
	if type(tables) ~= "table" then
		print("MPT_DS: SaveTables 数据必须是表", tostring(fileName));
		if callback ~= nil then pcall(callback, false); end
		return;
	end
	for tableName, data in pairs(tables) do
		if not StorageValidateName(tableName) then
			print("MPT_DS: 非法表名", tostring(tableName));
			if callback ~= nil then pcall(callback, false); end
			return;
		end
	end
	MPT_Storage_LoadAll(fileName, function(all)
		for tableName, data in pairs(tables) do
			all[tableName] = data;
		end
		local ok, encoded = pcall(MPT_Serialize, all);
		if not ok or type(encoded) ~= "string" then
			print("MPT_DS: 序列化失败", fileName);
			if callback ~= nil then pcall(callback, false); end
			return;
		end
		local prefix : string = STORAGE_GROUP_PREFIX .. fileName .. "][";
		StorageDeleteGroupsByPrefix(prefix);
		StorageCreateCleanGroup(prefix .. #encoded .. "]" .. encoded);
		if callback ~= nil then
			local cbOk, err = pcall(callback, true);
			if not cbOk and err ~= nil then print("MPT_DS: SaveTables 回调错误", fileName, tostring(err)); end
		end
	end);
end

-- 幂等守卫置位（放在文件末尾：只有全部定义成功才置位，半加载状态可由下次 include 自愈）
MPT_Storage_Loaded = true;
