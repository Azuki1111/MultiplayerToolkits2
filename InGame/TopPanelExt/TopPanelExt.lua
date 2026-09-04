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
local g_StrategicTeamLeaderNames : table = {}	-- 战略资源队友 leader 名缓存（playerID => Name，避免资源循环内重复查询）
local g_TeamLuxuryExtraCache : table = {}		-- 队友额外奢侈品 presence 缓存（playerID => {ResourceType => true}，PlayerResourceChanged 事件预过滤用，GetMoreLUXURYstr 每次全量刷新同步）

local m_FoodYieldButton = nil
local m_PopulationYieldButton = nil
local m_ProductionYieldButton = nil

-- ============================================================================
-- 条目10：兼容禁止交易模式——接线统一解析器（修复条目9 恒 true 占位：
-- 当时配置参数不存在，未接 GameConfiguration）
-- local isLuxuriesTradingAllowed = true
-- local isStrategicsTradingAllowed = true
include("MPT_TradeRules");
local tradeRules : table = MPT_ResolveTradeRules();
local isLuxuriesTradingAllowed = tradeRules.Luxuries;
local isStrategicsTradingAllowed = tradeRules.Strategics;
-- ----------------------------------------------------------------------------

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
-- 条目9 战略资源 Tooltip 无参数常量文本预加载（RefreshResources 资源循环内避免反复 Locale.Lookup；
-- 带 {1} 占位符的 tag（ACCUMULATION_PER_TURN_* / CONSUMPTION 等）须原地 带值 调用，不在此预加载）
local ResourceItemInStockpileStr	= Locale.Lookup("LOC_RESOURCE_ITEM_IN_STOCKPILE")				-- "库存中"
local ResourceItemInReserveStr		= Locale.Lookup("LOC_RESOURCE_ITEM_IN_RESERVE")					-- "储备中"

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
    g_StrategicTeamLeaderNames = {}
    local localPlayerID : number = Game.GetLocalPlayer()
    local localPlayer : table = Players[localPlayerID]
    for j, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
        if localPlayer:GetTeam() == Players[playerID]:GetTeam() and localPlayerID ~= playerID then
            table.insert(g_StrategicTeamPlayerIDs, playerID)
            local leaderType = PlayerConfigurations[playerID]:GetLeaderTypeName();
            g_StrategicTeamLeaderNames[playerID] = Locale.Lookup(GameInfo.Leaders[leaderType].Name);
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
    m_FoodYieldButton.YieldIconString:SetOffsetY(4)
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
    -- 条目9优化：presence 缓存惰性初始化（PlayerResourceChanged 事件预过滤用）
    local teamLuxuryCache : table = g_TeamLuxuryExtraCache[playerID]
    if teamLuxuryCache == nil then
        teamLuxuryCache = {}
        g_TeamLuxuryExtraCache[playerID] = teamLuxuryCache
    end
    local More = false

    for resource in GameInfo.Resources() do
        if resource.ResourceClassType ~= nil and resource.ResourceClassType == "RESOURCECLASS_LUXURY" then
            local amount = pPlayerResources:GetResourceAmount(resource.ResourceType)
            teamLuxuryCache[resource.ResourceType] = (amount > 1) or nil		-- 同步 presence 缓存（事件预过滤用）
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

                    -- 显示判定所需 getter（轻量提前；不显示则跳过后续 cap/reserved/Tooltip/队友循环）
                    local stockpileAmount : number = pPlayerResources:GetResourceAmount(resource.ResourceType);
                    local accumulationPerTurn : number = pPlayerResources:GetResourceAccumulationPerTurn(resource.ResourceType);
                    local importPerTurn : number = pPlayerResources:GetResourceImportPerTurn(resource.ResourceType);
                    local bonusPerTurn : number = pPlayerResources:GetBonusResourcePerTurn(resource.ResourceType);
                    local unitConsumptionPerTurn : number = pPlayerResources:GetUnitResourceDemandPerTurn(resource.ResourceType);
                    local powerConsumptionPerTurn : number = pPlayerResources:GetPowerResourceDemandPerTurn(resource.ResourceType);
                    local totalAccumulationPerTurn : number = accumulationPerTurn + importPerTurn + bonusPerTurn;
                    local totalConsumptionPerTurn : number = unitConsumptionPerTurn + powerConsumptionPerTurn;

                    if (stockpileAmount > 0 or totalAccumulationPerTurn > 0 or totalConsumptionPerTurn > 0 or g_TeamVisibleResources[resource.Index]) then		-- 当解锁时显示
                        -- 仅显示时再取 cap/reserved、拼 Tooltip、跑队友循环（不可见资源跳过全部重活）
                        local stockpileCap : number = pPlayerResources:GetResourceStockpileCap(resource.ResourceType);
                        local reservedAmount : number = pPlayerResources:GetReservedResourceAmount(resource.ResourceType);
                        local totalAmount : number = stockpileAmount + reservedAmount;

                        if (totalAmount > stockpileCap) then
                            totalAmount = stockpileCap;
                        end

                        local iconName : string = "[ICON_"..resource.ResourceType.."]";

                        local resourceText : string = iconName .. " " .. stockpileAmount;

                        local numDigits : number = 3;
                        if (stockpileAmount >= 10) then
                            numDigits = 4;
                        end
                        local guessinstanceWidth : number = math.ceil(numDigits * FONT_MULTIPLIER);

                        local tooltip : string = iconName .. " " .. Locale.Lookup(resource.Name);
                        if (reservedAmount ~= 0) then
                            tooltip = tooltip .. "[NEWLINE]" .. totalAmount .. "/" .. stockpileCap .. " " .. ResourceItemInStockpileStr;
                            tooltip = tooltip .. "[NEWLINE]-" .. reservedAmount .. " " .. ResourceItemInReserveStr;
                        else
                            tooltip = tooltip .. "[NEWLINE]" .. totalAmount .. "/" .. stockpileCap .. " " .. ResourceItemInStockpileStr;
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

        local LeaderName = g_StrategicTeamLeaderNames[playerID];		-- leader 名缓存（BuildStrategicTeamPlayerIDs 填充，避免每资源重查）

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
-- 条目9优化：PlayerResourceChanged 事件处理器（奢侈品显示及时刷新）
-- 基类仅把该事件挂到战略资源刷新；本处理器过滤后驱动 RefreshLuxuryResourcesType，
-- 使队友/自己奢侈品数量变化当回合即更新按钮计数、[icon_PressureHigh] 标记与 tooltip。
-- 三层过滤：① 仅奢侈品资源类（resourceTypeID 即 GameInfo.Resources 行键）；
-- ② 显示范围玩家（自己 / 同队存活主要玩家，FFA 时全部存活主要玩家，城邦蛮族排除）；
-- ③ g_TeamLuxuryExtraCache presence 缓存——队友额外区只显示「>1 的存在性」，
--    1 边界未翻转（如 3→2、2→3、0→1）时显示不变，跳过重刷新；缓存由 GetMoreLUXURYstr 每次全量刷新同步。
-- ===========================================================================
function OnMPTPlayerResourceChanged(ownerPlayerID:number, resourceTypeID:number)
    -- 过滤① 资源类：仅奢侈品
    local resource = (resourceTypeID ~= nil and resourceTypeID >= 0) and GameInfo.Resources[resourceTypeID] or nil
    if resource == nil or resource.ResourceClassType ~= "RESOURCECLASS_LUXURY" then
        return
    end
    local localPlayerID : number = Game.GetLocalPlayer()
    if localPlayerID == -1 or ownerPlayerID == nil or ownerPlayerID < 0 then
        return
    end
    local ownerPlayer : table = Players[ownerPlayerID]
    if ownerPlayer == nil then
        return
    end
    -- 过滤② 玩家范围：自己必刷（按钮计数/自己额外区数量变化）；队友要求存活主要玩家 + 同队（或 FFA）
    if ownerPlayerID ~= localPlayerID then
        if not ownerPlayer:IsAlive() or not ownerPlayer:IsMajor() then
            return
        end
        local localPlayer : table = Players[localPlayerID]
        if not IsFFA and localPlayer:GetTeam() ~= ownerPlayer:GetTeam() then
            return
        end
        -- 过滤③ presence 缓存：1 边界未翻转则显示不变，跳过重刷新
        local isExtra : boolean = ownerPlayer:GetResources():GetResourceAmount(resource.ResourceType) > 1
        local teamLuxuryCache : table = g_TeamLuxuryExtraCache[ownerPlayerID]
        if teamLuxuryCache ~= nil and ((teamLuxuryCache[resource.ResourceType] ~= nil) == isExtra) then
            return
        end
    end
    RefreshLuxuryResourcesType()
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

    Events.ResearchCompleted.Add(GetTeamVisibleResources);
    Events.CivicCompleted.Add(GetTeamVisibleResources);
    Events.PlayerResourceChanged.Add(OnMPTPlayerResourceChanged);		-- 条目9优化：奢侈品变化及时刷新（过滤见 OnMPTPlayerResourceChanged）

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

