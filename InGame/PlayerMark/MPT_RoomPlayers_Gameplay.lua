-- ============================================================================
-- MPT_RoomPlayers_Gameplay.lua（条目4.9：房间玩家集合快照，Gameplay 侧）
--
-- 用途：供 InGame 玩家标记面板「房间玩家」页签读档——用 Game:SetProperty 把对局内
--   所有玩家信息持久化为快照，UI 侧用 Game:GetProperty 读取显示。
--   显示范围定义（用户确认）：所有**非自己**玩家，**含观察者、含当前不在线**的；
--   游戏中途加入的玩家也要显示（追加）。
--
-- 数据：每玩家一个 property（存表，乔尔 MiniRecord 实证 Game:SetProperty 支持 table value）：
--   Game:SetProperty("MPT_RoomPlayer_"..playerID, { nid=网络ID, name=玩家名tag/原样, leader=领袖Type });
--   另有 playerID 有序列表：Game:SetProperty("MPT_RoomPlayerList", {id1, id2, ...})。
--   掉线/退出不删 property（「不在线仍显示」）。
--
-- 初始化/追加：
--   1) 脚本加载即补存全部玩家（覆盖「开局已存在玩家」——脚本加载可能晚于加入事件）；
--   2) GameEvents.PlayerAddedToGame：中途加入玩家时追加；
--   3) GameEvents.OnGameTurnStarted：首个回合补存兜底（防漏）。
--
-- 注册：AddGameplayScripts(Context=InGame)。UI 侧刷新订阅引擎事件（Events.PlayerJoined 等），
--   本脚本不 emit GameEvents（UI 不订阅 Gameplay 侧事件）；UI 读 GetProperty + 自己刷新。
-- ============================================================================

-- 幂等守卫：本文件可能被多次 include（防御），只执行一次
if MPT_RoomPlayers_Gameplay_Loaded then return; end

-- ============================================================================
-- MPT_RoomPlayers_ReadList / WriteList：读/写 playerID 有序列表 property。
-- ============================================================================
local function MPT_RoomPlayers_ReadList()
	local list = Game:GetProperty("MPT_RoomPlayerList");
	if type(list) == "table" then return list; end
	return {};
end

local function MPT_RoomPlayers_WriteList(list)
	Game:SetProperty("MPT_RoomPlayerList", list);
end

-- ============================================================================
-- MPT_RoomPlayers_SetPlayer(playerID)：把单个玩家信息写入快照 + 追加到列表（幂等）。
--   过关：cfg 无效则跳过（观察者/掉线槽位 PlayerConfigurations 仍有效，正常写入）。
-- ============================================================================
local function MPT_RoomPlayers_SetPlayer(playerID : number)
	local cfg = PlayerConfigurations[playerID];
	if cfg == nil then return; end
	local leader = cfg:GetLeaderTypeName();
	Game:SetProperty("MPT_RoomPlayer_" .. playerID, {
		nid = cfg:GetNetworkIdentifer() or "",
		name = cfg:GetPlayerName() or "",		-- 可能是 LOC tag 或原样名；UI 侧 Locale.Lookup 解析
		leader = (leader ~= nil) and leader or "",
	});
	local list = MPT_RoomPlayers_ReadList();
	local exists = false;
	for _, i in ipairs(list) do
		if i == playerID then exists = true; break; end
	end
	if not exists then
		table.insert(list, playerID);
		MPT_RoomPlayers_WriteList(list);
	end
end

-- ============================================================================
-- MPT_RoomPlayers_InitAll()：初始化——补存全部玩家（非自己：用户确认排除自己；
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

-- 脚本加载即补存
MPT_RoomPlayers_InitAll();

-- 幂等守卫置位（文件末尾：全部定义成功才置位）
MPT_RoomPlayers_Gameplay_Loaded = true;
