-- ============================================================================
-- MPT_DataStorage.lua
-- 联机工具箱 2.0：极简本地数据读写工具（条目4.3预备）
--
-- 定位：纯读写工具，与 PKU「文明6 Mod本地数据框架」（工坊 3417070280）差异化——
--   无压缩、无缓存、无启动预载、无索引键、无注册表/版本迁移/联机同步/配置UI。
--   调用方自选 .Civ6Cfg 文件名与键名，每次 LoadData 都真实读盘。
--
-- 原理：GameConfiguration 键值随存档落盘。Network.SaveGame 指定
--   FileType = SaveFileTypes.GAME_CONFIGURATION 时，把当前 GameConfiguration 单独存成
--   .Civ6Cfg 配置存档；读取时 Network.LoadGame 载入该配置存档，再 GameConfiguration.GetValue
--   取回。数据经 MPT_Serialize 序列化为纯可打印 ASCII（%q 转义），超长按块拆分。
--
-- 用法（任意前端/游戏内上下文 include 后直接调用；异步，结果经回调返回）：
--   MPT_Storage_SaveData("MyMod", "Blacklist", t, function(ok) end);   -- 写：序列化→落盘 MyMod.Civ6Cfg
--   MPT_Storage_LoadData("MyMod", "Blacklist", function(t) end);       -- 读：t=数据表，无存档/键损坏=nil
--   MPT_Storage_DeleteFile("MyMod", function(found) end);              -- 删：删除 MyMod.Civ6Cfg
--
-- 注意事项（务必读）：
--   · 【LoadGame 重置语义与快照/恢复链】LoadGame 会把 GameConfiguration 替换为该文件快照，
--     且 GAME_CONFIGURATION 存档实测含房间槽位身份（「名字@网络ID」）与 Players:* 配置——
--     联机准备房间内【裸】LoadGame 会把旧快照盖回槽位（条目4.4 换槽后原槽位显示旧房客的
--     bug 根因）。故 LoadData 内置「快照/恢复链」：先把当前实况 SaveGame 成临时档
--     MPT_RestoreSnapshot，读数据档取键后立即 LoadGame 临时档恢复实况并删除之，
--     准备房间内可安全调用；InGame 读档时机自负（PKU 有先例）。
--   · 存档文件夹恒为 Saves\Single（保存恒用 SaveTypes.SINGLE_PLAYER，读写同目录，实测）。
--   · 作业串行：模块内建 FIFO 队列，任时刻只有一个读写作业在途（并发查询互顶为实测坑），
--     回调按入队顺序到达；无看门狗——引擎回调可靠性已三轮实测。
--   · fileName/key 仅限字母数字下划线（要拼进 GameConfiguration 键名）。
--
-- 关键实测结论（条目4.3预备 Phase0/1/2，详见 AGENTS.md 踩坑记录）：
--   · 前端 Events.SaveComplete / Events.LoadComplete 均正常触发；
--   · GameConfiguration 单值 512000 字符完整往返（未触顶），切块 128000 留足余量；
--   · 房间内 5 秒级高频写读 + 反复落盘可靠（SaveComplete 100% 到达）；
--   · UI.QuerySaveGameList 直查可用（无弹窗）：结果经 LuaEvents.FileListQueryResults 回调，
--     必须按自身 requestID 认领（启动期 MainMenu 并发查询会互顶，误收会判断落空）；
--   · 任意路径读写：SaveGame 带 Path 字段、LoadGame 用构造表可从任意路径读写配置档
--     （本工具不用该能力，存档恒在 Saves\Single）。
-- ============================================================================

-- 幂等守卫：重复 include（本文件可能被多个上下文引入）直接返回，互不影响。
-- MPT_Storage_Loaded 在文件末尾全部定义完成后才置位：若顶层中途夭折（错误被吞等），
-- 守卫不置位，下次 include 重新完整执行可自愈。
if MPT_Storage_Loaded then return; end

include("MPT_Serialize");

-- ============================================================================
-- 常量
-- ============================================================================
local STORAGE_KEY_PREFIX : string = "MPT_DS_";		-- GameConfiguration 键前缀（防与其他键碰撞）
local STORAGE_CHUNK_SIZE : number = 128000;			-- 单值切块长度（单值 512000 实测完整读写，取 1/4 留余量）
local STORAGE_SNAPSHOT_NAME : string = "MPT_RestoreSnapshot";	-- LoadData 快照/恢复链临时档名（常量、每次覆盖、用完即删）

-- ============================================================================
-- 作业队列状态（FIFO：任时刻只有一个作业在途，回调按入队顺序到达）
-- ============================================================================
local g_storageJobs : table = {};	-- 待执行作业队列
local g_storageJob  = nil;			-- 在途作业（nil=空闲）

local StorageRunNext, StorageFinishJob;	-- 互递归前向声明

-- ============================================================================
-- StorageClearKey：清除某键及其全部旧块（多块时键值为块数）。
-- 覆盖写入前必须先清：上次多块本次单块时，残留的旧块会污染拼接读取。
-- ============================================================================
local function StorageClearKey(key : string)
	local oldValue = GameConfiguration.GetValue(key);
	if type(oldValue) == "number" then
		for i = 1, oldValue do
			GameConfiguration.SetValue(key .. "_" .. i, nil);
		end
	end
	GameConfiguration.SetValue(key, nil);
end

-- ============================================================================
-- StorageWriteKey：编码串切块写入（切块防单值长度上限；多块时键存块数）
-- ============================================================================
local function StorageWriteKey(key : string, encodedStr : string)
	StorageClearKey(key);
	local chunkNum : number = math.ceil(#encodedStr / STORAGE_CHUNK_SIZE);
	if chunkNum > 1 then
		GameConfiguration.SetValue(key, chunkNum);
		for i = 1, chunkNum do
			GameConfiguration.SetValue(key .. "_" .. i, string.sub(encodedStr, (i - 1) * STORAGE_CHUNK_SIZE + 1, i * STORAGE_CHUNK_SIZE));
		end
	else
		GameConfiguration.SetValue(key, encodedStr);
	end
end

-- ============================================================================
-- StorageReadKey：读取键并拼接反序列化（多块时键值为块数；块缺失视为损坏返回 nil）
-- ============================================================================
local function StorageReadKey(key : string)
	local value = GameConfiguration.GetValue(key);
	if type(value) == "number" then
		local chunks : table = {};
		for i = 1, value do
			local chunk = GameConfiguration.GetValue(key .. "_" .. i);
			if type(chunk) ~= "string" then return nil; end
			chunks[i] = chunk;
		end
		value = table.concat(chunks);
	end
	if type(value) ~= "string" then return nil; end
	return MPT_Deserialize(value);
end

-- ============================================================================
-- StorageValidateName：fileName/key 仅限字母数字下划线（fileName 做文件名，key 拼进键名）
-- ============================================================================
local function StorageValidateName(name)
	return type(name) == "string" and string.match(name, "^[%w_]+$") ~= nil;
end

-- ============================================================================
-- 内部：发起文件列表直查（Saves\Single 的 GAME_CONFIGURATION，无弹窗）。
-- 成功置 job.step="query" 并返回 true；查询都发不出返回 false（事件不会再来，调用方负责收尾）。
-- ============================================================================
local function StorageStartQuery(job)
	job.queryId = nil;
	local ok, queryId = pcall(function()
		return UI.QuerySaveGameList(SaveLocations.LOCAL_STORAGE, SaveTypes.SINGLE_PLAYER, SaveLocationOptions.NORMAL + SaveLocationOptions.LOAD_METADATA, SaveFileTypes.GAME_CONFIGURATION, "");
	end);
	if ok and queryId ~= nil then
		job.step = "query";
		job.queryId = queryId;
		return true;
	end
	return false;
end

-- ============================================================================
-- 内部：LoadData 快照/恢复链——把 GameConfiguration 恢复为临时档 A 的实况快照（LoadComplete
-- 里 step="restore" 分支删 A 并收尾）。任何 load 失败路径都必须经此恢复，防旧快照残留盖房。
-- ============================================================================
local function StorageRestoreSnapshot(job, result)
	job.data = result;
	if job.fileSnap == nil then
		StorageFinishJob(result);	-- 无快照可恢复（正常流程到不了这里：快照保存成功才会发出 LoadGame）
		return;
	end
	local ok = pcall(function() Network.LoadGame(job.fileSnap, 0); end);
	if ok then
		job.step = "restore";
	else
		print("MPT_DS: 恢复快照失败，房间配置可能停留在数据档快照");
		pcall(function() UI.DeleteSavedGame(job.fileSnap); end);
		StorageFinishJob(result);
	end
end

-- ============================================================================
-- 内部：执行队首作业。save=切块写键后落盘等 SaveComplete；delete=直查文件列表；
-- load=快照/恢复链：①先把当前实况 SaveGame 成临时档 A（等 SaveComplete）→ ②直查列表
-- 拿 A 与数据档 B → ③LoadGame(B) 取键 → ④LoadGame(A) 恢复实况 → ⑤删 A 收尾。
-- ============================================================================
StorageRunNext = function()
	if g_storageJob ~= nil then return; end
	local job = g_storageJobs[1];
	if job == nil then return; end
	table.remove(g_storageJobs, 1);
	g_storageJob = job;
	if job.kind == "save" then
		StorageWriteKey(STORAGE_KEY_PREFIX .. job.key, job.encoded);
		local ok = pcall(function()
			Network.SaveGame({ Name = job.fileName, Type = SaveTypes.SINGLE_PLAYER, FileType = SaveFileTypes.GAME_CONFIGURATION });
		end);
		if not ok then
			StorageClearKey(STORAGE_KEY_PREFIX .. job.key);
			StorageFinishJob(false);
		end
	elseif job.kind == "load" then
		-- 快照/恢复链第①步：存当前实况临时档 A，落盘完成事件里再走查询
		job.step = "saveSnap";
		local ok = pcall(function()
			Network.SaveGame({ Name = STORAGE_SNAPSHOT_NAME, Type = SaveTypes.SINGLE_PLAYER, FileType = SaveFileTypes.GAME_CONFIGURATION });
		end);
		if not ok then
			StorageFinishJob(nil);
		end
	else	-- delete 直查文件列表
		if not StorageStartQuery(job) then
			StorageFinishJob(false);
		end
	end
end

-- ============================================================================
-- 内部：结束在途作业——先推进队列再回调（回调内可安全再次入队；回调异常不炸队列）
-- ============================================================================
StorageFinishJob = function(result)
	local job = g_storageJob;
	if job == nil then return; end
	g_storageJob = nil;
	local callback = job.callback;
	StorageRunNext();
	if callback ~= nil then pcall(callback, result); end
end

-- ============================================================================
-- 内部：SaveComplete 派发——在途 save 作业落盘完成清键收尾；load 作业则是快照 A 落盘完成，
-- 继续走直查列表（eResult 非 0 视为快照失败：尚未 LoadGame，无需恢复，直接收尾）
-- ============================================================================
Events.SaveComplete.Add(function(eResult, eType, eOptions, eFileType)
	local job = g_storageJob;
	if job == nil then return; end
	if eFileType ~= nil and eFileType ~= SaveFileTypes.GAME_CONFIGURATION then return; end
	if job.kind == "save" then
		StorageClearKey(STORAGE_KEY_PREFIX .. job.key);	-- 落盘后清键，防混入房间配置与真实存档（PKU 同款清理思路）
		StorageFinishJob(eResult == nil or eResult == 0);
	elseif job.kind == "load" and job.step == "saveSnap" then
		if eResult ~= nil and eResult ~= 0 then StorageFinishJob(nil); return; end
		if not StorageStartQuery(job) then
			StorageFinishJob(nil);
		end
	end
end);

-- ============================================================================
-- 内部：LoadComplete 派发——load 作业按 step 认领：loadData=数据档读档完成，立即取键
-- （恢复后键即被快照覆盖）再 LoadGame 恢复快照；restore=恢复完成，删临时档收尾。
-- ============================================================================
Events.LoadComplete.Add(function(eResult, eType, eOptions, eFileType)
	local job = g_storageJob;
	if job == nil or job.kind ~= "load" then return; end
	if job.step == "loadData" then
		StorageRestoreSnapshot(job, StorageReadKey(STORAGE_KEY_PREFIX .. job.key));
	elseif job.step == "restore" then
		if eResult ~= nil and eResult ~= 0 then
			print("MPT_DS: 恢复快照读档失败，房间配置可能停留在数据档快照");
		end
		if job.fileSnap ~= nil then pcall(function() UI.DeleteSavedGame(job.fileSnap); end); end
		StorageFinishJob(job.data);
	end
end);

-- ============================================================================
-- 内部：文件列表派发（LuaEvents.FileListQueryResults，引擎触发）——按自身 requestID 认领；
-- load 一次查询同时拿数据档 B 与快照档 A：B 找到则 LoadGame 读档（等 LoadComplete 取键后恢复），
-- 未找到则删 A 直接收尾（未 LoadGame，配置未被碰）；delete 找到则 DeleteSavedGame。
-- ============================================================================
LuaEvents.FileListQueryResults.Add(function(fileList : table, id : number)
	local job = g_storageJob;
	if job == nil or job.queryId == nil or id ~= job.queryId then return; end
	pcall(function() UI.CloseFileListQuery(id); end);
	job.queryId = nil;
	local foundData = nil;
	local foundSnap = nil;
	for _, file in pairs(fileList or {}) do
		if file.Name == job.fileName .. ".Civ6Cfg" then
			foundData = file;
		elseif job.kind == "load" and file.Name == STORAGE_SNAPSHOT_NAME .. ".Civ6Cfg" then
			foundSnap = file;
		end
	end
	if job.kind == "load" then
		job.fileSnap = foundSnap;
		if foundData == nil then
			if foundSnap ~= nil then pcall(function() UI.DeleteSavedGame(foundSnap); end); end
			StorageFinishJob(nil);
			return;
		end
		local ok = pcall(function() Network.LoadGame(foundData, 0); end);
		if ok then
			job.step = "loadData";
		else
			StorageRestoreSnapshot(job, nil);	-- LoadGame 发不出去：恢复快照并收尾
		end
	else	-- delete
		if foundData == nil then StorageFinishJob(false); return; end
		pcall(function() UI.DeleteSavedGame(foundData); end);
		StorageFinishJob(true);
	end
end);

-- ============================================================================
-- 对外：写——data 序列化后切块写入并落盘 fileName.Civ6Cfg（Saves\Single）。
-- data 为任意纯数据（表/字符串/数字/布尔；函数/循环表序列化报错）；
-- callback(success:boolean) 可选。
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
	table.insert(g_storageJobs, { kind = "save", fileName = fileName, key = key, encoded = encoded, callback = callback });
	StorageRunNext();
end

-- ============================================================================
-- 对外：读——载入 fileName.Civ6Cfg 并读回 key 反序列化后的数据。
-- callback(data) 必填；文件不存在/键缺失/数据损坏均回调 nil。
-- 内置快照/恢复链（先 SaveGame 当前实况临时档，取键后 LoadGame 恢复并删除），
-- 联机准备房间内可安全调用，不会再把旧槽位身份快照盖回房间。
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
	table.insert(g_storageJobs, { kind = "load", fileName = fileName, key = key, callback = callback });
	StorageRunNext();
end

-- ============================================================================
-- 对外：删——删除 fileName.Civ6Cfg；callback(found:boolean) 可选。
-- ============================================================================
function MPT_Storage_DeleteFile(fileName : string, callback)
	if not StorageValidateName(fileName) then
		print("MPT_DS: 非法 fileName", tostring(fileName));
		if callback ~= nil then pcall(callback, false); end
		return;
	end
	table.insert(g_storageJobs, { kind = "delete", fileName = fileName, callback = callback });
	StorageRunNext();
end

-- 幂等守卫置位（放在文件末尾：只有全部定义与事件注册成功才置位，半加载状态可由下次 include 自愈）
MPT_Storage_Loaded = true;
