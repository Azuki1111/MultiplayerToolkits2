-- ===========================================================================
--	Support functions for formatting of Tech and Civic areas which are used
--	within their "Choosers" and their panel version within the "World Tracker"
-- ===========================================================================
-- 条目14：真实科文进度（TCP）——本文件同名覆盖原版 Base/Assets/UI/TechAndCivicSupport.lua
-- 移植自联机工具箱 1.67（工坊 3693899014 TCP/TechAndCivicSupport.lua），被 7 个 UI context
-- include（TechTree/CivicsTree/ResearchChooser/CivicsChooser/EventPopup/TechCivicCompletedPopup/WorldTracker），
-- 只能整文件同名覆盖（ImportFiles LoadOrder 100010 压过 1.67 的 2001）。
-- 相对 1.67 的优化：
--   - 删调试代码（printTable/print）、函数命名 MPT 前缀、缓存变量 local 化；
--   - 文本预加载缓存（带参数 tag 拆 PRE/SUF + Lua .. 拼接）；
--   - 去掉冗余 Boosted 字段（原版已有同语义 BoostTriggered）；
--   - 「可凭 boost 完成」图标走数据层：GetResearchData/GetCivicData 在 Enough 时直接给
--     kData.Name 追加 [icon_You]（所有消费 kData.Name 的显示点自动生效，无需逐个覆盖
--     ResearchChooser/CivicsChooser 显示函数，1.67 需改 4 个文件、本方案只需本文件 +
--     TechTree/CivicsTree 两个节点渲染覆盖）。
-- ===========================================================================

include("InstanceManager");
include("SupportFunctions");
include("Civ6Common");

-- ===========================================================================
-- 条目14 分区：文本预加载缓存（无参数纯文本 tag，运行时直接引用变量、不内联 Locale.Lookup）
-- ===========================================================================
local MPT_ProgressPRE	: string = Locale.Lookup("LOC_MPT_TCP_PROGRESS_PRE")			-- "研究进度："
local MPT_ProgressSUF	: string = Locale.Lookup("LOC_MPT_TCP_PROGRESS_SUF")			-- " / "
local MPT_EstimatesPRE	: string = Locale.Lookup("LOC_MPT_TCP_ESTIMATES_PRE")			-- "[Newline]获得提升后："
local MPT_EstimatesSUF	: string = Locale.Lookup("LOC_MPT_TCP_ESTIMATES_SUF")			-- " / "
local MPT_EnoughStr		: string = Locale.Lookup("LOC_MPT_TCP_ENOUGH")				-- "[Newline][icon_You]可通过获得提升而完成"

-- ===========================================================================
-- 条目14 分区：真实科文进度辅助函数
-- ===========================================================================
MPT_IconEnough	= "[icon_You]";		-- 可凭 boost 完成时追加的图标标记（与文本 tag 内 [icon_You] 大小写统一）

-- 加速缓存（仅本玩家、每回合一次；GameEffects 遍历较重）
local MPT_cachedTurn			: number = -1;
local MPT_cachedExtraTechBoost	: number = 0;
local MPT_cachedExtraCivicBoost	: number = 0;

-- ===========================================================================
-- 获取修改器附加的科技/市政加速（EFFECT_ADJUST_TECHNOLOGY_BOOST / EFFECT_ADJUST_CIVIC_BOOST，
-- 如领袖能力 +x% 研究加速），结果为百分比数值（如 10 表示 +10%）。
-- 仅对本玩家求值并缓存，跨回合自动失效重算。
-- 用法：MPT_GetExtraBoostFromModifiers(Game.GetLocalPlayer(), true)  -- isTech=true 科技，false 市政
-- ===========================================================================
function MPT_GetExtraBoostFromModifiers(playerID:number, isTech:boolean)
	if GameEffects == nil then		-- 防御：GameEffects API 不可用（某些 UI context）时返回 0
		return 0;
	end
	-- Only need to check for the local players.
	local cur : number = Game.GetCurrentGameTurn();
	if playerID ~= Game.GetLocalPlayer() then
		return 0;
	end
	if cur == MPT_cachedTurn then
		if isTech then
			return MPT_cachedExtraTechBoost;
		else
			return MPT_cachedExtraCivicBoost;
		end
	end

	MPT_cachedTurn = cur;
	local techRatio		: number = 0;
	local civicRatio	: number = 0;
	for _, modifierObjID in ipairs(GameEffects.GetModifiers()) do
		local isActive	: boolean = GameEffects.GetModifierActive(modifierObjID);
		local ownerObjID : number = GameEffects.GetModifierOwner(modifierObjID);
		if isActive and MPT_IsOwnerRequirementSetMet(modifierObjID) and (GameEffects.GetObjectsPlayerId(ownerObjID) == playerID) then
			-- The modifier is active, belongs to the given player, and owner requirement set is met.
			local modifierDef : table = GameEffects.GetModifierDefinition(modifierObjID);
			local modifierRow : table = modifierDef and GameInfo.Modifiers[modifierDef.Id] or nil;
			local modifierType : string = modifierRow and modifierRow.ModifierType or nil;
			if modifierType then
				local modifierTypeRow : table = GameInfo.DynamicModifiers[modifierType];
				if modifierTypeRow then
					if modifierTypeRow.EffectType == 'EFFECT_ADJUST_TECHNOLOGY_BOOST' then
						techRatio = techRatio + modifierDef.Arguments.Amount;
					end
					if modifierTypeRow.EffectType == 'EFFECT_ADJUST_CIVIC_BOOST' then
						civicRatio = civicRatio + modifierDef.Arguments.Amount;
					end
				end
			end
		end
	end
	MPT_cachedExtraTechBoost	= techRatio;
	MPT_cachedExtraCivicBoost	= civicRatio;
	if isTech then
		return MPT_cachedExtraTechBoost;
	else
		return MPT_cachedExtraCivicBoost;
	end
end

-- ===========================================================================
-- 判断 modifier 的 owner requirement set 是否已满足（无 requirement 时视为满足）
-- 用法：MPT_IsOwnerRequirementSetMet(modifierObjId)
-- ===========================================================================
function MPT_IsOwnerRequirementSetMet(modifierObjId:number)
	if modifierObjId ~= nil and modifierObjId ~= 0 then
		local ownerRequirementSetId = GameEffects.GetModifierOwnerRequirementSet(modifierObjId);
		if ownerRequirementSetId then
			return GameEffects.GetRequirementSetState(ownerRequirementSetId) == "Met";
		end
	end
	return true;
end

-- ===========================================================================
-- 数值取整到 0.1（非整数时保留 1 位小数，用于进度显示）
-- 用法：MPT_GetNumfone(num)
-- ===========================================================================
function MPT_GetNumfone(num:number)
	if num % 1 ~= 0 then
		num = math.floor(num * 10) / 10;
	end
	return num;
end


-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local DATA_FIELD_UNLOCK_IM		:string = "_UnlockIM";
local MAX_BEFORE_TRUNC_BOOST_MSG:number = 220;			-- Size in which boost messages will be truncated and tooltipified
local SIZE_ICON_CIVIC_LARGE		:number = 38;
local SIZE_ICON_RESEARCH_LARGE	:number = 38;
local MAX_ICONS_BEFORE_OVERFLOW	:number = 6;

-- ===========================================================================
--	MEMBERS
--	These are instanced for each file that adds this support file.
-- ===========================================================================
local m_kGovernmentData		:table; -- Used to cache government info.
local m_kCivicsData			:table; -- Used to cache civics info.
local m_kTechsData			:table; -- Used to cache tech info.

-- Utility Methods

function GetUnlockablesForCivic_Cached(civicType, playerId)

	--Set player ID to -1 if it is invalid in any way.
	local playerIndex = playerId;
	if playerIndex == nil then
		playerIndex = -1;
	end

	if m_kCivicsData == nil or table.count(m_kCivicsData)==0 then
		m_kCivicsData = {};
		for i = 0, GameDefines.MAX_PLAYERS, 1 do
			m_kCivicsData[i] = {};
		end
	end

	if m_kCivicsData[playerIndex][civicType] ~= nil then
		return m_kCivicsData[playerIndex][civicType];
	end

	local results:table = GetUnlockablesForCivic(civicType, playerId);
	m_kCivicsData[playerIndex][civicType] = results;
	return results;
end

-- ===================================================================================================================================
--	Get the unlockables for a tech, through the 'cached' table.
--	If the entry in the table is not initialized, it will be added.
--	This optionally accepts a database generated table of all the player's unlockables, this
--	should only be passed in when generating the cache.  While the game is running, the cache should contain all the
--	necessary entries.
-- ===================================================================================================================================
function GetUnlockablesForTech_Cached(techType, playerId, playerUnlockables)

	--Set player ID to -1 if it is invalid in any way.
	local playerIndex = playerId;
	if playerIndex == nil then
		playerIndex = -1;
	end

	if m_kTechsData == nil or table.count(m_kTechsData)==0 then
		m_kTechsData = {};
		for i = 0, GameDefines.MAX_PLAYERS-1, 1 do
			m_kTechsData[i] = {};
		end
	end

	if m_kTechsData[playerIndex][techType] ~= nil then
		return m_kTechsData[playerIndex][techType];
	end

	local results:table = GetUnlockablesForTech(techType, playerId, playerUnlockables);
	m_kTechsData[playerIndex][techType] = results;
	return results;
end

-- ===================================================================================================================================
--	RETURNS the string name of an unlocked icon based on the type passed in
-- ===================================================================================================================================
function GetUnlockIcon( typeName :string )
	local icon :string = "ICON_TECHUNLOCK_0";

	local typeInfo :table = GameInfo.Types[typeName];
	if(typeInfo) then
		local icons_by_kind = {
			KIND_PROJECT = "ICON_TECHUNLOCK_0",
			KIND_WONDER = "ICON_TECHUNLOCK_0",
			KIND_BUILDING = "ICON_TECHUNLOCK_1",
			KIND_DISTRICT = "ICON_TECHUNLOCK_2",
			KIND_IMPROVEMENT = "ICON_TECHUNLOCK_3",
			KIND_UNIT = "ICON_TECHUNLOCK_4",
			KIND_RESOURCE = "ICON_TECHUNLOCK_5",
			KIND_GOVERNMENT = "ICON_TECHUNLOCK_6",
			KIND_ROUTE = "ICON_TECHUNLOCK_3",
			KIND_AGREEMENT = "ICON_TECHUNLOCK_8",
			KIND_POLICY = "ICON_TECHUNLOCK_9",
		};

		if(typeInfo.Kind == "KIND_POLICY") then
			local policy = GameInfo.Policies[typeName];
			local slotType = policy and policy.GovernmentSlotType or nil;
					
			if(slotType == "SLOT_MILITARY" ) then
				icon = "ICON_TECHUNLOCK_10";
			elseif(slotType == "SLOT_DIPLOMATIC" ) then
				icon = "ICON_TECHUNLOCK_11";
			elseif(slotType == "SLOT_ECONOMIC" ) then
				icon = "ICON_TECHUNLOCK_12";
			elseif(slotType == "SLOT_WILDCARD" or slotType == "SLOT_GREAT_PERSON") then
				icon = "ICON_TECHUNLOCK_9";
			else
				icon = icons_by_kind["KIND_POLICY"];
			end
		else
			if typeInfo.Kind == "KIND_BUILDING" then
				for row in GameInfo.Buildings() do
					if row.BuildingType == typeInfo.Type then
						if row.IsWonder ~= nil and row.IsWonder == true then
							return icons_by_kind["KIND_WONDER"];
						else
							return icons_by_kind[typeInfo.Kind]
						end
					end
				end
			else
				if(typeInfo.Kind == "KIND_DIPLOMATIC_ACTION") then
					icon = "ICON_TECHUNLOCK_8";
				else
					icon = icons_by_kind[typeInfo.Kind];
				end
			end
		end
	end
	
	return icon;
end

-- ===========================================================================
--
-- ===========================================================================
function GetGovernmentData()
	if m_kGovernmentData == nil or table.count(m_kGovernmentData)==0 then
		m_kGovernmentData = {};
		for row in GameInfo.Governments() do			
			local governmentType	:string = row.GovernmentType;
			local slotMilitary		:number = 0;
			local slotEconomic		:number = 0;
			local slotDiplomatic	:number = 0;
			local slotWildcard		:number = 0;
			for entry in GameInfo.Government_SlotCounts() do
				if (governmentType == entry.GovernmentType) then
					local slotType = entry.GovernmentSlotType;				
					if(slotType == "SLOT_MILITARY") then slotMilitary = slotMilitary + entry.NumSlots;
					elseif(slotType == "SLOT_ECONOMIC") then slotEconomic = slotEconomic + entry.NumSlots;
					elseif(slotType == "SLOT_DIPLOMATIC") then slotDiplomatic = slotDiplomatic + entry.NumSlots;
					elseif(slotType == "SLOT_WILDCARD" or slotType =="SLOT_GREAT_PERSON") then slotWildcard	= slotWildcard + entry.NumSlots;
					end
				end
			end

			m_kGovernmentData[governmentType] = {
				Name				= row.Name,
				NumSlotMilitary		= slotMilitary,
				NumSlotEconomic		= slotEconomic,
				NumSlotDiplomatic	= slotDiplomatic,
				NumSlotWildcard		= slotWildcard
			}
		end
	end

	return m_kGovernmentData;	
end

function ResetOverflowArrow( kItemInstance:table )
	if kItemInstance == nil then
		return;
	end
	if kItemInstance.PageTurnerImage == nil then
		return;
	end
	kItemInstance.PageTurnerImage:FlipX(false);
	kItemInstance.UnlockPageTurner:SetHide(true);
	kItemInstance.UnlockPageTurner:ClearCallback(Mouse.eLClick);
end

function OnOverflowArrowPressed( kItemInstance:table, nUnlockableOffset:number )
	local unlockables :table = kItemInstance.UnlockStack:GetChildren();
	local overflowPage :boolean = kItemInstance.PageTurnerImage:IsFlippedHorizontal();
	kItemInstance.PageTurnerImage:FlipX(not overflowPage);
	for i=nUnlockableOffset+1, #unlockables, 1 do
		unlockables[i]:SetHide(not unlockables[i]:IsHidden());
	end
	kItemInstance.UnlockStack:ReprocessAnchoring();
end

function HandleOverflow( numUnlockables:number, kItemInstance:table, numMaxVisible:number, numMaxPerPage:number )
	if kItemInstance == nil then
		return nil;
	end

	kItemInstance.UnlockPageTurner:SetHide(true);

	if numUnlockables <= numMaxVisible then
		return;
	end
	
	local unlockables :table = kItemInstance.UnlockStack:GetChildren();
	-- Stack may contain hidden controls due to InstanceManager use.
	-- Luckily, they should all be pushed to the back of the list due to reparenting.
	-- So, only toggle the visibility states of the last numUnlockables unlocks!
	local nUnlockableOffset :number = #unlockables - numUnlockables;

	kItemInstance.UnlockPageTurner:SetHide(false);
	kItemInstance.UnlockPageTurner:RegisterCallback( Mouse.eLClick, function() OnOverflowArrowPressed(kItemInstance, nUnlockableOffset); end);
	
	for i=nUnlockableOffset+numMaxPerPage+1, #unlockables, 1 do
		unlockables[i]:SetHide(true);
	end
	kItemInstance.UnlockStack:ReprocessAnchoring();
end

-- ===========================================================================
--
-- ===========================================================================
function PopulateUnlockablesForCivic(playerID:number, civicID:number, kItemIM:table, kGovernmentIM:table, callback:ifunction, hideDescriptionIcon:boolean )

	local kCivicData:table = GameInfo.Civics[civicID];
	if kCivicData == nil then
		UI.DataError("Unable to find a civic type in the database with an ID value of #"..tostring(civicID));
		return;
	end

	local governmentData = GetGovernmentData();
	local civicType:string = kCivicData.CivicType;

	-- Unlockables is an array of {type, name}
	local numIcons:number = 0;
	local unlockables = GetUnlockablesForCivic_Cached(civicType, playerID);
	
	if(unlockables and #unlockables > 0) then
		for i,v in ipairs(unlockables) do

			local typeName = v[1];
			local civilopediaKey = v[3];
			local typeInfo = GameInfo.Types[typeName];
		
			if(kGovernmentIM and typeInfo and typeInfo.Kind == "KIND_GOVERNMENT") then

				local unlock = kGovernmentIM:GetInstance();

				local government = governmentData[typeName];
				if(government) then
					unlock.MilitaryPolicyLabel:SetText(tostring(government.NumSlotMilitary));
					unlock.EconomicPolicyLabel:SetText(tostring(government.NumSlotEconomic));
					unlock.DiplomaticPolicyLabel:SetText(tostring(government.NumSlotDiplomatic));
					unlock.WildcardPolicyLabel:SetText(tostring(government.NumSlotWildcard));
					unlock.GovernmentName:SetText(Locale.Lookup(government.Name));
				end	
				local toolTip = ToolTipHelper.GetToolTip(typeName, playerID);
				unlock.GovernmentInstanceGrid:LocalizeAndSetToolTip(toolTip);

				unlock.GovernmentInstanceGrid:RegisterCallback(Mouse.eLClick, callback);

				if(not IsTutorialRunning()) then
					unlock.GovernmentInstanceGrid:RegisterCallback(Mouse.eRClick, function() 
						LuaEvents.OpenCivilopedia(civilopediaKey);
					end);
				end
			else
				local unlockIcon = kItemIM:GetInstance();

				local iconName :string = GetUnlockIcon(typeName);					
				unlockIcon.Icon:SetHide( not unlockIcon.Icon:SetIcon("ICON_"..typeName));	-- Hide if an icon isn't found with that type.

				local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,38);
				if textureSheet ~= nil then
					unlockIcon.UnlockIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
				end

				local toolTip = ToolTipHelper.GetToolTip(typeName, playerID);

				unlockIcon.UnlockIcon:LocalizeAndSetToolTip(toolTip);
			
				if callback ~= nil then		
					unlockIcon.UnlockIcon:RegisterCallback(Mouse.eLClick, callback);
				else
					unlockIcon.UnlockIcon:ClearCallback(Mouse.eLClick);
				end

				if(not IsTutorialRunning()) then
					unlockIcon.UnlockIcon:RegisterCallback(Mouse.eRClick, function() 
						LuaEvents.OpenCivilopedia(civilopediaKey);
					end);
				end
			end

			numIcons = numIcons + 1;
		end
		
	end

	if (kCivicData.Description and hideDescriptionIcon ~= true) then
		local unlockIcon:table	= kItemIM:GetInstance();
		unlockIcon.Icon:SetHide(true); -- foreground icon unnecessary in this case
		local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_TECHUNLOCK_13",38);
		if textureSheet ~= nil then
			unlockIcon.UnlockIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
		end
		unlockIcon.UnlockIcon:LocalizeAndSetToolTip(kCivicData.Description);
		if callback ~= nil then		
			unlockIcon.UnlockIcon:RegisterCallback(Mouse.eLClick, callback);
		else
			unlockIcon.UnlockIcon:ClearCallback(Mouse.eLClick);
		end

		if(not IsTutorialRunning()) then
			unlockIcon.UnlockIcon:RegisterCallback(Mouse.eRClick, function() 
				LuaEvents.OpenCivilopedia(civicType);
			end);
		end

		numIcons = numIcons + 1;
	end

	kItemIM.m_ParentControl:CalculateSize();

	return numIcons;
end


-- ===========================================================================
--
-- ===========================================================================
function PopulateUnlockablesForTech(playerID:number, techID:number, instanceManager:table, callback:ifunction )

	local kTechData:table = GameInfo.Technologies[techID];
	if kTechData==nil then
		UI.DataError("Unable to find a tech type in the database with an ID value of #"..tostring(techID));
		return;
	end

	local techType:string = kTechData.TechnologyType;


	-- Unlockables is an array of {type, name}
	local numIcons:number = 0;
	local unlockables:table = GetUnlockablesForTech_Cached(techType, playerID);

	-- Hard-coded goodness.
	if unlockables and table.count(unlockables) > 0 then
		for i,v in ipairs(unlockables) do

			local typeName	:string = v[1];
			local civilopediaKey = v[3];
			local unlockIcon:table	= instanceManager:GetInstance();
			
			local iconName :string = GetUnlockIcon(typeName);					
			unlockIcon.Icon:SetHide( not unlockIcon.Icon:SetIcon("ICON_"..typeName));	-- Hide if an icon isn't found with that type.
			 
			local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconName,38);
			if textureSheet ~= nil then
				unlockIcon.UnlockIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
			end

			local toolTip :string = ToolTipHelper.GetToolTip(typeName, playerID, nil);
			unlockIcon.UnlockIcon:LocalizeAndSetToolTip(toolTip);
			if callback ~= nil then		
				unlockIcon.UnlockIcon:RegisterCallback(Mouse.eLClick, callback);
			else
				unlockIcon.UnlockIcon:ClearCallback(Mouse.eLClick);
			end

			if(not IsTutorialRunning()) then
				unlockIcon.UnlockIcon:RegisterCallback(Mouse.eRClick, function() 
					LuaEvents.OpenCivilopedia(civilopediaKey);
				end);
			end
		end

		numIcons = numIcons + 1;
	end

	if kTechData.Description then
		local unlockIcon:table	= instanceManager:GetInstance();
		unlockIcon.Icon:SetHide(true); -- foreground icon unnecessary in this case
		local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_TECHUNLOCK_13",38);
		if textureSheet ~= nil then
			unlockIcon.UnlockIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
		end
		unlockIcon.UnlockIcon:LocalizeAndSetToolTip(kTechData.Description);
		if callback ~= nil then		
			unlockIcon.UnlockIcon:RegisterCallback(Mouse.eLClick, callback);
		else
			unlockIcon.UnlockIcon:ClearCallback(Mouse.eLClick);
		end

		if(not IsTutorialRunning()) then
			unlockIcon.UnlockIcon:RegisterCallback(Mouse.eRClick, function() 
				LuaEvents.OpenCivilopedia(kTechData.TechnologyType);
			end);
		end

		numIcons = numIcons + 1;
	end

	return numIcons;
end


-- ===========================================================================
--	Obtain the "active" data, either what is currently being worked on or
--	what just completed.
--	RETURN: active data or NIL
-- ===========================================================================
function GetActiveData( kData:table )
	for _, data in ipairs(kData) do
		if data.IsCurrent or data.IsLastCompleted then
			return data;
		end
	end
	return nil;
end

-- ===========================================================================
--	Returns a custom instance manager for unlocks that will exist in a control.
-- ===========================================================================
function GetUnlockIM( kControl:table )
	local unlockIM :table = kControl[DATA_FIELD_UNLOCK_IM];
	if unlockIM ~= nil then
		unlockIM:ResetInstances();
	else
		-- Create
		unlockIM = InstanceManager:new("UnlockIconInstance", "UnlockIcon", kControl.UnlockStack);
		kControl[DATA_FIELD_UNLOCK_IM] = unlockIM;
	end
	return unlockIM;
end


-- ===========================================================================
--	Show the meters and boost information for a given tech.
-- ===========================================================================
function RealizeMeterAndBoosts( kControl:table, kData:table )
	
	local progress:number = kData.Progress;

	if kData.Boostable then
		local boostString :string = "[NEWLINE]" .. Locale.Lookup(kData.TriggerDesc);
		if  kData.BoostTriggered then
			boostString = Locale.Lookup("LOC_TECH_HAS_BEEN_BOOSTED") .. boostString;	-- Same whether tech/civic
			kControl.IconHasBeenBoosted:SetToolTipString(boostString);
			progress = math.clamp( progress, 0, 1.0 );
		else
			boostString = Locale.Lookup("LOC_TECH_CAN_BE_BOOSTED") .. boostString;		-- Same whether tech/civic
			kControl.IconCanBeBoosted:SetToolTipString( boostString );
			-- ============================================================================
			-- 条目14：boost 进度条显示改为「boost 后预估完成度」（真实进度）
			-- local boostAmount = math.min( (kData.Progress + kData.BoostAmount ), 1.0 );
			local boostAmount = kData.Estimates/kData.Cost;
			-- ----------------------------------------------------------------------------
			kControl.BoostMeter:SetPercent( boostAmount );
		end
		
		TruncateStringWithTooltip(kControl.BoostLabel, MAX_BEFORE_TRUNC_BOOST_MSG, Locale.Lookup(kData.TriggerDesc) )
	end	

	if kData.IsLastCompleted then
		progress = 1.0;
	end

	kControl.IconCanBeBoosted:SetHide( (not ( kData.Boostable and not kData.BoostTrigger)) or kData.IsLastCompleted );
	kControl.IconHasBeenBoosted:SetHide( (not kData.BoostTriggered) or kData.IsLastCompleted );
	kControl.ProgressMeter:SetPercent( progress );
	kControl.BoostLabel:SetHide( (not kData.Boostable) or kData.IsLastCompleted );
	kControl.BoostMeter:SetHide( (not kData.Boostable) or kData.IsLastCompleted or (kData.BoostTriggered) );
end


-- ===========================================================================
--
-- ===========================================================================
function RealizeIcon( kIconControl:table, typeName:string, size:number )
	local textureString :string = "ICON_" .. typeName;
	local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(textureString, size);
	if textureSheet ~= nil then
		kIconControl:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
	else
		UI.DataError("Missing icon '"..tostring(textureString).."' at size "..tostring(size));
	end
end


-- ===========================================================================
--
-- ===========================================================================
function RealizeTurnsLeft( kControl:table, kData:table)
	
	local turnsLeft			:number = (kData == nil) and -1 or kData.TurnsLeft;
	
	-- The UI was only designed to show up to 3 characters in this label
	if turnsLeft > 999 then turnsLeft = 999; end

	local isLastCompleted	:boolean = false;
	local isRepeatable		:boolean = false;

	if kData ~= nil then
		isLastCompleted = kData.IsLastCompleted;
		isRepeatable = kData.Repeatable;
		if isLastCompleted and not isRepeatable then
			kControl.TurnsLeft:SetText( Locale.Lookup("LOC_RESEARCH_CHOOSER_JUST_COMPLETED") );
		else
			if kData.TurnsLeft ~= -1 then
				kControl.TurnsLeft:SetText("[ICON_Turn]" .. tostring(turnsLeft));
			else
				kControl.TurnsLeft:SetText("");
			end
		end
	else
		kControl.TurnsLeft:SetText("");
	end
	
	-- ============================================================================
	-- 条目14：TurnsLeft Tooltip 三档真实进度（进度 / 进度+提升后预估 / 进度+可凭提升完成）
	-- ============================================================================
	if kData ~= nil then
		local progressStr :string = MPT_ProgressPRE..MPT_GetNumfone(kData.Progress*kData.Cost)..MPT_ProgressSUF..kData.Cost;
		kControl.TurnsLeft:SetToolTipString("");
		if isLastCompleted then										-- 刚完成，无 Tooltip
			kControl.TurnsLeft:SetToolTipString("");
		elseif kData.BoostTriggered or not kData.Boostable then		-- 已触发 boost 或不可 boost：仅显示当前进度
			kControl.TurnsLeft:SetToolTipString(progressStr);
		else														-- 可 boost 未触发：追加提升后预估
			kControl.TurnsLeft:SetToolTipString(progressStr..MPT_EstimatesPRE..MPT_GetNumfone(kData.Estimates)..MPT_EstimatesSUF..kData.Cost);
		end
		if kData.Enough then										-- 可凭 boost 完成：追加完成标记
			kControl.TurnsLeft:SetToolTipString(progressStr..MPT_EnoughStr);
		end
	end

	-- Label only exists in the big version:
	if kControl.TurnsLeftLabel ~= nil then
		kControl.TurnsLeftLabel:SetHide( isLastCompleted or turnsLeft < 0 );
	end
end


-- ===========================================================================
--	Obtain a single research/tech item.
-- ===========================================================================
function GetResearchData( localPlayer:number, pPlayerTechs:table, kTech:table )
	
	if kTech == nil then	-- Immediate return if there is no tech to inspect; likely first turn.
		return nil;
	end

	local iTech			:number = kTech.Index;
	local isBoostable	:boolean = false;
	local boostAmount	:number = 0;
	local isRepeatable	:boolean = kTech.Repeatable;
	local researchCost	:number = pPlayerTechs:GetResearchCost(iTech);
	local techType		:string = kTech.TechnologyType;
	local triggerDesc	:string = "";

	for row in GameInfo.Boosts() do
		if row.TechnologyType == techType then
			isBoostable	= true;					
			-- ============================================================================
			-- 条目14：boost 量叠加 modifier 附加加速（真实进度）
			-- boostAmount = (row.Boost *.01 ) * researchCost;		--Convert the boost value to decimal and determine the actual boost amount.
			boostAmount = ((row.Boost + MPT_GetExtraBoostFromModifiers(Game.GetLocalPlayer(), true)) *.01 ) * researchCost;		--Convert the boost value to decimal and determine the actual boost amount.
			-- ----------------------------------------------------------------------------
			triggerDesc = row.TriggerDescription;
			break;
		end
	end
	local kData :table = {
		ID				= iTech, 
		Boostable		= isBoostable,
		BoostAmount		= boostAmount / researchCost,
		BoostTriggered	= pPlayerTechs:HasBoostBeenTriggered(iTech),
		Hash			= kTech.Hash,
		Name			= Locale.Lookup( kTech.Name ),
		IsCurrent		= false,		-- caller needs to update upon return
		IsLastCompleted	= false,		-- caller needs to update upon return
		Repeatable		= isRepeatable,
		Cost			= researchCost,
		Progress		= pPlayerTechs:GetResearchProgress(iTech) / researchCost,
		TechType		= techType,
		ToolTip			= ToolTipHelper.GetToolTip( techType, localPlayer ),
		TriggerDesc		= triggerDesc,
		TurnsLeft		= pPlayerTechs:GetTurnsToResearch(iTech),
		Estimates		= pPlayerTechs:GetResearchProgress(iTech),		-- 预估值（boost 后进度，绝对）
		Enough			= false											-- 是否可凭 boost 完成
	};
	-- ============================================================================
	-- 条目14：未触发 boost 时修正预估（含 0.5 步进取整补偿：引擎 GetResearchProgress 按 0.5 步进，
	-- boost 进度为 0.5 整数倍时减 0.5 否则减 1，向下取整后叠加当前进度）
	-- ============================================================================
	if not kData.BoostTriggered then		-- 未触发 boost
		kData.Estimates = math.min(pPlayerTechs:GetResearchProgress(iTech) + math.floor(math.max(kData.Cost * kData.BoostAmount - ( (kData.Cost * kData.BoostAmount % 0.5 == 0) and 0.5 or 1),0) ),kData.Cost);		-- 后预估的值
	end
	if kData.Estimates == kData.Cost then
		kData.Enough = true;
	end	
	-- ============================================================================
	-- 条目14：可凭 boost 完成时 Name 直接带图标标记（数据层方案——所有消费 kData.Name 的
	-- 显示点自动生效：ResearchChooser/CivicsChooser 的 TechName、本文件 RealizeCurrentResearch
	-- 的 TitleButton；避免逐个覆盖显示函数，也无需替换 Chooser context）
	-- ============================================================================
	if kData.Enough then
		kData.Name = kData.Name..MPT_IconEnough;
	end
			
	return kData;
end

-- ===========================================================================
--	Realize content at the top of a list which is one of the following:
--	the current research, the recently completed research or NIL if player
--	has just started the game.
-- ===========================================================================
function RealizeCurrentResearch( playerID:number, kData:table, kControl:table )

	-- If a control instance is passed in, use that for the controls, otherwise
	-- assume the control exists off of the main control set of the context.
	if kControl == nil then
		kControl = Controls;
	end

	kControl.MainPanel:ClearMouseEnterCallback();
	kControl.MainPanel:ClearMouseExitCallback();

	local isNonActive:boolean = false;
	local techUnlockIM:table = GetUnlockIM( kControl );	-- Use this context's "Controls" table for the currnet IM

	if kData ~= nil then
		local techType:string = kData.TechType;
		local numUnlockables:number;
		kControl.TitleButton:SetText(Locale.ToUpper(kData.Name));	-- 条目14：可凭 boost 完成的图标已由 GetResearchData 数据层追加到 Name（见 GetResearchData）

		if(not IsTutorialRunning()) then
			kControl.TitleButton:RegisterCallback(Mouse.eRClick, function() LuaEvents.OpenCivilopedia(techType); end);
		end

		kControl.MainPanel:RegisterMouseEnterCallback(		function() kControl.MainGearAnim:Play(); end);
		kControl.MainPanel:RegisterMouseExitCallback(		function() kControl.MainGearAnim:Stop(); end);				
		
		RealizeMeterAndBoosts( kControl, kData );
		RealizeIcon( kControl.Icon, kData.TechType, SIZE_ICON_RESEARCH_LARGE );

		numUnlockables = PopulateUnlockablesForTech( playerID, kData.ID, techUnlockIM, nil );
		if numUnlockables ~= nil and kControl ~= nil then
			HandleOverflow(numUnlockables, kControl, MAX_ICONS_BEFORE_OVERFLOW, MAX_ICONS_BEFORE_OVERFLOW-1);
		end

		-- Show/Hide Recommended Icon
		if kControl.RecommendedIcon then
			if kData.IsRecommended and kData.AdvisorType then
				kControl.RecommendedIcon:SetIcon(kData.AdvisorType);
				kControl.RecommendedIcon:SetHide(false);
				kControl.TitleStack:ReprocessAnchoring();
			else
				kControl.RecommendedIcon:SetHide(true);
			end
		end
	else
		-- Nothing has been researched yet.
		kControl.TitleButton:ClearCallback(Mouse.eRClick);
		kControl.BoostMeter:SetPercent(0);
		kControl.ProgressMeter:SetPercent(0);
		kControl.BoostLabel:SetHide( true );
		kControl.IconCanBeBoosted:SetHide( true );
		kControl.IconHasBeenBoosted:SetHide( true );
		if kControl.RecommendedIcon then
			kControl.RecommendedIcon:SetHide( true );
		end
		isNonActive = true;
	end

	RealizeTurnsLeft( kControl, kData );	
	kControl.TitleButton:SetHide( isNonActive );
	kControl.Icon:SetHide( isNonActive );
end



-- ===========================================================================
--	Determine the current data.
-- ===========================================================================
function GetCivicData( localPlayer:number, pPlayerCulture:table, kCivic:table )

	if kCivic == nil then	-- Immediate return if there is no tech to inspect; likely first turn.
		return nil;
	end
	
	local iCivic		:number = kCivic.Index;			
	local isBoostable	:boolean = false;
	local boostAmount	:number = 0;
	local isRepeatable	:boolean = kCivic.Repeatable;
	local progressCost	:number = pPlayerCulture:GetCultureCost(iCivic)
	local civicType		:string = kCivic.CivicType;
	local triggerDesc	:string = "";

	for row in GameInfo.Boosts() do
		if row.CivicType == civicType then
			isBoostable	= true;					
			-- ============================================================================
			-- 条目14：boost 量叠加 modifier 附加加速（真实进度）
			-- boostAmount = (row.Boost *.01 ) * progressCost;		--Convert the boost value to decimal and determine the actual boost amount.
			boostAmount = ((row.Boost + MPT_GetExtraBoostFromModifiers(Game.GetLocalPlayer(), false)) *.01 ) * progressCost;		--Convert the boost value to decimal and determine the actual boost amount.
			-- ----------------------------------------------------------------------------
			triggerDesc = row.TriggerDescription;
			break;
		end
	end

	local kData :table = {
		ID				= iCivic, 
		Boostable		= isBoostable,
		BoostAmount		= boostAmount / progressCost,
		BoostTriggered	= pPlayerCulture:HasBoostBeenTriggered(iCivic),
		Cost			= progressCost,
		Hash			= kCivic.Hash,
		Name			= Locale.Lookup( kCivic.Name ),
		IsCurrent		= false,		-- caller needs to update upon return
		IsLastCompleted	= false,		-- caller needs to update upon return
		Repeatable		= isRepeatable,
		Progress		= (pPlayerCulture:GetCulturalProgress(iCivic) / progressCost),
		CivicType		= civicType,
		ToolTip			= ToolTipHelper.GetToolTip( civicType, localPlayer ),
		TriggerDesc		= triggerDesc,
		TurnsLeft		= pPlayerCulture:GetTurnsToProgressCivic(iCivic),
		Estimates		= pPlayerCulture:GetCulturalProgress(iCivic),		-- 预估值（boost 后进度，绝对）
		Enough			= false												-- 是否可凭 boost 完成
	};
	-- ============================================================================
	-- 条目14：未触发 boost 时修正预估（同 GetResearchData 的 0.5 步进取整补偿）
	-- ============================================================================
	if not kData.BoostTriggered then		-- 未触发 boost
		kData.Estimates = math.min(pPlayerCulture:GetCulturalProgress(iCivic) + math.floor(math.max(kData.Cost * kData.BoostAmount - ( (kData.Cost * kData.BoostAmount % 0.5 == 0) and 0.5 or 1),0)),kData.Cost);		-- 后预估的值
	end	
	if kData.Estimates == kData.Cost then
		kData.Enough = true;
	end
	-- ============================================================================
	-- 条目14：可凭 boost 完成时 Name 直接带图标标记（数据层方案，同 GetResearchData）
	-- ============================================================================
	if kData.Enough then
		kData.Name = kData.Name..MPT_IconEnough;
	end

	return kData;
end


-- ===========================================================================
--	Realize content at the top of a list which is one of the following:
--	the current research, the recently completed research or NIL if player
--	has just started the game.
-- ===========================================================================
function RealizeCurrentCivic( playerID:number, kData:table, kControl:table, cachedModifiers:table )

	-- If a control instance is passed in, use that for the controls, otherwise
	-- assume the control exists off of the main control set of the context.
	if kControl == nil then
		kControl = Controls;
	end

	kControl.MainPanel:ClearMouseEnterCallback();
	kControl.MainPanel:ClearMouseExitCallback();

	local isNonActive:boolean = false;
	local unlockIM:table = GetUnlockIM( kControl );	-- Use this context's "Controls" table for the currnet IM
	

	if kData ~= nil then
		local techType:string = kData.CivicType;
		local numUnlockables:number = 0;
		kControl.TitleButton:SetText( Locale.ToUpper(kData.Name) );	-- 条目14：可凭 boost 完成的图标已由 GetCivicData 数据层追加到 Name（见 GetCivicData）

		if(not IsTutorialRunning()) then
			kControl.TitleButton:RegisterCallback(Mouse.eRClick,	function() LuaEvents.OpenCivilopedia(techType); end);
		end

		kControl.MainPanel:RegisterMouseEnterCallback(	function() kControl.MainGearAnim:Play(); end);
		kControl.MainPanel:RegisterMouseExitCallback(	function() kControl.MainGearAnim:Stop(); end);
		
		RealizeMeterAndBoosts( kControl, kData );
		RealizeIcon( kControl.Icon, kData.CivicType, SIZE_ICON_CIVIC_LARGE );		

		-- Include extra icons in total unlocks
		local extraUnlocks:table = {};
		local hideDescriptionIcon:boolean = false;
		local civicModifiers:table = cachedModifiers[kData.CivicType];
		if ( civicModifiers ) then
			for _,tModifier in ipairs(civicModifiers) do
				local tIconData :table = g_ExtraIconData[tModifier.ModifierType];
				if ( tIconData ) then
					hideDescriptionIcon = hideDescriptionIcon or tIconData.HideDescriptionIcon;
					table.insert(extraUnlocks, {IconData=tIconData, ModifierTable=tModifier});
				end
			end
		end

		numUnlockables = numUnlockables + PopulateUnlockablesForCivic( playerID, kData.ID, unlockIM, nil, nil, hideDescriptionIcon );

		-- Initialize extra icons
		for _,tUnlock in pairs(extraUnlocks) do
			tUnlock.IconData:Initialize(kControl.UnlockStack, tUnlock.ModifierTable);
			numUnlockables = numUnlockables + 1;
		end
		
		HandleOverflow(numUnlockables, kControl, MAX_ICONS_BEFORE_OVERFLOW, MAX_ICONS_BEFORE_OVERFLOW-1);

		-- Show/Hide Recommended Icon
		if kControl.RecommendedIcon then
			if kData.IsRecommended and kData.AdvisorType then
				kControl.RecommendedIcon:SetIcon(kData.AdvisorType);
				kControl.RecommendedIcon:SetHide(false);
				kControl.TitleStack:ReprocessAnchoring();
			else
				kControl.RecommendedIcon:SetHide(true);
			end
		end
	else
		-- Nothing has been researched yet.
		kControl.TitleButton:ClearCallback(Mouse.eRClick);
		kControl.BoostMeter:SetPercent(0);
		kControl.ProgressMeter:SetPercent(0);
		kControl.BoostLabel:SetHide( true );
		kControl.IconCanBeBoosted:SetHide( true );
		kControl.IconHasBeenBoosted:SetHide( true );
		kControl.TurnsLeftLabel:SetHide( true );
		isNonActive = true;
	end

	RealizeTurnsLeft( kControl, kData );
	kControl.TitleButton:SetHide( isNonActive );
	kControl.Icon:SetHide( isNonActive );
end

-- Returns a table: strCivicType -> Array of Modifiers
-- Each modifier is a table containing ModifierType, ModifierId, and an optional ModifierValue
function TechAndCivicSupport_BuildCivicModifierCache()
	-- Collect modifiers into list
	local tModCache :table = {}; -- ModifierId -> table of modifier data
	for tModInfo in GameInfo.Modifiers() do
		tModCache[tModInfo.ModifierId] = {
			ModifierId = tModInfo.ModifierId,
			ModifierType = tModInfo.ModifierType,
		};
	end

	-- Collect modifier arguments, add to relevant modifier table
	for tModArgs in GameInfo.ModifierArguments() do
		-- ModifierValue should be changed into an array if we must track multiple args per modifier.
		tModCache[tModArgs.ModifierId].ModifierValue = tModArgs.Value;
	end
	
	-- Collect modifiers used by civics
	local tCache :table = {}; -- strCivicType -> Array of Modifiers
	for tCivicMod:table in GameInfo.CivicModifiers() do
		local tCivicCache :table = tCache[tCivicMod.CivicType];
		if ( not tCivicCache ) then
			tCivicCache = {};
			tCache[tCivicMod.CivicType] = tCivicCache;
		end
		
		local tModInfo :table = tModCache[tCivicMod.ModifierId];
		assert( tModInfo );
		table.insert( tCivicCache, tModInfo );
	end

	return tCache;
end
