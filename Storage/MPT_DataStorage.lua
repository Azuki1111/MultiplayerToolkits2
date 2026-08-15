-- ============================================================================
-- MPT_DataStorage.lua
-- 联机工具箱 2.0 前端：本地数据持久化存储模块（条目4.3预备）
--
-- 基于 PKU「文明6 Mod本地数据框架」（工坊 3417070280，作者皮皮凯）的存储管线优化重写：
--   原实现 Common/UI/Additions/ModLocalDataManager.lua（SaveConfig/LoadConfigComplete）
--   + Common/UniversalLuaScript/PK_LibDeflate.lua（序列化压缩封装）
--   指南 https://github.com/X-PPK/CIV6-PKUIModDataGuide（gitee 有同名镜像）
--
-- 原理：GameConfiguration 键值随存档落盘。Network.SaveGame 指定
--   FileType = SaveFileTypes.GAME_CONFIGURATION 时，把当前 GameConfiguration 单独存成
--   .Civ6Cfg 配置存档；读取时 Network.LoadGame 载入该配置存档，再 GameConfiguration.GetValue
--   取回。存档文件夹由保存时的 Type 决定（Saves\Single / Saves\Multi）。
--
-- 本模块由 UI/StagingRoom/StagingRoom.lua 顶层 include 承载（前端实测无法用 AddUserInterfaces
-- 新建空 Context——Lua 不执行，前端功能必须依附既有界面上下文）；前端 Context 脚本在启动时
-- 即执行，故本模块随游戏启动自动运行，注册 MPT_Storage_* 全局 API 供同上下文直接调用。
--
-- 关键实测结论（Phase0/1/2 三轮游戏内实测，详见 git 历史与 AGENTS.md 踩坑记录）：
--   · LoadGame 是【重置语义】：不在存档里的键会被清掉（哨兵键实测）→ 加载必须在进房间
--     之前完成，故本模块在游戏启动时（主菜单）自动加载，房间内只读缓存/落盘；
--   · 文件列表菜单按当前环境枚举存档文件夹：主菜单列 Saves\Single，联机准备房间列
--     Saves\Multi（实测）→ 读取在主菜单发生，故保存【恒用 SINGLE_PLAYER】，读写同目录；
--   · UI.QuerySaveGameList 直查可用（无弹窗）：5 参调用（第5参目录路径恒传 "" 用默认目录，
--     与 LoadSaveMenu_Shared.lua:1060 一致），结果经 LuaEvents.FileListQueryResults 按自身
--     requestID 认领、用完 UI.CloseFileListQuery 释放；并发查询会互相干扰（启动期 MainMenu
--     自己也在查），故必须按 requestID 过滤，且直查不与弹窗查询同时发起；
--   · 任意目录枚举：SaveLocationOptions.DIRECTORIES + directoryPath 对 GAME_CONFIGURATION
--     同样有效（文件与子目录混列）；UI.GetSaveLocationPath 返回存档目录磁盘真实路径；
--   · 任意路径读写配置档：Network.SaveGame 带 Path 字段（官方仅 WORLDBUILDER_MAP 用）对
--     GAME_CONFIGURATION 生效；Network.LoadGame 用构造表 {Name,Path,Location,Type,FileType}
--     可从任意路径读回（哨兵键实测一致）——本模块仍存 Saves\Single 标准目录；
--   · 前端 Events.SaveComplete / Events.LoadComplete 均正常触发；
--   · GameConfiguration 单值 512000 字符完整读写往返（未触顶），切块取 128000 留足余量；
--   · 房间内每5秒高频写读 + 每20秒完整落盘，24轮×2启动全部可靠（SaveComplete 100%）。
-- 已知副作用（PKU 同款）：启动加载会把 GameConfiguration 替换为上次保存时的快照，
--   即建房/高级设置的初始值呈现上次保存时的房间配置（相当于"记住上次房间设置"）。
--
-- 相对 PKU 原实现的优化/裁剪：
--   1. 仅前端环境（本 mod 是纯前端 mod）：砍掉 InGame 分支、ExposedMembers 跨环境
--      缓存、联机同步、配置 UI 自动生成、ModDataIds 注册表、版本迁移钩子（1746 行框架 → 本文件）；
--   2. 压缩择优：PKU 无条件 Deflate 压缩 + EncodeForPrint（编码 +33% 体积），短数据反而
--      膨胀；本模块压缩后与原串比长度谁小存谁，前缀 'C:'=压缩编码 / 'P:'=明文，读端按前缀分流；
--   3. 序列化换用本 mod 的 MPT_Serialize（紧凑输出，压缩前体积更小）；
--   4. 键名统一 MPT_DS_ 前缀 + 索引键记名登记（GameConfiguration 无键枚举 API）；
--   5. 覆盖写入前先清旧块（上次多块本次单块时残留旧块会污染拼接读取）。
--
-- 数据布局（GameConfiguration 键）：
--   MPT_DS__Index          索引：编码后的 dataId 数组（记名制，读取时按名取回）
--   MPT_DS_<dataId>        单块：编码串（字符串）；多块：块数（数字）
--   MPT_DS_<dataId>_<i>    第 i 块（每块 STORAGE_CHUNK_SIZE 字符）
--
-- 用法（同上下文直接调用，模块随启动自动加载）：
--   LuaEvents.MPT_Storage_Ready.Add(fn);         -- 可选：加载完成（或全新无存档）后触发
--   if MPT_Storage_IsReady() then ... end        -- 加载完成（或无存档全新启动）后为 true
--   MPT_Storage_Set("Blacklist", t);             -- 写缓存（dataId 仅限字母数字下划线）
--   MPT_Storage_Save();                          -- 缓存全量落盘 MPT_ModData.Civ6Cfg
--   local t = MPT_Storage_Get("Blacklist");      -- 读缓存（无数据返回 nil）
--   MPT_Storage_Delete("Blacklist");             -- 删除（下次 Save 时清键）
-- ============================================================================

-- 幂等守卫：重复 include（本文件可能被多个上下文引入）直接返回，不重置模块状态
if MPT_Storage_Loaded then return; end
MPT_Storage_Loaded = true;

include("MPT_Serialize");
include("MPT_LibDeflate");

-- ============================================================================
-- 常量
-- ============================================================================
local STORAGE_FILE_NAME    : string = "MPT_ModData";	-- 配置存档文件名（Saves\Single\MPT_ModData.Civ6Cfg）
local STORAGE_KEY_PREFIX   : string = "MPT_DS_";		-- GameConfiguration 键前缀
local STORAGE_INDEX_ID     : string = "_Index";			-- 索引 dataId（登记全部 dataId 清单，保留字不可占用）
local STORAGE_CHUNK_SIZE   : number = 128000;			-- 单值切块长度（单值 512000 实测完整读写，取 1/4 留余量）
local STORAGE_MAX_RELOAD   : number = 3;				-- 读取失败最大重试次数
local STORAGE_PREFIX_PLAIN : string = "P:";				-- 编码串前缀：明文（序列化源码）
local STORAGE_PREFIX_COMPR : string = "C:";				-- 编码串前缀：Deflate 压缩 + EncodeForPrint
local STORAGE_BOOT_TIMEOUT : number = 60;				-- 启动引导超时秒数（等不到主菜单控件则本次放弃加载）

-- ============================================================================
-- 模块状态（本上下文内缓存；功能条目直接读写缓存，Save 时统一落盘）
-- ============================================================================
local g_storageCache      : table = {};			-- dataId → 数据表
local g_storageTombstones : table = {};			-- dataId → true（Delete 标记，Save 时清键）
local g_storageKnownIds   : table = {};			-- 存档中已知的 dataId（Save 时清理已删除项的旧键）
local g_storageReady      : boolean = false;	-- Init 加载完成（或无存档全新启动）后为 true
local g_storageLoading    : boolean = false;	-- Init 进行中去重
local g_storageReloadNum  : number = 0;			-- 读取失败已重试次数
local g_storageSaveDirty  : boolean = false;	-- Save 置位，SaveComplete 到达后清键复位
local g_storageQueryId    = nil;				-- 文件列表直查 requestID（非 nil 表示查询在途）
local g_storageBootTime   : number = 0;			-- 启动引导注册时刻（os.time 墙钟）
local g_storageBooted     : boolean = false;	-- 启动引导是否已触发 Init

-- 前向声明（互递归/回调引用）
local StorageOnFileList, StorageOnLoadComplete;

-- ============================================================================
-- StorageEncode：数据表 → 带前缀编码串
-- 管线：MPT_Serialize 序列化 → Deflate level 9 压缩 → EncodeForPrint 可打印编码；
-- 与原串比长度谁小存谁（Deflate 头部 + Encode 4/3 膨胀使短数据压缩得不偿失）。
-- 参数 t：纯数据表；返回 string：'P:'+明文 或 'C:'+压缩编码串
-- ============================================================================
local function StorageEncode(t : table)
	local plainStr : string = MPT_Serialize(t);
	local ok, encodedStr = pcall(function()
		local compressedStr = LibDeflate:CompressDeflate(plainStr, {level = 9});
		if compressedStr == nil then return nil; end
		return LibDeflate:EncodeForPrint(compressedStr);
	end);
	if ok and encodedStr ~= nil and #encodedStr < #plainStr then
		return STORAGE_PREFIX_COMPR .. encodedStr;
	end
	return STORAGE_PREFIX_PLAIN .. plainStr;
end

-- ============================================================================
-- StorageDecode：带前缀编码串 → 数据表（按前缀分流；损坏数据全程守卫返回 nil）
-- 参数 str：StorageEncode 产出的编码串；返回 table 或 nil
-- ============================================================================
local function StorageDecode(str)
	if type(str) ~= "string" or #str < 2 then return nil; end
	local prefix : string = string.sub(str, 1, 2);
	local body   : string = string.sub(str, 3);
	if prefix == STORAGE_PREFIX_PLAIN then
		return MPT_Deserialize(body);
	elseif prefix == STORAGE_PREFIX_COMPR then
		local ok, result = pcall(function()
			local compressedStr = LibDeflate:DecodeForPrint(body);
			if compressedStr == nil then return nil; end
			local plainStr = LibDeflate:DecompressDeflate(compressedStr);
			if plainStr == nil then return nil; end
			return MPT_Deserialize(plainStr);
		end);
		if ok then return result; end
	end
	return nil;
end

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
-- StorageReadKey：读取键并拼接解码（多块时键值为块数；块缺失视为损坏返回 nil）
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
	return StorageDecode(value);
end

-- ============================================================================
-- StorageValidateDataId：dataId 仅限字母数字下划线（要拼进 GameConfiguration 键名），
-- 且不得占用索引保留字 _Index。
-- ============================================================================
local function StorageValidateDataId(dataId)
	return type(dataId) == "string" and string.match(dataId, "^[%w_]+$") ~= nil and dataId ~= STORAGE_INDEX_ID;
end

-- ============================================================================
-- 对外：读缓存（未加载或无数据返回 nil）
-- ============================================================================
function MPT_Storage_Get(dataId : string)
	return g_storageCache[dataId];
end

-- ============================================================================
-- 对外：写缓存（仅内存，MPT_Storage_Save 后落盘）
-- ============================================================================
function MPT_Storage_Set(dataId : string, t : table)
	if not StorageValidateDataId(dataId) then
		print("MPT_DS: 非法 dataId", dataId);
		return;
	end
	g_storageCache[dataId] = t;
	g_storageTombstones[dataId] = nil;
end

-- ============================================================================
-- 对外：删除缓存并打删除标记（下次 Save 时清键）
-- ============================================================================
function MPT_Storage_Delete(dataId : string)
	g_storageCache[dataId] = nil;
	g_storageTombstones[dataId] = true;
end

-- ============================================================================
-- 对外：是否已完成加载
-- ============================================================================
function MPT_Storage_IsReady()
	return g_storageReady;
end

-- ============================================================================
-- 对外：缓存全量落盘到 MPT_ModData.Civ6Cfg（GAME_CONFIGURATION 配置存档）。
-- 先写索引再写各 dataId；tombstone 与存档已知但已删除的 dataId 清键。
-- 恒用 SINGLE_PLAYER：读取发生在主菜单（启动时），主菜单文件列表枚举 Saves\Single；
-- 存档文件夹只由 Type 决定，与调用时所在房间无关（Phase0 实测）。
-- ============================================================================
function MPT_Storage_Save()
	if not g_storageReady then
		print("MPT_DS: 尚未完成加载，忽略保存（防止空缓存覆盖磁盘数据）");
		return;
	end
	local ids : table = {};
	for dataId in pairs(g_storageCache) do
		table.insert(ids, dataId);
	end
	StorageWriteKey(STORAGE_KEY_PREFIX .. STORAGE_INDEX_ID, StorageEncode(ids));
	for _, dataId in ipairs(ids) do
		StorageWriteKey(STORAGE_KEY_PREFIX .. dataId, StorageEncode(g_storageCache[dataId]));
	end
	for dataId in pairs(g_storageTombstones) do
		StorageClearKey(STORAGE_KEY_PREFIX .. dataId);
	end
	for dataId in pairs(g_storageKnownIds) do
		if g_storageCache[dataId] == nil then
			StorageClearKey(STORAGE_KEY_PREFIX .. dataId);
		end
	end
	g_storageTombstones = {};
	g_storageKnownIds = {};
	for _, dataId in ipairs(ids) do
		g_storageKnownIds[dataId] = true;
	end
	local gameFile = {
		Name = STORAGE_FILE_NAME,
		Type = SaveTypes.SINGLE_PLAYER,
		FileType = SaveFileTypes.GAME_CONFIGURATION,
	};
	g_storageSaveDirty = true;
	Network.SaveGame(gameFile);
	print("MPT_DS: 已请求保存 " .. STORAGE_FILE_NAME .. ".Civ6Cfg（" .. #ids .. " 项）");
end

-- ============================================================================
-- 内部：SaveComplete 回调——落盘完成后清掉 GameConfiguration 里的 MPT_DS_ 键，
-- 防止键值混入准备房间配置与真实游戏存档（PKU InGame 同款清理思路）。
-- ============================================================================
local function StorageOnSaveComplete(eResult, eType, eOptions, eFileType)
	if not g_storageSaveDirty then return; end
	if eFileType ~= nil and eFileType ~= SaveFileTypes.GAME_CONFIGURATION then return; end
	g_storageSaveDirty = false;
	StorageClearKey(STORAGE_KEY_PREFIX .. STORAGE_INDEX_ID);
	for dataId in pairs(g_storageKnownIds) do
		StorageClearKey(STORAGE_KEY_PREFIX .. dataId);
	end
end
Events.SaveComplete.Add(StorageOnSaveComplete);

-- ============================================================================
-- 内部：读取完成回调（Events.LoadComplete，Network.LoadGame 后触发）
-- 读索引 → 按名读各 dataId 进缓存；失败重试 STORAGE_MAX_RELOAD 次（PKU ReloadNum 思路）。
-- ============================================================================
StorageOnLoadComplete = function(eResult, eType, eOptions, eFileType)
	Events.LoadComplete.Remove(StorageOnLoadComplete);	-- 只在主动 LoadGame 前订阅，触发即退订
	local ids = StorageReadKey(STORAGE_KEY_PREFIX .. STORAGE_INDEX_ID);
	if type(ids) ~= "table" then
		if g_storageReloadNum < STORAGE_MAX_RELOAD then
			g_storageReloadNum = g_storageReloadNum + 1;
			print("MPT_DS: 读取索引失败，重试第 " .. g_storageReloadNum .. " 次");
			g_storageLoading = false;
			MPT_Storage_Init();		-- 重新走完整加载流程
		else
			print("MPT_DS: 读取失败超过上限，本次启动放弃加载（磁盘数据未改动）");
			g_storageLoading = false;
		end
		return;
	end
	g_storageCache = {};
	g_storageKnownIds = {};
	for _, dataId in ipairs(ids) do
		local t = StorageReadKey(STORAGE_KEY_PREFIX .. dataId);
		if t ~= nil then
			g_storageCache[dataId] = t;
			g_storageKnownIds[dataId] = true;
		else
			print("MPT_DS: dataId " .. tostring(dataId) .. " 读取失败，跳过");
		end
	end
	g_storageReady = true;
	g_storageLoading = false;
	print("MPT_DS: 加载完成，共 " .. #ids .. " 项");
	LuaEvents.MPT_Storage_Ready();
end

-- ============================================================================
-- 内部：文件列表回调（LuaEvents.FileListQueryResults，引擎触发）。
-- 按本模块自身 requestID 认领——启动期 MainMenu 自己也在查询（MOST_RECENT_ONLY），不过滤
-- 会误收其 GAME_STATE 结果导致判断落空（实测）；认领后无论结果如何都退订并释放查询。
-- 找到 MPT_ModData.Civ6Cfg 则 LoadGame 载入；未找到按全新数据启动（非失败）。
-- ============================================================================
StorageOnFileList = function(fileList : table, id : number)
	if g_storageQueryId == nil or id ~= g_storageQueryId then return; end
	LuaEvents.FileListQueryResults.Remove(StorageOnFileList);
	pcall(function() UI.CloseFileListQuery(g_storageQueryId); end);
	g_storageQueryId = nil;
	if not g_storageLoading then return; end
	for _, file in pairs(fileList or {}) do
		if file.Name == STORAGE_FILE_NAME .. ".Civ6Cfg" then
			Events.LoadComplete.Add(StorageOnLoadComplete, 1);	-- 第二参沿用 PKU 实证写法
			Network.LoadGame(file, 0);
			print("MPT_DS: 找到 " .. STORAGE_FILE_NAME .. ".Civ6Cfg，开始载入");
			return;
		end
	end
	g_storageReady = true;
	g_storageLoading = false;
	print("MPT_DS: 未找到 " .. STORAGE_FILE_NAME .. ".Civ6Cfg，按全新数据启动");
	LuaEvents.MPT_Storage_Ready();
end

-- ============================================================================
-- 对外：初始化并异步加载（幂等）。完成或全新启动后触发 LuaEvents.MPT_Storage_Ready。
-- 直查 Saves\Single 的 GAME_CONFIGURATION 列表（无弹窗）。查询在途且无看门狗：
-- 引擎回调可靠性已实测（与 MainMenu 同款用法），若极端情况无回调则本次启动存储
-- 不可用（g_storageLoading 卡 true，Save 拒绝执行防覆盖磁盘），不引入额外复杂度。
-- ============================================================================
function MPT_Storage_Init()
	if g_storageReady or g_storageLoading then return; end
	g_storageLoading = true;
	LuaEvents.FileListQueryResults.Add(StorageOnFileList);
	local okQuery, queryId = pcall(function()
		return UI.QuerySaveGameList(SaveLocations.LOCAL_STORAGE, SaveTypes.SINGLE_PLAYER, SaveLocationOptions.NORMAL + SaveLocationOptions.LOAD_METADATA, SaveFileTypes.GAME_CONFIGURATION, "");
	end);
	if okQuery and queryId ~= nil then
		g_storageQueryId = queryId;
		print("MPT_DS: 文件列表直查已发起 requestID=", queryId);
	else
		LuaEvents.FileListQueryResults.Remove(StorageOnFileList);
		g_storageLoading = false;
		print("MPT_DS: 文件列表直查调用失败，本次启动放弃加载：", tostring(queryId));
	end
end

-- ============================================================================
-- 启动引导：本文件随 StagingRoom 上下文在前端启动时执行。轮询等待主菜单 LoadGameMenu 控件
-- 出现后自动执行一次加载（此时尚无房间，LoadGame 重置 GameConfiguration 无副作用）；
-- 超时放弃，本次启动存储不可用（MPT_Storage_IsReady()=false，Save 拒绝执行防覆盖磁盘）。
-- ============================================================================
local function StorageBootTick()
	if g_storageBooted then
		Events.GameCoreEventPublishComplete.Remove(StorageBootTick);
		return;
	end
	if os.time() - g_storageBootTime >= STORAGE_BOOT_TIMEOUT then
		Events.GameCoreEventPublishComplete.Remove(StorageBootTick);
		print("MPT_DS: 启动引导超时（" .. STORAGE_BOOT_TIMEOUT .. " 秒未等到主菜单控件），本次启动不加载");
		return;
	end
	if ContextPtr:LookUpControl("/FrontEnd/MainMenu/LoadGameMenu") == nil then return; end
	g_storageBooted = true;
	Events.GameCoreEventPublishComplete.Remove(StorageBootTick);
	print("MPT_DS: 主菜单就绪，开始加载本地数据存档");
	MPT_Storage_Init();
end
g_storageBootTime = os.time();
Events.GameCoreEventPublishComplete.Add(StorageBootTick);
print("MPT_DS: 启动引导已注册（等待主菜单 LoadGameMenu 控件）");
