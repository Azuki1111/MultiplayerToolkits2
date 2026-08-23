-- ===========================================================================
-- 条目9：顶部面板扩展（TPE）——移植自联机工具箱 1.67（工坊 3693899014 TPE 目录）
-- 在顶部面板追加 食物/生产力/人口/奢侈品 四个统计按钮 + 联动 Tooltip；
-- 重写 RefreshResources（战略资源）Tooltip 追加队友战略资源清单。
-- 相对 1.67 的优化：奢侈品类型查表 O(1)、资源表轻量化、玩家/队伍列表缓存、
-- 冗余调取去重、文本预加载缓存、取消 CanRefresh 冻结缺陷（每次悬停发最新数据）。
-- 注册：ReplaceUIScript(LuaContext=TopPanel) 投递本文件；本文件经 ImportFiles 入 VFS 供 include 基类探测。
-- ===========================================================================

-- ===========================================================================
-- INCLUDES（基类探测：Exp2 优先，退 Exp1，再退 Base；仅当 Initialize 存在即视为基类）
-- ===========================================================================
local files = {
    "TopPanel_Expansion2",
    "TopPanel_Expansion1",
    "TopPanel",
}

local BaseFile = ""

for _, file in ipairs(files) do
    include(file)
    if Initialize then
        print("MPT_TPE: Loading " .. file .. " as base file");
        BaseFile = file
        break
    end
end

-- ===========================================================================
-- 全局变量
-- ===========================================================================
TPE_BASE_RefreshYields = RefreshYields;
TPT_BASE_LateInitialize = LateInitialize;

local g_LocalplayerLuxurySet : table = {}		-- 本玩家拥有的奢侈品类型集合（ResourceType => true，查表 O(1)，替代 1.67 数组线性遍历）
local g_TopPanelResources : table = {}			-- 顶部面板显示的战略资源轻量表（{Index, Hash}，替代 1.67 存整行）
local g_TeamVisibleResources : table = {}		-- 队友已解锁的战略资源（Index => true）
local g_LuxuryTeamPlayerIDs : table = nil		-- 奢侈品队友列表（FFA 时含全部存活玩家；每刷新周期构建一次）
local g_StrategicTeamPlayerIDs : table = nil	-- 战略资源队友列表（仅同队；每刷新周期构建一次）

local m_FoodYieldButton = nil
local m_PopulationYieldButton = nil
local m_ProductionYieldButton = nil

-- 兼容禁止交易模式
local isLuxuriesTradingAllowed = true
local isStrategicsTradingAllowed = true

-- FFA 时的奢侈品显示（默认 true：无任何队伍时视为 FFA，显示所有玩家的重复奢侈品）
local IsFFA = true

-- ===========================================================================
-- 文本预加载缓存（条目9 分区：带参数 tag 拆为无参数 PRE/SUF + Lua .. 拼接，运行时直接引用变量）
-- ===========================================================================
local LuxuryResourcesPRE	= Locale.Lookup("LOC_MPT_TPE_LUXURY_RESOURCES_PRE")			-- "[ICON_RESOURCE_TOYS] 拥有的奢侈品:("
local LuxuryResourcesSUF	= Locale.Lookup("LOC_MPT_TPE_LUXURY_RESOURCES_SUF")			-- " 种类)"
local MoreLuxuryNameStr		= Locale.Lookup("LOC_MPT_TPE_MORE_LUXURY_NAME")				-- "自己的额外奢侈品"
local TeamMoreLuxuryNameStr	= Locale.Lookup("LOC_MPT_TPE_TEAM_MORE_LUXURY_NAME")		-- "其他玩家的重复奢侈品"
local TeamMoreStrategicStr	= Locale.Lookup("LOC_MPT_TPE_TEAM_MORE_STRATEGIC_NAME")		-- "队友可用的战略"

-- ===========================================================================
-- 构建奢侈品队友列表（IsFFA 时含全部存活玩家，否则仅同队；排除自己）
-- 原版每次循环内 GetAliveMajorIDs()，这里每刷新周期构建一次
-- ===========================================================================
function BuildLuxuryTeamPlayerIDs()
    g_LuxuryTeamPlayerIDs = {}
    local localPlayerID : number = Game.GetLocalPlayer()
    local localPlayer : table = Players[localPlayerID]
    for j, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
        if (localPlayer:GetTeam() == Players[playerID]:GetTeam() or IsFFA) and localPlayerID ~= playerID then
            table.insert(g_LuxuryTeamPlayerIDs, playerID)
        end
    end
end

-- ===========================================================================
-- 构建战略资源队友列表（仅同队，排除自己）
-- ===========================================================================
function BuildStrategicTeamPlayerIDs()
    g_StrategicTeamPlayerIDs = {}
    local localPlayerID : number = Game.GetLocalPlayer()
    local localPlayer : table = Players[localPlayerID]
    for j, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
        if localPlayer:GetTeam() == Players[playerID]:GetTeam() and localPlayerID ~= playerID then
            table.insert(g_StrategicTeamPlayerIDs, playerID)
        end
    end
end

-- ===========================================================================
-- 城市食物产出统计
-- ===========================================================================
function RefreshFood()
    if m_YieldButtonDoubleManager == nil then return end		-- 健壮性守卫（Base 亦定义，双保险）
    m_FoodYieldButton = m_FoodYieldButton or m_YieldButtonDoubleManager:GetInstance();

    local Food_Info = {
        TotalFood = 0,
        CitysInfo = {},
    }

    local pTotalFood = 0
    local pTotalFoodSurplus = 0

    local pPlayerCities = Players[Game.GetLocalPlayer()]:GetCities()

    for i, pCity in pPlayerCities:Members() do
        local pCityFood = pCity:GetYield(YieldTypes.Food)
        local pFoodSurplus, growthModifier = GetFoodSurplus(pCity)

        pTotalFood = pTotalFood + pCityFood
        pTotalFoodSurplus = pTotalFoodSurplus + pFoodSurplus

        local kdate = {
            CityName = Locale.Lookup(pCity:GetName()),
            CityFood = pCityFood,
            FoodSurplus = pFoodSurplus,
            GrowthModifier = growthModifier,
        }
        table.insert(Food_Info.CitysInfo, kdate)
    end
    Food_Info.TotalFood = Locale.ToNumber(pTotalFood, "#####.#");

    m_FoodYieldButton.YieldIconString:SetText("[ICON_FoodLarge]")
    m_FoodYieldButton.YieldPerTurn:SetColorByName("ResFoodLabelCS")
    m_FoodYieldButton.YieldPerTurn:SetText(Locale.ToNumber(pTotalFoodSurplus, "+#####.#;-#####.#"))
    m_FoodYieldButton.YieldBalance:SetText(Locale.ToNumber(pTotalFood, "#####.#"));
    m_FoodYieldButton.YieldBalance:SetColorByName("ResFoodLabelCS");
    m_FoodYieldButton.YieldBacking:SetToolTipType("TooltipType_TopPanel_Food")
    m_FoodYieldButton.YieldBacking:SetColorByName("ResFoodLabelCS")
    m_FoodYieldButton.YieldBacking:ClearToolTipCallback()
    -- 每次悬停发送最新数据（1.67 的 CanRefresh 冻结缺陷已取消：其置 false 后 tooltip 数据永不更新）
    m_FoodYieldButton.YieldBacking:SetToolTipCallback(
        function()
            LuaEvents.TopPanelToolTip_Food_Refresh(Food_Info)
        end
    );
    m_FoodYieldButton.YieldButtonStack:CalculateSize()
end

-- ===========================================================================
-- 获取城市余粮
-- ===========================================================================
function GetFoodSurplus(pCity)
    local FoodSurplusNum = 0
    local growthModifier = 1
    local pCityGrowth : table = pCity:GetGrowth();
    local isStarving : boolean = pCityGrowth:GetTurnsUntilStarvation() ~= -1;
    local HappinessGrowthModifier = pCityGrowth:GetHappinessGrowthModifier();
    local OtherGrowthModifiers = pCityGrowth:GetOtherGrowthModifier();
    local FoodSurplus = Round( pCityGrowth:GetFoodSurplus(), 1);
    local HousingMultiplier = pCityGrowth:GetHousingGrowthModifier();
    local Occupied = pCity:IsOccupied();
    local OccupationMultiplier = pCityGrowth:GetOccupationGrowthModifier();

    if not isStarving then
        growthModifier =  math.max(1 + (HappinessGrowthModifier/100) + OtherGrowthModifiers, 0);
        local iModifiedFood = Round(FoodSurplus * growthModifier, 2);
        FoodSurplusNum = iModifiedFood * HousingMultiplier;
        if Occupied then
            FoodSurplusNum = iModifiedFood * OccupationMultiplier;
        end
    else
        FoodSurplusNum = FoodSurplus;
    end

    growthModifier = Round(growthModifier, 2)

    return FoodSurplusNum, growthModifier
end

-- ===========================================================================
-- 城市人口统计
-- ===========================================================================
function RefreshPopulation()
    if m_YieldButtonDoubleManager == nil then return end		-- 健壮性守卫
    m_PopulationYieldButton = m_PopulationYieldButton or m_YieldButtonDoubleManager:GetInstance()

    local Population_Info = {
        TotalPopulation = 0,
        PopulationPerTurn = 0,
        CitysInfo = {},
    }

    local pTotalPopulation = 0
    local pTotalPopulationPerTurn = 0

    local pPlayerCities = Players[Game.GetLocalPlayer()]:GetCities()

    for i, pCity in pPlayerCities:Members() do
        local pPopulation = pCity:GetPopulation()
        local pPopulationPerTurn = GetPopulationPerTurn(pCity)

        local pCityGrowth = pCity:GetGrowth()

        pTotalPopulation = pTotalPopulation + pPopulation
        pTotalPopulationPerTurn = pTotalPopulationPerTurn + pPopulationPerTurn

        local kdate = {
            CityName = Locale.Lookup(pCity:GetName()),
            Population = pPopulation,
            Housing = pCityGrowth:GetHousing() - pPopulation,
            HousingMultiplier = pCityGrowth:GetHousingGrowthModifier(),
            Amenity = pCityGrowth:GetAmenities() - pCityGrowth:GetAmenitiesNeeded(),
            HappinessGrowthModifier = pCityGrowth:GetHappinessNonFoodYieldModifier() / 100,
        }
        table.insert(Population_Info.CitysInfo, kdate)
    end

    Population_Info.TotalPopulation = Locale.ToNumber(pTotalPopulation, "#####.#");
    Population_Info.PopulationPerTurn = Locale.ToNumber(Round(pTotalPopulationPerTurn, 1), "#####.#");

    m_PopulationYieldButton.YieldIconString:SetText("[ICON_Citizen]")
    m_PopulationYieldButton.YieldIconString:SetOffsetY(6)
    m_PopulationYieldButton.YieldPerTurn:SetColorByName("StatNormalCS")
    m_PopulationYieldButton.YieldPerTurn:SetText(Locale.ToNumber(Round(pTotalPopulationPerTurn, 1), "+####.#;-####.#"))
    m_PopulationYieldButton.YieldPerTurn:SetOffsetY(-2)
    m_PopulationYieldButton.YieldBalance:SetText(Locale.ToNumber(pTotalPopulation, "#####"));
    m_PopulationYieldButton.YieldBalance:SetOffsetY(-1)
    m_PopulationYieldButton.YieldBalance:SetColorByName("StatNormalCS");
    m_PopulationYieldButton.YieldBacking:SetColorByName("ChatMessage_Whisper")
    m_PopulationYieldButton.YieldBacking:SetToolTipType("TooltipType_TopPanel_Population")
    m_PopulationYieldButton.YieldBacking:ClearToolTipCallback()
    -- 每次悬停发送最新数据（同 RefreshFood，取消 1.67 CanRefresh 冻结缺陷）
    m_PopulationYieldButton.YieldBacking:SetToolTipCallback(
        function()
            LuaEvents.TopPanelToolTip_Population_Refresh(Population_Info)
        end
    );
    m_PopulationYieldButton.YieldButtonStack:CalculateSize()
end

-- ===========================================================================
-- 获取城市人口增长（余粮除以所需粮食）
-- ===========================================================================
function GetPopulationPerTurn(pCity)
    local pCityGrowth : table = pCity:GetGrowth();
    local growthThreshold : number = pCityGrowth:GetGrowthThreshold();
    local FoodSurPlus = GetFoodSurplus(pCity)

    return FoodSurPlus / growthThreshold
end

-- ===========================================================================
-- 城市生产力统计
-- ===========================================================================
function RefreshProduction()
    if m_YieldButtonSingleManager == nil then return end		-- 健壮性守卫
    m_ProductionYieldButton = m_ProductionYieldButton or m_YieldButtonSingleManager:GetInstance()

    local Production_Info = {
        TotalProduction = 0,
        CitysInfo = {},
    }

    local pPlayerCities = Players[Game.GetLocalPlayer()]:GetCities()
    local pTotalProduction = 0

    for i, pCity in pPlayerCities:Members() do
        local pCityProduction = pCity:GetYield(YieldTypes.PRODUCTION)

        pTotalProduction = pTotalProduction + pCityProduction

        local kdate = {
            CityName = Locale.Lookup(pCity:GetName()),
            CityProduction = pCityProduction,
        }
        table.insert(Production_Info.CitysInfo, kdate)
    end

    Production_Info.TotalProduction = Locale.ToNumber(pTotalProduction, "#####.#");

    m_ProductionYieldButton.YieldIconString:SetText("[ICON_ProductionLarge]")
    m_ProductionYieldButton.YieldPerTurn:SetText(Locale.ToNumber(pTotalProduction, "+#####.#;-#####.#"))
    m_ProductionYieldButton.YieldPerTurn:SetColorByName("ResProductionLabelCS")
    m_ProductionYieldButton.YieldBacking:SetColorByName("ChatMessage_Whisper")
    m_ProductionYieldButton.YieldBacking:SetToolTipType("TooltipType_TopPanel_Production")
    m_ProductionYieldButton.YieldBacking:ClearToolTipCallback()
    -- 每次悬停发送最新数据（同 RefreshFood，取消 1.67 CanRefresh 冻结缺陷）
    m_ProductionYieldButton.YieldBacking:SetToolTipCallback(
        function()
            LuaEvents.TopPanelToolTip_Production_Refresh(Production_Info)
        end
    );
    m_ProductionYieldButton.YieldButtonStack:CalculateSize()
end

-- ===========================================================================
-- 奢侈品资源统计（总数量/种类 + 自己额外可交易奢侈品 + 队友重复奢侈品）
-- ===========================================================================
function RefreshLuxuryResourcesType()
    if m_YieldButtonSingleManager == nil then return end		-- 健壮性守卫
    m_LuxuryResourcesTypeYieldButton = m_LuxuryResourcesTypeYieldButton or m_YieldButtonSingleManager:GetInstance()

    g_LocalplayerLuxurySet = {}		-- 清空集合

    local sTextColorGreen = "[COLOR:StatGoodCS]"
    local sTextColorEnd = "[ENDCOLOR]"
    local Morestr = MoreLuxuryNameStr

    local sLuxuryResourceListText = ""
    local pLuxuryTotalAmount = 0
    local pLuxuryTotalType = 0
    local More = false

    local pPlayerResources = Players[Game.GetLocalPlayer()]:GetResources()
    BuildLuxuryTeamPlayerIDs()		-- 队友列表每刷新周期构建一次（IsTradableResources 复用）

    for resource in GameInfo.Resources() do
        if resource.ResourceClassType ~= nil and resource.ResourceClassType == "RESOURCECLASS_LUXURY" then
            local amount = pPlayerResources:GetResourceAmount(resource.ResourceType)
            if (amount > 0) then
                local addLuxuryResourceText = "[NEWLINE][ICON_"..resource.ResourceType.."] "..Locale.Lookup(resource.Name)
                sLuxuryResourceListText = sLuxuryResourceListText..addLuxuryResourceText
                pLuxuryTotalAmount = pLuxuryTotalAmount + amount
                pLuxuryTotalType = pLuxuryTotalType + 1
                g_LocalplayerLuxurySet[resource.ResourceType] = true		-- 将已有奢侈写入集合
                if (amount > 1) then
                    if IsTradableResources(resource) then
                        More = true
                        local Moreamount = amount - 1
                        local MoreaddLuxuryResourceText = "[NEWLINE][ICON_"..resource.ResourceType.."] "..Locale.Lookup(resource.Name).." "..Moreamount
                        Morestr = Morestr..MoreaddLuxuryResourceText
                    end
                end
            end
        end
    end

    local sYieldPerTurnText = ""

    if pLuxuryTotalAmount > pLuxuryTotalType and More == true then
        sYieldPerTurnText = sTextColorGreen..pLuxuryTotalAmount..sTextColorEnd.."/"..pLuxuryTotalType
    else
        sYieldPerTurnText = pLuxuryTotalAmount.."/"..pLuxuryTotalType
    end

    local sToolTopText = LuxuryResourcesPRE..pLuxuryTotalType..LuxuryResourcesSUF.."[NEWLINE]"..sLuxuryResourceListText

    if More == true and isLuxuriesTradingAllowed == true then
        sToolTopText = sToolTopText..Morestr
    end
    -- 队友额外奢侈品
    local LUXURYtext = TeamMoreLuxuryNameStr
    local TeamMore = false

    for j, playerID in ipairs(g_LuxuryTeamPlayerIDs) do
        local LUXURYstr = GetMoreLUXURYstr(playerID)
        if LUXURYstr then
            TeamMore = true
            LUXURYtext = LUXURYtext..LUXURYstr
        end
    end

    if TeamMore == true and isLuxuriesTradingAllowed == true then
        sToolTopText = sToolTopText..LUXURYtext
        sYieldPerTurnText = sYieldPerTurnText.."[icon_PressureHigh]"
    end

    m_LuxuryResourcesTypeYieldButton.YieldIconString:SetText("[ICON_RESOURCE_TOYS]")
    m_LuxuryResourcesTypeYieldButton.YieldPerTurn:SetText(sYieldPerTurnText)
    m_LuxuryResourcesTypeYieldButton.YieldPerTurn:SetColorByName("StatNormalCS")
    m_LuxuryResourcesTypeYieldButton.YieldBacking:SetToolTipString(sToolTopText)
    m_LuxuryResourcesTypeYieldButton.YieldBacking:SetColorByName("ChatMessage_Whisper")
    m_LuxuryResourcesTypeYieldButton.YieldButtonStack:CalculateSize()
end

-- ===========================================================================
-- 获取额外奢侈品字符串（队友的重复且可交易奢侈品）
-- ===========================================================================
function GetMoreLUXURYstr(playerID)

    local pPlayerConfig = PlayerConfigurations[playerID];
    local leaderType = PlayerConfigurations[playerID]:GetLeaderTypeName();
    local LeaderName = Locale.Lookup(GameInfo.Leaders[leaderType].Name);

    local LUXURYstr = "[NEWLINE][NEWLINE][icon_Bullet]"..LeaderName

    local pPlayerResources = Players[playerID]:GetResources()
    local More = false

    for resource in GameInfo.Resources() do
        if resource.ResourceClassType ~= nil and resource.ResourceClassType == "RESOURCECLASS_LUXURY" then
            local amount = pPlayerResources:GetResourceAmount(resource.ResourceType)
            if (amount > 1 and IsNewLuxury(resource)) then
                if PopulateAvailableResources(playerID, resource) then
                    More = true
                    local MoreaddLuxuryResourceText = "[NEWLINE][ICON_"..resource.ResourceType.."] "..Locale.Lookup(resource.Name)

                    LUXURYstr = LUXURYstr..MoreaddLuxuryResourceText
                end
            end
        end
    end
    if More == true then
        return LUXURYstr
    else
        return false
    end
end

-- ===========================================================================
-- 是本玩家未拥有的新奢侈品？（查表 O(1)，替代 1.67 数组线性遍历）
-- ===========================================================================
function IsNewLuxury(resource)
    return g_LocalplayerLuxurySet[resource.ResourceType] == nil
end

-- ===========================================================================
-- 判断是否是可交易的奢侈品（对队友列表逐个尝试，命中首个满足条件的队友）
-- ===========================================================================
function IsTradableResources(Resource)
    local localPlayerID : number = Game.GetLocalPlayer()
    local localPlayer : table = Players[localPlayerID]
    for j, playerID in ipairs(g_LuxuryTeamPlayerIDs) do
        if not localPlayer:GetDiplomacy():IsAtWarWith(playerID) and localPlayer:GetDiplomacy():HasMet(playerID) then		-- 队友（列表已过滤同队/FFA/自己）
            local pForDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, localPlayerID, playerID);
            local possibleResources : table = DealManager.GetPossibleDealItems(localPlayerID, playerID, DealItemTypes.RESOURCES, pForDeal);
            if (possibleResources ~= nil) then
                for i, entry in ipairs(possibleResources) do
                    local resourceDesc : table = GameInfo.Resources[entry.ForType];
                    if resourceDesc == Resource then
                        return true
                    end
                end
            end
            break
        end
    end
    return false
end

-- ===========================================================================
-- 判断是否是可交易的资源（队友视角：对方是否有多余可交易给本玩家的资源）
-- ===========================================================================
function PopulateAvailableResources(otherPlayerID, Resource)
    local localPlayerID = Game.GetLocalPlayer()
    local pForDeal : table = DealManager.GetWorkingDeal(DealDirection.OUTGOING, localPlayerID, otherPlayerID);
    local possibleResources : table = DealManager.GetPossibleDealItems(otherPlayerID, localPlayerID, DealItemTypes.RESOURCES, pForDeal);
    if (possibleResources ~= nil) then
        for i, entry in ipairs(possibleResources) do
            local resourceDesc : table = GameInfo.Resources[entry.ForType];
            if resourceDesc == Resource then
                if entry.MaxAmount > 1 then
                    return true
                end
            end
        end
    end
    return false
end

-- ===========================================================================
--	OVERRIDE：战略资源面板（基于 TopPanel_Expansion2 版，追加队友战略资源 Tooltip 段）
-- ===========================================================================
if BaseFile == "TopPanel_Expansion2" then
    function RefreshResources()
        if not GameCapabilities.HasCapability("CAPABILITY_DISPLAY_TOP_PANEL_RESOURCES") then
            m_kResourceIM:ResetInstances();
            return;
        end
        local localPlayerID = Game.GetLocalPlayer();
        local localPlayer = Players[localPlayerID];
        if (localPlayerID ~= -1) then
            m_kResourceIM:ResetInstances();
            local pPlayerResources : table = localPlayer:GetResources();
            local yieldStackX : number = Controls.YieldStack:GetSizeX();
            local infoStackX : number = Controls.StaticInfoStack:GetSizeX();
            local metaStackX : number = Controls.RightContents:GetSizeX();
            local screenX, _ : number = UIManager:GetScreenSizeVal();
            local maxSize : number = screenX - yieldStackX - infoStackX - metaStackX - m_viewReportsX - META_PADDING;
            if (maxSize < 0) then maxSize = 0; end
            local currSize : number = 0;
            local isOverflow : boolean = false;
            local overflowString : string = "";
            local plusInstance : table;
            BuildStrategicTeamPlayerIDs();		-- 队友列表每刷新周期构建一次（GetMoreStrategicstr 复用）
            for resource in GameInfo.Resources() do
                if (resource.ResourceClassType ~= nil and resource.ResourceClassType ~= "RESOURCECLASS_BONUS" and resource.ResourceClassType ~="RESOURCECLASS_LUXURY" and resource.ResourceClassType ~="RESOURCECLASS_ARTIFACT") then

                    local stockpileAmount : number = pPlayerResources:GetResourceAmount(resource.ResourceType);
                    local stockpileCap : number = pPlayerResources:GetResourceStockpileCap(resource.ResourceType);
                    local reservedAmount : number = pPlayerResources:GetReservedResourceAmount(resource.ResourceType);
                    local accumulationPerTurn : number = pPlayerResources:GetResourceAccumulationPerTurn(resource.ResourceType);
                    local importPerTurn : number = pPlayerResources:GetResourceImportPerTurn(resource.ResourceType);
                    local bonusPerTurn : number = pPlayerResources:GetBonusResourcePerTurn(resource.ResourceType);
                    local unitConsumptionPerTurn : number = pPlayerResources:GetUnitResourceDemandPerTurn(resource.ResourceType);
                    local powerConsumptionPerTurn : number = pPlayerResources:GetPowerResourceDemandPerTurn(resource.ResourceType);
                    local totalConsumptionPerTurn : number = unitConsumptionPerTurn + powerConsumptionPerTurn;
                    local totalAmount : number = stockpileAmount + reservedAmount;

                    if (totalAmount > stockpileCap) then
                        totalAmount = stockpileCap;
                    end

                    local iconName : string = "[ICON_"..resource.ResourceType.."]";

                    local totalAccumulationPerTurn : number = accumulationPerTurn + importPerTurn + bonusPerTurn;

                    local resourceText : string = iconName .. " " .. stockpileAmount;

                    local numDigits : number = 3;
                    if (stockpileAmount >= 10) then
                        numDigits = 4;
                    end
                    local guessinstanceWidth : number = math.ceil(numDigits * FONT_MULTIPLIER);

                    local tooltip : string = iconName .. " " .. Locale.Lookup(resource.Name);
                    if (reservedAmount ~= 0) then
                        tooltip = tooltip .. "[NEWLINE]" .. totalAmount .. "/" .. stockpileCap .. " " .. Locale.Lookup("LOC_RESOURCE_ITEM_IN_STOCKPILE");
                        tooltip = tooltip .. "[NEWLINE]-" .. reservedAmount .. " " .. Locale.Lookup("LOC_RESOURCE_ITEM_IN_RESERVE");
                    else
                        tooltip = tooltip .. "[NEWLINE]" .. totalAmount .. "/" .. stockpileCap .. " " .. Locale.Lookup("LOC_RESOURCE_ITEM_IN_STOCKPILE");
                    end
                    if (totalAccumulationPerTurn >= 0) then
                        tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_RESOURCE_ACCUMULATION_PER_TURN", totalAccumulationPerTurn);
                    else
                        tooltip = tooltip .. "[NEWLINE][COLOR_RED]" .. Locale.Lookup("LOC_RESOURCE_ACCUMULATION_PER_TURN", totalAccumulationPerTurn) .. "[ENDCOLOR]";
                    end
                    if (accumulationPerTurn > 0) then
                        tooltip = tooltip .. "[NEWLINE] " .. Locale.Lookup("LOC_RESOURCE_ACCUMULATION_PER_TURN_EXTRACTED", accumulationPerTurn);
                    end
                    if (importPerTurn > 0) then
                        tooltip = tooltip .. "[NEWLINE] " .. Locale.Lookup("LOC_RESOURCE_ACCUMULATION_PER_TURN_FROM_CITY_STATES", importPerTurn);
                    end
                    if (bonusPerTurn > 0) then
                        tooltip = tooltip .. "[NEWLINE] " .. Locale.Lookup("LOC_RESOURCE_ACCUMULATION_PER_TURN_FROM_BONUS_SOURCES", bonusPerTurn);
                    end
                    if (totalConsumptionPerTurn > 0) then
                        tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_RESOURCE_CONSUMPTION", totalConsumptionPerTurn);
                        if (unitConsumptionPerTurn > 0) then
                            tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_RESOURCE_UNIT_CONSUMPTION_PER_TURN", unitConsumptionPerTurn);
                        end
                        if (powerConsumptionPerTurn > 0) then
                            tooltip = tooltip .. "[NEWLINE]" .. Locale.Lookup("LOC_RESOURCE_POWER_CONSUMPTION_PER_TURN", powerConsumptionPerTurn);
                        end
                    end
                    -------------------------------------------------------------
                    -- 追加队友可用战略资源清单
                    local TeamStrategicYtext = TeamMoreStrategicStr
                    local TeamMore = false
                    for j, playerID in ipairs(g_StrategicTeamPlayerIDs) do
                        local Strategicstr = GetMoreStrategicstr(playerID, resource)
                        if Strategicstr ~= 0 then
                            TeamMore = true
                            TeamStrategicYtext = TeamStrategicYtext..Strategicstr
                        end
                    end

                    if TeamMore == true and isStrategicsTradingAllowed == true then
                        tooltip = tooltip .. "[NEWLINE]" .. TeamStrategicYtext
                    end
                    ------------------------------------
                    if (stockpileAmount > 0 or totalAccumulationPerTurn > 0 or totalConsumptionPerTurn > 0 or g_TeamVisibleResources[resource.Index]) then		-- 当解锁时显示
                        if(currSize + guessinstanceWidth < maxSize and not isOverflow) then
                            if (stockpileCap > 0) then
                                local instance : table = m_kResourceIM:GetInstance();
                                if (totalAccumulationPerTurn > totalConsumptionPerTurn) then
                                    instance.ResourceVelocity:SetHide(false);
                                    instance.ResourceVelocity:SetTexture("CityCondition_Rising");
                                elseif (totalAccumulationPerTurn < totalConsumptionPerTurn) then
                                    instance.ResourceVelocity:SetHide(false);
                                    instance.ResourceVelocity:SetTexture("CityCondition_Falling");
                                else
                                    instance.ResourceVelocity:SetHide(true);
                                end

                                instance.ResourceText:SetText(resourceText);
                                instance.ResourceText:SetToolTipString(tooltip);
                                -- 条目9续：战略资源点击发送交易（覆盖式注册，实例池复用安全；闭包捕获 ResourceType 拷贝
                                -- 防迭代器行对象复用；回调内部自行判断 允许交易/有可接收队友，禁止交易模式不动作）
                                local clickResourceType : string = resource.ResourceType;
                                instance.ResourceText:RegisterCallback(Mouse.eLClick, function() MPT_TPE_OpenResourceSendPopup(clickResourceType) end);
                                local instanceWidth : number = instance.ResourceText:GetSizeX();
                                currSize = currSize + instanceWidth;
                            end
                        else
                            if (not isOverflow) then
                                overflowString = tooltip;
                                local instance : table = m_kResourceIM:GetInstance();
                                instance.ResourceText:SetText("[ICON_Plus]");
                                plusInstance = instance.ResourceText;
                            else
                                overflowString = overflowString .. "[NEWLINE]" .. tooltip;
                            end
                            isOverflow = true;
                        end
                    end
                end
            end

            if (plusInstance ~= nil) then
                plusInstance:SetToolTipString(overflowString);
            end

            Controls.ResourceStack:CalculateSize();

            if(Controls.ResourceStack:GetSizeX() == 0) then
                Controls.Resources:SetHide(true);
            else
                Controls.Resources:SetHide(false);
            end
        end
    end

    -- ===========================================================================
    -- 获取队友战略资源字符串（队友该资源总量 > 0 时返回清单，否则返回 0）
    -- ===========================================================================
    function GetMoreStrategicstr(playerID, resource)

        local MoreStrategicstr = ""

        local leaderType = PlayerConfigurations[playerID]:GetLeaderTypeName();
        local LeaderName = Locale.Lookup(GameInfo.Leaders[leaderType].Name);					-- 获取领袖名字

        local pPlayerResources : table = Players[playerID]:GetResources();
        local stockpileAmount : number = pPlayerResources:GetResourceAmount(resource.ResourceType);
        local stockpileCap : number = pPlayerResources:GetResourceStockpileCap(resource.ResourceType);
        local reservedAmount : number = pPlayerResources:GetReservedResourceAmount(resource.ResourceType);

        local totalAmount : number = stockpileAmount + reservedAmount;

        if (totalAmount > stockpileCap) then
            totalAmount = stockpileCap;
        end
        if totalAmount > 0 then
            MoreStrategicstr = MoreStrategicstr .. "[NEWLINE][icon_bullet]" .. LeaderName .. "[NEWLINE]" .. "[ICON_"..resource.ResourceType.."]" .. totalAmount
            return MoreStrategicstr
        else
            return 0
        end
    end
end

-- ===========================================================================
--	判断队友是否解锁了资源（研究/市政完成时刷新解锁缓存）
-- ===========================================================================
function GetTeamVisibleResources(playerID)
    local localPlayerID : number = Game.GetLocalPlayer()
    if Players[localPlayerID]:GetTeam() == Players[playerID]:GetTeam() or playerID == localPlayerID then		-- 是队友
        local pPlayerResources = Players[playerID]:GetResources();
        for i, kdate in ipairs(g_TopPanelResources) do
            if pPlayerResources:IsResourceVisible(kdate.Hash) then
                g_TeamVisibleResources[kdate.Index] = true
            end
        end
    end
end

-- ===========================================================================
-- OVERRIDE：刷新产出（先调基类，再追加自定义按钮）
-- ===========================================================================
function RefreshYields()
    TPE_BASE_RefreshYields();

    RefreshFood()
    RefreshProduction()
    RefreshPopulation()
    RefreshLuxuryResourcesType()

    Controls.YieldStack:CalculateSize();
    Controls.StaticInfoStack:CalculateSize();
    Controls.InfoStack:CalculateSize();
end

-- ===========================================================================
-- OVERRIDE：延迟初始化（先调基类，再注册事件/判定 FFA/预构建战略资源表）
-- ===========================================================================
function LateInitialize()
    TPT_BASE_LateInitialize()

    MPT_TPE_RegisterSendPopupControls()		-- 条目9续：注册发送弹窗按钮回调（基类 LateInitialize 后控件已构建）

    Events.ResearchCompleted.Add(GetTeamVisibleResources);
    Events.CivicCompleted.Add(GetTeamVisibleResources);

    for j, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
        if Players[playerID]:GetTeam() ~= playerID then		-- 没有选择队伍的情况下，队伍id等于玩家id
            IsFFA = false
        end
    end

    for resource in GameInfo.Resources() do
        if (resource.ResourceClassType ~= nil and resource.ResourceClassType ~= "RESOURCECLASS_BONUS" and resource.ResourceClassType ~="RESOURCECLASS_LUXURY" and resource.ResourceClassType ~="RESOURCECLASS_ARTIFACT") then
            table.insert(g_TopPanelResources, {Index = resource.Index, Hash = resource.Hash});		-- 仅存轻量 {Index,Hash}
        end
    end
    GetTeamVisibleResources(Game.GetLocalPlayer())
end

-- ===========================================================================
-- 条目9续：战略资源点击发送交易（本分区整体 do...end 包裹）
-- 点击顶部面板战略资源 → 弹窗列出 我方持有量/各可接收队友空余/合计可发送量 → 确认后
-- 按空余降序向每个可接收队友分别发起 PROPOSED 交易提案（对方手动接受，引擎无自动接受 API）。
-- 兼容禁止交易模式：isStrategicsTradingAllowed==false 时点击不动作。
-- 依赖 DealManager（与 Base/Assets/UI/DiplomacyDealView.lua 同款 API）：
--   GetWorkingDeal / pDeal:AddItemOfType / pDealItem:SetValueType/SetAmount/SetDuration
--   / pDealItem:IsValid / pDeal:RemoveItemByID / FindItemsByType / DealManager.SendWorkingDeal
-- 弹窗控件 MPT_TPE_SendPopup 定义于 TopPanel.xml 覆盖版（内嵌本 Context，全屏居中）。
-- ===========================================================================
do
    local SendPopupIM = nil				-- 队友列表行实例管理器（惰性创建）
    local SendResourceType = nil		-- 当前弹窗对应的资源类型
    local SendTeammates = nil			-- 当前弹窗的可接收队友列表快照（{playerID, leaderName, space}，空余降序）

    -- 文本预加载缓存（条目9续：无参数纯文本 tag，运行时直接引用变量，带参数 tag 拆 PRE/SUF）
    local SendTitlePRE		= Locale.Lookup("LOC_MPT_TPE_SEND_TITLE_PRE")
    local SendTitleSUF		= Locale.Lookup("LOC_MPT_TPE_SEND_TITLE_SUF")
    local SendYourAmountPRE	= Locale.Lookup("LOC_MPT_TPE_SEND_YOUR_AMOUNT_PRE")
    local SendYourAmountSUF	= Locale.Lookup("LOC_MPT_TPE_SEND_YOUR_AMOUNT_SUF")
    local SendSpacePRE		= Locale.Lookup("LOC_MPT_TPE_SEND_SPACE_PRE")
    local SendSpaceSUF		= Locale.Lookup("LOC_MPT_TPE_SEND_SPACE_SUF")
    local SendTotalPRE		= Locale.Lookup("LOC_MPT_TPE_SEND_TOTAL_PRE")
    local SendTotalSUF		= Locale.Lookup("LOC_MPT_TPE_SEND_TOTAL_SUF")
    local SendBannedStr		= Locale.Lookup("LOC_MPT_TPE_SEND_TRADE_BANNED")
    local SendNoTeammateStr	= Locale.Lookup("LOC_MPT_TPE_SEND_NO_TEAMMATE")

    -- 构建可接收队友列表：对方该资源「存储上限 - 当前持有量」> 0，且同队（g_StrategicTeamPlayerIDs
    -- 已过滤）已相遇、非交战；按空余降序返回（先送空余大的，保证分配合理不超我方持有）
    function MPT_TPE_BuildReceivableTeammates(resourceType)
        local localPlayerID = Game.GetLocalPlayer()
        local pDiplomacy = Players[localPlayerID]:GetDiplomacy()
        local list = {}
        for j, playerID in ipairs(g_StrategicTeamPlayerIDs) do
            local pOtherRes = Players[playerID]:GetResources()
            local space = pOtherRes:GetResourceStockpileCap(resourceType) - pOtherRes:GetResourceAmount(resourceType)
            if space > 0 and pDiplomacy:HasMet(playerID) and not pDiplomacy:IsAtWarWith(playerID) then
                local leaderType = PlayerConfigurations[playerID]:GetLeaderTypeName()
                table.insert(list, {
                    playerID = playerID,
                    leaderName = Locale.Lookup(GameInfo.Leaders[leaderType].Name),
                    space = space,
                })
            end
        end
        table.sort(list, function(a, b) return a.space > b.space end)
        return list
    end

    -- 是否有可接收队友（供 RefreshResources 点击注册逻辑使用）
    function MPT_TPE_HasReceivableTeammate(resourceType)
        return #MPT_TPE_BuildReceivableTeammates(resourceType) > 0
    end

    -- 打开战略资源发送弹窗（点击资源实例触发）
    function MPT_TPE_OpenResourceSendPopup(resourceType)
        if isStrategicsTradingAllowed == false then return end		-- 禁止交易模式不响应
        local localPlayerID = Game.GetLocalPlayer()
        if localPlayerID == -1 then return end
        local pPlayerResources = Players[localPlayerID]:GetResources()
        local myAmount = pPlayerResources:GetResourceAmount(resourceType)
        if myAmount <= 0 then return end								-- 无持有不弹

        SendResourceType = resourceType
        SendTeammates = MPT_TPE_BuildReceivableTeammates(resourceType)

        -- 标题（资源图标+名）与 我方持有量
        Controls.MPT_TPE_SendTitle:SetText(SendTitlePRE.."[ICON_"..resourceType.."] "..Locale.Lookup(GameInfo.Resources[resourceType].Name)..SendTitleSUF)
        Controls.MPT_TPE_SendYourAmount:SetText(SendYourAmountPRE..myAmount..SendYourAmountSUF)

        -- 队友列表（InstanceManager 动态行：领袖名 + 空余）
        if SendPopupIM == nil then
            SendPopupIM = InstanceManager:new("MPT_TPE_SendRow", "Top", Controls.MPT_TPE_SendList)
        end
        SendPopupIM:ResetInstances()
        local totalSend = 0
        for i, mate in ipairs(SendTeammates) do
            local inst = SendPopupIM:GetInstance()
            inst.LeaderName:SetText(mate.leaderName)
            inst.SpaceText:SetText(SendSpacePRE..mate.space..SendSpaceSUF)
            totalSend = totalSend + mate.space
        end
        -- 合计可发送量：队友空余总和 与 我方持有 取小
        totalSend = math.min(totalSend, myAmount)
        Controls.MPT_TPE_SendTotal:SetText(SendTotalPRE..totalSend..SendTotalSUF)

        -- 无队友可接收时的提示
        Controls.MPT_TPE_SendBanned:SetHide(true)
        if #SendTeammates == 0 then
            Controls.MPT_TPE_SendTotal:SetText(SendNoTeammateStr)
        end

        Controls.MPT_TPE_SendList:CalculateSize()
        Controls.MPT_TPE_SendPopup:SetHide(false)
        Controls.MPT_TPE_SendPopup:CalculateSize()
    end

    -- 确认发送：向每个可接收队友分别发起 PROPOSED 提案（对方手动接受；每对玩家一单）
    function MPT_TPE_ConfirmSend()
        if isStrategicsTradingAllowed == false then MPT_TPE_CloseSendPopup() return end
        if SendResourceType == nil then MPT_TPE_CloseSendPopup() return end
        local localPlayerID = Game.GetLocalPlayer()
        local pPlayerResources = Players[localPlayerID]:GetResources()
        local resourceType = SendResourceType
        local remaining = pPlayerResources:GetResourceAmount(resourceType)		-- 我方剩余可送（硬上限）

        for i, mate in ipairs(SendTeammates) do
            if remaining <= 0 then break end
            if not DealManager.HasPendingDeal(localPlayerID, mate.playerID) then		-- 已有在途交易则跳过该队友
                local sendAmount = math.min(remaining, mate.space)
                if sendAmount > 0 then
                    local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, localPlayerID, mate.playerID)
                    if pDeal ~= nil then
                        -- 清理该资源残留条目（防与既有交易条目冲突）
                        local oldItems = pDeal:FindItemsByType(DealItemTypes.RESOURCES, DealItemSubTypes.NONE, localPlayerID)
                        if oldItems ~= nil then
                            for k, oldItem in ipairs(oldItems) do
                                if oldItem:GetValueType() == resourceType then
                                    pDeal:RemoveItemByID(oldItem:GetID())
                                end
                            end
                        end
                        local pDealItem = pDeal:AddItemOfType(DealItemTypes.RESOURCES, localPlayerID)
                        if pDealItem ~= nil then
                            pDealItem:SetValueType(resourceType)
                            pDealItem:SetDuration(30)			-- 资源交易默认 30 回合（同原版 DiplomacyDealView）
                            pDealItem:SetAmount(sendAmount)
                            if pDealItem:IsValid() then
                                DealManager.SendWorkingDeal(DealProposalAction.PROPOSED, localPlayerID, mate.playerID)
                                remaining = remaining - sendAmount
                            else
                                -- 超出单笔上限则减半重试一次，仍无效则丢弃该条目
                                local tryAmount = math.floor(sendAmount / 2)
                                if tryAmount >= 1 then
                                    pDealItem:SetAmount(tryAmount)
                                    if pDealItem:IsValid() then
                                        DealManager.SendWorkingDeal(DealProposalAction.PROPOSED, localPlayerID, mate.playerID)
                                        remaining = remaining - tryAmount
                                    else
                                        pDeal:RemoveItemByID(pDealItem:GetID())
                                    end
                                else
                                    pDeal:RemoveItemByID(pDealItem:GetID())
                                end
                            end
                        end
                    end
                end
            end
        end
        MPT_TPE_CloseSendPopup()
    end

    -- 关闭发送弹窗
    function MPT_TPE_CloseSendPopup()
        if Controls.MPT_TPE_SendPopup ~= nil then
            Controls.MPT_TPE_SendPopup:SetHide(true)
        end
        if SendPopupIM ~= nil then SendPopupIM:ResetInstances() end
        SendResourceType = nil
        SendTeammates = nil
    end

    -- 注册弹窗按钮回调（由 LateInitialize 在基类初始化后调用，此时 Controls 已构建）
    function MPT_TPE_RegisterSendPopupControls()
        if Controls.MPT_TPE_SendPopup ~= nil then
            Controls.MPT_TPE_SendConfirm:RegisterCallback(Mouse.eLClick, MPT_TPE_ConfirmSend)
            Controls.MPT_TPE_SendCancel:RegisterCallback(Mouse.eLClick, MPT_TPE_CloseSendPopup)
        end
    end
end
