local MONITOR_START_TURN :number = 2;
include("InstanceManager");
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
local function GetCurrentTurn()
	if Game and Game.GetCurrentGameTurn then
		local ok, t = pcall(Game.GetCurrentGameTurn);
		if ok and type(t) == "number" then return t end
	end
	return 0;
end
local function IsMonitoringActive()
	return GetCurrentTurn() >= MONITOR_START_TURN;
end
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
local function GetPlayerDisplayName(playerID)
	local cfg = PlayerConfigurations[playerID];
	if cfg then
		local ok, name = pcall(function() return cfg:GetPlayerName() end);
		if ok and name and name ~= "" then return Locale.Lookup(name) end
	end
	return "Player " .. tostring(playerID);
end
local function GetPlayerSteamID(playerID)
	local cfg = PlayerConfigurations[playerID];
	if cfg then
		local ok, id = pcall(function() return cfg:GetNetworkIdentifer() end);
		if ok and id and id ~= "" then return tostring(id) end
	end
	return nil;
end
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
local function CopyPlayerInfo(playerID)
	local name = GetPlayerDisplayName(playerID);
	local steamID = GetPlayerSteamID(playerID);
	local text = (steamID ~= nil) and (name .. " " .. steamID) or name;
	if UIManager and UIManager.SetClipboardString then
		UIManager:SetClipboardString(text);
	end
end
local function GetPlayerCheckStatus(playerID)
	if not m_ReceivedProof[playerID] then return "unknown" end
	if Mzq ~= nil and Mzq("c", playerID) == 1 then return "ok" end
	return "mismatch";
end
local function GetDigestPair(playerID)
	if Mzq == nil then return "" end
	local okD, mine = pcall(function() return Mzq("d") end);
	local okE, theirs = pcall(function() return Mzq("e", playerID) end);
	if not okD or not okE then return "" end
	return tostring(mine or "") .. " / " .. tostring(theirs or "");
end
local function RefreshPanel()
	if not m_PlayerListIM then return end
	m_PlayerListIM:ResetInstances();
	local ids = GetRemoteHumanPlayerIDs();
	Controls.NoPlayersLabel:SetHide(#ids > 0);
	for _, playerID in ipairs(ids) do
		local inst = m_PlayerListIM:GetInstance();
		local status = GetPlayerCheckStatus(playerID);
		inst.LeaderIcon:SetIcon(GetLeaderIconName(playerID));
		inst.PlayerName:SetText(GetPlayerDisplayName(playerID));
		local style = STATUS_STYLE[status];
		inst.StatusLabel:SetText(style.text);
		inst.StatusLabel:SetColorByName(style.color);
		local steamID = GetPlayerSteamID(playerID);
		local tooltip;
		if steamID then
			tooltip = "Steam ID: " .. steamID .. "[NEWLINE]" .. HashCheckEntryTTStr;
		else
			tooltip = HashCheckEntryTTNoidStr;
		end
		if status == "mismatch" then
			local diag = GetDigestPair(playerID);
			if diag ~= "" and diag ~= " / " then
				tooltip = tooltip .. "[NEWLINE]" .. diag;
			end
		end
		inst.EntryButton:SetToolTipString(tooltip);
		inst.EntryButton:RegisterCallback(Mouse.eLClick, function() CopyPlayerInfo(playerID) end);
	end
	Controls.PlayerListStack:CalculateSize();
end
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
local function InitializeDLLState()
	if Mzq == nil then return false end
	local ok, res = pcall(function() return Mzq("a") end);
	return ok and res == 1;
end
local function ProcessRemoteProof(playerID)
	if Mzq == nil then return end
	local ok, stored = pcall(function() return Mzq("b", playerID) end);
	if ok and stored == 1 then
		m_ReceivedProof[playerID] = true;
		RefreshPanel();
	end
end
local function OnPlayerInfoChanged(playerID)
	if not IsMonitoringActive() then return end
	if Mzq == nil then return end
	local localPlayerID = GetLocalPlayerID();
	if localPlayerID ~= nil and playerID == localPlayerID then return end
	ProcessRemoteProof(playerID);
end
local function OnLocalPlayerTurnBegin()
	if IsMonitoringActive() and not m_MonitorStarted then
		m_MonitorStarted = true;
		for _, playerID in ipairs(GetRemoteHumanPlayerIDs()) do
			ProcessRemoteProof(playerID);
		end
	end
	RefreshPanel();
end
local function OnLoadScreenClose()
	InitializeDLLState();
end
local function SafeAdd(eventTable, eventName, handler)
	if eventTable and eventTable[eventName] and eventTable[eventName].Add then
		pcall(function() eventTable[eventName].Add(handler) end);
	end
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, ClosePanel);
ContextPtr:SetHide(true);
LuaEvents.MPT_HashCheck_Toggle.Add(TogglePanel);
SafeAdd(Events, "LoadScreenClose", OnLoadScreenClose);
SafeAdd(Events, "PlayerInfoChanged", OnPlayerInfoChanged);
SafeAdd(Events, "LocalPlayerTurnBegin", OnLocalPlayerTurnBegin);
