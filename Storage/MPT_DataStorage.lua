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
-- 本模块由 Storage/MPT_DataStorage.xml 空 Context 承载（AddUserInterfaces Context=FrontEnd），
-- 游戏启动到主菜单时自动运行；前端各 UI 上下文共享同一 Lua VM，消费方直接调用本文件
-- 注册的全局 API（MPT_Storage_*），无需 include（重复 include 会重置模块状态，禁止）。
--
-- 关键实测结论（Phase0/Phase1，详见 git 历史与 AGENTS.md 踩坑记录）：
--   · LoadGame 是【重置语义】：不在存档里的键会被清掉（哨兵键实测）→ 加载必须在进房间
--     之前完成，故本模块在游戏启动时（主菜单）自动加载，房间内只读缓存/落盘；
--   · 文件列表菜单按当前环境枚举存档文件夹：主菜单列 Saves\Single，联机准备房间列
--     Saves\Multi（实测）→ 读取在主菜单发生，故保存【恒用 SINGLE_PLAYER】，读写同目录；
--   · UI.QuerySaveGameList 曾实测不触发回调被判死路；但 MainMenu.lua:1547-1616 证实其结果
--     经【LuaEvents.FileListQueryResults】回调（疑此前订阅错 Events 通道）→ 正由文件末尾
--     【临时】Phase 2 探针复核，若直查可用则去掉弹窗加载路径；
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
-- 用法（任意前端上下文直接调用，启动时自动加载，无需 include）：
--   LuaEvents.MPT_Storage_Ready.Add(fn);         -- 可选：加载完成（或全新无存档）后触发
--   if MPT_Storage_IsReady() then ... end        -- 加载完成（或无存档全新启动）后为 true
--   MPT_Storage_Set("Blacklist", t);             -- 写缓存（dataId 仅限字母数字下划线）
--   MPT_Storage_Save();                          -- 缓存全量落盘 MPT_ModData.Civ6Cfg
--   local t = MPT_Storage_Get("Blacklist");      -- 读缓存（无数据返回 nil）
--   MPT_Storage_Delete("Blacklist");             -- 删除（下次 Save 时清键）
-- ============================================================================

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
local g_storageLoadMenu   = nil;				-- 暂存的 LoadGameMenu 控件引用（用完即关）
local g_storageBootTime   : number = 0;			-- 启动引导注册时刻（os.time 墙钟）
local g_storageBooted     : boolean = false;	-- 启动引导是否已触发 Init

-- 前向声明（互递归/回调引用）
local StorageOnFileList, StorageOnLoadComplete, StorageCloseLoadMenu;

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
	StorageCloseLoadMenu();
	print("MPT_DS: 加载完成，共 " .. #ids .. " 项");
	LuaEvents.MPT_Storage_Ready();
end

-- ============================================================================
-- 内部：文件列表回调（LuaEvents.FileListQueryResults）。
-- 找到 MPT_ModData.Civ6Cfg 则 LoadGame 载入；未找到按全新数据启动（非失败）。
-- ============================================================================
StorageOnFileList = function(fileList, id)
	LuaEvents.FileListQueryResults.Remove(StorageOnFileList);
	StorageCloseLoadMenu();		-- 列表已到，立即关掉弹窗
	if not g_storageLoading then return; end
	-- 【临时调试】逐条列出存档名，验证主菜单枚举范围（冒烟实测后删除）
	for _, file in pairs(fileList or {}) do
		print("MPT_DS", "FILE", file.Name);
	end
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
-- 内部：打开/关闭 LoadGameMenu 以触发文件列表查询
-- （UI.QuerySaveGameList 实测不触发回调——死路；菜单通道为 PKU 实证路径。
--   菜单会短暂闪现覆盖当前界面，每次启动至多一次；拿到列表后立即关闭）
-- ============================================================================
local function StorageOpenLoadMenu()
	g_storageLoadMenu = ContextPtr:LookUpControl("/FrontEnd/MainMenu/LoadGameMenu");
	if g_storageLoadMenu == nil then
		print("MPT_DS: 找不到 /FrontEnd/MainMenu/LoadGameMenu 控件，加载中止");
		g_storageLoading = false;
		return false;
	end
	if g_storageLoadMenu:IsHidden() then
		UIManager:QueuePopup(g_storageLoadMenu, PopupPriority.Current, { FileType = SaveFileTypes.GAME_CONFIGURATION });
	end
	return true;
end

StorageCloseLoadMenu = function()
	if g_storageLoadMenu ~= nil then
		if not g_storageLoadMenu:IsHidden() then
			UIManager:DequeuePopup(g_storageLoadMenu);
		end
		g_storageLoadMenu = nil;
	end
end

-- ============================================================================
-- 对外：初始化并异步加载（幂等）。完成或全新启动后触发 LuaEvents.MPT_Storage_Ready。
-- ============================================================================
function MPT_Storage_Init()
	if g_storageReady or g_storageLoading then return; end
	g_storageLoading = true;
	LuaEvents.FileListQueryResults.Add(StorageOnFileList);
	StorageOpenLoadMenu();
end

-- ============================================================================
-- 【临时调试】条目4.3 Phase 2 探针：QuerySaveGameList 直查 + GAME_CONFIGURATION 带 Path 落盘
-- 背景：MainMenu.lua:1547-1616 证实 UI.QuerySaveGameList 结果经 LuaEvents.FileListQueryResults
--   回调（按 requestID 匹配认领，用完 UI.CloseFileListQuery 释放），纯前端无弹窗可用——
--   此前「死路」结论疑为订阅错 Events 通道。本探针与弹窗流程并行、只打日志不改变加载行为。
--   注意：主加载回调 StorageOnFileList 不校验 id，探针结果会先到达并被它消费（同为
--   Saves\Single 的 GAME_CONFIGURATION 列表，内容等价，属预期）。
-- 判定：Lua.log 中 MPT_DS QUERY 行（ok=直查可用→后续去掉弹窗；timeout=维持弹窗路径）。
-- ============================================================================
local STORAGE_PROBE_TIMEOUT : number = 10;			-- 直查探针超时秒数
local g_storageProbeId      = nil;					-- 直查请求 ID（非 nil 表示探针在途）
local g_storageProbeTime    : number = 0;			-- 探针发起时刻

local StorageProbeOnFileList, StorageProbeTick;		-- 本区回调互引用前向声明

-- ============================================================================
-- 【临时调试】探针回调：认领本探针的查询结果，逐条打文件名后释放查询
-- ============================================================================
StorageProbeOnFileList = function(fileList : table, id : number)
	if g_storageProbeId == nil or id ~= g_storageProbeId then return; end	-- 只认领本探针的查询
	LuaEvents.FileListQueryResults.Remove(StorageProbeOnFileList);
	Events.GameCoreEventPublishComplete.Remove(StorageProbeTick);
	local count : number = 0;
	for _, file in pairs(fileList or {}) do
		count = count + 1;
		print("MPT_DS QUERY FILE", file.Name, "LastModified=", tostring(file.LastModified));
	end
	print("MPT_DS QUERY ok requestID=", id, "文件数=", count);
	pcall(function() UI.CloseFileListQuery(g_storageProbeId); end);
	g_storageProbeId = nil;
end

-- ============================================================================
-- 【临时调试】探针看门狗：超时无回调则判直查不可用，退订并释放查询
-- ============================================================================
StorageProbeTick = function()
	if g_storageProbeId == nil then
		Events.GameCoreEventPublishComplete.Remove(StorageProbeTick);
		return;
	end
	if os.time() - g_storageProbeTime < STORAGE_PROBE_TIMEOUT then return; end
	Events.GameCoreEventPublishComplete.Remove(StorageProbeTick);
	LuaEvents.FileListQueryResults.Remove(StorageProbeOnFileList);
	pcall(function() UI.CloseFileListQuery(g_storageProbeId); end);
	g_storageProbeId = nil;
	print("MPT_DS QUERY timeout（" .. STORAGE_PROBE_TIMEOUT .. " 秒无回调），维持弹窗加载路径");
end

-- ============================================================================
-- 【临时调试】探针发起：直查 Saves\Single 的 GAME_CONFIGURATION 列表；
-- 附带验证 GAME_CONFIGURATION 带 Path 字段是否被引擎接受（官方仅 WORLDBUILDER_MAP 用 Path，
-- SaveGameMenu.lua:58-61）：目标写 Saves 根目录 MPT_PathTest，生效则落在该处，否则在 Saves\Single。
-- ============================================================================
local function StorageProbeStart()
	if g_storageProbeId ~= nil then return; end
	local okPath, savePath = pcall(function()
		return UI.GetSaveLocationPath(SaveLocations.LOCAL_STORAGE, SaveTypes.SINGLE_PLAYER, SaveLocationOptions.NO_OPTIONS, false);
	end);
	print("MPT_DS QUERY 存档目录=", okPath and tostring(savePath) or "获取失败");
	LuaEvents.FileListQueryResults.Add(StorageProbeOnFileList);
	g_storageProbeTime = os.time();
	Events.GameCoreEventPublishComplete.Add(StorageProbeTick);
	local okQuery, queryId = pcall(function()
		return UI.QuerySaveGameList(SaveLocations.LOCAL_STORAGE, SaveTypes.SINGLE_PLAYER, SaveLocationOptions.NORMAL + SaveLocationOptions.LOAD_METADATA, SaveFileTypes.GAME_CONFIGURATION);
	end);
	if okQuery and queryId ~= nil then
		g_storageProbeId = queryId;
		print("MPT_DS QUERY 直查已发起 requestID=", queryId);
	else
		print("MPT_DS QUERY 直查调用失败：", tostring(queryId));
	end
	if okPath and type(savePath) == "string" then
		local savesRoot = string.match(savePath, "^(.*)[/\\][^/\\]+$");
		if savesRoot ~= nil then
			local testPath : string = savesRoot .. "/MPT_PathTest";
			pcall(function()
				Network.SaveGame({ Name = "MPT_PathTest", Type = SaveTypes.SINGLE_PLAYER, FileType = SaveFileTypes.GAME_CONFIGURATION, Path = testPath });
			end);
			print("MPT_DS QUERY Path探针已请求，目标=", testPath, "（用后删除该测试文件）");
		end
	end
end

-- ============================================================================
-- 启动引导：本文件随空 Context 在前端启动时运行。轮询等待主菜单 LoadGameMenu 控件
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
	StorageProbeStart();	-- 【临时调试】Phase 2 探针（与弹窗流程并行，冒烟后删除）
	MPT_Storage_Init();
end
g_storageBootTime = os.time();
Events.GameCoreEventPublishComplete.Add(StorageBootTick);
print("MPT_DS: 启动引导已注册（等待主菜单 LoadGameMenu 控件）");
