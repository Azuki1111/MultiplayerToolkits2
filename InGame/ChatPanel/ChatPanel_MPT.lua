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
--   1) 缓存原版 UpdatePlayerEntry 并包裹——构建/刷新玩家列表条目后，
--      给该玩家实例的 PlayerNameButton（ChatPanel.xml 新增透明按钮）注册点击回调；
--   2) 点击回调经 LuaEvents.MPT_PlayerMark_OpenAddPopupForPlayer(playerID) 桥接到
--      PlayerMark Context（InGame/PlayerMark 订阅），打开「添加玩家」弹窗并预填
--      网络ID/昵称（同前端 StagingRoom PlayerNameButton 逻辑）。
--
-- 实例→playerID 关联（修复：不用 LookUpControl——那是 ContextPtr 的方法，控件对象没有）：
--   PlayerListStack:GetChildren() 返回实例根容器数组（按构建序）；
--   实例根:GetChildren() 返回其直接子（XML 声明序）：[1]=PullDown、[2]=PlayerNameButton；
--   PullDown:GetChildren()[2] = PlayerName Label（XML 序：ConnectionIcon, PlayerName, ConnectionLabel）。
--   按 PlayerName 文本遍历 PlayerConfigurations 反查 playerID（SlotName 匹配，跳过自己）。
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
-- MPT_FindPlayerIDBySlotName(slotName)：遍历 PlayerConfigurations 反查显示名匹配的 playerID。
--   返回 nil 表示无匹配（安全降级：不注册按钮）。
-- ============================================================================
local function MPT_FindPlayerIDBySlotName(slotName : string)
	if slotName == nil or slotName == "" then return nil; end
	for iPlayerID, pConfig in pairs(PlayerConfigurations) do
		if pConfig ~= nil then
			local name = pConfig:GetSlotName();
			if name ~= nil and name == slotName then
				return iPlayerID;
			end
		end
	end
	return nil;
end

-- ============================================================================
-- MPT_RegisterPlayerNameButtonForInstance(instRoot, iPlayerID)：给单个实例根容器
--   的 PlayerNameButton 注册点击回调（幂等：SetVoid 已关联该玩家则跳过）。
--   instRoot 直接子结构：[1]=PlayerListPull、[2]=PlayerNameButton（XML 声明序）。
-- ============================================================================
local function MPT_RegisterPlayerNameButtonForInstance(instRoot, iPlayerID : number)
	local children = instRoot:GetChildren();
	if children == nil or #children < 2 then return; end
	local btn = children[2];	-- PlayerNameButton（XML 序第 2 个直接子）
	if btn == nil then return; end
	if btn:GetVoid1() == iPlayerID then return; end	-- 幂等
	btn:SetVoid1(iPlayerID);
	btn:RegisterCallback(Mouse.eLClick, function() MPT_OpenAddPopupForPlayer(iPlayerID); end);
end

-- ============================================================================
-- 包裹 UpdatePlayerEntry：调用原版后，遍历 PlayerListStack 全部实例，
--   按 PlayerName 文本匹配当前玩家，注册其按钮回调。
-- ============================================================================
if UpdatePlayerEntry ~= nil then
	local baseUpdatePlayerEntry = UpdatePlayerEntry;
	function UpdatePlayerEntry(iPlayerID : number)
		baseUpdatePlayerEntry(iPlayerID);
		-- 遍历 PlayerListStack 找本玩家实例：从 PlayerName 文本反查
		local stack = Controls.PlayerListStack;
		if stack == nil then return; end
		local stackChildren = stack:GetChildren();
		if stackChildren == nil then return; end
		local pConfig = PlayerConfigurations[iPlayerID];
		if pConfig == nil then return; end
		local slotName : string = pConfig:GetSlotName();
		if slotName == nil or slotName == "" then return; end
		for i, instRoot in ipairs(stackChildren) do
			-- 实例根直接子：[1]=PullDown → GetChildren()[2]=PlayerName Label
			local instChildren = instRoot:GetChildren();
			if instChildren ~= nil and #instChildren >= 1 then
				local pullDown = instChildren[1];
				if pullDown ~= nil then
					local pullChildren = pullDown:GetChildren();
					if pullChildren ~= nil and #pullChildren >= 2 then
						local nameLabel = pullChildren[2];	-- PlayerName Label
						if nameLabel ~= nil and nameLabel:GetText() == slotName then
							MPT_RegisterPlayerNameButtonForInstance(instRoot, iPlayerID);
							return;	-- 已处理本玩家实例
						end
					end
				end
			end
		end
	end
else
	print("MPT ChatPanel: 未找到 UpdatePlayerEntry，跳过玩家名点击注入");
end
