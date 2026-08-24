-- ============================================================================
-- ChatPanel_MPT.lua（条目4.8续：玩家名点击 → 打开玩家标记「添加玩家」弹窗）
--
-- 经 ReplaceUIScript（LuaContext=ChatPanel, LuaReplace=本文件）注入到原版
-- ChatPanel 上下文（WorldTracker.xml <LuaContext FileName="ChatPanel"/> 加载）。
-- 仿 1.67 ChatPanel_TPT.lua 的「多文件探测 include」模式：
--   先 include("chatpanel_MPH.lua")（MPH mod 存在时其覆盖版），回退 include("ChatPanel.lua")
--   （原版 Base；DLC CivRoyaleScenario 变体 ChatPanel_CivRoyaleScenario.lua 内部自己
--   include("ChatPanel") 叠加覆盖，探测 Base 即覆盖全部变体）。
-- 注入内容：
--   1) 缓存原版 UpdatePlayerEntry 并包裹——每次构建/刷新玩家列表条目后，
--      给该玩家实例的 PlayerNameButton（ChatPanel.xml 新增透明按钮）注册点击回调；
--   2) 点击回调经 LuaEvents.MPT_PlayerMark_OpenAddPopupForPlayer(playerID) 桥接到
--      PlayerMark Context（InGame/PlayerMark 订阅），打开「添加玩家」弹窗并预填
--      网络ID/昵称（同前端 StagingRoom PlayerNameButton 逻辑）。
--
-- 实例→playerID 关联：原版 m_playerListEntries 是局部 upvalue 访问不到，PlayerListStack
--   的子项是实例根容器（GetChildren() 数组）。用 PlayerName 文本匹配（原版
--   playerEntry.PlayerName:SetText(pPlayerConfig:GetSlotName())）：找到显示名与当前
--   玩家 SlotName 相同的实例，给其按钮 SetVoid1(playerID) + 注册回调（幂等）。
--   匹配不到（同名玩家等罕见情况）则不注册，安全降级为不可点。
-- ============================================================================

-- 探测 include 原版（1.67 同款：MPH 覆盖优先，否则 Base；探测标志 Initialize 存在即成功）
local baseFiles = {
	"chatpanel_MPH.lua",
	"ChatPanel.lua"
};
for i, file in ipairs(baseFiles) do
	include(file);
	if Initialize ~= nil then
		print("MPT ChatPanel: 加载原版基础文件 " .. file);
		break;
	end
end

-- ============================================================================
-- MPT_OpenAddPopupForPlayer(playerID)：玩家名点击 → 桥接 PlayerMark 弹窗
--   跳过自己（同前端 OnSlotNameClick 语义：不标记自己）。
-- ============================================================================
local function MPT_OpenAddPopupForPlayer(playerID : number)
	if playerID == nil then return; end
	if playerID == Network.GetLocalPlayerID() then return; end	-- 不标记自己
	local pConfig = PlayerConfigurations[playerID];
	if pConfig == nil then return; end
	LuaEvents.MPT_PlayerMark_OpenAddPopupForPlayer(playerID);	-- 转发：PlayerMark Context 内查 ID/昵称并弹窗
end

-- ============================================================================
-- MPT_RegisterPlayerNameButtonForPlayer(iPlayerID)：给 PlayerListStack 中显示名为
--   该玩家 SlotName 的实例注册 PlayerNameButton 点击回调（幂等：SetVoid 已关联则跳过）。
-- ============================================================================
local function MPT_RegisterPlayerNameButtonForPlayer(iPlayerID : number)
	local stack = Controls.PlayerListStack;
	if stack == nil then return; end
	local children = stack:GetChildren();
	if children == nil then return; end
	local pConfig = PlayerConfigurations[iPlayerID];
	if pConfig == nil then return; end
	local slotName : string = pConfig:GetSlotName();
	if slotName == nil or slotName == "" then return; end
	for i, instRoot in ipairs(children) do
		local nameLabel = instRoot:LookUpControl("PlayerName");
		if nameLabel ~= nil and nameLabel:GetText() == slotName then
			local btn = instRoot:LookUpControl("PlayerNameButton");
			if btn ~= nil then
				if btn:GetVoid1() ~= iPlayerID then	-- 幂等
					btn:SetVoid1(iPlayerID);
					btn:RegisterCallback(Mouse.eLClick, function() MPT_OpenAddPopupForPlayer(iPlayerID); end);
				end
			end
			return;	-- 已找到本玩家实例
		end
	end
end

-- ============================================================================
-- 包裹 UpdatePlayerEntry：调用原版后，注册本玩家实例的按钮回调。
-- ============================================================================
if UpdatePlayerEntry ~= nil then
	local baseUpdatePlayerEntry = UpdatePlayerEntry;
	function UpdatePlayerEntry(iPlayerID : number)
		baseUpdatePlayerEntry(iPlayerID);
		MPT_RegisterPlayerNameButtonForPlayer(iPlayerID);
	end
else
	print("MPT ChatPanel: 未找到 UpdatePlayerEntry，跳过玩家名点击注入");
end
