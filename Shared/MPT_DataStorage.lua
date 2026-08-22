-- ============================================================================
-- MPT_DataStorage.lua
-- 联机工具箱 2.0：极简本地数据读写工具（条目4.3预备）
--
-- 定位：纯读写工具。调用方自选命名空间段（fileName）与键名段（key），
--   数据经 MPT_Serialize 序列化后由 ModGroup 组名承载（原 .Civ6Cfg 方案已移除）。
--
-- 原理：Modding.CreateModGroup(name, group) 创建 Mod 组，组名长度 >64MB 未触顶、
--   创建即落库 Mods.sqlite（ModGroups 表）、跨进程冷启动 Modding.GetModGroups()
--   读回完整（条目4.4 存储回归探路三轮实测，详见 AGENTS.md「ModGroup 组名存储实测定论」）。
--
-- 组名格式：[size_0][color:0,0,0,0][MPT_DS][fileName][key][len]数据
--   · [size_0][color:0,0,0,0] 隐形前缀（Civ6 Label 文本标签：字号0+全透明）——
--     数据组在前端 Mods 界面组列表不可见（1.67 [size_0] 前缀同款思路 + 透明色强化）；
--   · len = 数据字符数，读取时校验完整性（截断/损坏 → nil）；
--   · 单组名直存不切块（实测上限 64MB 远超实际数据量；1.67 的 2000 切块为保守设计）。
--
-- 干净组：建组前批量禁用全部已启用 mod（官方 DisableAllMods 模式：
--   GetInstalledMods 条目 .Enabled 筛选、DisableMod/EnableMod 表参数批量操作），
--   建组后即恢复——数据组不含任何 mod，玩家在前端误切到数据组不会改变 mod 启用状态。
--
-- 用法（任意前端/游戏内上下文 include 后直接调用；同步执行，结果经回调返回）：
--   MPT_Storage_SaveData("MyMod", "Blacklist", t, function(ok) end);   -- 写：序列化→删旧组→建组
--   MPT_Storage_LoadData("MyMod", "Blacklist", function(t) end);       -- 读：t=数据表，无组/损坏=nil
--   MPT_Storage_DeleteFile("MyMod", function(found) end);              -- 删：删 MyMod 全部数据组
--
-- 注意事项：
--   · fileName/key 仅限字母数字下划线（要拼进组名前缀做定界解析）；
--   · 全同步执行：Modding 组管理 API 均同步返回，无事件等待、无队列；
--   · 禁用→建组→恢复窗口内崩溃会残留 mod 全禁状态（概率极低，Mods 界面可手动恢复）。
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
-- StorageValidateName：fileName/key 仅限字母数字下划线（要拼进组名前缀做定界解析）
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
-- 对外：写——data 序列化后以组名承载（先删同 key 旧组，再建干净新组）。
-- data 为任意纯数据（表/字符串/数字/布尔；函数/循环表序列化报错）；
-- callback(success:boolean) 可选，同步调用。
-- ============================================================================
function MPT_Storage_SaveData(fileName : string, key : string, data, callback)
	if not StorageValidateName(fileName) or not StorageValidateName(key) then
		print("MPT_DS: 非法 fileName/key", tostring(fileName), tostring(key));
		if callback ~= nil then pcall(callback, false); end
		return;
	end
	local ok, encoded = pcall(MPT_Serialize, data);
	if not ok or type(encoded) ~= "string" then
		print("MPT_DS: 序列化失败", key);
		if callback ~= nil then pcall(callback, false); end
		return;
	end
	local prefix : string = STORAGE_GROUP_PREFIX .. fileName .. "][" .. key .. "][";
	StorageDeleteGroupsByPrefix(prefix);
	StorageCreateCleanGroup(prefix .. #encoded .. "]" .. encoded);
	if callback ~= nil then pcall(callback, true); end
end

-- ============================================================================
-- 对外：读——按前缀找数据组，len 校验后反序列化读回（异常多组时取第一个完好的）。
-- callback(data) 必填，同步调用；组不存在/长度损坏/反序列化失败均回调 nil。
-- ============================================================================
function MPT_Storage_LoadData(fileName : string, key : string, callback)
	if not StorageValidateName(fileName) or not StorageValidateName(key) then
		print("MPT_DS: 非法 fileName/key", tostring(fileName), tostring(key));
		if callback ~= nil then pcall(callback, nil); end
		return;
	end
	if type(callback) ~= "function" then
		print("MPT_DS: LoadData 缺少 callback", key);
		return;
	end
	local prefix : string = STORAGE_GROUP_PREFIX .. fileName .. "][" .. key .. "][";
	local data = nil;
	for i, v in ipairs(Modding.GetModGroups()) do
		if string.sub(v.Name, 1, #prefix) == prefix then
			local rest : string = string.sub(v.Name, #prefix + 1);
			local closePos = string.find(rest, "]", 1, true);	-- len 定界符（plain find：] 是模式魔法字符）
			if closePos ~= nil then
				local len = tonumber(string.sub(rest, 1, closePos - 1));
				local encoded : string = string.sub(rest, closePos + 1);
				if len ~= nil and len == #encoded then
					data = MPT_Deserialize(encoded);
					if data ~= nil then break; end
				else
					print("MPT_DS: 数据组长度校验失败", key);
				end
			end
		end
	end
	pcall(callback, data);
end

-- ============================================================================
-- 对外：删——删除 fileName 下全部 key 的数据组；callback(found:boolean) 可选，同步调用。
-- ============================================================================
function MPT_Storage_DeleteFile(fileName : string, callback)
	if not StorageValidateName(fileName) then
		print("MPT_DS: 非法 fileName", tostring(fileName));
		if callback ~= nil then pcall(callback, false); end
		return;
	end
	local found = StorageDeleteGroupsByPrefix(STORAGE_GROUP_PREFIX .. fileName .. "][");
	if callback ~= nil then pcall(callback, found); end
end

-- 幂等守卫置位（放在文件末尾：只有全部定义成功才置位，半加载状态可由下次 include 自愈）
MPT_Storage_Loaded = true;
