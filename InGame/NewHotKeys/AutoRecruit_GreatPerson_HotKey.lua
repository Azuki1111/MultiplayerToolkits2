-- ===========================================================================
-- 条目27：伟人自动招募（移植 1.65 NHK/UI/AutoRecruit_GreatPerson_HotKey.lua）
--
-- 功能：Shift+K 切换自动招募模式。开启后订阅 GreatPeoplePointsChanged，每次伟人点数
--   变化即重算时间线，对「可招募 且（仅自己可招募 或 自己是该类别点数最高者）」的
--   伟人立即发起招募（UI.RequestPlayerOperation RECRUIT_GREAT_PERSON）；
--   LaunchBar 伟人按钮挂 GPA_Icon 指示灯标示模式状态（再按 Shift+K 关闭并退订）。
--
-- 注入机制：AddUserInterfaces 迷你上下文（同条目12/20 机制），GPA_Icon 控件
--   LateInitialize 时 ChangeParent 挂到 /InGame/LaunchBar/GreatPeopleButton。
-- 与 1.65 差异（逐条留痕）：
--   1) 零全局污染：1.65 泄漏 PopulateData/OnRecruitButtonClick 等 6 个全局，本文件全部
--      local（条目18 同款约定）
--   2) GPA_Icon 挂载加 m_attached 幂等守卫（防 LoadScreenClose 多次触发重复 ChangeParent，
--      项目条目5/12 同款惯例；1.65 无守卫）
--   3) 点数类别表 nil 防御：PointsByClass[classID] 空表/缺项时跳过该伟人（1.65 直接
--      [1] 索引，全灭等极端局踩空崩脚）
--   4) 【不移植】1.65 已注释停用的手动招募键 HotKey_TPT_Recruit（Shift+L 死代码）
-- 相对 1.65 的让位（criteria 层，modinfo 配置）：1.65 在装时本上下文不加载（其原版
--   Lua 继续服务，避免双重招募请求）。
-- 注册：AddUserInterfaces(900) + ImportFiles(900)，criteria=NHK_MPT
-- ===========================================================================

include("GameCapabilities");

local m_AutoRecruitActionId : number = Input.GetActionId("HotKey_TPT_AutoRecruit");

local IsAuto : boolean = false;		-- 自动招募模式
local m_attached : boolean = false;	-- GPA_Icon 挂载守卫

-- ===========================================================================
-- 重算伟人时间线与全玩家点数表（结构照抄原版 GreatPeoplePopup，1.65 原样）
-- ===========================================================================
local function PopulateData(data : table)
	if data == nil then
		return;
	end

	local displayPlayerID : number = Game.GetLocalPlayer();
	if (displayPlayerID == -1) then
		return;
	end

	local pGreatPeople : table = Game.GetGreatPeople();
	if pGreatPeople == nil then
		return;
	end

	local pTimeline : table = pGreatPeople:GetTimeline()

	for i, entry in ipairs(pTimeline) do

		local canRecruit : boolean = false;
		local recruitCost : number = entry.Cost;
		local onlyLocalPlayerCanRecruit : boolean = true;

		if (entry.Individual ~= nil) then
			if (Players[displayPlayerID] ~= nil) then
				canRecruit = pGreatPeople:CanRecruitPerson(displayPlayerID, entry.Individual);
			end

			for _, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
				if playerID ~= Game.GetLocalPlayer() then
					if pGreatPeople:CanRecruitPerson(playerID, entry.Individual) then
						onlyLocalPlayerCanRecruit = false
					end
				end
			end
		end

		local kPerson : table = {
			IndividualId					= entry.Individual,
			ClassId							= entry.Class,
			CanRecruit						= canRecruit,
			RecruitCost						= recruitCost,
			OnlyLocalPlayerCanRecruit		= onlyLocalPlayerCanRecruit,
		};
		table.insert(data.Timeline, kPerson);
	end

	for classInfo in GameInfo.GreatPersonClasses() do
		local classID : number = classInfo.Index;
		local pointsTable : table = {};
		local players = Game.GetPlayers{Major = true, Alive = true};
		for i, player in ipairs(players) do
			local playerPoints : table = {
				PointsTotal			= player:GetGreatPeoplePoints():GetPointsTotal(classID),
				PlayerID			= player:GetID()
			};
			table.insert(pointsTable, playerPoints);
		end
		table.sort(pointsTable, function(a, b)
			return a.PointsTotal > b.PointsTotal;
		end);
		data.PointsByClass[classID] = pointsTable;
	end
end

-- ===========================================================================
-- 发起招募请求（1.65 原样）
-- ===========================================================================
local function OnRecruitButtonClick(individualID : number)
	local pLocalPlayer : table = Players[Game.GetLocalPlayer()];
	if (pLocalPlayer ~= nil) then
		local kParameters : table = {};
		kParameters[PlayerOperations.PARAM_GREAT_PERSON_INDIVIDUAL_TYPE] = individualID;
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.RECRUIT_GREAT_PERSON, kParameters);
	end
end

-- ===========================================================================
-- 自动招募主体：点数变化即重算，对满足条件的伟人立即招募
-- 条件 = 可招募 且（仅自己可招募 或 自己是该类别点数最高者）；条目27优化③类别表 nil 防御
-- ===========================================================================
local function OnGreatPeoplePointsChanged(playerID : number)
	local kData : table = {
		Timeline		= {},
		PointsByClass	= {},
	};

	PopulateData(kData);	-- do not use past data

	for i, kPerson in ipairs(kData.Timeline) do
		if (HasCapability("CAPABILITY_GREAT_PEOPLE_CAN_RECRUIT") and kPerson.CanRecruit and kPerson.RecruitCost ~= nil) then
			local tClassPoints : table = kData.PointsByClass[kPerson.ClassId];
			if tClassPoints ~= nil and tClassPoints[1] ~= nil then
				if kPerson.OnlyLocalPlayerCanRecruit or tClassPoints[1].PlayerID == Game.GetLocalPlayer() then
					OnRecruitButtonClick(kPerson.IndividualId)		-- 立即招募
				end
			end
		end
	end
end

-- ===========================================================================
-- 输入分发：Shift+K 切换自动招募模式（开=订阅点数变化+立即结算一次+亮灯；关=全反）
-- ===========================================================================
local function OnInputActionTriggered(actionId : number)
	if actionId == m_AutoRecruitActionId then
		IsAuto = not IsAuto;
		if IsAuto then
			Events.GreatPeoplePointsChanged.Add(OnGreatPeoplePointsChanged);
			OnGreatPeoplePointsChanged()
			Controls.GPA_Icon:SetHide(false)
		else
			Events.GreatPeoplePointsChanged.Remove(OnGreatPeoplePointsChanged);
			Controls.GPA_Icon:SetHide(true)
		end
		UI.PlaySound("Play_MP_Game_Launch_Timer_Beep")
		return
	end
end

-- ===========================================================================
-- GPA_Icon 指示灯挂载到 LaunchBar 伟人按钮（LoadScreenClose 后面板才就绪）
-- ===========================================================================
local function LateInitialize()
	if m_attached then
		return;
	end
	local Ctr : table = ContextPtr:LookUpControl("/InGame/LaunchBar/GreatPeopleButton")
	if Ctr ~= nil then
		Controls.GPA_Icon:ChangeParent(Ctr)
		m_attached = true;
	end
end

-- ===========================================================================
-- 初始化（1.65 原样：文件加载即注册事件）
-- ===========================================================================
local function Initialize()
	Events.InputActionTriggered.Add(OnInputActionTriggered);
	Events.LoadScreenClose.Add(LateInitialize)
end
Initialize();
