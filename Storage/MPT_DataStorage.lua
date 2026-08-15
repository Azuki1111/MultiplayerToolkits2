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
--   .Civ6Cfg 配置存档（文档\My Games\Sid Meier's Civilization VI\Saves\Single）；
--   读取时 Network.LoadGame 载入该配置存档，再 GameConfiguration.GetValue 取回。
--
-- 相对 PKU 原实现的优化/裁剪：
--   1. 仅前端环境（本 mod 是纯前端 mod）：砍掉 InGame 分支、ExposedMembers 跨环境
--      缓存、联机同步、配置 UI 自动生成、ModDataIds 注册表、版本迁移钩子（1746 行框架 → 本文件）；
--   2. 压缩择优：PKU 无条件 Deflate 压缩 + EncodeForPrint（编码 +33% 体积），短数据反而
--      膨胀；本模块压缩后与原串比长度谁小存谁，前缀 'C:'=压缩编码 / 'P:'=明文，读端按前缀分流；
--   3. 序列化换用本 mod 的 MPT_Serialize（紧凑输出，压缩前体积更小）；
--   4. 键名统一 MPT_DS_ 前缀 + 索引键记名登记（GameConfiguration 无键枚举 API，
--      PKU 靠核心 mod 键存注册表，此处同理简化）；
--   5. 覆盖写入前先清旧块（上次 3 块本次 1 块时残留旧块会污染拼接读取）。
--
-- 数据布局（GameConfiguration 键）：
--   MPT_DS__Index          索引：编码后的 dataId 数组（记名制，读取时按名取回）
--   MPT_DS_<dataId>        单块：编码串（字符串）；多块：块数（数字）
--   MPT_DS_<dataId>_<i>    第 i 块（每块 STORAGE_CHUNK_SIZE 字符）
--
-- 用法：
--   MPT_Storage_Init();                          -- 进准备房间时调用一次（幂等），异步加载
--   LuaEvents.MPT_Storage_Ready.Add(fn);         -- 加载完成（或全新无存档）后触发
--   if MPT_Storage_IsReady() then ... end
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
local STORAGE_CHUNK_SIZE   : number = 2000;				-- 单值切块长度（1.67/PKU 长期沿用的安全值；调大需先实测上限）
local STORAGE_MAX_RELOAD   : number = 3;				-- 读取失败最大重试次数
local STORAGE_PREFIX_PLAIN : string = "P:";				-- 编码串前缀：明文（序列化源码）
local STORAGE_PREFIX_COMPR : string = "C:";				-- 编码串前缀：Deflate 压缩 + EncodeForPrint
local STORAGE_QUERY_TIMEOUT: number = 3;				-- 文件列表 API 查询超时秒数（超时回退弹窗方式）

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
local g_storageQueryTime  : number = 0;			-- 文件列表查询发起时刻（os.time 墙钟）

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
-- 覆盖写入前必须先清：上次 3 块本次 1 块时，残留的 _2/_3 旧块会污染拼接读取。
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
		print("MPT_DataStorage: 非法 dataId", dataId);
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
-- ============================================================================
function MPT_Storage_Save()
	if not g_storageReady then
		print("MPT_DataStorage: 尚未完成加载，忽略保存（防止空缓存覆盖磁盘数据）");
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
	print("MPT_DataStorage: 已请求保存 " .. STORAGE_FILE_NAME .. ".Civ6Cfg（" .. #ids .. " 项）");
end

-- ============================================================================
-- 内部：SaveComplete 回调——落盘完成后清掉 GameConfiguration 里的 MPT_DS_ 键，
-- 防止键值混入准备房间配置与真实游戏存档（PKU InGame 同款清理思路）。
-- 若前端不触发 SaveComplete（Phase0 实测项），键残留会话内 GameConfiguration，
-- 下次 Save 会重写，无害但会混入本局游戏存档，待实测后定论。
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
	local ids = StorageReadKey(STORAGE_KEY_PREFIX .. STORAGE_INDEX_ID);
	if type(ids) ~= "table" then
		if g_storageReloadNum < STORAGE_MAX_RELOAD then
			g_storageReloadNum = g_storageReloadNum + 1;
			print("MPT_DataStorage: 读取索引失败，重试第 " .. g_storageReloadNum .. " 次");
			g_storageLoading = false;
			MPT_Storage_Init();		-- 重新走完整加载流程
		else
			print("MPT_DataStorage: 读取失败超过上限，本次启动放弃加载（磁盘数据未改动）");
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
			print("MPT_DataStorage: dataId " .. tostring(dataId) .. " 读取失败，跳过");
		end
	end
	g_storageReady = true;
	g_storageLoading = false;
	StorageCloseLoadMenu();
	print("MPT_DataStorage: 加载完成，共 " .. #ids .. " 项");
	LuaEvents.MPT_Storage_Ready();
end

-- ============================================================================
-- 内部：文件列表回调（LuaEvents.FileListQueryResults）。
-- 找到 MPT_ModData.Civ6Cfg 则 LoadGame 载入；未找到按全新数据启动（非失败）。
-- ============================================================================
StorageOnFileList = function(fileList, id)
	LuaEvents.FileListQueryResults.Remove(StorageOnFileList);
	if not g_storageLoading then return; end
	for _, file in pairs(fileList or {}) do
		if file.Name == STORAGE_FILE_NAME .. ".Civ6Cfg" then
			Events.LoadComplete.Add(StorageOnLoadComplete, 1);	-- 第二参沿用 PKU 实证写法
			Network.LoadGame(file, 0);
			return;
		end
	end
	g_storageReady = true;
	g_storageLoading = false;
	StorageCloseLoadMenu();
	print("MPT_DataStorage: 未找到 " .. STORAGE_FILE_NAME .. ".Civ6Cfg，按全新数据启动");
	LuaEvents.MPT_Storage_Ready();
end

-- ============================================================================
-- 内部：文件列表查询方式一——UI.QuerySaveGameList 直接查询（不开系统菜单）。
-- 可用性为 Phase0 实测项；调用不报错不代表会触发 FileListQueryResults，靠看门狗兜底。
-- ============================================================================
local function StorageRequestFileListByAPI()
	if UI.QuerySaveGameList == nil then return false; end
	local ok = pcall(UI.QuerySaveGameList, "Single");
	print("MPT_DataStorage: UI.QuerySaveGameList 调用结果", ok);
	return ok;
end

-- ============================================================================
-- 内部：文件列表查询方式二——QueuePopup 打开 LoadGameMenu 触发查询（PKU 实证可用路径）。
-- 菜单会短暂闪现覆盖当前界面（每次启动至多一次）；拿到列表后立即关闭。
-- ============================================================================
local function StorageRequestFileListByMenu()
	g_storageLoadMenu = ContextPtr:LookUpControl("/FrontEnd/MainMenu/LoadGameMenu");
	if g_storageLoadMenu == nil then
		print("MPT_DataStorage: 找不到 /FrontEnd/MainMenu/LoadGameMenu 控件，加载中止");
		g_storageLoading = false;
		return;
	end
	if g_storageLoadMenu:IsHidden() then
		UIManager:QueuePopup(g_storageLoadMenu, PopupPriority.Current, { FileType = SaveFileTypes.GAME_CONFIGURATION });
	end
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
-- 内部：查询看门狗——API 方式超时未收到 FileListQueryResults 则回退弹窗方式。
-- （GameCoreEventPublishComplete 为高频事件；os.time 墙钟判定，参照条目4.1修复先例）
-- ============================================================================
local function StorageQueryWatchdog()
	if not g_storageLoading then
		Events.GameCoreEventPublishComplete.Remove(StorageQueryWatchdog);
		return;
	end
	if os.time() - g_storageQueryTime < STORAGE_QUERY_TIMEOUT then return; end
	Events.GameCoreEventPublishComplete.Remove(StorageQueryWatchdog);
	print("MPT_DataStorage: 文件列表 API 查询超时，回退 LoadGameMenu 弹窗方式");
	StorageRequestFileListByMenu();
end

-- ============================================================================
-- 对外：初始化并异步加载（幂等）。完成或全新启动后触发 LuaEvents.MPT_Storage_Ready。
-- ============================================================================
function MPT_Storage_Init()
	if g_storageReady or g_storageLoading then return; end
	g_storageLoading = true;
	LuaEvents.FileListQueryResults.Add(StorageOnFileList);
	g_storageQueryTime = os.time();
	Events.GameCoreEventPublishComplete.Add(StorageQueryWatchdog);
	StorageRequestFileListByAPI();
end
