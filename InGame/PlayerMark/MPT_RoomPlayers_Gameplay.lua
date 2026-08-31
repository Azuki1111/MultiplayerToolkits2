-- ============================================================================
-- MPT_RoomPlayers_Gameplay.lua（条目4.9：房间玩家集合快照，Gameplay 侧）
--
-- 用途：供 InGame 玩家标记面板「房间玩家」页签读档——把对局内所有玩家信息做成快照，
--   UI 侧读取显示。显示范围定义（用户确认）：所有**非自己**玩家，**含观察者、含当前
--   不在线**的；游戏中途加入的玩家也要显示（追加）。
--
-- 数据分层（条目4.9修复+重构）：
--   ① 对局持久层：Game:SetProperty / GetProperty——快照随存档保存/读回，信息正确存进对局：
--       Game:SetProperty("MPT_RoomPlayer_"..playerID, { nid=, name=, leader= })
--       Game:SetProperty("MPT_RoomPlayerList", {id1, id2, ...})
--   ② UI 交互通道：ExposedMembers.MPT_RoomPlayers = { List={}, Players={} }——内存态快照
--       挂共享表（ui-gameplay-bridge 模式），UI 直读、不再逐条 GetProperty
--   本脚本双写同步：脚本加载时从持久层回灌内存态（读档数据不丢）→ 事件驱动更新时双写；
--   写持久层前与内存态旧值比对，未变化跳过（回合开始兜底全量扫时省联机属性同步流量）。
--
-- 修复（条目4.9修复）：GetNetworkIdentifer / GetPlayerName 在 Gameplay 脚本环境不存在
--   （原版仅 UI 侧调用，如 ChatPanel/StagingRoom；实测 GetNetworkIdentifer 报
--   "function expected instead of nil" 崩溃致本脚本加载失败、快照从未写入），
--   方法存在性防御取值，取不到存空串；UI 侧（条目11 MPT_PlayerMark_RebuildRoomList）
--   读共享表时用 InGame UI 环境实时补全。
--
-- 掉线/退出不删快照（「不在线仍显示」）。存储含全部玩家（含自己），UI 侧显示时排除自己。
--
-- 初始化/追加：
--   1) 脚本加载即回灌持久层 + 补存全部玩家（覆盖「开局已存在玩家」——脚本加载可能晚于加入事件）；
--   2) GameEvents.PlayerAddedToGame：中途加入玩家时追加；
--   3) GameEvents.OnGameTurnStarted：首个回合补存兜底（防漏）。
--
-- 注册：AddGameplayScripts(Context=InGame)。UI 侧刷新订阅引擎事件（Events.PlayerJoined 等），
--   本脚本不 emit GameEvents（UI 不订阅 Gameplay 侧事件）；UI 读 ExposedMembers + 自己刷新。
-- ============================================================================

-- 幂等守卫：本文件可能被多次 include（防御），只执行一次
if MPT_RoomPlayers_Gameplay_Loaded then return; end

-- ============================================================================
-- 数据分层初始化：ExposedMembers 共享表（UI 交互通道）+ GameProperties（对局持久层）
-- ============================================================================
ExposedMembers.MPT_RoomPlayers = ExposedMembers.MPT_RoomPlayers or { List = {}, Players = {} };
local MPT_RoomPlayers_Data = ExposedMembers.MPT_RoomPlayers;

-- ============================================================================
-- MPT_RoomPlayers_ReadList()：从对局持久层读回 playerID 有序列表。
-- ============================================================================
local function MPT_RoomPlayers_ReadList()
	local list = Game:GetProperty("MPT_RoomPlayerList");
	if type(list) == "table" then return list; end
	return {};
end

-- ============================================================================
-- MPT_RoomPlayers_LoadFromGame()：脚本加载/读档时——持久层 → ExposedMembers 内存态回灌。
-- ============================================================================
local function MPT_RoomPlayers_LoadFromGame()
	MPT_RoomPlayers_Data.List = MPT_RoomPlayers_ReadList();
	MPT_RoomPlayers_Data.Players = {};
	for _, playerID in ipairs(MPT_RoomPlayers_Data.List) do
		local snap = Game:GetProperty("MPT_RoomPlayer_" .. playerID);
		if type(snap) == "table" then
			MPT_RoomPlayers_Data.Players[playerID] = snap;
		end
	end
end

-- ============================================================================
-- MPT_RoomPlayers_InList(playerID)：playerID 是否已在快照列表。
-- ============================================================================
local function MPT_RoomPlayers_InList(playerID : number)
	for _, i in ipairs(MPT_RoomPlayers_Data.List) do
		if i == playerID then return true; end
	end
	return false;
end

-- ============================================================================
-- MPT_RoomPlayers_SetPlayer(playerID)：写入单个玩家快照——持久层 + 内存态双写，幂等。
--   过关：cfg 无效则跳过（观察者/掉线槽位 PlayerConfigurations 仍有效，正常写入）。
-- ============================================================================
local function MPT_RoomPlayers_SetPlayer(playerID : number)
	local cfg = PlayerConfigurations[playerID];
	if cfg == nil then return; end
	local leader = cfg:GetLeaderTypeName();
	-- ==== 条目4.9修复：Gameplay 脚本环境无 GetNetworkIdentifer / GetPlayerName（原版仅 UI 侧
	-- 调用，实测 GetNetworkIdentifer 报 "function expected instead of nil" 崩溃致脚本加载失败），
	-- 方法存在性防御取值，取不到存空串；UI 侧读共享表时用 InGame UI 环境实时补全
	-- 旧代码：
	-- Game:SetProperty("MPT_RoomPlayer_" .. playerID, {
	-- 	nid = cfg:GetNetworkIdentifer() or "",
	-- 	name = cfg:GetPlayerName() or "",		-- 可能是 LOC tag 或原样名；UI 侧 Locale.Lookup 解析
	-- 	leader = (leader ~= nil) and leader or "",
	-- });
	-- ----
	local nid = "";
	if cfg.GetNetworkIdentifer ~= nil then nid = cfg:GetNetworkIdentifer() or ""; end
	local name = "";
	if cfg.GetPlayerName ~= nil then name = cfg:GetPlayerName() or ""; end	-- 可能是 LOC tag 或原样名；UI 侧 Locale.Lookup 解析
	local snap = {
		nid = nid,
		name = name,
		leader = (leader ~= nil) and leader or "",
	};
	local old = MPT_RoomPlayers_Data.Players[playerID];
	if old ~= nil and old.nid == snap.nid and old.name == snap.name and old.leader == snap.leader then
		return;	-- 未变化不重写（回合开始兜底全量扫时省联机属性同步流量）
	end
	MPT_RoomPlayers_Data.Players[playerID] = snap;					-- 内存态（UI 经 ExposedMembers 直读）
	Game:SetProperty("MPT_RoomPlayer_" .. playerID, snap);			-- 对局持久层（随存档保存）
	if not MPT_RoomPlayers_InList(playerID) then
		table.insert(MPT_RoomPlayers_Data.List, playerID);
		Game:SetProperty("MPT_RoomPlayerList", MPT_RoomPlayers_Data.List);
	end
end

-- ============================================================================
-- MPT_RoomPlayers_InitAll()：初始化——补存全部玩家（含自己，UI 侧显示时排除自己；
--   含观察者/掉线槽位，PlayerConfigurations 均有效）。
-- ============================================================================
local function MPT_RoomPlayers_InitAll()
	if Game == nil then return; end
	for playerID, cfg in pairs(PlayerConfigurations) do
		if cfg ~= nil then
			MPT_RoomPlayers_SetPlayer(playerID);
		end
	end
end

-- ============================================================================
-- 事件订阅 + 初始化
-- ============================================================================

-- 中途加入玩家 → 追加快照
function OnGameEvent_PlayerAddedToGame(playerID)
	MPT_RoomPlayers_SetPlayer(playerID);
end
GameEvents.PlayerAddedToGame.Add(OnGameEvent_PlayerAddedToGame);

-- 首个回合补存兜底（防脚本加载晚于 PlayerAddedToGame 漏存）
GameEvents.OnGameTurnStarted.Add(MPT_RoomPlayers_InitAll);

-- 脚本加载：回灌持久层（读档数据不丢）+ 补存全部
MPT_RoomPlayers_LoadFromGame();
MPT_RoomPlayers_InitAll();

-- 幂等守卫置位（文件末尾：全部定义成功才置位）
MPT_RoomPlayers_Gameplay_Loaded = true;
