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
--   · 【LoadGame 重置语义】LoadData 会把 GameConfiguration 替换为该文件快照，不在文件里的
--     键被清掉（实测）——请在安全时机调用（主菜单/进房前后）；联机准备房间内读档实测
--     不踢人、不影响房间配置（房间配置由网络同步持有）；InGame 读档时机自负（PKU 有先例）。
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

-- 幂等守卫：重复 include（本文件可能被多个上下文引入）直接返回，互不影响
if MPT_Storage_Loaded then return; end
MPT_Storage_Loaded = true;

include("MPT_Serialize");

-- ============================================================================
-- 常量
-- ============================================================================
local STORAGE_KEY_PREFIX : string = "MPT_DS_";		-- GameConfiguration 键前缀（防与其他键碰撞）
local STORAGE_CHUNK_SIZE : number = 128000;			-- 单值切块长度（单值 512000 实测完整读写，取 1/4 留余量）

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
-- 内部：执行队首作业。save=切块写键后落盘等 SaveComplete；load/delete=先直查文件列表。
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
	else	-- load / delete 都先直查 Saves\Single 的 GAME_CONFIGURATION 列表（无弹窗）
		job.queryId = nil;
		local ok, queryId = pcall(function()
			return UI.QuerySaveGameList(SaveLocations.LOCAL_STORAGE, SaveTypes.SINGLE_PLAYER, SaveLocationOptions.NORMAL + SaveLocationOptions.LOAD_METADATA, SaveFileTypes.GAME_CONFIGURATION, "");
		end);
		if ok and queryId ~= nil then
			job.queryId = queryId;
		else
			StorageFinishJob(job.kind == "delete" and false or nil);
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
-- 内部：SaveComplete 派发——在途 save 作业落盘完成，清键后收尾
-- ============================================================================
Events.SaveComplete.Add(function(eResult, eType, eOptions, eFileType)
	local job = g_storageJob;
	if job == nil or job.kind ~= "save" then return; end
	if eFileType ~= nil and eFileType ~= SaveFileTypes.GAME_CONFIGURATION then return; end
	StorageClearKey(STORAGE_KEY_PREFIX .. job.key);	-- 落盘后清键，防混入房间配置与真实存档（PKU 同款清理思路）
	StorageFinishJob(eResult == nil or eResult == 0);
end);

-- ============================================================================
-- 内部：LoadComplete 派发——在途 load 作业读档完成，读键反序列化后收尾
-- ============================================================================
Events.LoadComplete.Add(function(eResult, eType, eOptions, eFileType)
	local job = g_storageJob;
	if job == nil or job.kind ~= "load" or job.queryId ~= nil then return; end	-- 仅在 LoadGame 已发出后认领
	StorageFinishJob(StorageReadKey(STORAGE_KEY_PREFIX .. job.key));
end);

-- ============================================================================
-- 内部：文件列表派发（LuaEvents.FileListQueryResults，引擎触发）——按自身 requestID 认领；
-- load 找到则 LoadGame 读档，delete 找到则 DeleteSavedGame，未找到按 nil/false 收尾。
-- ============================================================================
LuaEvents.FileListQueryResults.Add(function(fileList : table, id : number)
	local job = g_storageJob;
	if job == nil or job.queryId == nil or id ~= job.queryId then return; end
	pcall(function() UI.CloseFileListQuery(id); end);
	job.queryId = nil;
	local found = nil;
	for _, file in pairs(fileList or {}) do
		if file.Name == job.fileName .. ".Civ6Cfg" then
			found = file;
			break;
		end
	end
	if job.kind == "load" then
		if found == nil then StorageFinishJob(nil); return; end
		local ok = pcall(function() Network.LoadGame(found, 0); end);
		if not ok then StorageFinishJob(nil); end
	else	-- delete
		if found == nil then StorageFinishJob(false); return; end
		pcall(function() UI.DeleteSavedGame(found); end);
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
-- 【重置语义警告】会把 GameConfiguration 替换为该文件快照，请注意调用时机（见文件头）。
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
