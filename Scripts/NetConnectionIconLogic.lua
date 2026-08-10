-------------------------------------------------
-- Network Connection Logic
-- 
-- Common scripting logic used for updating player network connection status.
-- IE, network connection icons, labels, etc.
-------------------------------------------------
-- ============================================================================
-- 联机工具箱2.0 修改说明（本文件同名覆盖原版 Scripts/NetConnectionIconLogic.lua）
-- 条目3.7 网络连接显示优化：
-- 1. UpdateNetConnectionIcon 增加可选第三参数 pingLabel，在房间槽位
--    就绪状态文本后常驻显示 ping 数值，颜色跟随绿黄红三档；
--    pingLabel 传 nil 时行为与原版完全一致（ChatPanel 两参数调用不受影响）
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

-- 联机工具箱2.0 新增：常驻 ping 数值的档位颜色（0xAARRGGBB，与连接灯同色系）
local PING_COLOR_GREAT	= 0xFF50C850; -- 绿
local PING_COLOR_OK		= 0xFFE8C840; -- 黄
local PING_COLOR_BAD	= 0xFFF05050; -- 红

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
				pingLabel:SetText(tostring(iPingTime) .. "ms");
				if(iPingTime < PING_GREAT) then
					pingLabel:SetColor(PING_COLOR_GREAT);
				elseif(iPingTime < PING_OK) then
					pingLabel:SetColor(PING_COLOR_OK);
				else
					pingLabel:SetColor(PING_COLOR_BAD);
				end
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

----------------------------------------------------------------
-- UpdateNetConnectionLabel
-- Remember to call UpdateNetConnectionLabel when...
-- * Creating a network connection label.
----------------------------------------------------------------
function UpdateNetConnectionLabel(playerID :number, connectLabel :table)
	-- Update network connection status
	local pPlayerConfig = PlayerConfigurations[playerID];
	local slotStatus = pPlayerConfig:GetSlotStatus();
	if(slotStatus == SlotStatus.SS_TAKEN or slotStatus == SlotStatus.SS_OBSERVER) then
		local statusString :string;
		local tooltipString :string;
		if(Network.IsPlayerHotJoining(playerID)) then
			-- Player is hot joining.
			statusString = PlayerConnectingSummaryStr;
			tooltipString = PlayerConnectingStr;
		elseif(Network.IsPlayerConnected(playerID)) then
			if(not pPlayerConfig:GetModReady()) then
				statusString = PlayerNotModReadySummaryStr;
				tooltipString = PlayerNotModReadyStr;
			elseif(Network.IsPlayerResyncing(playerID)) then
				statusString = PlayerResyncingSummaryStr;
				tooltipString = PlayerResyncingStr;
			else
				-- Player is fully connected.
				statusString = PlayerConnectedSummaryStr;
				tooltipString = PlayerConnectedStr;
			end
		else
			-- Not connected
			statusString = PlayerNotConnectedSummaryStr;
			tooltipString = PlayerNotConnectedStr;
		end	
		
		connectLabel:SetText(statusString);
		connectLabel:SetToolTipString(tooltipString);
	end
end
