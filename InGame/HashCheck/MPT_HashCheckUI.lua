-- ============================================================================
-- 条目34：反作弊监测面板（移植工坊 3775385784「反作弊监控 0.2.5」UI/HashCheckInGameUI.lua，
-- 作者 Synora 即本 mod 作者；UI 逻辑原样移植）
-- 数据链路：HashCheck_GameCores.sql 把 GS 引擎核心重定向到本 mod 钩子 DLL（criteria
-- MPT_HASH_CHECK 门控）→ DLL 注入 HashCheckDLL 全局并后台聚合哈希本机全部启用文件 →
-- 联机经引擎玩家信息通道交换证明 → 本面板按玩家比对显示 一致/不一致/等待数据。
-- DLL 未加载（未勾选开关 / 无 GS / DllPrefix 被其他钩子 mod 抢占）时优雅降级：
-- HashCheckDLL == nil 守卫 → 全员显示「等待数据...」，面板本身可用。
-- 入口改造（用户裁决）：删除原版 LaunchBar 注入（AttachLaunchButton 全套），改由
-- 条目8 MPT_QuickPanel「反作弊监测」按钮经 LuaEvents.MPT_HashCheck_Toggle 开关。
-- 注意：GetNetworkIdentifer 为引擎 API 历史拼写（原版 StagingRoom/ChatPanel 同款），不可"纠正"。
-- ============================================================================
local MONITOR_START_TURN :number = 2;	-- 回合 1 不监控（开局载入尚未稳定，从首回合结束后的回合开始拉取）

include("InstanceManager");

-- 文本预加载（项目规约：无参数纯文本 tag 集中缓存；带参数文本改无参数 tag + Lua .. 拼接）
local HashCheckStatusOkStr		= Locale.Lookup("LOC_MPT_HASHCHECK_STATUS_OK");
local HashCheckStatusMismatchStr	= Locale.Lookup("LOC_MPT_HASHCHECK_STATUS_MISMATCH");
local HashCheckStatusUnknownStr	= Locale.Lookup("LOC_MPT_HASHCHECK_STATUS_UNKNOWN");
local HashCheckEntryTTStr		= Locale.Lookup("LOC_MPT_HASHCHECK_ENTRY_TT");
local HashCheckEntryTTNoidStr	= Locale.Lookup("LOC_MPT_HASHCHECK_ENTRY_TT_NOID");

local m_PlayerListIM	= InstanceManager:new("PlayerStatusEntry", "RootContainer", Controls.PlayerListStack);
local m_ReceivedProof	= {};
local m_PanelOpen		= false;
local m_MonitorStarted	= false;

local STATUS_STYLE = {
	ok       = { text = HashCheckStatusOkStr,       color = "StatGoodCS"   },
	mismatch = { text = HashCheckStatusMismatchStr, color = "StatBadCS"    },
	unknown  = { text = HashCheckStatusUnknownStr,  color = "BodyTextCool" },
};

-- 当前回合数（pcall 防御，取不到按 0 = 未开始监控处理）
local function GetCurrentTurn()
	if Game and Game.GetCurrentGameTurn then
		local ok, t = pcall(Game.GetCurrentGameTurn);
		if ok and type(t) == "number" then return t end
	end
	return 0;
end

-- 监控是否已激活（≥ MONITOR_START_TURN）
local function IsMonitoringActive()
	return GetCurrentTurn() >= MONITOR_START_TURN;
end

-- 本地玩家 ID（Network 优先，Game 兜底，全 pcall）
local function GetLocalPlayerID()
	if Network and Network.GetLocalPlayerID then
		local ok, pid = pcall(Network.GetLocalPlayerID);
		if ok and pid ~= nil then return pid end;
	end
	if Game and Game.GetLocalPlayer then
		local ok, pid = pcall(Game.GetLocalPlayer);
		if ok and pid ~= nil then return pid end;
	end
	return nil;
end

-- 其他存活真人玩家 ID 列表（排除自己；观察者局 AI 与自己均不入列）
local function GetRemoteHumanPlayerIDs()
	local ids = {};
	if not PlayerManager or not PlayerManager.GetAliveMajorIDs then return ids end
	local ok, majorIDs = pcall(PlayerManager.GetAliveMajorIDs);
	if not ok or type(majorIDs) ~= "table" then return ids end
	local localPlayerID = GetLocalPlayerID();
	for _, playerID in ipairs(majorIDs) do
		if playerID ~= localPlayerID then
			local cfg = PlayerConfigurations[playerID];
			local isHuman = false;
			if cfg then
				local ok2, h = pcall(function() return cfg:IsHuman() end);
				isHuman = ok2 and h == true;
			end
			if isHuman then table.insert(ids, playerID) end
		end
	end
	return ids;
end

-- 玩家显示名（取不到回退 "Player N"）
local function GetPlayerDisplayName(playerID)
	local cfg = PlayerConfigurations[playerID];
	if cfg then
		local ok, name = pcall(function() return cfg:GetPlayerName() end);
		if ok and name and name ~= "" then return Locale.Lookup(name) end
	end
	return "Player " .. tostring(playerID);
end

-- 玩家 Steam ID（引擎 typo API，见头部注意）
local function GetPlayerSteamID(playerID)
	local cfg = PlayerConfigurations[playerID];
	if cfg then
		local ok, id = pcall(function() return cfg:GetNetworkIdentifer() end);
		if ok and id and id ~= "" then return tostring(id) end
	end
	return nil;
end

-- 玩家领袖图标名（原版图集，取不到回退默认头像）
local function GetLeaderIconName(playerID)
	local cfg = PlayerConfigurations[playerID];
	if cfg then
		local ok, leaderType = pcall(function() return cfg:GetLeaderTypeName() end);
		if ok and leaderType and leaderType ~= "" then
			return "ICON_" .. leaderType;
		end
	end
	return "ICON_LEADER_DEFAULT";
end

-- 点击条目：复制「玩家名 SteamID」到剪贴板（举报/核对用）
local function CopyPlayerInfo(playerID)
	local name = GetPlayerDisplayName(playerID);
	local steamID = GetPlayerSteamID(playerID);
	local text = (steamID ~= nil) and (name .. " " .. steamID) or name;
	if UIManager and UIManager.SetClipboardString then
		UIManager:SetClipboardString(text);
	end
end

-- 玩家文件状态：无证明 = unknown；DLL 比对通过 = ok；否则 mismatch
local function GetPlayerCheckStatus(playerID)
	if not m_ReceivedProof[playerID] then return "unknown" end
	if HashCheckDLL ~= nil and HashCheckDLL("CheckHash", playerID) then return "ok" end
	return "mismatch";
end

-- 全量重建玩家列表（PlayerInfoChanged / 回合开始触发，频率低可接受）
local function RefreshPanel()
	if not m_PlayerListIM then return end
	m_PlayerListIM:ResetInstances();
	local ids = GetRemoteHumanPlayerIDs();
	Controls.NoPlayersLabel:SetHide(#ids > 0);
	for _, playerID in ipairs(ids) do
		local inst = m_PlayerListIM:GetInstance();
		inst.LeaderIcon:SetIcon(GetLeaderIconName(playerID));
		inst.PlayerName:SetText(GetPlayerDisplayName(playerID));
		local style = STATUS_STYLE[GetPlayerCheckStatus(playerID)];
		inst.StatusLabel:SetText(style.text);
		inst.StatusLabel:SetColorByName(style.color);
		local steamID = GetPlayerSteamID(playerID);
		if steamID then
			-- 带参数文本改无参数 tag 缓存 + .. 拼接（项目规约）
			inst.EntryButton:SetToolTipString("Steam ID: " .. steamID .. "[NEWLINE]" .. HashCheckEntryTTStr);
		else
			inst.EntryButton:SetToolTipString(HashCheckEntryTTNoidStr);
		end
		inst.EntryButton:RegisterCallback(Mouse.eLClick, function() CopyPlayerInfo(playerID) end);
	end
	Controls.PlayerListStack:CalculateSize();
end

-- 打开面板（AddUserInterfaces 上下文默认隐藏，先升 ContextPtr 再刷数据）
local function OpenPanel()
	m_PanelOpen = true;
	RefreshPanel();
	ContextPtr:SetHide(false);
end

local function ClosePanel()
	m_PanelOpen = false;
	ContextPtr:SetHide(true);
end

local function TogglePanel()
	if m_PanelOpen then ClosePanel() else OpenPanel() end
end

-- 通知 DLL 进入工作状态（建立 mod 索引并启动后台哈希；DLL 未加载时返回 false 优雅降级）
local function InitializeDLLState()
	if HashCheckDLL == nil then return false end
	local ok, res = pcall(function() return HashCheckDLL("Init") end);
	return ok and res == true;
end

-- 收到远端玩家信息推送 → 存其证明并刷新（本机自己的推送跳过）
local function ProcessRemoteProof(playerID)
	if HashCheckDLL == nil then return end
	local ok, stored = pcall(function() return HashCheckDLL("StoreRemoteProof", playerID) end);
	if ok and stored == true then
		m_ReceivedProof[playerID] = true;
		RefreshPanel();
	end
end

local function OnPlayerInfoChanged(playerID)
	if not IsMonitoringActive() then return end
	if HashCheckDLL == nil then return end
	local localPlayerID = GetLocalPlayerID();
	if localPlayerID ~= nil and playerID == localPlayerID then return end
	ProcessRemoteProof(playerID);
end

-- 本地回合开始：首个达标回合一次性拉取全部远端证明，之后完全依赖 PlayerInfoChanged
local function OnLocalPlayerTurnBegin()
	if IsMonitoringActive() and not m_MonitorStarted then
		m_MonitorStarted = true;
		for _, playerID in ipairs(GetRemoteHumanPlayerIDs()) do
			ProcessRemoteProof(playerID);
		end
	end

	RefreshPanel();
end

-- 局加载完成：只初始化 DLL 状态（按钮注入已随入口改造移除，见头部说明）
local function OnLoadScreenClose()
	InitializeDLLState();
end

-- 事件订阅 pcall 包裹（引擎事件缺失时不中断本上下文加载）
local function SafeAdd(eventTable, eventName, handler)
	if eventTable and eventTable[eventName] and eventTable[eventName].Add then
		pcall(function() eventTable[eventName].Add(handler) end);
	end
end

Controls.CloseButton:RegisterCallback(Mouse.eLClick, ClosePanel);
ContextPtr:SetHide(true);

-- 条目8：QuickPanel「反作弊监测」按钮 → 开/关本面板（跨 Context；条目11/12 同款）
LuaEvents.MPT_HashCheck_Toggle.Add(TogglePanel);

SafeAdd(Events, "LoadScreenClose", OnLoadScreenClose);
SafeAdd(Events, "PlayerInfoChanged", OnPlayerInfoChanged);
SafeAdd(Events, "LocalPlayerTurnBegin", OnLocalPlayerTurnBegin);
