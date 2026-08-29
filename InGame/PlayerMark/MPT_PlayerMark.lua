-- ============================================================================
-- 条目11：游戏内玩家标记面板（移植条目4.4 PlayerMarkPanel 到 InGame）
--
-- 来源：FrontEnd/UI/StagingRoom/StagingRoom.lua 条目4.4 分区（玩家标记管理：
--   纯本地玩家档案——好友/一般/黑名单标记 + 记事本），面板逻辑整体复制。
-- 数据：与前端 4.4 同一份存档（ModGroup 组名 [MPT_DS][MPT_PlayerInfo][Players]），
--   双向互通；Modding 组存储 API 游戏内可用（用户实证）。
-- 存储层：直接 include Shared/MPT_DataStorage.lua（其自带 include("MPT_Serialize")
--   与幂等守卫）——游戏内 include 本 mod VFS 文件可靠（AGENTS.md 踩坑记录），
--   Shared 独立文件本就是为游戏内消费方保留，不再复制第三份内联副本。
-- 打开方式：QuickPanel（条目8）展开区「玩家标记」按钮 → LuaEvents.MPT_PlayerMark_Toggle。
-- 关闭：X 按钮 / 点击面板外（ModalBlocker）/ ESC（ContextPtr:SetInputHandler，
--   EndGameMenu.lua:1294 同款；添加弹窗在时先关弹窗）。
-- 确认/提示弹窗：自研 MPT_PMConfirmPopup（替代引擎内置 PopupDialog——其 MakeInstance
--   在 AddUserInterfaces 空 Context 不实例化，Controls.PopupRoot 为 nil 报错，条目11 修复）。
-- 与前端 4.4 的差异（逐条注释横幅留痕）：
--   1) 删 MPT_PlayerMark_OnSlotNameClick（准备房间槽位热区联动，游戏内无此入口）；
--   2) MPT_PlayerMark_SaveToDisk 回调内删 MPT_PlayerMark_RefreshLocalCache()
--      （条目4.8 房间显示层刷新，游戏内无此层）；
--   3) 删 MPT_PlayerMark_ResetOnExit（退房硬重置；游戏内退回主菜单即销毁 UI 状态，
--      且 Open 每次真实读盘重建，无残留问题）；
--   4) 打开入口改 LuaEvents.MPT_PlayerMark_Toggle（前端为 XML 内 PlayerMarkButton）；
--   5) AddUserInterfaces 上下文引擎以 isHidden=true 加载（InGame.lua 硬编码挂
--      AdditionalUserInterfaces），Open/Close 首尾带 ContextPtr:SetHide 切换；
--   6) 控件注册段删 PlayerMarkButton 回调（本 Context XML 无此控件）；
--   7) 条目4.8续：同步隐身开关复选框与设置（与前端 StagingRoom.xml 同款 XML、Lua 同构函数
--      与接入点；无差异，仅控件上下文不同——本 Context XML 内 PlayerMarkHiddenMarkCheck）。
-- ============================================================================

include("InstanceManager");
-- 条目11 修复：弃用引擎内置 PopupDialog（其 MakeInstance 在 AddUserInterfaces 空 Context 不实例化，
-- Controls.PopupRoot 为 nil 会报 Runtime Error）；确认/提示改自研 MPT_PMConfirmPopup（见 XML 与文件下方函数）。
include("MPT_DataStorage");	-- 条目4.3 存储管线（自带 include("MPT_Serialize") 与幂等守卫）

-- ############################################################################
-- 条目4.4 副本开始（与 StagingRoom.lua 条目4.4 分区同构：do...end 包裹）
-- ############################################################################
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
local PlayerMarkCancelStr			: string = Locale.Lookup("LOC_CANCEL");
local PlayerMarkTagNameStrs			: table = {	-- 下标即 Tag：标签下拉项/按钮文本（复用过滤复选框文本 tag）
	Locale.Lookup("LOC_MPT_PLAYERMARK_FILTER_FRIEND"),
	Locale.Lookup("LOC_MPT_PLAYERMARK_FILTER_NORMAL"),
	Locale.Lookup("LOC_MPT_PLAYERMARK_FILTER_BLACK") };

-- ============================================================================
-- 常量与全局状态（保持全局：与前端 4.4 副本一致，且 LuaEvents/输入处理在分区外引用）
-- ============================================================================
local PLAYERMARK_STORAGE_FILE : string = "MPT_PlayerInfo";	-- 数据组命名空间段（字母数字下划线）
local PLAYERMARK_STORAGE_KEY  : string = "Players";			-- 数据组键名段
local PLAYERMARK_TAG_ICONS : table = { "[ICON_OnlineGreenPingPip]", "[ICON_OnlineYellowPingPig]", "[ICON_OnlineRedPingPig]" };	-- 下标即 Tag：1好友 2一般 3黑名单（游戏真实图标名黄/红为 PingPig，已核实）；带方括号文本 tag，下拉按钮文本用
local PLAYERMARK_TAG_ICON_NAMES : table = { "OnlineGreenPingPip", "OnlineYellowPingPig", "OnlineRedPingPig" };	-- 下标即 Tag；列表行 Image:SetIcon 用（FontIcons.xml 的裸 Name——SetIcon/Icon= 内部自动拼 ICON_ 前缀，不可再带）

g_PlayerMarkList        = {};		-- 玩家记录数组（磁盘内容的工作副本）
g_MPT_MarkHidden        = true;		-- 条目4.8续：隐身设置内存态（默认开启=隐藏自身 SQL 公共标记；与前端 4.4 同语义）
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
local m_playerMarkRoomIM = InstanceManager:new("MarkRoomEntryInstance", "RootContainer", Controls.PlayerMarkRoomListStack);
local g_playerMarkEntryIds : table = {};	-- 左列实例序号 -> 玩家 Id（点击行时反查，列表过滤/排序后下标不稳定）

-- ============================================================================
-- 条目11：自研确认/提示弹窗状态（替代引擎内置 PopupDialog；控件见 MPT_PlayerMark.xml）
--   g_PlayerMarkConfirmCallback = 「确定」按钮的回调（nil=仅提示）；确定后执行并清空，取消清空关闭。
-- ============================================================================
g_PlayerMarkConfirmCallback = nil;

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
-- 条目11：MPT_PlayerMark_Confirm(titleStr, textStr, onConfirm) —— 确认框（确定/取消）。
-- 确定 → 关闭弹窗后执行 onConfirm；取消 → 仅关闭。同名前端函数为 PopupDialog 版，本函数为自研弹窗版。
-- ============================================================================
function MPT_PlayerMark_Confirm(titleStr : string, textStr : string, onConfirm)
	g_PlayerMarkConfirmCallback = onConfirm;
	Controls.MPT_PMConfirmTitle:SetText(titleStr);
	Controls.MPT_PMConfirmText:SetText(textStr);
	Controls.MPT_PMConfirmOkButton:SetHide(false);
	Controls.MPT_PMConfirmCancelButton:SetHide(false);
	Controls.MPT_PMConfirmPopup:SetHide(false);
end

-- ============================================================================
-- 条目11：MPT_PlayerMark_Notify(titleStr, textStr) —— 仅提示（只有确定按钮）。
-- 用于昵称为空/重复 ID 等提示（前端 PopupDialog 版对应 AddTitle+AddText+AddButton(OK)）。
-- ============================================================================
function MPT_PlayerMark_Notify(titleStr : string, textStr : string)
	g_PlayerMarkConfirmCallback = nil;
	Controls.MPT_PMConfirmTitle:SetText(titleStr);
	Controls.MPT_PMConfirmText:SetText(textStr);
	Controls.MPT_PMConfirmOkButton:SetHide(false);
	Controls.MPT_PMConfirmCancelButton:SetHide(true);
	Controls.MPT_PMConfirmPopup:SetHide(false);
end

-- ============================================================================
-- 条目11：确认弹窗按钮点击（注册见文件末尾控件注册段；确定执行回调并清空，取消仅清空关闭）
-- ============================================================================
function MPT_PlayerMark_ConfirmOkClick()
	Controls.MPT_PMConfirmPopup:SetHide(true);
	local cb = g_PlayerMarkConfirmCallback;
	g_PlayerMarkConfirmCallback = nil;
	if cb ~= nil then cb(); end
end

function MPT_PlayerMark_ConfirmCancelClick()
	g_PlayerMarkConfirmCallback = nil;
	Controls.MPT_PMConfirmPopup:SetHide(true);
end

-- ============================================================================
-- MPT_PlayerMark_LoadFromDisk(callback) / MPT_PlayerMark_SaveToDisk(callback)
-- 条目4.3 存储管线包装：真实读盘刷新 g_PlayerMarkList / 把工作副本落盘。
-- ============================================================================
function MPT_PlayerMark_LoadFromDisk(callback)
	MPT_Storage_LoadComposite(PLAYERMARK_STORAGE_FILE, { "Players", "Settings" }, function(players, settings)
		g_PlayerMarkList = (type(players) == "table") and players or {};
		if type(settings) == "table" and type(settings.HiddenSqlMark) == "boolean" then
			g_MPT_MarkHidden = settings.HiddenSqlMark;
		else
			g_MPT_MarkHidden = true;
		end
		if callback ~= nil then callback(); end
	end);
end

function MPT_PlayerMark_SaveToDisk(callback)
	MPT_Storage_SaveComposite(PLAYERMARK_STORAGE_FILE, {
		Players = g_PlayerMarkList,
		Settings = { HiddenSqlMark = g_MPT_MarkHidden },
	}, function(ok)
		-- ============================================================================
		-- 条目11 差异2：删 MPT_PlayerMark_RefreshLocalCache() 调用（条目4.8 房间显示层刷新，游戏内无此层）
		-- if ok then
		-- 	MPT_PlayerMark_RefreshLocalCache();
		-- end
		-- ----------------------------------------------------------------------------
		if callback ~= nil then callback(ok); end
	end);
end

-- ============================================================================
-- 条目4.8续：隐身设置（隐藏自身 SQL 公共标记）——与前端 4.4 同步（StagingRoom.lua 同款）。
-- 语义：勾选 = 隐藏自己，房间内其他玩家加载我的配置后跳过我的 SQL 公共标记
--   （Admin/Normal/Honor；Ban 强制显示）。默认开启（继承 1.67 IsHiddenPlayerInfo_STR="T"）。
-- 存储：与 Players 同命名空间 MPT_PlayerInfo 下复合组 Settings 字段（LoadFromDisk 已一并读回）。
-- 广播：设置/进房时写 PlayerConfigurations[我]:SetValue("HiddenPlayerInfo","T"/"F")
--   + Network.BroadcastPlayerInfo（游戏内 PlayerConfigurations/Network 可用，QuickPanel 已验证）。
-- ============================================================================

-- MPT_PlayerMark_ApplyHiddenMarkUI()：复选框 UI 状态 <- 内存设置（g_MPT_MarkHidden）
function MPT_PlayerMark_ApplyHiddenMarkUI()
	Controls.PlayerMarkHiddenMarkCheck:SetCheck(g_MPT_MarkHidden);
end

-- MPT_PlayerMark_BroadcastHiddenMark()：把内存设置写入本机 PlayerConfigurations 并广播
--   （打开面板/勾选后调用；PlayerConfigurations[我] 不可用时静默跳过）
function MPT_PlayerMark_BroadcastHiddenMark()
	local localPlayerID : number = Network.GetLocalPlayerID();
	if localPlayerID ~= nil and PlayerConfigurations[localPlayerID] ~= nil then
		PlayerConfigurations[localPlayerID]:SetValue("HiddenPlayerInfo", g_MPT_MarkHidden and "T" or "F");
		Network.BroadcastPlayerInfo(localPlayerID);
	end
end

-- MPT_PlayerMark_LoadSettings()：读 Settings 存档刷新 g_MPT_MarkHidden 并应用 UI+广播
--   （无存档/字段缺失 → 默认 true 开启隐身；读完广播一次保证他人视角即时生效）
--   注：真实读库入口是 LoadFromDisk（LoadComposite 一次读回 Players+Settings）；
--   本函数保留为打开面板时的独立刷新（读复合组 Settings 字段）。
function MPT_PlayerMark_LoadSettings()
	MPT_Storage_LoadComposite(PLAYERMARK_STORAGE_FILE, { "Settings" }, function(settings)
		if type(settings) == "table" and type(settings.HiddenSqlMark) == "boolean" then
			g_MPT_MarkHidden = settings.HiddenSqlMark;
		else
			g_MPT_MarkHidden = true;	-- 默认开启隐身（继承 1.67）
		end
		MPT_PlayerMark_ApplyHiddenMarkUI();
		-- 条目4.9：双页签按钮（存储标签/房间玩家）
		Controls.MarkSavedTabButton:RegisterCallback(Mouse.eLClick, function() MPT_PlayerMark_SelectTab("saved"); end);
		Controls.MarkRoomTabButton:RegisterCallback(Mouse.eLClick, function() MPT_PlayerMark_SelectTab("room"); end);
		MPT_PlayerMark_BroadcastHiddenMark();
	end);
end

-- MPT_PlayerMark_OnHiddenMarkCheck()：复选框勾选回调（NoStateChange 手动维护勾选态）
--   取反 → 广播 → 落盘（复合写 Players+Settings）→ 重刷 UI
function MPT_PlayerMark_OnHiddenMarkCheck()
	g_MPT_MarkHidden = not g_MPT_MarkHidden;
	MPT_PlayerMark_ApplyHiddenMarkUI();
	MPT_PlayerMark_BroadcastHiddenMark();
	MPT_Storage_SaveComposite(PLAYERMARK_STORAGE_FILE, {
		Players = g_PlayerMarkList,
		Settings = { HiddenSqlMark = g_MPT_MarkHidden },
	}, function(ok)
		if not ok then
			print("MPT_PlayerMark: 隐身设置落盘失败（存储管线回调 false）");
		end
	end);
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
-- MPT_PlayerMark_SelectTab(tab)：Tab 台切换——"saved"=存储标签 / "room"=房间玩家。
--   文字颜色随选中态变化（对齐 CreateTabs/TabSupport.lua 逻辑）：未选中用默认浅白
--   0xFFefe7e1，选中用深色 0xFF331D05（同 GreatPeoplePopup 配色）；背景覆盖控件显隐。
-- ============================================================================
local m_tabDefaultFontColor	: number = UI.GetColorValueFromHexLiteral(0xFFefe7e1);
local m_tabSelectedFontColor	: number = UI.GetColorValueFromHexLiteral(0xFF331D05);

function MPT_PlayerMark_SelectTab(tab : string)
	local isSaved = (tab == "saved");
	Controls.PlayerMarkSavedContent:SetHide(not isSaved);
	Controls.PlayerMarkRoomContent:SetHide(isSaved);
	-- 存储标签按钮
	local savedText = Controls.MarkSavedTabButton:GetTextControl();
	if savedText ~= nil then savedText:SetColor(isSaved and m_tabSelectedFontColor or m_tabDefaultFontColor); end
	Controls.MarkSavedTabSelected:SetHide(not isSaved);
	Controls.MarkSavedTabButton:SetSelected(isSaved);
	-- 房间玩家按钮
	local roomText = Controls.MarkRoomTabButton:GetTextControl();
	if roomText ~= nil then roomText:SetColor((not isSaved) and m_tabSelectedFontColor or m_tabDefaultFontColor); end
	Controls.MarkRoomTabSelected:SetHide(isSaved);
	Controls.MarkRoomTabButton:SetSelected(not isSaved);
end

-- ============================================================================
-- MPT_PlayerMark_IsMarked(nid)：该玩家网络ID是否已在 g_PlayerMarkList 中被标记。
-- ============================================================================
local function MPT_PlayerMark_IsMarked(nid : string)
	if nid == nil or nid == "" then return false; end
	for _, rec in ipairs(g_PlayerMarkList) do
		if rec.Id == nid then return true; end
	end
	return false;
end

-- ============================================================================
-- MPT_PlayerMark_RebuildRoomList()：重建「房间玩家」列表（读 Gameplay 侧 Game:SetProperty 快照）。
--   显示所有非自己玩家（含观察者/不在线）；未标记显示添加按钮；文明头像+在线状态。
-- ============================================================================
function MPT_PlayerMark_RebuildRoomList()
	if m_playerMarkRoomIM == nil then return; end
	m_playerMarkRoomIM:ResetInstances();
	if Controls.PlayerMarkRoomListStack == nil then return; end

	-- ========== 临时测试数据：20 个虚拟玩家（调整控件尺寸用，调完即删） ==========
	-- 用测试数据替代 Game:GetProperty 读档，便于调控件尺寸/滚动/添加按钮显隐。
	--   字段对齐真实快照 {nid,name,leader}，额外加 online/marked 两个测试专用布尔：
	--   snap.online 非 nil 时优先用（替代实时 PlayerConfigurations 判断）；否则实时判断。
	--   snap.marked 非 nil 时优先用（替代 MPT_PlayerMark_IsMarked）；否则按 nid 查 g_PlayerMarkList。
	local testList : table = {};
	local testSnap : table = {};
	local leaderPool : table = { "TRAJAN", "CLEOPATRA", "GANDHI", "VICTORIA", "ALEXANDER", "SALADIN", "PETER", "HOJO", "KUPE", "TAMAR" };
	for i = 1, 20 do
		local pid : number = 1000 + i;
		table.insert(testList, pid);
		testSnap[pid] = {
			nid = "76561198" .. string.format("%08d", i),
			name = "测试玩家" .. i,
			leader = leaderPool[(i - 1) % #leaderPool + 1],
			online = (i % 2 == 0),	-- 偶数在线、奇数离线
			marked = (i % 3 == 0),	-- 每 3 个标记一个（隐藏添加按钮）
		};
	end
	-- ========== 测试数据结束 ==========

	local localPlayer = Game.GetLocalPlayer();
	local count : number = 0;
	for _, playerID in ipairs(testList) do
		if playerID ~= localPlayer then	-- 排除自己（用户确认）
			local snap = testSnap[playerID];
			if type(snap) == "table" then
				local inst = m_playerMarkRoomIM:GetInstance();
				if inst ~= nil then
					inst.RoomPlayerName:SetText(Locale.Lookup(snap.name or ""));
					local leader = snap.leader or "";
					if leader ~= "" then
						inst.RoomLeaderIcon:SetText("[ICON_ICON_" .. leader .. "]");
					else
						inst.RoomLeaderIcon:SetText("[ICON_ICON_LEADER_DEFAULT]");
					end
					-- 在线状态：测试数据 snap.online 优先，否则实时 PlayerConfigurations 判断
					local online : boolean = false;
					if snap.online ~= nil then
						online = snap.online;
					else
						local cfg = PlayerConfigurations[playerID];
						if cfg ~= nil then
							online = cfg:IsAlive() or (GameConfiguration.IsNetworkMultiplayer() and Network.IsPlayerConnected(playerID) and cfg:GetSlotStatus() == 4);
						end
					end
					inst.RoomConnLabel:SetText(online and "[icon_CheckmarkBlue]在线" or "[icon_Exclamation]离线");
					-- 添加按钮：未标记显示点击打开弹窗，已标记隐藏
					local isMarked : boolean;
					if snap.marked ~= nil then
						isMarked = snap.marked;
					else
						isMarked = MPT_PlayerMark_IsMarked(snap.nid);
					end
					if isMarked then
						inst.RoomAddMarkButton:SetHide(true);
					else
						inst.RoomAddMarkButton:SetHide(false);
						inst.RoomAddMarkButton:SetVoid1(playerID);
						local nid = snap.nid; local nm = snap.name;
						inst.RoomAddMarkButton:RegisterCallback(Mouse.eLClick, function() MPT_PlayerMark_OpenAddPopup(nid, Locale.Lookup(nm or "")); end);
					end
					count = count + 1;
				end
			end
		end
	end
	Controls.PlayerMarkRoomEmptyLabel:SetHide(count > 0);
	Controls.PlayerMarkRoomListStack:CalculateSize();
	if Controls.PlayerMarkRoomListScrollPanel ~= nil then
		Controls.PlayerMarkRoomListScrollPanel:CalculateSize();
	end
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
		MPT_PlayerMark_Notify(PlayerMarkNoticeTitleStr, PlayerMarkNameEmptyStr);
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
-- 可选 presetId/presetName：预填网络ID与昵称（前端为准备房间玩家名按钮联动；游戏内无此入口，保留参数兼容）
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
-- 条目11 差异1：删 MPT_PlayerMark_OnSlotNameClick（准备房间槽位「玩家名」热区按钮联动，
-- 游戏内无此入口）。原函数（前端 StagingRoom.lua 条目4.4 分区保留）：
-- function MPT_PlayerMark_OnSlotNameClick(playerID : number)
-- 	if playerID == Network.GetLocalPlayerID() then return; end	-- 不标记自己
-- 	local pConfig = PlayerConfigurations[playerID];
-- 	if pConfig == nil then return; end
-- 	local nid = pConfig:GetNetworkIdentifer();
-- 	if nid == nil or nid == "" then return; end
-- 	MPT_PlayerMark_OpenAddPopup(nid, Locale.Lookup(pConfig:GetPlayerName()));
-- end
-- ----------------------------------------------------------------------------

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
		MPT_PlayerMark_Notify(PlayerMarkExistsTitleStr, PlayerMarkExistsTextStr);
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
-- 打开：显示上下文/遮挡层/面板后真实读盘，回调到达后重建列表/编辑区（面板已关也无碍）。
-- 关闭：先收添加弹窗；有未保存改动先弹确认（确认后递归关闭）；幂等。
-- 条目11 差异5：AddUserInterfaces 上下文引擎以 isHidden=true 加载（InGame.lua 硬编码挂
--   AdditionalUserInterfaces），故 Open 首部 ContextPtr:SetHide(false)、Close 尾部
--   ContextPtr:SetHide(true)；面板内控件的显隐逻辑与前端一致。
-- ============================================================================
function MPT_PlayerMark_Open()
	ContextPtr:SetHide(false);	-- 条目11：先显示上下文（默认隐藏），控件才渲染
	Controls.PlayerMarkModalBlocker:SetHide(false);
	Controls.PlayerMarkPanel:SetHide(false);
	UI.PlaySound("UI_Screen_Open");
	MPT_PlayerMark_LoadFromDisk(function()
		MPT_PlayerMark_LoadSettings();	-- 条目4.8续：读隐身设置存档并应用 UI+广播（异步回调，不阻塞）
		MPT_PlayerMark_RebuildRoomList();	-- 条目4.9：房间玩家列表（读 Gameplay 快照）
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
	ContextPtr:SetHide(true);	-- 条目11：连同上下文一起隐藏（输入处理也随之停止，见 EndGameMenu 同款模式）
	UI.PlaySound("UI_Screen_Close");
end

-- ============================================================================
-- 条目11 差异3：删 MPT_PlayerMark_ResetOnExit（退房硬重置——前端 Lua 状态跨房间存续
-- 才需要；游戏内退回主菜单即销毁 UI 状态，且 Open 每次真实读盘重建，无残留问题）。
-- ----------------------------------------------------------------------------

-- ============================================================================
-- 条目4.4：控件注册（复选框默认全勾选；排序按钮文案默认「最新修改在前」；搜索占位文本按焦点/内容显隐）
-- 条目11 差异6：删 PlayerMarkButton 打开按钮回调注册（本 Context XML 无此控件，
--   打开入口见文件末尾 LuaEvents.MPT_PlayerMark_Toggle）。
-- ============================================================================
-- 原前端代码（StagingRoom.lua 条目4.4 分区保留）：
-- Controls.PlayerMarkButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_Open);
-- Controls.PlayerMarkButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
-- ----------------------------------------------------------------------------
Controls.PlayerMarkCloseButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_Close);
Controls.PlayerMarkModalBlocker:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_Close);
Controls.PlayerMarkHiddenMarkCheck:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_OnHiddenMarkCheck);	-- 条目4.8续：隐身开关
MPT_PlayerMark_ApplyHiddenMarkUI();	-- 条目4.8续：初始勾选态（默认隐身；LoadSettings 读盘后会再刷）

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
-- 条目11：确认/提示弹窗按钮（自研 MPT_PMConfirmPopup，定义见本分区上方）
Controls.MPT_PMConfirmOkButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_ConfirmOkClick);
Controls.MPT_PMConfirmCancelButton:RegisterCallback(Mouse.eLClick, MPT_PlayerMark_ConfirmCancelClick);
end	-- 条目4.4 副本 do 块结束（与前端同构）

-- ############################################################################
-- 条目11：游戏内适配——打开入口（LuaEvents）与 ESC 输入处理
-- ############################################################################

-- ============================================================================
-- MPT_PlayerMark_Toggle()：面板开关（供 QuickPanel 展开区「玩家标记」按钮跨 Context 触发）。
-- 用法：QuickPanel 按钮回调里 LuaEvents.MPT_PlayerMark_Toggle()。
-- ============================================================================
function MPT_PlayerMark_Toggle()
	if Controls.PlayerMarkPanel:IsHidden() then
		MPT_PlayerMark_Open();
	else
		MPT_PlayerMark_Close();
	end
end
LuaEvents.MPT_PlayerMark_Toggle.Add(MPT_PlayerMark_Toggle);

-- ============================================================================
-- 条目4.9：房间玩家列表刷新——玩家加入/离开/对局信息更新时重建（数据源为 Gameplay 侧 Game:SetProperty 快照）
-- ============================================================================
-- 只订阅存在的引擎事件（PlayerJoined 不存在会索引 nil；用 PlayerInfoChanged——玩家配置变化含加入。
--   每个事件 nil 守卫，避免任一不存在的键导致 main chunk 崩溃。）
local function MPT_RoomRefreshIfOpen() if Controls.PlayerMarkPanel ~= nil and not Controls.PlayerMarkPanel:IsHidden() then MPT_PlayerMark_RebuildRoomList(); end end;
if Events.PlayerInfoChanged ~= nil then Events.PlayerInfoChanged.Add(MPT_RoomRefreshIfOpen); end
if Events.MultiplayerPostPlayerDisconnected ~= nil then Events.MultiplayerPostPlayerDisconnected.Add(MPT_RoomRefreshIfOpen); end
if Events.GameInfoUpdated ~= nil then Events.GameInfoUpdated.Add(MPT_RoomRefreshIfOpen); end

-- ============================================================================
-- 输入处理（EndGameMenu.lua:1294 同款模式）：ESC 优先关闭本面板——
--   添加弹窗开 → 先关弹窗；面板开 → 关面板；均消费（return true）。
--   其余按键/面板未开时 return false 放行，不挡游戏菜单与其他界面。
--   上下文隐藏时引擎不派发输入，故面板关闭后本处理自然停止。
-- ============================================================================
local function MPT_PlayerMark_OnInput(pInputStruct : table)
	local uiMsg : number = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyUp then
		local key : number = pInputStruct:GetKey();
		if key == Keys.VK_ESCAPE then
			-- 确认/提示弹窗开 → 先关（等同取消；确认弹窗的确定回调不清，恢复面板后仍可再确认）
			if not Controls.MPT_PMConfirmPopup:IsHidden() then
				MPT_PlayerMark_ConfirmCancelClick();
				return true;
			end
			if not Controls.PlayerMarkEditPopup:IsHidden() then
				MPT_PlayerMark_CloseAddPopup();
				return true;
			end
			if not Controls.PlayerMarkPanel:IsHidden() then
				MPT_PlayerMark_Close();
				return true;
			end
		end
	end
	return false;
end
ContextPtr:SetInputHandler(MPT_PlayerMark_OnInput, true);
