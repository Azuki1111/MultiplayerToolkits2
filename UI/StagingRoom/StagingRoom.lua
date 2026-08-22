----------------------------------------------------------------  
-- Staging Room Screen
----------------------------------------------------------------  
include( "InstanceManager" );	--InstanceManager
include( "PlayerSetupLogic" );
include( "NetworkUtilities" );
include( "ButtonUtilities" );
include( "PlayerTargetLogic" );
include( "ChatLogic" );
include( "NetConnectionIconLogic" );
include( "PopupDialog" );
include( "Civ6Common" );
include( "TeamSupport" );
-- ============================================================================
-- 条目4.3预备：序列化与本地数据读写工具【已内联至本文件末尾】（条目4.3预备分区）。
-- 原设计为顶层 include Storage/ 两份独立文件。实测定论：前端 include() 本 mod 经
-- ImportFiles 注册的 Lua 文件，在「开一局游戏再退回主菜单」后的新前端 Lua 状态下
-- 静默不执行（pcall(include) 返回成功与 table，但文件体零执行、无任何报错——引擎缺陷，
-- 单变量实验已排除双环境注册嫌疑，详见 git 条目4.3预备诊断与 AGENTS.md 踩坑记录）。
-- ReplaceUIScript 投递的本文件每次前端重建都可靠重执行，故改为内联承载。
-- Storage/ 独立文件保留给未来游戏内消费方，改动存储/序列化代码必须双向同步。
-- ----------------------------------------------------------------------------


----------------------------------------------------------------  
-- Constants
---------------------------------------------------------------- 
local CountdownTypes = {
	None				= "None",
	Launch				= "Launch",						-- Standard Launch Countdown
	Launch_Instant		= "Launch_Instant",				-- Instant Launch
	WaitForPlayers		= "WaitForPlayers",				-- Used by Matchmaking games after the Ready countdown to try to fill up the game with human players before starting.
	Ready_PlayByCloud	= "Ready_PlayByCloud",
	Ready_MatchMaking	= "Ready_MatchMaking",
};

local TimerTypes = {
	Script 				= "Script",						-- Timer is internally tracked in this script.
	NetworkManager 		= "NetworkManager",				-- Timer is handled by the NetworkManager.  This is synchronized across all the clients in a matchmaking game.
};


----------------------------------------------------------------  
-- Globals
----------------------------------------------------------------  
local g_PlayerEntries = {};					-- All the current player entries, indexed by playerID.
local g_PlayerRootToPlayerID = {};  -- maps the string name of a player entry's Root control to a playerID.
local g_PlayerReady = {};			-- cached player ready status, indexed by playerID.
local g_PlayerModStatus = {};		-- cached player localized mod status strings.
local g_cachedTeams = {};				-- A cached mapping of PlayerID->TeamID.

local m_playerTarget = { targetType = ChatTargetTypes.CHATTARGET_ALL, targetID = GetNoPlayerTargetID() };
local m_playerTargetEntries = {};
local m_ChatInstances		= {};
local m_infoTabsIM:table = InstanceManager:new("ShellTab", "TopControl", Controls.InfoTabs);
local m_shellTabIM:table = InstanceManager:new("ShellTab", "TopControl", Controls.ShellTabs);
local m_friendsIM = InstanceManager:new( "FriendInstance", "RootContainer", Controls.FriendsStack );
local m_playersIM = InstanceManager:new( "PlayerListEntry", "Root", Controls.PlayerListStack );
local g_GridLinesIM = InstanceManager:new( "HorizontalGridLine", "Control", Controls.GridContainer );
local m_gameSetupParameterIM = InstanceManager:new( "GameSetupParameter", "Root", nil );
local m_kPopupDialog:table;
local m_shownPBCReadyPopup = false;			-- Remote clients in a new PlayByCloud game get a ready-to-go popup when
											-- This variable indicates this popup has already been shown in this instance
											-- of the staging room.
local m_savePBCReadyChoice :boolean = false;	-- Should we save the user's PlayByCloud ready choice when they have decided?
local m_exitReadyWait :boolean = false;		-- Are we waiting on a local player ready change to propagate prior to exiting the match?
local m_numPlayers:number;
local m_teamColors = {};
local m_sessionID :number = FireWireTypes.FIREWIRE_INVALID_ID;

-- Additional Content 
local m_modsIM = InstanceManager:new("AdditionalContentInstance", "Root", Controls.AdditionalContentStack);

-- Reusable tooltip control
local m_CivTooltip:table = {};
ContextPtr:BuildInstanceForControl("CivToolTip", m_CivTooltip, Controls.TooltipContainer);
m_CivTooltip.UniqueIconIM = InstanceManager:new("IconInfoInstance",	"Top", m_CivTooltip.InfoStack);
m_CivTooltip.HeaderIconIM = InstanceManager:new("IconInstance", "Top", m_CivTooltip.InfoStack);
m_CivTooltip.CivHeaderIconIM = InstanceManager:new("CivIconInstance", "Top", m_CivTooltip.InfoStack);
m_CivTooltip.HeaderIM = InstanceManager:new("HeaderInstance", "Top", m_CivTooltip.InfoStack);

-- Game launch blockers
local m_bTeamsValid = true;						-- Are the teams valid for game start?
local g_everyoneConnected = true;				-- Is everyone network connected to the game?
local g_badPlayerForMapSize = false;			-- Are there too many active civs for this map?
local g_notEnoughPlayers = false;				-- Is there at least one player in the game?（联机工具箱2.0：允许单人开局）
local g_everyoneReady = false;					-- Is everyone ready to play?
local g_everyoneModReady = true;				-- Does everyone have the mods for this game?
local g_humanRequiredFilled = true;				-- Are all the human required slots filled by humans?
local g_duplicateLeaders = false;				-- Are there duplicate leaders blocking launch?
												-- Note:  This only applies if No Duplicate Leaders parameter is set.
local g_pbcNewGameCheck = true;					-- In a PlayByCloud game, only the game host can launch a new game.	
local g_pbcMinHumanCheck = true;				-- PlayByCloud matches need at least two human players. 
												-- The game and backend can not handle solo games. 
												-- NOTE: The backend will automatically end started PBC matches that end up 
												-- with a solo human due to quits/kicks. 
local g_matchMakeFullGameCheck = true;			-- In a Matchmaking game, we only game launch during the ready countdown if the game is full of human players.				
local g_viewingGameSummary = true;
local g_hotseatNumHumanPlayers = 0;
local g_hotseatNumAIPlayers = 0;
local g_isBuildingPlayerList = false;

local m_iFirstClosedSlot = -1;					-- Closed slot to show Add player line

local NO_COUNTDOWN = -1;

local m_countdownType :string				= CountdownTypes.None;	-- Which countdown type is active?
local g_fCountdownTimer :number 			= NO_COUNTDOWN;			-- Start game countdown timer.  Set to -1 when not in use.
local g_fCountdownInitialTime :number 		= NO_COUNTDOWN;			-- Initial time for the current countdown.
local g_fCountdownTickSoundTime	:number 	= NO_COUNTDOWN;			-- When was the last time we make a countdown tick sound?
local g_fCountdownReadyButtonTime :number	= NO_COUNTDOWN;			-- When was the last time we updated the ready button countdown time?

-- Defines for the different Countdown Types.
-- CountdownTime - How long does the ready up countdown last in seconds?
-- TickStartTime - How long before the end of the ready countdown time does the ticking start?
local g_CountdownData = {
	[CountdownTypes.Launch]				= { CountdownTime = 10,		TimerType = TimerTypes.Script,				TickStartTime = 10},
	[CountdownTypes.Launch_Instant]		= { CountdownTime = 0,		TimerType = TimerTypes.Script,				TickStartTime = 0},
	[CountdownTypes.WaitForPlayers]		= { CountdownTime = 180,	TimerType = TimerTypes.NetworkManager,		TickStartTime = 10},
	[CountdownTypes.Ready_PlayByCloud]	= { CountdownTime = 600,	TimerType = TimerTypes.Script,				TickStartTime = 10},
	[CountdownTypes.Ready_MatchMaking]	= { CountdownTime = 60,		TimerType = TimerTypes.Script,				TickStartTime = 10},
};

-- hotseatOnly - Only available in hotseat mode.
-- hotseatInProgress = Available for active civs (AI/HUMAN) when loading a hotseat game
-- hotseatAllowed - Allowed in hotseat mode.
local g_slotTypeData = 
{
	{ name ="LOC_SLOTTYPE_OPEN",		tooltip = "LOC_SLOTTYPE_OPEN_TT",		hotseatOnly=false,	slotStatus=SlotStatus.SS_OPEN,		hotseatInProgress = false,		hotseatAllowed=false},
	{ name ="LOC_SLOTTYPE_AI",			tooltip = "LOC_SLOTTYPE_AI_TT",			hotseatOnly=false,	slotStatus=SlotStatus.SS_COMPUTER,	hotseatInProgress = true,		hotseatAllowed=true },
	{ name ="LOC_SLOTTYPE_CLOSED",		tooltip = "LOC_SLOTTYPE_CLOSED_TT",		hotseatOnly=false,	slotStatus=SlotStatus.SS_CLOSED,	hotseatInProgress = false,		hotseatAllowed=true },		
	{ name ="LOC_SLOTTYPE_HUMAN",		tooltip = "LOC_SLOTTYPE_HUMAN_TT",		hotseatOnly=true,	slotStatus=SlotStatus.SS_TAKEN,		hotseatInProgress = true,		hotseatAllowed=true },		
	{ name ="LOC_MP_SWAP_PLAYER",		tooltip = "TXT_KEY_MP_SWAP_BUTTON_TT",	hotseatOnly=false,	slotStatus=-1,						hotseatInProgress = true,		hotseatAllowed=true },		
	-- ============================================================================
	-- 联机工具箱2.0 条目3.8：新增「移除玩家」下拉选项（替代原玩家条目行右侧 X 按钮，仅房主可见）。
	-- slotStatus=-2 为哨兵值 + kickOption 标记：PopulateSlotTypePulldown 按 IsPlayerKickable 判定显隐，
	-- OnSlotType 命中后转 OnKickButton 走原确认弹窗流程；文本复用原版 LOC_MP_KICK_PLAYER，无需新增本地化。
	{ name ="LOC_MP_KICK_PLAYER",		tooltip = "LOC_MP_KICK_PLAYER",			hotseatOnly=false,	slotStatus=-2,	kickOption=true,	hotseatInProgress = false,	hotseatAllowed=false },
	-- ----------------------------------------------------------------------------
};

-- ============================================================================
-- 联机工具箱2.0：修改房间最大人数 12 -> 20
-- local MAX_EVER_PLAYERS : number = 12; -- hardwired max possible players in multiplayer, determined by how many players 
local MAX_EVER_PLAYERS : number = 20; -- hardwired max possible players in multiplayer, determined by how many players 
-- ----------------------------------------------------------------------------
-- ============================================================================
-- 联机工具箱2.0：最小开局人数 2 -> 1（参考 RL_Pangaea：allow single player games）
-- local MIN_EVER_PLAYERS : number = 2;  -- hardwired min possible players in multiplayer, the game does bad things if there aren't at least two players on different teams.
local MIN_EVER_PLAYERS : number = 1;  -- hardwired min possible players in multiplayer, allow single player games.
-- ----------------------------------------------------------------------------
-- ============================================================================
-- 联机工具箱2.0：官方支持人数上限 8 -> 20（仅影响超上限警告文本，跟随 MAX_EVER_PLAYERS）
-- local MAX_SUPPORTED_PLAYERS : number = 8; -- Max number of officially supported players in multiplayer.  You can play with more than this number, but QA hasn't vetted it.
local MAX_SUPPORTED_PLAYERS : number = 20; -- Max number of officially supported players in multiplayer.  You can play with more than this number, but QA hasn't vetted it.
-- ----------------------------------------------------------------------------
local g_currentMaxPlayers : number = MAX_EVER_PLAYERS;
local g_currentMinPlayers : number = MIN_EVER_PLAYERS;
	
local PlayerConnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_CHAT" );
local PlayerDisconnectedChatStr = Locale.Lookup( "LOC_MP_PLAYER_DISCONNECTED_CHAT" );
local PlayerHostMigratedChatStr = Locale.Lookup( "LOC_MP_PLAYER_HOST_MIGRATED_CHAT" );
local PlayerKickedChatStr = Locale.Lookup( "LOC_MP_PLAYER_KICKED_CHAT" );
local BytesStr = Locale.Lookup( "LOC_BYTES" );
local KilobytesStr = Locale.Lookup( "LOC_KILOBYTES" );
local MegabytesStr = Locale.Lookup( "LOC_MEGABYTES" );
local DefaultHotseatPlayerName = Locale.Lookup( "LOC_HOTSEAT_DEFAULT_PLAYER_NAME" );
local NotReadyStatusStr = Locale.Lookup("LOC_NOT_READY");
local ReadyStatusStr = Locale.Lookup("LOC_READY_LABEL");
local BadMapSizeSlotStatusStr = Locale.Lookup("LOC_INVALID_SLOT_MAP_SIZE");
local BadMapSizeSlotStatusStrTT = Locale.Lookup("LOC_INVALID_SLOT_MAP_SIZE_TT");
local EmptyHumanRequiredSlotStatusStr :string = Locale.Lookup("LOC_INVALID_SLOT_HUMAN_REQUIRED");
local EmptyHumanRequiredSlotStatusStrTT :string = Locale.Lookup("LOC_INVALID_SLOT_HUMAN_REQUIRED_TT");
local UnsupportedText = Locale.Lookup("LOC_READY_UNSUPPORTED");
local UnsupportedTextTT = Locale.Lookup("LOC_READY_UNSUPPORTED_TT");
local downloadPendingStr = Locale.Lookup("LOC_MODS_SUBSCRIPTION_DOWNLOAD_PENDING");
local loadingSaveGameStr = Locale.Lookup("LOC_STAGING_ROOM_LOADING_SAVE");
local gameInProgressGameStr = Locale.Lookup("LOC_STAGING_ROOM_GAME_IN_PROGRESS");

local onlineIconStr = "[ICON_OnlinePip]";
local offlineIconStr = "[ICON_OfflinePip]";

local COLOR_GREEN				:number = UI.GetColorValueFromHexLiteral(0xFF00FF00);
local COLOR_RED					:number = UI.GetColorValueFromHexLiteral(0xFF0000FF);
local ColorString_ModGreen		:string = "[color:ModStatusGreen]";
local PLAYER_LIST_SIZE_DEFAULT	:number = 325;
local PLAYER_LIST_SIZE_HOTSEAT	:number = 535;
local GRID_LINE_WIDTH			:number = 1020;
local GRID_LINE_HEIGHT			:number = 51;
-- ============================================================================
-- 联机工具箱2.0 条目3.8：移除玩家列移除，竖线 GridLine_5 一并删除（XML），网格竖线列数 5 -> 4
-- （RealizeGridSize 按此数动态索引 GridLine_1..N，列数与 XML 不符会因索引 nil 中断主 chunk）
-- local NUM_COLUMNS				:number = 5;
local NUM_COLUMNS				:number = 4;
-- ----------------------------------------------------------------------------

local TEAM_ICON_SIZE			:number = 38;
local TEAM_ICON_PREFIX			:string = "ICON_TEAM_ICON_";


-------------------------------------------------
-- Localized Constants
-------------------------------------------------
local LOC_FRIENDS:string = Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_FRIENDS"));
local LOC_GAME_SETUP:string = Locale.Lookup("LOC_MULTIPLAYER_GAME_SETUP");
local LOC_GAME_SUMMARY:string = Locale.Lookup("LOC_MULTIPLAYER_GAME_SUMMARY");
local LOC_STAGING_ROOM:string = Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_STAGING_ROOM"));


-- ===========================================================================
function Close()	
    if m_kPopupDialog:IsOpen() then
		m_kPopupDialog:Close();
	end
	LuaEvents.Multiplayer_ExitShell();
end

-- ===========================================================================
--	Input Handler
-- ===========================================================================
function KeyUpHandler( key:number )
	-- ============================================================================
	-- 联机工具箱2.0：玩家标记管理打开时 ESC 优先关闭（条目4.4；添加弹窗在时先关弹窗，再关面板；
	-- 两个函数定义在本文件末尾条目4.4分区，全局函数运行时解析）
	-- ============================================================================
	if not Controls.PlayerMarkEditPopup:IsHidden() then
		MPT_PlayerMark_CloseAddPopup();
		return true;
	end
	if not Controls.PlayerMarkPanel:IsHidden() then
		MPT_PlayerMark_Close();
		return true;
	end
	-- ============================================================================
	-- 联机工具箱2.0：非官方模组清单面板打开时 ESC 优先关闭面板（条目4.2；
	-- 判定用 g_modListOpen，SlideAnim Reverse 不回设 Hidden，IsHidden 不可靠）
	-- ============================================================================
	if g_modListOpen then
		CloseModListPanel();
		return true;
	end
	-- ============================================================================
	-- 联机工具箱2.0：更新公告面板打开时 ESC 优先关闭面板（条目3.5；原版 ESC 为退出房间确认，需拦截）
	-- ============================================================================
	if not Controls.ChangelogPanel:IsHidden() then
		CloseChangelogPanel();
		return true;
	end
	-- ============================================================================
	-- 联机工具箱2.0：查看器面板打开时 ESC 优先关闭面板（条目4.5/4.6 融合：图标/贴图双页签
	-- 共用一个 IconViewerPanel 根容器；函数定义在本文件末尾条目4.6分区，全局函数运行时解析）
	-- ============================================================================
	if not Controls.IconViewerPanel:IsHidden() then
		MPT_Viewer_Close();
		return true;
	end
	-- ============================================================================
	if key == Keys.VK_ESCAPE then
		Close();
		return true;
	end
    return false;
end
function OnInputHandler( pInputStruct:table )
	local uiMsg :number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then return KeyUpHandler( pInputStruct:GetKey() ); end	
	return false;
end


----------------------------------------------------------------  
-- Helper Functions
---------------------------------------------------------------- 
function SetCurrentMaxPlayers( newMaxPlayers : number )
	g_currentMaxPlayers = math.min(newMaxPlayers, MAX_EVER_PLAYERS);
end

function SetCurrentMinPlayers( newMinPlayers : number )
	g_currentMinPlayers = math.max(newMinPlayers, MIN_EVER_PLAYERS);
end

-- Could this player slot be displayed on the staging room?  The staging room ignores a lot of possible slots (city states; barbs; player slots exceeding the map size)
function IsDisplayableSlot(playerID :number)
	local pPlayerConfig = PlayerConfigurations[playerID];
	if(pPlayerConfig == nil) then
		return false;
	end

	if(playerID < g_currentMaxPlayers	-- Any slot under the current max player limit is displayable.
		-- Full Civ participants are displayable.
		or (pPlayerConfig:IsParticipant() 
			and pPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV) ) then
			return true;
	end

	return false;
end

-- Is the cloud match in progress?
function IsCloudInProgress()
	if(not GameConfiguration.IsPlayByCloud()) then
		return false;
	end

	if(GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_LAUNCHED -- Saved game state is launched.
		-- Has the cloud match blocked player joins?  The game host sets this prior to launching the match.
		-- We check for this becaus the game state will only be set to GAMESTATE_LAUNCHED once the first turn is committed.
		-- We need to count as being inprogress from when the host started to launch the match thru them committing their first turn.
		or Network.IsCloudJoinsBlocked()) then
		return true;
	end

	return false;
end

-- Are we in a launched PlayByCloud match where it is not our turn?
function IsCloudInProgressAndNotTurn()
	if(not IsCloudInProgress()) then
		return false;
	end

	if(Network.IsCloudTurnPlayer()) then
		return false;
	end

	-- If the local player is dead, count as false.  This should result in the CheckForGameStart immediately autolaunching the game so the player can see the endgamemenu.
	local localPlayerID = Network.GetLocalPlayerID();
	if( localPlayerID ~= NetPlayerTypes.INVALID_PLAYERID) then
		local localPlayerConfig = PlayerConfigurations[localPlayerID];
		if(not localPlayerConfig:IsAlive()) then
			return false;
		end
	end

	-- TTP 44083 - It is always the host's turn if the match is "in progress" but the match has not been started.  
	-- This can happen if the game host disconnected from the match right as the launch countdown hit zero.
	if(Network.IsGameHost() and not Network.IsCloudMatchStarted()) then
		return false;
	end

	return true;
end

function IsLaunchCountdownActive()
	if(m_countdownType == CountdownTypes.Launch or m_countdownType == CountdownTypes.Launch_Instant) then
		return true;
	end

	return false;
end

function IsReadyCountdownActive()
	if(m_countdownType == CountdownTypes.Ready_MatchMaking 
		or m_countdownType == CountdownTypes.Ready_PlayByCloud) then
		return true;
	end

	return false;
end

function IsWaitForPlayersCountdownActive()
	if(m_countdownType == CountdownTypes.WaitForPlayers) then
		return true;
	end

	return false;
end

function IsUseReadyCountdown()
	local type = GetReadyCountdownType();
	if(type ~= CountdownTypes.None) then
		return true;
	end

	return false;
end

function GetReadyCountdownType()
	if(GameConfiguration.IsPlayByCloud()) then
		return CountdownTypes.Ready_PlayByCloud;
	elseif(GameConfiguration.IsMatchMaking()) then
		return CountdownTypes.Ready_MatchMaking;
	end
	return CountdownTypes.None;
end	

function IsUseWaitingForPlayersCountdown()
	return GameConfiguration.IsMatchMaking();
end

function GetCountdownTimeRemaining()
	local countdownData :table = g_CountdownData[m_countdownType];
	if(countdownData == nil) then
		return 0;
	end

	if(countdownData.TimerType == TimerTypes.NetworkManager) then
		local sessionTime :number = Network.GetElapsedSessionTime();
		return countdownData.CountdownTime - sessionTime;
	else
		return g_fCountdownTimer;
	end
end


----------------------------------------------------------------  
-- Event Handlers
---------------------------------------------------------------- 
function OnMapMaxMajorPlayersChanged(newMaxPlayers : number)
	if(g_currentMaxPlayers ~= newMaxPlayers) then
		SetCurrentMaxPlayers(newMaxPlayers);
		if(ContextPtr:IsHidden() == false) then
			CheckGameAutoStart();	-- game start can change based on the new max players.
			BuildPlayerList();	-- rebuild player list because several player slots will have changed.
		end
	end
end

function OnMapMinMajorPlayersChanged(newMinPlayers : number)
	if(g_currentMinPlayers ~= newMinPlayers) then
		SetCurrentMinPlayers(newMinPlayers);
		if(ContextPtr:IsHidden() == false) then
			CheckGameAutoStart();	-- game start can change based on the new min players.
		end
	end
end

-------------------------------------------------
-- OnGameConfigChanged
-------------------------------------------------
function OnGameConfigChanged()
	if(ContextPtr:IsHidden() == false) then
		RealizeGameSetup(); -- Rebuild the game settings UI.
		RebuildTeamPulldowns();	-- NoTeams setting might have changed.

		-- PLAYBYCLOUDTODO - Remove PBC special case once ready state changes have been moved to cloud player meta data.
		-- PlayByCloud uses GameConfigChanged to communicate player ready state changes, don't reset ready in that mode.
		if(not GameConfiguration.IsPlayByCloud() and not Automation.IsActive()) then
			SetLocalReady(false);  -- unready so player can acknowledge the new settings.
		end

		-- [TTP 42798] PlayByCloud Only - Ensure local player is ready if match is inprogress.  
		-- Previously players could get stuck unready if they unreadied between the host starting the launch countdown but before the game launch.
		if(IsCloudInProgress()) then
			SetLocalReady(true);
		end

		CheckGameAutoStart();  -- Toggling "No Duplicate Leaders" can affect the autostart.
	end
	OnMapMaxMajorPlayersChanged(MapConfiguration.GetMaxMajorPlayers());	
	OnMapMinMajorPlayersChanged(MapConfiguration.GetMinMajorPlayers());
	RefreshHostPermissions();	-- 联机工具箱2.0：刷新「AI槽位」按钮可见性（条目3.2）
end

-------------------------------------------------
-- OnPlayerInfoChanged
-------------------------------------------------
function PlayerInfoChanged_SpecificPlayer(playerID)
	-- Targeted update of another player's entry.
	local pPlayerConfig = PlayerConfigurations[playerID];
	if(g_cachedTeams[playerID] ~= pPlayerConfig:GetTeam()) then
		OnTeamChange(playerID, false);
	end

	Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	UpdatePlayerEntry(playerID);
	
	Controls.PlayerListStack:CalculateSize();
	Controls.PlayersScrollPanel:CalculateSize();
end

function OnPlayerInfoChanged(playerID)
	if(ContextPtr:IsHidden() == false) then
		-- Ignore PlayerInfoChanged events for non-displayable player slots.
		if(not IsDisplayableSlot(playerID)) then
			return;
		end

		if(playerID == Network.GetLocalPlayerID()) then
			-- If we are the host and our info changed, we need to locally refresh all the player slots.
			-- We do this because the host's ready status disables/enables pulldowns on all the other player slots.
			if(Network.IsGameHost()) then
				UpdateAllPlayerEntries();
			else
				-- A remote client needs to update the disabled status of all slot type pulldowns if their data was changed.
				-- We do this because readying up disables the slot type pulldown for all players.
				UpdateAllPlayerEntries_SlotTypeDisabled();

				PlayerInfoChanged_SpecificPlayer(playerID);
			end
		else
			PlayerInfoChanged_SpecificPlayer(playerID);
		end

		CheckGameAutoStart();	-- Player might have changed their ready status.
		UpdateReadyButton();
		
		-- Update chat target pulldown.
		PlayerTarget_OnPlayerInfoChanged( playerID, Controls.ChatPull, Controls.ChatEntry, Controls.ChatIcon, m_playerTargetEntries, m_playerTarget, false);
	end
end

function OnUploadCloudPlayerConfigComplete(success :boolean)
	if(m_exitReadyWait == true) then
		m_exitReadyWait = false;
		Close();
	end
end

-------------------------------------------------
-- OnTeamChange
-------------------------------------------------
function OnTeamChange( playerID, isBatchCall )
	local pPlayerConfig = PlayerConfigurations[playerID];
	if(pPlayerConfig ~= nil) then
		local teamID = pPlayerConfig:GetTeam();
		local playerEntry = GetPlayerEntry(playerID);
		local updateOpenEmptyTeam = false;

		-- Check for situations where we might need to update the Open Empty Team slot.
		if( (g_cachedTeams[playerID] ~= nil and GameConfiguration.GetTeamPlayerCount(g_cachedTeams[playerID]) <= 0) -- was last player on old team.
			or (GameConfiguration.GetTeamPlayerCount(teamID) <= 1) ) then -- first player on new team.
			-- this player was the last player on that team.  We might need to create a new empty team.
			updateOpenEmptyTeam = true;
		end
		
		if(g_cachedTeams[playerID] ~= nil 
			and g_cachedTeams[playerID] ~= teamID
			-- Remote clients will receive team changes during the PlayByCloud game launch process if they just wait in the staging room.
			-- That should not unready the player which can mess up the autolaunch process.
			and not IsCloudInProgress()) then 
			-- Reset the player's ready status if they actually changed teams.
			SetLocalReady(false);
		end

		-- cache the player's teamID for the next OnTeamChange.
		g_cachedTeams[playerID] = teamID;
		
		if(not isBatchCall) then
			-- There's some stuff that we have to do it to maintain the player list. 
			-- We intentionally wait to do this if we're in the middle of doing a batch of these updates.
			-- If you're doing a batch of these, call UpdateTeamList(true) when you're done.
			UpdateTeamList(updateOpenEmptyTeam);
		end
	end	
end


-------------------------------------------------
-- OnMultiplayerPingTimesChanged
-------------------------------------------------
function OnMultiplayerPingTimesChanged()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		-- 联机工具箱2.0 条目3.7：第三参数原传 StatusLabel（原版函数忽略该参数），现改传 PingLabel 以常驻显示 ping 数值
		-- 原代码：UpdateNetConnectionIcon(playerID, playerEntry.ConnectionStatus, playerEntry.StatusLabel);
		UpdateNetConnectionIcon(playerID, playerEntry.ConnectionStatus, playerEntry.PingLabel);
		UpdateNetConnectionLabel(playerID, playerEntry.StatusLabel);
	end
end

function OnCloudGameKilled( matchID, success )
	if(success) then
		Close();
	else
		--Show error prompt.
		m_kPopupDialog:Close();
		m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_FAIL_TITLE")));
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_FAIL"));
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_FAIL_ACCEPT") );
		m_kPopupDialog:Open();
	end
end

function OnCloudGameQuit( matchID, success )
	if(success) then
		-- On success, close popup and exit the screen
		Close();
	else
		--Show error prompt.
		m_kPopupDialog:Close();
		m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_QUITING_GAME_FAIL_TITLE")));
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_QUITING_GAME_FAIL"));
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_MULTIPLAYER_QUITING_GAME_FAIL_ACCEPT") );
		m_kPopupDialog:Open();
	end
end

-------------------------------------------------
-- Chat
-------------------------------------------------
function OnMultiplayerChat( fromPlayer, toPlayer, text, eTargetType )
	OnChat(fromPlayer, toPlayer, text, eTargetType, true);
end

function OnChat( fromPlayer, toPlayer, text, eTargetType, playSounds :boolean )
	if(ContextPtr:IsHidden() == false) then
		local pPlayerConfig = PlayerConfigurations[fromPlayer];
		local playerName = Locale.Lookup(pPlayerConfig:GetPlayerName());

		-- Selecting chat text color based on eTargetType	
		local chatColor :string = "[color:ChatMessage_Global]";
		if(eTargetType == ChatTargetTypes.CHATTARGET_TEAM) then
			chatColor = "[color:ChatMessage_Team]";
		elseif(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
			chatColor = "[color:ChatMessage_Whisper]";  
		end
		
		local chatString	= "[color:ChatPlayerName]" .. playerName;

		-- When whispering, include the whisperee's name as well.
		if(eTargetType == ChatTargetTypes.CHATTARGET_PLAYER) then
			local pTargetConfig :table	= PlayerConfigurations[toPlayer];
			if(pTargetConfig ~= nil) then
				local targetName = Locale.Lookup(pTargetConfig:GetPlayerName());
				chatString = chatString .. " [" .. targetName .. "]";
			end
		end

		-- Ensure text parsed properly
		text = ParseChatText(text);

		chatString			= chatString .. ": [ENDCOLOR]" .. chatColor;
		-- Add a space before the [ENDCOLOR] tag to prevent the user from accidentally escaping it
		chatString			= chatString .. text .. " [ENDCOLOR]";

		AddChatEntry( chatString, Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);

		if(playSounds and fromPlayer ~= Network.GetLocalPlayerID()) then
			UI.PlaySound("Play_MP_Chat_Message_Received");
		end
	end
end

-------------------------------------------------
-------------------------------------------------
function SendChat( text )
    if( string.len( text ) > 0 ) then
		-- Parse text for possible chat commands
		local parsedText :string;
		local chatTargetChanged :boolean = false;
		local printHelp :boolean = false;
		parsedText, chatTargetChanged, printHelp = ParseInputChatString(text, m_playerTarget);
		if(chatTargetChanged) then
			ValidatePlayerTarget(m_playerTarget);
			UpdatePlayerTargetPulldown(Controls.ChatPull, m_playerTarget);
			UpdatePlayerTargetEditBox(Controls.ChatEntry, m_playerTarget);
			UpdatePlayerTargetIcon(Controls.ChatIcon, m_playerTarget);
		end

		if(printHelp) then
			ChatPrintHelp(Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);
		end

		if(parsedText ~= "") then
			-- m_playerTarget uses PlayerTargetLogic values and needs to be converted  
			local chatTarget :table ={};
			PlayerTargetToChatTarget(m_playerTarget, chatTarget);
			Network.SendChat( parsedText, chatTarget.targetType, chatTarget.targetID );
			UI.PlaySound("Play_MP_Chat_Message_Sent");
		end
    end
    Controls.ChatEntry:ClearString();
end

-------------------------------------------------
-- ParseChatText - ensures icon tags parsed properly
-------------------------------------------------
function ParseChatText(text)
	startIdx, endIdx = string.find(string.upper(text), "%[ICON_");
	if(startIdx == nil) then
		return text;
	else
		for i = endIdx + 1, string.len(text) do
			character = string.sub(text, i, i);
			if(character=="]") then
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text,i + 1));
			elseif(character==" ") then
				text = string.gsub(text, " ", "]", 1);
				return string.sub(text, 1, i) .. ParseChatText(string.sub(text, i + 1));
			elseif (character=="[") then
				return string.sub(text, 1, i - 1) .. "]" .. ParseChatText(string.sub(text, i));
			end
		end
		return text.."]";
	end
	return text;
end

-------------------------------------------------
-------------------------------------------------

function OnMultplayerPlayerConnected( playerID )
	if( ContextPtr:IsHidden() == false ) then
		OnChat( playerID, -1, PlayerConnectedChatStr, false );
		UI.PlaySound("Play_MP_Player_Connect");
		UpdateFriendsList();

		-- Autoplay Host readies up as soon as the required number of network connections (human or autoplay players) have connected.
		if(Automation.IsActive() and Network.IsGameHost()) then
			local minPlayers = Automation.GetSetParameter("CurrentTest", "MinPlayers", 2);
			local connectedCount = 0;
			if(minPlayers ~= nil) then
				-- Count network connected player slots
				local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
				for i, iPlayer in ipairs(player_ids) do	
					if(Network.IsPlayerConnected(iPlayer)) then
						connectedCount = connectedCount + 1;
					end
				end

				if(connectedCount >= minPlayers) then
					Automation.Log("HostGame MinPlayers met, host readying up.  MinPlayers=" .. tostring(minPlayers) .. " ConnectedPlayers=" .. tostring(connectedCount));
					SetLocalReady(true);
				end
			end
		end
	end
end

-------------------------------------------------
-------------------------------------------------

function OnMultiplayerPrePlayerDisconnected( playerID )
	if( ContextPtr:IsHidden() == false ) then
		local playerCfg = PlayerConfigurations[playerID];
		if(playerCfg:IsHuman()) then
			if(Network.IsPlayerKicked(playerID)) then
				OnChat( playerID, -1, PlayerKickedChatStr, false );
			else
    			OnChat( playerID, -1, PlayerDisconnectedChatStr, false );
			end
			UI.PlaySound("Play_MP_Player_Disconnect");
			UpdateFriendsList();
		end
	end
end

-------------------------------------------------
-------------------------------------------------

function OnModStatusUpdated(playerID: number, modState : number, bytesDownloaded : number, bytesTotal : number,
							modsRemaining : number, modsRequired : number)

	g_mpt_installedVerCache = nil;	-- 联机工具箱2.0：mod 下载/启用状态变化，版本缓存失效重建（条目4.1）
	if(modState == 1) then -- MOD_STATE_DOWNLOADING
		local modStatusString = downloadPendingStr;
		modStatusString = modStatusString .. "[NEWLINE][Icon_AdditionalContent]" .. tostring(modsRemaining) .. "/" .. tostring(modsRequired);
		g_PlayerModStatus[playerID] = modStatusString;
	else
		g_PlayerModStatus[playerID] = nil;
		-- 联机工具箱2.0：本机 mod 下载/更新到达终态 → 置脏标记，tick 静默期满后重发（房主）/重报（客机）版本指纹（条目4.1修复 A3）
		if playerID == Network.GetLocalPlayerID() then
			g_mpt_modListDirtyTime = os.time();
		end
	end
	UpdatePlayerEntry(playerID);

	--[[ Prototype Mod Status Progress Bars
	local playerEntry = g_PlayerEntries[playerID];
	if(playerEntry ~= nil) then
		if(modState ~= 1) then
			playerEntry.PlayerModProgressStack:SetHide(true);
		else
			-- MOD_STATE_DOWNLOADING
			playerEntry.PlayerModProgressStack:SetHide(false);

			-- Update Progress Bar
			local progress : number = 0;
			if(bytesTotal > 0) then
				progress = bytesDownloaded / bytesTotal;
			end
			playerEntry.ModProgressBar:SetPercent(progress);

			-- Building Bytes Remaining Label
			if(bytesTotal > 0) then
				local bytesRemainingStr : string = "";
				local modSizeStr : string = BytesStr;
				local bytesDownloadedScaled : number = bytesDownloaded;
				local bytesTotalScaled : number = bytesTotal;
				if(bytesTotal > 1000000) then
					-- Megabytes
					modSizeStr = MegabytesStr;
					bytesDownloadedScaled = bytesDownloadedScaled / 1000000;
					bytesTotalScaled = bytesTotalScaled / 1000000;
				elseif(bytesTotal > 1000) then
					-- kilobytes
					modSizeStr = KilobytesStr;
					bytesDownloadedScaled = bytesDownloadedScaled / 1000;
					bytesTotalScaled = bytesTotalScaled / 1000;
				end
				bytesRemainingStr = string.format("%.02f%s/%.02f%s", bytesDownloadedScaled, modSizeStr, bytesTotalScaled, modSizeStr);
				playerEntry.BytesRemaining:SetText(bytesRemainingStr);
				playerEntry.BytesRemaining:SetHide(false);
			else
				playerEntry.BytesRemaining:SetHide(true);
			end

			-- Bulding ModProgressRemaining Label
			local modProgressStr : string = "";
			modProgressStr = modProgressStr .. " " .. tostring(modsRemaining) .. "/" .. tostring(modsRequired);
			playerEntry.ModProgressRemaining:SetText(modProgressStr);
		end
	end
	--]]
end

-------------------------------------------------
-------------------------------------------------

function OnAbandoned(eReason)
	if (not ContextPtr:IsHidden()) then

		-- We need to CheckLeaveGame before triggering the reason popup because the reason popup hides the staging room
		-- and would block the leave game incorrectly.  This fixes TTP 22192.
		CheckLeaveGame();

		if (eReason == KickReason.KICK_HOST) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_KICKED", "LOC_GAME_ABANDONED_KICKED_TITLE" );
		elseif (eReason == KickReason.KICK_NO_HOST) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_HOST_LOSTED", "LOC_GAME_ABANDONED_HOST_LOSTED_TITLE" );
		elseif (eReason == KickReason.KICK_NO_ROOM) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_ROOM_FULL", "LOC_GAME_ABANDONED_ROOM_FULL_TITLE" );
		elseif (eReason == KickReason.KICK_VERSION_MISMATCH) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_VERSION_MISMATCH", "LOC_GAME_ABANDONED_VERSION_MISMATCH_TITLE" );
		elseif (eReason == KickReason.KICK_MOD_ERROR) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_MOD_ERROR", "LOC_GAME_ABANDONED_MOD_ERROR_TITLE" );
		elseif (eReason == KickReason.KICK_MOD_MISSING) then
			local modMissingErrorStr = Modding.GetLastModErrorString();
			LuaEvents.MultiplayerPopup( modMissingErrorStr, "LOC_GAME_ABANDONED_MOD_MISSING_TITLE" );
		elseif (eReason == KickReason.KICK_MATCH_DELETED) then
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_MATCH_DELETED", "LOC_GAME_ABANDONED_MATCH_DELETED_TITLE" );
		else
			LuaEvents.MultiplayerPopup( "LOC_GAME_ABANDONED_CONNECTION_LOST", "LOC_GAME_ABANDONED_CONNECTION_LOST_TITLE");
		end
		Close();
	end
end

-------------------------------------------------
-------------------------------------------------

function OnMultiplayerGameLaunchFailed()
	-- Multiplayer game failed for launch for some reason.
	if(not GameConfiguration.IsPlayByCloud()) then
		SetLocalReady(false); -- Unready the local player so they can try it again.
	end

	m_kPopupDialog:Close();	-- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_GAME_LAUNCH_FAILED_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_GAME_LAUNCH_FAILED"));
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_MULTIPLAYER_GAME_LAUNCH_FAILED_ACCEPT"));
	m_kPopupDialog:Open();
end

-------------------------------------------------
-------------------------------------------------

function OnLeaveGameComplete()
	-- We just left the game, we shouldn't be open anymore.
	UIManager:DequeuePopup( ContextPtr );
end

-------------------------------------------------
-------------------------------------------------

function OnBeforeMultiplayerInviteProcessing()
	-- We're about to process a game invite.  Get off the popup stack before we accidently break the invite!
	UIManager:DequeuePopup( ContextPtr );
end


-------------------------------------------------
-------------------------------------------------

function OnMultiplayerHostMigrated( newHostID : number )
	if(ContextPtr:IsHidden() == false) then
		-- If the local machine has become the host, we need to rebuild the UI so host privileges are displayed.
		local localPlayerID = Network.GetLocalPlayerID();
		if(localPlayerID == newHostID) then
			RealizeGameSetup();
			BuildPlayerList();
		end

		OnChat( newHostID, -1, PlayerHostMigratedChatStr, false );
		UI.PlaySound("Play_MP_Host_Migration");
		RefreshHostPermissions();	-- 联机工具箱2.0：房主迁移后刷新「AI槽位」按钮可见性（条目3.2）
	end
end

----------------------------------------------------------------
-- Button Handlers
----------------------------------------------------------------

-------------------------------------------------
-- OnSlotType
-------------------------------------------------
function OnSlotType( playerID, id )
	--print("playerID: " .. playerID .. " id: " .. id);
	-- ============================================================================
	-- 联机工具箱2.0 条目3.8：命中「移除玩家」选项（kickOption 标记）时转原踢出确认弹窗流程，不改动槽位状态
	if g_slotTypeData[id].kickOption then
		OnKickButton(playerID);
		return;
	end
	-- ----------------------------------------------------------------------------
	-- NOTE:  This function assumes that the given player slot is not occupied by a player.  We
	--				assume that players having to be kicked before the slot's type can be manually changed.
	local pPlayerConfig = PlayerConfigurations[playerID];
	local pPlayerEntry = g_PlayerEntries[playerID];

	if g_slotTypeData[id].slotStatus == -1 then
		OnSwapButton(playerID);
		return;
	end

	pPlayerConfig:SetSlotStatus(g_slotTypeData[id].slotStatus);

	-- When setting the slot status to a major civ type, some additional data in the player config needs to be set.
	if(g_slotTypeData[id].slotStatus == SlotStatus.SS_TAKEN or g_slotTypeData[id].slotStatus == SlotStatus.SS_COMPUTER) then
		pPlayerConfig:SetMajorCiv();
	end

	Network.BroadcastPlayerInfo(playerID); -- Network the slot status change.
	
	Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	
	m_iFirstClosedSlot = -1;
	UpdateAllPlayerEntries();

	UpdatePlayerEntry(playerID);

	CheckTeamsValid();
	CheckGameAutoStart();

	if g_slotTypeData[id].slotStatus == SlotStatus.SS_CLOSED then
		Controls.PlayerListStack:CalculateSize();
		Controls.PlayersScrollPanel:CalculateSize();
	end
end

-------------------------------------------------
-- OnSwapButton
-------------------------------------------------
function OnSwapButton(playerID)
	-- In this case, playerID is the desired playerID.
	local localPlayerID = Network.GetLocalPlayerID();
	local oldDesiredPlayerID = Network.GetChangePlayerID(localPlayerID);
	local newDesiredPlayerID = playerID;
	if(oldDesiredPlayerID == newDesiredPlayerID) then
		-- player already requested to swap to this player.  Toggle back to no player swap.
		newDesiredPlayerID = NetPlayerTypes.INVALID_PLAYERID;
	end
	Network.RequestPlayerIDChange(newDesiredPlayerID);
end

-- ============================================================================
-- 联机工具箱2.0 条目3.8：移除玩家 X 按钮移除，功能改入槽位类型下拉框选项（仅房主可见）。
-- IsPlayerKickable(playerID)：判定本机是否可对指定槽位执行移除（逻辑抽取自原 UpdatePlayerEntry 内 isKickable，
-- 条件不变：本机为房主 && 槽位状态为占用/观察者 && 非本机自己 && 非热座）。
-- 用法：PopulateSlotTypePulldown 对 g_slotTypeData 中 kickOption 项按此显隐；OnSlotType 命中后转 OnKickButton。
-- ============================================================================
function IsPlayerKickable(playerID)
	local localPlayerID = Network.GetLocalPlayerID();
	local pPlayerConfig = PlayerConfigurations[playerID];
	local slotStatus = pPlayerConfig:GetSlotStatus();
	return Network.IsGameHost()			-- Only the game host may kick
		and (slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_OBSERVER)
		and playerID ~= localPlayerID	-- Can't kick yourself
		and not GameConfiguration.IsHotseat();	-- Can't kick in hotseat, players use the slot type pulldowns instead.
end
-- ----------------------------------------------------------------------------

-------------------------------------------------
-- OnKickButton
-------------------------------------------------
function OnKickButton(playerID)
	-- Kick button was clicked for the given player slot.
	--print("playerID " .. playerID);
	UIManager:PushModal(Controls.ConfirmKick, true);
	local pPlayerConfig = PlayerConfigurations[playerID];
	if pPlayerConfig:GetSlotStatus() == SlotStatus.SS_COMPUTER then
		LuaEvents.SetKickPlayer(playerID, "LOC_SLOTTYPE_AI");
	else
		local playerName = pPlayerConfig:GetPlayerName();
		LuaEvents.SetKickPlayer(playerID, playerName);
	end
end

-------------------------------------------------
-- OnAddPlayer
-------------------------------------------------
function OnAddPlayer(playerID)
	-- Add Player was clicked for the given player slot.
	-- ============================================================================
	-- 联机工具箱2.0 条目3.2改版：「添加玩家」按钮改为直接添加AI玩家（原为设为空缺槽位）；
	-- SetMajorCiv 对齐 OnSlotType 选 AI 槽位分支（AI 槽位必须设为 major civ）
	-- Set this slot to open
	-- pPlayerConfig:SetSlotStatus(SlotStatus.SS_OPEN);
	-- ============================================================================
	local pPlayerConfig = PlayerConfigurations[playerID];
	local playerName = pPlayerConfig:GetPlayerName();
	m_iFirstClosedSlot = -1;

	pPlayerConfig:SetSlotStatus(SlotStatus.SS_COMPUTER);
	pPlayerConfig:SetMajorCiv();
	-- ----------------------------------------------------------------------------
	Network.BroadcastPlayerInfo(playerID); -- Network the slot status change.

	Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	UpdateAllPlayerEntries();

	CheckTeamsValid();
	CheckGameAutoStart();

	Controls.PlayerListStack:CalculateSize();
	Controls.PlayersScrollPanel:CalculateSize();
	Resize();	
end

-------------------------------------------------
-- OnPlayerEntryReady
-------------------------------------------------
function OnPlayerEntryReady(playerID)
	-- Every player entry ready button has this callback, but it only does something if this is for the local player.
	local localPlayerID = Network.GetLocalPlayerID();
	if(playerID == localPlayerID) then
		OnReadyButton();
	end
end

-------------------------------------------------
-- OnJoinTeamButton
-------------------------------------------------
function OnTeamPull( playerID :number, teamID :number)
	local playerConfig = PlayerConfigurations[playerID];

	if(playerConfig ~= nil and teamID ~= playerConfig:GetTeam()) then
		playerConfig:SetTeam(teamID);
		Network.BroadcastPlayerInfo(playerID);
		OnTeamChange(playerID, false);
	end

	UpdatePlayerEntry(playerID);
end

-------------------------------------------------
-- OnInviteButton
-------------------------------------------------
function OnInviteButton()
	local pFriends = Network.GetFriends(Network.GetTransportType());
	if pFriends ~= nil then
		pFriends:ActivateInviteOverlay();
	end
end

-------------------------------------------------
-- OnReadyButton
-------------------------------------------------
function OnReadyButton()
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];

	if(not IsCloudInProgress()) then -- PlayByCloud match already in progress, don't touch the local ready state.
		SetLocalReady(not localPlayerConfig:GetReady());
	end
	
	-- Clicking the ready button in some situations instant launches the game.
	if(GameConfiguration.IsHotseat() 
		-- Not our turn in an inprogress PlayByCloud match.  Immediately launch game so player can observe current game state.
		-- NOTE: We can only do this if GAMESTATE_LAUNCHED is set. This indicates that the game host has committed the first turn and
		--		GAMESTATE_LAUNCHED is baked into the save state.
		or (IsCloudInProgressAndNotTurn() and GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_LAUNCHED)) then 
		Network.LaunchGame();
	end
end

-------------------------------------------------
-- OnClickToCopy
-------------------------------------------------
function OnClickToCopy()
	local sText:string = Controls.JoinCodeText:GetText();
	UIManager:SetClipboardString(sText);
end

----------------------------------------------------------------
-- Screen Scripting
----------------------------------------------------------------
function SetLocalReady(newReady)
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];

	-- PlayByCloud Only - Disallow unreadying once the match has started.
	if(IsCloudInProgress() and newReady == false) then
		return;
	end

	-- When using a ready countdown, the player can not unready themselves outside of the ready countdown.
	if(IsUseReadyCountdown() 
		and newReady == false
		and not IsReadyCountdownActive()) then
		return;
	end
	
	if(newReady ~= localPlayerConfig:GetReady()) then
		
		if not GameConfiguration.IsHotseat() then
			Controls.ReadyCheck:SetSelected(newReady);
		end

		-- Show ready-to-go popup when a remote client readies up in a fresh PlayByCloud match.
		if(newReady 
			and GameConfiguration.IsPlayByCloud()
			and GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_LAUNCHED
			and not m_shownPBCReadyPopup
			and not m_exitReadyWait) then -- Do not show ready popup if we are exiting due to pressing the back button.
			ShowPBCReadyPopup();
		end

		localPlayerConfig:SetReady(newReady);
		Network.BroadcastPlayerInfo();
		UpdatePlayerEntry(localPlayerID);
		CheckGameAutoStart();
	end
end

function ShowPBCReadyPopup()
	m_shownPBCReadyPopup = true;
	local readyUpBehavior :number = UserConfiguration.GetPlayByCloudClientReadyBehavior();
	if(readyUpBehavior == PlayByCloudReadyBehaviorType.PBC_READY_ASK_ME) then
		m_kPopupDialog:Close();	-- clear out the popup incase it is already open.
		m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_PLAYBYCLOUD_REMOTE_READY_POPUP_TITLE")));
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_PLAYBYCLOUD_REMOTE_READY_POPUP_TEXT"));
		m_kPopupDialog:AddCheckBox(Locale.Lookup("LOC_REMEMBER_MY_CHOICE"), false, OnPBCReadySaveChoice);
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_PLAYBYCLOUD_REMOTE_READY_POPUP_OK"), OnPBCReadyOK );
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_PLAYBYCLOUD_REMOTE_READY_POPUP_LOBBY_EXIT"), OnPBCReadyExitGame, nil, nil );
		m_kPopupDialog:Open();
	elseif(readyUpBehavior == PlayByCloudReadyBehaviorType.PBC_READY_EXIT_LOBBY) then
		StartExitGame();
	end

	-- Nothing needs to happen for the PlayByCloudReadyBehaviorType.PBC_READY_DO_NOTHING.  Obviously.

end

function OnPBCReadySaveChoice()
	m_savePBCReadyChoice = true;
end

function OnPBCReadyOK()
	-- OK means do nothing and remain in the staging room.
	if(m_savePBCReadyChoice == true) then
		Options.SetUserOption("Interface", "PlayByCloudClientReadyBehavior", PlayByCloudReadyBehaviorType.PBC_READY_DO_NOTHING);
		Options.SaveOptions();
	end	
end

function OnPBCReadyExitGame()
	if(m_savePBCReadyChoice == true) then
		Options.SetUserOption("Interface", "PlayByCloudClientReadyBehavior", PlayByCloudReadyBehaviorType.PBC_READY_EXIT_LOBBY);
		Options.SaveOptions();
	end	

	StartExitGame();
end

-------------------------------------------------
-- Update Teams valid status
-------------------------------------------------
function CheckTeamsValid()
	m_bTeamsValid = false;
	local noTeamPlayers : boolean = false;
	local teamTest : number = TeamTypes.NO_TEAM;
	-- ============================================================================
	-- 联机工具箱2.0：允许只有1个玩家时开始游戏 —— 统计 full-civ 参与者数，单人时队伍视为有效
	-- ----------------------------------------------------------------------------
	local participantCount : number = 0;
    
	-- Teams are invalid if all players are on the same team.
	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local curPlayerConfig = PlayerConfigurations[iPlayer];
		if( curPlayerConfig:IsParticipant() 
		and curPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV ) then
			participantCount = participantCount + 1;	-- 联机工具箱2.0：累计参与者数
			local curTeam : number = curPlayerConfig:GetTeam();
			if(curTeam == TeamTypes.NO_TEAM) then
				-- If someone doesn't have a team, it means that teams are valid.
				m_bTeamsValid = true;
				return;
			elseif(teamTest == TeamTypes.NO_TEAM) then
				teamTest = curTeam;
			elseif(teamTest ~= curTeam) then
				-- people are on different teams.  Teams are valid.
				m_bTeamsValid = true;
				return;
			end
		end
	end
	-- ============================================================================
	-- 联机工具箱2.0：单人局无「全员同队」冲突概念，队伍视为有效（2人及以上逻辑不变）
	-- ----------------------------------------------------------------------------
	if(participantCount == 1) then
		m_bTeamsValid = true;
	end
end

-------------------------------------------------
-- CHECK FOR GAME AUTO START
-------------------------------------------------
function CheckGameAutoStart()
	
	-- PlayByCloud Only - Autostart if we are the active turn player.
	if IsCloudInProgress() and Network.IsCloudTurnPlayer() then
		if(not IsLaunchCountdownActive()) then
			-- Reset global blocking variables so the ready button is not dirty from previous sessions.
			ResetAutoStartFlags();				
			SetLocalReady(true);
			StartLaunchCountdown();
		end
	-- Check to see if we should start/stop the multiplayer game.
	
	elseif(not Network.IsPlayerHotJoining(Network.GetLocalPlayerID())
		
		and not IsCloudInProgressAndNotTurn()
		and not Network.IsCloudLaunching()) then -- We should not autostart if we are already launching into a PlayByCloud match.
		local startCountdown = true;
				
		-- Reset global blocking variables because we're going to recalculate them.
		ResetAutoStartFlags();

		-- Count players and check to see if a human player isn't ready.
		local totalPlayers = 0;
		local totalHumans = 0;
		local noDupLeaders = GameConfiguration.GetValue("NO_DUPLICATE_LEADERS");
		local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();		
		
		for i, iPlayer in ipairs(player_ids) do	
			local curPlayerConfig = PlayerConfigurations[iPlayer];
			local curSlotStatus = curPlayerConfig:GetSlotStatus();
			local curIsFullCiv = curPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
			
			if((curSlotStatus == SlotStatus.SS_TAKEN -- Human civ
				or Network.IsPlayerConnected(iPlayer))	-- network connection on this slot, could be an multiplayer autoplay.
				and (curPlayerConfig:IsAlive() or curSlotStatus == SlotStatus.SS_OBSERVER)) then -- Dead players do not block launch countdown.  Observers count as dead but should still block launch to be consistent. 
				if(not curPlayerConfig:GetReady()) then
					print("CheckGameAutoStart: Can't start game because player ".. iPlayer .. " isn't ready");
					startCountdown = false;
					g_everyoneReady = false;
				-- Players are set to ModRrady when have they successfully downloaded and configured all the mods required for this game.
				-- See Network::Manager::OnFinishedGameplayContentConfigure()
				elseif(not curPlayerConfig:GetModReady()) then
					print("CheckGameAutoStart: Can't start game because player ".. iPlayer .. " isn't mod ready");
					startCountdown = false;
					g_everyoneModReady = false;
				end
			
			elseif(curPlayerConfig:IsHumanRequired() == true 
				and GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_PREGAME) then
				-- If this is a new game, all human required slots need to be filled by a human.  
				-- NOTE: Human required slots do not need to be filled when loading a save.
				startCountdown = false;
				g_humanRequiredFilled = false;
			end
			
			if( (curSlotStatus == SlotStatus.SS_COMPUTER or curSlotStatus == SlotStatus.SS_TAKEN) and curIsFullCiv ) then
				totalPlayers = totalPlayers + 1;
				
				if(curSlotStatus == SlotStatus.SS_TAKEN) then
					totalHumans = totalHumans + 1;
				end

				if(iPlayer >= g_currentMaxPlayers) then
					-- A player is occupying an invalid player slot for this map size.
					print("CheckGameAutoStart: Can't start game because player " .. iPlayer .. " is in an invalid slot for this map size.");
					startCountdown = false;
					g_badPlayerForMapSize = true;
				end

				-- Check for selection error (ownership rules, duplicate leaders, etc)
				local err = GetPlayerParameterError(iPlayer)
				if(err) then
					
					startCountdown = false;
					if(noDupLeaders and err.Id == "InvalidDomainValue" and err.Reason == "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS") then
						g_duplicateLeaders = true;
					end
				end
			end
		end
		
		-- Check player count
		-- ============================================================================
		-- 联机工具箱2.0：允许只有1个玩家时开始游戏（最小开局人数 g_currentMinPlayers -> 1，0人仍阻止）
		-- if(totalPlayers < g_currentMinPlayers) then
		if(totalPlayers < 1) then
		-- ----------------------------------------------------------------------------
			print("CheckGameAutoStart: Can't start game because there are not enough players. " .. totalPlayers .. "/" .. g_currentMinPlayers);
			startCountdown = false;
			g_notEnoughPlayers = true;
		end

		if(GameConfiguration.IsPlayByCloud() 
			and GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_LAUNCHED
			and totalHumans < 2) then
			print("CheckGameAutoStart: Can't start game because two human players are required for PlayByCloud. totalHumans: " .. totalHumans);
			startCountdown = false;
			g_pbcMinHumanCheck = false;
		end

		if(GameConfiguration.IsMatchMaking()
			and GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_LAUNCHED
			and totalHumans < totalPlayers
			and (IsReadyCountdownActive() or IsWaitForPlayersCountdownActive())) then
			print("CheckGameAutoStart: Can't start game because we are still in the Ready/Matchmaking Countdown and we do not have a full game yet. totalHumans: " .. totalHumans .. ", totalPlayers: " .. tostring(totalPlayers));
			startCountdown = false;
			g_matchMakeFullGameCheck = false;
		end

		if(not Network.IsEveryoneConnected()) then
			print("CheckGameAutoStart: Can't start game because players are joining the game.");
			startCountdown = false;
			g_everyoneConnected = false;
		end

		if(not m_bTeamsValid) then
			print("CheckGameAutoStart: Can't start game because all civs are on the same team!");
			startCountdown = false;
		end

		-- Only the host may launch a PlayByCloud match that is not already in progress.
		if(GameConfiguration.IsPlayByCloud()
			and GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_LAUNCHED
			and not Network.IsGameHost()) then
			print("CheckGameAutoStart: Can't start game because remote client can't launch new PlayByCloud game.");
			startCountdown = false;
			g_pbcNewGameCheck = false;
		end

	
		-- Hotseat bypasses the countdown system.
		if not GameConfiguration.IsHotseat() then
			-- ============================================================================
			-- 联机工具箱2.0：mod 版本校验未通过时压住启动倒计时并弹窗（条目4.1，仅网络会话房主；「放弃验证」后放行）
			if startCountdown and Network.IsNetSessionHost() and not g_mpt_checkSkipped and MPT_IsModCheckFailing() then
				startCountdown = false;
				MPT_MaybePopupModCheckWarning();
			end
			-- ----------------------------------------------------------------------------
			if(startCountdown) then
				-- Everyone has readied up and we can start.
				StartLaunchCountdown();
			else
				-- We can't autostart now, stop the countdown if we started it earlier.
				if(IsLaunchCountdownActive()) then
					StopCountdown();
				end
			end
		end
	end
	UpdateReadyButton();
end

function ResetAutoStartFlags()
	g_everyoneReady = true;
	g_everyoneConnected = true;
	g_badPlayerForMapSize = false;
	g_notEnoughPlayers = false;
	g_everyoneModReady = true;
	g_duplicateLeaders = false;
	g_humanRequiredFilled = true;
	g_pbcNewGameCheck = true;
	g_pbcMinHumanCheck = true;
	g_matchMakeFullGameCheck = true;
end

-------------------------------------------------
-- Leave the Game
-------------------------------------------------
function CheckLeaveGame()
	-- Leave the network session if we're in a state where the staging room should be triggering the exit.
	if not ContextPtr:IsHidden()	-- If the screen is not visible, this exit might be part of a general UI state change (like Multiplayer_ExitShell)
									-- and should not trigger a game exit.
		and Network.IsInSession()	-- Still in a network session.
		and not Network.IsInGameStartedState() then -- Don't trigger leave game if we're being used as an ingame screen. Worldview is handling this instead.
		print("StagingRoom::CheckLeaveGame() leaving the network session.");
		Network.LeaveGame();
	end
end

-- ===========================================================================
--	LUA Event
-- ===========================================================================
function OnHandleExitRequest()
	print("Staging Room -Handle Exit Request");

	CheckLeaveGame();

	-- ============================================================================
	-- 联机工具箱2.0：退出房间时自动隐藏更新公告面板（条目3.5）
	-- 面板可见状态在 Lua 状态跨房间存续（StagingRoom 顶层脚本不随房间重建），
	-- 若退出时面板仍打开，重进新房间会残留可见；此处统一在退出清理流程中隐藏。
	-- CloseChangelogPanel 幂等：面板已隐藏时直接返回，不会播放重复关闭音效。
	-- ============================================================================
	CloseChangelogPanel();
	-- ============================================================================
	-- 联机工具箱2.0：退出房间时关闭非官方模组清单面板（条目4.2，硬关闭防跨房残留）
	-- ============================================================================
	CloseModListPanel(true);
	-- ----------------------------------------------------------------------------
	-- ============================================================================
	-- 联机工具箱2.0：退出房间时关闭查看器面板（条目4.5/4.6 融合面板，幂等防跨房残留）
	-- ============================================================================
	MPT_Viewer_Close();
	-- ----------------------------------------------------------------------------
	-- ============================================================================
	-- 联机工具箱2.0：退出房间时重置玩家标记管理面板显示状态（条目4.4，硬重置防跨房残留：
	-- 丢弃未保存改动、硬关面板/添加弹窗/对话框，选中/搜索/过滤/排序回默认）
	-- ============================================================================
	MPT_PlayerMark_ResetOnExit();
	-- ----------------------------------------------------------------------------

	Controls.CountdownTimerAnim:ClearAnimCallback();
	
	-- Force close all popups because they are modal and will remain visible even if the screen is hidden
	for _, playerEntry:table in ipairs(g_PlayerEntries) do
		playerEntry.SlotTypePulldown:ForceClose();
		playerEntry.AlternateSlotTypePulldown:ForceClose();
		playerEntry.TeamPullDown:ForceClose();
		playerEntry.PlayerPullDown:ForceClose();
		playerEntry.HandicapPullDown:ForceClose();
	end

	-- Destroy setup parameters.
	HideGameSetup(function()
		-- Reset instances here.
		m_gameSetupParameterIM:ResetInstances();
	end);
	
	-- Destroy individual player parameters.
	ReleasePlayerParameters();

	-- Exit directly to Lobby
	ResetChat();
	UIManager:DequeuePopup( ContextPtr );
end

function GetPlayerEntry(playerID)
	local playerEntry = g_PlayerEntries[playerID];
	if(playerEntry == nil) then
		-- need to create the player entry.
		--print("creating playerEntry for player " .. tostring(playerID));
		playerEntry = m_playersIM:GetInstance();

		--SetupTeamPulldown( playerID, playerEntry.TeamPullDown );

		local civTooltipData : table = {
			InfoStack			= m_CivTooltip.InfoStack,
			InfoScrollPanel		= m_CivTooltip.InfoScrollPanel;
			CivToolTipSlide		= m_CivTooltip.CivToolTipSlide;
			CivToolTipAlpha		= m_CivTooltip.CivToolTipAlpha;
			UniqueIconIM		= m_CivTooltip.UniqueIconIM;		
			HeaderIconIM		= m_CivTooltip.HeaderIconIM;
			CivHeaderIconIM		= m_CivTooltip.CivHeaderIconIM;
			HeaderIM			= m_CivTooltip.HeaderIM;
			HasLeaderPlacard	= false;
		};

		SetupSplitLeaderPulldown(playerID, playerEntry,"PlayerPullDown",nil,nil,civTooltipData);
		SetupTeamPulldown(playerID, playerEntry.TeamPullDown);
		SetupHandicapPulldown(playerID, playerEntry.HandicapPullDown);

		--playerEntry.PlayerCard:RegisterCallback( Mouse.eLClick, OnSwapButton );
		--playerEntry.PlayerCard:SetVoid1(playerID);
		-- ============================================================================
		-- 联机工具箱2.0 条目3.8：KickButton 已移除（XML 同步删除），踢出改由槽位类型下拉框 kickOption 项触发 OnKickButton
		-- playerEntry.KickButton:RegisterCallback( Mouse.eLClick, OnKickButton );
		-- playerEntry.KickButton:SetVoid1(playerID);
		-- ----------------------------------------------------------------------------
		playerEntry.AddPlayerButton:RegisterCallback( Mouse.eLClick, OnAddPlayer );
		playerEntry.AddPlayerButton:SetVoid1(playerID);
		--[[ Prototype Mod Status Progress Bars
		playerEntry.PlayerModProgressStack:SetHide(true);
		--]]
		playerEntry.ReadyImage:RegisterCallback( Mouse.eLClick, OnPlayerEntryReady );
		playerEntry.ReadyImage:SetVoid1(playerID);
		-- ============================================================================
		-- 联机工具箱2.0 条目4.4：玩家名热区按钮——点击打开玩家标记「添加玩家」弹窗并预填该槽位网络ID/昵称
		playerEntry.PlayerNameButton:RegisterCallback( Mouse.eLClick, MPT_PlayerMark_OnSlotNameClick );
		playerEntry.PlayerNameButton:SetVoid1(playerID);
		-- ----------------------------------------------------------------------------

		g_PlayerEntries[playerID] = playerEntry;
		g_PlayerRootToPlayerID[tostring(playerEntry.Root)] = playerID;

		-- Remember starting ready status.
		local pPlayerConfig = PlayerConfigurations[playerID];
		g_PlayerReady[playerID] = pPlayerConfig:GetReady();

		UpdatePlayerEntry(playerID);

		Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	end

	return playerEntry;
end

-------------------------------------------------
-- PopulateSlotTypePulldown
-------------------------------------------------
function PopulateSlotTypePulldown( pullDown, playerID, slotTypeOptions )
	
	local instanceManager = pullDown["InstanceManager"];
	if not instanceManager then
		instanceManager = PullDownInstanceManager:new("InstanceOne", "Button", pullDown);
		pullDown["InstanceManager"] = instanceManager;
	end
	
	
	instanceManager:ResetInstances();
	pullDown.ItemCount = 0;

	for i, pair in ipairs(slotTypeOptions) do

		local pPlayerConfig = PlayerConfigurations[playerID];
		local playerSlotStatus = pPlayerConfig:GetSlotStatus();

		-- This option is a valid swap player option.
		local showSwapButton = pair.slotStatus == -1 
			and playerSlotStatus ~= SlotStatus.SS_CLOSED -- Can't swap to closed slots.
			and not pPlayerConfig:IsLocked() -- Can't swap to locked slots.
			and not GameConfiguration.IsHotseat() -- no swap option in hotseat.
			and not GameConfiguration.IsPlayByCloud() -- no swap option in PlayByCloud.
			and not GameConfiguration.IsMatchMaking() -- or when matchmaking
			and playerID ~= Network.GetLocalPlayerID();

		-- This option is a valid slot type option.
		-- ============================================================================
		-- 联机工具箱2.0 条目3.8：kickOption（移除玩家）项不走通用槽位逻辑（slotStatus=-2 哨兵防止在开放槽等处误显示），按 IsPlayerKickable 显隐，仅房主可见
		-- local showSlotButton = CheckShowSlotButton(pair, playerID);
		local showSlotButton = not pair.kickOption and CheckShowSlotButton(pair, playerID);
		local showKickButton = pair.kickOption == true and IsPlayerKickable(playerID);
		-- ----------------------------------------------------------------------------

		-- Valid state for hotseatOnly flag
		local hotseatOnlyCheck = (GameConfiguration.IsHotseat() and pair.hotseatAllowed) or (not GameConfiguration.IsHotseat() and not pair.hotseatOnly);

		-- ============================================================================
		-- 联机工具箱2.0 条目3.8：显示条件并入 showKickButton
		-- if(	hotseatOnlyCheck
		-- 	and (showSwapButton or showSlotButton))then
		if(	hotseatOnlyCheck
			and (showSwapButton or showSlotButton or showKickButton))then
		-- ----------------------------------------------------------------------------

			pullDown.ItemCount = pullDown.ItemCount + 1;
			local instance = instanceManager:GetInstance();
			local slotDisplayName = pair.name;
			local slotToolTip = pair.tooltip;

			-- In PlayByCloud OPEN slots are autoflagged as HumanRequired., morph the display name and tooltip.
			if(GameConfiguration.IsPlayByCloud() and pair.slotStatus == SlotStatus.SS_OPEN) then
				slotDisplayName = "LOC_SLOTTYPE_HUMANREQ";
				slotToolTip = "LOC_SLOTTYPE_HUMANREQ_TT";
			end

			instance.Button:LocalizeAndSetText( slotDisplayName );

			if pair.slotStatus == -1 then
				local isHuman = (playerSlotStatus == SlotStatus.SS_TAKEN);
				instance.Button:LocalizeAndSetToolTip(isHuman and "TXT_KEY_MP_SWAP_WITH_PLAYER_BUTTON_TT" or "TXT_KEY_MP_SWAP_BUTTON_TT");
			else
				instance.Button:LocalizeAndSetToolTip( slotToolTip );
			end
			instance.Button:SetVoids( playerID, i );	
		end
	end

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback(OnSlotType);
	pullDown:SetDisabled(pullDown.ItemCount < 1);
end

function CheckShowSlotButton(slotData :table, playerID: number)
	local pPlayerConfig :object = PlayerConfigurations[playerID];
	local playerSlotStatus :number = pPlayerConfig:GetSlotStatus();

	if(slotData.slotStatus == -1) then
		return false;
	end

	
	-- Special conditions for changing slot types for human slots in network games.
	if(playerSlotStatus == SlotStatus.SS_TAKEN and not GameConfiguration.IsHotseat()) then
		-- You can't change human player slots outside of hotseat mode.
		return false;
	end

	-- You can't switch a civilization to open/closed if the game is at the minimum player count.
	if(slotData.slotStatus == SlotStatus.SS_CLOSED or slotData.slotStatus == SlotStatus.SS_OPEN) then
		if(playerSlotStatus == SlotStatus.SS_TAKEN or playerSlotStatus == SlotStatus.SS_COMPUTER) then -- Current SlotType is a civ
			-- In PlayByCloud OPEN slots are autoflagged as HumanRequired.
			-- We allow them to bypass the minimum player count because 
			-- a human player must occupy the slot for the game to launch. 
			if(not GameConfiguration.IsPlayByCloud() or slotData.slotStatus ~= SlotStatus.SS_OPEN) then
				-- ============================================================================
				-- 联机工具箱2.0：允许把AI关到只剩1名参与者（配合单人开局）；最后1个槽位仍不可关
				-- if(GameConfiguration.GetParticipatingPlayerCount() <= g_currentMinPlayers)	 then
				if(GameConfiguration.GetParticipatingPlayerCount() <= 1)	 then
				-- ----------------------------------------------------------------------------
					return false;				
				end
			end
		end
	end

	-- Can't change the slot type of locked player slots.
	if(pPlayerConfig:IsLocked()) then
		return false;
	end

	-- Can't change slot type in matchmaded games. 
	if(GameConfiguration.IsMatchMaking()) then
		return false;
	end

	-- Only the host can change non-local slots.
	if(not Network.IsGameHost() and playerID ~= Network.GetLocalPlayerID()) then
		return false;
	end

	-- Can normally only change slot types before the game has started unless this is a option that can be changed mid-game in hotseat.
	if(GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME) then
		if(not slotData.hotseatInProgress or not GameConfiguration.IsHotseat()) then
			return false;
		end
	end

	return true;
end

-------------------------------------------------
-- Team Scripting
-------------------------------------------------
function GetTeamCounts( teamCountTable :table )
	for playerID, teamID in pairs(g_cachedTeams) do
		if(teamCountTable[teamID] == nil) then
			teamCountTable[teamID] = 1;
		else
			teamCountTable[teamID] = teamCountTable[teamID] + 1;
		end
	end
end

function AddTeamPulldownEntry( playerID:number, pullDown:table, instanceManager:table, teamID:number, teamName:string )
	
	local instance = instanceManager:GetInstance();
	
	if teamID >= 0 then
		local teamIconName:string = TEAM_ICON_PREFIX .. tostring(teamID);
		instance.ButtonImage:SetSizeVal(TEAM_ICON_SIZE, TEAM_ICON_SIZE);
		instance.ButtonImage:SetIcon(teamIconName, TEAM_ICON_SIZE);
		instance.ButtonImage:SetColor(GetTeamColor(teamID));
	end

	instance.Button:SetVoids( playerID, teamID );
end

function SetupTeamPulldown( playerID:number, pullDown:table )

	local instanceManager = pullDown["InstanceManager"];
	if not instanceManager then
		instanceManager = PullDownInstanceManager:new("InstanceOne", "Button", pullDown);
		pullDown["InstanceManager"] = instanceManager;
	end
	instanceManager:ResetInstances();

	local teamCounts = {};
	GetTeamCounts(teamCounts);

	local pulldownEntries = {};
	local noTeams = GameConfiguration.GetValue("NO_TEAMS");

	-- Always add "None" entry
	local newPulldownEntry:table = {};
	newPulldownEntry.teamID = -1;
	newPulldownEntry.teamName = GameConfiguration.GetTeamName(-1);
	table.insert(pulldownEntries, newPulldownEntry);

	if(not noTeams) then
		for teamID, playerCount in pairs(teamCounts) do
			if teamID ~= -1 then
				newPulldownEntry = {};
				newPulldownEntry.teamID = teamID;
				newPulldownEntry.teamName = GameConfiguration.GetTeamName(teamID);
				table.insert(pulldownEntries, newPulldownEntry);
			end
		end

		-- Add an empty team slot so players can join/create a new team
		local newTeamID :number = 0;
		while(teamCounts[newTeamID] ~= nil) do
			newTeamID = newTeamID + 1;
		end
		local newTeamName : string = tostring(newTeamID);
		newPulldownEntry = {};
		newPulldownEntry.teamID = newTeamID;
		newPulldownEntry.teamName = newTeamName;
		table.insert(pulldownEntries, newPulldownEntry);
	end

	table.sort(pulldownEntries, function(a, b) return a.teamID < b.teamID; end);

	for pullID, curPulldownEntry in ipairs(pulldownEntries) do
		AddTeamPulldownEntry(playerID, pullDown, instanceManager, curPulldownEntry.teamID, curPulldownEntry.teamName);
	end

	pullDown:CalculateInternals();
	pullDown:RegisterSelectionCallback( OnTeamPull );
end

function RebuildTeamPulldowns()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		SetupTeamPulldown(playerID, playerEntry.TeamPullDown);
	end
end

function UpdateTeamList(updateOpenEmptyTeam)
	if(updateOpenEmptyTeam) then
		-- Regenerate the team pulldowns to show at least one empty team option so players can create new teams.
		RebuildTeamPulldowns();
	end

	CheckTeamsValid(); -- Check to see if the teams are valid for game start.
	CheckGameAutoStart();

	
	
	Controls.PlayerListStack:CalculateSize();
	Controls.PlayersScrollPanel:CalculateSize();
	Controls.HotseatDeco:SetHide(not GameConfiguration.IsHotseat());
end

-------------------------------------------------
-- UpdatePlayerEntry
-------------------------------------------------
function UpdateAllPlayerEntries()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		 UpdatePlayerEntry(playerID);
	end
end

-- Update the disabled state of the slot type pulldown for all players.
function UpdateAllPlayerEntries_SlotTypeDisabled()
	for playerID, playerEntry in pairs( g_PlayerEntries ) do
		 UpdatePlayerEntry_SlotTypeDisabled(playerID);
	end
end

-- Update the disabled state of the slot type pulldown for this player.
function UpdatePlayerEntry_SlotTypeDisabled(playerID)
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];
	local playerEntry = g_PlayerEntries[playerID];
	if(playerEntry ~= nil) then

		-- Disable the pulldown if there are no items in it.
		local itemCount = playerEntry.SlotTypePulldown.ItemCount or 0;

		-- The slot type pulldown handles user access permissions internally (See PopulateSlotTypePulldown()).  
		-- However, we need to disable the pulldown entirely if the local player has readied up.
		local bCanChangeSlotType:boolean = not localPlayerConfig:GetReady() 
											and itemCount > 0; -- No available slot type options.

		playerEntry.AlternateSlotTypePulldown:SetDisabled(not bCanChangeSlotType);
		playerEntry.SlotTypePulldown:SetDisabled(not bCanChangeSlotType);
	end
end

function UpdatePlayerEntry(playerID)
	local playerEntry = g_PlayerEntries[playerID];
	if(playerEntry ~= nil) then
		local localPlayerID = Network.GetLocalPlayerID();
		local localPlayerConfig = PlayerConfigurations[localPlayerID];
		local pPlayerConfig = PlayerConfigurations[playerID];
		local slotStatus = pPlayerConfig:GetSlotStatus();
		local isMinorCiv = pPlayerConfig:GetCivilizationLevelTypeID() ~= CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
		local isAlive = pPlayerConfig:IsAlive();
		local isActiveSlot = not isMinorCiv 
			and (slotStatus ~= SlotStatus.SS_CLOSED) 
			and (slotStatus ~= SlotStatus.SS_OPEN) 
			and (slotStatus ~= SlotStatus.SS_OBSERVER)
			-- In PlayByCloud, the local player still gets an active slot even if they are dead.  We do this so that players
			--		can rejoin the match to see the end game screen,
			and (isAlive or (GameConfiguration.IsPlayByCloud() and playerID == localPlayerID));
		local isHotSeat:boolean = GameConfiguration.IsHotseat();
		
		-- Has this game aleady been started?  Hot joining or loading a save game.
		local gameInProgress:boolean = GameConfiguration.GetGameState() ~= GameStateTypes.GAMESTATE_PREGAME;

		-- NOTE: UpdatePlayerEntry() currently only has control over the team player attribute.  Everything else is controlled by 
		--		PlayerConfigurationValuesToUI() and the PlayerSetupLogic.  See CheckExternalEnabled().
		-- Can the local player change this slot's attributes (handicap; civ, etc) at this time?
		local bCanChangePlayerValues = not pPlayerConfig:GetReady()  -- Can't change a slot once that player is ready.
										and not gameInProgress -- Can't change player values once the game has been started.
										and not pPlayerConfig:IsLocked() -- Can't change the values of locked players.
										and (playerID == localPlayerID		-- You can change yourself.
											-- Game host can alter all the non-human slots if they are not ready.
											or (slotStatus ~= SlotStatus.SS_TAKEN and Network.IsGameHost() and not localPlayerConfig:GetReady())
											-- The player has permission to change everything in hotseat.
											or isHotSeat);
		

			
		-- ============================================================================
		-- 联机工具箱2.0 条目3.8：KickButton 已移除，原 isKickable 判定抽取为 IsPlayerKickable（供 PopulateSlotTypePulldown 的 kickOption 项显隐）
		-- local isKickable:boolean = Network.IsGameHost()			-- Only the game host may kick
		-- 	and (slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_OBSERVER)
		-- 	and playerID ~= localPlayerID			-- Can't kick yourself
		-- 	and not isHotSeat;	-- Can't kick in hotseat, players use the slot type pulldowns instead.
		-- ----------------------------------------------------------------------------

		-- Show player card for human players only during online matches
		local hidePlayerCard:boolean = isHotSeat or slotStatus ~= SlotStatus.SS_TAKEN;
		local showHotseatEdit:boolean = isHotSeat and slotStatus == SlotStatus.SS_TAKEN;
		playerEntry.SlotTypePulldown:SetHide(hidePlayerCard);
		-- ============================================================================
		-- 联机工具箱2.0 条目4.4：玩家名热区按钮显隐随 SlotTypePulldown（仅其他人类玩家槽位可点，自己除外）
		playerEntry.PlayerNameButton:SetHide(hidePlayerCard or playerID == localPlayerID);
		-- ----------------------------------------------------------------------------
		playerEntry.HotseatEditButton:SetHide(not showHotseatEdit);
		playerEntry.AlternateEditButton:SetHide(not hidePlayerCard);
		playerEntry.AlternateSlotTypePulldown:SetHide(not hidePlayerCard);


		local statusText:string = "";
		if slotStatus == SlotStatus.SS_TAKEN then
			local hostID:number = Network.GetGameHostPlayerID();
			statusText = Locale.Lookup(playerID == hostID and "LOC_SLOTLABEL_HOST" or "LOC_SLOTLABEL_PLAYER");
		elseif slotStatus == SlotStatus.SS_COMPUTER then
			statusText = Locale.Lookup("LOC_SLOTLABEL_COMPUTER");
		elseif slotStatus == SlotStatus.SS_OBSERVER then
			local hostID:number = Network.GetGameHostPlayerID();
			statusText = Locale.Lookup(playerID == hostID and "LOC_SLOTLABEL_OBSERVER_HOST" or "LOC_SLOTLABEL_OBSERVER");
		end
		playerEntry.PlayerStatus:SetText(statusText);
		playerEntry.AlternateStatus:SetText(statusText);

		-- Update cached ready status and play sound if player is newly ready.
		if slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_OBSERVER then
			local isReady:boolean = pPlayerConfig:GetReady();
			if(isReady ~= g_PlayerReady[playerID]) then
				g_PlayerReady[playerID] = isReady;
				if(isReady == true) then
					UI.PlaySound("Play_MP_Player_Ready");
				end
			end
		end

		-- Update ready icon
		local showStatusLabel = not isHotSeat and slotStatus ~= SlotStatus.SS_OPEN;
		if not isHotSeat then
			if g_PlayerReady[playerID] or slotStatus == SlotStatus.SS_COMPUTER then
				playerEntry.ReadyImage:SetTextureOffsetVal(0,136);
			else
				playerEntry.ReadyImage:SetTextureOffsetVal(0,0);
			end

			-- Update status string
			local statusString = NotReadyStatusStr;
			local statusTTString = "";
			if(slotStatus == SlotStatus.SS_TAKEN 
				and not pPlayerConfig:GetModReady() 
				and g_PlayerModStatus[playerID] ~= nil 
				and g_PlayerModStatus[playerID] ~= "") then
				statusString = g_PlayerModStatus[playerID];
			elseif(playerID >= g_currentMaxPlayers) then
				-- Player is invalid slot for this map size.
				statusString = BadMapSizeSlotStatusStr;
				statusTTString = BadMapSizeSlotStatusStrTT;
			elseif(curSlotStatus == SlotStatus.SS_OPEN
				and pPlayerConfig:IsHumanRequired() == true 
				and GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_PREGAME) then
				-- Empty human required slot
				statusString = EmptyHumanRequiredSlotStatusStr;
				statusTTString = EmptyHumanRequiredSlotStatusStrTT;
				showStatusLabel = true;
			elseif(g_PlayerReady[playerID] or slotStatus == SlotStatus.SS_COMPUTER) then
				statusString = ReadyStatusStr;
			end

			-- Check to see if we should warning that this player is above MAX_SUPPORTED_PLAYERS.
			local playersBeforeUs = 0;
			for iLoopPlayer = 0, playerID-1, 1 do	
				local loopPlayerConfig = PlayerConfigurations[iLoopPlayer];
				local loopSlotStatus = loopPlayerConfig:GetSlotStatus();
				local loopIsFullCiv = loopPlayerConfig:GetCivilizationLevelTypeID() == CivilizationLevelTypes.CIVILIZATION_LEVEL_FULL_CIV;
				if( (loopSlotStatus == SlotStatus.SS_COMPUTER or loopSlotStatus == SlotStatus.SS_TAKEN) and loopIsFullCiv ) then
					playersBeforeUs = playersBeforeUs + 1;
				end
			end
			if playersBeforeUs >= MAX_SUPPORTED_PLAYERS then
				statusString = statusString .. "[NEWLINE][COLOR_Red]" .. UnsupportedText;
				if statusTTString ~= "" then
					statusTTString = statusTTString .. "[NEWLINE][COLOR_Red]" .. UnsupportedTextTT;
				else
					statusTTString = "[COLOR_Red]" .. UnsupportedTextTT;
				end
			end

			local err = GetPlayerParameterError(playerID)
			if(err) then
				local reason = err.Reason or "LOC_SETUP_PLAYER_PARAMETER_ERROR";
				statusString = statusString .. "[NEWLINE][COLOR_Red]" .. Locale.Lookup(reason) .. "[ENDCOLOR]";
			end

			playerEntry.StatusLabel:SetText(statusString);
			playerEntry.StatusLabel:SetToolTipString(statusTTString);
		end
		playerEntry.StatusLabel:SetHide(not showStatusLabel);

		if playerID == localPlayerID then
			playerEntry.YouIndicatorLine:SetHide(false);
		else
			playerEntry.YouIndicatorLine:SetHide(true);
		end

		playerEntry.AddPlayerButton:SetHide(true);
		-- Available actions vary if the slot has an active player in it
		if(isActiveSlot) then
			playerEntry.Root:SetHide(false);
			playerEntry.PlayerPullDown:SetHide(false);
			playerEntry.ReadyImage:SetHide(isHotSeat);
			playerEntry.TeamPullDown:SetHide(false);
			playerEntry.HandicapPullDown:SetHide(false);
			-- 联机工具箱2.0 条目3.8：KickButton 已移除（踢出改入槽位类型下拉框，仅房主可见）
			-- playerEntry.KickButton:SetHide(not isKickable);
		else
			if(playerID >= g_currentMaxPlayers) then
				-- inactive slot is invalid for the current map size, hide it.
				playerEntry.Root:SetHide(true);
			elseif slotStatus == SlotStatus.SS_CLOSED then
				
				if (m_iFirstClosedSlot == -1 or m_iFirstClosedSlot == playerID) 
				and Network.IsGameHost() 
				and not localPlayerConfig:GetReady()			-- Hide when the host is ready (to be consistent with the player slot behavior)
				and not gameInProgress 
				and not IsLaunchCountdownActive()				-- Don't show Add Player button while in the launch countdown.
				and not GameConfiguration.IsMatchMaking() then	-- Players can't change number of slots when matchmaking.
					m_iFirstClosedSlot = playerID;
					playerEntry.AddPlayerButton:SetHide(false);
					playerEntry.Root:SetHide(false);
				else
					playerEntry.Root:SetHide(true);
				end
			elseif slotStatus == SlotStatus.SS_OBSERVER and Network.IsPlayerConnected(playerID) then
				playerEntry.Root:SetHide(false);
				playerEntry.PlayerPullDown:SetHide(true);
				playerEntry.TeamPullDown:SetHide(true);
				playerEntry.ReadyImage:SetHide(false);
				playerEntry.HandicapPullDown:SetHide(true);
				-- 联机工具箱2.0 条目3.8：KickButton 已移除（观察者槽位踢出经 AlternateSlotTypePulldown 的 kickOption 项，仅房主可见）
				-- playerEntry.KickButton:SetHide(not isKickable);
			else 
				if(gameInProgress
					-- Explicitedly always hide city states.  
					-- In PlayByCloud, the host uploads the player configuration data for city states after the gamecore resolution for new games,
					-- but this happens prior to setting the gamestate to launched in the save file during the first end turn commit.
					or (slotStatus == SlotStatus.SS_COMPUTER and isMinorCiv)) then
					-- Hide inactive slots for games in progress
					playerEntry.Root:SetHide(true);
				else
					-- Inactive slots are visible in the pregame.
					playerEntry.Root:SetHide(false);
					playerEntry.PlayerPullDown:SetHide(true);
					playerEntry.TeamPullDown:SetHide(true);
					playerEntry.ReadyImage:SetHide(true);
					playerEntry.HandicapPullDown:SetHide(true);
					-- 联机工具箱2.0 条目3.8：KickButton 已移除（踢出改入槽位类型下拉框，仅房主可见）
					-- playerEntry.KickButton:SetHide(true);
				end
			end
		end

		--[[ Prototype Mod Status Progress Bars
		-- Hide the player's mod progress if they are mod ready.
		-- This is how the mod progress is hidden once mod downloads are completed.
		if(pPlayerConfig:GetModReady()) then
			playerEntry.PlayerModProgressStack:SetHide(true);
		end
		--]]

		PopulateSlotTypePulldown( playerEntry.AlternateSlotTypePulldown, playerID, g_slotTypeData );
		PopulateSlotTypePulldown(playerEntry.SlotTypePulldown, playerID, g_slotTypeData);
		UpdatePlayerEntry_SlotTypeDisabled(playerID);

		if(isActiveSlot) then
			PlayerConfigurationValuesToUI(playerID); -- Update player configuration pulldown values.

            local parameters = GetPlayerParameters(playerID);
            if(parameters == nil) then
                parameters = CreatePlayerParameters(playerID);
            end

			if parameters.Parameters ~= nil then
				local parameter = parameters.Parameters["PlayerLeader"];

				local leaderType = parameter.Value.Value;
				local icons = GetPlayerIcons(parameter.Value.Domain, parameter.Value.Value);


				local playerColor = icons.PlayerColor;
				local civIcon = playerEntry["CivIcon"];
                local civIconBG = playerEntry["IconBG"];
                local colorControl = playerEntry["ColorPullDown"];
                local civWarnIcon = playerEntry["WarnIcon"];
				colorControl:SetHide(false);	

				civIconBG:SetHide(true);
                civIcon:SetHide(true);
                if (parameter.Value.Value ~= "RANDOM" and parameter.Value.Value ~= "RANDOM_POOL1" and parameter.Value.Value ~= "RANDOM_POOL2") then
                    local colorAlternate = parameters.Parameters["PlayerColorAlternate"] or 0;
        			local backColor, frontColor = UI.GetPlayerColorValues(playerColor, colorAlternate.Value);
					
					if(backColor and frontColor and backColor ~= 0 and frontColor ~= 0) then
						civIcon:SetIcon(icons.CivIcon);
        				civIcon:SetColor(frontColor);
						civIconBG:SetColor(backColor);

						civIconBG:SetHide(false);
						civIcon:SetHide(false);
	        				
						local itemCount = 0;
						if bCanChangePlayerValues then
							local colorInstanceManager = colorControl["InstanceManager"];
							if not colorInstanceManager then
								colorInstanceManager = PullDownInstanceManager:new( "InstanceOne", "Button", colorControl );
								colorControl["InstanceManager"] = colorInstanceManager;
							end

							colorInstanceManager:ResetInstances();
							for j=0, 3, 1 do					
								local backColor, frontColor = UI.GetPlayerColorValues(playerColor, j);
								if(backColor and frontColor and backColor ~= 0 and frontColor ~= 0) then
									local colorEntry = colorInstanceManager:GetInstance();
									itemCount = itemCount + 1;
	
									colorEntry.CivIcon:SetIcon(icons.CivIcon);
									colorEntry.CivIcon:SetColor(frontColor);
									colorEntry.IconBG:SetColor(backColor);
									colorEntry.Button:SetToolTipString(nil);
									colorEntry.Button:RegisterCallback(Mouse.eLClick, function()
										
										-- Update collision check color
										local primary, secondary = UI.GetPlayerColorValues(playerColor, j);
										m_teamColors[playerID] = {primary, secondary}

										local colorParameter = parameters.Parameters["PlayerColorAlternate"];
										parameters:SetParameterValue(colorParameter, j);
									end);
								end           
							end
						end

						colorControl:CalculateInternals();
						colorControl:SetDisabled(not bCanChangePlayerValues or itemCount == 0 or itemCount == 1);
					
						-- update what color we are for collision checks
						m_teamColors[playerID] = { backColor, frontColor};

						local myTeam = m_teamColors[playerID];
                        local bShowWarning = false;
						for k,v in pairs(m_teamColors) do
							if(k ~= playerID) then
								 if( myTeam and v and UI.ArePlayerColorsConflicting( v, myTeam ) ) then
                                    bShowWarning = true;
                                end
							end
						end
                        civWarnIcon:SetHide(not bShowWarning);
    					if bShowWarning == true then
    						civWarnIcon:LocalizeAndSetToolTip("LOC_SETUP_PLAYER_COLOR_COLLISION");
    					else
    						civWarnIcon:SetToolTipString(nil);
    					end
					end
                end
			end
		else
			local colorControl = playerEntry["ColorPullDown"];
			colorControl:SetHide(true);	
        end
		
		-- TeamPullDown is not controlled by PlayerConfigurationValuesToUI and is set manually.
		local noTeams = GameConfiguration.GetValue("NO_TEAMS");
		-- ============================================================================
		-- 联机工具箱2.0：房主可修改其他真人玩家的队伍（条目3.4）；OnTeamPull 内部已 SetTeam + 广播
		-- playerEntry.TeamPullDown:SetDisabled(not bCanChangePlayerValues or noTeams);
		playerEntry.TeamPullDown:SetDisabled((not bCanChangePlayerValues and not CanHostEditOtherPlayer(playerID)) or noTeams);
		-- ----------------------------------------------------------------------------
		local teamID:number = pPlayerConfig:GetTeam();
		-- If the game is in progress and this player is on a team by themselves, display it as if they are on no team.
		-- We do this to be consistent with the ingame UI.
		if(gameInProgress and GameConfiguration.GetTeamPlayerCount(teamID) <= 1) then
			teamID = TeamTypes.NO_TEAM;
		end
		if teamID >= 0 then
			-- Adjust the texture offset based on the selected team
			local teamIconName:string = TEAM_ICON_PREFIX .. tostring(teamID);
			playerEntry.ButtonSelectedTeam:SetSizeVal(TEAM_ICON_SIZE, TEAM_ICON_SIZE);
			playerEntry.ButtonSelectedTeam:SetIcon(teamIconName, TEAM_ICON_SIZE);
			playerEntry.ButtonSelectedTeam:SetColor(GetTeamColor(teamID));
			playerEntry.ButtonSelectedTeam:SetHide(false);
			playerEntry.ButtonNoTeam:SetHide(true);
		else
			playerEntry.ButtonSelectedTeam:SetHide(true);
			playerEntry.ButtonNoTeam:SetHide(false);
		end

		-- NOTE: order matters. you MUST call this after all other setup and before resize as hotseat will hide/show manipulate elements specific to that mode.
		if(isHotSeat) then
			UpdatePlayerEntry_Hotseat(playerID);		
		end

		-- Slot name toggles based on slotstatus.
		-- Update AFTER hotseat checks as hot seat checks may upate nickname.
		playerEntry.PlayerName:LocalizeAndSetText(pPlayerConfig:GetSlotName()); 
		playerEntry.AlternateName:LocalizeAndSetText(pPlayerConfig:GetSlotName()); 

		-- Update online pip status for human slots.
		if(pPlayerConfig:IsHuman()) then
			local iconStr = onlineIconStr;
			if(not Network.IsPlayerConnected(playerID)) then
				iconStr = offlineIconStr;
			end
			playerEntry.ConnectionStatus:SetText(iconStr);
		end
		
	else
		print("PlayerEntry not found for playerID(" .. tostring(playerID) .. ").");
	end
end

function UpdatePlayerEntry_Hotseat(playerID)
	if(GameConfiguration.IsHotseat()) then
		local playerEntry = g_PlayerEntries[playerID];
		if(playerEntry ~= nil) then
			local localPlayerID = Network.GetLocalPlayerID();
			local pLocalPlayerConfig = PlayerConfigurations[localPlayerID];
			local pPlayerConfig = PlayerConfigurations[playerID];
			local slotStatus = pPlayerConfig:GetSlotStatus();

			g_hotseatNumHumanPlayers = 0;
			g_hotseatNumAIPlayers = 0;
			local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
			for i, iPlayer in ipairs(player_ids) do	
				local curPlayerConfig = PlayerConfigurations[iPlayer];
				local curSlotStatus = curPlayerConfig:GetSlotStatus();
				
				print("UpdatePlayerEntry_Hotseat: playerID=" .. iPlayer .. ", SlotStatus=" .. curSlotStatus);	
				if(curSlotStatus == SlotStatus.SS_TAKEN) then 
					g_hotseatNumHumanPlayers = g_hotseatNumHumanPlayers + 1;
				elseif(curSlotStatus == SlotStatus.SS_COMPUTER) then
					g_hotseatNumAIPlayers = g_hotseatNumAIPlayers + 1;
				end
			end
			print("UpdatePlayerEntry_Hotseat: g_hotseatNumHumanPlayers=" .. g_hotseatNumHumanPlayers .. ", g_hotseatNumAIPlayers=" .. g_hotseatNumAIPlayers);	

			if(slotStatus == SlotStatus.SS_TAKEN) then
				local nickName = pPlayerConfig:GetNickName();
				if(nickName == nil or #nickName == 0) then
					pPlayerConfig:SetHotseatName(DefaultHotseatPlayerName .. " " .. g_hotseatNumHumanPlayers);
				end
			end

			if(not g_isBuildingPlayerList and GameConfiguration.IsHotseat() and (slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_COMPUTER)) then
				UpdateAllDefaultPlayerNames();
			end

			-- 联机工具箱2.0 条目3.8：KickButton 已移除（热座踢出本就走槽位类型下拉，kickOption 项热座不显示）
			-- playerEntry.KickButton:SetHide(true);
			--[[ Prototype Mod Status Progress Bars
			playerEntry.PlayerModProgressStack:SetHide(true);
			--]]

			playerEntry.HotseatEditButton:RegisterCallback(Mouse.eLClick, function()
				UIManager:PushModal(Controls.EditHotseatPlayer, true);
				LuaEvents.StagingRoom_SetPlayerID(playerID);
			end);
		end
	end
end

-- ===========================================================================
function UpdateAllDefaultPlayerNames()
	local humanDefaultPlayerNameConfigs :table = {};
	local humanDefaultPlayerNameEntries :table = {};
	local numHumanPlayers :number = 0;
	local kPlayerIDs :table = GameConfiguration.GetMultiplayerPlayerIDs();

	for i, iPlayer in ipairs(kPlayerIDs) do
		local pCurPlayerConfig	:object = PlayerConfigurations[iPlayer];
		local pCurPlayerEntry	:object = g_PlayerEntries[iPlayer];
		local slotStatus		:number = pCurPlayerConfig:GetSlotStatus();
		
		-- Case where multiple times on one machine it appeared a config could exist
		-- for a taken player but no player object?
		local isSafeToReferencePlayer:boolean = true;
		if pCurPlayerEntry==nil and (slotStatus == SlotStatus.SS_TAKEN) then
			isSafeToReferencePlayer = false;
			UI.DataError("Mismatch player config/entry for player #"..tostring(iPlayer)..". SlotStatus: "..tostring(slotStatus));
		end
		
		if isSafeToReferencePlayer and (slotStatus == SlotStatus.SS_TAKEN) then
			local strRegEx = "^" .. DefaultHotseatPlayerName .. " %d+$"
			print(strRegEx .. " " .. pCurPlayerConfig:GetNickName());
			local isDefaultPlayerName = string.match(pCurPlayerConfig:GetNickName(), strRegEx);
			if(isDefaultPlayerName ~= nil) then
				humanDefaultPlayerNameConfigs[#humanDefaultPlayerNameConfigs+1] = pCurPlayerConfig;
				humanDefaultPlayerNameEntries[#humanDefaultPlayerNameEntries+1] = pCurPlayerEntry;
			end
		end
	end

	for i, v in ipairs(humanDefaultPlayerNameConfigs) do
		local playerConfig = humanDefaultPlayerNameConfigs[i];
		local playerEntry = humanDefaultPlayerNameEntries[i];
		playerConfig:SetHotseatName(DefaultHotseatPlayerName .. " " .. i);
		playerEntry.PlayerName:LocalizeAndSetText(playerConfig:GetNickName()); 
		playerEntry.AlternateName:LocalizeAndSetText(playerConfig:GetNickName());
	end

end

-------------------------------------------------
-- SortPlayerListStack
-------------------------------------------------
function SortPlayerListStack(a, b)
	-- a and b are the Root controls of the PlayerListEntry we are sorting.
	local playerIDA = g_PlayerRootToPlayerID[tostring(a)];
	local playerIDB = g_PlayerRootToPlayerID[tostring(b)];
	if(playerIDA ~= nil and playerIDB ~= nil) then
		local playerConfigA = PlayerConfigurations[playerIDA];
		local playerConfigB = PlayerConfigurations[playerIDB];

		-- push closed slots to the bottom
		if(playerConfigA:GetSlotStatus() == SlotStatus.SS_CLOSED) then
			return false;
		elseif(playerConfigB:GetSlotStatus() == SlotStatus.SS_CLOSED) then
			return true;
		end

		-- Finally, sort by playerID value.
		return playerIDA < playerIDB;
	elseif (playerIDA ~= nil and playerIDB == nil) then
		-- nil entries should be at the end of the list.
		return true;
	elseif(playerIDA == nil and playerIDB ~= nil) then
		-- nil entries should be at the end of the list.
		return false;
	else
		return tostring(a) < tostring(b);				
	end	
end

function UpdateReadyButton_Hotseat()
	if(GameConfiguration.IsHotseat()) then
		if(g_hotseatNumHumanPlayers == 0) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_HOTSEAT_NO_HUMAN_PLAYERS")));
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_HOTSEAT_NO_HUMAN_PLAYERS_TT");
			Controls.ReadyButton:SetDisabled(true);
		elseif(g_hotseatNumHumanPlayers + g_hotseatNumAIPlayers < 2) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS")));
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
			Controls.ReadyButton:SetDisabled(true);
		elseif(not m_bTeamsValid) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_HOTSEAT_INVALID_TEAMS")));
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_HOTSEAT_INVALID_TEAMS_TT");
			Controls.ReadyButton:SetDisabled(true);
		elseif(g_badPlayerForMapSize) then
			Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_PLAYER_MAP_SIZE");
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
			Controls.ReadyButton:SetDisabled(true);
		elseif(g_duplicateLeaders) then
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS")));
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
			Controls.ReadyButton:SetDisabled(true);
		else
			Controls.StartLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_START_GAME")));
			Controls.ReadyButton:SetText("");
			Controls.ReadyButton:LocalizeAndSetToolTip("");
			Controls.ReadyButton:SetDisabled(false);
		end
	end
end

function UpdateReadyButton()
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];

	if(GameConfiguration.IsHotseat()) then
		UpdateReadyButton_Hotseat();
		return;
	end

	local localPlayerEntry = GetPlayerEntry(localPlayerID);
	local localPlayerButton = localPlayerEntry.ReadyImage;
	if(m_countdownType ~= CountdownTypes.None) then
		local startLabel :string = Locale.ToUpper(Locale.Lookup("LOC_GAMESTART_COUNTDOWN_FORMAT"));  -- Defaults to COUNTDOWN_LAUNCH
		local toolTip :string = "";
		if(IsReadyCountdownActive()) then
			startLabel = Locale.ToUpper(Locale.Lookup("LOC_READY_COUNTDOWN_FORMAT"));
			toolTip = Locale.Lookup("LOC_READY_COUNTDOWN_TT");
		elseif(IsWaitForPlayersCountdownActive()) then
			startLabel = Locale.ToUpper(Locale.Lookup("LOC_WAITING_FOR_PLAYERS_COUNTDOWN_FORMAT"));
			toolTip = Locale.Lookup("LOC_WAITING_FOR_PLAYERS_COUNTDOWN_TT");
		end

		local timeRemaining :number = GetCountdownTimeRemaining();
		local intTime :number = math.floor(timeRemaining);
		Controls.StartLabel:SetText( startLabel );
		Controls.ReadyButton:LocalizeAndSetText(  intTime );
		Controls.ReadyButton:LocalizeAndSetToolTip( toolTip );
		Controls.ReadyCheck:LocalizeAndSetToolTip( toolTip );
		localPlayerButton:LocalizeAndSetToolTip( toolTip );
	elseif(IsCloudInProgressAndNotTurn()) then
		Controls.StartLabel:SetText( Locale.ToUpper(Locale.Lookup( "LOC_START_WAITING_FOR_TURN" )));
		Controls.ReadyButton:SetText("");
		Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_START_WAITING_FOR_TURN_TT" );
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_START_WAITING_FOR_TURN_TT" );
		localPlayerButton:LocalizeAndSetToolTip( "LOC_START_WAITING_FOR_TURN_TT" );
	elseif(not g_everyoneReady) then
		-- Local player hasn't readied up yet, just show "Ready"
		Controls.StartLabel:SetText( Locale.ToUpper(Locale.Lookup( "LOC_ARE_YOU_READY" )));
		Controls.ReadyButton:SetText("");
		Controls.ReadyButton:LocalizeAndSetToolTip( "" );
		Controls.ReadyCheck:LocalizeAndSetToolTip( "" );
		localPlayerButton:LocalizeAndSetToolTip( "" );
	-- Local player is ready, show why we're not in the countdown yet!
	elseif(not g_everyoneConnected) then
		-- Waiting for a player to finish connecting to the game.
		Controls.StartLabel:SetText( Locale.ToUpper(Locale.Lookup("LOC_READY_BLOCKED_PLAYERS_CONNECTING")));

		local waitingForJoinersTooltip : string = Locale.Lookup("LOC_READY_BLOCKED_PLAYERS_CONNECTING_TT");
		local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
		for i, iPlayer in ipairs(player_ids) do	
			local curPlayerConfig = PlayerConfigurations[iPlayer];
			local curSlotStatus = curPlayerConfig:GetSlotStatus();
			if(curSlotStatus == SlotStatus.SS_TAKEN and not Network.IsPlayerConnected(playerID)) then
				waitingForJoinersTooltip = waitingForJoinersTooltip .. "[NEWLINE]" .. "(" .. Locale.Lookup(curPlayerConfig:GetPlayerName()) .. ") ";
			end
		end
		Controls.ReadyButton:SetToolTipString( waitingForJoinersTooltip );
		Controls.ReadyCheck:SetToolTipString( waitingForJoinersTooltip );
		localPlayerButton:SetToolTipString( waitingForJoinersTooltip );
	elseif(g_notEnoughPlayers) then
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS");
		Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
		localPlayerButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_NOT_ENOUGH_PLAYERS_TT");
	elseif(not m_bTeamsValid) then
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_TEAMS_INVALID");
		Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_TEAMS_INVALID_TT" );
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_TEAMS_INVALID_TT" );
		localPlayerButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_TEAMS_INVALID_TT" );
	elseif(g_badPlayerForMapSize) then
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_PLAYER_MAP_SIZE");
		Controls.ReadyButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
		localPlayerButton:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_PLAYER_MAP_SIZE_TT", g_currentMaxPlayers);
	elseif(not g_everyoneModReady) then
		-- A player doesn't have the mods required for this game.
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_PLAYERS_NOT_MOD_READY");

		local waitingForModReadyTooltip : string = Locale.Lookup("LOC_READY_BLOCKED_PLAYERS_NOT_MOD_READY");
		local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
		for i, iPlayer in ipairs(player_ids) do	
			local curPlayerConfig = PlayerConfigurations[iPlayer];
			local curSlotStatus = curPlayerConfig:GetSlotStatus();
			if(curSlotStatus == SlotStatus.SS_TAKEN and not curPlayerConfig:GetModReady()) then
				waitingForModReadyTooltip = waitingForModReadyTooltip .. "[NEWLINE]" .. "(" .. Locale.Lookup(curPlayerConfig:GetPlayerName()) .. ") ";
			end
		end
		Controls.ReadyButton:SetToolTipString( waitingForModReadyTooltip );
		Controls.ReadyCheck:SetToolTipString( waitingForModReadyTooltip );
		localPlayerButton:SetToolTipString( waitingForModReadyTooltip );
	elseif(g_duplicateLeaders) then
		Controls.StartLabel:LocalizeAndSetText("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
		Controls.ReadyButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
		localPlayerButton:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_NO_DUPLICATE_LEADERS");
	elseif(not g_humanRequiredFilled) then
		Controls.StartLabel:LocalizeAndSetText("LOC_SETUP_ERROR_HUMANS_REQUIRED");
		Controls.ReadyButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_HUMANS_REQUIRED_TT");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_HUMANS_REQUIRED_TT");
		localPlayerButton:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_HUMANS_REQUIRED");
	elseif(not g_pbcNewGameCheck) then
		Controls.StartLabel:LocalizeAndSetText("LOC_SETUP_ERROR_PLAYBYCLOUD_REMOTE_READY");
		Controls.ReadyButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_PLAYBYCLOUD_REMOTE_READY_TT");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_SETUP_ERROR_PLAYBYCLOUD_REMOTE_READY_TT");
		localPlayerButton:LocalizeAndSetToolTip("LOC_SETUP_ERROR_PLAYBYCLOUD_REMOTE_READY");	
	elseif(not g_pbcMinHumanCheck) then
		Controls.StartLabel:LocalizeAndSetText("LOC_READY_BLOCKED_NOT_ENOUGH_HUMANS");
		Controls.ReadyButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_NOT_ENOUGH_HUMANS_TT");
		Controls.ReadyCheck:LocalizeAndSetToolTip( "LOC_READY_BLOCKED_NOT_ENOUGH_HUMANS_TT");
		localPlayerButton:LocalizeAndSetToolTip("LOC_READY_BLOCKED_NOT_ENOUGH_HUMANS");			
	end

	local errorReason;
	local game_err = GetGameParametersError();
	if(game_err) then
		errorReason = game_err.Reason or "LOC_SETUP_PARAMETER_ERROR";
	end

	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		-- Check for selection error (ownership rules, duplicate leaders, etc)
		local err = GetPlayerParameterError(iPlayer)
		if(err) then
			errorReason = err.Reason or "LOC_SETUP_PLAYER_PARAMETER_ERROR"
		end
	end
	-- Block ready up when there is a civ ownership issue.  
	-- We have to do this because ownership is not communicated to the host.
	if(errorReason) then
		Controls.StartLabel:SetText("[COLOR_RED]" .. Locale.Lookup(errorReason) .. "[ENDCOLOR]");
		Controls.ReadyButton:SetDisabled(true)
		Controls.ReadyCheck:SetDisabled(true);
		localPlayerButton:SetDisabled(true);
	else
		Controls.ReadyButton:SetDisabled(false);
		Controls.ReadyCheck:SetDisabled(false);
		localPlayerButton:SetDisabled(false);
	end
end

-------------------------------------------------
-- Start Game Launch Countdown
-------------------------------------------------
function StartCountdown(countdownType :string)
	if(m_countdownType == countdownType) then
		return;
	end

	local countdownData = g_CountdownData[countdownType];
	if(countdownData == nil) then
		print("ERROR: missing countdownData for type " .. tostring(countdownType));
		return;
	end

	print("Starting Countdown Type " .. tostring(countdownType));
	m_countdownType = countdownType;

	if(countdownData.TimerType == TimerTypes.Script) then
		g_fCountdownTimer = countdownData.CountdownTime;
	else
		g_fCountdownTimer = NO_COUNTDOWN;
	end

	g_fCountdownTickSoundTime = countdownData.TickStartTime;
	g_fCountdownInitialTime = countdownData.CountdownTime;
	g_fCountdownReadyButtonTime = countdownData.CountdownTime;

	Controls.CountdownTimerAnim:RegisterAnimCallback( OnUpdateTimers );

	-- Update m_iFirstClosedSlot's player slot so it will hide the Add Player button if needed for this countdown type.
	if(m_iFirstClosedSlot ~= -1) then
		UpdatePlayerEntry(m_iFirstClosedSlot);
	end

	ShowHideReadyButtons();
end

function StartLaunchCountdown()
	--print("StartLaunchCountdown");
	local gameState = GameConfiguration.GetGameState();
	-- In progress PlayByCloud games and matchmaking games launch instantly.
	if((GameConfiguration.IsPlayByCloud() and gameState == GameStateTypes.GAMESTATE_LAUNCHED)
		or GameConfiguration.IsMatchMaking()) then
		-- Joining a PlayByCloud game already in progress has a much faster countdown to be less annoying.
		StartCountdown(CountdownTypes.Launch_Instant);
	else
		StartCountdown(CountdownTypes.Launch);
	end
end

function StartReadyCountdown()
	StartCountdown(GetReadyCountdownType());
end

-------------------------------------------------
-- Stop Launch Countdown
-------------------------------------------------
function StopCountdown()
	if(m_countdownType ~= CountdownTypes.None) then
		print("Stopping Countdown. m_countdownType=" .. tostring(m_countdownType));
	end

	Controls.TurnTimerMeter:SetPercent(0);
	m_countdownType = CountdownTypes.None;	
	g_fCountdownTimer = NO_COUNTDOWN;
	g_fCountdownInitialTime = NO_COUNTDOWN;
	UpdateReadyButton();

	-- Update m_iFirstClosedSlot's player slot so it will show the Add Player button.
	if(m_iFirstClosedSlot ~= -1) then
		UpdatePlayerEntry(m_iFirstClosedSlot);
	end

	ShowHideReadyButtons();

	Controls.CountdownTimerAnim:ClearAnimCallback();	
end

-------------------------------------------------
-- BuildPlayerList
-------------------------------------------------
function BuildPlayerList()
	ReleasePlayerParameters(); -- Release all the player parameters so they do not have zombie references to the entries we are now wiping.
	g_isBuildingPlayerList = true;
	-- Clear previous data.
	g_PlayerEntries = {};
	g_PlayerRootToPlayerID = {};
	g_cachedTeams = {};
	m_playersIM:ResetInstances();
	m_iFirstClosedSlot = -1;
	local numPlayers:number = 0;

	-- Create a player slot for every current participant and available player slot for the players.
	local player_ids = GameConfiguration.GetMultiplayerPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local pPlayerConfig = PlayerConfigurations[iPlayer];
		if(pPlayerConfig ~= nil
			and IsDisplayableSlot(iPlayer)) then
			if(GameConfiguration.IsHotseat()) then
				local nickName = pPlayerConfig:GetNickName();
				if(nickName == nil or #nickName == 0) then
					pPlayerConfig:SetHotseatName(DefaultHotseatPlayerName .. " " .. iPlayer + 1);
				end
			end
            m_teamColors[numPlayers] = nil;
            -- Trigger a fake OnTeamChange on every active player slot to automagically create required PlayerEntry/TeamEntry
			OnTeamChange(iPlayer, true);
			numPlayers = numPlayers + 1;
            m_numPlayers = numPlayers;
		end	
	end

	UpdateTeamList(true);

	SetupGridLines(numPlayers - 1);

	g_isBuildingPlayerList = false;
end

-- ===========================================================================
-- Adjust vertical grid lines
-- ===========================================================================
function RealizeGridSize()
	Controls.PlayerListStack:CalculateSize();
	Controls.PlayersScrollPanel:CalculateSize();

	-- 联机工具箱2.0：竖线由 Line 改为细 Box 后同步改用 SetSizeY（SetEndY 为 Line API，且实测对 XML parent 表达式无效）
	local gridLineHeight:number = math.max(Controls.PlayerListStack:GetSizeY(), Controls.PlayersScrollPanel:GetSizeY());
	for i = 1, NUM_COLUMNS do
		Controls["GridLine_" .. i]:SetSizeY(gridLineHeight);
	end

	Controls.GridContainer:SetSizeY(gridLineHeight);
end

-------------------------------------------------
-- ResetChat
-------------------------------------------------
function ResetChat()
	m_ChatInstances = {}
	Controls.ChatStack:DestroyAllChildren();
	ChatPrintHelpHint(Controls.ChatStack, m_ChatInstances, Controls.ChatScroll);
end

-------------------------------------------------
--	Should only be ticking if there are timers active.
-------------------------------------------------
function OnUpdateTimers( uiControl:table, fProgress:number )

	local fDTime:number = UIManager:GetLastTimeDelta();

	if(m_countdownType == CountdownTypes.None) then
		Controls.CountdownTimerAnim:ClearAnimCallback();
	else
		UpdateCountdownTimeRemaining();
		local timeRemaining :number = GetCountdownTimeRemaining();
		Controls.TurnTimerMeter:SetPercent(timeRemaining / g_fCountdownInitialTime);
		if( IsLaunchCountdownActive() and not Network.IsEveryoneConnected() ) then
			-- not all players are connected anymore.  This is probably due to a player join in progress.
			StopCountdown();
		elseif( timeRemaining <= 0 ) then
			local stopCountdown = true;
			local checkForStart = false;
			if( IsLaunchCountdownActive() ) then
				-- Timer elapsed, launch the game if we're the netsession host.
				if(Network.IsNetSessionHost()) then
					Network.LaunchGame();
				end
			elseif( IsReadyCountdownActive() ) then
				-- Force ready the local player
				SetLocalReady(true);

				if(IsUseWaitingForPlayersCountdown()) then
					-- Transition to the Waiting For Players countdown.
					StartCountdown(CountdownTypes.WaitForPlayers);
					stopCountdown = false;
				end
			elseif( IsWaitForPlayersCountdownActive() ) then
				-- After stopping the countdown, recheck for start.  This should trigger the launch countdown because all players should be past their ready countdowns.
				checkForStart = true;			
			end

			if(stopCountdown == true) then
				StopCountdown();
			end

			if(checkForStart == true) then
				CheckGameAutoStart();
			end
		else
			-- Update countdown tick sound.
			if( timeRemaining < g_fCountdownTickSoundTime) then
				g_fCountdownTickSoundTime = g_fCountdownTickSoundTime-1; -- set countdown tick for next second.
				UI.PlaySound("Play_MP_Game_Launch_Timer_Beep");
			end

			-- Update countdown ready button.
			if( timeRemaining < g_fCountdownReadyButtonTime) then
				g_fCountdownReadyButtonTime = g_fCountdownReadyButtonTime-1; -- set countdown tick for next second.
				UpdateReadyButton();
			end
		end
	end
end

function UpdateCountdownTimeRemaining()
	local countdownData :table = g_CountdownData[m_countdownType];
	if(countdownData == nil) then
		print("ERROR: missing countdown data!");
		return;
	end

	if(countdownData.TimerType == TimerTypes.NetworkManager) then
		-- Network Manager timer updates itself.
		return;
	end

	local fDTime:number = UIManager:GetLastTimeDelta();
	g_fCountdownTimer = g_fCountdownTimer - fDTime;
end

-------------------------------------------------
-------------------------------------------------
function OnShow()
	-- Fetch g_currentMaxPlayers because it might be stale due to loading a save.
	-- ============================================================================
	-- 联机工具箱2.0：OnShow 中硬编码的人数上限 12 -> MAX_EVER_PLAYERS（与上方常量统一，避免两处不同步）
	-- g_currentMaxPlayers = math.min(MapConfiguration.GetMaxMajorPlayers(), 12);
	g_currentMaxPlayers = math.min(MapConfiguration.GetMaxMajorPlayers(), MAX_EVER_PLAYERS);
	-- ----------------------------------------------------------------------------
	RefreshHostPermissions();	-- 联机工具箱2.0：刷新「AI槽位」按钮可见性（条目3.2）
	m_shownPBCReadyPopup = false;
	m_exitReadyWait = false;
	RestoreAdCarousel();	-- 联机工具箱2.0：重进准备房间恢复广告面板（条目3.6）

	local networkSessionID:number = Network.GetSessionID();
	if m_sessionID ~= networkSessionID then
		-- This is a fresh session.
		m_sessionID = networkSessionID;
		MPT_ResetModCheckSession();	-- 联机工具箱2.0：新房间重置模组校验生命周期（条目4.1）
		-- ============================================================================
		-- 联机工具箱2.0：新房间自动更新本局已启用的非官方创意工坊mod（条目4.7，移植1.67 UpdateAllMods；
		-- 触发点由 1.67 的 RealizeGameSetup 改为新会话分支，每进房只触发一次；函数定义在文件末尾条目4.7分区）
		-- ----------------------------------------------------------------------------
		MPT_UpdateEnabledMods();

		StopCountdown();

		-- When using the ready countdown mode, start the ready countdown if the player is not already readied up.
		-- If the player is already readied up, we just don't allow them to unready.
		local localPlayerID :number = Network.GetLocalPlayerID();
		local localPlayerConfig :table = PlayerConfigurations[localPlayerID];
		if(IsUseReadyCountdown() 
			and localPlayerConfig ~= nil
			and localPlayerConfig:GetReady() == false) then
			StartReadyCountdown();
		end
	end

	InitializeReadyUI();
	ShowHideInviteButton();	
	ShowHideTopLeftButtons();
	RealizeGameSetup();
	BuildPlayerList();
	PopulateTargetPull(Controls.ChatPull, Controls.ChatEntry, Controls.ChatIcon, m_playerTargetEntries, m_playerTarget, false, OnChatPulldownChanged);
	ShowHideChatPanel();

	local pFriends = Network.GetFriends();
	if (pFriends ~= nil) then
		pFriends:SetRichPresence("civPresence", Network.IsGameHost() and "LOC_PRESENCE_HOSTING_GAME" or "LOC_PRESENCE_IN_STAGING_ROOM");
	end

	UpdateFriendsList();
	RealizeInfoTabs();
	RealizeGridSize();

	-- Forgive me universe!
	Controls.ReadyButton:SetOffsetY(isHotSeat and -16 or -18);

	if(Automation.IsActive()) then
		if(not Network.IsGameHost()) then
			-- Remote clients ready up immediately.
			SetLocalReady(true);
		else
			local minPlayers = Automation.GetSetParameter("CurrentTest", "MinPlayers", 2);
			if (minPlayers ~= nil) then
				-- See if we are going to be the only one in the game, set ourselves ready. 
				if (minPlayers == 1) then
					Automation.Log("HostGame MinPlayers==1, host readying up.");
					SetLocalReady(true);
				end
			end
		end
	end
end


function OnChatPulldownChanged(newTargetType :number, newTargetID :number)
	local textControl:table = Controls.ChatPull:GetButton():GetTextControl();
	local text:string = textControl:GetText();
	Controls.ChatPull:SetToolTipString(text);
end

-------------------------------------------------
-------------------------------------------------
function InitializeReadyUI()
	-- Set initial ready check state.  This might be dirty from a previous staging room.
	local localPlayerID = Network.GetLocalPlayerID();
	local localPlayerConfig = PlayerConfigurations[localPlayerID];

	if(IsCloudInProgressAndNotTurn()) then
		-- Show the ready check as unselected while in an inprogress PlayByCloud match where it is not our turn.  
		-- Clicking the ready button will instant launch the match so the player can observe the current game state.
		Controls.ReadyCheck:SetSelected(false);
	else
		Controls.ReadyCheck:SetSelected(localPlayerConfig:GetReady());
	end

	-- Hotseat doesn't use the readying mechanic (countdown; ready background elements; ready column). 
	local isHotSeat:boolean = GameConfiguration.IsHotseat();
	Controls.LargeCompassDeco:SetHide(isHotSeat);
	Controls.TurnTimerBG:SetHide(isHotSeat);
	Controls.TurnTimerMeter:SetHide(isHotSeat);
	Controls.TurnTimerHotseatBG:SetHide(not isHotSeat);
	Controls.ReadyColumnLabel:SetHide(isHotSeat);

	ShowHideReadyButtons();
end

-------------------------------------------------
-------------------------------------------------
function ShowHideInviteButton()
	local canInvite :boolean = CanInviteFriends(true);
	Controls.InviteButton:SetHide( not canInvite );
end

-------------------------------------------------
-------------------------------------------------
function ShowHideTopLeftButtons()
	local showEndGame :boolean = GameConfiguration.IsPlayByCloud() and Network.IsGameHost();
	local showQuitGame : boolean = GameConfiguration.IsPlayByCloud();

	Controls.EndGameButton:SetHide( not showEndGame);
	Controls.QuitGameButton:SetHide( not showQuitGame);

	Controls.LeftTopButtonStack:CalculateSize();	
end

-------------------------------------------------
-------------------------------------------------
function ShowHideReadyButtons()
	-- show ready button when in not in a countdown or hotseat.
	local showReadyCheck = not GameConfiguration.IsHotseat() and (m_countdownType == CountdownTypes.None);
	Controls.ReadyCheckContainer:SetHide(not showReadyCheck);
	Controls.ReadyButtonContainer:SetHide(showReadyCheck);
end

-------------------------------------------------
-------------------------------------------------
function ShowHideChatPanel()
	if(GameConfiguration.IsHotseat() or not UI.HasFeature("Chat") or GameConfiguration.IsPlayByCloud()) then
		Controls.ChatContainer:SetHide(true);
	else
		Controls.ChatContainer:SetHide(false);
	end
	--Controls.TwinPanelStack:CalculateSize();
end

-------------------------------------------------------------------------------
-- Setup Player Interface
-- This gets or creates player parameters for a given player id.
-- It then appends a driver to the setup parameter to control a visual 
-- representation of the parameter
-------------------------------------------------------------------------------
function SetupSplitLeaderPulldown(playerId:number, instance:table, pulldownControlName:string, civIconControlName, leaderIconControlName, tooltipControls:table)
	local parameters = GetPlayerParameters(playerId);
	if(parameters == nil) then
		parameters = CreatePlayerParameters(playerId);
	end

	-- Need to save our master tooltip controls so that we can update them if we hop into advanced setup and then go back to basic setup
	if (tooltipControls.HasLeaderPlacard) then
		m_tooltipControls = {};
		m_tooltipControls = tooltipControls;
	end

	-- Defaults
	if(leaderIconControlName == nil) then
		leaderIconControlName = "LeaderIcon";
	end
		
	local control = instance[pulldownControlName];
	local leaderIcon = instance[leaderIconControlName];
	local civIcon = instance["CivIcon"];
	local civIconBG = instance["IconBG"];
	local civWarnIcon = instance["WarnIcon"];
    local scrollText = instance["ScrollText"];
	local instanceManager = control["InstanceManager"];
	if not instanceManager then
		instanceManager = PullDownInstanceManager:new( "InstanceOne", "Button", control );
		control["InstanceManager"] = instanceManager;
	end

	local colorControl = instance["ColorPullDown"];
	local colorInstanceManager = colorControl["InstanceManager"];
	if not colorInstanceManager then
		colorInstanceManager = PullDownInstanceManager:new( "InstanceOne", "Button", colorControl );
		colorControl["InstanceManager"] = colorInstanceManager;
	end
    colorControl:SetDisabled(true);

	local controls = parameters.Controls["PlayerLeader"];
	if(controls == nil) then
		controls = {};
		parameters.Controls["PlayerLeader"] = controls;
	end

	m_currentInfo = {										
		CivilizationIcon = "ICON_CIVILIZATION_UNKNOWN",
		LeaderIcon = "ICON_LEADER_DEFAULT",
		CivilizationName = "LOC_RANDOM_CIVILIZATION",
		LeaderName = "LOC_RANDOM_LEADER"
	};

	civWarnIcon:SetHide(true);
	civIconBG:SetHide(true);

	table.insert(controls, {
		UpdateValue = function(v)
			local button = control:GetButton();

			if(v == nil) then
				button:LocalizeAndSetText("LOC_SETUP_ERROR_INVALID_OPTION");
				button:ClearCallback(Mouse.eMouseEnter);
				button:ClearCallback(Mouse.eMouseExit);
			else
				local caption = v.Name;
				if(v.Invalid) then
					local err = v.InvalidReason or "LOC_SETUP_ERROR_INVALID_OPTION";
					caption = caption .. "[NEWLINE][COLOR_RED](" .. Locale.Lookup(err) .. ")[ENDCOLOR]";
				end

				if(scrollText ~= nil) then
					scrollText:SetText(caption);
					button:LocalizeAndSetText("");
				else
					button:SetText(caption);
				end
				
				local icons = GetPlayerIcons(v.Domain, v.Value);
				local playerColor = icons.PlayerColor or "";
				if(leaderIcon) then
					leaderIcon:SetIcon(icons.LeaderIcon);
				end

				if(not tooltipControls.HasLeaderPlacard) then
					-- Upvalues
					local info;
					local domain = v.Domain;
					local value = v.Value;
					button:RegisterCallback( Mouse.eMouseEnter, function() 
						if(info == nil) then info = GetPlayerInfo(domain, value, playerId); end
						DisplayCivLeaderToolTip(info, tooltipControls, false); 
					end);
					
					button:RegisterCallback( Mouse.eMouseExit, function() 
						if(info == nil) then info = GetPlayerInfo(domain, value, playerId); end
						DisplayCivLeaderToolTip(info, tooltipControls, true); 
					end);
				end

				local primaryColor, secondaryColor = UI.GetPlayerColorValues(playerColor, 0);
				if v.Value == "RANDOM" or v.Value == "RANDOM_POOL1" or v.Value == "RANDOM_POOL2" or primaryColor == nil then
					civIconBG:SetHide(true);
					civIcon:SetHide(true);
					civWarnIcon:SetHide(true);
                    colorControl:SetDisabled(true);
				else

					local colorCount = 0;
					for j=0, 3, 1 do
						local backColor, frontColor = UI.GetPlayerColorValues(playerColor, j);
						if(backColor and frontColor and backColor ~= 0 and frontColor ~= 0) then
							colorCount = colorCount + 1;
						end
					end

					local notExternalEnabled = not CheckExternalEnabled(playerId, true, true, nil);
					colorControl:SetDisabled(notExternalEnabled or colorCount == 0 or colorCount == 1);

                    -- also update collision check color
                    -- Color collision checking.
					local myTeam = m_teamColors[playerId];
					local bShowWarning = false;
					for k , v in pairs(m_teamColors) do
						if(k ~= playerId) then
							if( myTeam and v and myTeam[1] == v[1] and myTeam[2] == v[2] ) then
								bShowWarning = true;
							end
						end
					end
					civWarnIcon:SetHide(not bShowWarning);
    				if bShowWarning == true then
    					civWarnIcon:LocalizeAndSetToolTip("LOC_SETUP_PLAYER_COLOR_COLLISION");
    				else
    					civWarnIcon:SetToolTipString(nil);
    				end	
                end
			end		
		end,
		UpdateValues = function(values)
			instanceManager:ResetInstances();
            local iIteratedPlayerID = 0;

			-- Avoid creating call back for each value.
			local hasPlacard = tooltipControls.HasLeaderPlacard;
			local OnMouseExit = function()
				DisplayCivLeaderToolTip(m_currentInfo, tooltipControls, not hasPlacard);
			end;

			for i,v in ipairs(values) do
				local icons = GetPlayerIcons(v.Domain, v.Value);
				local playerColor = icons.PlayerColor;

				local entry = instanceManager:GetInstance();
				
				local caption = v.Name;
				if(v.Invalid) then 
					local err = v.InvalidReason or "LOC_SETUP_ERROR_INVALID_OPTION";
					caption = caption .. "[NEWLINE][COLOR_RED](" .. Locale.Lookup(err) .. ")[ENDCOLOR]";
				end

				if(entry.ScrollText ~= nil) then
					entry.ScrollText:SetText(caption);
				else
					entry.Button:SetText(caption);
				end
				entry.LeaderIcon:SetIcon(icons.LeaderIcon);
				
				-- Upvalues
				local info;
				local domain = v.Domain;
				local value = v.Value;
				
				entry.Button:RegisterCallback( Mouse.eMouseEnter, function() 
					if(info == nil) then info = GetPlayerInfo(domain, value, playerId); end
					DisplayCivLeaderToolTip(info, tooltipControls, false);
				 end);

				entry.Button:RegisterCallback( Mouse.eMouseExit,OnMouseExit);
				entry.Button:SetToolTipString(nil);			

				entry.Button:RegisterCallback(Mouse.eLClick, function()
					-- ============================================================================
					-- 联机工具箱2.0：房主修改其他真人玩家的领袖（条目3.4）——直接写 PlayerConfigurations + 广播，
					-- 不走参数系统（其 Config_CanWriteParameter 对非本地玩家返回 false 会静默失败）；
					-- 房主路径不执行下方备用色重置，保留对方原配色。
					-- ----------------------------------------------------------------------------
					if CanHostEditOtherPlayer(playerId) then
						HostSetPlayerLeader(playerId, v);
						return;
					end
					if(info == nil) then info = GetPlayerInfo(domain, value); end

					--  if the user picked random, hide the civ icon again
					local primaryColor, secondaryColor = UI.GetPlayerColorValues(playerColor, 0);
					 m_teamColors[playerId] = {primaryColor, secondaryColor};

                    -- set default alternate color to the primary
					local colorParameter = parameters.Parameters["PlayerColorAlternate"]; 
					parameters:SetParameterValue(colorParameter, 0);

                    -- set the team
                    local leaderParameter = parameters.Parameters["PlayerLeader"];
					parameters:SetParameterValue(leaderParameter, v);

					if(playerId == 0) then
						m_currentInfo = info;
					end
				end);
			end
			control:CalculateInternals();
		end,
		SetEnabled = function(enabled, parameter)
			local notExternalEnabled = not CheckExternalEnabled(playerId, enabled, true, parameter);
			local singleOrEmpty = #parameter.Values <= 1;

			-- ============================================================================
			-- 联机工具箱2.0：房主可打开其他真人玩家的领袖下拉（条目3.4）
			-- control:SetDisabled(notExternalEnabled or singleOrEmpty);
			control:SetDisabled((notExternalEnabled and not CanHostEditOtherPlayer(playerId)) or singleOrEmpty);
			-- ----------------------------------------------------------------------------
		end,
	--	SetVisible = function(visible)
	--		control:SetHide(not visible);
	--	end
	});
end

-- ===========================================================================
function OnGameSetupTabClicked()
	UIManager:DequeuePopup( ContextPtr );
end

-- ===========================================================================

function RealizeShellTabs()
	m_shellTabIM:ResetInstances();

	local gameSetup:table = m_shellTabIM:GetInstance();
	gameSetup.Button:SetText(LOC_GAME_SETUP);
	gameSetup.SelectedButton:SetText(LOC_GAME_SETUP);
	gameSetup.Selected:SetHide(true);
	gameSetup.Button:RegisterCallback( Mouse.eLClick, OnGameSetupTabClicked );

	AutoSizeGridButton(gameSetup.Button,250,32,10,"H");
	AutoSizeGridButton(gameSetup.SelectedButton,250,32,20,"H");
	gameSetup.TopControl:SetSizeX(gameSetup.Button:GetSizeX());

	local stagingRoom:table = m_shellTabIM:GetInstance();
	stagingRoom.Button:SetText(LOC_STAGING_ROOM);
	stagingRoom.SelectedButton:SetText(LOC_STAGING_ROOM);
	stagingRoom.Button:SetDisabled(not Network.IsInSession());
	stagingRoom.Selected:SetHide(false);

	AutoSizeGridButton(stagingRoom.Button,250,32,20,"H");
	AutoSizeGridButton(stagingRoom.SelectedButton,250,32,20,"H");
	stagingRoom.TopControl:SetSizeX(stagingRoom.Button:GetSizeX());
	
	Controls.ShellTabs:CalculateSize();
end

-- ===========================================================================
function OnGameSummaryTabClicked()
	-- TODO
end

function OnFriendsTabClicked()
	-- TODO
end

-- ===========================================================================
function BuildGameSetupParameter(o, parameter)

	local parent = GetControlStack(parameter.GroupId);
	local control;
	
	-- If there is no parent, don't visualize the control.  This is most likely a player parameter.
	if(parent == nil or not parameter.Visible) then
		return;
	end;

	
	local c = m_gameSetupParameterIM:GetInstance();		
	c.Root:ChangeParent(parent);

	-- Store the root control, NOT the instance table.
	g_SortingMap[tostring(c.Root)] = parameter;		
			
	c.Label:SetText(parameter.Name);
	c.Value:SetText(parameter.DefaultValue);
	c.Root:SetToolTipString(parameter.Description);

	control = {
		Control = c,
		UpdateValue = function(value, p)
			local t:string = type(value);
			if(p.Array) then
				local valueText;

				if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
					valueText = Locale.Lookup("LOC_SELECTION_EVERYTHING");
				else
					valueText = Locale.Lookup("LOC_SELECTION_NOTHING");
				end

				-- Remove random leaders from the Values table that is used to determine number of leaders selected
				for i = #p.Values, 1, -1 do
					local kItem:table = p.Values[i];
					if kItem.Value == "RANDOM" or kItem.Value == "RANDOM_POOL1" or kItem.Value == "RANDOM_POOL2" then
						table.remove(p.Values, i);
					end
				end

				if(t == "table") then
					local count = #value;
					if (parameter.UxHint ~= nil and parameter.UxHint == "InvertSelection") then
						if(count == 0) then
							valueText = Locale.Lookup("LOC_SELECTION_EVERYTHING");
						elseif(count == #p.Values) then
							valueText = Locale.Lookup("LOC_SELECTION_NOTHING");
						else
							valueText = Locale.Lookup("LOC_SELECTION_CUSTOM", #p.Values-count);
						end
					else
						if(count == 0) then
							valueText = Locale.Lookup("LOC_SELECTION_NOTHING");
						elseif(count == #p.Values) then
							valueText = Locale.Lookup("LOC_SELECTION_EVERYTHING");
						else
							valueText = Locale.Lookup("LOC_SELECTION_CUSTOM", count);
						end
					end
				end
				c.Value:SetText(valueText);
				c.Value:SetToolTipString(parameter.Description);
			else
				if t == "table" then
					c.Value:SetText(value.Name);
				elseif t == "boolean" then
					c.Value:SetText(Locale.Lookup(value and "LOC_MULTIPLAYER_TRUE" or "LOC_MULTIPLAYER_FALSE"));
				else
					c.Value:SetText(tostring(value));
				end
			end			
		end,
		SetVisible = function(visible)
			c.Root:SetHide(not visible);
		end,
		Destroy = function()
			g_StringParameterManager:ReleaseInstance(c);
		end,
	};

	o.Controls[parameter.ParameterId] = control;
end

function RealizeGameSetup()
	BuildGameState();

	m_gameSetupParameterIM:ResetInstances();
	BuildGameSetup(BuildGameSetupParameter);

	BuildAdditionalContent();
end


-- ===========================================================================
--	Can join codes be used in the current lobby system?
-- ===========================================================================
function ShowJoinCode()
	local pbcMode			:boolean = GameConfiguration.IsPlayByCloud() and (GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_LOAD_PREGAME or GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_PREGAME);
	local crossPlayMode		:boolean = (Network.GetTransportType() == TransportType.TRANSPORT_EOS);
	local eosAllowed		:boolean = (Network.GetNetworkPlatform() == NetworkPlatform.NETWORK_PLATFORM_EOS) and GameConfiguration.IsInternetMultiplayer();
	return pbcMode or crossPlayMode or eosAllowed;
end

-- ===========================================================================
function BuildGameState()
	-- Indicate that this game is for loading a save or already in progress.
	local gameState = GameConfiguration.GetGameState();
	if(gameState ~= GameStateTypes.GAMESTATE_PREGAME) then
		local gameModeStr : string;

		if(gameState == GameStateTypes.GAMESTATE_LOAD_PREGAME) then
			-- in the pregame for loading a save
			gameModeStr = loadingSaveGameStr;
		else
			-- standard game in progress
			gameModeStr = gameInProgressGameStr;
		end
		Controls.GameStateText:SetHide(false);
		Controls.GameStateText:SetText(gameModeStr);
	else
		Controls.GameStateText:SetHide(true);
	end

	-- A 'join code' is a short string that can be sent through the MP system
	-- to allow other players to connect to the same session of the game.
	-- Originally only for PBC but added to support other MP game types.
	local joinCode :string = Network.GetJoinCode();
	Controls.JoinCodeRoot:SetHide( ShowJoinCode()==false );
	if joinCode ~= nil and joinCode ~= "" then
		Controls.JoinCodeText:SetText(joinCode);
	else
		Controls.JoinCodeText:SetText("---");			-- Better than showing nothing?
	end

	Controls.AdditionalContentStack:CalculateSize();
	Controls.ParametersScrollPanel:CalculateSize();
end

-- ===========================================================================
function BuildAdditionalContent()
	m_modsIM:ResetInstances();

	local enabledMods = GameConfiguration.GetEnabledMods();
	for _, curMod in ipairs(enabledMods) do
		local modControl = m_modsIM:GetInstance();
		local modTitleStr : string = curMod.Title;
		-- ============================================================================
		-- 联机工具箱2.0：去除内联字号标签 [size_N]（大小写不敏感），与模组清单面板一致
		-- 原代码直接使用 curMod.Title，此处增加剥离
		modTitleStr = string.gsub(modTitleStr, "%[[sS][iI][zZ][eE]_%d+%]", "");
		-- ----------------------------------------------------------------------------

		-- Color unofficial mods to call them out.
		if(not curMod.Official) then
			modTitleStr = ColorString_ModGreen .. modTitleStr .. "[ENDCOLOR]";
		end
		modControl.ModTitle:SetText(modTitleStr);
	end

	Controls.AdditionalContentStack:CalculateSize();
	Controls.ParametersScrollPanel:CalculateSize();
end

-- ===========================================================================
function RealizeInfoTabs()
	m_infoTabsIM:ResetInstances();
	local friends:table;
	local gameSummary:table

	gameSummary = m_infoTabsIM:GetInstance();
	gameSummary.Button:SetText(LOC_GAME_SUMMARY);
	gameSummary.SelectedButton:SetText(LOC_GAME_SUMMARY);
	gameSummary.Selected:SetHide(not g_viewingGameSummary);

	gameSummary.Button:RegisterCallback(Mouse.eLClick, function()
		g_viewingGameSummary = true;
		Controls.Friends:SetHide(true);
		friends.Selected:SetHide(true);
		gameSummary.Selected:SetHide(false);
		Controls.ParametersScrollPanel:SetHide(false);
	end);

	AutoSizeGridButton(gameSummary.Button,200,32,10,"H");
	AutoSizeGridButton(gameSummary.SelectedButton,200,32,20,"H");
	gameSummary.TopControl:SetSizeX(gameSummary.Button:GetSizeX());

	if not GameConfiguration.IsHotseat() then
		friends = m_infoTabsIM:GetInstance();
		friends.Button:SetText(LOC_FRIENDS);
		friends.SelectedButton:SetText(LOC_FRIENDS);
		friends.Selected:SetHide(g_viewingGameSummary);
		friends.Button:SetDisabled(not Network.IsInSession());
		friends.Button:RegisterCallback( Mouse.eLClick, function()
			g_viewingGameSummary = false;
			Controls.Friends:SetHide(false);
			friends.Selected:SetHide(false);
			gameSummary.Selected:SetHide(true);
			Controls.ParametersScrollPanel:SetHide(true);
			UpdateFriendsList();
		end );

		AutoSizeGridButton(friends.Button,200,32,20,"H");
		AutoSizeGridButton(friends.SelectedButton,200,32,20,"H");
		friends.TopControl:SetSizeX(friends.Button:GetSizeX());
	end

	Controls.InfoTabs:CalculateSize();
end

-------------------------------------------------
function UpdateFriendsList()

	if ContextPtr:IsHidden() or GameConfiguration.IsHotseat() then
		Controls.InfoContainer:SetHide(true);
		return;
	end

	m_friendsIM:ResetInstances();
	Controls.InfoContainer:SetHide(false);
	local friends:table = GetFriendsList();
	local bCanInvite:boolean = CanInviteFriends(false) and Network.HasSingleFriendInvite();

	-- DEBUG
	--for i = 1, 19 do
	-- /DEBUG
	for _, friend in pairs(friends) do
		local instance:table = m_friendsIM:GetInstance();

		-- Build the dropdown for the friend list
		local friendActions:table = {};
		BuildFriendActionList(friendActions, bCanInvite and not IsFriendInGame(friend));

		-- end build
		local friendPlayingCiv:boolean = friend.PlayingCiv; -- cache value to ensure it's available in callback function

		PopulateFriendsInstance(instance, friend, friendActions, 
			function(friendID, actionType) 
				if actionType == "invite" then
					local statusText:string = friendPlayingCiv and "LOC_PRESENCE_INVITED_ONLINE" or "LOC_PRESENCE_INVITED_OFFLINE";
					instance.PlayerStatus:LocalizeAndSetText(statusText);
				end
			end
		);

	end
	-- DEBUG
	--end
	-- /DEBUG

	Controls.FriendsStack:CalculateSize();
	Controls.FriendsScrollPanel:CalculateSize();
	Controls.FriendsScrollPanel:GetScrollBar():SetAndCall(0);

	if Controls.FriendsScrollPanel:GetScrollBar():IsHidden() then
		Controls.FriendsScrollPanel:SetOffsetX(8);
	else
		Controls.FriendsScrollPanel:SetOffsetX(3);
	end

	if table.count(friends) == 0 then
		Controls.InviteButton:SetAnchor("C,C");
		Controls.InviteButton:SetOffsetY(0);
	else
		Controls.InviteButton:SetAnchor("C,B");
		Controls.InviteButton:SetOffsetY(27);
	end
end

function IsFriendInGame(friend:table)
	local player_ids = GameConfiguration.GetParticipatingPlayerIDs();
	for i, iPlayer in ipairs(player_ids) do	
		local curPlayerConfig = PlayerConfigurations[iPlayer];
		local steamID = curPlayerConfig:GetNetworkIdentifer();
		if( steamID ~= nil and steamID == friend.ID and Network.IsPlayerConnected(iPlayer) ) then
			return true;
		end
	end
	return fasle;
end

-------------------------------------------------
function SetupGridLines(numPlayers:number)
	g_GridLinesIM:ResetInstances();
	RealizeGridSize();
	local nextY:number = GRID_LINE_HEIGHT;
	local gridSize:number = Controls.GridContainer:GetSizeY();
	local numLines:number = math.max(numPlayers, gridSize / GRID_LINE_HEIGHT);
	for i:number = 1, numLines do
		g_GridLinesIM:GetInstance().Control:SetOffsetY(nextY);
		nextY = nextY + GRID_LINE_HEIGHT;
	end
end

-------------------------------------------------
-------------------------------------------------
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues( "StagingRoom" );
	end
end

function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue("StagingRoom", "isHidden", ContextPtr:IsHidden());
end

function OnGameDebugReturn( context:string, contextTable:table )
	if context == "StagingRoom" and contextTable["isHidden"] == false then
		if ContextPtr:IsHidden() then
			ContextPtr:SetHide(false);
		else
			OnShow();
		end
	end	
end

-- ===========================================================================
--	LUA Event
--	Show the screen
-- ===========================================================================
function OnRaise(resetChat:boolean)
	-- Make sure HostGame screen is on the stack
	LuaEvents.StagingRoom_EnsureHostGame();

	UIManager:QueuePopup( ContextPtr, PopupPriority.Current );
end

-- ===========================================================================
function Resize()
	local screenX, screenY:number = UIManager:GetScreenSizeVal();
	Controls.MainWindow:SetSizeY(screenY-( Controls.LogoContainer:GetSizeY()-Controls.LogoContainer:GetOffsetY() ));
	local window = Controls.MainWindow:GetSizeY() - Controls.TopPanel:GetSizeY();
	Controls.ChatContainer:SetSizeY(window/2 -80)
	Controls.PrimaryStackGrid:SetSizeY(window-Controls.ChatContainer:GetSizeY() -75 )
	Controls.InfoContainer:SetSizeY(window/2 -80)
	Controls.PrimaryPanelStack:CalculateSize()
	RealizeGridSize();
end

-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string )   
  if type == SystemUpdateUI.ScreenResize then
	Resize();
  end
end

-- ===========================================================================
function StartExitGame()
	if(GetReadyCountdownType() == CountdownTypes.Ready_PlayByCloud) then
		-- If we are using the PlayByCloud ready countdown, the local player needs to be set to ready before they can leave.
		-- If we are not ready, we set ready and wait for that change to propagate to the backend.
		local localPlayerID :number = Network.GetLocalPlayerID();
		local localPlayerConfig :table = PlayerConfigurations[localPlayerID];
		if(localPlayerConfig:GetReady() == false) then
			m_exitReadyWait = true;
			SetLocalReady(true);

			-- Next step will be in OnUploadCloudPlayerConfigComplete.
			return;
		end
	end

	Close();
end

-- ===========================================================================
function OnEndGame_Start()
	Network.CloudKillGame();

	-- Show killing game popup
	m_kPopupDialog:Close(); -- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_ENDING_GAME_PROMPT"));
	m_kPopupDialog:Open();

	-- Next step is in OnCloudGameKilled.
end

function OnQuitGame_Start()
	Network.CloudQuitGame();

	-- Show killing game popup
	m_kPopupDialog:Close(); -- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_QUITING_GAME_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_MULTIPLAYER_QUITING_GAME_PROMPT"));
	m_kPopupDialog:Open();

	-- Next step is in OnCloudGameQuit.
end

function OnExitGameAskAreYouSure()
	if(GameConfiguration.IsPlayByCloud()) then
		-- PlayByCloud immediately exits to streamline the process and avoid confusion with the popup text.
		StartExitGame();
		return;
	end

	m_kPopupDialog:Close();	-- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_GAME_MENU_QUIT_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_QUIT_WARNING"));
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), StartExitGame, nil, nil, "PopupButtonInstanceRed" );
	m_kPopupDialog:Open();
end

function OnEndGameAskAreYouSure()
	m_kPopupDialog:Close(); -- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_GAME_MENU_END_GAME_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_END_GAME_WARNING"));
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnEndGame_Start, nil, nil, "PopupButtonInstanceRed" );
	m_kPopupDialog:Open();
end

function OnQuitGameAskAreYouSure()
	m_kPopupDialog:Close(); -- clear out the popup incase it is already open.
	m_kPopupDialog:AddTitle(  Locale.ToUpper(Locale.Lookup("LOC_GAME_MENU_QUIT_GAME_TITLE")));
	m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_QUIT_GAME_WARNING"));
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), nil );
	m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnQuitGame_Start, nil, nil, "PopupButtonInstanceRed" );
	m_kPopupDialog:Open();
end


-- ===========================================================================
function GetInviteTT()
	if( Network.GetNetworkPlatform() == NetworkPlatform.NETWORK_PLATFORM_EOS ) then
		return Locale.Lookup("LOC_EPIC_INVITE_BUTTON_TT");
	end

	return Locale.Lookup("LOC_INVITE_BUTTON_TT");
end

-- ###########################################################################
-- 联机工具箱2.0 自定义函数区
-- 本区域集中存放本 mod 新增的功能函数，每个函数均带注释与用法说明。
-- ###########################################################################

-- ============================================================================
-- 快捷打开/关闭AI（条目3.2，参考联机工具箱1.67 OnCloseAIButtonL/R 并重写）
-- 用法：房主点击顶部「AI槽位」按钮 —— 左键关闭全部非真人槽位，右键全部打开为 OPEN。
-- 效率说明：仅状态发生变化的槽位才执行 SetSlotStatus + 广播；
--          UI 刷新链（排序/重绘/校验/尺寸重算）在循环结束后统一执行一次。
-- ============================================================================

-------------------------------------------------
-- SetAllNonHumanSlots
-- 将全部非真人槽位设置为目标状态（仅房主可执行）。
-- newSlotStatus : SlotStatus.SS_CLOSED（左键关闭）或 SlotStatus.SS_OPEN（右键打开）
-- 遍历说明：遍历全部槽位 0..g_currentMaxPlayers-1（不用 GetMultiplayerPlayerIDs，
--          该列表不含已关闭槽位，会导致关闭过的槽位右键开不回来）；
--          槽位总数由地图尺寸上限决定，本函数不做扩容。
-------------------------------------------------
function SetAllNonHumanSlots( newSlotStatus )
	if not Network.IsGameHost() then
		return;
	end
	for playerID = 0, g_currentMaxPlayers - 1 do
		local pPlayerConfig = PlayerConfigurations[playerID];
		if pPlayerConfig ~= nil and not pPlayerConfig:IsHuman() and pPlayerConfig:GetSlotStatus() ~= newSlotStatus then
			pPlayerConfig:SetSlotStatus(newSlotStatus);
			Network.BroadcastPlayerInfo(playerID);
		end
	end
	-- 刷新链只执行一次（参照原版 OnSlotType 的单槽刷新顺序）
	Controls.PlayerListStack:SortChildren(SortPlayerListStack);
	m_iFirstClosedSlot = -1;
	UpdateAllPlayerEntries();
	CheckTeamsValid();
	CheckGameAutoStart();
	Controls.PlayerListStack:CalculateSize();
	Controls.PlayersScrollPanel:CalculateSize();
	Resize();
end

-------------------------------------------------
-- OnAISlotsButtonL / OnAISlotsButtonR
-- 「AI槽位」按钮左键（全关）/ 右键（全开）回调。
-------------------------------------------------
function OnAISlotsButtonL()
	SetAllNonHumanSlots(SlotStatus.SS_CLOSED);
end

function OnAISlotsButtonR()
	UI.PlaySound("Play_UI_Click");	-- GridButton 右键不自动播放点击音
	SetAllNonHumanSlots(SlotStatus.SS_OPEN);
end

-- ============================================================================
-- 快捷分队（条目3.3，移植联机工具箱1.67 并重写；评分机制已重设计为纯谐波位次分 + 相邻结对随机）
-- 用法：房主左键点击玩家列表「队伍」列表头 —— 随机平衡分队；右键 —— 按槽位顺序1212分队。
-- 机制：SetTeam + BroadcastPlayerInfo 后由原版 PlayerInfoChanged 事件链自动刷新条目与队伍下拉。
-- ============================================================================

-------------------------------------------------
-- GetSlotOrderScore
-- 楼层位次分（纯函数）：score(i) = 1 / (i + SCORE_SMOOTHING)
-- 位置 i 按玩家 ID 升序（1 起），分数严格单调递减（ID 顺序越低评分越高）；
-- 首尾比 (N+1)/2 随人数线性增长，相邻位区分度不随人数稀释。
-- 分数语义 = 楼层优势（伟人招募/奇观建造的结算优先权），分队目标为两队总分差最小。
-------------------------------------------------
local SCORE_SMOOTHING : number = 1;	-- 谐波平滑常数（越大曲线越平；1.67 原式为 N/2，大房间会抹平相邻位区分度）
local MAX_BALANCE_ATTEMPTS : number = 10;	-- 最优保留的最大尝试次数
function GetSlotOrderScore( position )
	return 1 / (position + SCORE_SMOOTHING);
end

-------------------------------------------------
-- GetBalancedRandomTeams
-- 随机平衡分队（相邻结对随机 + 最优保留）：
-- 1. 相邻位置结对 (1,2)(3,4)…，每对内抛硬币随机一人进 A 队，奇数人时最后一人随机进队；
-- 2. 最多 MAX_BALANCE_ATTEMPTS 次尝试，保留两队楼层总分差最小的一份，
--    分差 <= 最小结对分差（精度极限）时提前结束；
-- 3. 返回 playerID -> boolean（true = A 队）。
-------------------------------------------------
function GetBalancedRandomTeams( playerIDs, maxAttempts )
	local playerCount : number = #playerIDs;
	local bestAssignment : table = {};
	for _, playerID in ipairs(playerIDs) do
		bestAssignment[playerID] = false;
	end
	if playerCount <= 1 then
		return bestAssignment;
	end

	-- 预算位次分与最小结对分差（精度极限）
	local scores : table = {};
	local minPairGap : number = 1;
	for position = 2, playerCount do
		scores[position - 1] = GetSlotOrderScore(position - 1);
		minPairGap = math.min(minPairGap, GetSlotOrderScore(position - 1) - GetSlotOrderScore(position));
	end
	scores[playerCount] = GetSlotOrderScore(playerCount);

	local bestScoreDiff : number = math.huge;
	for attempt = 1, (maxAttempts or MAX_BALANCE_ATTEMPTS) do
		local teamAssignment : table = {};
		local signedScoreDiff : number = 0;	-- A 队总分 - B 队总分
		local position : number = 1;
		while position <= playerCount do
			local assignFirstToA : boolean = math.random() < 0.5;
			if position + 1 <= playerCount then
				-- 结对内随机一人进 A 队，分差伸缩相消
				teamAssignment[playerIDs[position]] = assignFirstToA;
				teamAssignment[playerIDs[position + 1]] = not assignFirstToA;
				local pairGap : number = scores[position] - scores[position + 1];
				signedScoreDiff = signedScoreDiff + (assignFirstToA and pairGap or -pairGap);
				position = position + 2;
			else
				-- 奇数人最后一人随机进队
				teamAssignment[playerIDs[position]] = assignFirstToA;
				signedScoreDiff = signedScoreDiff + (assignFirstToA and scores[position] or -scores[position]);
				position = position + 1;
			end
		end
		if math.abs(signedScoreDiff) < bestScoreDiff then
			bestScoreDiff = math.abs(signedScoreDiff);
			bestAssignment = teamAssignment;
			if bestScoreDiff <= minPairGap then
				break;	-- 已达精度极限，提前结束
			end
		end
	end
	return bestAssignment;
end

-------------------------------------------------
-- GetRandomTeamIDs
-- 返回一奇一偶两个队伍 ID（错开队伍配色，避免固定颜色）。
-------------------------------------------------
function GetRandomTeamIDs()
	return 2 * math.random(1, 6) - 1, 2 * math.random(1, 5);
end

-------------------------------------------------
-- AssignTeams
-- 快捷分队核心（仅房主可执行）：
-- 收集全部参与者（排除观察者），按 teamAssignment 表分配队伍，
-- 观察者/空位置为无队伍；每名玩家只 SetTeam + 广播一次。
-- playerIDs      : GameConfiguration.GetMultiplayerPlayerIDs()
-- teamAssignment : playerID -> boolean（true = A 队），nil 表示按顺序交错
-------------------------------------------------
function AssignTeams( playerIDs, teamAssignment )
	if not Network.IsGameHost() then
		return;
	end
	local teamID_A : number, teamID_B : number = GetRandomTeamIDs();
	local useTeamA : boolean = true;
	for _, playerID in ipairs(playerIDs) do
		local pPlayerConfig = PlayerConfigurations[playerID];
		local isParticipant : boolean = pPlayerConfig:IsParticipant() and pPlayerConfig:GetLeaderTypeName() ~= "LEADER_SPECTATOR";
		local newTeam : number = -1;
		if isParticipant then
			-- 注意不能用 a and b or c 写法：teamAssignment[playerID] 为 false 时会错误落到 useTeamA
			local assignA : boolean;
			if teamAssignment ~= nil then
				assignA = teamAssignment[playerID] == true;
			else
				assignA = useTeamA;
				useTeamA = not useTeamA;
			end
			newTeam = assignA and teamID_A or teamID_B;
		end
		pPlayerConfig:SetTeam(newTeam);
		Network.BroadcastPlayerInfo(playerID);
	end
end

-------------------------------------------------
-- OnRandomTeamButtonL / OnRandomTeamButtonR
-- 「队伍」列表头左键（随机平衡分队）/ 右键（顺序1212分队）回调。
-------------------------------------------------
function OnRandomTeamButtonL()
	if not Network.IsGameHost() then
		return;
	end
	local playerIDs = GameConfiguration.GetMultiplayerPlayerIDs();
	local participantIDs : table = {};
	for _, playerID in ipairs(playerIDs) do
		local pPlayerConfig = PlayerConfigurations[playerID];
		if pPlayerConfig:IsParticipant() and pPlayerConfig:GetLeaderTypeName() ~= "LEADER_SPECTATOR" then
			table.insert(participantIDs, playerID);
		end
	end
	AssignTeams(playerIDs, GetBalancedRandomTeams(participantIDs));
end

function OnRandomTeamButtonR()
	UI.PlaySound("Play_UI_Click");	-- GridButton 右键不自动播放点击音
	if not Network.IsGameHost() then
		return;
	end
	AssignTeams(GameConfiguration.GetMultiplayerPlayerIDs(), nil);
end

-- ============================================================================
-- 房主权限提升（条目3.4，参考乔尔定制mod：直接写 PlayerConfigurations 绕过参数系统权限门）
-- 机制：原版的队伍/领袖修改限制只是 UI 禁用与参数系统的 Config_CanWriteParameter 权限门，
--      本区域函数在房主操作其他真人玩家时放开 UI、并直接写 PlayerConfigurations + 广播。
-- ============================================================================

-------------------------------------------------
-- CanHostEditOtherPlayer
-- 统一判定「房主可编辑该真人玩家」：本机是房主、非热座、目标非本机、
-- SS_TAKEN、目标未 ready、未锁定、游戏未开始（PREGAME）、房主自己未 ready。
-- 调用点：队伍下拉禁用、领袖下拉启用、领袖下拉点击拦截。
-------------------------------------------------
function CanHostEditOtherPlayer( playerId )
	if not Network.IsGameHost() or GameConfiguration.IsHotseat() then
		return false;
	end
	if playerId == Network.GetLocalPlayerID() then
		return false;
	end
	local pPlayerConfig = PlayerConfigurations[playerId];
	local localPlayerConfig = PlayerConfigurations[Network.GetLocalPlayerID()];
	return pPlayerConfig ~= nil
		and pPlayerConfig:GetSlotStatus() == SlotStatus.SS_TAKEN
		and not pPlayerConfig:GetReady()
		and not pPlayerConfig:IsLocked()
		and GameConfiguration.GetGameState() == GameStateTypes.GAMESTATE_PREGAME
		and localPlayerConfig ~= nil and not localPlayerConfig:GetReady();
end

-------------------------------------------------
-- HostSetPlayerLeader
-- 房主修改其他玩家的所选领袖（仅房主可执行）：
-- 直接写 PlayerConfigurations 绕过参数系统权限门，
-- 逐条复刻 Player_WriteParameterValues 的 PlayerLeader 分支（PlayerSetupLogic.lua:57-90）。
-- playerId : 目标玩家 ID；valueRow : 领袖下拉的 DomainValues 行（.Value 为领袖类型名）
-- 末尾广播 + 本地即时刷新，其他玩家客户端实时看到变化。
-------------------------------------------------
function HostSetPlayerLeader( playerId, valueRow )
	if not CanHostEditOtherPlayer(playerId) then
		return;
	end
	local pPlayerConfig = PlayerConfigurations[playerId];
	local leaderType = valueRow.Value;
	if leaderType == -1 or leaderType == "RANDOM" then
		pPlayerConfig:SetLeaderName(nil);
		pPlayerConfig:SetLeaderTypeName(nil);
		pPlayerConfig:SetLeaderRandomPoolID(LeaderRandomPoolTypes.LEADER_RANDOM_POOL_DEFAULT);
	elseif leaderType == "RANDOM_POOL1" then
		pPlayerConfig:SetLeaderName(nil);
		pPlayerConfig:SetLeaderTypeName(nil);
		pPlayerConfig:SetLeaderRandomPoolID(LeaderRandomPoolTypes.LEADER_RANDOM_POOL_1);
	elseif leaderType == "RANDOM_POOL2" then
		pPlayerConfig:SetLeaderName(nil);
		pPlayerConfig:SetLeaderTypeName(nil);
		pPlayerConfig:SetLeaderRandomPoolID(LeaderRandomPoolTypes.LEADER_RANDOM_POOL_2);
	else
		pPlayerConfig:SetLeaderName(valueRow.RawName or valueRow.Name);
		pPlayerConfig:SetLeaderTypeName(leaderType);
	end
	Network.BroadcastPlayerInfo(playerId);	-- 广播：其他玩家实时看到变化
	UpdatePlayerEntry(playerId);			-- 本地即时刷新
end

-------------------------------------------------
-- RefreshHostPermissions
-- 统一房主刷新判定：每次进入房间或房主变化时调用，统一进行权限判定。
-- 1. 刷新本 mod 自定义按钮（AI槽位 / 快捷分队）可见性；
-- 2. 重评估所有玩家条目的下拉可编辑状态（队伍/领袖放开随房主身份即时生效/失效）。
-- 调用点：OnShow / OnGameConfigChanged / OnMultiplayerHostMigrated。
-------------------------------------------------
function RefreshHostPermissions()
	UpdateCustomButtonsState();
	UpdateAllPlayerEntries();
end

-------------------------------------------------
-- UpdateCustomButtonsState
-- 刷新本 mod 自定义按钮（AI槽位 / 快捷分队 / 重新校验）可见性：仅房主、非热座、非云端时显示。
-------------------------------------------------
function UpdateCustomButtonsState()
	local hideButtons : boolean = not Network.IsGameHost() or GameConfiguration.IsHotseat() or GameConfiguration.IsPlayByCloud();
	Controls.AISlotsButton:SetHide(hideButtons);
	Controls.RandomTeamButton:SetHide(hideButtons);
	Controls.ModRecheckButton:SetHide(hideButtons);
end

-- ============================================================================
-- 更新公告（条目3.5，参考 GME GreatMultiplayerExpand_Panel 更新日志部分并重写为 SQL 数据驱动）
-- 用法：左下角「更新日志」按钮打开公告面板；仅 X 按钮 / 点击面板外 / ESC 关闭。
-- 数据源：前端配置库 MPT_Changelog 表（Version / LogDate / TextTag，见 FrontEnd/Changelog/Changelog_Data.sql），
--        读取用 DB.ConfigurationQuery（前端配置库句柄，参照 1.67 TPT_PlayerData 用法；
--        DB.Query 是游戏内数据库句柄，前端上下文不适用）。
-- 读取规则：按 LogDate DESC, Version DESC, rowid ASC 排序（最新公告排最上，最老排最下）；
--          相同 Version+LogDate 归为一组 —— 同版本一个实例：版本号左上、日期右上、
--          下方为组内条目文本（行首统一 [icon_You] 图标，不编号）；
--          首组（最新）版本号后追加「（当前版本）」；
--          TextTag 经 LocalizedText 按当前游戏语言解析（多语言预留，数据表零改动）。
-- ============================================================================

-- 更新公告本地化文本缓存（条目3.5，预加载避免每次构建公告时重复 Lookup）
local ChangelogCurrentVersionStr = Locale.Lookup("LOC_MPT_FE_CHANGELOG_CURRENT");

-------------------------------------------------
-- BuildChangelog
-- 从 MPT_Changelog 表构建公告列表；数据静态，每次加载只在首次打开面板时构建一次。
-- 行高自适应（GME 式）：行高 = 头部区56 + 文本实际高（实例默认高 60）。
-------------------------------------------------
local m_changelogEntryIM = InstanceManager:new("ChangelogEntryInstance", "EntryRoot", Controls.ChangelogStack);
local g_changelogBuilt : boolean = false;

function BuildChangelog()
	if g_changelogBuilt then
		return;
	end
	g_changelogBuilt = true;

	m_changelogEntryIM:ResetInstances();

	local changelogRows = DB.ConfigurationQuery("SELECT Version, LogDate, TextTag FROM MPT_Changelog ORDER BY LogDate DESC, Version DESC, rowid ASC");
	if changelogRows == nil then
		return;
	end

	-- 按 Version+LogDate 归组（查询已按组连续排序，组序即展示序）
	local versionGroups : table = {};	-- { { Version=..., LogDate=..., Texts={...} }, ... }
	local groupIndex : table = {};		-- groupKey -> versionGroups 下标
	for i, row in ipairs(changelogRows) do
		local groupKey : string = row.LogDate .. "|" .. row.Version;
		if groupIndex[groupKey] == nil then
			table.insert(versionGroups, { Version = row.Version, LogDate = row.LogDate, Texts = {} });
			groupIndex[groupKey] = #versionGroups;
		end
		table.insert(versionGroups[groupIndex[groupKey]].Texts, Locale.Lookup(row.TextTag));
	end

	for groupNumber, versionGroup in ipairs(versionGroups) do
		local entryInstance = m_changelogEntryIM:GetInstance();
		-- 版本号（左上），首组为最新版本追加「（当前版本）」
		local versionText : string = versionGroup.Version;
		if groupNumber == 1 then
			versionText = versionText .. " " .. ChangelogCurrentVersionStr;
		end
		entryInstance.VersionLabel:SetText(versionText);
		-- 日期（右上）
		entryInstance.DateLabel:SetText(versionGroup.LogDate);
		-- 版本号/日期行下方：组内条目逐行拼接，行首统一 [icon_You] 图标（不编号）
		local entryText : string = "";
		for rowNumber, text in ipairs(versionGroup.Texts) do
			if rowNumber > 1 then
				entryText = entryText .. "[NEWLINE]";
			end
			entryText = entryText .. "[icon_You] " .. text;
		end
		entryInstance.EntryText:SetText(entryText);
		-- 行高 = 文本上偏移38 + 文本高 + 底边距32（实例内部文本下方留白一行）
		entryInstance.EntryRoot:SetSizeY(entryInstance.EntryText:GetSizeY() + 70);
	end

	Controls.ChangelogStack:CalculateSize();
	Controls.ChangelogScrollPanel:CalculateSize();
end

-------------------------------------------------
-- OpenChangelogPanel / CloseChangelogPanel
-- 打开 / 关闭更新公告面板（含全屏点击拦截层）；ESC 拦截见 KeyUpHandler。
-------------------------------------------------
function OpenChangelogPanel()
	BuildChangelog();
	Controls.ChangelogModalBlocker:SetHide(false);
	Controls.ChangelogPanel:SetHide(false);
	UI.PlaySound("UI_Screen_Open");
end

function CloseChangelogPanel()
	if Controls.ChangelogPanel:IsHidden() then
		return;
	end
	Controls.ChangelogPanel:SetHide(true);
	Controls.ChangelogModalBlocker:SetHide(true);
	UI.PlaySound("UI_Screen_Close");
end

-- ============================================================================
-- 广告轮播（条目3.6，移植原版主菜单 ChallengeCarousel 并重命名/裁剪）
-- 用法：广告条目由 MPT_Ads 表驱动（FrontEnd/Ads/Ads_Data.sql），按 rowid 顺序展示、
--       按本机日期过滤 StartDate/EndDate；自动轮播 + 左右箭头手动翻页 + 底部指示点。
-- 移植说明：首尾各复制一条实例实现无缝循环滚动（原版 CarouselEntry 机制）；
--          点击条目在 Url 非空时经 Steam.ActivateGameOverlayToUrl 打开网页
--          （BSR / 原版 Mods.lua 同款用法），Url 为空则点击无动作。
-- ============================================================================

-- 单条广告展示时长（毫秒）与翻页补间时长（毫秒）
local AD_DISPLAY_DURATION_MS : number = 5000;
local AD_ANIM_DURATION_MS : number = 400;

local m_adEntryIM = InstanceManager:new("AdEntryInstance", "AdEntryRoot", Controls.AdStack);
local m_adIndicatorIM = InstanceManager:new("AdIndicatorInstance", "AdIndicatorRoot", Controls.AdIndicatorStack);
local g_adEntries : table = {};			-- 过滤后的广告行 { {TextureName=..., ToolTipTag=..., Url=...}, ... }
local m_adCurrentEntry : number = 1;	-- 当前条目下标（1..#g_adEntries；首尾复制实例不计入）
local m_adSlideTimerMS : number = 0;	-- 当前条目已展示时长
local m_adAnim : table = { active = false, time = 0, startValue = 0, destinationValue = 0, destinationIndex = 0 };	-- 翻页补间状态

-------------------------------------------------
-- AdGetOffsetValue
-- 计算第 index 个滚动实例（含首尾复制）对应的滚动值（原版 CarouselGetOffsetValue 移植）。
-------------------------------------------------
function AdGetOffsetValue( index )
	local entryWidth : number = Controls.AdStack:GetChildren()[1]:GetSizeX();
	return (entryWidth * index) / (Controls.AdStack:GetSizeX() - entryWidth);
end

-------------------------------------------------
-- AdSetSelectedEntry
-- 设置当前条目并刷新指示点高亮（原版 CarouselSetSelectedEntry 裁剪：去除 Challenges 上报）。
-------------------------------------------------
function AdSetSelectedEntry( index )
	m_adCurrentEntry = index;
	m_adIndicatorIM:ResetInstances();
	for i = 1, #g_adEntries do
		local indicatorInstance = m_adIndicatorIM:GetInstance();
		if i == m_adCurrentEntry then
			indicatorInstance.AdIndicatorImage:SetTextureOffsetVal(0, 14);
		else
			indicatorInstance.AdIndicatorImage:SetTextureOffsetVal(0, 0);
		end
	end
end

-------------------------------------------------
-- AdScrollToEntry
-- 启动到第 index 个滚动实例的补间滚动（滚动期间禁用箭头，原版 CarouselScrollToEntry 移植）。
-------------------------------------------------
function AdScrollToEntry( index )
	if index == m_adCurrentEntry then
		return;
	end
	m_adAnim.active = true;
	m_adAnim.time = 0;
	m_adAnim.startValue = Controls.AdScroll:GetScrollValue();
	m_adAnim.destinationValue = AdGetOffsetValue(index);
	m_adAnim.destinationIndex = index;
	Controls.AdLeftButton:SetEnabled(false);
	Controls.AdRightButton:SetEnabled(false);
end

-------------------------------------------------
-- AdFinishedScrolling
-- 补间结束收尾：滚到首尾复制实例时无感跳回对应真实条目（无缝循环），恢复箭头（原版移植）。
-------------------------------------------------
function AdFinishedScrolling( index )
	if index == (#g_adEntries + 1) then
		index = 1;
	elseif index == 0 then
		index = #g_adEntries;
	end
	Controls.AdScroll:SetScrollValue(AdGetOffsetValue(index));
	AdSetSelectedEntry(index);
	m_adSlideTimerMS = 0;
	m_adAnim.active = false;
	m_adAnim.time = 0;
	Controls.AdLeftButton:SetEnabled(true);
	Controls.AdRightButton:SetEnabled(true);
end

-------------------------------------------------
-- OnAdLeftClick / OnAdRightClick
-- 左右箭头回调：向相邻条目翻页（滚过边界时借首尾复制实例过渡，由 AdFinishedScrolling 跳回）。
-------------------------------------------------
function OnAdLeftClick()
	AdScrollToEntry(m_adCurrentEntry - 1);
end

function OnAdRightClick()
	AdScrollToEntry(m_adCurrentEntry + 1);
end

-------------------------------------------------
-- OnAdEntryClick
-- 广告条目点击回调（参数为 SetVoid1 写入的条目下标）：Url 非空时经 Steam Overlay 打开网页。
-------------------------------------------------
function OnAdEntryClick( entryIndex )
	local adEntry = g_adEntries[entryIndex + 1];
	if adEntry ~= nil and adEntry.Url ~= "" then
		UI.PlaySound("Play_UI_Click");
		Steam.ActivateGameOverlayToUrl(adEntry.Url);
	end
end

-------------------------------------------------
-- OnAdCloseClick
-- 关闭按钮回调：隐藏轮播容器并显示「最新动态」唤起按钮（仅本次进入有效，重进准备房间由 RestoreAdCarousel 恢复）。
-------------------------------------------------
function OnAdCloseClick()
	Controls.AdCarouselContainer:SetHide(true);
	Controls.AdShowButton:SetHide(false);
	UI.PlaySound("UI_Screen_Close");
end

-------------------------------------------------
-- OnAdShowButtonClick
-- 「最新动态」按钮回调：唤回广告轮播并隐藏自身（与 OnAdCloseClick 互斥显隐）。
-------------------------------------------------
function OnAdShowButtonClick()
	Controls.AdCarouselContainer:SetHide(false);
	Controls.AdShowButton:SetHide(true);
	UI.PlaySound("UI_Screen_Open");
end

-------------------------------------------------
-- RestoreAdCarousel
-- 重进准备房间时恢复广告面板（OnShow 调用；无可展示条目时保持隐藏）。
-------------------------------------------------
function RestoreAdCarousel()
	if #g_adEntries > 0 then
		Controls.AdCarouselContainer:SetHide(false);
		Controls.AdShowButton:SetHide(true);
	end
end

-------------------------------------------------
-- BuildAdCarousel
-- 从 MPT_Ads 表构建广告轮播；数据静态，加载时构建一次（原版 UpdateChallengeCarousel 移植）。
-- 日期过滤：本机当天与 StartDate/EndDate（YYYY-MM-DD）字符串比较，起止当日均展示；
--          无可展示条目时隐藏整个轮播容器。
-------------------------------------------------
function BuildAdCarousel()
	local adRows = DB.ConfigurationQuery("SELECT TextureName, StartDate, EndDate, ToolTipTag, Url FROM MPT_Ads ORDER BY rowid ASC");
	g_adEntries = {};
	if adRows ~= nil then
		local today : string = os.date("%Y-%m-%d");
		for i, row in ipairs(adRows) do
			if (row.StartDate == "" or today >= row.StartDate) and (row.EndDate == "" or today <= row.EndDate) then
				table.insert(g_adEntries, { TextureName = row.TextureName, ToolTipTag = row.ToolTipTag, Url = row.Url });
			end
		end
	end

	m_adEntryIM:ResetInstances();

	local entryCount : number = #g_adEntries;
	if entryCount == 0 then
		Controls.AdCarouselContainer:SetHide(true);
		return;
	end

	-- 首尾各复制一条实例，滚过边界时视觉连续（跳回逻辑见 AdFinishedScrolling）
	for i = 0, entryCount + 1 do
		local entryIndex : number = i - 1;
		if entryIndex == -1 then
			entryIndex = entryCount - 1;
		elseif entryIndex == entryCount then
			entryIndex = 0;
		end

		local adEntry = g_adEntries[entryIndex + 1];
		local entryInstance = m_adEntryIM:GetInstance();
		-- 贴图设在 Image 子控件上：Button 无基础 Texture 时不创建贴图槽，直接 SetTexture 静默无效
		entryInstance.AdEntryImage:SetTexture(adEntry.TextureName);
		if adEntry.ToolTipTag ~= "" then
			entryInstance.AdEntryButton:SetToolTipString(Locale.Lookup(adEntry.ToolTipTag));
		end
		entryInstance.AdEntryButton:SetVoid1(entryIndex);
		entryInstance.AdEntryButton:RegisterCallback( Mouse.eLClick, OnAdEntryClick );
		entryInstance.AdEntryButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	end

	-- 单条广告无需翻页：隐藏箭头与指示点
	local multiEntry : boolean = (entryCount > 1);
	Controls.AdLeftButton:SetHide(not multiEntry);
	Controls.AdRightButton:SetHide(not multiEntry);
	Controls.AdIndicatorStack:SetHide(not multiEntry);

	Controls.AdStack:CalculateSize();
	Controls.AdScroll:CalculateSize();

	AdSetSelectedEntry(1);
	Controls.AdCarouselContainer:SetHide(false);
	Controls.AdScroll:SetScrollValue(AdGetOffsetValue(1));
end

-------------------------------------------------
-- OnAdUpdate
-- 帧回调（ContextPtr:SetUpdate）：驱动翻页补间与自动轮播计时（原版 OnUpdate 轮播段移植）。
-------------------------------------------------
function OnAdUpdate( fDeltaTime )
	if m_adAnim.active then
		local newTime : number = m_adAnim.time + fDeltaTime * 1000;
		if newTime >= AD_ANIM_DURATION_MS then
			Controls.AdScroll:SetScrollValue(m_adAnim.destinationValue);
			AdFinishedScrolling(m_adAnim.destinationIndex);
		else
			Controls.AdScroll:SetScrollValue(m_adAnim.startValue + (m_adAnim.destinationValue - m_adAnim.startValue) * (newTime / AD_ANIM_DURATION_MS));
			m_adAnim.time = newTime;
		end
	elseif #g_adEntries > 1 then
		-- 手动翻页后计时同样清零（AdFinishedScrolling 重置），避免紧接着自动翻页
		m_adSlideTimerMS = m_adSlideTimerMS + fDeltaTime * 1000;
		if m_adSlideTimerMS >= AD_DISPLAY_DURATION_MS then
			AdScrollToEntry(m_adCurrentEntry + 1);
		end
	end
end

-- ============================================================================
-- 网络连接显示优化（条目3.7：常驻 ping 数值 + 吸收联机工具箱1.67 BNL 黑灯修复）
-- 简单覆盖：本分区重定义全局 UpdateNetConnectionIcon，覆盖第10行
--      include("NetConnectionIconLogic") 建立的原版同名函数（原同名覆盖文件
--      Scripts/NetConnectionIconLogic.lua 已移除，include 现解析回原版共享脚本；
--      本分区在 include 之后执行，运行时调用一律命中本版本）。
--      UpdateNetConnectionLabel 未修改，继续由 include 的原版文件提供。
--      下列字符串/档位常量为文件内 local 副本（原文件中为 file-local，跨文件不可共享）。
-- 修改内容（与已移除的覆盖文件一致）：
-- 1. UpdateNetConnectionIcon 增加可选第三参数 pingLabel，在房间槽位
--    就绪状态文本后常驻显示 ping 数值，颜色跟随绿黄红三档；
--    pingLabel 传 nil 时行为与原版完全一致（双参调用不受影响）
-- 2. 吸收联机工具箱1.67 BNL 黑灯修复：ping<=1 且非本机玩家时显示离线灯，
--    原版此时会错误显示绿灯
-- ============================================================================
-- Connection Icon Strings
local PlayerConnectedStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED" );
local PlayerConnectingStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTING" );
local PlayerNotConnectedStr = Locale.Lookup( "LOC_MP_PLAYER_NOTCONNECTED" );
local PlayerNotModReadyStr = Locale.Lookup( "LOC_MP_PLAYER_NOT_MOD_READY" );
local PlayerResyncingStr = Locale.Lookup( "LOC_MP_PLAYER_RESYNCING" );

-- Connection Label Strings.
local PlayerConnectedSummaryStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTED_SUMMARY" );
local PlayerConnectingSummaryStr = Locale.Lookup( "LOC_MP_PLAYER_CONNECTING_SUMMARY" );
local PlayerNotConnectedSummaryStr = Locale.Lookup( "LOC_MP_PLAYER_NOTCONNECTED_SUMMARY" );
local PlayerNotModReadySummaryStr = Locale.Lookup( "LOC_MP_PLAYER_NOT_MOD_READY_SUMMARY" );
local PlayerResyncingSummaryStr = Locale.Lookup( "LOC_MP_PLAYER_RESYNCING_SUMMARY" );

-- Ping Time Strings
local secondsStr = Locale.Lookup( "LOC_TIME_SECONDS" );
local millisecondsStr = Locale.Lookup( "LOC_TIME_MILLISECONDS" );

local PING_GREAT	= 100; -- [Milliseconds] Player's ping is considered to be great (green) if under this number.
local PING_OK		= 200; -- [Milliseconds] Player's ping is considered to be ok (yellow) if under this number.

-- 联机工具箱2.0 新增：常驻 ping 数值的档位颜色文本标签（与连接灯同色系）
-- 注意：SetColor 数值颜色对 Label 文本无效（实测显示黑色），改用引擎文本颜色标签
-- 格式参考联机工具箱1.67 Update/PlayerData.sql 的 [color:R,G,B] 内联颜色用法，此处用带 Alpha 的四分量形式
local PING_COLOR_GREAT	= "[color:80,200,80,255]"; -- 绿
local PING_COLOR_OK		= "[color:232,200,64,255]"; -- 黄
local PING_COLOR_BAD	= "[color:240,80,80,255]"; -- 红

----------------------------------------------------------------
-- UpdateNetConnectionIcon
-- Remember to call UpdateNetConnectionIcon when...
-- * Creating a new icon.
-- * For all icons on a MultiplayerPingTimesChanged event.
----------------------------------------------------------------
-- 联机工具箱2.0：新增可选第三参数 pingLabel（常驻 ping 数值标签）
function UpdateNetConnectionIcon(playerID :number, connectIcon, pingLabel)
	-- Update network connection status
	local pPlayerConfig = PlayerConfigurations[playerID];
	local slotStatus = pPlayerConfig:GetSlotStatus();
	if(slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_OBSERVER) then
		-- build ping string
		local iPingTime = Network.GetPingTime( playerID );
		local pingStr = "";
		if(playerID ~= Network.GetLocalPlayerID()) then
			if (iPingTime < 1000) then
				pingStr = " " .. tostring(iPingTime) .. millisecondsStr;
			else
				pingStr = " " .. tostring(iPingTime/1000) .. secondsStr;
			end
		end

		-- 联机工具箱2.0 新增：常驻 ping 数值标签
		-- 仅已连接的非本机玩家且 ping>1 时显示（ping<=1 视为断线，配合黑灯修复）
		if(pingLabel ~= nil) then
			if(playerID ~= Network.GetLocalPlayerID()
				and Network.IsPlayerConnected(playerID)
				and iPingTime > 1) then
				-- 颜色以文本标签形式加在数值前（SetColor 对 Label 无效，见上方常量注释）
				local colorTag :string = PING_COLOR_BAD;
				if(iPingTime < PING_GREAT) then
					colorTag = PING_COLOR_GREAT;
				elseif(iPingTime < PING_OK) then
					colorTag = PING_COLOR_OK;
				end
				pingLabel:SetText(colorTag .. tostring(iPingTime) .. "ms");
				pingLabel:SetHide(false);
			else
				pingLabel:SetHide(true);
			end
		end

		connectIcon:SetHide(false);
		if(Network.IsPlayerHotJoining(playerID)) then
			-- Player is hot joining.
			connectIcon:SetString("[ICON_HotjoiningPip]");
			connectIcon:SetToolTipString( PlayerConnectingStr ..  pingStr);
		elseif(Network.IsPlayerConnected(playerID)) then
			if(not pPlayerConfig:GetModReady()) then
				-- Player is not mod ready yet
				connectIcon:SetString("[ICON_NotModReadyPip]");
				connectIcon:SetToolTipString( PlayerNotModReadyStr .. pingStr );
			elseif(Network.IsPlayerResyncing(playerID)) then
				connectIcon:SetString("[ICON_ResyncingPip]");
				connectIcon:SetToolTipString( PlayerResyncingStr .. pingStr );
			else
				-- fully connected
				-- icon changes based on ping time and pause state.
				if(pPlayerConfig:GetWantsPause()) then
					-- 联机工具箱2.0 吸收1.67 BNL修复：ping<=1 且非本机视为断线，显示黑灯
					if(iPingTime <= 1 and playerID ~= Network.GetLocalPlayerID()) then
						connectIcon:SetString("[ICON_OfflinePip]");
					elseif(iPingTime < PING_GREAT) then -- green
						connectIcon:SetString("[ICON_PausedGreenPingPip]");
					elseif(iPingTime < PING_OK) then -- yellow
						connectIcon:SetString("[ICON_PausedYellowPingPig]");
					else -- red
						connectIcon:SetString("[ICON_PausedRedPingPig]");
					end
				else
					-- 联机工具箱2.0 吸收1.67 BNL修复：ping<=1 且非本机视为断线，显示黑灯
					if(iPingTime <= 1 and playerID ~= Network.GetLocalPlayerID()) then
						connectIcon:SetString("[ICON_OfflinePip]");
					elseif(iPingTime < PING_GREAT) then -- green
						connectIcon:SetString("[ICON_OnlineGreenPingPip]");
					elseif(iPingTime < PING_OK) then -- yellow
						connectIcon:SetString("[ICON_OnlineYellowPingPig]");
					else -- red
						connectIcon:SetString("[ICON_OnlineRedPingPig]");
					end
				end	

				connectIcon:SetToolTipString( PlayerConnectedStr .. pingStr );
			end
		else
			-- Not connected
			connectIcon:SetString("[ICON_OfflinePip]");
			connectIcon:SetToolTipString( PlayerNotConnectedStr );		
		end		
  else
		connectIcon:SetHide(true);
		-- 联机工具箱2.0 新增：空槽位时同步隐藏 ping 数值标签
		if(pingLabel ~= nil) then
			pingLabel:SetHide(true);
		end
  end
end

-- ============================================================================
-- 多人游戏 mod 版本校验（条目4.1）
-- 校验清单：SQL 注册表 MPT_ModCheck（前端配置库，见 FrontEnd/ModCheck/ModCheck_Data.sql），
--      各 mod 自行登记 modId（opt-in）；房主广播 注册表∩已启用 的 modId 与版本指纹。
--      「重新校验」按钮强制全员重新回报。校验未通过时房主启动倒计时被压住并弹窗
--      （返回重新验证 / 放弃验证），不一致玩家整行红底（各端本地比对，全员可见）。
-- 数据通道（PlayerConfigurations:SetValue/GetValue + Network.BroadcastPlayerInfo，参考1.67 BSR Poke_Gold）：
--   MPT_MC_LIST  房主写："<rev>_<modId1>,<modId2>,..."（注册清单，直接发 modId；实测4000字符无损）
--   MPT_MC_HOSTV 房主写："<v1>;<v2>;..."（房主各 mod 的 Version 指纹，与清单同序，作为比对基准）
--   MPT_MC_VERS  非房主写自己："<rev>_<v1>;<v2>;..."（针对清单 rev 的回报；rev 不匹配视为未回报）
-- 防换槽误报：状态键 = playerID+玩家名，换槽/换人即重置；回报自带 rev，旧清单回报天然失效。
-- ============================================================================
-- 版本校验本地化文本缓存（条目4.1，预加载避免每次弹窗/构建明细时重复 Lookup）
-- 明细行由「玩家名 + 前缀分隔 + 模组名 + 固定正文」用 .. 拼接，全部为无参数纯文本 tag。
local ModCheckDetailNoReportStr = Locale.Lookup("LOC_MPT_MODCHECK_DETAIL_NOREPORT");
local ModCheckDetailMismatchPrefixStr = Locale.Lookup("LOC_MPT_MODCHECK_DETAIL_MISMATCH_PREFIX");
local ModCheckDetailMismatchSuffixStr = Locale.Lookup("LOC_MPT_MODCHECK_DETAIL_MISMATCH_SUFFIX");
local ModCheckDetailPendingStr = Locale.Lookup("LOC_MPT_MODCHECK_DETAIL_PENDING");
local ModCheckPopupTitleStr = Locale.Lookup("LOC_MPT_MODCHECK_POPUP_TITLE");
local ModCheckPopupTextStr = Locale.Lookup("LOC_MPT_MODCHECK_POPUP_TEXT");
local ModCheckPopupRecheckStr = Locale.Lookup("LOC_MPT_MODCHECK_POPUP_RECHECK");
local ModCheckPopupSkipStr = Locale.Lookup("LOC_MPT_MODCHECK_POPUP_SKIP");

local MPT_CHECK = { PENDING = 0, OK = 1, FAILED = 2, HOST = 99 };	-- 校验状态命名常量（替代 MPH 魔法数字）
local MPT_MC_LIST_KEY : string = "MPT_MC_LIST";
local MPT_MC_HOSTV_KEY : string = "MPT_MC_HOSTV";
local MPT_MC_VERS_KEY : string = "MPT_MC_VERS";
local MPT_REPORT_TIMEOUT : number = 10;	-- 清单生效后等待回报的超时（秒，os.time 墙钟），超时判「未回报」
local g_mpt_playerModStatus : table = {};	-- [playerID] = { Status, Name, Mismatch, NoReport }，按 playerID 做键
local g_mpt_enabledModMap : table = {};	-- 已启用 mod 映射 [modId]=rawTitle（启用过滤与标题解析用）
local g_mpt_listRev : number = 0;			-- 本机已知的最新清单 rev（房主=已发布值，客户端=读到的值）
local g_mpt_publishTime : number = 0;		-- 当前清单生效时刻（os.time，超时判定用）
local g_mpt_knownHostID : number = -1;		-- 已知房主槽位（检测房主迁移）
g_mpt_checkSkipped = false;	-- 房主已选择「放弃验证」（增员时自动复位；条目4.1修复：新 rev 发布时也复位——放弃仅对当轮验证有效）。不用 local：CheckGameAutoStart（本文件 :1261 前部）引用本变量，Lua local 词法作用域不覆盖声明点之前的函数
local g_mpt_popupShownRev : number = -1;	-- 已弹过窗的清单 rev（同一 rev 只弹一次）
local g_mpt_lastTickTime : number = 0;		-- tick 节流（os.time 秒级）
g_mpt_roomEnterTime = 0;	-- 本房间进入时刻（os.time；沉淀门用，0=未记录时以首个可见 tick 兜底）。条目4.1修复新增，用全局不占寄存器
g_mpt_reportDueTime = 0;	-- 待执行回报的到期时刻（os.time，0=无待报；按 playerID 抖动摊平全员同 tick 广播）。条目4.1修复新增
g_mpt_modListDirtyTime = 0;	-- 本机 mod 下载/更新到终态的时刻（os.time，0=干净；静默期满后重发/重报指纹）。不用 local：OnModStatusUpdated（本文件 :693 前部）写本变量。条目4.1修复新增
g_mpt_installedVerCache = nil;	-- 已安装 mod 版本缓存 [modId]=version字符串（nil=未构建；失效点：ModStatusUpdated / 新会话）。不用 local：OnModStatusUpdated（本文件 :693 前部）引用本变量，local 词法作用域不覆盖声明点之前的函数

-------------------------------------------------
-- MPT_SplitString
-- 按单个分隔符拆分字符串为数组（"+ "模式丢弃空段；本模块数据中无空段，空串返回空表）。
-------------------------------------------------
function MPT_SplitString( text : string, delimiter : string )
	local result : table = {};
	if text == nil or text == "" then
		return result;
	end
	for piece in string.gmatch(text, "([^" .. delimiter .. "]+)") do
		table.insert(result, piece);
	end
	return result;
end

-------------------------------------------------
-- MPT_RebuildInstalledVerCache
-- 一次 Modding.GetInstalledMods() 全量枚举，构建 [modId]=version 映射（Version 缺失存 "?"）。
-- 背景：GetInstalledMods 枚举开销随安装 mod 数增长，旧实现每次发布按勾选数调用 7+ 次全量枚举，
--      导致切换槽位/勾选复选框时明显卡顿；改为懒构建一次、之后纯表查找。
-- 失效点：Events.ModStatusUpdated（mod 下载/启用状态变化）、MPT_ResetModCheckSession（新会话保险）。
-------------------------------------------------
function MPT_RebuildInstalledVerCache()
	g_mpt_installedVerCache = {};
	local mods = Modding.GetInstalledMods();
	if mods == nil then
		return;
	end
	for _, mod in ipairs(mods) do
		local version = Modding.GetModProperty(mod.Handle, "Version");
		g_mpt_installedVerCache[mod.Id] = version ~= nil and tostring(version) or "?";
	end
end

-------------------------------------------------
-- MPT_GetLocalModVersion
-- 读取本机已安装 mod 的 modinfo <Properties><Version>（同 MPH GetLocalModVersion :551）；
-- 未安装或未填 Version 均返回 "?"（双方同为 "?" 视为一致）。走 g_mpt_installedVerCache 缓存。
-------------------------------------------------
function MPT_GetLocalModVersion( modId )
	if modId == nil then
		return "?";
	end
	if g_mpt_installedVerCache == nil then
		MPT_RebuildInstalledVerCache();
	end
	return g_mpt_installedVerCache[modId] or "?";
end

-------------------------------------------------
-- MPT_GetModTitle
-- 取启用 mod 的显示名（Title 为 LOC 标签时本地化，否则原样）；未启用/未知名回退为 modId。
-------------------------------------------------
function MPT_GetModTitle( modId : string )
	local title = g_mpt_enabledModMap[modId];
	if title == nil then
		return tostring(modId);
	end
	if string.sub(title, 1, 4) == "LOC_" then
		return Locale.Lookup(title);
	end
	return title;
end

-------------------------------------------------
-- MPT_CacheEnabledMods
-- 刷新已启用 mod 映射 [modId]=rawTitle；调用点：tick 每秒一次（覆盖游戏配置变化）、发布前。
-------------------------------------------------
function MPT_CacheEnabledMods()
	g_mpt_enabledModMap = {};
	local enabledMods = GameConfiguration.GetEnabledMods() or {};
	for _, curMod in ipairs(enabledMods) do
		g_mpt_enabledModMap[curMod.Id] = tostring(curMod.Title);
	end
end

-------------------------------------------------
-- MPT_GetRegisteredCheckList
-- 校验清单 = SQL 注册表 MPT_ModCheck ∩ 当前已启用 mod（各 mod 自行登记 modId，opt-in）；
-- 返回 modId 数组（发布/回报/比对共用；每次发布时查询，表小开销可忽略）。
-------------------------------------------------
function MPT_GetRegisteredCheckList()
	local result : table = {};
	local rows = DB.ConfigurationQuery("SELECT ModId FROM MPT_ModCheck ORDER BY rowid ASC");
	if rows == nil then
		return result;
	end
	for _, row in ipairs(rows) do
		local modId = row.ModId;
		if modId ~= nil and g_mpt_enabledModMap[modId] ~= nil then
			table.insert(result, modId);
		end
	end
	return result;
end

-------------------------------------------------
-- MPT_GetHostCheckList
-- 读房主槽位的清单 value；返回 rev, modIdArray（房主未发布时返回 nil）。
-------------------------------------------------
function MPT_GetHostCheckList()
	local hostID : number = Network.GetGameHostPlayerID();
	local pHostConfig = PlayerConfigurations[hostID];
	if pHostConfig == nil then
		return nil;
	end
	local listStr = pHostConfig:GetValue(MPT_MC_LIST_KEY);
	if listStr == nil or listStr == "" then
		return nil;
	end
	local splitAt = string.find(listStr, "_");
	if splitAt == nil then
		return nil;
	end
	local rev = tonumber(string.sub(listStr, 1, splitAt - 1));
	local idxArray = MPT_SplitString(string.sub(listStr, splitAt + 1), ",");
	return rev, idxArray;
end

-------------------------------------------------
-- MPT_UpdateRowWarning
-- 按状态显隐玩家行整行红底（ModCheckWarnBox）；forceHide 用于玩家退出时强制还原。
-------------------------------------------------
function MPT_UpdateRowWarning( playerID : number, forceHide : boolean )
	local playerEntry = g_PlayerEntries[playerID];
	if playerEntry == nil then
		return;
	end
	local info = g_mpt_playerModStatus[playerID];
	local show : boolean = (forceHide ~= true) and info ~= nil and info.Status == MPT_CHECK.FAILED;
	playerEntry.ModCheckWarnBox:SetHide(not show);
end

-------------------------------------------------
-- MPT_ResetPlayerStatusForNewRev
-- 新清单生效：非房主玩家全部回 PENDING 等新一轮回报，红行同步刷新。
-------------------------------------------------
function MPT_ResetPlayerStatusForNewRev()
	for playerID, info in pairs(g_mpt_playerModStatus) do
		if info.Status ~= MPT_CHECK.HOST then
			info.Status = MPT_CHECK.PENDING;
			info.Mismatch = {};
			info.NoReport = false;
			MPT_UpdateRowWarning(playerID);
		end
	end
end

-------------------------------------------------
-- MPT_ResetModCheckSession
-- 新会话（新房间）重置校验生命周期：rev 归零（触发首次发布）、已知房主复位、
-- 玩家状态表清空（reconcile 重建）、「放弃验证」与弹窗记录复位、
-- 进房沉淀门重新计时、待报/脏标记清零（条目4.1修复新增后三项）。
-- 调用点：OnShow 检测到 fresh session 时；Lua 状态跨房间存续，不重置则后续房间校验静默失效。
-------------------------------------------------
function MPT_ResetModCheckSession()
	g_mpt_listRev = 0;
	g_mpt_knownHostID = -1;
	g_mpt_publishTime = 0;
	g_mpt_checkSkipped = false;
	g_mpt_popupShownRev = -1;
	g_mpt_playerModStatus = {};
	g_mpt_installedVerCache = nil;	-- 版本缓存一并失效（新会话保险，下次用到时一次枚举重建）
	g_mpt_roomEnterTime = os.time();	-- 进房沉淀门起点（完整进房稳定后才读 SQL 清单/首发首报）
	g_mpt_reportDueTime = 0;			-- 清掉上一房间可能挂着的待报
	g_mpt_modListDirtyTime = 0;
end

-------------------------------------------------
-- MPT_PublishCheckList（房主）
-- 注册清单（MPT_ModCheck ∩ 已启用）→ modId 清单 + 本地 Version 指纹，rev 自增后经 PlayerConfig value 广播。
-- 调用点：「重新校验」/ 弹窗「返回重新验证」/ 接管房主 / 首次进房（tick 驱动）。
-------------------------------------------------
function MPT_PublishCheckList()
	if not Network.IsGameHost() then
		return;
	end
	-- 双保险：隐藏窗口期禁止发布（弹窗「返回重新验证」不经过 tick 门控可直达本函数；
	-- 日志实证房间初始化隐藏期 BroadcastPlayerInfo 会推送半初始化槽位配置，触发本地玩家槽位 0→1→2 漂移、旧槽位残留为 AI）
	if ContextPtr:IsHidden() then
		return;
	end
	MPT_CacheEnabledMods();
	local idList : table = MPT_GetRegisteredCheckList();
	local verList : table = {};
	for _, modId in ipairs(idList) do
		table.insert(verList, MPT_GetLocalModVersion(modId));
	end
	g_mpt_listRev = g_mpt_listRev + 1;
	local hostID : number = Network.GetLocalPlayerID();
	local pConfig = PlayerConfigurations[hostID];
	pConfig:SetValue(MPT_MC_LIST_KEY, tostring(g_mpt_listRev) .. "_" .. table.concat(idList, ","));
	pConfig:SetValue(MPT_MC_HOSTV_KEY, table.concat(verList, ";"));
	Network.BroadcastPlayerInfo(hostID);
	g_mpt_publishTime = os.time();
	g_mpt_checkSkipped = false;	-- 条目4.1修复 A4：新 rev = 新一轮验证，「放弃验证」仅对当轮有效
	MPT_ResetPlayerStatusForNewRev();
	-- 条目4.1修复 A1：发布即作废当轮校验结果（全员回 PENDING）；若启动倒计时正在运行（房主倒计时中点了「重新校验」），立即重评估压停
	CheckGameAutoStart();
	print("MPT_PublishCheckList rev=", g_mpt_listRev, "mods=", #idList);
end

-------------------------------------------------
-- MPT_RequestReport（非房主，条目4.1修复 C3 新增）
-- 统一回报请求通道：只登记到期时刻，由 tick 到期后统一执行 MPT_ReportVersions。
-- 背景：rev 变化那一秒所有客机在同一 tick 窗口 SetValue+BroadcastPlayerInfo，20 人房并发
--      20 份全量玩家信息，易网络卡顿；调用方传入按 playerID 的确定性抖动把回报摊平。
-- 用法：MPT_RequestReport(delaySeconds)；多次请求取最早到期时刻，到期只执行一次。
-------------------------------------------------
function MPT_RequestReport(delaySeconds : number)
	if Network.IsGameHost() then
		return;	-- 房主指纹走 HOSTV，无回报通道
	end
	local dueTime : number = os.time() + (delaySeconds or 0);
	if g_mpt_reportDueTime == 0 or dueTime < g_mpt_reportDueTime then
		g_mpt_reportDueTime = dueTime;
	end
end

-------------------------------------------------
-- MPT_ReportVersions（非房主）
-- 按房主清单顺序计算本机 Version 指纹，带上清单 rev 回报（广播）。
-- 条目4.1修复 C3：算出的 VERS 与槽位现值相同则直接返回，不重复广播（消除无效网络流量）。
-- 调用点：tick 中 g_mpt_reportDueTime 到期（统一回报通道，勿直接调用以免绕过抖动）。
-------------------------------------------------
function MPT_ReportVersions()
	if Network.IsGameHost() then
		return;	-- 房主指纹走 HOSTV，无需回报
	end
	local rev, modIdArray = MPT_GetHostCheckList();
	if rev == nil then
		return;
	end
	local verList : table = {};
	for _, modId in ipairs(modIdArray) do
		table.insert(verList, MPT_GetLocalModVersion(modId));
	end
	local localPlayerID : number = Network.GetLocalPlayerID();
	local pConfig = PlayerConfigurations[localPlayerID];
	local newValue : string = tostring(rev) .. "_" .. table.concat(verList, ";");
	if pConfig:GetValue(MPT_MC_VERS_KEY) == newValue then
		return;	-- 与槽位现值相同：不重复 SetValue/广播（断线重连后旧值仍在等场景）
	end
	pConfig:SetValue(MPT_MC_VERS_KEY, newValue);
	Network.BroadcastPlayerInfo(localPlayerID);
end

-------------------------------------------------
-- MPT_ReconcilePlayers
-- 对账玩家状态表（加入/退出/换槽重新计算）：
--   键 = playerID+玩家名，换槽/换人即重置（防读取旧占槽者残留 value 误报，用户指定）；
--   退出删除；增员复位「放弃验证」；房主自身恒为 HOST。
--   JoinTime 记录进房/换人时刻（条目4.1修复 C1：超时宽限按各玩家自己的进房时刻起算）；
--   本机玩家条目新建时经统一回报通道兜底补报（条目4.1修复 A2：断线重连/换槽后 rev 未变，
--   正常路径只在 rev 变化时回报一次，不补报会被判「未回报」卡死）。
-------------------------------------------------
function MPT_ReconcilePlayers()
	local seen : table = {};
	local added : boolean = false;
	local addedLocal : boolean = false;	-- 新增条目是否含本机玩家（条目4.1修复 A2）
	local localPlayerID : number = Network.GetLocalPlayerID();
	local playerIDs : table = GameConfiguration.GetMultiplayerPlayerIDs();
	for _, playerID in ipairs(playerIDs) do
		local pConfig = PlayerConfigurations[playerID];
		if pConfig ~= nil and pConfig:IsHuman() and Network.IsPlayerConnected(playerID) then
			seen[playerID] = true;
			local name : string = tostring(pConfig:GetPlayerName());
			local info = g_mpt_playerModStatus[playerID];
			if info == nil then
				g_mpt_playerModStatus[playerID] = { Status = MPT_CHECK.PENDING, Name = name, Mismatch = {}, NoReport = false, JoinTime = os.time() };
				added = true;
				if playerID == localPlayerID then
					addedLocal = true;
				end
			elseif info.Name ~= name then
				info.Status = MPT_CHECK.PENDING;
				info.Name = name;
				info.Mismatch = {};
				info.NoReport = false;
				info.JoinTime = os.time();	-- 换人进槽：宽限期重新起算（条目4.1修复 C1）
			end
		end
	end
	for playerID in pairs(g_mpt_playerModStatus) do
		if not seen[playerID] then
			MPT_UpdateRowWarning(playerID, true);
			g_mpt_playerModStatus[playerID] = nil;
		end
	end
	local hostID : number = Network.GetGameHostPlayerID();
	-- 房主迁移后原房主仍在房：清掉其残留 HOST 标记，重新纳入校验（否则永远跳过比对）
	for playerID, info in pairs(g_mpt_playerModStatus) do
		if info.Status == MPT_CHECK.HOST and playerID ~= hostID then
			info.Status = MPT_CHECK.PENDING;
		end
	end
	if hostID ~= nil and hostID >= 0 and g_mpt_playerModStatus[hostID] ~= nil then
		g_mpt_playerModStatus[hostID].Status = MPT_CHECK.HOST;
	end
	if added then
		g_mpt_checkSkipped = false;	-- 新玩家未经验证，不继承「放弃验证」
	end
	-- 条目4.1修复 A2：本机条目新建（断线重连/换槽/首次进房）且清单已发布 → 兜底补报
	-- （抖动 1 秒走统一通道；正常 rev 跟踪路径也会在 rev 变化时请求，通道内取最早到期时刻）
	if addedLocal and g_mpt_listRev > 0 then
		MPT_RequestReport(1);
	end
end

-------------------------------------------------
-- MPT_EvaluateAll
-- 各端对称的纯本地比对：读房主 HOSTV + 各玩家 VERS（rev 需匹配当前清单）→
-- 状态表与红行；超时未回报判 FAILED（没装本 mod 的玩家必然落入此类）。
-------------------------------------------------
function MPT_EvaluateAll()
	local rev, modIdArray = MPT_GetHostCheckList();
	if rev == nil or rev ~= g_mpt_listRev then
		return;	-- 清单未发布或本机尚未跟踪到最新 rev
	end
	if #modIdArray == 0 then
		-- 空清单 = 无需校验，全部视为通过
		for playerID, info in pairs(g_mpt_playerModStatus) do
			if info.Status ~= MPT_CHECK.HOST then
				info.Status = MPT_CHECK.OK;
				info.Mismatch = {};
				info.NoReport = false;
				MPT_UpdateRowWarning(playerID);
			end
		end
		return;
	end
	local hostID : number = Network.GetGameHostPlayerID();
	local pHostConfig = PlayerConfigurations[hostID];
	if pHostConfig == nil then
		return;	-- 条目4.1修复 B5：房主迁移切换帧槽位瞬态无效，防御
	end
	local hostVersStr = pHostConfig:GetValue(MPT_MC_HOSTV_KEY);
	local hostVers : table = MPT_SplitString(hostVersStr or "", ";");
	local now : number = os.time();
	for playerID, info in pairs(g_mpt_playerModStatus) do
		if info.Status ~= MPT_CHECK.HOST then
			local reported : boolean = false;
			local mismatch : table = {};
			local pConfig = PlayerConfigurations[playerID];
			local versStr = pConfig ~= nil and pConfig:GetValue(MPT_MC_VERS_KEY) or nil;
			if versStr ~= nil then
				local splitAt = string.find(versStr, "_");
				if splitAt ~= nil and tonumber(string.sub(versStr, 1, splitAt - 1)) == rev then
					reported = true;
					local vers : table = MPT_SplitString(string.sub(versStr, splitAt + 1), ";");
					for i, modId in ipairs(modIdArray) do
						local hostVer : string = tostring(hostVers[i] or "?");
						local playerVer : string = tostring(vers[i] or "?");
						if hostVer ~= playerVer then
							table.insert(mismatch, { ModId = modId, HostVer = hostVer, PlayerVer = playerVer });
						end
					end
				end
			end
			if not reported then
				-- 条目4.1修复 C1：宽限按「清单发布时刻与该玩家进房时刻的较晚者」起算，迟到进房/换槽的玩家也有自己的 10 秒回报窗口，不再被立即误判「未回报」
				if now - math.max(g_mpt_publishTime, info.JoinTime or 0) >= MPT_REPORT_TIMEOUT then
					info.Status = MPT_CHECK.FAILED;
					info.NoReport = true;
					info.Mismatch = {};
				else
					info.Status = MPT_CHECK.PENDING;
				end
			elseif #mismatch > 0 then
				info.Status = MPT_CHECK.FAILED;
				info.NoReport = false;
				info.Mismatch = mismatch;
			else
				info.Status = MPT_CHECK.OK;
				info.NoReport = false;
				info.Mismatch = {};
			end
			MPT_UpdateRowWarning(playerID);
		end
	end
end

-------------------------------------------------
-- MPT_IsModCheckFailing
-- 任一玩家未通过（PENDING/FAILED）即 true；CheckGameAutoStart 钩子据此压倒计时。
-- 清单尚未发布（rev==0，进房首秒窗口期）时不判失败，避免误压倒计时/误弹窗。
-------------------------------------------------
function MPT_IsModCheckFailing()
	if g_mpt_listRev == 0 then
		return false;
	end
	for _, info in pairs(g_mpt_playerModStatus) do
		if info.Status ~= MPT_CHECK.OK and info.Status ~= MPT_CHECK.HOST then
			return true;
		end
	end
	return false;
end

-------------------------------------------------
-- MPT_IsCheckActive
-- 功能总开关：热座/PBC 不启用（value 通道在 PBC 行为未验证），退房后停止。
-------------------------------------------------
function MPT_IsCheckActive()
	if GameConfiguration.IsHotseat() or GameConfiguration.IsPlayByCloud() then
		return false;
	end
	return Network.IsInSession();
end

-------------------------------------------------
-- MPT_ModCheckTick（Events.GameCoreEventPublishComplete，Initialize 注册）
-- 1s 节流驱动全部校验逻辑：进房沉淀门 → 房主首发/迁移重发清单 → 客户端 rev 跟踪与抖动回报 →
-- reconcile（加入/退出/换槽）→ 本地比对 → 红行 → 到期回报/脏重发 → 状态迁移回调。
-- 统一兜底，不依赖单次事件。条目4.1修复新增：
--   C2 沉淀门：进房 3 秒内不动作（等前端 Configuration 库切换到本房间启用 mod 集再读 SQL 清单）；
--   C3 回报经统一通道按 playerID%4 秒抖动摊平，避免 rev 变化时全员同 tick 广播；
--   A1 校验通过/失败迁移时房主端回调 CheckGameAutoStart（倒计时自动恢复/压停）；
--   A3 本机 mod 下载/更新终态静默 3 秒后房主重发清单 / 客机重报。
-------------------------------------------------
function MPT_ModCheckTick()
	if not MPT_IsCheckActive() then
		return;
	end
	-- 可见性门：只在准备房间实际显示（初始化稳定）时运行校验逻辑。
	-- 日志实证：房间创建过渡（HostGame/JoiningRoom）中本 context 虽隐藏但 GameCoreEventPublishComplete 仍会触发，
	-- 此时 BroadcastPlayerInfo 会推送半初始化槽位配置，引发本地玩家槽位 0→1→2 漂移风暴（旧槽位残留 AI）。
	if ContextPtr:IsHidden() then
		return;
	end
	local now : number = os.time();
	if now == g_mpt_lastTickTime then
		return;
	end
	g_mpt_lastTickTime = now;

	-- 进房沉淀门（条目4.1修复 C2）：完整进房稳定后才读 SQL 清单/首发首报
	if g_mpt_roomEnterTime == 0 then
		g_mpt_roomEnterTime = now;	-- 兜底：未经过新会话重置时以首个可见 tick 为进房时刻
	end
	if now - g_mpt_roomEnterTime < 3 then
		return;
	end

	MPT_CacheEnabledMods();

	-- 房主迁移检测：本机成为新房主时接续 rev 重新发布清单
	-- 阻尼：忽略瞬态无效 hostID（不更新已知值）；重发需确认本机确为房主槽位（防初始化期 ID 抖动误触发）
	local hostID : number = Network.GetGameHostPlayerID();
	if hostID ~= nil and hostID >= 0 and hostID ~= g_mpt_knownHostID then
		g_mpt_knownHostID = hostID;
		if Network.IsGameHost() and hostID == Network.GetLocalPlayerID() then
			MPT_PublishCheckList();
		end
	end

	-- 房主首次进房发布
	if Network.IsGameHost() and g_mpt_listRev == 0 then
		MPT_PublishCheckList();
	end

	-- 跟踪清单 rev：变化 → 抖动重报 + 状态重置（房主读到自己发布的同 rev 不会进入）
	local rev = MPT_GetHostCheckList();
	if rev ~= nil and rev ~= g_mpt_listRev then
		g_mpt_listRev = rev;
		g_mpt_publishTime = now;
		-- 条目4.1修复 C3：按 playerID 确定性抖动 0-3 秒摊平全员回报，避免同 tick 广播风暴
		local localID : number = Network.GetLocalPlayerID();
		MPT_RequestReport(localID ~= nil and (localID % 4) or 0);
		MPT_ResetPlayerStatusForNewRev();
	end

	-- 条目4.1修复 A1：记录比对前状态，尾部迁移时回调（EvaluateAll 只在 tick 改状态，事件驱动的 CheckGameAutoStart 读到的是迁移前状态）
	local wasFailing : boolean = MPT_IsModCheckFailing();

	MPT_ReconcilePlayers();
	MPT_EvaluateAll();

	-- 条目4.1修复 C3：到期执行统一回报请求（抖动摊平）
	if g_mpt_reportDueTime ~= 0 and now >= g_mpt_reportDueTime then
		g_mpt_reportDueTime = 0;
		MPT_ReportVersions();
	end

	-- 条目4.1修复 A3：本机 mod 下载/更新终态静默期满 → 房主重发清单（rev++ 全员重报）/ 客机重报
	if g_mpt_modListDirtyTime ~= 0 and now - g_mpt_modListDirtyTime >= 3 then
		g_mpt_modListDirtyTime = 0;
		if Network.IsGameHost() then
			MPT_PublishCheckList();
		else
			MPT_RequestReport(0);
		end
	end

	-- 条目4.1修复 A1：校验通过/失败状态迁移 → 房主端重评估启动（全绿自动恢复倒计时；转失败压停并弹窗）
	if Network.IsGameHost() and wasFailing ~= MPT_IsModCheckFailing() then
		CheckGameAutoStart();
	end
end

-------------------------------------------------
-- MPT_BuildFailureDetails
-- 弹窗明细：逐未通过玩家列出原因（未回报/逐 mod 版本不一致/等待中）。
-------------------------------------------------
function MPT_BuildFailureDetails()
	local details : table = {};
	for playerID, info in pairs(g_mpt_playerModStatus) do
		if info.Status == MPT_CHECK.FAILED then
			if info.NoReport then
				table.insert(details, info.Name .. ModCheckDetailNoReportStr);
			else
				for _, m in ipairs(info.Mismatch) do
					table.insert(details, info.Name .. ModCheckDetailMismatchPrefixStr .. MPT_GetModTitle(m.ModId) .. ModCheckDetailMismatchSuffixStr);
				end
			end
		elseif info.Status == MPT_CHECK.PENDING then
			table.insert(details, info.Name .. ModCheckDetailPendingStr);
		end
	end
	return table.concat(details, "[NEWLINE]");
end

-------------------------------------------------
-- MPT_MaybePopupModCheckWarning
-- 校验未通过时给房主弹窗（同一 rev 只弹一次，防 CheckGameAutoStart 反复触发）：
-- 按钮①「返回重新验证」→ rev 自增强制全员重报；按钮②「放弃验证」→ 放行本次启动。
-------------------------------------------------
function MPT_MaybePopupModCheckWarning()
	if g_mpt_popupShownRev == g_mpt_listRev then
		return;
	end
	g_mpt_popupShownRev = g_mpt_listRev;
	m_kPopupDialog:Close();
	m_kPopupDialog:AddTitle(Locale.ToUpper(ModCheckPopupTitleStr));
	m_kPopupDialog:AddText(ModCheckPopupTextStr .. "[NEWLINE]" .. MPT_BuildFailureDetails());
	m_kPopupDialog:AddButton(ModCheckPopupRecheckStr, MPT_OnPopupRecheck);
	m_kPopupDialog:AddButton(ModCheckPopupSkipStr, MPT_OnPopupSkip);
	m_kPopupDialog:Open();
end

function MPT_OnPopupRecheck()
	MPT_PublishCheckList();
end

function MPT_OnPopupSkip()
	g_mpt_checkSkipped = true;
	CheckGameAutoStart();	-- 重新评估启动（本次放行）
end

-------------------------------------------------
-- MPT_OnRecheckButton
-- 「重新校验」按钮回调（rev 自增强制全员重报；校验清单为 SQL 注册表驱动，无手选面板）。
-------------------------------------------------
function MPT_OnRecheckButton()
	UI.PlaySound("Play_UI_Click");
	MPT_PublishCheckList();
end

-- ============================================================================
-- 非官方模组清单侧滑面板（条目4.2）
-- 用法：左下角「模组清单」按钮打开侧滑面板，列出本房间启用的非官方 mod；
--       点击行经 Steam.ActivateGameOverlayToUrl 打开对应创意工坊页面；
--       本机未订阅的行显橙色底 + 「未订阅」，已订阅正常，无 SubscriptionId 的本地 mod 不可点。
-- 数据来源（参考 BSR OnModCheckButton）：GameConfiguration.GetEnabledMods()（房间启用 mod）
--       与 Modding.GetInstalledMods()（本机安装 mod，含 Official/SubscriptionId/Name）交叉，
--       订阅状态用 Modding.GetSubscriptions()（本机订阅 ID 列表，比较时 tostring 归一）。
-- 面板每次打开都重建列表（跨房无残留）；关闭走 SlideAnim Reverse 滑回左侧。
-- ============================================================================
-- 模组清单本地化文本缓存（条目4.2，预加载避免每次重建列表时重复 Lookup）
local ModListLocalStr = Locale.Lookup("LOC_MPT_MODLIST_LOCAL");
local ModListSubscribedStr = Locale.Lookup("LOC_MPT_MODLIST_SUBSCRIBED");
local ModListUnsubscribedStr = Locale.Lookup("LOC_MPT_MODLIST_UNSUBSCRIBED");
local ModListEmptyStr = Locale.Lookup("LOC_MPT_MODLIST_EMPTY");

local m_modListEntryIM = InstanceManager:new("ModListEntryInstance", "EntryRoot", Controls.ModListStack);
g_modListOpen = false;	-- 面板开/关态。不用 local：KeyUpHandler/OnHandleExitRequest（本文件前部）引用本变量，且 SlideAnim Reverse 不回设 Hidden，IsHidden 不可靠

-------------------------------------------------
-- MPT_BuildModList
-- 重建模组清单：房间启用 ∩ 非官方；未订阅行橙色底；本地（无工坊 ID）行不可点。
-------------------------------------------------
function MPT_BuildModList()
	m_modListEntryIM:ResetInstances();

	-- 本机订阅 ID 集合（tostring 归一，与 installed.SubscriptionId 比较）
	local subscribedSet : table = {};
	local subscriptions = Modding.GetSubscriptions() or {};
	for _, sid in ipairs(subscriptions) do
		subscribedSet[tostring(sid)] = true;
	end

	-- 本机安装 mod 映射 [modId] = installedMod（含 Official/SubscriptionId/Name）
	local installedMap : table = {};
	local installedMods = Modding.GetInstalledMods() or {};
	for _, mod in ipairs(installedMods) do
		installedMap[tostring(mod.Id)] = mod;
	end

	local enabledMods = GameConfiguration.GetEnabledMods() or {};
	local shownCount : number = 0;

	for _, curMod in ipairs(enabledMods) do
		local modId : string = tostring(curMod.Id);
		local installed = installedMap[modId];
		if installed ~= nil and not installed.Official then
			local entryInstance = m_modListEntryIM:GetInstance();
			shownCount = shownCount + 1;

			-- 显示名：优先已安装 mod 的 Name（LOC 标签本地化），缺失回退 Title（MPT_GetModTitle）
			local displayName : string = nil;
			if installed.Name ~= nil and installed.Name ~= "" then
				displayName = Locale.Lookup(installed.Name);
			end
			if displayName == nil or displayName == "" then
				displayName = MPT_GetModTitle(modId);
			end
			-- 去除内联字号标签 [size_N]（大小写不敏感），避免污染列表展示
			displayName = string.gsub(displayName, "%[[sS][iI][zZ][eE]_%d+%]", "");
			entryInstance.ModNameLabel:SetText(displayName);

			local subscriptionId = installed.SubscriptionId;
			local hasSubId : boolean = subscriptionId ~= nil and tostring(subscriptionId) ~= "";

			-- Tooltip：显示 mod 的 Description（本地/工坊通用，对齐原版 Mods.lua 读取方式）
			local description = Modding.GetModProperty(installed.Handle, "Description");
			if description ~= nil and description ~= "" then
				description = Modding.GetModText(installed.Handle, description) or description;
			end
			entryInstance.ModRowButton:SetToolTipString((description ~= nil and description ~= "") and Locale.Lookup(description) or nil);

			if not hasSubId then
				-- 本地（非工坊）模组：无订阅判定，不可点，状态「本地」
				entryInstance.SubscribedLabel:SetText(ModListLocalStr);
				entryInstance.ModRowButton:SetDisabled(true);
			else
				local isSubscribed : boolean = subscribedSet[tostring(subscriptionId)] ~= nil;
				entryInstance.ModRowButton:SetDisabled(false);
				if isSubscribed then
					entryInstance.SubscribedLabel:SetText(ModListSubscribedStr);
				else
					entryInstance.SubscribedLabel:SetText("[COLOR_RED]" .. ModListUnsubscribedStr .. "[ENDCOLOR]");
				end
				local url : string = "https://steamcommunity.com/sharedfiles/filedetails/?id=" .. tostring(subscriptionId);
				entryInstance.ModRowButton:RegisterCallback(Mouse.eLClick, function()
					Steam.ActivateGameOverlayToUrl(url);
				end);
			end

			entryInstance.ModRowButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		end
	end

	if shownCount == 0 then
		-- 空态提示：无交互行展示「本房间没有启用非官方模组」
		local emptyInstance = m_modListEntryIM:GetInstance();
		emptyInstance.ModNameLabel:SetText(ModListEmptyStr);
		emptyInstance.SubscribedLabel:SetText("");
		emptyInstance.ModRowButton:SetDisabled(true);
		emptyInstance.ModRowButton:SetToolTipString(nil);
	end

	Controls.ModListStack:CalculateSize();
	Controls.ModListScrollPanel:CalculateSize();
end

-------------------------------------------------
-- OpenModListPanel / CloseModListPanel
-- 打开（重建列表 + 左侧滑出 + 显示全屏拦截层）/ 关闭。
-- CloseModListPanel(instant)：instant=true 硬关闭（直接隐藏，退出房间用），
-- 否则动画滑回（Header 关闭按钮 / 点击面板外 / ESC 用）。Close 幂等。
-------------------------------------------------
function OpenModListPanel()
	MPT_BuildModList();
	g_modListOpen = true;
	Controls.ModListModalBlocker:SetHide(false);
	Controls.ModListSlideAnim:SetHide(false);
	Controls.ModListSlideAnim:SetSpeed(1);
	Controls.ModListSlideAnim:SetToBeginning();
	Controls.ModListSlideAnim:Play();
	UI.PlaySound("UI_Screen_Open");
end

function CloseModListPanel( instant:boolean )
	if not g_modListOpen then
		return;
	end
	g_modListOpen = false;
	Controls.ModListModalBlocker:SetHide(true);
	if instant then
		-- 硬关闭：直接隐藏，不依赖滑回动画完成（退出房间时屏幕即将被回收）
		Controls.ModListSlideAnim:SetHide(true);
	else
		Controls.ModListSlideAnim:SetSpeed(3);
		Controls.ModListSlideAnim:Reverse();
		UI.PlaySound("UI_Screen_Close");
	end
end

-- ===========================================================================
--	Initialize screen
-- ===========================================================================
function Initialize()

	m_kPopupDialog = PopupDialog:new( "StagingRoom" );
	
	SetCurrentMaxPlayers(MapConfiguration.GetMaxMajorPlayers());
	SetCurrentMinPlayers(MapConfiguration.GetMinMajorPlayers());
	Events.SystemUpdateUI.Add(OnUpdateUI);
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShowHandler(OnShow);
	Controls.BackButton:RegisterCallback( Mouse.eLClick, OnExitGameAskAreYouSure );
	Controls.BackButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ChatEntry:RegisterCommitCallback( SendChat );
	Controls.InviteButton:RegisterCallback( Mouse.eLClick, OnInviteButton );
	Controls.InviteButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.EndGameButton:RegisterCallback( Mouse.eLClick, OnEndGameAskAreYouSure );
	Controls.EndGameButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);	
	Controls.QuitGameButton:RegisterCallback( Mouse.eLClick, OnQuitGameAskAreYouSure );
	Controls.QuitGameButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);	
	Controls.ReadyButton:RegisterCallback( Mouse.eLClick, OnReadyButton );
	Controls.ReadyButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ReadyCheck:RegisterCallback( Mouse.eLClick, OnReadyButton );
	Controls.ReadyCheck:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.JoinCodeText:RegisterCallback( Mouse.eLClick, OnClickToCopy );
	-- ============================================================================
	-- 联机工具箱2.0：注册「AI槽位」按钮回调（条目3.2）与「快捷分队」按钮回调（条目3.3）
	-- ----------------------------------------------------------------------------
	Controls.AISlotsButton:RegisterCallback( Mouse.eLClick, OnAISlotsButtonL );
	Controls.AISlotsButton:RegisterCallback( Mouse.eRClick, OnAISlotsButtonR );
	Controls.AISlotsButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.RandomTeamButton:RegisterCallback( Mouse.eLClick, OnRandomTeamButtonL );
	Controls.RandomTeamButton:RegisterCallback( Mouse.eRClick, OnRandomTeamButtonR );
	Controls.RandomTeamButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	-- ============================================================================
	-- 联机工具箱2.0：注册「更新公告」按钮与面板关闭回调（条目3.5）
	-- ----------------------------------------------------------------------------
	Controls.ChangelogButton:RegisterCallback( Mouse.eLClick, OpenChangelogPanel );
	Controls.ChangelogButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ChangelogCloseButton:RegisterCallback( Mouse.eLClick, CloseChangelogPanel );
	Controls.ChangelogModalBlocker:RegisterCallback( Mouse.eLClick, CloseChangelogPanel );
	-- ============================================================================
	-- 联机工具箱2.0：注册广告轮播箭头回调与帧更新，并构建轮播（条目3.6）
	-- ----------------------------------------------------------------------------
	Controls.AdLeftButton:RegisterCallback( Mouse.eLClick, OnAdLeftClick );
	Controls.AdLeftButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.AdRightButton:RegisterCallback( Mouse.eLClick, OnAdRightClick );
	Controls.AdRightButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.AdCloseButton:RegisterCallback( Mouse.eLClick, OnAdCloseClick );
	Controls.AdCloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.AdShowButton:RegisterCallback( Mouse.eLClick, OnAdShowButtonClick );
	Controls.AdShowButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	ContextPtr:SetUpdate( OnAdUpdate );
	BuildAdCarousel();
	-- ============================================================================
	-- 联机工具箱2.0：注册「重新校验」按钮与校验 tick（条目4.1，清单为 SQL 注册表驱动，无手选面板）
	-- ----------------------------------------------------------------------------
	Controls.ModRecheckButton:RegisterCallback( Mouse.eLClick, MPT_OnRecheckButton );
	Controls.ModRecheckButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Events.GameCoreEventPublishComplete.Add( MPT_ModCheckTick );
	-- ============================================================================
	-- 联机工具箱2.0：注册「非官方模组清单」按钮与面板关闭回调（条目4.2）
	-- ----------------------------------------------------------------------------
	Controls.ModListButton:RegisterCallback( Mouse.eLClick, OpenModListPanel );
	Controls.ModListButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ModListCloseButton:RegisterCallback( Mouse.eLClick, function() CloseModListPanel(); end );
	Controls.ModListCloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.ModListModalBlocker:RegisterCallback( Mouse.eLClick, function() CloseModListPanel(); end );

	Controls.InviteButton:SetToolTipString(GetInviteTT());

	Events.MapMaxMajorPlayersChanged.Add(OnMapMaxMajorPlayersChanged); 
	Events.MapMinMajorPlayersChanged.Add(OnMapMinMajorPlayersChanged);
	Events.MultiplayerPrePlayerDisconnected.Add( OnMultiplayerPrePlayerDisconnected );
	Events.GameConfigChanged.Add(OnGameConfigChanged);
	Events.PlayerInfoChanged.Add(OnPlayerInfoChanged);
	Events.UploadCloudPlayerConfigComplete.Add(OnUploadCloudPlayerConfigComplete);
	Events.ModStatusUpdated.Add(OnModStatusUpdated);
	Events.MultiplayerChat.Add( OnMultiplayerChat );
	Events.MultiplayerGameAbandoned.Add( OnAbandoned );
	Events.MultiplayerGameLaunchFailed.Add( OnMultiplayerGameLaunchFailed );
	Events.LeaveGameComplete.Add( OnLeaveGameComplete );
	Events.BeforeMultiplayerInviteProcessing.Add( OnBeforeMultiplayerInviteProcessing );
	Events.MultiplayerHostMigrated.Add( OnMultiplayerHostMigrated );
	Events.MultiplayerPlayerConnected.Add( OnMultplayerPlayerConnected );
	Events.MultiplayerPingTimesChanged.Add(OnMultiplayerPingTimesChanged);
	Events.SteamFriendsStatusUpdated.Add( UpdateFriendsList );
	Events.SteamFriendsPresenceUpdated.Add( UpdateFriendsList );
	Events.CloudGameKilled.Add(OnCloudGameKilled);
	Events.CloudGameQuit.Add(OnCloudGameQuit);

	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);
	LuaEvents.HostGame_ShowStagingRoom.Add( OnRaise );
	LuaEvents.JoiningRoom_ShowStagingRoom.Add( OnRaise );
	LuaEvents.EditHotseatPlayer_UpdatePlayer.Add(UpdatePlayerEntry);
	LuaEvents.Multiplayer_ExitShell.Add( OnHandleExitRequest );

	Controls.TitleLabel:SetText(Locale.ToUpper(Locale.Lookup("LOC_MULTIPLAYER_STAGING_ROOM")));
	ResizeButtonToText(Controls.BackButton);
	ResizeButtonToText(Controls.EndGameButton);
	ResizeButtonToText(Controls.QuitGameButton);
	RealizeShellTabs();
	RealizeInfoTabs();
	SetupGridLines(0);
	Resize();
	
end

Initialize();


-- ############################################################################
-- 条目4.3预备：序列化与本地数据读写（内联副本）
-- ============================================================================
-- 【为什么内联而不 include】实测定论：前端 include() 本 mod 经 ImportFiles 注册的
-- Lua 文件，只在进程首个前端生命周期内真正执行；开一局游戏再退回主菜单后，前端重建的
-- 新 Lua 状态下 include 静默不执行（pcall(include) 返回成功与 table，但文件体零执行、
-- 无任何报错——引擎缺陷，单变量实验已排除双环境注册嫌疑，详见 git 条目4.3预备诊断）。
-- ReplaceUIScript 投递的本文件每次前端重建都可靠重执行，故两模块内联于此。
-- 【同步义务】本区与 Storage/MPT_Serialize.lua、Storage/MPT_DataStorage.lua 同源，
--   改动必须双向同步（Storage/ 独立文件保留给未来游戏内消费方）。
-- 【与独立文件的差异】内联副本无幂等守卫（本文件每状态只执行一次，守卫无意义；
--   且 chunk 顶层中间的 return 会编译失败，守卫结构本也无法照搬），无 include。
-- 【存储方式】ModGroup 组名承载数据（原 .Civ6Cfg 方案已移除）：组名格式
--   [size_0][color:0,0,0,0][MPT_DS][fileName][key][len]数据，隐形前缀使数据组在
--   前端 Mods 界面组列表不可见；建组走「干净组」流程（先禁用全部已启用 mod、
--   建后恢复）。实测依据见 AGENTS.md 踩坑记录「ModGroup 组名存储实测定论」。
-- ############################################################################

-- 寄存器上限适配：本分区块级 do...end 包裹，块内顶层 local 随块结束释放寄存器
--（Civ6 Lua 主 chunk 寄存器有限，各分区 local 累积过多会编译报 too many registers；
--  块内全局函数/回调以 upvalue 捕获 local，功能不受影响）
do
-- ============================================================================
-- 条目4.3预备：MPT_Serialize 序列化部分（同源自 Storage/MPT_Serialize.lua）
-- 移植自联机工具箱1.67 BSR serialize/deserialize（原版出自 metalua，MIT 协议），
-- 精简重写为纯数据表单遍递归：不支持函数/循环表（报错），共享子表按值展开，
-- 输出 return {...} 字面量（loadstring 可读 1.67 旧数据）；MPT_Deserialize 损坏返回 nil。
-- ============================================================================

-- Lua 关键字表：字符串键为合法标识符时可省略引号括号输出 k=v，是关键字时回退 ["k"]=v
local g_mpt_luaKeywords = {
	["and"]=true, ["break"]=true, ["do"]=true, ["else"]=true, ["elseif"]=true,
	["end"]=true, ["false"]=true, ["for"]=true, ["function"]=true, ["goto"]=true,
	["if"]=true, ["in"]=true, ["local"]=true, ["nil"]=true, ["not"]=true,
	["or"]=true, ["repeat"]=true, ["return"]=true, ["then"]=true, ["true"]=true,
	["until"]=true, ["while"]=true,
};

-- ============================================================================
-- 内部：递归把值 x 转储为 Lua 字面量字符串片段，按序追加进 acc。
-- nest 为当前递归路径上的表集合（transient，离开该表即移除），用于检测循环引用。
-- 数组部分（整数键 1..#x）按位置输出，其余键按 [k]=v 或 k=v 输出。
-- ============================================================================
local function MPT_DumpValue(x, acc, nest)
	local t = type(x);
	if t == "number" then
		table.insert(acc, tostring(x));		-- 整数精确；浮点约 14 位有效数字
	elseif t == "boolean" then
		table.insert(acc, x and "true" or "false");
	elseif t == "string" then
		table.insert(acc, string.format("%q", x));
	elseif t == "table" then
		if nest[x] then
			error("MPT_Serialize: 不支持循环引用表");
		end
		nest[x] = true;
		table.insert(acc, "{");
		local first = true;
		for i = 1, #x do		-- 数组部分
			if first then first = false; else table.insert(acc, ","); end
			MPT_DumpValue(x[i], acc, nest);
		end
		for k, v in pairs(x) do		-- 哈希部分（跳过已按位置输出的数组键）
			if not (type(k) == "number" and k >= 1 and k <= #x and math.floor(k) == k) then
				if first then first = false; else table.insert(acc, ","); end
				if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") and not g_mpt_luaKeywords[k] then
					table.insert(acc, k);	-- 合法标识符键：k=v
				else
					table.insert(acc, "[");
					MPT_DumpValue(k, acc, nest);
					table.insert(acc, "]");
				end
				table.insert(acc, "=");
				MPT_DumpValue(v, acc, nest);
			end
		end
		nest[x] = nil;
		table.insert(acc, "}");
	elseif x == nil then
		table.insert(acc, "nil");
	else
		error("MPT_Serialize: 不支持序列化类型 " .. t);		-- function/userdata/thread
	end
end

-- ============================================================================
-- MPT_Serialize(x)：把纯数据值序列化为可 loadstring 读回的 Lua 源码字符串。
--   支持 nil/布尔/数字/字符串/表（可嵌套）；函数/userdata/线程报错；循环引用报错。
--   参数 x：任意纯数据值（通常为表）
--   返回 string：形如 "return{level=1,name="foo"}"（"return " 后必须留空格，
--   否则 return5/returntrue 这类纯数字/布尔顶层值会被词法分析成标识符）
-- ============================================================================
function MPT_Serialize(x)
	local acc = {};
	MPT_DumpValue(x, acc, {});
	return "return " .. table.concat(acc);
end

-- ============================================================================
-- MPT_Deserialize(s)：把 MPT_Serialize 的输出字符串读回为 Lua 值（含 1.67 旧数据）。
--   参数 s：MPT_Serialize 产出的字符串
--   返回：还原的 Lua 值；非字符串输入、语法损坏或执行失败时返回 nil（不抛错），
--   调用方可用 or {} 兜底（与 1.67 Read_tableString 的用法一致）
-- ============================================================================
function MPT_Deserialize(s)
	if type(s) ~= "string" then return nil; end
	local fn = loadstring(s);
	if fn == nil then return nil; end
	local ok, result = pcall(fn);
	if not ok then return nil; end
	return result;
end

-- ============================================================================
-- 条目4.3预备：MPT_DataStorage 本地数据读写部分（同源自 Storage/MPT_DataStorage.lua）
-- 极简本地数据读写工具：ModGroup 组名承载数据（原 .Civ6Cfg 方案已移除）。
-- 原理：Modding.CreateModGroup 组名长度 >64MB 未触顶、创建即落库 Mods.sqlite、
--   跨进程冷启动 GetModGroups() 读回完整（三轮实测，见 AGENTS.md「ModGroup 组名存储实测定论」）。
-- 组名格式：[size_0][color:0,0,0,0][MPT_DS][fileName][key][len]数据
--   [size_0][color:0,0,0,0] 隐形前缀（字号0+全透明）：数据组在前端 Mods 界面组列表不可见
--   （1.67 [size_0] 前缀同款思路 + 透明色强化）；len=数据字符数，读时校验完整性；
--   单组名直存不切块（实测上限 >> 实际数据量）。
-- 干净组：建组前批量禁用全部已启用 mod（官方 DisableAllMods 模式）、建组后即恢复——
--   数据组不含任何 mod，玩家在前端误切到数据组不会改变 mod 启用状态。
-- 用法（同步执行，结果经回调返回）：
--   MPT_Storage_SaveData("MyMod", "Blacklist", t, function(ok) end);   -- 写：序列化→删旧组→建组
--   MPT_Storage_LoadData("MyMod", "Blacklist", function(t) end);       -- 读：t=数据表，无组/损坏=nil
--   MPT_Storage_DeleteFile("MyMod", function(found) end);              -- 删：删 MyMod 全部数据组
-- ============================================================================

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
end	-- 条目4.3预备 do 块结束（寄存器上限适配）

-- ############################################################################
-- 条目4.4：玩家标记管理（纯本地玩家档案：好友/一般/黑名单标记 + 记事本）
-- ============================================================================
-- 用法：左下角 BottomLeftButtonStack「玩家标记」按钮打开面板；左列 过滤/搜索/排序/列表/添加，
--   右列内联编辑选中记录（含详细描述记事本）。面板与弹窗布局见 StagingRoom.xml 条目4.4 注释区。
-- 定位：纯本地记事本，不读取当前房间实况、不做任何房间联动/警告（与用户确认的边界）。
-- 存储：严格走条目4.3预备内联副本的 MPT_Storage_SaveData/LoadData（MPT_DataStorage 格式），
--   ModGroup 组名 [size_0][color:0,0,0,0][MPT_DS][MPT_PlayerInfo][Players][len]... 承载；
--   每次打开面板真实读库，仅「保存」按钮建组落库；面板代码不直接碰 Modding 组管理 API。
-- 数据：g_PlayerMarkList = { { Id=主键(17位纯数字Steam/32位字符Epic), Name=昵称,
--   Tag=1好友/2一般/3黑名单, Brief=简要描述, Details={ {Text,Time=os.time()}, ... },
--   Modified=os.time() }, ... }；显示日期一律由时间戳现算（os.date），不冗余存储。
-- 编辑语义：右侧改动（含详情增删）先暂存内存，「保存」才写盘并刷新 Modified；
--   「取消」还原；切换玩家/关闭面板时有未保存改动先弹确认框。
-- ############################################################################

-- 寄存器上限适配：本分区块级 do...end 包裹（同条目4.3预备注释）
do
-- ============================================================================
-- 条目4.4：本地化文本预加载缓存（规范：分区头后集中预加载；XML String=/ToolTip= 不预加载）
-- ============================================================================
local PlayerMarkSortDescStr			: string = Locale.Lookup("LOC_MPT_PLAYERMARK_SORT_DESC");
local PlayerMarkSortAscStr			: string = Locale.Lookup("LOC_MPT_PLAYERMARK_SORT_ASC");
local PlayerMarkModifiedPrefixStr	: string = Locale.Lookup("LOC_MPT_PLAYERMARK_MODIFIED_PREFIX");
local PlayerMarkIdInvalidStr		: string = Locale.Lookup("LOC_MPT_PLAYERMARK_HINT_ID_INVALID");
local PlayerMarkNameEmptyStr		: string = Locale.Lookup("LOC_MPT_PLAYERMARK_HINT_NAME_EMPTY");
local PlayerMarkNoticeTitleStr		: string = Locale.Lookup("LOC_MPT_PLAYERMARK_NOTICE_TITLE");
local PlayerMarkExistsTitleStr		: string = Locale.Lookup("LOC_MPT_PLAYERMARK_EXISTS_TITLE");
local PlayerMarkExistsTextStr		: string = Locale.Lookup("LOC_MPT_PLAYERMARK_EXISTS_TEXT");
local PlayerMarkConfirmDeleteTitleStr	: string = Locale.Lookup("LOC_MPT_PLAYERMARK_CONFIRM_DELETE_TITLE");
local PlayerMarkConfirmDeleteTextStr	: string = Locale.Lookup("LOC_MPT_PLAYERMARK_CONFIRM_DELETE_TEXT");
local PlayerMarkConfirmDiscardTitleStr	: string = Locale.Lookup("LOC_MPT_PLAYERMARK_CONFIRM_DISCARD_TITLE");
local PlayerMarkConfirmDiscardTextStr	: string = Locale.Lookup("LOC_MPT_PLAYERMARK_CONFIRM_DISCARD_TEXT");
local PlayerMarkOkStr				: string = Locale.Lookup("LOC_OK");
local PlayerMarkCancelStr			: string = Locale.Lookup("LOC_CANCEL");
local PlayerMarkTagNameStrs			: table = {	-- 下标即 Tag：标签下拉项/按钮文本（复用过滤复选框文本 tag）
	Locale.Lookup("LOC_MPT_PLAYERMARK_FILTER_FRIEND"),
	Locale.Lookup("LOC_MPT_PLAYERMARK_FILTER_NORMAL"),
	Locale.Lookup("LOC_MPT_PLAYERMARK_FILTER_BLACK") };

-- ============================================================================
-- 常量与全局状态（全局而非 local：KeyUpHandler 等本文件前部代码要调用本分区函数；
--   且「声明点之前引用的 local 会解析为全局」为已踩坑，统一全局避免声明顺序问题）
-- ============================================================================
local PLAYERMARK_STORAGE_FILE : string = "MPT_PlayerInfo";	-- 数据组命名空间段（字母数字下划线）
local PLAYERMARK_STORAGE_KEY  : string = "Players";			-- 数据组键名段
local PLAYERMARK_TAG_ICONS : table = { "[ICON_OnlineGreenPingPip]", "[ICON_OnlineYellowPingPig]", "[ICON_OnlineRedPingPig]" };	-- 下标即 Tag：1好友 2一般 3黑名单（游戏真实图标名黄/红为 PingPig，已核实）；带方括号文本 tag，下拉按钮文本用
local PLAYERMARK_TAG_ICON_NAMES : table = { "OnlineGreenPingPip", "OnlineYellowPingPig", "OnlineRedPingPig" };	-- 下标即 Tag；列表行 Image:SetIcon 用（FontIcons.xml 的裸 Name——SetIcon/Icon= 内部自动拼 ICON_ 前缀，不可再带）

g_PlayerMarkList        = {};		-- 玩家记录数组（磁盘内容的工作副本）
g_PlayerMarkSelectedId  = nil;		-- 当前选中玩家 Id（nil=未选中）
g_PlayerMarkSortAsc     = false;	-- 排序方向：false=最新修改在前（默认）
g_PlayerMarkFilterTag   = { true, true, true };	-- 三个过滤复选框勾选态（下标即 Tag）
g_PlayerMarkSearchStr   = "";		-- 搜索框当前内容（已转小写）
g_PlayerMarkDirty       = false;	-- 右侧有未保存改动
g_PlayerMarkEditTag     = 2;		-- 右侧编辑暂存：标签类型
g_PlayerMarkWorkDetails = {};		-- 右侧编辑暂存：详细描述数组（保存时整体写回记录）
g_PlayerMarkPopupTag    = 2;		-- 添加弹窗暂存：标签类型（默认一般）
g_PlayerMarkLoading     = false;	-- 右侧编辑区装载中（屏蔽 SetText 触发的改动回调，防误标 dirty）

local m_playerMarkEntryIM  = InstanceManager:new("PlayerMarkEntryInstance", "EntryRoot", Controls.PlayerMarkListStack);
local m_playerMarkDetailIM = InstanceManager:new("PlayerMarkDetailEntryInstance", "DetailRoot", Controls.PlayerMarkDetailStack);
local m_kPlayerMarkDialog  = PopupDialog:new("MPT_PlayerMark");	-- 本功能专用确认/提示弹窗（与房间 m_kPopupDialog 互不干扰）
local g_playerMarkEntryIds : table = {};	-- 左列实例序号 -> 玩家 Id（点击行时反查，列表过滤/排序后下标不稳定）

-- ============================================================================
-- 内部：PlayerMarkSetTagPullDownText(pd, tag)
-- 设置标签下拉按钮文本（图标+名称）；右侧编辑区与添加弹窗两个下拉共用。
-- ============================================================================
local function PlayerMarkSetTagPullDownText(pd, tag : number)
	tag = tag or 2;
	pd:GetButton():SetText(PLAYERMARK_TAG_ICONS[tag] .. " " .. PlayerMarkTagNameStrs[tag]);
end

-- ============================================================================
-- 内部：PlayerMarkRefreshTagPullDown() / PlayerMarkRefreshPopupTagPullDown()
-- 按当前暂存标签刷新右侧编辑区 / 添加弹窗的标签下拉按钮文本。
-- ============================================================================
local function PlayerMarkRefreshTagPullDown()
	PlayerMarkSetTagPullDownText(Controls.PlayerMarkTagPullDown, g_PlayerMarkEditTag);
end
local function PlayerMarkRefreshPopupTagPullDown()
	PlayerMarkSetTagPullDownText(Controls.PlayerMarkPopupTagPullDown, g_PlayerMarkPopupTag);
end

-- ============================================================================
-- 内部：PlayerMarkUpdateSaveButton()
-- 按 dirty/选中态刷新「保存」按钮可用性：无未保存改动或无选中记录时禁用（初始即禁用）。
-- ============================================================================
local function PlayerMarkUpdateSaveButton()
	Controls.PlayerMarkSaveButton:SetDisabled(not g_PlayerMarkDirty or MPT_PlayerMark_GetSelected() == nil);
end

-- ============================================================================
-- 内部：PlayerMarkOnEditorFieldChanged
-- 右侧编辑区文本改动回调：装载期（g_PlayerMarkLoading）屏蔽，其余置 dirty 并放行保存按钮。
-- ============================================================================
local function PlayerMarkOnEditorFieldChanged()
	if g_PlayerMarkLoading then return; end
	g_PlayerMarkDirty = true;
	PlayerMarkUpdateSaveButton();
end

-- ============================================================================
-- MPT_PlayerMark_FormatDate(time)：时间戳转显示日期串（YYYY-MM-DD）。
-- ============================================================================
function MPT_PlayerMark_FormatDate(time : number)
	return os.date("%Y-%m-%d", time or 0);
end

-- ============================================================================
-- MPT_PlayerMark_FormatDateTime(time)：时间戳转 "YYYY-MM-DD HH:MM:SS"（详细描述条目用，精确到秒）。
-- ============================================================================
function MPT_PlayerMark_FormatDateTime(time : number)
	return os.date("%Y-%m-%d %H:%M:%S", time or 0);
end

-- ============================================================================
-- MPT_PlayerMark_IsValidId(id)：ID 校验——17 位纯数字（Steam）或 32 位字符（Epic）。
-- ============================================================================
function MPT_PlayerMark_IsValidId(id)
	if type(id) ~= "string" then return false; end
	if #id == 17 then return string.match(id, "^%d+$") ~= nil; end
	if #id == 32 then return string.match(id, "^%w+$") ~= nil; end
	return false;
end

-- ============================================================================
-- MPT_PlayerMark_IsSteamId(id)：是否 17 位纯数字 SteamID64（Steam 主页按钮可用性判定；Epic 32 位 ID 无 Steam 主页）。
-- ============================================================================
function MPT_PlayerMark_IsSteamId(id)
	return type(id) == "string" and #id == 17 and string.match(id, "^%d+$") ~= nil;
end

-- ============================================================================
-- MPT_PlayerMark_FindIndex(id)：按主键查记录下标，未找到返回 nil。
-- ============================================================================
function MPT_PlayerMark_FindIndex(id)
	for i, rec in ipairs(g_PlayerMarkList) do
		if rec.Id == id then return i; end
	end
	return nil;
end

-- ============================================================================
-- MPT_PlayerMark_GetSelected()：取当前选中记录（无选中/记录已被删返回 nil）。
-- ============================================================================
function MPT_PlayerMark_GetSelected()
	if g_PlayerMarkSelectedId == nil then return nil; end
	local idx = MPT_PlayerMark_FindIndex(g_PlayerMarkSelectedId);
	if idx == nil then return nil; end
	return g_PlayerMarkList[idx];
end

-- ============================================================================
-- MPT_PlayerMark_Confirm(titleStr, textStr, onConfirm)：通用确认框（确定/取消）。
-- ============================================================================
function MPT_PlayerMark_Confirm(titleStr : string, textStr : string, onConfirm)
	m_kPlayerMarkDialog:Close();
	m_kPlayerMarkDialog:AddTitle(titleStr);
	m_kPlayerMarkDialog:AddText(textStr);
	m_kPlayerMarkDialog:AddButton(PlayerMarkOkStr, function() if onConfirm ~= nil then onConfirm(); end end);
	m_kPlayerMarkDialog:AddButton(PlayerMarkCancelStr);
	m_kPlayerMarkDialog:Open();
end

-- ============================================================================
-- MPT_PlayerMark_LoadFromDisk(callback) / MPT_PlayerMark_SaveToDisk(callback)
-- 条目4.3 存储管线包装：真实读盘刷新 g_PlayerMarkList / 把工作副本落盘。
-- ============================================================================
function MPT_PlayerMark_LoadFromDisk(callback)
	MPT_Storage_LoadData(PLAYERMARK_STORAGE_FILE, PLAYERMARK_STORAGE_KEY, function(data)
		g_PlayerMarkList = (type(data) == "table") and data or {};
		if callback ~= nil then callback(); end
	end);
end

function MPT_PlayerMark_SaveToDisk(callback)
	MPT_Storage_SaveData(PLAYERMARK_STORAGE_FILE, PLAYERMARK_STORAGE_KEY, g_PlayerMarkList, callback);
end

-- ============================================================================
-- MPT_PlayerMark_RebuildDetails()：由暂存数组 g_PlayerMarkWorkDetails 重建右侧详情列表。
--   倒序遍历显示（最新添加在数组尾、显示在最上）；删除按钮 SetVoid1 仍传原数组下标。
-- ============================================================================
function MPT_PlayerMark_RebuildDetails()
	m_playerMarkDetailIM:ResetInstances();
	local n : number = #g_PlayerMarkWorkDetails;
	for row = 1, n do
		local i : number = n - row + 1;
		local detail : table = g_PlayerMarkWorkDetails[i];
		local inst = m_playerMarkDetailIM:GetInstance();
		inst.DetailDateLabel:SetText(MPT_PlayerMark_FormatDateTime(detail.Time));
		inst.DetailTextLabel:SetText(detail.Text or "");
		inst.DetailTextLabel:SetToolTipString(detail.Text or "");
		-- 行高自适应（同更新公告条目3.5）：文本上偏移26 + 文本高 + 底边距14
		inst.DetailRoot:SetSizeY(inst.DetailTextLabel:GetSizeY() + 40);
		inst.DetailDeleteButton:SetVoid1(i);
		inst.DetailDeleteButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_OnDeleteDetail);
	end
	Controls.PlayerMarkDetailStack:CalculateSize();
	Controls.PlayerMarkDetailScrollPanel:CalculateSize();
end

-- ============================================================================
-- MPT_PlayerMark_RebuildList()：按 过滤复选框 + 搜索子串 + 日期排序 重建左列。
--   搜索同时匹配昵称与 NetworkIdentifier（string.find 纯文本模式，ASCII 大小写不敏感）；
--   排序按 Modified 时间戳，g_PlayerMarkSortAsc 控向（默认最新在前），等值按昵称字典序。
-- ============================================================================
function MPT_PlayerMark_RebuildList()
	local filtered : table = {};
	for _, rec in ipairs(g_PlayerMarkList) do
		if g_PlayerMarkFilterTag[rec.Tag or 2] then
			local matchSearch : boolean = true;
			if g_PlayerMarkSearchStr ~= "" then
				matchSearch = string.find(string.lower(rec.Name or ""), g_PlayerMarkSearchStr, 1, true) ~= nil
					or string.find(string.lower(rec.Id or ""), g_PlayerMarkSearchStr, 1, true) ~= nil;
			end
			if matchSearch then
				table.insert(filtered, rec);
			end
		end
	end
	table.sort(filtered, function(a, b)
		local ma : number = a.Modified or 0;
		local mb : number = b.Modified or 0;
		if ma == mb then return (a.Name or "") < (b.Name or ""); end
		if g_PlayerMarkSortAsc then return ma < mb; end
		return ma > mb;
	end);

	m_playerMarkEntryIM:ResetInstances();
	g_playerMarkEntryIds = {};
	for i, rec in ipairs(filtered) do
		local inst = m_playerMarkEntryIM:GetInstance();
		g_playerMarkEntryIds[i] = rec.Id;
		inst.TagIconLabel:SetIcon(PLAYERMARK_TAG_ICON_NAMES[rec.Tag or 2], 22);
		inst.NameLabel:SetText(rec.Name or "");
		-- 行按钮 tooltip：[ICON_YOU]+网络ID，空两行后接简要描述（无简要描述时只显示 ID）
		local tip : string = "[ICON_YOU]" .. (rec.Id or "");
		if rec.Brief ~= nil and rec.Brief ~= "" then
			tip = tip .. "[NEWLINE][NEWLINE]" .. rec.Brief;
		end
		inst.RowButton:SetToolTipString(tip);
		inst.RowButton:SetVoid1(i);
		inst.RowButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_OnEntryClick);
		inst.SelectedFrame:SetHide(rec.Id ~= g_PlayerMarkSelectedId);
	end
	Controls.PlayerMarkListEmptyLabel:SetHide(#filtered > 0);
	Controls.PlayerMarkListStack:CalculateSize();
	Controls.PlayerMarkListScrollPanel:CalculateSize();
end

-- ============================================================================
-- MPT_PlayerMark_RefreshEditor()：把选中记录载入右侧编辑区；无选中则显示空态提示。
--   装载期间置 g_PlayerMarkLoading 屏蔽文本改动回调（防 SetText 误标 dirty）。
-- ============================================================================
function MPT_PlayerMark_RefreshEditor()
	local rec = MPT_PlayerMark_GetSelected();
	Controls.PlayerMarkEmptyHint:SetHide(rec ~= nil);
	Controls.PlayerMarkEditor:SetHide(rec == nil);
	g_PlayerMarkLoading = true;
	if rec == nil then
		g_PlayerMarkDirty = false;
		g_PlayerMarkLoading = false;
		PlayerMarkUpdateSaveButton();
		return;
	end
	Controls.PlayerMarkNameEdit:SetText(rec.Name or "");
	Controls.PlayerMarkHeaderName:SetText(rec.Name or "");
	Controls.PlayerMarkHeaderId:SetText(rec.Id);
	-- Steam 主页按钮仅对 17 位纯数字 ID（SteamID64）可用；Epic 32 位 ID 禁用
	Controls.PlayerMarkSteamButton:SetDisabled(not MPT_PlayerMark_IsSteamId(rec.Id));
	g_PlayerMarkEditTag = rec.Tag or 2;
	PlayerMarkRefreshTagPullDown();
	Controls.PlayerMarkBriefEdit:SetText(rec.Brief or "");
	Controls.PlayerMarkModifiedLabel:SetText(PlayerMarkModifiedPrefixStr .. MPT_PlayerMark_FormatDate(rec.Modified));
	-- 详情编辑走暂存副本（单层深拷贝），保存时才整体写回记录
	g_PlayerMarkWorkDetails = {};
	for i, detail in ipairs(rec.Details or {}) do
		g_PlayerMarkWorkDetails[i] = { Text = detail.Text, Time = detail.Time };
	end
	g_PlayerMarkLoading = false;
	g_PlayerMarkDirty = false;
	MPT_PlayerMark_RebuildDetails();
	PlayerMarkUpdateSaveButton();
end

-- ============================================================================
-- MPT_PlayerMark_Select(id)：选中玩家并载入编辑区；有未保存改动先弹确认（放弃/取消）。
-- ============================================================================
function MPT_PlayerMark_Select(id)
	if id == g_PlayerMarkSelectedId then return; end
	if g_PlayerMarkDirty and g_PlayerMarkSelectedId ~= nil then
		MPT_PlayerMark_Confirm(PlayerMarkConfirmDiscardTitleStr, PlayerMarkConfirmDiscardTextStr, function()
			g_PlayerMarkDirty = false;
			MPT_PlayerMark_Select(id);
		end);
		return;
	end
	g_PlayerMarkSelectedId = id;
	MPT_PlayerMark_RefreshEditor();
	MPT_PlayerMark_RebuildList();	-- 重刷列表以更新选中行金色外框
	UI.PlaySound("Play_UI_Click");
end

-- ============================================================================
-- 左列行点击：实例序号反查玩家 Id 后选中。
-- ============================================================================
function MPT_PlayerMark_OnEntryClick(index : number)
	local id = g_playerMarkEntryIds[index];
	if id ~= nil then
		MPT_PlayerMark_Select(id);
	end
end

-- ============================================================================
-- 详情行删除 / 详情输入行添加（均为暂存改动：置 dirty，保存生效/取消还原，不弹确认）。
-- ============================================================================
function MPT_PlayerMark_OnDeleteDetail(index : number)
	if index == nil or index < 1 or index > #g_PlayerMarkWorkDetails then return; end
	table.remove(g_PlayerMarkWorkDetails, index);
	g_PlayerMarkDirty = true;
	MPT_PlayerMark_RebuildDetails();
	PlayerMarkUpdateSaveButton();
end

function MPT_PlayerMark_OnAddDetail()
	local text = Controls.PlayerMarkDetailEdit:GetText();
	if text == nil or text == "" then return; end
	table.insert(g_PlayerMarkWorkDetails, { Text = text, Time = os.time() });
	Controls.PlayerMarkDetailEdit:SetText("");
	Controls.PlayerMarkDetailEdit:TakeFocus();
	g_PlayerMarkDirty = true;
	MPT_PlayerMark_RebuildDetails();
	PlayerMarkUpdateSaveButton();
end

-- ============================================================================
-- MPT_PlayerMark_ApplySave()：保存按钮——昵称非空校验后写回记录（Modified 刷新为当前
--   时间戳），落盘成功才重建列表/重载编辑区；保存后 dirty 清零、按钮回禁用态（防连点重复落盘）。
-- ============================================================================
function MPT_PlayerMark_ApplySave()
	local rec = MPT_PlayerMark_GetSelected();
	if rec == nil then return; end
	local name = Controls.PlayerMarkNameEdit:GetText();
	if name == nil or name == "" then
		m_kPlayerMarkDialog:Close();
		m_kPlayerMarkDialog:AddTitle(PlayerMarkNoticeTitleStr);
		m_kPlayerMarkDialog:AddText(PlayerMarkNameEmptyStr);
		m_kPlayerMarkDialog:AddButton(PlayerMarkOkStr);
		m_kPlayerMarkDialog:Open();
		return;
	end
	rec.Name = name;
	rec.Brief = Controls.PlayerMarkBriefEdit:GetText() or "";
	rec.Tag = g_PlayerMarkEditTag;
	rec.Details = g_PlayerMarkWorkDetails;
	rec.Modified = os.time();
	g_PlayerMarkDirty = false;
	PlayerMarkUpdateSaveButton();
	MPT_PlayerMark_SaveToDisk(function(ok)
		if ok then
			UI.PlaySound("Play_UI_Click");
		else
			print("MPT_PlayerMark: 保存失败（存储管线回调 false）");
		end
		MPT_PlayerMark_RebuildList();
		MPT_PlayerMark_RefreshEditor();
	end);
end

-- ============================================================================
-- MPT_PlayerMark_CancelEdit()：取消按钮——重新载入选中记录即还原全部暂存改动。
-- ============================================================================
function MPT_PlayerMark_CancelEdit()
	if MPT_PlayerMark_GetSelected() == nil then return; end
	MPT_PlayerMark_RefreshEditor();
	UI.PlaySound("Play_UI_Click");
end

-- ============================================================================
-- MPT_PlayerMark_DeleteSelected()：删除玩家按钮——弹确认框；确认后立即从存档抹除
--   （不走保存按钮、不可经取消还原），落盘后重建并回到未选中态。
-- ============================================================================
function MPT_PlayerMark_DeleteSelected()
	local rec = MPT_PlayerMark_GetSelected();
	if rec == nil then return; end
	MPT_PlayerMark_Confirm(PlayerMarkConfirmDeleteTitleStr, PlayerMarkConfirmDeleteTextStr, function()
		local idx = MPT_PlayerMark_FindIndex(g_PlayerMarkSelectedId);
		if idx ~= nil then
			table.remove(g_PlayerMarkList, idx);
		end
		g_PlayerMarkSelectedId = nil;
		g_PlayerMarkDirty = false;
		MPT_PlayerMark_SaveToDisk(function(ok)
			if not ok then
				print("MPT_PlayerMark: 删除落盘失败（存储管线回调 false）");
			end
			MPT_PlayerMark_RebuildList();
			MPT_PlayerMark_RefreshEditor();
		end);
	end);
end

-- ============================================================================
-- 添加弹窗：打开（清空并默认「一般」标签）/ 关闭 / 字段改动实时校验 / 创建。
-- 创建时重复 ID 不建新档：转为选中已有记录并弹提示。
-- ============================================================================
-- 可选 presetId/presetName：预填网络ID与昵称（准备房间玩家名按钮联动，回调 MPT_PlayerMark_OnSlotNameClick 在 GetPlayerEntry 内注册）
function MPT_PlayerMark_OpenAddPopup(presetId, presetName)
	Controls.PlayerMarkPopupIdEdit:SetText(presetId or "");
	Controls.PlayerMarkPopupNameEdit:SetText(presetName or "");
	Controls.PlayerMarkPopupBriefEdit:SetText("");
	g_PlayerMarkPopupTag = 2;
	PlayerMarkRefreshPopupTagPullDown();
	Controls.PlayerMarkPopupCreateButton:SetDisabled(true);
	Controls.PlayerMarkEditPopup:SetHide(false);
	Controls.PlayerMarkPopupIdEdit:TakeFocus();
	MPT_PlayerMark_OnPopupFieldChanged();	-- 预填后按内容刷新创建按钮可用态（SetText 不一定触发 StringChanged 回调，手动兜底）
	UI.PlaySound("Play_UI_Click");
end

-- ============================================================================
-- MPT_PlayerMark_OnSlotNameClick(playerID)：准备房间玩家槽位「玩家名」热区按钮点击——
--   取该槽位网络ID与昵称，打开添加弹窗并预填；自己、AI/开放等无网络ID槽位忽略。
-- ============================================================================
function MPT_PlayerMark_OnSlotNameClick(playerID : number)
	if playerID == Network.GetLocalPlayerID() then return; end	-- 不标记自己
	local pConfig = PlayerConfigurations[playerID];
	if pConfig == nil then return; end
	local nid = pConfig:GetNetworkIdentifer();
	if nid == nil or nid == "" then return; end
	MPT_PlayerMark_OpenAddPopup(nid, Locale.Lookup(pConfig:GetPlayerName()));
end

function MPT_PlayerMark_CloseAddPopup()
	Controls.PlayerMarkEditPopup:SetHide(true);
end

function MPT_PlayerMark_OnPopupFieldChanged()
	local id = Controls.PlayerMarkPopupIdEdit:GetText();
	local name = Controls.PlayerMarkPopupNameEdit:GetText();
	local idValid : boolean = MPT_PlayerMark_IsValidId(id);
	Controls.PlayerMarkPopupCreateButton:SetDisabled(not idValid or name == nil or name == "");
	-- Steam 主页按钮仅对 17 位纯数字 ID 可用（Epic 32 位禁用），随输入实时刷新
	Controls.PlayerMarkPopupSteamButton:SetDisabled(not MPT_PlayerMark_IsSteamId(id));
	-- 校验提示改为「创建」按钮 tooltip（禁用态按钮悬停仍显示）
	if id ~= nil and id ~= "" and not idValid then
		Controls.PlayerMarkPopupCreateButton:SetToolTipString(PlayerMarkIdInvalidStr);
	elseif name == nil or name == "" then
		Controls.PlayerMarkPopupCreateButton:SetToolTipString(PlayerMarkNameEmptyStr);
	else
		Controls.PlayerMarkPopupCreateButton:SetToolTipString("");
	end
end

function MPT_PlayerMark_CreateFromPopup()
	local id = Controls.PlayerMarkPopupIdEdit:GetText();
	local name = Controls.PlayerMarkPopupNameEdit:GetText();
	if not MPT_PlayerMark_IsValidId(id) or name == nil or name == "" then return; end
	MPT_PlayerMark_CloseAddPopup();
	if MPT_PlayerMark_FindIndex(id) ~= nil then
		-- 重复 ID：转为编辑已有记录并提示
		MPT_PlayerMark_Select(id);
		m_kPlayerMarkDialog:Close();
		m_kPlayerMarkDialog:AddTitle(PlayerMarkExistsTitleStr);
		m_kPlayerMarkDialog:AddText(PlayerMarkExistsTextStr);
		m_kPlayerMarkDialog:AddButton(PlayerMarkOkStr);
		m_kPlayerMarkDialog:Open();
		return;
	end
	table.insert(g_PlayerMarkList, {
		Id = id,
		Name = name,
		Tag = g_PlayerMarkPopupTag,
		Brief = Controls.PlayerMarkPopupBriefEdit:GetText() or "",
		Details = {},
		Modified = os.time(),
	});
	MPT_PlayerMark_SaveToDisk(function(ok)
		if ok then
			MPT_PlayerMark_RebuildList();
			MPT_PlayerMark_Select(id);
		else
			print("MPT_PlayerMark: 创建落盘失败（存储管线回调 false）");
		end
	end);
end

-- ============================================================================
-- MPT_PlayerMark_Open() / MPT_PlayerMark_Close()
-- 打开：显示遮挡层与面板后真实读盘，回调到达后重建列表/编辑区（面板已关也无碍）。
-- 关闭：先收添加弹窗；有未保存改动先弹确认（确认后递归关闭）；幂等。
-- ============================================================================
function MPT_PlayerMark_Open()
	Controls.PlayerMarkModalBlocker:SetHide(false);
	Controls.PlayerMarkPanel:SetHide(false);
	UI.PlaySound("UI_Screen_Open");
	MPT_PlayerMark_LoadFromDisk(function()
		MPT_PlayerMark_RebuildList();
		MPT_PlayerMark_RefreshEditor();
	end);
end

function MPT_PlayerMark_Close()
	if Controls.PlayerMarkPanel:IsHidden() then
		return;
	end
	if not Controls.PlayerMarkEditPopup:IsHidden() then
		MPT_PlayerMark_CloseAddPopup();
	end
	if g_PlayerMarkDirty then
		MPT_PlayerMark_Confirm(PlayerMarkConfirmDiscardTitleStr, PlayerMarkConfirmDiscardTextStr, function()
			g_PlayerMarkDirty = false;
			MPT_PlayerMark_Close();
		end);
		return;
	end
	Controls.PlayerMarkPanel:SetHide(true);
	Controls.PlayerMarkModalBlocker:SetHide(true);
	UI.PlaySound("UI_Screen_Close");
end

-- ============================================================================
-- MPT_PlayerMark_ResetOnExit()：退出准备房间时硬重置本功能显示状态（供 OnHandleExitRequest 调用）。
--   Lua 状态跨房间存续，不重置会残留进新房间。不弹任何确认：未保存改动直接丢弃；
--   面板/添加弹窗/确认对话框硬关闭；选中、搜索、过滤、排序、编辑暂存全部回到初始默认。
--   控件勾选/文案同步复位（控件状态同样跨房间存续）；列表与编辑区不必重建，下次打开
--   MPT_PlayerMark_Open 会 LoadFromDisk 后重建。
-- ============================================================================
function MPT_PlayerMark_ResetOnExit()
	g_PlayerMarkDirty = false;				-- 丢弃未保存改动（退房不再弹放弃确认）
	m_kPlayerMarkDialog:Close();			-- 确认/提示对话框一并硬关闭
	Controls.PlayerMarkEditPopup:SetHide(true);
	Controls.PlayerMarkPanel:SetHide(true);
	Controls.PlayerMarkModalBlocker:SetHide(true);
	-- 显示状态归位：取消选中、清空搜索、过滤全勾选、排序回默认（最新修改在前）
	g_PlayerMarkSelectedId = nil;
	g_PlayerMarkSearchStr = "";
	g_PlayerMarkFilterTag = { true, true, true };
	g_PlayerMarkSortAsc = false;
	g_PlayerMarkEditTag = 2;
	g_PlayerMarkWorkDetails = {};
	g_PlayerMarkPopupTag = 2;
	Controls.PlayerMarkSearchEditBox:SetText("");
	Controls.PlayerMarkSearchPlaceholder:SetHide(false);
	Controls.PlayerMarkFilterFriend:SetCheck(true);
	Controls.PlayerMarkFilterNormal:SetCheck(true);
	Controls.PlayerMarkFilterBlack:SetCheck(true);
	Controls.PlayerMarkSortButton:SetText(PlayerMarkSortDescStr);
end

-- ============================================================================
-- 条目4.4：控件注册（分区自包含初始化；本文件每前端状态只执行一次，无需守卫。
--   复选框默认全勾选；排序按钮文案默认「最新修改在前」；搜索占位文本按焦点/内容显隐）
-- ============================================================================
Controls.PlayerMarkButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_Open);
Controls.PlayerMarkButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
Controls.PlayerMarkCloseButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_Close);
Controls.PlayerMarkModalBlocker:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_Close);

-- 左列：过滤复选框 / 排序切换 / 搜索框
local function PlayerMarkOnFilterChanged()
	g_PlayerMarkFilterTag[1] = Controls.PlayerMarkFilterFriend:IsChecked();
	g_PlayerMarkFilterTag[2] = Controls.PlayerMarkFilterNormal:IsChecked();
	g_PlayerMarkFilterTag[3] = Controls.PlayerMarkFilterBlack:IsChecked();
	MPT_PlayerMark_RebuildList();
end
Controls.PlayerMarkFilterFriend:SetCheck(true);
Controls.PlayerMarkFilterNormal:SetCheck(true);
Controls.PlayerMarkFilterBlack:SetCheck(true);
Controls.PlayerMarkFilterFriend:RegisterCallback(Mouse.eLClick, PlayerMarkOnFilterChanged);
Controls.PlayerMarkFilterNormal:RegisterCallback(Mouse.eLClick, PlayerMarkOnFilterChanged);
Controls.PlayerMarkFilterBlack:RegisterCallback(Mouse.eLClick, PlayerMarkOnFilterChanged);
Controls.PlayerMarkSortButton:SetText(PlayerMarkSortDescStr);
Controls.PlayerMarkSortButton:RegisterCallback(Mouse.eLClick, function()
	g_PlayerMarkSortAsc = not g_PlayerMarkSortAsc;
	Controls.PlayerMarkSortButton:SetText(g_PlayerMarkSortAsc and PlayerMarkSortAscStr or PlayerMarkSortDescStr);
	MPT_PlayerMark_RebuildList();
end);
Controls.PlayerMarkSearchEditBox:RegisterStringChangedCallback(function()
	g_PlayerMarkSearchStr = string.lower(Controls.PlayerMarkSearchEditBox:GetText() or "");
	Controls.PlayerMarkSearchPlaceholder:SetHide(g_PlayerMarkSearchStr ~= "");
	MPT_PlayerMark_RebuildList();
end);
Controls.PlayerMarkSearchEditBox:RegisterHasFocusCallback(function()
	Controls.PlayerMarkSearchPlaceholder:SetHide(true);
end);
Controls.PlayerMarkSearchEditBox:RegisterLostFocusCallback(function()
	Controls.PlayerMarkSearchPlaceholder:SetHide((Controls.PlayerMarkSearchEditBox:GetText() or "") ~= "");
end);

-- 左列底部添加按钮与添加弹窗（包一层匿名函数：RegisterCallback 会以 void1/void2 默认 0,0 作参数直调，会把两个 0 预填进输入框）
Controls.PlayerMarkAddButton:RegisterCallback(Mouse.eLClick, function() MPT_PlayerMark_OpenAddPopup(); end);
Controls.PlayerMarkPopupCancelButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_CloseAddPopup);
Controls.PlayerMarkPopupCreateButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_CreateFromPopup);
-- 弹窗 Steam 主页按钮：以输入框当前 ID 打开 Steam 个人主页（禁用态由 OnPopupFieldChanged 控制，此处再防御一次）
Controls.PlayerMarkPopupSteamButton:RegisterCallback(Mouse.eLClick, function()
	local id = Controls.PlayerMarkPopupIdEdit:GetText();
	if MPT_PlayerMark_IsSteamId(id) then
		Steam.ActivateGameOverlayToUrl("https://steamcommunity.com/profiles/" .. id);
	end
end);
Controls.PlayerMarkPopupIdEdit:RegisterStringChangedCallback(MPT_PlayerMark_OnPopupFieldChanged);
Controls.PlayerMarkPopupNameEdit:RegisterStringChangedCallback(MPT_PlayerMark_OnPopupFieldChanged);
-- 添加弹窗标签下拉：构建三项（图标+名称，同右侧下拉范式），选中即暂存 g_PlayerMarkPopupTag
Controls.PlayerMarkPopupTagPullDown:ClearEntries();
for tag = 1, 3 do
	local entry : table = {};
	Controls.PlayerMarkPopupTagPullDown:BuildEntry("InstanceOne", entry);
	entry.Button:SetText(PLAYERMARK_TAG_ICONS[tag] .. " " .. PlayerMarkTagNameStrs[tag]);
	entry.Button:RegisterCallback(Mouse.eLClick, function()
		g_PlayerMarkPopupTag = tag;
		PlayerMarkRefreshPopupTagPullDown();
	end);
end
Controls.PlayerMarkPopupTagPullDown:CalculateInternals();

-- 右列编辑区：文本改动标 dirty（装载期屏蔽）；标签类型下拉；详情输入回车=添加；保存/取消/删除
Controls.PlayerMarkNameEdit:RegisterStringChangedCallback(PlayerMarkOnEditorFieldChanged);
Controls.PlayerMarkBriefEdit:RegisterStringChangedCallback(PlayerMarkOnEditorFieldChanged);
-- 标签类型下拉：构建三项（图标+名称，范式同 Mods.lua 排序下拉），选中即暂存 g_PlayerMarkEditTag 并标 dirty
Controls.PlayerMarkTagPullDown:ClearEntries();
for tag = 1, 3 do
	local entry : table = {};
	Controls.PlayerMarkTagPullDown:BuildEntry("InstanceOne", entry);
	entry.Button:SetText(PLAYERMARK_TAG_ICONS[tag] .. " " .. PlayerMarkTagNameStrs[tag]);
	entry.Button:RegisterCallback(Mouse.eLClick, function()
		g_PlayerMarkEditTag = tag;
		PlayerMarkRefreshTagPullDown();
		g_PlayerMarkDirty = true;
		PlayerMarkUpdateSaveButton();
	end);
end
Controls.PlayerMarkTagPullDown:CalculateInternals();
PlayerMarkRefreshTagPullDown();
Controls.PlayerMarkDetailEdit:RegisterCommitCallback(MPT_PlayerMark_OnAddDetail);
Controls.PlayerMarkAddDetailButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_OnAddDetail);
Controls.PlayerMarkSaveButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_ApplySave);
Controls.PlayerMarkCancelButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_CancelEdit);
Controls.PlayerMarkDeleteButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_DeleteSelected);
-- Steam 主页按钮：打开选中玩家的 Steam 个人主页（Overlay 内置浏览器，同条目4.2 跳工坊）；禁用态由 RefreshEditor 按 ID 格式控制
Controls.PlayerMarkSteamButton:RegisterCallback(Mouse.eLClick, function()
	local rec = MPT_PlayerMark_GetSelected();
	if rec ~= nil and rec.Id ~= nil then
		Steam.ActivateGameOverlayToUrl("https://steamcommunity.com/profiles/" .. rec.Id);
	end
end);
end	-- 条目4.4 do 块结束（寄存器上限适配）


-- ############################################################################
-- 条目4.5：图标查看器（移植 Easy Icon Viewer 工坊 3173843667，本作者旧作，并优化）
-- ============================================================================
-- 用法：左下角 BottomLeftButtonStack「查看器」单按钮打开融合面板（回到上次停留页签，
-- 页签切换见条目4.6 分区末尾融合块）；点击图标复制 [ICON_x] 文本到剪贴板；搜索框按图标名
--   子串过滤（大小写不敏感）；「按尺寸排序」开关按图标宽度重排。
--   关闭：X 按钮 / 点击面板外 / ESC；退出房间自动关闭（OnHandleExitRequest）。
-- 数据源：前端配置库 MPT_IconCollection 表（FrontEnd/IconViewer/IconViewer_Data.sql，
--   5056 行；DB.ConfigurationQuery 为前端配置库句柄，同条目3.5 公告读取先例），
--   本分区顶层一次性预加载进 g_IconViewerData（纯数据，不建实例）。
-- 相对原作的优化：
--   1) 构建方式同原作：首开面板一次性同步构建全部实例（逐帧分批构建实测更卡，已弃用）；
--      图标宽度在构建实例时顺带测量存回数据行，免掉原作独立的 5056 次测量循环；
--   2) 重建走 InstanceManager 实例池（ResetInstances 释放复用），二次重建开销极小；
--   3) pairs 改 ipairs；新增搜索过滤；布局与横向滚动保持原作观感（浅色背景开关已按需求移除）。
-- ############################################################################

-- 寄存器上限适配：本分区块级 do...end 包裹（同条目4.3预备注释）
do
-- ============================================================================
-- 条目4.5：本地化文本预加载缓存（规范：分区头后集中预加载；XML String=/ToolTip= 不预加载；
--   带数字文本拆无参数前缀/后缀 tag，缓存后运行时用 .. 拼接）
-- ============================================================================
local IconViewerCountPrefixStr		: string = Locale.Lookup("LOC_MPT_ICONVIEWER_COUNT_PREFIX");
local IconViewerCountSuffixStr		: string = Locale.Lookup("LOC_MPT_ICONVIEWER_COUNT_SUFFIX");

-- ============================================================================
-- 常量与全局状态（全局而非 local：KeyUpHandler/OnHandleExitRequest 等本文件前部代码
--   要调用本分区函数；且「声明点之前引用的 local 会解析为全局」为已踩坑，统一全局避免声明顺序问题）
-- ============================================================================
g_IconViewerData           = {};		-- 预加载全量数据：{ { IconString="[ICON_X]", Size=测得宽度或nil }, ... }（[ICON_ICON 前缀组排末尾）
g_IconViewerSearchStr      = "";		-- 搜索框当前内容（已转小写）
g_IconViewerSortBySize     = false;		-- 按尺寸排序开关
g_IconViewerShownList      = nil;		-- 当前展示的数据行数组（点击图标反查用；nil=尚未构建）
g_IconViewerBuiltOnce      = false;		-- 无过滤全量构建已完成（全部图标宽度测量齐备，尺寸排序可用）

local m_iconViewerDarkIM  = InstanceManager:new("IconViewerDarkInstance", "ButtonRoot", Controls.IconViewerStack);

-- ============================================================================
-- 内部：MPT_IconViewer_Preload()
-- 顶层一次性预加载 MPT_IconCollection 全表到 g_IconViewerData（纯数据，不建实例）。
-- 顺序语义同原作 InitializeData：[ICON_ICON 前缀组移到末尾，其余保持数据库顺序。
-- ============================================================================
local function MPT_IconViewer_Preload()
	local iconRows = DB.ConfigurationQuery("SELECT IconString FROM MPT_IconCollection");
	if iconRows == nil then
		return;
	end
	local normalIcons    : table = {};
	local iconIconGroup  : table = {};	-- [ICON_ICON 前缀组（原作语义：排末尾）
	for i, row in ipairs(iconRows) do
		local iconString : string = row.IconString;
		if iconString ~= nil and iconString ~= "" then
			if string.upper(string.sub(iconString, 2, 10)) == "ICON_ICON" then
				table.insert(iconIconGroup, { IconString = iconString });
			else
				table.insert(normalIcons, { IconString = iconString });
			end
		end
	end
	for i, data in ipairs(iconIconGroup) do
		table.insert(normalIcons, data);
	end
	g_IconViewerData = normalIcons;
end
MPT_IconViewer_Preload();

-- ============================================================================
-- 内部：IconViewerComputeBuildList()
-- 按当前搜索串过滤、按当前排序开关排序，返回待构建的数据行数组。
-- 尺寸排序需首轮无过滤构建完成（全部宽度测量齐备）后才应用，否则保持预加载顺序。
-- ============================================================================
local function IconViewerComputeBuildList()
	local buildList : table = {};
	for i, data in ipairs(g_IconViewerData) do
		if g_IconViewerSearchStr == ""
			or string.find(string.lower(data.IconString), g_IconViewerSearchStr, 1, true) ~= nil then
			table.insert(buildList, data);
		end
	end
	if g_IconViewerSortBySize and g_IconViewerBuiltOnce then
		table.sort(buildList, function(a, b)
			if a.Size == b.Size then
				return a.IconString < b.IconString;
			end
			return (a.Size or 0) < (b.Size or 0);
		end);
	end
	return buildList;
end

-- ============================================================================
-- 内部：IconViewerUpdateStatus()
-- 刷新状态行为当前展示集计数「共 N 个图标」（未构建时清空）。
-- ============================================================================
local function IconViewerUpdateStatus()
	if g_IconViewerShownList ~= nil then
		Controls.IconViewerStatusLabel:SetText(IconViewerCountPrefixStr .. #g_IconViewerShownList .. IconViewerCountSuffixStr);
	else
		Controls.IconViewerStatusLabel:SetText("");
	end
end

-- ============================================================================
-- 条目4.5 公开：MPT_IconViewer_OnIconClick(i)
-- 图标按钮点击：复制该图标的 [ICON_x] 全文到剪贴板（i 为当前展示列表下标，经 SetVoid1 传入；
-- 前端剪贴板同 StagingRoom 原版 OnClickToCopy 加入代码复制的用法）。
-- ============================================================================
function MPT_IconViewer_OnIconClick(i : number)
	if g_IconViewerShownList == nil or g_IconViewerShownList[i] == nil then
		return;
	end
	UIManager:SetClipboardString(g_IconViewerShownList[i].IconString);
end

-- ============================================================================
-- 内部：MPT_IconViewer_StartBuild()
-- 重新计算构建列表并一次性同步构建全部实例（同原作加载方式；逐帧分批构建实测更卡，已弃用）。
-- 实例池释放复用（ResetInstances）；SetText 后顺带 GetSizeX 测量图标宽度存回数据行
-- （供尺寸排序，免原作独立测量循环）；无贴图图标（宽<=1）隐藏占位。
-- ============================================================================
function MPT_IconViewer_StartBuild()
	g_IconViewerShownList = IconViewerComputeBuildList();
	m_iconViewerDarkIM:ResetInstances();
	for i, data in ipairs(g_IconViewerShownList) do
		local iconInstance : table = m_iconViewerDarkIM:GetInstance();
		iconInstance.IconLabel:SetText("[size_0]" .. data.IconString);
		local iconSizeX : number = iconInstance.IconLabel:GetSizeX();
		data.Size = iconSizeX;	-- 顺带测量存回（无贴图图标宽度<=1，排序时自然排最前）
		if iconSizeX <= 1 then
			iconInstance.ButtonRoot:SetHide(true);
		else
			iconInstance.IconLabel:SetOffsetX(64 - iconSizeX / 2);
			iconInstance.IconLabel:SetOffsetY(66 - iconSizeX / 2);
		end
		iconInstance.IconButton:SetToolTipString(string.sub(data.IconString, 2, -2));	-- 去首尾方括号显示图标名
		iconInstance.IconButton:SetVoid1(i);
		iconInstance.IconButton:RegisterCallback(Mouse.eLClick, MPT_IconViewer_OnIconClick);
	end
	Controls.IconViewerStack:CalculateSize();
	Controls.IconViewerScrollPanel:CalculateInternalSize();
	-- 无过滤构建完成即全部图标宽度测量齐备，尺寸排序可用
	if g_IconViewerSearchStr == "" then
		g_IconViewerBuiltOnce = true;
	end
	IconViewerUpdateStatus();
end

-- ============================================================================
-- 条目4.5 公开：MPT_IconViewer_RequestRebuild()
-- 搜索串/背景/排序任一变化时立即同步重建；面板从未构建过（从未打开）时不启动，
-- 避免隐藏态白建 5056 实例。
-- ============================================================================
function MPT_IconViewer_RequestRebuild()
	if g_IconViewerShownList == nil then
		return;
	end
	MPT_IconViewer_StartBuild();
end

-- ============================================================================
-- 条目4.5/4.6 融合说明：面板打开/关闭/页签切换已并入条目4.6 分区末尾的
-- MPT_Viewer_OpenTab / MPT_Viewer_Close / MPT_Viewer_SelectTab（两查看器共用
-- IconViewerPanel 根容器）；图标页懒构建由 SelectTab 在首次切到时触发（本分区
-- MPT_IconViewer_StartBuild 不变）。
-- ============================================================================

-- ============================================================================
-- 条目4.5：控件注册（分区自包含初始化；本文件每前端状态只执行一次，无需守卫）
-- 融合面板的 MPT_Viewer_* 函数定义在条目4.6 分区（本行执行时全局函数尚未定义），
-- 故注册一律用匿名闭包，运行时解析全局。
-- ============================================================================
Controls.IconViewerButton:RegisterCallback(Mouse.eLClick, function() MPT_Viewer_OpenTab(g_ViewerCurrentTab); end);	-- 单入口按钮：打开融合面板并回到上次停留的页签
Controls.IconViewerButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
Controls.IconViewerCloseButton:RegisterCallback(Mouse.eLClick, function() MPT_Viewer_Close(); end);
Controls.IconViewerCloseButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
Controls.IconViewerModalBlocker:RegisterCallback(Mouse.eLClick, function() MPT_Viewer_Close(); end);

-- 搜索框：内容变化即重建过滤；占位文本按焦点/内容显隐（同 4.4 搜索框惯例）
Controls.IconViewerSearchEditBox:RegisterStringChangedCallback(function()
	g_IconViewerSearchStr = string.lower(Controls.IconViewerSearchEditBox:GetText() or "");
	Controls.IconViewerSearchPlaceholder:SetHide(g_IconViewerSearchStr ~= "");
	MPT_IconViewer_RequestRebuild();
end);
Controls.IconViewerSearchEditBox:RegisterHasFocusCallback(function()
	Controls.IconViewerSearchPlaceholder:SetHide(true);
end);
Controls.IconViewerSearchEditBox:RegisterLostFocusCallback(function()
	Controls.IconViewerSearchPlaceholder:SetHide((Controls.IconViewerSearchEditBox:GetText() or "") ~= "");
end);

-- 「按尺寸排序」开关（复选框为原作样式 NoStateChange=1，点击不自动翻转，回调内自管状态并手动 SetCheck，同原作做法）
Controls.IconViewerToggleSortCheck:RegisterCallback(Mouse.eLClick, function()
	g_IconViewerSortBySize = not g_IconViewerSortBySize;
	Controls.IconViewerToggleSortCheck:SetCheck(g_IconViewerSortBySize);
	UI.PlaySound("Tech_Tray_Slide_Open");
	MPT_IconViewer_RequestRebuild();
end);
end	-- 条目4.5 do 块结束（寄存器上限适配）


-- ############################################################################
-- 条目4.6：贴图查看器（移植 TextureViewer「Texture查看器」mod，本作者旧作，并适配优化）
-- ============================================================================
-- 用法：左下角 BottomLeftButtonStack「查看器」单按钮打开融合面板（同条目4.5），面板顶部
--   页签切到贴图页（页签切换见本分区末尾融合块）；悬停格子显示自定义预览 Tooltip（贴图真实
--   比例 + 像素尺寸 + 贴图名 + 来源 blp 包），点击格子复制贴图名到剪贴板；搜索框按贴图名
--   子串过滤（大小写不敏感）；「按来源包分组」开关按 SourceBlp 分组排序。
--   关闭：X 按钮 / 点击面板外 / ESC；退出房间自动关闭（OnHandleExitRequest）。
-- 数据源：前端配置库 MPT_TextureCollection 表（FrontEnd/TextureViewer/TextureViewer_Data.sql，
--   5017 行；DB.ConfigurationQuery 为前端配置库句柄，同条目4.5 先例），本分区顶层一次性
--   预加载进 g_TextureViewerData（纯数据，不建实例）。
-- 相对原作的适配与优化：
--   1) 承载从 InGame 独立 Context 改为准备房间面板（前端无法新建 UI Context，见踩坑记录），
--      入口从 LaunchBar 改为 BottomLeftButtonStack 按钮；
--   2) 原作 Initialize 即全量构建 5017 实例（进游戏就建）改为首开面板懒构建 +
--      InstanceManager 实例池复用（同条目4.5 惯例），二次重建开销极小；
--   3) 来源分组排序副本在预加载时一次算好（与正常序共享行表，行内容只读），开关切换零排序计算；
--   4) 自定义预览 Tooltip 机制不变（TTManager + StagingRoom.xml 内 ToolTipType，
--      前端可行有联机工具箱1.67 StagingRoom.xml 内 TooltipType_TPT_Update 先例）。
-- ############################################################################

-- 寄存器上限适配：本分区块级 do...end 包裹（同条目4.3预备注释）
do
-- ============================================================================
-- 条目4.6：本地化文本预加载缓存（规范：分区头后集中预加载；XML String=/ToolTip= 不预加载；
--   带数字文本拆无参数前缀/后缀 tag，缓存后运行时用 .. 拼接）
-- ============================================================================
local TextureViewerCountPrefixStr	: string = Locale.Lookup("LOC_MPT_TEXTUREVIEWER_COUNT_PREFIX");
local TextureViewerCountSuffixStr	: string = Locale.Lookup("LOC_MPT_TEXTUREVIEWER_COUNT_SUFFIX");
local TextureViewerTTSourceStr		: string = Locale.Lookup("LOC_MPT_TEXTUREVIEWER_TT_SOURCE");

-- ============================================================================
-- 常量与全局状态（全局而非 local：KeyUpHandler/OnHandleExitRequest 等本文件前部代码
--   要调用本分区函数；且「声明点之前引用的 local 会解析为全局」为已踩坑，统一全局避免声明顺序问题）
-- ============================================================================
g_TextureViewerData          = {};		-- 预加载全量数据：{ { TextureName="X", SourceBlp="Y.blp" }, ... }（数据库顺序）
g_TextureViewerSourceData    = {};		-- 按来源包分组排序副本（SourceBlp 字典序，同包内按 TextureName；与上表共享行表）
g_TextureViewerSearchStr     = "";		-- 搜索框当前内容（已转小写）
g_TextureViewerSortBySource  = false;	-- 按来源包分组开关
g_TextureViewerShownList     = nil;		-- 当前展示的数据行数组（点击格子反查用；nil=尚未构建）

local m_textureViewerIM       = InstanceManager:new("TextureViewerTileInstance", "ButtonRoot", Controls.TextureViewerStack);
local m_textureViewerTooltip  = {};		-- 自定义 Tooltip 控件表（分区末尾 TTManager:GetTypeControlTable 填充）

local TEXTUREVIEWER_TT_SCREEN_MARGIN : number = 40;	-- 预览 Tooltip 超屏缩放边距（屏幕四边各留空间）

-- ============================================================================
-- 内部：MPT_TextureViewer_Preload()
-- 顶层一次性预加载 MPT_TextureCollection 全表（纯数据，不建实例）。
-- 同时算出按来源包分组的排序副本（原作 GetSourceSortData 语义：SourceBlp 字典序，同包内按贴图名）。
-- ============================================================================
local function MPT_TextureViewer_Preload()
	local textureRows = DB.ConfigurationQuery("SELECT TextureName, SourceBlp FROM MPT_TextureCollection");
	if textureRows == nil then
		return;
	end
	local normalData : table = {};
	for i, row in ipairs(textureRows) do
		if row.TextureName ~= nil and row.TextureName ~= "" then
			table.insert(normalData, { TextureName = row.TextureName, SourceBlp = row.SourceBlp or "" });
		end
	end
	g_TextureViewerData = normalData;
	-- 来源分组排序副本：共享行表（行内容只读），预加载时一次排序，开关切换零计算
	local sourceData : table = {};
	for i, data in ipairs(normalData) do
		table.insert(sourceData, data);
	end
	table.sort(sourceData, function(a, b)
		if a.SourceBlp == b.SourceBlp then
			return a.TextureName < b.TextureName;
		end
		return a.SourceBlp < b.SourceBlp;
	end);
	g_TextureViewerSourceData = sourceData;
end
MPT_TextureViewer_Preload();

-- ============================================================================
-- 内部：TextureViewerComputeBuildList()
-- 按当前排序开关取基础数组（正常序 / 来源分组序），再按当前搜索串过滤，返回待构建的数据行数组。
-- ============================================================================
local function TextureViewerComputeBuildList()
	local baseList : table = g_TextureViewerSortBySource and g_TextureViewerSourceData or g_TextureViewerData;
	local buildList : table = {};
	for i, data in ipairs(baseList) do
		if g_TextureViewerSearchStr == ""
			or string.find(string.lower(data.TextureName), g_TextureViewerSearchStr, 1, true) ~= nil then
			table.insert(buildList, data);
		end
	end
	return buildList;
end

-- ============================================================================
-- 内部：TextureViewerUpdateStatus()
-- 刷新状态行为当前展示集计数「共 N 个贴图」（未构建时清空）。
-- ============================================================================
local function TextureViewerUpdateStatus()
	if g_TextureViewerShownList ~= nil then
		Controls.TextureViewerStatusLabel:SetText(TextureViewerCountPrefixStr .. #g_TextureViewerShownList .. TextureViewerCountSuffixStr);
	else
		Controls.TextureViewerStatusLabel:SetText("");
	end
end

-- ============================================================================
-- 条目4.6 公开：MPT_TextureViewer_OnTileClick(i)
-- 格子点击：复制该格贴图名到剪贴板（i 为当前展示列表下标，经 SetVoid1 传入；
-- 前端剪贴板同 StagingRoom 原版 OnClickToCopy 加入代码复制的用法）。
-- ============================================================================
function MPT_TextureViewer_OnTileClick(i : number)
	if g_TextureViewerShownList == nil or g_TextureViewerShownList[i] == nil then
		return;
	end
	UIManager:SetClipboardString(g_TextureViewerShownList[i].TextureName);
end

-- ============================================================================
-- 内部：TextureViewerFillTooltip(texName, srcBlp)
-- 填充自定义预览 Tooltip（全局单例控件表 m_textureViewerTooltip，每次悬停先重设纹理防残留）：
-- TTImage StretchMode=Auto 按真实比例渲染，SetTexture 后 auto 尺寸即贴图真实像素；
-- 读尺寸失败隐藏尺寸行；原图超屏幕可用区域时等比缩小防 Tooltip 溢出屏幕（移植原作逻辑）。
-- ============================================================================
local function TextureViewerFillTooltip(texName : string, srcBlp : string)
	m_textureViewerTooltip.TTImage:SetTexture(texName);
	local pixelW : number = m_textureViewerTooltip.TTImage:GetSizeX();
	local pixelH : number = m_textureViewerTooltip.TTImage:GetSizeY();
	if pixelW ~= nil and pixelH ~= nil and pixelW > 0 and pixelH > 0 then
		m_textureViewerTooltip.TTSizeLabel:SetText(pixelW .. " × " .. pixelH);
		m_textureViewerTooltip.TTSizeLabel:SetHide(false);
		local screenW, screenH : number = UIManager:GetScreenSizeVal();
		local scale : number = math.min(math.max(screenW - TEXTUREVIEWER_TT_SCREEN_MARGIN, 1) / pixelW,
			math.max(screenH - TEXTUREVIEWER_TT_SCREEN_MARGIN, 1) / pixelH, 1);
		if scale < 1 then
			-- 两数值设尺寸用 SetSizeVal（ControlBase::SetSize 只收 1 参，原作此处为潜伏 bug，超大贴图悬停即报错）
			m_textureViewerTooltip.TTImage:SetSizeVal(math.floor(pixelW * scale), math.floor(pixelH * scale));
		end
	else
		m_textureViewerTooltip.TTSizeLabel:SetHide(true);
	end
	m_textureViewerTooltip.TTNameLabel:SetText(texName);
	m_textureViewerTooltip.TTSourceLabel:SetText(TextureViewerTTSourceStr .. srcBlp);
end

-- ============================================================================
-- 内部：MPT_TextureViewer_StartBuild()
-- 重新计算构建列表并一次性同步构建全部实例（同条目4.5 加载方式）。
-- 实例池释放复用（ResetInstances）；每格 SetTexture 贴图 + 注册自定义预览 Tooltip + 点击复制。
-- ============================================================================
function MPT_TextureViewer_StartBuild()
	g_TextureViewerShownList = TextureViewerComputeBuildList();
	m_textureViewerIM:ResetInstances();
	for i, data in ipairs(g_TextureViewerShownList) do
		local tileInstance : table = m_textureViewerIM:GetInstance();
		-- 格子贴图：StretchMode=Uniform + 固定 100 边界（XML 定义）→ 引擎按纹理真实比例等比适配
		tileInstance.TextureImage:SetTexture(data.TextureName);
		-- 局部快照：避免闭包共享循环变量（Lua 经典陷阱）
		local texName : string = data.TextureName;
		local srcBlp  : string = data.SourceBlp;
		-- 自定义 TooltipType：悬停显示贴图预览 + 像素尺寸 + 名字 + 来源包
		tileInstance.TileButton:SetToolTipType("MPT_TextureViewerTooltip");
		tileInstance.TileButton:SetToolTipCallback(function()
			TextureViewerFillTooltip(texName, srcBlp);
		end);
		tileInstance.TileButton:SetVoid1(i);
		tileInstance.TileButton:RegisterCallback(Mouse.eLClick, MPT_TextureViewer_OnTileClick);
	end
	Controls.TextureViewerStack:CalculateSize();
	Controls.TextureViewerScrollPanel:CalculateInternalSize();
	TextureViewerUpdateStatus();
end

-- ============================================================================
-- 条目4.6 公开：MPT_TextureViewer_RequestRebuild()
-- 搜索串/排序开关变化时立即同步重建；面板从未构建过（从未打开）时不启动，避免隐藏态白建实例。
-- ============================================================================
function MPT_TextureViewer_RequestRebuild()
	if g_TextureViewerShownList == nil then
		return;
	end
	MPT_TextureViewer_StartBuild();
end

-- ============================================================================
-- 条目4.6：控件注册（分区自包含初始化；本文件每前端状态只执行一次，无需守卫）
-- 贴图页无独立关闭钮/遮挡层与入口按钮（条目4.5/4.6 融合：单入口按钮为图标页的
-- IconViewerButton，注册见条目4.5 分区），页签按钮注册见本分区末尾融合块。
-- ============================================================================
TTManager:GetTypeControlTable("MPT_TextureViewerTooltip", m_textureViewerTooltip);

-- 搜索框：内容变化即重建过滤；占位文本按焦点/内容显隐（同 4.4 搜索框惯例）
Controls.TextureViewerSearchEditBox:RegisterStringChangedCallback(function()
	g_TextureViewerSearchStr = string.lower(Controls.TextureViewerSearchEditBox:GetText() or "");
	Controls.TextureViewerSearchPlaceholder:SetHide(g_TextureViewerSearchStr ~= "");
	MPT_TextureViewer_RequestRebuild();
end);
Controls.TextureViewerSearchEditBox:RegisterHasFocusCallback(function()
	Controls.TextureViewerSearchPlaceholder:SetHide(true);
end);
Controls.TextureViewerSearchEditBox:RegisterLostFocusCallback(function()
	Controls.TextureViewerSearchPlaceholder:SetHide((Controls.TextureViewerSearchEditBox:GetText() or "") ~= "");
end);

-- 「按来源包分组」开关（复选框 NoStateChange=1 点击不自动翻转，回调内自管状态并手动 SetCheck，同条目4.5 做法）
Controls.TextureViewerToggleSortCheck:RegisterCallback(Mouse.eLClick, function()
	g_TextureViewerSortBySource = not g_TextureViewerSortBySource;
	Controls.TextureViewerToggleSortCheck:SetCheck(g_TextureViewerSortBySource);
	UI.PlaySound("Tech_Tray_Slide_Open");
	MPT_TextureViewer_RequestRebuild();
end);

-- ############################################################################
-- 条目4.5/4.6 融合：页签切换与统一开关
-- ============================================================================
-- 两查看器共用 IconViewerPanel 根容器 + 单一 IconViewerModalBlocker 遮挡层（XML 融合面板注释），
-- 页签台/按钮样式仿 ClimateScreen.xml（TabLedge2 + TabButton/TabButtonSelected）。
-- 本块函数为全局（KeyUpHandler/OnHandleExitRequest 与单入口按钮闭包都要调用）。
-- ############################################################################
g_ViewerCurrentTab = "icon";	-- 当前页签："icon" 图标页 / "texture" 贴图页

-- ============================================================================
-- 条目4.5/4.6 公开：MPT_Viewer_SelectTab(tab)
-- 切换页签：显隐两个内容容器 + 页签按钮选中态（TabButtonSelected 子钮显隐 + SetSelected，
-- 仿 ClimateScreen RefreshTabs 写法）；目标页从未构建过则顺带懒构建（首开该页才建实例）。
-- ============================================================================
function MPT_Viewer_SelectTab(tab : string)
	g_ViewerCurrentTab = tab;
	local isIcon : boolean = (tab == "icon");
	Controls.ViewerIconContent:SetHide(not isIcon);
	Controls.ViewerTextureContent:SetHide(isIcon);
	Controls.IconTabSelected:SetHide(not isIcon);
	Controls.IconTabButton:SetSelected(isIcon);
	Controls.TextureTabSelected:SetHide(isIcon);
	Controls.TextureTabButton:SetSelected(not isIcon);
	if isIcon then
		if g_IconViewerShownList == nil then
			MPT_IconViewer_StartBuild();
		end
	elseif g_TextureViewerShownList == nil then
		MPT_TextureViewer_StartBuild();
	end
end

-- ============================================================================
-- 条目4.5/4.6 公开：MPT_Viewer_OpenTab(tab) / MPT_Viewer_Close()
-- 打开融合面板并切到指定页签 / 关闭融合面板（含全屏点击拦截层）；Close 幂等；
-- ESC 拦截见 KeyUpHandler，退房关闭见 OnHandleExitRequest。
-- ============================================================================
function MPT_Viewer_OpenTab(tab : string)
	Controls.IconViewerModalBlocker:SetHide(false);
	Controls.IconViewerPanel:SetHide(false);
	UI.PlaySound("UI_Screen_Open");
	MPT_Viewer_SelectTab(tab);
end

function MPT_Viewer_Close()
	if Controls.IconViewerPanel:IsHidden() then
		return;
	end
	Controls.IconViewerPanel:SetHide(true);
	Controls.IconViewerModalBlocker:SetHide(true);
	UI.PlaySound("UI_Screen_Close");
end

-- 页签按钮注册（点击切换页签，不重建已构建内容）
Controls.IconTabButton:RegisterCallback(Mouse.eLClick, function() MPT_Viewer_SelectTab("icon"); end);
Controls.TextureTabButton:RegisterCallback(Mouse.eLClick, function() MPT_Viewer_SelectTab("texture"); end);
end	-- 条目4.6 do 块结束（寄存器上限适配）


-- ############################################################################
-- 条目4.7：进房自动更新已启用的非官方创意工坊mod（移植联机工具箱1.67 BSR UpdateAllMods 并优化）
-- ============================================================================
-- 用法：加入/创建准备房间（OnShow 新会话分支）时自动对本局已启用的非官方创意工坊 mod
--      逐一调用 Modding.UpdateSubscription 触发工坊更新检查；静默执行，无界面反馈，
--      仅 print 到 Lua.log 留痕。
-- 相对 1.67 的优化：
--   1. 触发时机：1.67 挂在 RealizeGameSetup（每次房间配置刷新都重复触发），改为新会话
--      分支每进房只触发一次；
--   2. 查找复杂度 O(n²)→O(n)：1.67 为启用×安装双重循环按 Id 匹配，改为单次遍历已安装
--      mod 建 [modId]=SubscriptionId 局部映射（每会话只跑一次，无需跨调用缓存）；
--   3. 会话幂等守卫：s_lastUpdateSessionID 记录上次触发会话，同会话重复调用直接返回
--      （本文件 Lua 状态跨房间存续，靠 sessionID 变化自然放行下次进房）；
--   4. nil 防御：GetEnabledMods/GetInstalledMods 返回 nil 安全跳过；SubscriptionId
--      空串跳过（自动排除 Epic/非工坊 mod）；
--   5. 日志留痕：print 触发更新的数量与 mod 标题（1.67 完全无日志）。
-- 寄存器上限适配：本分区块级 do...end 包裹（同条目4.3预备注释）
-- ############################################################################
do
local s_lastUpdateSessionID : number = -1;	-- 上次触发更新检查的会话 ID（幂等守卫）

-- ============================================================================
-- 条目4.7 公开：MPT_UpdateEnabledMods()
-- 对本局已启用（GameConfiguration.GetEnabledMods）的非官方创意工坊 mod 触发工坊更新检查。
-- 同会话幂等；调用点：OnShow 新会话分支（本文件 :2600 附近）。
-- ============================================================================
function MPT_UpdateEnabledMods()
	local sessionID : number = Network.GetSessionID();
	if sessionID == s_lastUpdateSessionID then
		return;		-- 同会话已触发过，直接返回
	end
	s_lastUpdateSessionID = sessionID;

	-- 单次遍历已安装 mod 建 [modId]=SubscriptionId 映射（替代 1.67 双重循环）
	local subscriptionMap : table = {};
	local installedMods = Modding.GetInstalledMods();
	if installedMods == nil then
		return;
	end
	for _, mod in ipairs(installedMods) do
		if mod.SubscriptionId ~= nil and mod.SubscriptionId ~= "" then
			subscriptionMap[mod.Id] = mod.SubscriptionId;
		end
	end

	-- 遍历本局已启用 mod：非官方且有工坊订阅的触发更新
	local updateCount : number = 0;
	local enabledMods = GameConfiguration.GetEnabledMods();
	if enabledMods == nil then
		return;
	end
	for _, curMod in ipairs(enabledMods) do
		if not curMod.Official then
			local subscriptionId = subscriptionMap[curMod.Id];
			if subscriptionId ~= nil then
				Modding.UpdateSubscription(subscriptionId);		-- 触发工坊更新检查
				updateCount = updateCount + 1;
				print("MPT 条目4.7：检查工坊更新 " .. tostring(curMod.Title) .. " (SubscriptionId=" .. tostring(subscriptionId) .. ")");
			end
		end
	end
	print("MPT 条目4.7：进房自动更新检查完成，共触发 " .. updateCount .. " 个非官方创意工坊mod");
end
end	-- 条目4.7 do 块结束（寄存器上限适配）
