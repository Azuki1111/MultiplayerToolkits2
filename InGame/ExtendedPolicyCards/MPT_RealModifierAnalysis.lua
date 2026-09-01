-- ===========================================================================
-- [MPT 条目21] Real Modifier Analysis（RMA 引擎, by Infixo, v7.0）
-- 来源：联机工具箱 1.67 BRS/RealModifierAnalysis.lua，MPT_ 前缀改名（防与 1.67 同装时
-- VFS 同名撞车）。经 AddUserInterfaces（Context=InGame）+ 本目录同名 MPT_RealModifierAnalysis.xml
-- 空壳 Context 配对自动执行（同条目5/12/13 机制），向 ExposedMembers.RMA 导出 6 个函数；
-- 本 mod 唯一消费方为 GovernmentScreen_MPT.lua（条目21 政策卡收益显示，EPC 的数据依赖层）。
-- 本文件相对 1.67 的改动（其余逐字节一致）：
--   删除第 1 行 print：其读取 GlobalParameters.BRS_VERSION_MAJOR/MINOR（由 BRS 的
--   BetterReportScreen_Database.sql 写入，本 mod 不移植该 SQL），nil 参与字符串连接会
--   崩整个 chunk（条目18 cfunction 同类坑）；RMA 全文仅此一处读 BRS 全局，删除即完全独立。
-- [MPT 条目21优化] 政策卡收益类型扩展：政策卡实际使用 90 种 EffectType（含 attach 一层，
--   经 Cache/DebugGameplay.sqlite 逐一枚举），引擎原仅处理 31 种，其余一律红字 Unknown。
--   新增 MPT 文本行通道（MPT_LineHandlers 58 种 EffectType + 两个 hook + 行缓存
--   MPT_LineCache + modifiers 懒索引 MPT_GetObjectModifierIds），分区见 FetchAndCacheData
--   之后的「MPT 文本行通道」横幅区；产量计算与原 31 种处理逻辑零改动。
--   顺带优化：CalculateModifierEffect 由全表扫描改按 (表,字段,类型) 懒索引。
-- [MPT 条目21用户裁决] 显示类型收敛为 20 种：仅保留「明确的资源数量加成/产出加成
--   (金/信/科/文/产/食/外交支持)/伟人点数/生产对象的生产力加成」+ 影响力点/联盟点/建造者次数
--   （供用户进一步裁决）；其余 38 种登记 MPT_KnownEffects 静默化（费用折扣/旅游/移动/经验/
--   战力/间谍/厌战/劫掠百分比/使者倍率/电力/开关定性类——不显示也不红字）。显示行一律不描述
--   回合（/每回合 字样删除）。图标 token 以本 mod IconViewer_Data.sql（游戏 XML 全量收集的
--   4975 个真实图标文本）核对修正：[ICON_Favor]→[ICON_FAVOR]。
-- [MPT 条目21用户裁决·实际计算] 显示从静态参数升级为实际数值：
--   ①生产族 9 种走 MPT_ImpactHandlers 产量通道（ApplyEffectAndCalculateImpact 顶部 hook）：
--     城市当前生产对象（BuildQueue hash 反查四表）匹配判定（含文明替代单位/建筑/区域、
--     PromotionClass+PrereqTech 时代、Projects.SpaceRace、奇观时代区间）→ 城市生产力 ×
--     Amount%，城市集合自动跨城求和，显示为真实产量数字（+X [生产图标]）
--   ②资源积累 = Amount × 玩家提取中地块数（Map 全图遍历 + IsResourceExtractableAt 引擎
--     判定，含被区域/奇观覆盖）；每城免费资源 = Amount × 城市数；每座建筑支持 = Favor ×
--     建筑数；对城邦商路 = Amount × 对城邦商路条数；伟人点 = Amount × 至下一位招募回合数
--     （上限为剩余缺口；池经 Game.GetGreatPeople():GetTimeline()，点数接口同原版
--     GreatPeoplePopup 800-801 行）——五类登记 MPT_DynamicHandlers 实时计算不缓存，
--     RefreshBaseData 时失效行/提取缓存；无收益（如无提取地块/无对城邦商路）时整行不显示
-- ===========================================================================
-- print("Loading Real Modifier Analysis.lua from Better Report Screen version "..GlobalParameters.BRS_VERSION_MAJOR.."."..GlobalParameters.BRS_VERSION_MINOR);
-- ===========================================================================
-- Real Modifier Analysis
-- Author: Infixo
-- Created: February 25th - March 1st, 2018
-- ===========================================================================

-- exposing functions and variables
if not ExposedMembers.RMA then ExposedMembers.RMA = {} end;
local RMA = ExposedMembers.RMA;
-- insert functions/objects into RMA in Initialize()

-- Expansions check
local bIsRiseAndFallMod:boolean = Modding.IsModActive("1B28771A-C749-434B-9053-D1380C553DE9"); -- Rise & Fall
local bIsGatheringStorm:boolean = Modding.IsModActive("4873eb62-8ccc-4574-b784-dda455e74e68"); -- Gathering Storm
local bIsRiseAndFall:boolean = (bIsRiseAndFallMod or bIsGatheringStorm); -- GS includes gameplay features from RF


-- ===========================================================================
-- DEBUG ROUTINES
-- ===========================================================================

-- debug output routine
function dprint(sStr,p1,p2,p3,p4,p5,p6)
	local sOutStr = sStr;
	if p1 ~= nil then sOutStr = sOutStr.." [1] "..tostring(p1); end
	if p2 ~= nil then sOutStr = sOutStr.." [2] "..tostring(p2); end
	if p3 ~= nil then sOutStr = sOutStr.." [3] "..tostring(p3); end
	if p4 ~= nil then sOutStr = sOutStr.." [4] "..tostring(p4); end
	if p5 ~= nil then sOutStr = sOutStr.." [5] "..tostring(p5); end
	if p6 ~= nil then sOutStr = sOutStr.." [6] "..tostring(p6); end
	print(sOutStr);
end

-- debug routine - print contents of a table of plot indices
function dshowinttable(pTable:table)  -- For debugging purposes. LOT of table data being handled here.
	-- for ease of reading they will be printed in rows by 10
	dprint("Showing table (t,count)", pTable, table.count(pTable));
	local iSize = table.count(pTable);
	if iSize == 0 then dprint("...nothing to show"); return; end
	for y = 0, math.floor((iSize-1)/10), 1 do
		local sOutStr = "";
		for x = 0,9,1 do
			local idx = 10*y+x;
			if idx < iSize then sOutStr = sOutStr..string.format("%5d", pTable[idx+1]); end
		end
		dprint("  row", y, sOutStr);
	end
end

-- debug routine - prints a table (no recursion)
function dshowtable(tTable:table)
	for k,v in pairs(tTable) do
		print(k, type(v), tostring(v));
	end
end

-- debug routine - prints a table, and tables inside recursively (up to 5 levels)
function dshowrectable(tTable:table, iLevel:number)
	local level:number = 0;
	if iLevel ~= nil then level = iLevel; end
	for k,v in pairs(tTable) do
		print(string.rep("---:",level), k, type(v), tostring(v));
		if type(v) == "table" and level < 5 then dshowrectable(v, level+1); end
	end
end

-- debug routine - prints extended yields table in a compacted form (1 line, formatted)
function dshowyields(pYields:table)
	local tOut:table = {}; table.insert(tOut, "  yields :");
	for yield,value in pairs(pYields) do table.insert(tOut, string.format("%s %5.2f :", yield, value)); end
	print(table.concat(tOut, " "));
end

-- debug routine - prints extended yields table in a compacted form (1 line, formatted)
function dshowsubject(pSubject:table)
	print("    sub: ", pSubject.SubjectType, pSubject.Name);
end

--dprint("Subjects are:"); for k,v in pairs(tSubjects) do print(k,v.SubjectType,v.Name); end -- debug
-- debug routne - prints all subjects in 1 line
function dshowsubjects(pSubjects:table)
	local tOut:table = {};
	for _,subject in pairs(pSubjects) do table.insert(tOut, subject.Name); end
	print("Subjects:", table.count(pSubjects), table.concat(tOut, ","));
end

--------------------------------------------------------------
-- Timer; usage is: Reset -> repeat ()
--------------------------------------------------------------

local MILISECS_PER_TICK: number = 10000;
local m_Timer1: number = 0
local m_Timer2: number = 0
local m_NumTicks1: number = 0;
local m_NumTicks2: number = 0;
local m_StartTime1: number = 0;
local m_StartTime2: number = 0;

function Timer1Reset()
	m_Timer1 = 0; m_NumTicks1 = 0;
end
function Timer2Reset()
	m_Timer2 = 0; m_NumTicks2 = 0;
end
function Timer1Start()
	m_StartTime1 = GetTickCount();
end
function Timer2Start()
	m_StartTime2 = GetTickCount();
end
function Timer1Tick()
	m_Timer1 = m_Timer1 + (GetTickCount()-m_StartTime1);
	m_NumTicks1 = m_NumTicks1 + 1;
	--print("Ticker1:", m_NumTicks1, m_Timer1); -- debug
end
function Timer2Tick()
	m_Timer2 = m_Timer2 + (GetTickCount()-m_StartTime2);
	m_NumTicks2 = m_NumTicks2 + 1;
	--print("Ticker2:", m_NumTicks2, m_Timer2); -- debug
end
function Timer1Stop(txt:string)
	if m_NumTicks1 == 0 then print("Timer1: no ticks"); return; end
	print("Timer1:", txt, math.floor(m_Timer1/MILISECS_PER_TICK), "milisecs", m_NumTicks1, "ticks", math.floor(m_Timer1/m_NumTicks1), "per tick");
end
function Timer2Stop(txt:string)
	if m_NumTicks2 == 0 then print("Timer2: no ticks"); return; end
	print("Timer2:", txt, math.floor(m_Timer2/MILISECS_PER_TICK), "milisecs", m_NumTicks2, "ticks", math.floor(m_Timer2/m_NumTicks2), "per tick");
end


-- ===========================================================================
-- DATA AND VARIABLES
-- ===========================================================================

local bBaseDataDirty:boolean = true; -- set to true to refresh the data
local tCities: table = nil; -- dynamically filled when needed (e.g. after refresh)
local tPlayer: table = nil; -- dynamically filled when needed (e.g. after refresh)
local tPlots: table = nil; -- only the local player's plots

-- supported Subject types, will be put into SubjectType field of respective tables
local SubjectTypes:table = {
	Game = "Game",
	Player = "Player",
	City = "City",
	District = "District",
	Building = "Building",
	Unit = "Unit",
	GreatWork = "GreatWork",
	TradeRoute = "TradeRoute",
	Plot = "Plot", -- also plot yields
}

-- 230521 #13 Building_YieldDistrictCopies
local tDistrictYieldCopies: table = {};
function InitializeDistrictYieldCopies()
	for row in GameInfo.Building_YieldDistrictCopies() do
		if tDistrictYieldCopies[row.BuildingType] == nil then tDistrictYieldCopies[row.BuildingType] = {}; end
		--table.insert(tDistrictYieldCopies[row.BuildingType], { Old = row.OldYieldType, New = row.NewYieldType}); -- too complex, assume 1=>1 copying
		tDistrictYieldCopies[row.BuildingType][row.OldYieldType] = row.NewYieldType;
	end
end
InitializeDistrictYieldCopies();


-- ===========================================================================
-- EXTENDED YIELDS
-- extended yields to support other effects, like Amenities, Tourism, etc.
-- ===========================================================================

-- YieldsTypes 0..5 are for FOOD, PRODUCTION, GOLD, SCIENCE, CULTURE and FAITH
-- they correspond to respective YIELD_ type in Yields table
YieldTypes.TOURISM = 6
YieldTypes.AMENITY = 7
YieldTypes.HOUSING = 8
YieldTypes.LOYALTY = 9
--YieldTypes.GPPOINT =  9 -- Great Person Point
--YieldTypes.ENVOY   = 10
--YieldTypes.APPEAL  = 11
-- whereever possible keep yields in a table named Yields with entries { YieldType = YieldValue }

-- create maps (speed up)
local YieldTypesMap: table = {};
for yield in GameInfo.Yields() do
	YieldTypesMap[ yield.YieldType ] = string.gsub(yield.YieldType, "YIELD_","");
end
local YieldTypesOrder: table = {};
for yield,yid in pairs(YieldTypes) do
	YieldTypesOrder[yid] = yield;
end 
--print("YieldTypes"); dshowtable(YieldTypes);
--print("YieldTypesMap"); dshowtable(YieldTypesMap);
--print("YieldTypesOrder"); --dshowtable(YieldTypesOrder);
--for yid,yield in ipairs(YieldTypesOrder) do dprint("YieldTypesOrder", yid, yield) end

-- get a new table with all 0
function YieldTableNew()
	local tNew:table = {};
	for yield,_ in pairs(YieldTypes) do tNew[ yield ] = 0; end
	return tNew;
end

-- set all values to 0
function YieldTableClear(pYields:table)
	for yield,_ in pairs(YieldTypes) do pYields[ yield ] = 0; end
end

-- add two tables
function YieldTableAdd(pYields:table, pYieldsToAdd:table)
	for yield,_ in pairs(YieldTypes) do pYields[ yield ] = pYields[ yield ] + pYieldsToAdd[ yield ]; end
end

-- multiply by a given number
function YieldTableMultiply(pYields:table, fModifier:number)
	for yield,_ in pairs(YieldTypes) do pYields[ yield ] = pYields[ yield ] * fModifier; end
end

-- 230522 #3 multiply by a table of numbers
function YieldTableMultiplyTable(pYields:table, pModifier:table)
	for yield,_ in pairs(YieldTypes) do pYields[ yield ] = pYields[ yield ] * pModifier[ yield ]; end
end

-- multiply by a percentage given as integer 0..100
function YieldTablePercent(pYields:table, iPercent:number)
	return YieldTableMultiply(pYields, iPercent/100.0);
end

-- get a specific yield, takes both YieldTypes and "YIELD_XXX" form
function YieldTableGetYield(pYields:table, sYield:string)
	if YieldTypesMap[ sYield ] then return pYields[ YieldTypesMap[ sYield ] ];
	else                            return pYields[ sYield ];                  end
end

-- set a specific yield, takes both YieldTypes and "YIELD_XXX" form
function YieldTableSetYield(pYields:table, sYield:string, fValue:number)
	if YieldTypesMap[ sYield ] then pYields[ YieldTypesMap[ sYield ] ] = fValue;
	else                            pYields[ sYield ] = fValue;                  end
end

-- returns a compacted string with yields info
function YieldTableGetInfo(pYields:table)
	local sYieldInfo:string = "";
	for	_,yield in ipairs(YieldTypesOrder) do
		if pYields[yield] ~= 0 then sYieldInfo = sYieldInfo..(sYieldInfo == "" and "" or " ")..GetYieldString("YIELD_"..yield, pYields[yield]); end
	end
	return sYieldInfo;
end

-- 2019-06-20 GS introduced multiple yields in one modifier, separated with comma
function YieldTableSetMultipleYields(pYields:table, sYields:string, sValues:string)
	sYields = string.gsub(sYields, " ", ""); -- 230522 #3 Some of them have spaces inside, values are converted to number so it's not a problem
	sYields = sYields..",";	sValues = sValues..",";
	while string.len(sYields) > 0 and string.len(sValues) > 0 do
		local iCommaYields:number = string.find(sYields, ",");
		local iCommaValues:number = string.find(sValues, ",");
		--print("YieldTableSetMultipleYields", sYields, iCommaYields, sValues, iCommaValues);
		YieldTableSetYield(pYields, string.sub(sYields, 1, iCommaYields-1), tonumber(string.sub(sValues, 1, iCommaValues-1)));
		-- remove processed yield
		sYields = string.sub(sYields, iCommaYields+1);
		sValues = string.sub(sValues, iCommaValues+1);
	end
end


-- ===========================================================================
-- GENERIC FUNCTIONS AND HELPERS
-- ===========================================================================

function GetGameInfoIndex(sTableName:string, sTypeName:string) 
	local tTable = GameInfo[sTableName];
	if tTable then
		local row = tTable[sTypeName];
		if row then return row.Index
		else        return -1;        end
	end
	return -1;
end

-- check if 'value' exists in table 'pTable'; should work for any type of 'value' and table indices
function IsInTable(pTable:table, value)
	for _,data in pairs(pTable) do
		if data == value then return true; end
	end
	return false;
end

-- returns 'key' at which a given 'value' is stored in table 'pTable'; nil if not found; should work for any type of 'value' and table indices
function GetTableKey(pTable:table, value)
	for key,data in pairs(pTable) do
		if data == value then return key; end
	end
	return nil;
end

-- changes "AA_BB_CC" string into "Aa Bb Cc"
function Capitalize(sText:string)
	--local str:string = sText:gsub("_", " ");
	--return tostring( str:gsub("(%a)([%w_']*)", function(first,rest) return first:upper()..rest:lower() end) );
	return sText; -- debug
end


-- ===========================================================================
-- Couple of functions from include("Civ6Common");
-- ===========================================================================

-- ===========================================================================
--	Return the inline text-icon for a given yield
--	yieldType	A database YIELD_TYPE
--	returns		The [ICON_yield] string
-- ===========================================================================
function GetYieldTextIcon( yieldType:string )
	local  iconString:string = "";
	if		yieldType == nil or yieldType == ""	then
		iconString = "Error:NIL";
	elseif  yieldType == "YIELD_TOURISM" then
		iconString = "[ICON_Tourism]"
	elseif  yieldType == "YIELD_AMENITY" then
		iconString = "[ICON_Amenities]" -- [ICON_Therefore] a green arrow pointing to the right
	elseif  yieldType == "YIELD_HOUSING" then
		iconString = "[ICON_Housing]" -- [ICON_LocationPip] a blue pin pointing down
	elseif  yieldType == "YIELD_LOYALTY" then
		iconString = "[ICON_PressureUp]" -- [ICON_PressureDown] is a red arrow pointing down
	elseif	GameInfo.Yields[yieldType] ~= nil and GameInfo.Yields[yieldType].IconString ~= nil and GameInfo.Yields[yieldType].IconString ~= "" then
		iconString = GameInfo.Yields[yieldType].IconString;
	else
		iconString = "Unknown:"..yieldType; 
	end			
	return iconString;
end

-- ===========================================================================
--	Return the inline entry for a yield's color
-- ===========================================================================
function GetYieldTextColor( yieldType:string )
	if     yieldType == nil or yieldType == "" then return "[COLOR:255,255,255,255]NIL ";
	elseif yieldType == "YIELD_FOOD"		   then return "[COLOR:ResFoodLabelCS]";
	elseif yieldType == "YIELD_PRODUCTION"	   then return "[COLOR:ResProductionLabelCS]";
	elseif yieldType == "YIELD_GOLD"		   then return "[COLOR:ResGoldLabelCS]";
	elseif yieldType == "YIELD_SCIENCE"		   then return "[COLOR:ResScienceLabelCS]";
	elseif yieldType == "YIELD_CULTURE"		   then return "[COLOR:ResCultureLabelCS]";
	elseif yieldType == "YIELD_FAITH"		   then return "[COLOR:ResFaithLabelCS]";
	elseif yieldType == "YIELD_TOURISM"		   then return "[COLOR:ResTourismLabelCS]";
	elseif yieldType == "YIELD_AMENITY"        then return "[COLOR_White]";
	elseif yieldType == "YIELD_HOUSING"        then return "[COLOR_White]";
	elseif yieldType == "YIELD_LOYALTY"        then return "[COLOR_White]";
	else											return "[COLOR:255,255,255,0]ERROR ";
	end				
end

-- ===========================================================================
-- Updated functions from Civ6Common, to include rounding to 1 decimal digit
-- ===========================================================================
function toPlusMinusString( value:number )
	if value == 0 then return "0"; end
	--return Locale.ToNumber(value, "+#,###.#;-#,###.#");
	return Locale.ToNumber(math.floor((value*10)+0.5)/10, "+#,###.#;-#,###.#");
end

function toPlusMinusNoneString( value:number )
	if value == 0 then return " "; end
	--return Locale.ToNumber(value, "+#,###.#;-#,###.#");
	return Locale.ToNumber(math.floor((value*10)+0.5)/10, "+#,###.#;-#,###.#");
end

-- ===========================================================================
--	Return a string with a yield icon and a +/- based on yield amount.
-- ===========================================================================
function GetYieldString( yieldType:string, amount:number )
	return GetYieldTextIcon(yieldType)..GetYieldTextColor(yieldType)..toPlusMinusString(amount).."[ENDCOLOR]";
end


-- ===========================================================================
--	This function is from SupportFunctions.lua
--	return a table indexed by buildingType, with a table of GameInfo.GreatWorks in that building
-- ===========================================================================

function GetGreatWorksForCity(pCity:table)
	local result:table = {};
	if pCity then
		local pCityBldgs:table = pCity:GetBuildings();
		for buildingInfo in GameInfo.Buildings() do
			local buildingIndex:number = buildingInfo.Index;
			local buildingType:string = buildingInfo.BuildingType;
			if(pCityBldgs:HasBuilding(buildingIndex)) then
				local numSlots:number = pCityBldgs:GetNumGreatWorkSlots(buildingIndex);
				if (numSlots ~= nil and numSlots > 0) then
					local greatWorksInBuilding:table = {};

					-- populate great works
					for index:number=0, numSlots - 1 do
						local greatWorkIndex:number = pCityBldgs:GetGreatWorkInSlot(buildingIndex, index);
						if greatWorkIndex ~= -1 then
							local greatWorkType:number = pCityBldgs:GetGreatWorkTypeFromIndex(greatWorkIndex);
							table.insert(greatWorksInBuilding, GameInfo.GreatWorks[greatWorkType]);
							-- YIELDS: only Tourism (field Tourism)
						end
					end

					-- create association between building type and great works
					if #greatWorksInBuilding > 0 then
						result[buildingType] = greatWorksInBuilding;
					end
					-- THEMED use pCityBldgs:IsBuildingThemedCorrectly()
					-- local regularTourism:number = pCityBldgs:GetBuildingTourismFromGreatWorks(false, buildingIndex);
					-- local religionTourism:number = pCityBldgs:GetBuildingTourismFromGreatWorks(true, buildingIndex);
					-- local yieldValue:number = pCityBldgs:GetBuildingYieldFromGreatWorks(yieldIndex, buildingIndex);
				end
			end
		end
	end
	return result;
end


-- ===========================================================================
-- A function for grabbing city data - from City Support by Firaxis
-- ===========================================================================

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
DATA_DOMINANT_RELIGION = "_DOMINANTRELIGION";

--YIELD_STATE = {
	--NORMAL  = 0,
	--FAVORED = 1,
	--IGNORED = 2
--}

-- 230522 #17 Districts with HitPoints can be garrisoned
local tGarrisonDistricts: table = {};
for row in GameInfo.Districts() do
	if row.HitPoints > 0 then tGarrisonDistricts[row.DistrictType] = true; end
end


-- ===========================================================================
--	Obtains the texture for a city's current production.
--	pCity				The city
--	optionalIconSize	Size of the icon to return.
--
--	RETURNS	NIL if error, otherwise a table containing:
--			name of production item
--			description
--			icon texture of the produced item
--			u offset of the icon texture
--			v offset of the icon texture
--			(0-1) percent complete
--			(0-1) percent complete after next turn
--			# of turns
--			progress
--			cost
-- ===========================================================================
function GetCurrentProductionInfoOfCity( pCity:table, iconSize:number )
	local pBuildQueue	:table = pCity:GetBuildQueue();
	if pBuildQueue == nil then
		UI.DataError("No production queue in city!");
		return nil;
	end	
	local hash	:number = pBuildQueue:GetCurrentProductionTypeHash();
	local data	:table  = GetProductionInfoOfCity(pCity, hash);
	return data;
end


-- ===========================================================================
--	Update the yield data for a city.
-- ===========================================================================
--[[
function UpdateYieldData( pCity:table, data:table )
	data.CulturePerTurn				= pCity:GetYield( YieldTypes.CULTURE );
	data.CulturePerTurnToolTip		= pCity:GetYieldToolTip(YieldTypes.CULTURE);

	data.FaithPerTurn				= pCity:GetYield( YieldTypes.FAITH );
	data.FaithPerTurnToolTip		= pCity:GetYieldToolTip(YieldTypes.FAITH);

	data.FoodPerTurn				= pCity:GetYield( YieldTypes.FOOD );
	data.FoodPerTurnToolTip			= pCity:GetYieldToolTip(YieldTypes.FOOD);

	data.GoldPerTurn				= pCity:GetYield( YieldTypes.GOLD );
	data.GoldPerTurnToolTip			= pCity:GetYieldToolTip(YieldTypes.GOLD);

	data.ProductionPerTurn			= pCity:GetYield( YieldTypes.PRODUCTION );
	data.ProductionPerTurnToolTip	= pCity:GetYieldToolTip(YieldTypes.PRODUCTION);

	data.SciencePerTurn				= pCity:GetYield( YieldTypes.SCIENCE );
	data.SciencePerTurnToolTip		= pCity:GetYieldToolTip(YieldTypes.SCIENCE);

	return data;
end
--]]

-- ===========================================================================
-- ===========================================================================
function GetDistrictYieldText(district)
	local yieldText = "";
	for yield in GameInfo.Yields() do
		local yieldAmount = district:GetYield(yield.Index);
		if yieldAmount > 0 then
			yieldText = yieldText .. GetYieldString( yield.YieldType, yieldAmount );
		end
	end
	return yieldText;
end


-- ===========================================================================
--	Obtain the total resources for a given city.
-- ===========================================================================
function GetCityResourceData( pCity:table )

	-- Loop through all the plots for a given city; tallying the resource amount.
	local kResources : table = {};
	local cityPlots : table = Map.GetCityPlots():GetPurchasedPlots(pCity)
	for _, plotID in ipairs(cityPlots) do
		local plot			: table = Map.GetPlotByIndex(plotID)
		local plotX			: number = plot:GetX()
		local plotY			: number = plot:GetY()
		local eResourceType : number = plot:GetResourceType();

		-- TODO: Account for trade/diplomacy resources.
		if eResourceType ~= -1 and Players[pCity:GetOwner()]:GetResources():IsResourceExtractableAt(plot) then
			if kResources[eResourceType] == nil then
				kResources[eResourceType] = 1;
			else
				kResources[eResourceType] = kResources[eResourceType] + 1;
			end
		end
	end
	return kResources;
end

-- ===========================================================================
-- Retrieve Governor data, if applicable
-- Is established?, Count how many promotions a governor has
function GetGovernorData(pCity:table)
	if not bIsRiseAndFall then return false, 0 end
	local pGovernor:table = pCity:GetAssignedGovernor()
	if not pGovernor then return false, 0 end
	-- count promotions
	local iNumPromos:number = 0
	local sGovernorType:string = GameInfo.Governors[ pGovernor:GetType() ].GovernorType
	for row in GameInfo.GovernorPromotions() do
		if row.GovernorType == sGovernorType and pGovernor:HasPromotion(row.Index) then iNumPromos = iNumPromos + 1 end
	end
	return pGovernor:IsEstablished(), iNumPromos
end

-- ===========================================================================
--	For a given city, return a table o' data for it and the surrounding
--	districts.
--	RETURNS:	table of data
--				.City - city object
--				.field - city data
--				.Districts - table of Districts (has Buildings inside)
--						.Buildings - table of Buildings in the District
--				.Wonders - wonders
--				.OutgoingRoutes - trade routes
--				.IncomingRoutes - trade routes
-- ===========================================================================
function GetCityData( pCity:table )

	local ownerID				:number = pCity:GetOwner();
	local pPlayer				:table	= Players[ownerID];
	local pCityDistricts		:table	= pCity:GetDistricts();
	local pMainDistrict			:table	= pPlayer:GetDistricts():FindID( pCity:GetDistrictID() );	-- Note player GetDistrict's object is different than above.
	local districtHitpoints		:number	= 0;
	local currentDistrictDamage :number = 0;
	local wallHitpoints			:number	= 0;
	local currentWallDamage		:number	= 0;
	local garrisonDefense		:number	= 0;

	if pCity ~= nil and pMainDistrict ~= nil then
		districtHitpoints		= pMainDistrict:GetMaxDamage(DefenseTypes.DISTRICT_GARRISON);
		currentDistrictDamage	= pMainDistrict:GetDamage(DefenseTypes.DISTRICT_GARRISON);
		wallHitpoints			= pMainDistrict:GetMaxDamage(DefenseTypes.DISTRICT_OUTER);
		currentWallDamage		= pMainDistrict:GetDamage(DefenseTypes.DISTRICT_OUTER);
		garrisonDefense			= math.floor(pMainDistrict:GetDefenseStrength() + 0.5);
	end

	-- Return value is here, 0/nil may be filled out below.
	local data :table = {
		City					= pCity,
		SubjectType				= SubjectTypes.City,
		Name					= Locale.Lookup(pCity:GetName()),
		Yields 					= YieldTableNew(), -- extended yields
		ContinentType			= 0,
		Districts				= {},		-- Per Entry Format: { Name, YieldType, YieldChange, Buildings={ Name,YieldType,YieldChange,isPillaged,isBuilt} }
		FoodSurplus				= 0,
		IsGovernorEstablished	= false,
		NumDistricts			= 0,
		NumSpecialtyDistricts	= 0,
		Population				= pCity:GetPopulation(),
		Wonders					= {},		-- Format per entry: { Name, YieldType, YieldChange }
		Plot 					= Map.GetPlot(pCity:GetX(), pCity:GetY()),
		NumResources            = 0, -- 230522 #10 Johannesburg
		IsGarrisonUnit          = false, -- 230522 #17 Garrison in a city
		
		--- not used yet
		AmenitiesNetAmount				= 0,
		AmenitiesNum					= 0,
		AmenitiesFromLuxuries			= 0,
		AmenitiesFromEntertainment		= 0,
		AmenitiesFromCivics				= 0,
		AmenitiesFromGreatPeople		= 0,
		AmenitiesFromCityStates			= 0,
		AmenitiesFromReligion			= 0,
		AmenitiesFromNationalParks  	= 0,
		AmenitiesFromStartingEra		= 0,
		AmenitiesFromImprovements		= 0,
		AmenitiesRequiredNum			= 0,
		AmenitiesFromGovernors			= 0,
		BeliefsOfDominantReligion		= {},
		Buildings						= {},		-- Per Entry Format: { Name, CitizenNum }
		BuildingsNum					= 0,
		CityWallTotalHP					= 0,
		CityWallHPPercent				= 0,
		CulturePerTurn					= 0,
		CurrentFoodPercent				= 0;		
		CurrentProdPercent				= 0,
		CurrentProductionName			= "",
		CurrentProductionDescription	= "",
		CurrentTurnsLeft				= 0,
		Damage							= 0,
		Defense							= garrisonDefense;
		DistrictsNum					= pCityDistricts:GetNumZonedDistrictsRequiringPopulation(),
		DistrictsPossibleNum			= pCityDistricts:GetNumAllowedDistrictsRequiringPopulation(),
		FaithPerTurn					= 0,
		FoodPercentNextTurn				= 0,
		FoodPerTurn						= 0,
		GoldPerTurn						= 0,
		GrowthPercent					= 100,
		Happiness						= 0,		
		HappinessGrowthModifier			= 0,		-- Multiplier
		HappinessNonFoodYieldModifier	= 0,		-- Multiplier
		Housing							= 0,
		HousingMultiplier				= 0,
		IsCapital						= pCity:IsCapital(),
		IsUnderSiege					= false,
		OccupationMultiplier            = 0,
		OwnerID							= ownerID,
		OtherGrowthModifiers			= 0,
		PantheonBelief					= -1,
		ProdPercentNextTurn				= 0,
		ProductionPerTurn				= 0;		
		ProductionQueue					= {},
		Religions						= {},		-- Format per entry: { Name, Followers }
		ReligionFollowers				= 0,
		SciencePerTurn					= 0,
		TradingPosts					= {},		-- Format per entry: { Player Number }
		TurnsUntilGrowth				= 0,
		TurnsUntilExpansion				= 0,
		UnitStats						= nil,
		--YieldFilters					= {},
	};

	-- extended yields
	for yield,yid in pairs(YieldTypes) do data.Yields[ yield ] = pCity:GetYield( yid ); end
	
	local pCityGrowth					:table = pCity:GetGrowth();
	local pCityCulture					:table = pCity:GetCulture();
	local cityGold						:table = pCity:GetGold();		
	local pBuildQueue					:table = pCity:GetBuildQueue();
	local currentProduction				:string = "LOC_HUD_CITY_PRODUCTION_NOTHING_PRODUCED";
	local currentProductionDescription	:string = "";
	local currentProductionStats		:string = "";
	local pct							:number = 0;
	local pctNextTurn					:number = 0;
	local prodTurnsLeft					:number = -1;
	local productionInfo				:table = nil; --GetCurrentProductionInfoOfCity( pCity, SIZE_PRODUCTION_ICON ); -- Infixo: NO PRODUCTION INFO YET

	-- extended yields
	data.Yields.HOUSING = pCityGrowth:GetHousing();
	data.Yields.AMENITY = pCityGrowth:GetAmenities();
	
	-- additional data
	data.IsGovernorEstablished, data.NumGovernorPromotions = GetGovernorData(pCity)
	data.ContinentType = Map.GetPlot( pCity:GetX(), pCity:GetY() ):GetContinentType()
	data.GreatWorks = GetGreatWorksForCity(pCity)
	
	-- If something is currently being produced, mark it in the queue.
	if productionInfo ~= nil then
		currentProduction				= productionInfo.Name;
		currentProductionDescription	= productionInfo.Description;
		if(productionInfo.StatString ~= nil) then
			currentProductionStats		= productionInfo.StatString;
		end
		pct								= productionInfo.PercentComplete;
		pctNextTurn						= productionInfo.PercentCompleteNextTurn;
		prodTurnsLeft					= productionInfo.Turns;
		productionInfo.Index			= 1;
		data.ProductionQueue[1]			= productionInfo;	--Place in front

		-- Some buildings will not have a description.
		if currentProductionDescription == nil then
			currentProductionDescription = "";
		end
	end

	-- current production type
	data.CurrentProductionType = "NONE";
	local iCurrentProductionHash:number = pCity:GetBuildQueue():GetCurrentProductionTypeHash();
	if iCurrentProductionHash ~= 0 then
		if     GameInfo.Buildings[iCurrentProductionHash] ~= nil then data.CurrentProductionType = "BUILDING";
		elseif GameInfo.Districts[iCurrentProductionHash] ~= nil then data.CurrentProductionType = "DISTRICT";
		elseif GameInfo.Units[iCurrentProductionHash]     ~= nil then data.CurrentProductionType = "UNIT";
		elseif GameInfo.Projects[iCurrentProductionHash]  ~= nil then data.CurrentProductionType = "PROJECT";
		end
	end

	local isGrowing	:boolean = pCityGrowth:GetTurnsUntilGrowth() ~= -1;
	local isStarving:boolean = pCityGrowth:GetTurnsUntilStarvation() ~= -1;

	local turnsUntilGrowth :number = 0;	-- It is possible for zero... no growth and no starving.
	if isGrowing then
		turnsUntilGrowth = pCityGrowth:GetTurnsUntilGrowth();
	elseif isStarving then
		turnsUntilGrowth = -pCityGrowth:GetTurnsUntilStarvation();	-- Make negative
	end	
		
	local food             :number = pCityGrowth:GetFood();
	local growthThreshold  :number = pCityGrowth:GetGrowthThreshold();
	local foodSurplus      :number = pCityGrowth:GetFoodSurplus();
	local foodpct          :number = math.max( math.min( food / growthThreshold, 1.0 ), 0.0);
	local foodpctNextTurn  :number = 0;
	if turnsUntilGrowth > 0 then
		local foodGainNextTurn = foodSurplus * pCityGrowth:GetOverallGrowthModifier();
		foodpctNextTurn = (food + foodGainNextTurn) / growthThreshold;
		foodpctNextTurn = math.max( math.min( foodpctNextTurn, 1.0), 0.0 );
	end

	-- Three religion objects to work with: overall game object, the player's religion, and this specific city's religious population
	local pGameReligion		:table = Game.GetReligion();
	local pPlayerReligion	:table = pPlayer:GetReligion();
	local pAllReligions		:table = pGameReligion:GetReligions();
	local pReligions		:table = pCity:GetReligion():GetReligionsInCity();	
	local eDominantReligion	:number = pCity:GetReligion():GetMajorityReligion();
	local followersAll		:number = 0;
	for _, religionData in pairs(pReligions) do				

		-- If the value for the religion type is less than 0, there is no religion (citizens working towards a Patheon).
		local religionType	:string = (religionData.Religion > 0) and GameInfo.Religions[religionData.Religion].ReligionType or "RELIGION_PANTHEON";
		local thisReligion	:table = { ID=religionData.Religion, ReligionType=religionType, Followers=religionData.Followers };
		table.insert( data.Religions, thisReligion );		

		if religionData.Religion == eDominantReligion and eDominantReligion > -1 then
			data.Religions[DATA_DOMINANT_RELIGION] = thisReligion;
			for _,kFoundReligion in ipairs(pAllReligions) do
				if kFoundReligion.Religion == eDominantReligion then
					for _,belief in pairs(kFoundReligion.Beliefs) do
						table.insert( data.BeliefsOfDominantReligion, belief );
					end
					break;
				end
			end
		end

		if religionType ~= "RELIGION_PANTHEON" then
			followersAll = followersAll + religionData.Followers;
		end
	end

	-- number of followers of the main religion (from ReportScreen.lua)
	data.MajorityReligionFollowers = 0;
	--local eDominantReligion:number = pCity:GetReligion():GetMajorityReligion();
	if eDominantReligion > 0 then -- WARNING! this rules out pantheons!
		for _, religionData in pairs(pCity:GetReligion():GetReligionsInCity()) do
			if religionData.Religion == eDominantReligion then data.MajorityReligionFollowers = religionData.Followers; end
		end
	end
	--print("Majority religion followers for", cityName, data.MajorityReligionFollowers);
	
	data.AmenitiesNetAmount				= pCityGrowth:GetAmenities() - pCityGrowth:GetAmenitiesNeeded();
	data.AmenitiesNum					= pCityGrowth:GetAmenities();
	data.AmenitiesFromLuxuries			= pCityGrowth:GetAmenitiesFromLuxuries();
	data.AmenitiesFromEntertainment		= pCityGrowth:GetAmenitiesFromEntertainment();
	data.AmenitiesFromCivics			= pCityGrowth:GetAmenitiesFromCivics();
	data.AmenitiesFromGreatPeople		= pCityGrowth:GetAmenitiesFromGreatPeople();
	data.AmenitiesFromCityStates		= pCityGrowth:GetAmenitiesFromCityStates();
	data.AmenitiesFromReligion			= pCityGrowth:GetAmenitiesFromReligion();
	data.AmenitiesFromNationalParks		= pCityGrowth:GetAmenitiesFromNationalParks();
	data.AmenitiesFromStartingEra		= pCityGrowth:GetAmenitiesFromStartingEra();
	data.AmenitiesFromImprovements		= pCityGrowth:GetAmenitiesFromImprovements();
	data.AmenitiesLostFromWarWeariness	= pCityGrowth:GetAmenitiesLostFromWarWeariness();
	data.AmenitiesLostFromBankruptcy	= pCityGrowth:GetAmenitiesLostFromBankruptcy();
	data.AmenitiesRequiredNum			= pCityGrowth:GetAmenitiesNeeded();
	--data.AmenitiesFromGovernors			= pCityGrowth:GetAmenitiesFromGovernors();
	data.AmenityAdvice					= pCity:GetAmenityAdvice();
	data.CityWallHPPercent				= (wallHitpoints-currentWallDamage) / wallHitpoints;
	data.CityWallCurrentHP				= wallHitpoints-currentWallDamage;
	data.CityWallTotalHP				= wallHitpoints;
	data.CurrentFoodPercent				= foodpct;
	data.CurrentProductionName			= Locale.Lookup( currentProduction );
	data.CurrentProdPercent				= pct;
	data.CurrentProductionDescription	= Locale.Lookup( currentProductionDescription );
	data.CurrentProductionIcon			= productionInfo and productionInfo.Icon;
	data.CurrentProductionStats			= productionInfo and productionInfo.StatString;
	data.CurrentTurnsLeft				= prodTurnsLeft;		
	data.FoodPercentNextTurn			= foodpctNextTurn;
	data.FoodSurplus					= foodSurplus; --Round( foodSurplus, 1); -- this is rounded to integer actually already
	data.Happiness						= pCityGrowth:GetHappiness();
	data.HappinessGrowthModifier		= pCityGrowth:GetHappinessGrowthModifier();
	data.HappinessNonFoodYieldModifier	= pCityGrowth:GetHappinessNonFoodYieldModifier();
	data.HitpointPercent				= ((districtHitpoints-currentDistrictDamage) / districtHitpoints);
	data.HitpointsCurrent				= districtHitpoints-currentDistrictDamage;
	data.HitpointsTotal					= districtHitpoints;
	data.Housing						= pCityGrowth:GetHousing(); -- incorrect, but not used by RMA
	data.HousingFromWater				= pCityGrowth:GetHousingFromWater();
	data.HousingFromBuildings			= pCityGrowth:GetHousingFromBuildings();
	data.HousingFromImprovements		= pCityGrowth:GetHousingFromImprovements(); -- incorrect, but bnot used by RMA
	data.HousingFromDistricts			= pCityGrowth:GetHousingFromDistricts();
	data.HousingFromCivics				= pCityGrowth:GetHousingFromCivics();
	data.HousingFromGreatPeople			= pCityGrowth:GetHousingFromGreatPeople();
	data.HousingFromStartingEra			= pCityGrowth:GetHousingFromStartingEra();
	data.HousingMultiplier				= pCityGrowth:GetHousingGrowthModifier();
	data.HousingAdvice					= pCity:GetHousingAdvice();
	data.OccupationMultiplier			= pCityGrowth:GetOccupationGrowthModifier();
	data.Occupied                       = pCity:IsOccupied();
	data.OtherGrowthModifiers			= pCityGrowth:GetOtherGrowthModifier();	-- Growth modifiers from Religion & Wonders
	data.PantheonBelief					= pPlayerReligion:GetPantheon();	
	data.ProdPercentNextTurn			= pctNextTurn;
	data.ReligionFollowers				= followersAll;
	data.TurnsUntilExpansion			= pCityCulture:GetTurnsUntilExpansion();
	data.TurnsUntilGrowth				= turnsUntilGrowth;
	data.UnitStats						= nil; --GetUnitStats( pBuildQueue:GetCurrentProductionTypeHash() );	--NIL if not a unit -- Infixo: NO UNIT STATS
	
	-- Helper to get an internally used enum based on the state of a certain yield.
	--[[
	local pCitizens :table = pCity:GetCitizens();
	function GetYieldState( yieldEnum:number )
		if pCitizens:IsFavoredYield(yieldEnum) then			return YIELD_STATE.FAVORED;
		elseif pCitizens:IsDisfavoredYield(yieldEnum) then	return YIELD_STATE.IGNORED;
		else												return YIELD_STATE.NORMAL;
		end
	end	 		
	data.YieldFilters[YieldTypes.CULTURE]	= GetYieldState(YieldTypes.CULTURE);
	data.YieldFilters[YieldTypes.FAITH]		= GetYieldState(YieldTypes.FAITH);
	data.YieldFilters[YieldTypes.FOOD]		= GetYieldState(YieldTypes.FOOD);
	data.YieldFilters[YieldTypes.GOLD]		= GetYieldState(YieldTypes.GOLD);
	data.YieldFilters[YieldTypes.PRODUCTION]= GetYieldState(YieldTypes.PRODUCTION);
	data.YieldFilters[YieldTypes.SCIENCE]	= GetYieldState(YieldTypes.SCIENCE);
	--]]
	--data = UpdateYieldData( pCity, data );

	-- Determine builds, districts, and wonders
	local pCityBuildings	:table = pCity:GetBuildings();
	local kCityPlots		:table = Map.GetCityPlots():GetPurchasedPlots( pCity );
	if (kCityPlots ~= nil) then
		for _,plotID in pairs(kCityPlots) do
			local kPlot:table =  Map.GetPlotByIndex(plotID);
			local kBuildingTypes:table = pCityBuildings:GetBuildingsAtLocation(plotID);
			for _, type in ipairs(kBuildingTypes) do
				local building	= GameInfo.Buildings[type];
				table.insert( data.Buildings, { 
					Name		= GameInfo.Buildings[building.BuildingType].Name, 
					Citizens	= kPlot:GetWorkerCount(),
					isPillaged	= pCityBuildings:IsPillaged(type),
					Maintenance	= GameInfo.Buildings[building.BuildingType].Maintenance			--Expense in gold
				});
			end
		end
	end	

	local pDistrict : table = pPlayer:GetDistricts():FindID( pCity:GetDistrictID() );
	if pDistrict ~= nil then
		data.IsUnderSiege = pDistrict:IsUnderSiege();
	else
		UI.DataError("Some data will be missing as unable to obtain the corresponding district for city: "..pCity:GetName());
	end
	
	-------------------------------------
	-- 230522 CITY PLOTS
	-- Loop through all the plots of the city, based on GetCityResourceData())
	
	local kResources: table = {};
	local cityPlots : table = Map.GetCityPlots():GetPurchasedPlots(pCity)
	for _, plotID in ipairs(cityPlots) do
		local plot: table = Map.GetPlotByIndex(plotID);
		local eResourceType: number = plot:GetResourceType();
		local eImprovementType: number = plot:GetImprovementType();

	    -- 230522 #10 Johannesburg Count improved different resource types
		-- Note: It must be an actual improvement. Strategics under districts do not trigger Johannesburg effect!
		if eResourceType ~= -1 and eImprovementType ~= -1 and not plot:IsImprovementPillaged() then
			-- must also check if this a valid improvement
			local tResults: table =
				DB.Query("SELECT * FROM Improvement_ValidResources WHERE ImprovementType = ? AND ResourceType = ?",
					GameInfo.Improvements[eImprovementType].ImprovementType,
					GameInfo.Resources[eResourceType].ResourceType);
			if tResults and #tResults > 0 then -- found a valid improved resource
				kResources[eResourceType] = true;
			end
		end
	end
	data.NumResources = table.count(kResources);	
	
	-------------------------------------
	-- DISTRICTS
	for i, district in pCityDistricts:Members() do

		-- Helper to obtain yields for a district: build a lookup table and then match type.
		local kTempDistrictYields :table = {};
		for yield in GameInfo.Yields() do
			kTempDistrictYields[yield.Index] = yield;
		end
		-- ==========
		function GetDistrictYield( district:table, yieldType:string )
			for i,yield in ipairs( kTempDistrictYields ) do
				if yield.YieldType == yieldType then
					return district:GetYield(i);
				end
			end
			return 0;
		end

		--I do not know why we make local functions, but I am keeping standard
		function GetDistrictBonus( district:table, yieldType:string )
			for i,yield in ipairs( kTempDistrictYields ) do
				if yield.YieldType == yieldType then
					return district:GetAdjacencyYield(i);
				end
			end
			return 0;
		end


		local districtInfo	:table	= GameInfo.Districts[district:GetType()];
		local districtType	:string = districtInfo.DistrictType;	
		local locX			:number = district:GetX();
		local locY			:number = district:GetY();
		local kPlot			:table  = Map.GetPlot(locX,locY);
		local plotID		:number = kPlot:GetIndex();	
		local districtTable :table	= { 
			SubjectType		= SubjectTypes.District,
			Name			= data.Name..": "..Locale.Lookup(districtInfo.Name),
			Plot 			= kPlot,
			Yields   		= YieldTableNew(), -- district yields (from adjacency)
			--AdjYields   = YieldTableNew(), -- adjacency bonus yields -- Infixo: ADJACENCY = STANDARD YIELD
			DistrictType 	= districtType,
			CityCenter		= districtInfo.CityCenter,
			OnePerCity		= districtInfo.OnePerCity,
			-- not used yet
			YieldBonus	= GetDistrictYieldText( district ),
			isPillaged  = pCityDistricts:IsPillaged(district:GetType()),
			isBuilt		= district:IsComplete(),--pCityDistricts:HasDistrict(districtInfo.Index, true);
			Icon		= "ICON_"..districtType,
			Buildings	= {},
			--Culture		= GetDistrictYield(district, "YIELD_CULTURE" ),			
			--Faith		= GetDistrictYield(district, "YIELD_FAITH" ),
			--Food		= GetDistrictYield(district, "YIELD_FOOD" ),
			--Gold		= GetDistrictYield(district, "YIELD_GOLD" ),
			--Production	= GetDistrictYield(district, "YIELD_PRODUCTION" ),
			--Science		= GetDistrictYield(district, "YIELD_SCIENCE" ),
			Tourism		= 0,
			Maintenance = districtInfo.Maintenance,
			--[[
			AdjacencyBonus = {
				Culture		= GetDistrictBonus(district, "YIELD_CULTURE"),
				Faith		= GetDistrictBonus(district, "YIELD_FAITH"),
				Food		= GetDistrictBonus(district, "YIELD_FOOD"),
				Gold		= GetDistrictBonus(district, "YIELD_GOLD"),
				Production	= GetDistrictBonus(district, "YIELD_PRODUCTION"),
				Science		= GetDistrictBonus(district, "YIELD_SCIENCE"),
			},
			--]]
		};
		-- count all districts and specialty ones
		if district:IsComplete() and not districtInfo.CityCenter and                             districtType ~= "DISTRICT_WONDER" then
			data.NumDistricts = data.NumDistricts + 1;
		end
		if district:IsComplete() and not districtInfo.CityCenter and districtInfo.OnePerCity and districtType ~= "DISTRICT_WONDER" then
			data.NumSpecialtyDistricts = data.NumSpecialtyDistricts + 1;
		end
		
		-- extended yields -- Infixo: CHECK seems that Districts don't produce yields by themselves, only adjacency yields
		-- there is no table for that, also both functions produce the same results
		-- BUT! There is ADJUST_DISTRICT_YIELD_CHANGE, used by MODIFIER_PLAYER_DISTRICTS_ADJUST_YIELD_CHANGE and MODIFIER_PLAYER_DISTRICT_ADJUST_YIELD_CHANGE and ADJUST_DISTRICT_EXTRA_REGIONAL_YIELD for MODIFIER_PLAYER_DISTRICT_ADJUST_EXTRA_REGIONAL_YIELD
		-- the first is used by Minors to adjust yields (e.g. MINOR_CIV_SCIENTIFIC_YIELD_FOR_CAMPUS, attached when Medium influence), the other two are not used
		-- the third ise used by GREATPERSON_EXTRA_REGIONAL_BUILDING_PRODUCTION
		-- OK, Minors are giving yields to Buildings now, not Districts, different modifiers are used
		-- Another problem is that calling it with 6 gives negative big integers, unknown (bug?)
		--for yield,yid in pairs(YieldTypes) do districtTable.Yields[ yield ] = district:GetYield( yid ); end
		--for yield,yid in pairs(YieldTypes) do districtTable.Yields[ yield ] = district:GetAdjacencyYield( yid ); end -- Infixo: ADJACENCY = STANDARD YIELD
		--districtTable.Yields.TOURISM = 0; -- tourism is produced in another way, GetYield() produces stupid numbers here
		-- SECOND APPROACH
		-- GetYield and GetAdjacencyYield give yields AFTER applying modifiers
		-- We can get raw, unmodified yields from Plot:GetAdjacencyYield, however this requires a bit more complex call
		-- kPlot holds the plot, district:GetType(), also produces 0 for index=6, so it's ok
		for yield,yid in pairs(YieldTypes) do
			districtTable.Yields[ yield ] = kPlot:GetAdjacencyYield(ownerID, pCity:GetID(), district:GetType(), yid)
		end
		
		-- 230522 #17 Garrison unit can be also in an Encampment, so we will handle all possible districts in one go
		if not data.IsGarrisonUnit and tGarrisonDistricts[districtInfo.DistrictType] then -- don't iterate if we already found a garrison
			for _,unit in ipairs(Units.GetUnitsInPlot(plotID)) do
				if unit:GetCombat() > 0 then data.IsGarrisonUnit = true; break; end
			end
		end

		---------------------------------------------------------------------
		-- BUILDINGS
		local buildingTypes = pCityBuildings:GetBuildingsAtLocation(plotID);
		for _, buildingType in ipairs(buildingTypes) do -- buildingType is an Index here
			local building		:table = GameInfo.Buildings[buildingType];
			local sBuildingType:string = building.BuildingType;
			--local kYields		:table = {}; -- not used

			-- Obtain yield info for buildings.
			--[[ Infixo noy used
			for yieldRow in GameInfo.Yields() do
				local yieldChange = pCity:GetBuildingYield(buildingType, yieldRow.YieldType);
				if yieldChange ~= 0 then
					table.insert( kYields, {
						YieldType	= yieldRow.YieldType,
						YieldChange	= yieldChange
					});
				end
			end
			--]]
			-- Helper: to extract a particular yield type
			--[[ Infixo not used
			function YieldFind( kYields:table, yieldType:string )
				for _,yield in ipairs(kYields) do
					if yield.YieldType == yieldType then
						return yield.YieldChange;
					end
				end
				return 0;	-- none found
			end
			--]]
			-- Duplicate of data but common yields in an easy to parse format.
			--local culture	:number = YieldFind( kYields, "YIELD_CULTURE" );
			--local faith		:number = YieldFind( kYields, "YIELD_FAITH" );
			--local food		:number = YieldFind( kYields, "YIELD_FOOD" );
			--local gold		:number = YieldFind( kYields, "YIELD_GOLD" );
			--local production:number = YieldFind( kYields, "YIELD_PRODUCTION" );
			--local science	:number = YieldFind( kYields, "YIELD_SCIENCE" );
			-- extended yields
			local extyields :table = YieldTableNew();
			-- fix for certain policies based on building yields
			-- pCity:GetBuildingYield does NOT return a base yield, only processed one, so if the policy is selected, then it calculates the effect twice
			-- use the base data from DB
			function GetBuildingBaseYield(sBuildingType:string, sYieldType:string)
				--print("GetBuildingBaseYield", sBuildingType, sYieldType);
				for row in GameInfo.Building_YieldChanges() do
					if row.BuildingType == sBuildingType and row.YieldType == sYieldType then return row.YieldChange; end
				end
				return 0;
			end
			--for yield,yid in pairs(YieldTypes) do extyields[ yield ] = pCity:GetBuildingYield(buildingType, yid); end
			for yield,_ in pairs(YieldTypes) do extyields[ yield ] = GetBuildingBaseYield(sBuildingType, "YIELD_"..yield); end
			-- extyields.TOURISM = 0; -- tourism is produced in another way, GetBuildingYield() produces stupid numbers here ??? I don't know, the bug is for districts for sure
			
			if building.IsWonder then
				table.insert( data.Wonders, {
					SubjectType			= SubjectTypes.Building,
					Name				= Locale.Lookup(building.Name), 
					Yields				= extyields,
					BuildingType		= sBuildingType,
					-- not used yet
					--Yields				= kYields,
					Icon				= "ICON_"..sBuildingType,
					--Citizens
					isPillaged			= pCityBuildings:IsPillaged(building.BuildingType),
					isBuilt				= pCityBuildings:HasBuilding(building.Index),
					--CulturePerTurn		= culture,	
					--FaithPerTurn		= faith,		
					--FoodPerTurn			= food,		
					--GoldPerTurn			= gold,		
					--ProductionPerTurn	= production,
					--SciencePerTurn		= science,
				});
			else
				data.BuildingsNum = data.BuildingsNum + 1;
				table.insert( districtTable.Buildings, { 
					SubjectType			= SubjectTypes.Building,
					Name				= Locale.Lookup(building.Name),
					Yields				= extyields,
					BuildingType		= sBuildingType,
					-- not used yet
					--Yields				= kYields,
					Icon				= "ICON_"..sBuildingType,
					Citizens			= kPlot:GetWorkerCount(),
					isPillaged			= pCityBuildings:IsPillaged(buildingType);
					isBuilt				= pCityBuildings:HasBuilding(building.Index);
					--CulturePerTurn		= culture,	
					--FaithPerTurn		= faith,		
					--FoodPerTurn			= food,		
					--GoldPerTurn			= gold,		
					--ProductionPerTurn	= production,
					--SciencePerTurn		= science,
				});
			end

		end

		-- Add district unless it's the special wonder district; toss that one.
		if districtType ~= "DISTRICT_WONDER" then
			table.insert( data.Districts, districtTable );
		end
	end

	---------------------------------------------------------------
	-- TRADING POSTS
	local pTrade:table = pCity:GetTrade();
	for iPlayer:number = 0, MapConfiguration.GetMaxMajorPlayers()-1,1 do
		if (pTrade:HasActiveTradingPost(iPlayer)) then
			table.insert( data.TradingPosts, iPlayer );
		end
	end

	---------------------------------------------------------------
	-- TRADE ROUTES
	local pPlayerDiplomaticAI:table = pPlayer:GetDiplomaticAI()
	data.OutgoingRoutes = {}
	data.NumRoutesDomestic = 0
	data.NumRoutesInternational = 0
	for _,route in ipairs(pTrade:GetOutgoingRoutes()) do
		local routeData:table = {
			SubjectType = SubjectTypes.TradeRoute,
			Name        = "", -- later
			IsDomestic  = (route.OriginCityPlayer == route.DestinationCityPlayer), -- boolean
			Yields      = YieldTableNew(), -- later
			NumImprovedResourcesAtDestination = 0, -- later
			IsDestinationPlayerAlly = false, -- later
			IsDestinationSuzerained = false, -- 230521 #1 Wisselbanken
			NumSpecialtyDistricts = 0, -- later
		}
		-- copy yields
		for _,yield in ipairs(route.OriginYields) do
			YieldTableSetYield(routeData.Yields, GameInfo.Yields[yield.YieldIndex].YieldType, yield.Amount)
		end
	
		-- counters
		if routeData.IsDomestic then data.NumRoutesDomestic      = data.NumRoutesDomestic + 1
		else                         data.NumRoutesInternational = data.NumRoutesInternational + 1 end

		-- Find destination city
		local pDestPlayer:table = Players[ route.DestinationCityPlayer ] -- can be used to find out diplo details
		local pDestCity:table = pDestPlayer:GetCities():FindID(route.DestinationCityID)
		routeData.Name = data.Name.." - "..Locale.Lookup(pDestCity:GetName())

		-- market economy: number of resources improved at destination (lux, strat)
		local tResources:table = GetCityResourceData(pDestCity) -- Firaxis function
		local function CountImprovedResources(sResourceClassToCount:string)
			local iNum:number = 0
			for eResourceType,amount in pairs(tResources) do
				if GameInfo.Resources[eResourceType].ResourceClassType == sResourceClassToCount then iNum = iNum + amount end
			end
			return iNum
		end
		routeData.NumImprovedResourcesStrategic = CountImprovedResources("RESOURCECLASS_STRATEGIC")
		routeData.NumImprovedResourcesLuxury    = CountImprovedResources("RESOURCECLASS_LUXURY")
		routeData.NumImprovedResourcesBonus     = CountImprovedResources("RESOURCECLASS_BONUS")
		-- 230521 #1 If destination an is Ally (diplo)
		routeData.IsDestinationPlayerAlly = ( pPlayerDiplomaticAI:GetDiplomaticStateIndex(route.DestinationCityPlayer) == GameInfo.DiplomaticStates.DIPLO_STATE_ALLIED.Index );
		
		-- 230521 #1 If destination is a CityState and we are its suzerain
		if pDestPlayer:IsMinor() then
			routeData.IsDestinationSuzerained = ( pDestPlayer:GetInfluence():GetSuzerain() == route.OriginCityPlayer );
		end
		
		-- GreatPerson number of specialty districts at destination
		for _,district in pDestCity:GetDistricts():Members() do
			local districtInfo:table = GameInfo.Districts[ district:GetType() ];
			if district:IsComplete() and not districtInfo.CityCenter and districtInfo.OnePerCity and districtInfo.DistrictType ~= "DISTRICT_WONDER" then
				routeData.NumSpecialtyDistricts = routeData.NumSpecialtyDistricts + 1;
			end
		end
		
		table.insert(data.OutgoingRoutes, routeData)
	end
	data.NumRoutes = table.count(data.OutgoingRoutes)
	
	-- incoming routes are a bit easier, only yields are needed as for now
	data.IncomingRoutes = {}
	for _,route in ipairs(pTrade:GetIncomingRoutes()) do
		local routeData:table = {
			SubjectType = SubjectTypes.TradeRoute,
			Name        = "", -- later
			IsDomestic  = (route.OriginCityPlayer == route.DestinationCityPlayer), -- boolean
			Yields      = YieldTableNew(), -- later
			IsOriginPlayerAlly = false, -- 230521 #1 Wisselbanken
			IsOriginSuzerained = false, -- 230521 #1 Wisselbanken
		}
		-- copy yields
		for _,yield in ipairs(route.DestinationYields) do
			YieldTableSetYield(routeData.Yields, GameInfo.Yields[yield.YieldIndex].YieldType, yield.Amount)
		end

		-- Find origin city
		local pOriginPlayer:table = Players[ route.OriginCityPlayer ]
		local pOriginCity:table = pOriginPlayer:GetCities():FindID(route.OriginCityID)
		routeData.Name = Locale.Lookup(pOriginCity:GetName()).." - "..data.Name -- opposite to outgoing
		
		-- 230521 #1 If origin is an Ally (diplo)
		routeData.IsOriginPlayerAlly = ( pOriginPlayer:GetDiplomaticAI():GetDiplomaticStateIndex(route.DestinationCityPlayer) == GameInfo.DiplomaticStates.DIPLO_STATE_ALLIED.Index );

		-- 230521 #1 If origin is a CityState and we are its suzerain
		if pOriginPlayer:IsMinor() then
			routeData.IsOriginSuzerained = ( pOriginPlayer:GetInfluence():GetSuzerain() == route.DestinationCityPlayer );
		end

		table.insert(data.IncomingRoutes, routeData)
	end
	
	-- done!
	return data
end


-- ===========================================================================
-- Obtain unit maintenance
-- This function will use GameInfo for vanilla game and UnitManager for Rise&Fall
function GetUnitMaintenance(pUnit:table)
	local iUnitMaintenance:number = GameInfo.Units[ pUnit:GetUnitType() ].Maintenance;
	local unitMilitaryFormation = pUnit:GetMilitaryFormation();
	if unitMilitaryFormation == MilitaryFormationTypes.CORPS_FORMATION then return math.ceil(iUnitMaintenance * 1.5); end -- it is 150% rounded UP
	if unitMilitaryFormation == MilitaryFormationTypes.ARMY_FORMATION  then return iUnitMaintenance * 2; end -- it is 200%
	                                                                        return iUnitMaintenance;
end

-- ===========================================================================
-- Diplomatic data (city states and allies)
-- Trade routes (?)
-- Units (?)
function GetPlayerData(ePlayerID:number)
	local pPlayer:table = Players[ Game.GetLocalPlayer() ]
	if ePlayerID then pPlayer = Players[ ePlayerID ] end
	if not pPlayer then return end -- error
	
	tPlayer 			= {} -- clear old data
	tPlayer.Player 		= pPlayer
	tPlayer.SubjectType = SubjectTypes.Player
	tPlayer.Name 		= Locale.Lookup(PlayerConfigurations[pPlayer:GetID()]:GetCivilizationShortDescription())
	tPlayer.Cities		= tCities
	
	-- YIELDS
	tPlayer.Yields = YieldTableNew()
	tPlayer.Yields.GOLD    = pPlayer:GetTreasury():GetGoldYield();
	tPlayer.Yields.SCIENCE = pPlayer:GetTechs():GetScienceYield();
	tPlayer.Yields.CULTURE = pPlayer:GetCulture():GetCultureYield();
	tPlayer.Yields.FAITH   = pPlayer:GetReligion():GetFaithYield();
	tPlayer.Yields.TOURISM = pPlayer:GetStats():GetTourism();
	local iTotFood:number, iTotProd:number, iTotAmenity:number, iTotHousing:number = 0, 0, 0, 0
	for _,city in pPlayer:GetCities():Members() do
		iTotFood    = iTotFood    + city:GetGrowth():GetFoodSurplus()
		iTotAmenity = iTotAmenity + city:GetGrowth():GetAmenities()
		iTotHousing = iTotHousing + city:GetGrowth():GetHousing()
		iTotProd    = iTotProd    + city:GetBuildQueue():GetProductionYield()
	end
	tPlayer.Yields.FOOD = iTotFood
	tPlayer.Yields.PRODUCTION = iTotProd
	tPlayer.Yields.AMENITY = iTotAmenity
	tPlayer.Yields.HOUSING = iTotHousing

	-- TRADE ROUTES
	tPlayer.NumRoutes = 0
	tPlayer.NumRoutesDomestic = 0
	tPlayer.NumRoutesInternational = 0
	for cityname,city in pairs(tCities) do
		tPlayer.NumRoutes = tPlayer.NumRoutes + city.NumRoutes
		tPlayer.NumRoutesDomestic = tPlayer.NumRoutesDomestic + city.NumRoutesDomestic
		tPlayer.NumRoutesInternational = tPlayer.NumRoutesInternational + city.NumRoutesInternational
	end

	-- UNITS
	tPlayer.Units = {}
	for _,unit in pPlayer:GetUnits():Members() do
		local pUnitInfo:table = GameInfo.Units[ unit:GetUnitType() ]
		
		-- get localized unit name with appropriate suffix
		local unitName:string = Locale.Lookup(pUnitInfo.Name);
		local unitMilitaryFormation:number = unit:GetMilitaryFormation()
		if (unitMilitaryFormation == MilitaryFormationTypes.CORPS_FORMATION) then
			unitName = unitName.." [ICON_Corps]"
		elseif (unitMilitaryFormation == MilitaryFormationTypes.ARMY_FORMATION) then
			unitName = unitName.." [ICON_Army]"
		else
			--BRS Civilian units can be NO_FORMATION (-1) or STANDARD (0)
			unitMilitaryFormation = MilitaryFormationTypes.STANDARD_FORMATION; -- 0
		end
		local unitData:table = {
			SubjectType = SubjectTypes.Unit,
			Name = unitName,
			MilitaryFormation = unitMilitaryFormation,
			Maintenance = GetUnitMaintenance(unit),
			IsCivilian = (pUnitInfo.FormationClass == "FORMATION_CLASS_CIVILIAN"),
		}
		table.insert(tPlayer.Units, unitData)
	end

	-- WMDs
	tPlayer.WMDs = {
		Num = 0,
		Maintenance = 0,
	}
	for row in GameInfo.WMDs() do
		local iNum:number = pPlayer:GetWMDs():GetWeaponCount(row.Index)
		tPlayer.WMDs.Num = tPlayer.WMDs.Num + iNum
		tPlayer.WMDs.Maintenance = tPlayer.WMDs.Maintenance + iNum * row.Maintenance
	end
	
	-- CITY-STATES
	tPlayer.NumSuzerainCityStates = 0;
	tPlayer.NumInfluenceTokensGiven = 0;
	for _,minor in ipairs(PlayerManager.GetAliveMinors()) do
		-- we need to check for City State actually, because Free Cities are considered Minors as well
		if minor:IsMinor() then 
			if minor:GetInfluence():GetSuzerain() == pPlayer:GetID() then tPlayer.NumSuzerainCityStates = tPlayer.NumSuzerainCityStates + 1; end
			tPlayer.NumInfluenceTokensGiven = tPlayer.NumInfluenceTokensGiven + minor:GetInfluence():GetTokensReceived(pPlayer:GetID());
		end
	end

end


-- ===========================================================================
-- PLOT YIELDS

function GetPlotsData(ePlayerID:number)
	local pPlayer:table = Players[ Game.GetLocalPlayer() ];
	if ePlayerID then pPlayer = Players[ ePlayerID ]; end
	if not pPlayer then return; end -- error
	
	tPlots = {}; -- clear old data
	for _,city in pPlayer:GetCities():Members() do
		for _,plotIndex in ipairs(Map.GetCityPlots():GetPurchasedPlots(city)) do
			local pPlot:table = Map.GetPlotByIndex(plotIndex);
			if pPlot then
				local plotData:table = {
					SubjectType = SubjectTypes.Plot,
					Name = tostring(pPlot:GetX())..":"..tostring(pPlot:GetY()),
					Plot = pPlot,
				};
				table.insert(tPlots, plotData);
			end
		end
	end

end

-- ===========================================================================
-- MODIFIERS' STATIC DATA
-- ===========================================================================
-- 0. Start with ModifierId
-- 1. Retrieve all relevant data into a table that will store them for future use
--   1a. Retrieve data from Modifiers: ModifierType, 3x bools, OwnerReqSetId, SubjectReqSetId
--   1b. ModifierType is the key, retrieve data from DynamicModifiers: CollectionType, EffectType
--   1c. Retrieve data from ModifierArguments: table of key=Name, value=Value
--         ignore Extra (usually -1) and SecondExtra for now
--         Type could be 'ScaleByGameSpeed' - probably for value only; start with Standard Speed, add scaling later
-- 2. display raw data
-- 3. Analyze CollectionType
-- 4. Analyze EffectType
-- ===========================================================================

local tModifiers: table = {}; -- main table to store all modifiers; will be populated online, also acting as cache
-- Modifier
--   .ModifierId
--   .ModifierType
--   .RunOnce / .NewOnly / .Permanent
--   .OwnerReqSetId / .SubjectReqSetId
--   .OwnerReqSet / .SubjectReqSet
--   .CollectionType
--   .EffectType
--   .Arguments - table of {Name=Value}

local tReqs: table = {}; -- main table to store all requirements; will be populated online, also acting as cache
-- Req
--   .ReqId
--   .Arguments
--   more fields here

local tReqSets: table = {}; -- main table to store all requirement sets; will be populated online, also acting as cache
-- ReqSet
--   .ReqSetId
--   .TestAll / .TestAny
--   .Reqs - table of {Req}


function FetchAndCacheDataReq(sReqId:string)
	--dprint("FUNCAL FetchAndCacheDataReq(req)", sReqId);
	-- check if we already have it
	local tReq:table = tReqs[ sReqId ];
	if tReq then return tReq; end
	-- Requirements
	local req: table = GameInfo.Requirements[sReqId]; -- 230513 #2 This is a PK!
	-- Check if exists
	if not req then print("ERROR: FetchAndCacheDataReq unknown requirement", sReqId); return nil; end
	-- initialize an empty req
	tReq = {};
	tReq.ReqId         = sReqId;
	tReq.ReqType       = req.RequirementType;
	tReq.Inverse       = req.Inverse; -- boolean
	tReq.Persistent    = req.Persistent; -- boolean, only 1% are true - TODO: WHAT DOES IT DO?
	tReq.ProgressWeight= req.ProgressWeight; -- integer, 1% is 0, the rest is 1
	tReq.Triggered     = req.Triggered; -- boolean, only 2% are true
	-- .Likeliness, .Impact -- always 0
	-- .Reverse -- always false
	-- RequirementArguments - this one must be searched entirely
	tReq.Arguments = {};
	local tResults: table = DB.Query("SELECT * FROM RequirementArguments WHERE RequirementId = ?", sReqId);
	if tResults and #tResults > 0 then
		for _,arg in ipairs(tResults) do
			tReq.Arguments[ arg.Name ] = arg.Value;
		end
	end
	-- done!
	tReqs[ sReqId ] = tReq;
	return tReq;
end

local INDENT2 = "   ";

function DecodeReq(tOut:table, sReqId:string)
	--dprint("FUNCAL DecodeReq(req)",sReqId);
	local tReq:table = FetchAndCacheDataReq(sReqId);
	if not tReq then return "ERROR: "..sReqId.." not defined!"; end
	table.insert(tOut, INDENT2..sReqId);
	table.insert(tOut, INDENT2.."Type: "..string.sub(tReq.ReqType, 13)); -- 230513 #2 hide REQUIREMENT_
	for name,value in pairs(tReq.Arguments) do table.insert(tOut, INDENT2..name.." = "..value); end
	if tReq.Inverse then table.insert(tOut, INDENT2.."Inverse"); end
	if tReq.Persistent then table.insert(tOut, INDENT2.."Persistent"); end
	if tReq.Triggered then table.insert(tOut, INDENT2.."Triggered"); end
	if tReq.ProgressWeight ~= 1 then table.insert(tOut, INDENT2.."ProgressWeight = "..tReq.ProgressWeight); end -- 230513 #2 3 cases where 0
end


function FetchAndCacheDataReqSet(sReqSetId:string)
	--dprint("FUNCAL FetchAndCacheDataReqSet(req)", sReqSetId);
	-- check if we already have it
	local tReqSet:table = tReqSets[ sReqSetId ];
	if tReqSet then return tReqSet; end
	-- RequirementSets
	local req: table = GameInfo.RequirementSets[sReqSetId]; -- #230513 this is a PK!
	if not req then print("ERROR: FetchAndCacheDataReqSet unknown req set", sReqSetId); return nil; end
	tReqSet = {};
	tReqSet.ReqSetId = sReqSetId;
	tReqSet.TestAll = ( req.RequirementSetType == "REQUIREMENTSET_TEST_ALL" );-- 90% are TEST_ALL
	tReqSet.TestAny = ( req.RequirementSetType == "REQUIREMENTSET_TEST_ANY" );
	tReqSet.Reqs = {};
	-- fill actual Requirements (from RequirementSetRequirements)
	-- filters in GameInfo don't work for modifiers, we need to use normal search
	local tResults: table = DB.Query("SELECT * FROM RequirementSetRequirements WHERE RequirementSetId = ?", sReqSetId);
	if tResults and #tResults > 0 then
		for _,req in ipairs(tResults) do
			table.insert(tReqSet.Reqs, FetchAndCacheDataReq(req.RequirementId));
		end
	end
	-- done!
	tReqSets[ sReqSetId ] = tReqSet;
	return tReqSet;
end

function DecodeReqSet(tOut:table, sReqSetId:string)
	--dprint("FUNCAL DecodeReqSet(req)",sReqSetId);
	local tReqSet:table = FetchAndCacheDataReqSet(sReqSetId);
	if not tReqSet then return "ERROR: "..sReqSetId.." not defined!"; end
	if tReqSet.TestAll then table.insert(tOut, "Test ALL of:"); end
	if tReqSet.TestAny then table.insert(tOut, "Test ANY of:"); end
	for _,req in ipairs(tReqSet.Reqs) do DecodeReq(tOut, req.ReqId); end
end


function FetchAndCacheData(sModifierId:string)
	--dprint("FUNCAL FetchAndCacheData(mod)", sModifierId);
	-- check if we already have it
	local tModifier:table = tModifiers[ sModifierId ];
	if tModifier then return tModifier; end
	-- filters in GameInfo don't work for modifiers, we need to use normal search
	tModifier = {};
	-- Modifiers
	local mod: table = GameInfo.Modifiers[sModifierId]; -- 230514 #2 This is a PK!
	-- check if it exists!
	if not mod then print("WARNING! FetchAndCacheData: No definition for Modifier", sModifierId); return nil; end
	tModifier.ModifierId   = sModifierId;
	tModifier.ModifierType = mod.ModifierType;
	tModifier.RunOnce      = mod.RunOnce; -- boolean
	tModifier.NewOnly      = mod.NewOnly; -- boolean
	tModifier.Permanent    = mod.Permanent; -- boolean
	tModifier.OwnerReqSetId = mod.OwnerRequirementSetId;
	tModifier.SubjectReqSetId = mod.SubjectRequirementSetId;
	
	-- DynamicModifiers
	local tResults: table = DB.Query("SELECT * FROM DynamicModifiers WHERE ModifierType = ?", tModifier.ModifierType);
	if tResults and tResults[1] then
		tModifier.CollectionType = tResults[1].CollectionType;
		tModifier.EffectType     = tResults[1].EffectType;
	end
	if tModifier.CollectionType == nil or tModifier.EffectType == nil then print("WARNING! FetchAndCacheData: No dynamic modifier definition for Modifier", sModifierId); return nil; end
	
	-- ModifierStrings - this one must be searched entirely
	tResults = DB.Query("SELECT * FROM ModifierStrings WHERE ModifierId = ?", sModifierId);
	if tResults then 
		-- There are 4 modifiers with 2 strings, but 99% of them has only 1
		if tResults[1] then
			local txt: string = Locale.Lookup(tResults[1].Text);
			if #txt == 0 then txt = tResults[1].Text; end
			tModifier.Text = tResults[1].Context..": "..txt;
		end
		if tResults[2] then
			local txt: string = Locale.Lookup(tResults[2].Text);
			if #txt == 0 then txt = tResults[2].Text; end
			tModifier.Text = tModifier.Text.."; "..tResults[2].Context..": "..txt;
		end
	end
	
	-- ModifierArguments - this one must be searched entirely
	tModifier.Arguments = {};
	tResults = DB.Query("SELECT * FROM ModifierArguments WHERE ModifierId = ?", sModifierId);
	if tResults and #tResults then 
		for _,arg in ipairs(tResults) do
			-- now we need to convert values into a proper type
			-- there are 216 names, so maybe we'll do it when actually trying to use it?
			--dprint("..found arg", arg.Name, arg.Value);
			tModifier.Arguments[ arg.Name ] = arg.Value;
			-- special handling for Type
			if arg.Type == "ScaleByGameSpeed" then
				-- add here: access game speed, multiply by it
				tModifier.ScaleByGameSpeed = true;
			end
		end -- for
	end -- if
	-- requirements
	if tModifier.OwnerReqSetId   then tModifier.OwnerReqSet   = FetchAndCacheDataReqSet(tModifier.OwnerReqSetId);   end
	if tModifier.SubjectReqSetId then tModifier.SubjectReqSet = FetchAndCacheDataReqSet(tModifier.SubjectReqSetId); end
	-- done!
	tModifiers[ sModifierId ] = tModifier;
	return tModifier; 
end

-- ===========================================================================
-- [MPT 条目21优化] 政策卡收益类型扩展（MPT 文本行通道）
-- 引擎原产量通道（tImpact→YieldTableGetInfo）只认 10 种产量 key，且政策卡实际使用的
-- 59 种 EffectType 未被 ApplyEffectAndCalculateImpact 处理（一律红字 Unknown）。
-- 本分区注册 MPT_LineHandlers（EffectType → 行格式化函数）：静态参数驱动的短文本行，
-- 由 CalculateModifierEffect（hook ①，收集进卡面串与 tooltip）与 DecodeModifier
-- （hook ②，命中则跳过原链避免误标 Unknown）两个 hook 消费。产量计算零改动（保真）。
-- 行结果按 ModifierId 缓存（MPT_LineCache）——参数静态不随局面变化，零陈旧风险；
-- 自定义措辞取自功能文本 SQL（ExtendedPolicyCards_*.sql，tag 前缀 LOC_MPT_EPC_），
-- 对象名/类别名/时代/资源/能力名走原版 LOC tag 自动本地化。
-- 差集与参数形态来源：Cache/DebugGameplay.sqlite 逐一枚举（90 种政策可达 EffectType
-- − 引擎已处理 31 种），图标经 Base/Assets/UI/Icons/Icons_*.xml 核实存在。
-- ===========================================================================
local MPT_LineHandlers:table = {};
local MPT_KnownEffects:table = {};	-- 已识别但不显示的类型（用户裁决，见下方静默注册区）：hook② 跳过原链避免红字 Unknown，不产生显示行
local MPT_ImpactHandlers:table = {};	-- [MPT 条目21用户裁决] 实际产量计算类（生产族）：返回 tImpact 走产量通道，DecodeModifier 自动跨城求和
local MPT_DynamicHandlers:table = {};	-- 动态计算类（数值随局势变化）：结果不进 MPT_LineCache 缓存
local MPT_LineCache:table = {};
local MPT_ExtractCache:table = {};	-- [ePlayerID] = { [ResourceType]=提取中地块数 }（IsResourceExtractableAt 引擎判定，含被区域/奇观覆盖）
local MPT_ModIndexCache:table = {};

-- 取 GameInfo 行的本地化名，缺失/无文本返回 nil
-- [MPT 条目21修复] tTable/row 不可写 :table 标注——GameInfo[sTable] 动态键访问返回 userdata，
-- 引擎对带标注赋值做运行时类型检查报 Type check failed（Lua.log 实证，同条目18 cfunction 同族）
local function MPT_GetGameInfoName(sTable:string, sType:string)
	if sType == nil then return nil; end
	local tTable = GameInfo[sTable];
	if tTable == nil then return nil; end
	local row = tTable[sType];
	if row == nil or row.Name == nil then return nil; end
	local s:string = Locale.Lookup(row.Name);
	if s == nil or #s == 0 or s == row.Name then return nil; end	-- 引擎同款判定：Lookup 未定义返回原 tag
	return s;
end

-- 带符号百分比（参数驱动，符号跟随 Amount；nil/非数字兜底 0）
local function MPT_Pct(iAmount:number)
	return Locale.ToNumber(iAmount or 0, "+#,###.#;-#,###.#").."%";
end

-- 带符号数值
local function MPT_Sign(iAmount:number)
	return Locale.ToNumber(iAmount or 0, "+#,###.#;-#,###.#");
end

-- 产量图标（复用引擎 GetYieldTextIcon，YIELD_ 前缀形参）
local function MPT_YieldIcon(sYieldType:string)
	return GetYieldTextIcon(sYieldType);
end

-- 短语本地化：命中返回文本，失败返回 nil（调用方自行决定兜底）
local function MPT_TryLocale(sTag:string)
	local s:string = Locale.Lookup(sTag);
	if s == nil or #s == 0 or s == sTag then return nil; end	-- 引擎同款判定：Lookup 未定义返回原 tag
	return s;
end

-- 短语本地化（功能文本 SQL 的无参 tag；失败显示原 tag 便于发现漏文本）
local function MPT_Phrase(sTag:string)
	return MPT_TryLocale(sTag) or sTag;
end

-- [MPT 条目21用户裁决] 玩家全图「提取中」资源地块计数（含被区域/奇观覆盖的地块——
-- IsResourceExtractableAt 为引擎提取判定，同 CitySupport GetCityResourceData 547 行用法）。
-- 结果按 ePlayerID 缓存，RefreshBaseData 时失效重建。
local function MPT_GetExtractionCount(ePlayerID:number, sResourceType:string)
	if ePlayerID == nil or sResourceType == nil then return 0; end
	local tCache:table = MPT_ExtractCache[ePlayerID];
	if tCache == nil then
		tCache = {};
		local pPlayer:table = Players[ePlayerID];
		local pResources = pPlayer and pPlayer:GetResources();
		if pResources ~= nil then
			for i:number = 0, Map.GetPlotCount() - 1 do
				local plot:table = Map.GetPlotByIndex(i);
				if plot ~= nil then
					local eResource:number = plot:GetResourceType();
					if eResource ~= -1 and plot:GetOwner() == ePlayerID and pResources:IsResourceExtractableAt(plot) then
						local resDef:table = GameInfo.Resources[eResource];
						if resDef ~= nil then
							tCache[resDef.ResourceType] = (tCache[resDef.ResourceType] or 0) + 1;
						end
					end
				end
			end
		end
		MPT_ExtractCache[ePlayerID] = tCache;
	end
	return tCache[sResourceType] or 0;
end

-- ----------------------------------------------------------------------------
-- [MPT 条目21用户裁决] 实际产量计算族（MPT_ImpactHandlers，走 tImpact 产量通道）：
-- 对象生产力加成按「城市当前生产对象匹配判定 → 城市生产力 × Amount%」逐城计算，
-- COLLECTION 城市集合时由 DecodeModifier 的 YieldTableAdd 自动跨城求和。
-- 当前生产对象经 pBuildQueue:GetCurrentProductionTypeHash() 后按 hash 反查四表
-- （GameInfo Buildings/Units/Districts/Projects 支持按 hash 索引，同 CitySupport 203-206 行）。
-- ----------------------------------------------------------------------------
local function MPT_GetCurrentProduction(pCity:table)
	local pBuildQueue:table = pCity:GetBuildQueue();
	if pBuildQueue == nil then return nil; end
	local hash:number = pBuildQueue:GetCurrentProductionTypeHash();
	if hash == nil or hash == 0 then return nil; end
	local buildingDef:table = GameInfo.Buildings[hash];
	if buildingDef ~= nil then return buildingDef, "BUILDING"; end
	local unitDef:table = GameInfo.Units[hash];
	if unitDef ~= nil then return unitDef, "UNIT"; end
	local districtDef:table = GameInfo.Districts[hash];
	if districtDef ~= nil then return districtDef, "DISTRICT"; end
	local projectDef:table = GameInfo.Projects[hash];
	if projectDef ~= nil then return projectDef, "PROJECT"; end
	return nil;
end

-- 单城实际加成：当前生产对象匹配 → 城市生产力 × Amount%（不匹配返回 0）
local function MPT_CityProductionImpact(tMod:table, pCity:table, pMatch)
	local def:table, sKind:string = MPT_GetCurrentProduction(pCity);
	if def == nil or not pMatch(def, sKind) then return 0; end
	return pCity:GetYield(YieldTypes.PRODUCTION) * (tonumber(tMod.Arguments.Amount or 0) / 100.0);
end

-- 通用包装：City 主体算单城、Player 主体遍历全部城市求和（COLLECTION_OWNER 类修饰符）
-- [MPT 条目21修复] pMatch 参数不可写 :function 标注（保留字做类型名，解析期报错，见 1836 行前科）
local function MPT_ImpactProduction(tMod:table, tSubject:table, sSubjectType:string, pMatch)
	local tImpact:table = YieldTableNew();
	if tSubject.SubjectType == SubjectTypes.City and tSubject.City ~= nil then
		tImpact.PRODUCTION = MPT_CityProductionImpact(tMod, tSubject.City, pMatch);
	elseif tSubject.SubjectType == SubjectTypes.Player and tSubject.Player ~= nil then
		local iTotal:number = 0;
		for _,pCity in tSubject.Player:GetCities():Members() do
			iTotal = iTotal + MPT_CityProductionImpact(tMod, pCity, pMatch);
		end
		tImpact.PRODUCTION = iTotal;
	else
		return nil;
	end
	return tImpact;
end

-- 时代判定：单位经 PrereqTech → Technologies.EraType（奇观另经 PrereqCivic → Civics.EraType）
local function MPT_GetDefEra(def:table)
	if def.PrereqTech ~= nil then
		local techDef:table = GameInfo.Technologies[def.PrereqTech];
		if techDef ~= nil then return techDef.EraType; end
	end
	if def.PrereqCivic ~= nil then
		local civicDef:table = GameInfo.Civics[def.PrereqCivic];
		if civicDef ~= nil then return civicDef.EraType; end
	end
	return nil;
end

-- 1/9 组：单位生产力（精确 + 文明替代单位）
MPT_ImpactHandlers["EFFECT_ADJUST_UNIT_PRODUCTION"] = function(tMod, tSubject, sSubjectType)
	return MPT_ImpactProduction(tMod, tSubject, sSubjectType, function(def, sKind)
		if sKind ~= "UNIT" then return false; end
		if def.UnitType == tMod.Arguments.UnitType then return true; end
		local rep:table = GameInfo.UnitReplaces[def.UnitType];
		return rep ~= nil and rep.ReplacesUnitType == tMod.Arguments.UnitType;
	end);
end;
-- 兵种+时代生产力（最多使用）：PromotionClass 匹配 + PrereqTech 时代匹配（NO_ERA 不限时代）
MPT_ImpactHandlers["EFFECT_ADJUST_UNIT_TAG_ERA_PRODUCTION"] = function(tMod, tSubject, sSubjectType)
	return MPT_ImpactProduction(tMod, tSubject, sSubjectType, function(def, sKind)
		if sKind ~= "UNIT" or def.PromotionClass ~= tMod.Arguments.UnitPromotionClass then return false; end
		local sEra:string = tMod.Arguments.EraType;
		if sEra == nil or sEra == "NO_ERA" then return true; end
		return MPT_GetDefEra(def) == sEra;
	end);
end;
-- 建筑生产力（含文明替代建筑）
MPT_ImpactHandlers["EFFECT_ADJUST_BUILDING_PRODUCTION"] = function(tMod, tSubject, sSubjectType)
	return MPT_ImpactProduction(tMod, tSubject, sSubjectType, function(def, sKind)
		if sKind ~= "BUILDING" then return false; end
		if def.BuildingType == tMod.Arguments.BuildingType then return true; end
		local rep:table = GameInfo.BuildingReplaces[def.BuildingType];
		return rep ~= nil and rep.ReplacesBuildingType == tMod.Arguments.BuildingType;
	end);
end;
-- 区域生产力（含文明替代区域）
MPT_ImpactHandlers["EFFECT_ADJUST_DISTRICT_PRODUCTION"] = function(tMod, tSubject, sSubjectType)
	return MPT_ImpactProduction(tMod, tSubject, sSubjectType, function(def, sKind)
		if sKind ~= "DISTRICT" then return false; end
		if def.DistrictType == tMod.Arguments.DistrictType then return true; end
		local rep:table = GameInfo.DistrictReplaces[def.DistrictType];
		return rep ~= nil and rep.ReplacesDistrictType == tMod.Arguments.DistrictType;
	end);
end;
-- 项目生产力（精确）
MPT_ImpactHandlers["EFFECT_ADJUST_PROJECT_PRODUCTION"] = function(tMod, tSubject, sSubjectType)
	return MPT_ImpactProduction(tMod, tSubject, sSubjectType, function(def, sKind)
		return sKind == "PROJECT" and def.ProjectType == tMod.Arguments.ProjectType;
	end);
end;
-- 全项目生产力
MPT_ImpactHandlers["EFFECT_ADJUST_ALL_PROJECTS_PRODUCTION"] = function(tMod, tSubject, sSubjectType)
	return MPT_ImpactProduction(tMod, tSubject, sSubjectType, function(def, sKind)
		return sKind == "PROJECT";
	end);
end;
-- 太空项目生产力（Projects.SpaceRace 列判定）
MPT_ImpactHandlers["EFFECT_ADJUST_SPACE_RACE_PROJECTS_PRODUCTION"] = function(tMod, tSubject, sSubjectType)
	return MPT_ImpactProduction(tMod, tSubject, sSubjectType, function(def, sKind)
		return sKind == "PROJECT" and def.SpaceRace ~= nil and def.SpaceRace ~= 0;
	end);
end;
-- 全单位生产力
MPT_ImpactHandlers["EFFECT_ADJUST_ALL_UNIT_PRODUCTION_MODIFIER"] = function(tMod, tSubject, sSubjectType)
	return MPT_ImpactProduction(tMod, tSubject, sSubjectType, function(def, sKind)
		return sKind == "UNIT";
	end);
end;
-- 时代奇观生产力：奇观（Buildings.IsWonder）且前置科技/市政时代在 [StartEra, EndEra] 区间
MPT_ImpactHandlers["EFFECT_ADJUST_WONDER_ERA_PRODUCTION"] = function(tMod, tSubject, sSubjectType)
	return MPT_ImpactProduction(tMod, tSubject, sSubjectType, function(def, sKind)
		if sKind ~= "BUILDING" or def.IsWonder == nil or def.IsWonder == 0 then return false; end
		local sEra:string = MPT_GetDefEra(def);
		if sEra == nil then return false; end
		local eraDef:table = GameInfo.Eras[sEra];
		local startDef:table = GameInfo.Eras[tMod.Arguments.StartEra];
		local endDef:table = GameInfo.Eras[tMod.Arguments.EndEra];
		if eraDef == nil or startDef == nil or endDef == nil then return false; end
		return eraDef.Index >= startDef.Index and eraDef.Index <= endDef.Index;
	end);
end;

-- ----------------------------------------------------------------------------
-- MPT_LineHandlers 注册区：每条目 function(tMod, ePlayerID) -> string（单行，卡面 [NEWLINE] 分隔）
-- [MPT 条目21用户裁决] 仅保留「明确的资源数量加成/产出加成(金/信/科/文/产/食/外交支持)/
-- 伟人点数/生产对象的生产力加成」；费用折扣/旅游/移动/经验/战力/间谍/厌战/劫掠百分比/
-- 使者倍率/开关定性类全部静默化（不显示不红字），显示行不描述回合（/每回合 字样已除）。
-- [MPT 条目21用户裁决·动态计算] 数值随局势变化的类型（资源提取/城邦商路/建筑支持/免费
-- 资源/伟人点总计）登记 MPT_DynamicHandlers：不进缓存实时计算，实际数量按 modifier 真实
-- 语义计算（如资源 = Amount × 玩家提取中地块数）。
-- ----------------------------------------------------------------------------

-- [MPT 条目21修复] 生产加成族 9 种的旧静态行 handler 已删除（迁移至上方 MPT_ImpactHandlers
-- 实际产量通道）；此处残留会双重注册同名键——hook② 因 LineHandlers 命中而短路实际计算，
-- 且静态行经 GameInfo[sTable] 动态键取名返回 userdata，撞 :table 标注类型检查即崩
-- （Lua.log 实证 POLICY_MILITARY_FIRST: Type check failed: expected 'table', got 'userdata'）

-- 资源数量族（动态计算：实际数量 = Amount × 玩家提取中地块数——IsResourceExtractableAt
-- 引擎判定含被区域/奇观覆盖的地块；无提取地块时不显示该行）
MPT_LineHandlers["EFFECT_ADJUST_PLAYER_RESOURCE_ACCUMULATION_MODIFIER"] = function(tMod, ePlayerID)
	local sRes:string = tMod.Arguments.ResourceType or "";
	local n:number = tonumber(tMod.Arguments.Amount or 0) * MPT_GetExtractionCount(ePlayerID, sRes);
	if n == 0 then return ""; end
	return MPT_Sign(n).." [ICON_"..sRes.."]";
end;
MPT_DynamicHandlers["EFFECT_ADJUST_PLAYER_RESOURCE_ACCUMULATION_MODIFIER"] = true;
-- 对城邦商路平产（动态计算：实际数量 = Amount × 当前对城邦商路条数，无商路时不显示）
MPT_LineHandlers["EFFECT_ADJUST_CITY_STATE_TRADE_ROUTE_FLAT_YIELD"] = function(tMod, ePlayerID)
	local pPlayer:table = Players[ePlayerID];
	local n:number = tonumber(tMod.Arguments.Amount or 0);
	if pPlayer == nil or n == 0 then return ""; end
	local iCount:number = 0;
	for _,pCity in pPlayer:GetCities():Members() do
		local pTrade = pCity:GetTrade();	-- [MPT 条目21修复] 接口对象去 :table 标注（userdata 风险）
		if pTrade ~= nil then
			for _,route in ipairs(pTrade:GetOutgoingRoutes()) do
				local pDest:table = Players[route.DestinationCityPlayer];
				if pDest ~= nil and pDest:IsMinor() then iCount = iCount + 1; end
			end
		end
	end
	if iCount == 0 then return ""; end
	return MPT_Sign(n * iCount)..MPT_YieldIcon(tMod.Arguments.YieldType).." ("..MPT_Phrase("LOC_MPT_EPC_CS_TRADE")..")";
end;
MPT_DynamicHandlers["EFFECT_ADJUST_CITY_STATE_TRADE_ROUTE_FLAT_YIELD"] = true;
-- 外交支持族：每回合/决议返还为全局固定量；每座建筑动态计算（实际数量 = Favor × 拥有建筑数）
MPT_LineHandlers["EFFECT_ADJUST_PLAYER_EXTRA_FAVOR_PER_TURN"] = function(tMod, ePlayerID)
	return MPT_Sign(tonumber(tMod.Arguments.Amount or 0)).." [ICON_FAVOR]";
end;
MPT_LineHandlers["EFFECT_ADJUST_PLAYER_BUILDING_FAVOR"] = function(tMod, ePlayerID)
	local pPlayer:table = Players[ePlayerID];
	local buildingDef:table = GameInfo.Buildings[tMod.Arguments.BuildingType];
	local n:number = tonumber(tMod.Arguments.Favor or 0);
	if pPlayer == nil or buildingDef == nil or n == 0 then return ""; end
	local iCount:number = 0;
	for _,pCity in pPlayer:GetCities():Members() do
		if pCity:GetBuildings():HasBuilding(buildingDef.Index) then iCount = iCount + 1; end
	end
	if iCount == 0 then return ""; end
	return MPT_Sign(n * iCount).." [ICON_FAVOR] ("..MPT_Phrase("LOC_MPT_EPC_PER_BUILDING")..(MPT_GetGameInfoName("Buildings", tMod.Arguments.BuildingType) or "")..")";
end;
MPT_DynamicHandlers["EFFECT_ADJUST_PLAYER_BUILDING_FAVOR"] = true;
MPT_LineHandlers["EFFECT_ADJUST_PLAYER_FAVOR_REFUND_FOR_SUCCESSFUL_RESOLUTION"] = function(tMod, ePlayerID)
	return MPT_Pct(tonumber(tMod.Arguments.Percent or 0)).." [ICON_FAVOR] ("..MPT_Phrase("LOC_MPT_EPC_RESOLUTION")..")";
end;
-- [MPT 条目21用户裁决] 免费电力不显示（用户要求去掉电力加成）
MPT_KnownEffects["EFFECT_ADJUST_CITY_FREE_POWER"] = true;
-- 每城免费资源（动态计算：实际数量 = Amount × 城市数）
MPT_LineHandlers["EFFECT_GRANT_FREE_RESOURCE_EXTRACTED"] = function(tMod, ePlayerID)
	local pPlayer:table = Players[ePlayerID];
	local sRes:string = tMod.Arguments.ResourceType or "";
	local n:number = tonumber(tMod.Arguments.Amount or 0);
	if pPlayer == nil or n == 0 then return ""; end
	local iCities:number = pPlayer:GetCities():GetCount();
	if iCities == 0 then return ""; end
	return MPT_Sign(n * iCities).." [ICON_"..sRes.."]";
end;
MPT_DynamicHandlers["EFFECT_GRANT_FREE_RESOURCE_EXTRACTED"] = true;
-- 静默化：购地/单位/全军购买费用、升级金费/资源折扣、新建街区获金、击杀战利、劫掠收益、
-- 商路/外来旅游业绩、乐队演出旅游
MPT_KnownEffects["EFFECT_ADJUST_PLOT_PURCHASE_COST"] = true;
MPT_KnownEffects["EFFECT_ADJUST_ALL_UNITS_PURCHASE_COST"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_PURCHASE_COST"] = true;
MPT_KnownEffects["EFFECT_ADJUST_PLAYER_UNIT_UPGRADE_DISCOUNT_PERCENT"] = true;
MPT_KnownEffects["EFFECT_ADJUST_PLAYER_UNIT_UPGRADE_RESOURCE_COST_DISCOUNT"] = true;
MPT_KnownEffects["EFFECT_ADJUST_PLAYER_DISTRICT_CREATE_YIELD"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_POST_COMBAT_YIELD"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_PLUNDER_YIELDS"] = true;
MPT_KnownEffects["EFFECT_ADJUST_PLAYER_TRADE_ROUTE_TOURISM_MODIFIER"] = true;
MPT_KnownEffects["EFFECT_ADJUST_PLAYER_OVERALL_TOURISM_REDUCTION"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_ROCK_BAND_TOURISM_BOMB_VALUE_PEACE"] = true;

-- 伟人点数（动态计算：总计 = Amount × 至下一位招募的回合数，上限为剩余缺口——
-- 池数据经 Game.GetGreatPeople():GetTimeline() 取未招募个人的最低招募成本，
-- 点数接口 GetPointsTotal/GetPointsPerTurn 同原版 GreatPeoplePopup 800-801 行）
MPT_LineHandlers["EFFECT_ADJUST_GREAT_PERSON_POINTS"] = function(tMod, ePlayerID)
	local sClass:string = tMod.Arguments.GreatPersonClassType;
	local n:number = tonumber(tMod.Arguments.Amount or 0);
	if sClass == nil or n == 0 or ePlayerID == nil then return ""; end
	local classDef:table = GameInfo.GreatPersonClasses[sClass];
	local pPlayer:table = Players[ePlayerID];
	local pGP = pPlayer and pPlayer:GetGreatPeoplePoints();
	if classDef == nil or pGP == nil then return ""; end
	local idx:number = classDef.Index;
	local iPerTurn:number = pGP:GetPointsPerTurn(idx) or 0;
	local iTotal:number = pGP:GetPointsTotal(idx) or 0;
	-- 本 class 未招募个人的最低招募成本（点数池逐人递增，最低者即下一位）
	local iNextCost:number = nil;
	local pGreatPeople = Game.GetGreatPeople();
	if pGreatPeople ~= nil then
		for _,entry in ipairs(pGreatPeople:GetTimeline()) do
			if entry.Claimant == nil and entry.Individual ~= nil then
				local ind:table = GameInfo.GreatPersonIndividuals[entry.Individual];
				if ind ~= nil and ind.GreatPersonClassType == sClass then
					local iCost:number = tonumber(entry.Cost or 0);
					if iCost > 0 and (iNextCost == nil or iCost < iNextCost) then iNextCost = iCost; end
				end
			end
		end
	end
	if iNextCost ~= nil and iNextCost > iTotal then
		-- 到下一位被招募前本 modifier 累计贡献 = Amount × 剩余回合数，上限为剩余缺口
		local iRemaining:number = iNextCost - iTotal;
		local iTurns:number = math.max(1, math.ceil(iRemaining / math.max(1, iPerTurn + n)));
		local iGain:number = math.min(n * iTurns, iRemaining);
		if iGain > 0 then
			return MPT_Sign(iGain).." [ICON_"..sClass.."] ("..MPT_Phrase("LOC_MPT_EPC_TO_NEXT")..")";
		end
	end
	return MPT_Sign(n).." [ICON_"..sClass.."]";	-- 池信息不可得/进度已过：退回固定点数
end;
MPT_DynamicHandlers["EFFECT_ADJUST_GREAT_PERSON_POINTS"] = true;
MPT_LineHandlers["EFFECT_ADJUST_INFLUENCE_POINTS_PER_TURN"] = function(tMod)
	return MPT_Sign(tonumber(tMod.Arguments.Amount or 0)).." "..MPT_Phrase("LOC_MPT_EPC_INFLUENCE");
end;
MPT_LineHandlers["EFFECT_ADJUST_ALLIANCE_POINTS_FOR_MODIFIER"] = function(tMod)
	return MPT_Sign(tonumber(tMod.Arguments.Amount or 0)).." "..MPT_Phrase("LOC_MPT_EPC_ALLIANCE");
end;
MPT_KnownEffects["EFFECT_ADJUST_DUPLICATE_FIRST_INFLUENCE_TOKEN"] = true;
MPT_KnownEffects["EFFECT_ADJUST_DUPLICATE_INFLUENCE_TOKEN_WHEN_RIVAL_GOVERNMENT"] = true;

-- 建造者次数（审判官次数/移动/经验/战力/间谍/厌战等已静默化）
MPT_LineHandlers["EFFECT_ADJUST_UNIT_BUILD_CHARGES"] = function(tMod)
	return MPT_Sign(tonumber(tMod.Arguments.Amount or 0)).." [ICON_BUILD_CHARGES] ("..MPT_Phrase("LOC_MPT_EPC_BUILD_CHARGES")..")";
end;
-- 静默化：审判官次数（负向反直觉）、单位移动（含敌境/友境起始）、经验获取、对蛮族战力、
-- 城市外部防御、城市远程打击、受损战力减免、劫掠城区/改良、单位战力(attach)、厌战积累、
-- 间谍行动等级/反间谍等级、窃取科技加速、间谍行动耗时
MPT_KnownEffects["EFFECT_ADJUST_INQUISITION_START_CHARGES"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_MOVEMENT"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_ENEMY_TERRITORY_START_MOVEMENT"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_FRIENDLY_TERRITORY_START_MOVEMENT"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_EXPERIENCE_MODIFIER"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_BARBARIAN_COMBAT"] = true;
MPT_KnownEffects["EFFECT_ADJUST_CITY_OUTER_DEFENSE"] = true;
MPT_KnownEffects["EFFECT_ADJUST_CITY_RANGED_STRIKE"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_STRENGTH_REDUCTION_FOR_DAMAGE_MODIFIER"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_PILLAGE_DISTRICT_MODIFIER"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_PILLAGE_IMPROVEMENT_MODIFIER"] = true;
MPT_KnownEffects["EFFECT_ADJUST_PLAYER_STRENGTH_MODIFIER"] = true;
MPT_KnownEffects["EFFECT_ADJUST_WAR_WEARINESS"] = true;
MPT_KnownEffects["EFFECT_ADJUST_PLAYER_SPY_BONUS"] = true;
MPT_KnownEffects["EFFECT_ADJUST_PLAYER_STEAL_TECH_BOOSTS"] = true;
MPT_KnownEffects["EFFECT_ADJUST_UNIT_SPY_OFFENSIVE_OPERATION_TIME"] = true;

-- 开关/定性族全部静默化（授予隐藏能力/晋升无限制/禁止治疗/禁止影响力/禁止定居/
-- 禁止单位入境/禁止建造/开放边境/不满衰减——与卡面描述重复或无数量含义）
MPT_KnownEffects["EFFECT_GRANT_ABILITY"] = true;
MPT_KnownEffects["EFFECT_GRANT_UNIT_TYPE_UNLIMITED_PROMOTION_CHOICES"] = true;
MPT_KnownEffects["EFFECT_ADJUST_DISABLE_HEALING"] = true;
MPT_KnownEffects["EFFECT_ADJUST_DISABLE_INFLUENCE"] = true;
MPT_KnownEffects["EFFECT_ADJUST_DISABLE_SETTLING"] = true;
MPT_KnownEffects["EFFECT_ADJUST_PLAYER_BLOCK_UNIT_ENTRY"] = true;
MPT_KnownEffects["EFFECT_ADJUST_PLAYER_UNIT_BUILD_DISABLED"] = true;
MPT_KnownEffects["EFFECT_ADJUST_PLAYER_OPEN_BORDERS_FROM_INFLUENCE"] = true;
MPT_KnownEffects["DISABLE_PLAYER_GRIEVANCE_DECAY"] = true;

-- ----------------------------------------------------------------------------
-- MPT 行入口：按 EffectType 取格式化行，结果按 ModifierId 缓存（动态计算类跳过缓存实时求值；
-- 返回 nil = 非 MPT 显示类型：含未识别（走原链可能红字）与已识别静默（用户裁决不显示））
-- ----------------------------------------------------------------------------
function MPT_GetModifierLine(tMod:table, ePlayerID:number)
	if tMod == nil or tMod.EffectType == nil then return nil; end
	local bDynamic:boolean = (MPT_DynamicHandlers[tMod.EffectType] == true);
	if not bDynamic then
		local sCached:string = MPT_LineCache[tMod.ModifierId];
		if sCached ~= nil then
			if sCached == "" then return nil; end
			return sCached;
		end
	end
	local sLine:string = nil;
	-- [MPT 条目21修复] 不能写 pHandler:function——标注位要求类型名而 function 是保留字，
	-- 解析器报 <name> expected near 'function' 致整个 chunk 中止（条目18 cfunction/ifunction 同族坑）；
	-- pHandler 仅被调用不参与比较，无标注即无运行时类型检查，不必写 ifunction
	-- local pHandler:function = MPT_LineHandlers[tMod.EffectType];
	-- [MPT 条目21用户裁决] 表值三种形态：function=显示行、false=已识别静默（仅 KnownEffects 语义）、
	-- nil=未识别走原链——这里只调用函数形态
	local pHandler = MPT_LineHandlers[tMod.EffectType];
	if type(pHandler) == "function" then
		sLine = pHandler(tMod, ePlayerID);	-- handler 异常按 nil 兜底，不影响原链
	end
	if not bDynamic then
		if sLine ~= nil and sLine ~= "" then
			MPT_LineCache[tMod.ModifierId] = sLine;
			return sLine;
		end
		MPT_LineCache[tMod.ModifierId] = "";	-- 已知类型但无行（静默/参数异常），不再走 Unknown
	end
	return nil;
end

-- ----------------------------------------------------------------------------
-- [MPT 条目21优化] (modifiers 表, 类型字段, 类型值) → ModifierId 列表 懒索引
-- 替代 CalculateModifierEffect 对 GameInfo.XxxModifiers() 的全表扫描
-- （政府界面每次打开 59 卡 × 全表扫，政策表 100+ 行；索引一次构建全周期复用）
-- ----------------------------------------------------------------------------
local function MPT_GetObjectModifierIds(sTable:string, sField:string, sType:string)
	local sKey:string = sTable.."|"..sField.."|"..sType;
	local tCached:table = MPT_ModIndexCache[sKey];
	if tCached then return tCached; end
	local tIds:table = {};
	for row in GameInfo[sTable]() do
		if row[sField] == sType then
			-- stupid Firaxis, some fields are named ModifierId and some ModifierID (sic!) —— 原逻辑移入
			local sId:string = row.ModifierId;
			if not sId then sId = row.ModifierID; end
			if sId then table.insert(tIds, sId); end
		end
	end
	MPT_ModIndexCache[sKey] = tIds;
	return tIds;
end

------------------------------------------------------------------------------
-- Returns 5 values:
--  string - decoded into text (tooltip), contains info about structure, owner, subjects and final impact
--  table - extended yields table
--  string - id of the attached modifier, if an effect is "attach modifier"
--  boolean - true if there was an unknown effect
--  table - the modifier
--  string - type of subjects
function DecodeModifier(sModifierId:string, ePlayerID:number, iCityID:number, tMainSubjects:table, sMainSubjectType:string)
	--print("DecodeModifier(modid,pid,cid,subtype)",sModifierId,ePlayerID,iCityID,sMainSubjectType);
	local tMod:table = FetchAndCacheData(sModifierId);
	if not tMod then return "ERROR: "..sModifierId.." not defined!"; end
	local tOut = {};
	table.insert(tOut, "Modifier: "..tMod.ModifierId);
	table.insert(tOut, "Type: "..string.sub(tMod.ModifierType, 10)); -- 230514 #2
	if tMod.OwnerReqSetId then
		table.insert(tOut, "Owner: "..tMod.OwnerReqSetId);
		DecodeReqSet(tOut, tMod.OwnerReqSetId);
	end
	table.insert(tOut, "Collection: "..string.sub(tMod.CollectionType, 12)); -- 230514 #2
	if tMod.SubjectReqSetId then
		table.insert(tOut, "Subject: "..tMod.SubjectReqSetId);
		DecodeReqSet(tOut, tMod.SubjectReqSetId);
	end
	table.insert(tOut, "Effect: "..string.sub(tMod.EffectType, 8)); -- 230514 #2
	for name,value in pairs(tMod.Arguments) do table.insert(tOut, name.." = "..value); end
	if tMod.ScaleByGameSpeed then table.insert(tOut, "Scaled by Game Speed"); end
	if tMod.RunOnce then table.insert(tOut, "Run Once"); end
	if tMod.NewOnly then table.insert(tOut, "New Only"); end
	if tMod.Permanent then table.insert(tOut, "Permanent"); end
	-- analysis starts here
	if bBaseDataDirty then RefreshBaseData(); end -- make sure we have current data
	-- TODO: ASSUMPTION Owner will be Player, this is true for Policies and many other modifiers
	-- TODO: add support for other owners later, if necessary
	local tOwner:table, sOwnerType:string = tPlayer, SubjectTypes.Player; -- Players[ Game:GetLocalPlayer() ]
	-- 2018-03-27 added City support
	if ePlayerID and iCityID then
		local pCity:table = Players[ePlayerID]:GetCities():FindID(iCityID);
		if pCity then tOwner, sOwnerType = tCities[ pCity:GetName()], SubjectTypes.City; end
	end
	-- build a collection of subjects
	local tSubjects:table, sSubjectType:string = tMainSubjects, sMainSubjectType; -- let's start with passed args, will be nils most of the time
	if tMainSubjects == nil or sMainSubjectType == nil then 
		-- rebuild collection
		tSubjects, sSubjectType = BuildCollectionOfSubjects(tMod, tOwner, sOwnerType);
	else
		if tMod.CollectionType == "COLLECTION_CITY_DISTRICTS" then
			-- try to pass cities
			tSubjects, sSubjectType = BuildCollectionOfSubjects(tMod, tMainSubjects, sMainSubjectType);
		elseif tMod.CollectionType ~= "COLLECTION_OWNER" then
			-- rebuild collection
			tSubjects, sSubjectType = BuildCollectionOfSubjects(tMod, tOwner, sOwnerType);
		end
	end
	--print("Subjects are:"); for k,v in pairs(tSubjects) do print(k,v.SubjectType,v.Name); end -- debug
	--dshowsubjects(tSubjects); -- debug
	-- list subjects
	local tSubjectsOut:table = {};
	table.insert(tSubjectsOut, "Subject(s): "..sSubjectType);
	table.insert(tSubjectsOut, table.count(tSubjects));
	--if sSubjectType ~= SubjectTypes.Plot then
		for _,subject in ipairs(tSubjects) do table.insert(tSubjectsOut, subject.Name); end
	--end
	table.insert(tOut, table.concat(tSubjectsOut, ", "));
	-- calculate impact of the modifier
	local bUnknownEffect:boolean = false;
	local tImpact:table = YieldTableNew();
	for i,subject in pairs(tSubjects) do
		-- [MPT 条目21优化] 已知扩展类型（MPT_LineHandlers 或 MPT_KnownEffects 有登记）跳过原链——
		-- 原链对未处理 EffectType 返回 nil 会误标红字 Unknown；显示类收益以文本行通道在
		-- CalculateModifierEffect 展示，静默类（用户裁决不显示）按零产量处理
		-- local tSubjectImpact:table = ApplyEffectAndCalculateImpact(tMod, subject, sSubjectType); -- it will return nil if effect unknown
		local tSubjectImpact:table = nil;
		if MPT_LineHandlers[tMod.EffectType] ~= nil or MPT_KnownEffects[tMod.EffectType] then
			tSubjectImpact = YieldTableNew();
		else
			tSubjectImpact = ApplyEffectAndCalculateImpact(tMod, subject, sSubjectType);
		end
		if tSubjectImpact then
			--dprint("Impact for subject ", subject.Name); dshowyields(tSubjectImpact); -- debug
			YieldTableAdd(tImpact, tSubjectImpact);
		else
			bUnknownEffect = true;
		end
	end
	--dprint("Impact for all subjects"); dshowyields(tImpact); -- debug
	-- create an output string
	local sImpactText:string = "Effect: ";
	local bImpact:boolean = false;
	for	yield,value in pairs(tImpact) do
		if value ~= 0 then
			sImpactText = sImpactText..GetYieldString("YIELD_"..yield, value);
			bImpact = true;
		end
	end
	if not bImpact then sImpactText = sImpactText.."yields not affected"; end
	table.insert(tOut, sImpactText);
	if bUnknownEffect then table.insert(tOut, "[COLOR_Red]Unknown effect[ENDCOLOR]"); end -- [ICON_Exclamation]
	-- return 7 values
	return
		table.concat(tOut, "[NEWLINE]"),
		tImpact,
		((tMod.EffectType == "EFFECT_ATTACH_MODIFIER") and tMod.Arguments.ModifierId) or nil,
		bUnknownEffect,
		tMod,
		tSubjects,
		sSubjectType;
end


-- ===========================================================================
-- MODIFIERS' DYNAMIC ANALYSIS
-- ===========================================================================

------------------------------------------------------------------------------
-- Requires 3 arguments
--  table - requirement
--  table - subject to analyze (from tCities or any other)
--  string - type of subject (e.g. "City", "District")
function CheckOneRequirement(tReq:table, tSubject:table, sSubjectType:string)
	--print("CheckOneRequirement(req,type,sub)(subject)",tReq.ReqId,tReq.ReqType,sSubjectType,tSubject.SubjectType,tSubject.Name);
	
	local function CheckForMismatchError(sExpectedType:string, sExpectedType2:string)
		if sExpectedType == tSubject.SubjectType or (sExpectedType2 ~= nil and sExpectedType2 == tSubject.SubjectType) then return false; end
		print("ERROR: CheckOneRequirement mismatch for exp subject", sExpectedType, "got", tSubject.SubjectType, "req is", tReq.ReqId, tReq.ReqType); return true;
	end
	
	-- MAIN DISPATCHER FOR REQUIREMENTS
	local bIsValidSubject:boolean = false;
	
	if     tReq.ReqType == "REQUIREMENT_REQUIREMENTSET_IS_MET" then -- 19
		-- recursion? could be diffcult
		
	-- bunch of reqs simulated to be always true (usually regarding player's situation)
	elseif tReq.ReqType == "REQUIREMENT_PLAYER_IS_AT_PEACE"                 then return true;
	elseif tReq.ReqType == "REQUIREMENT_PLAYER_IS_AT_PEACE_WITH_ALL_MAJORS" then return true;
	elseif tReq.ReqType == "REQUIREMENT_CITY_FOLLOWS_PANTHEON" then return true;
	elseif tReq.ReqType == "REQUIREMENT_CITY_FOLLOWS_RELIGION" then return true;
	elseif tReq.ReqType == "REQUIREMENT_PLAYER_HAS_PANTHEON" then return true; -- 2019-04-14 Support for Real Balanced Pantheons
	
	-- 2019-04-14 Support for Real Balanced Pantheons
	elseif tReq.ReqType == "REQUIREMENT_GAME_ERA_IS" then
		-- valid for any subject, no check needed
		if bIsRiseAndFall then
			local eraType:string = GameInfo.Eras[ Game.GetEras():GetCurrentEra() ].EraType;
			bIsValidSubject = ( tReq.Arguments.EraType == eraType );
		end
	
	elseif tReq.ReqType == "REQUIREMENT_CITY_HAS_BUILDING" then -- 35, Wonders too!
		--if CheckForMismatchError(SubjectTypes.City) then return false; end
		if not( tSubject.SubjectType == SubjectTypes.City or tSubject.SubjectType == SubjectTypes.District ) then
			print("ERROR: CheckOneRequirement mismatch for subject", tSubject.SubjectType); dshowtable(tReq); return nil;
		end
		if tSubject.SubjectType == SubjectTypes.City then
			for _,district in ipairs(tSubject.Districts) do
				if district.isBuilt then
					for _,building in ipairs(district.Buildings) do
						local buildingType:string = building.BuildingType;	
						if GameInfo.BuildingReplaces[ buildingType ] then buildingType = GameInfo.BuildingReplaces[ buildingType ].ReplacesBuildingType; end
						bIsValidSubject = ( buildingType == tReq.Arguments.BuildingType ); -- BUILDING_LIGHTHOUSE, etc.
						if bIsValidSubject then break; end
					end
					if bIsValidSubject then break; end
				end -- isBuilt
			end
			if not bIsValidSubject then -- still not found
				for _,wonder in ipairs(tSubject.Wonders) do
					-- wonders don't have replacements
					bIsValidSubject = ( wonder.BuildingType == tReq.Arguments.BuildingType ); -- BUILDING_ST_BASILS_CATHEDRAL, etc.
					if bIsValidSubject then break; end
				end
			end
		else --  subject is District
			if tSubject.isBuilt then
				for _,building in ipairs(tSubject.Buildings) do
					local buildingType:string = building.BuildingType;	
					if GameInfo.BuildingReplaces[ buildingType ] then buildingType = GameInfo.BuildingReplaces[ buildingType ].ReplacesBuildingType; end
					bIsValidSubject = ( buildingType == tReq.Arguments.BuildingType ); -- BUILDING_LIGHTHOUSE, etc.
					if bIsValidSubject then break; end
				end
			end -- isBuilt
		end

	elseif tReq.ReqType == "REQUIREMENT_CITY_HAS_DISTRICT" then -- 10
		if CheckForMismatchError(SubjectTypes.City) then return false; end
		for _,district in ipairs(tSubject.Districts) do
			if district.isBuilt then
				local districtType:string = district.DistrictType;	
				if GameInfo.DistrictReplaces[ districtType ] then districtType = GameInfo.DistrictReplaces[ districtType ].ReplacesDistrictType; end
				bIsValidSubject = ( districtType == tReq.Arguments.DistrictType ); -- DISTRICT_THEATER, etc.
				if bIsValidSubject then break; end
			end -- isBuilt
		end
		
	elseif tReq.ReqType == "REQUIREMENT_CITY_HAS_HIGH_ADJACENCY_DISTRICT" then
		if CheckForMismatchError(SubjectTypes.City) then return false; end
		-- must use 3 arguments actually, plus replacements
		for _,district in ipairs(tSubject.Districts) do
			if district.isBuilt then
				local districtType:string = district.DistrictType;	
				if GameInfo.DistrictReplaces[ districtType ] then districtType = GameInfo.DistrictReplaces[ districtType ].ReplacesDistrictType; end
				bIsValidSubject = ( ( districtType == tReq.Arguments.DistrictType ) and -- DISTRICT_THEATER, etc.
									( YieldTableGetYield(district.Yields, tReq.Arguments.YieldType) >= tonumber(tReq.Arguments.Amount)) );
				if bIsValidSubject then break; end
			end -- isBuilt
		end

	elseif tReq.ReqType == "REQUIREMENT_CITY_HAS_X_POPULATION" then
		if CheckForMismatchError(SubjectTypes.City) then return false; end
		bIsValidSubject = ( tSubject.Population >= tonumber(tReq.Arguments.Amount) );
		
	elseif tReq.ReqType == "REQUIREMENT_CITY_HAS_X_SPECIALTY_DISTRICTS" then
		if CheckForMismatchError(SubjectTypes.City) then return false; end
		--local iNumDistricts:number = 0;
		--for _,district in ipairs(tSubject.Districts) do
			--if not district.CityCenter then iNumDistricts = iNumDistricts + 1; end
		--end
		bIsValidSubject = ( tSubject.NumSpecialtyDistricts >= tonumber(tReq.Arguments.Amount) );

	elseif tReq.ReqType == "REQUIREMENT_CITY_HAS_GOVERNOR" then
		if CheckForMismatchError(SubjectTypes.City) then return false; end
		bIsValidSubject = tSubject.IsGovernorEstablished;

	elseif tReq.ReqType == "REQUIREMENT_CITY_HAS_GOVERNOR_WITH_X_TITLES" then
		if CheckForMismatchError(SubjectTypes.City) then return false; end
		bIsValidSubject = (tSubject.IsGovernorEstablished and tSubject.NumGovernorPromotions >= tonumber(tReq.Arguments.Amount))
		
	elseif tReq.ReqType == "REQUIREMENT_CITY_HAS_GARRISON_UNIT" then
		if CheckForMismatchError(SubjectTypes.City) then return false; end
		bIsValidSubject = tSubject.IsGarrisonUnit;

	elseif tReq.ReqType == "REQUIREMENT_CITY_IS_OWNER_CAPITAL_CONTINENT" then
		if CheckForMismatchError(SubjectTypes.City) then return false; end
		-- compare capital's continent to this one
		local pCapital:table = Players[ tSubject.City:GetOwner() ]:GetCities():GetCapitalCity(); -- TODO: probably should be stored in thePlayer object
		local eOwnerCapitalContinent:number = Map.GetPlot( pCapital:GetX(), pCapital:GetY() ):GetContinentType();
		bIsValidSubject = ( tSubject.ContinentType == eOwnerCapitalContinent );
	
	elseif tReq.ReqType == "REQUIREMENT_DISTRICT_TYPE_MATCHES" then -- 12
		if CheckForMismatchError(SubjectTypes.District) then return false; end
		local districtType:string = tSubject.DistrictType;
		if GameInfo.DistrictReplaces[ districtType ] then districtType = GameInfo.DistrictReplaces[ districtType ].ReplacesDistrictType; end
		bIsValidSubject = ( districtType == tReq.Arguments.DistrictType ); -- DISTRICT_THEATER, etc.
			
	elseif tReq.ReqType == "REQUIREMENT_PLAYER_HAS_BUILDING" then -- 9
		if CheckForMismatchError("Player") then return false; end
		
	elseif tReq.ReqType == "REQUIREMENT_PLAYER_HAS_TECHNOLOGY" then -- 9
		--if CheckForMismatchError("Player") then return false; end
        -- 2021-05-14 Johannesburg fix
        local function CheckPlayerHasTechnology(pPlayer:table, sTech:string)
            if GameInfo.Technologies[sTech] == nil then return false; end
            return pPlayer:GetTechs():HasTech(GameInfo.Technologies[sTech].Index);
        end
        if tSubject.SubjectType == SubjectTypes.Player then
            bIsValidSubject = CheckPlayerHasTechnology(tPlayer.Player, tReq.Arguments.TechnologyType);
        elseif tSubject.SubjectType == SubjectTypes.City then
            bIsValidSubject = CheckPlayerHasTechnology(Players[ tSubject.City:GetOwner() ], tReq.Arguments.TechnologyType);
        else
            print("ERROR: CheckOneRequirement mismatch for subject", tSubject.SubjectType); dshowtable(tReq); return nil;
        end
		
	elseif tReq.ReqType == "REQUIREMENT_PLAYER_HAS_DISTRICT" then -- 1
		if CheckForMismatchError("Player") then return false; end
		
	elseif tReq.ReqType == "REQUIREMENT_PLOT_TERRAIN_CLASS_MATCHES" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		bIsValidSubject = false;
		local eTerrainType:number = tSubject.Plot:GetTerrainType();
		if eTerrainType ~= -1 then
			local sTerrainType:string = GameInfo.Terrains[eTerrainType].TerrainType;
			for row in GameInfo.TerrainClass_Terrains() do
				if row.TerrainType == sTerrainType and row.TerrainClassType == tReq.Arguments.TerrainClass then
					bIsValidSubject = true; break;
				end
			end
		end -- if
		
	elseif tReq.ReqType == "REQUIREMENT_PLOT_TERRAIN_TYPE_MATCHES" then -- 14
		if CheckForMismatchError(SubjectTypes.Plot, SubjectTypes.City) then return false; end -- 2021-05-14 Can also be a City
		local info:table = GameInfo.Terrains[ tReq.Arguments.TerrainType ];
		if info == nil then return false; end -- error
		bIsValidSubject = ( tSubject.Plot:GetTerrainType() == info.Index );

	elseif tReq.ReqType == "REQUIREMENT_PLOT_HAS_ANY_FEATURE" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		bIsValidSubject = ( tSubject.Plot:GetFeatureType() ~= -1 );
		
	elseif tReq.ReqType == "REQUIREMENT_PLOT_FEATURE_TYPE_MATCHES" then -- 10
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		local info:table = GameInfo.Features[ tReq.Arguments.FeatureType ];
		if info == nil then return false; end -- error
		bIsValidSubject = ( tSubject.Plot:GetFeatureType() == info.Index );

	elseif tReq.ReqType == "REQUIREMENT_PLOT_HAS_ANY_RESOURCE" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		bIsValidSubject = ( tSubject.Plot:GetResourceType() ~= -1 );
		
	elseif tReq.ReqType == "REQUIREMENT_PLOT_RESOURCE_TYPE_MATCHES" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		local info:table = GameInfo.Resources[ tReq.Arguments.ResourceType ];
		if info == nil then return false; end -- error
		bIsValidSubject = ( tSubject.Plot:GetResourceType() == info.Index );

	elseif tReq.ReqType == "REQUIREMENT_PLOT_RESOURCE_CLASS_TYPE_MATCHES" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		local resource:number = tSubject.Plot:GetResourceType();
		if resource < 0 then return false; end -- no resource in the plot
		local info:table = GameInfo.Resources[ resource ];
		if info == nil then return false; end -- error
		bIsValidSubject = ( info.ResourceClassType == tReq.Arguments.ResourceClassType );
		
	elseif tReq.ReqType == "REQUIREMENT_PLOT_RESOURCE_TAG_MATCHES" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		local resource:number = tSubject.Plot:GetResourceType();
		if resource < 0 then return false; end -- no resource in the plot
		local info:table = GameInfo.Resources[ resource ];
		if info == nil then return false; end -- error
		local sResourceType:string = info.ResourceType;
		bIsValidSubject = false;
		for row in GameInfo.TypeTags() do
			if row.Type == sResourceType and row.Tag == tReq.Arguments.Tag then
				bIsValidSubject = true; break;
			end
		end

	elseif tReq.ReqType == "REQUIREMENT_PLOT_RESOURCE_VISIBLE" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		bIsValidSubject = false;
		local resource:number = tSubject.Plot:GetResourceType();
		if resource ~= -1 then -- 2019-04-08 fixed lack of Inverse
			bIsValidSubject = ( tPlayer.Player:GetResources():IsResourceVisible( resource ) );
		end
	
	-- 2019-04-15 Support for Real Balance Pantheons
	elseif tReq.ReqType == "REQUIREMENT_PLOT_IS_MOUNTAIN" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		bIsValidSubject = tSubject.Plot:IsMountain();
		
	-- 2019-04-15 Support for Real Balance Pantheons
	elseif tReq.ReqType == "REQUIREMENT_PLOT_IS_HILLS" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		bIsValidSubject = tSubject.Plot:IsHills();
		
	-- 2019-04-15 Support for Real Balance Pantheons
	elseif tReq.ReqType == "REQUIREMENT_PLOT_HAS_ANY_DISTRICT" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		bIsValidSubject = ( tSubject.Plot:GetDistrictType() ~= -1 );
		
	-- 2019-04-15 Support for Real Balance Pantheons
	elseif tReq.ReqType == "REQUIREMENT_PLOT_HAS_ANY_IMPROVEMENT" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		bIsValidSubject = ( tSubject.Plot:GetImprovementType() ~= -1 or tSubject.Plot:GetDistrictType() ~= -1 ); -- 2020-06-04 Seems like the engine also considers districts as improvements

	elseif tReq.ReqType == "REQUIREMENT_PLOT_IMPROVEMENT_TYPE_MATCHES" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		local info:table = GameInfo.Improvements[ tReq.Arguments.ImprovementType ];
		if info == nil then print("ERROR: CheckOneRequirement unknown improvement", tReq.Arguments.ImprovementType); return false; end -- error
		bIsValidSubject = ( tSubject.Plot:GetImprovementType() == info.Index );
		
	elseif tReq.ReqType == "REQUIREMENT_PLOT_IS_APPEAL_BETWEEN" then
		--if CheckForMismatchError(SubjectTypes.Plot) then return false; end
        -- 2021-05-13 can be a District also DISTRICT_IS_CHARMING_NEIGHBORHOOD = Public Transport Policy
		if not( tSubject.SubjectType == SubjectTypes.Plot or tSubject.SubjectType == SubjectTypes.District ) then
			print("ERROR: CheckOneRequirement mismatch for subject", tSubject.SubjectType); dshowtable(tReq); return nil;
		end
		bIsValidSubject = ( tSubject.Plot:GetAppeal() >= tonumber(tReq.Arguments.MinimumAppeal) );
		-- there is probably maximum appeal but it is not used at all
		
	elseif tReq.ReqType == "REQUIREMENT_PLOT_ADJACENT_TO_RIVER" then
		--if CheckForMismatchError(SubjectTypes.Plot) then return false; end -- this could be District or Plot, maybe City?
		if not( tSubject.SubjectType == SubjectTypes.Plot or tSubject.SubjectType == SubjectTypes.District or tSubject.SubjectType == SubjectTypes.City ) then
			print("ERROR: CheckOneRequirement mismatch for subject", tSubject.SubjectType); dshowtable(tReq); return nil;
		end
		-- 2019-04-06 only IsRiver counts, tested on Hydro Dam upgrade
		--bIsValidSubject = ( tSubject.Plot:IsRiver() or tSubject.Plot:IsRiverAdjacent() );
		bIsValidSubject = tSubject.Plot:IsRiver();
	
	elseif tReq.ReqType == "REQUIREMENT_PLOT_DISTRICT_TYPE_MATCHES" then
		if CheckForMismatchError(SubjectTypes.District) then return false; end
		local districtType:string = tSubject.DistrictType;
		if GameInfo.DistrictReplaces[ districtType ] then districtType = GameInfo.DistrictReplaces[ districtType ].ReplacesDistrictType; end
		bIsValidSubject = ( districtType == tReq.Arguments.DistrictType ); -- DISTRICT_THEATER, etc.

	-- 2019-04-15 Support for Real Balance Pantheons
	elseif tReq.ReqType == "REQUIREMENT_PLOT_ADJACENT_DISTRICT_TYPE_MATCHES" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		--local districtType:string = tSubject.DistrictType;
		--if GameInfo.DistrictReplaces[ districtType ] then districtType = GameInfo.DistrictReplaces[ districtType ].ReplacesDistrictType; end
		local info:table = GameInfo.Districts[ tReq.Arguments.DistrictType ];
		if info == nil then print("ERROR: CheckOneRequirement unknown district", tReq.Arguments.DistrictType); return false; end -- error
		local eDistrictType:number = info.Index;
		local iX:number, iY:number = tSubject.Plot:GetX(), tSubject.Plot:GetY();
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
			if adjacentPlot ~= nil and adjacentPlot:GetDistrictType() == eDistrictType then bIsValidSubject = true; break; end
		end

    -- 2021-02-28 Support for Maritime Industries from PolicyRework2
	elseif tReq.ReqType == "REQUIREMENT_PLOT_IS_COASTAL_LAND" then -- new Requirement type from XP2 that can be used for Citied and Plots
        if tSubject.SubjectType == SubjectTypes.Plot or tSubject.SubjectType == SubjectTypes.City then
            bIsValidSubject = tSubject.Plot:IsCoastalLand(); -- City also has Plot in the table
        else
            print("ERROR: CheckOneRequirement mismatch for exp subject", "[City or Plot]", "got", tSubject.SubjectType, "req is", tReq.ReqId, tReq.ReqType); return true;
        end

	-- 230522 #3 Halicarnassus
	elseif tReq.ReqType == "REQUIREMENT_PLOT_IS_LAKE" then
		if CheckForMismatchError(SubjectTypes.Plot) then return false; end
		bIsValidSubject = tSubject.Plot:IsLake();
    
	else
		-- do nothing here... probably will never implement all possible types
		return false;
	end
	-- done!
	if tReq.Inverse then return not bIsValidSubject; end
	return bIsValidSubject;
end


------------------------------------------------------------------------------
-- Requires 3 arguments
--  table - requirement set
--  table - subject to analyze (from tCities or any other)
--  string - type of subject (e.g. "City", "District")
function CheckAllRequirements(tReqSet:table, tSubject:table, sSubjectType:string)
	--print("CheckAllRequirements(req,sub)(subject)",tReqSet.ReqSetId,sSubjectType,tSubject.SubjectType,tSubject.Name);
	for _,req in ipairs(tReqSet.Reqs) do
		local bIsValid:boolean = CheckOneRequirement(req, tSubject, sSubjectType);
		if tReqSet.TestAny and     bIsValid then return true;  end -- we found 1 positive, that is all needed for TestAny
		if tReqSet.TestAll and not bIsValid then return false; end -- we found 1 negative, that is all needed for TestAll
	end
	-- we went through all reqs and didn't break, it means that opposite condition to TestAll/Any is met
	if tReqSet.TestAny then return false; end -- all were negative
	if tReqSet.TestAll then return true;  end -- all were positive
	-- still nothing? error...
	print("ERROR: checked all requirements and nothing seems to work out for subject", sSubjectType);
	dshowtable(tReqSet);
	return false;
end


------------------------------------------------------------------------------
-- BuildCollectionOfSubjects return 2 values
--  table - of subjects - these are objects from tCities (cities, districts or buildings), TODO: filtered using SubReqs
--  string - type of the subject
function BuildCollectionOfSubjects(tMod:table, tOwner:table, sOwnerType:string)
	--print("BuildCollectionOfSubjects(subreq,ownname,owntype,passed)",tMod.SubjectReqSetId,tOwner.Name,tOwner.SubjectType,sOwnerType);
	local tSubjects:table, sSubjectType:string = {}, "([COLOR_Red]unknown[ENDCOLOR])";
	local tReqSet:table = tMod.SubjectReqSet; -- speed up some checking
	--dprint("  Subject requirement set is (id)", tMod.SubjectReqSetId);
	-- MAIN DISPATCHER FOR COLLECTIONS
	if tMod.CollectionType == "COLLECTION_OWNER" then
		-- most difficult one... not yet...
		-- for a start - we assume Player is the owner
		-- we'll need some exception handling here if this is not true
		if sOwnerType == SubjectTypes.City and tOwner.SubjectType == SubjectTypes.City then
			sSubjectType = SubjectTypes.City;
			table.insert(tSubjects, tOwner);
		else
			-- all other will get the player
			sSubjectType = SubjectTypes.Player;
			table.insert(tSubjects, tPlayer); -- there's only one
		end
		
	-- 2019-04-17 Fix for City-States attached modifiers that cannot recognize a subject properly
	elseif tMod.CollectionType == "COLLECTION_ALL_PLAYERS" then
		sSubjectType = SubjectTypes.Player;
		table.insert(tSubjects, tPlayer); -- there's only one

	elseif tMod.CollectionType == "COLLECTION_CITY_DISTRICTS" then
		local function AddDistrictsFromCity(tSubject:table)
			if tSubject.SubjectType ~= SubjectTypes.City then
				print("ERROR: BuildCollectionOfSubjects: Mismatch type for COLLECTION_CITY_DISTRICTS", sOwnerType); dshowtable(tMod); dshowrectable(tSubject); return
			end
			for _,district in ipairs(tSubject.Districts) do
				if district.isBuilt then
					--print("working on district",district.Name)
					if tReqSet then  
						if CheckAllRequirements(tReqSet, district, sSubjectType) then table.insert(tSubjects, district); end
					else
						table.insert(tSubjects, district);
					end
				end
			end
		end
		-- need City here as owner
		sSubjectType = SubjectTypes.District;
		if tOwner.SubjectType == SubjectTypes.City then -- single city
			AddDistrictsFromCity(tOwner);
		elseif sOwnerType == SubjectTypes.City then -- player's cities
			for cityname,citydata in pairs(tOwner) do
				AddDistrictsFromCity(citydata);
			end
		else
			print("ERROR: BuildCollectionOfSubjects: Mismatch type for COLLECTION_CITY_DISTRICTS", sOwnerType); dshowtable(tMod);
		end

	elseif tMod.CollectionType == "COLLECTION_PLAYER_CAPITAL_CITY" then
		sSubjectType = SubjectTypes.City;
		for cityname,citydata in pairs(tCities) do
			if citydata.IsCapital then
				table.insert(tSubjects, citydata);
				break;
			end
		end

	elseif tMod.CollectionType == "COLLECTION_PLAYER_CITIES" or
		-- WARNING! this is a shortcut for Beliefs; will produce incorrect results for e.g. Wonders or any other modifier that affects only single city
		tMod.CollectionType == "COLLECTION_ALL_CITIES" then
		sSubjectType = SubjectTypes.City;
		for cityname,citydata in pairs(tCities) do
			if tReqSet then 
				if CheckAllRequirements(tReqSet, citydata, sSubjectType) then table.insert(tSubjects, citydata); end
			else
				table.insert(tSubjects, citydata);
			end
		end

	elseif tMod.CollectionType == "COLLECTION_PLAYER_GOVERNORS" then -- we'll use cities that have an assigned Governor (doesn't need to be established?)
		sSubjectType = SubjectTypes.City;
		for cityname,citydata in pairs(tCities) do
			if bIsRiseAndFall and citydata.City:GetAssignedGovernor() then
				if tReqSet then 
					if CheckAllRequirements(tReqSet, citydata, sSubjectType) then table.insert(tSubjects, citydata); end
				else
					table.insert(tSubjects, citydata);
				end
			end
		end

	elseif tMod.CollectionType == "COLLECTION_PLAYER_DISTRICTS" then
		sSubjectType = SubjectTypes.District;
		for cityname,citydata in pairs(tCities) do
			for _,district in ipairs(citydata.Districts) do
				if district.isBuilt then
					if tReqSet then  
						if CheckAllRequirements(tReqSet, district, sSubjectType) then table.insert(tSubjects, district); end
					else
						table.insert(tSubjects, district);
					end
				end
			end
		end
		
	elseif tMod.CollectionType == "COLLECTION_PLAYER_PLOT_YIELDS" or 
		-- WARNING! this is a shortcut for Pantheons; will produce incorrect results for e.g. Wonders or any other modifier that affects only single city
		tMod.CollectionType == "COLLECTION_CITY_PLOT_YIELDS" then
		sSubjectType = SubjectTypes.Plot;
		for _,plot in ipairs(tPlots) do
			if tReqSet then
				if CheckAllRequirements(tReqSet, plot, sSubjectType) then table.insert(tSubjects, plot); end
			else
				table.insert(tSubjects, plot);
			end
		end

		
	else
		-- do nothing here... probably will never implement all possible types
		--COLLECTION_ALL_PLOT_YIELDS
		--COLLECTION_SINGLE_PLOT_YIELDS
		-- units
		--COLLECTION_ALLIANCE_TRAINED_UNITS
		--COLLECTION_ALLIANCE_UNITS
		--COLLECTION_ALL_UNITS
		--COLLECTION_CITY_TRAINED_UNITS
		--COLLECTION_EMERGENCY_UNITS
		--COLLECTION_PLAYER_TRAINED_UNITS
		--COLLECTION_PLAYER_UNITS
	end
	return tSubjects, sSubjectType;
end


------------------------------------------------------------------------------
-- Returns a table of extended yields
-- It will return nil if an effect is unknown
function ApplyEffectAndCalculateImpact(tMod:table, tSubject:table, sSubjectType:string)
	--print("ApplyEffectAndCalculateImpact(mod,eff,sub)(subject)",tMod.ModifierId,tMod.EffectType,sSubjectType,tSubject.SubjectType,tSubject.Name);

	local function CheckForMismatchError(sExpectedType:string)
		if sExpectedType == tSubject.SubjectType then return false; end
		print("ERROR: ApplyEffectAndCalculateImpact mismatch for subject", sSubjectType); dshowtable(tMod); return true;
	end
	
	-- MAIN DISPATCHER FOR EFFECTS
	local tImpact:table = YieldTableNew();

	-- [MPT 条目21用户裁决] 生产族实际产量计算（MPT_ImpactHandlers）：按城市当前生产对象
	-- 匹配后取「城市生产力 × Amount%」，City 主体算单城、Player 主体遍历全城求和
	-- （DecodeModifier 对城市集合自动 YieldTableAdd 汇总）。异常/nil 静默零产量不红字
	local pMPTImpactHandler = MPT_ImpactHandlers[tMod.EffectType];
	if pMPTImpactHandler ~= nil then
		local bOk, tResult = pcall(pMPTImpactHandler, tMod, tSubject, sSubjectType);
		if bOk and tResult ~= nil then return tResult; end
		print("MPT_RMA: impact handler failed for "..tostring(tMod.EffectType).." -> "..tostring(tResult));
		return YieldTableNew();
	end

	if tMod.EffectType == "EFFECT_ATTACH_MODIFIER" then
		-- well, do nothing here but return tImpact, this will clear unknown flag
	
	-- single effect for changing plot yields
	elseif tMod.EffectType == "EFFECT_ADJUST_PLOT_YIELD" then
		if CheckForMismatchError(SubjectTypes.Plot) then return nil; end
		YieldTableSetMultipleYields(tImpact, tMod.Arguments.YieldType, tMod.Arguments.Amount);

	------------------------------ CITY ------------------------------------------------
	
	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_YIELD_CHANGE" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, tonumber(tMod.Arguments.Amount));

	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_ALL_YIELDS_CHANGE" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		local fYieldChange:number = tonumber(tMod.Arguments.Amount);
		for yield in GameInfo.Yields() do YieldTableSetYield(tImpact, yield.YieldType, fYieldChange); end
		
	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_YIELD_MODIFIER" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		-- 230522 #3 support for multi-args
		if string.find(tMod.Arguments.YieldType, ",") == nil then
			YieldTableSetYield(tImpact, tMod.Arguments.YieldType, YieldTableGetYield(tSubject.Yields, tMod.Arguments.YieldType) * tonumber(tMod.Arguments.Amount) / 100.0);
		else
			YieldTableSetMultipleYields(tImpact, tMod.Arguments.YieldType, tMod.Arguments.Amount);
			YieldTableMultiply(tImpact, 0.01);
			YieldTableMultiplyTable(tImpact, tSubject.Yields);
		end

	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_YIELD_PER_DISTRICT" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, tonumber(tMod.Arguments.Amount) * tSubject.NumDistricts);
		
	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_YIELD_PER_POPULATION" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, tonumber(tMod.Arguments.Amount) * tSubject.Population);

	-- 2020-06-04 Reyna taxation, seems like they forgot about city yield per pop modifiers :)
	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_GOLD_FROM_CITIZENS" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		tImpact.GOLD = tonumber(tMod.Arguments.Amount) * tSubject.Population;
		
	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_GROWTH" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		tImpact.FOOD = tSubject.FoodSurplus * tonumber(tMod.Arguments.Amount) / 100.0;

	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_IDENTITY_PER_TURN" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		tImpact.LOYALTY = tonumber(tMod.Arguments.Amount);
		
	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_AMENITIES_FROM_RELIGION" then
		if not( tSubject.SubjectType == SubjectTypes.City or tSubject.SubjectType == SubjectTypes.District ) then
			print("ERROR: ApplyEffectAndCalculateImpact mismatch for subject", sSubjectType); dshowtable(tMod); return nil;
		end
		tImpact.AMENITY = tonumber(tMod.Arguments.Amount);
		
	-- 230522 #10 Johannesburg
	elseif tMod.EffectType == "EFFECT_ADJUST_YIELD_BY_NUMBER_OF_RESOURCES" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, tSubject.NumResources * tonumber(tMod.Arguments.Amount));
		
	------------------------------ DISTRICT ------------------------------------------------
	
	elseif tMod.EffectType == "EFFECT_ADJUST_DISTRICT_YIELD_MODIFIER" then
		if CheckForMismatchError(SubjectTypes.District) then return nil; end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, YieldTableGetYield(tSubject.Yields, tMod.Arguments.YieldType) * tonumber(tMod.Arguments.Amount) / 100.0);
		-- 230521 #13 Economic Union
		for _,building in ipairs(tSubject.Buildings) do
			if tDistrictYieldCopies[building.BuildingType] ~= nil and building.isBuilt and not building.isPillaged then
				local oldYield: string = tMod.Arguments.YieldType;
				local newYield: string = tDistrictYieldCopies[building.BuildingType][oldYield];
				if newYield ~= nil then
					local tImpactAdd: table = YieldTableNew();
					YieldTableSetYield(tImpactAdd, newYield, YieldTableGetYield(tSubject.Yields, oldYield) * tonumber(tMod.Arguments.Amount) / 100.0);
					YieldTableAdd(tImpact, tImpactAdd);
				end
			end
		end

	elseif tMod.EffectType == "EFFECT_ADJUST_DISTRICT_YIELD_CHANGE" then
		if CheckForMismatchError("District") then return nil; end
        -- 2021-05-14 Public Transport fix
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, tonumber(tMod.Arguments.Amount));

	-- 2019-04-17 Added
	elseif tMod.EffectType == "EFFECT_ADJUST_DISTRICT_YIELD_BASED_ON_ADJACENCY_BONUS" then
		if CheckForMismatchError(SubjectTypes.District) then return nil; end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldTypeToGrant, YieldTableGetYield(tSubject.Yields, tMod.Arguments.YieldTypeToMirror));

	elseif tMod.EffectType == "EFFECT_FEATURE_ADJACENCY" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		-- complex effect, with 4 parameters
		-- DistrictType, FeatureType (must be adjacent), YieldType, Amount
		-- need to iterate through all built districts and check if there's an adjacent feature
		
		local function GetNumAdjacentFeatureType(iX:number, iY:number, sFeatureType:string)
			local adjacentPlot:table, eFeature:number, iNum:number = nil, 0, 0;
			for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
				adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
				if adjacentPlot then
					eFeature = adjacentPlot:GetFeatureType();
					if eFeature > -1 and GameInfo.Features[eFeature].FeatureType == sFeatureType then iNum = iNum + 1; end
				end
			end
			return iNum;
		end
		
		local iNum:number = 0;
		for _,district in ipairs(tSubject.Districts) do
			if district.isBuilt and district.DistrictType == tMod.Arguments.DistrictType then
				iNum = iNum + GetNumAdjacentFeatureType(district.Plot:GetX(), district.Plot:GetY(), tMod.Arguments.FeatureType);
			end
		end
		-- compatibility tweak for CIVITAS CS mod - remove if not needed any more
		-- they use YieldChange instead of Amount in this modifier
		if     tMod.Arguments.Amount      then YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount));
		elseif tMod.Arguments.YieldChange then YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.YieldChange));
		end
		
	elseif tMod.EffectType == "EFFECT_TERRAIN_ADJACENCY" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		-- complex effect, with 4 parameters
		-- DistrictType, TerrainType (must be adjacent), YieldType, Amount
		-- need to iterate through all built districts and check if there's an adjacent terrain
		
		local function GetNumAdjacentTerrainType(iX:number, iY:number, sTerrainType:string)
			local adjacentPlot:table, eTerrain:number, iNum:number = nil, 0, 0;
			for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
				adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
				if adjacentPlot then
					eTerrain = adjacentPlot:GetTerrainType();
					if eTerrain > -1 and GameInfo.Terrains[eTerrain].TerrainType == sTerrainType then iNum = iNum + 1; end
				end
			end
			return iNum;
		end
		
		local iNum:number = 0;
		for _,district in ipairs(tSubject.Districts) do
			if district.isBuilt and district.DistrictType == tMod.Arguments.DistrictType then
				iNum = iNum + GetNumAdjacentTerrainType(district.Plot:GetX(), district.Plot:GetY(), tMod.Arguments.TerrainType);
			end
		end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount));
		
	------------------------------ BUILDING ------------------------------------------------
	
	elseif tMod.EffectType == "EFFECT_ADJUST_BUILDING_YIELD_CHANGE" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		local sBuildingType:string = tMod.Arguments.BuildingType;
		local bApplied:boolean = false;
		for _,district in ipairs(tSubject.Districts) do
			if district.isBuilt then
				for _,building in ipairs(district.Buildings) do
					local buildingType:string = building.BuildingType;	
					if GameInfo.BuildingReplaces[ buildingType ] then buildingType = GameInfo.BuildingReplaces[ buildingType ].ReplacesBuildingType; end
					if buildingType == sBuildingType then
						YieldTableSetYield(tImpact, tMod.Arguments.YieldType, tonumber(tMod.Arguments.Amount)); bApplied = true; break;
					end
				end
				if bApplied then break; end
			end -- isBuilt
		end
		
	elseif tMod.EffectType == "EFFECT_ADJUST_BUILDING_YIELD_MODIFIER" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		local sBuildingType:string = tMod.Arguments.BuildingType;
		local bApplied:boolean = false;
		for _,district in ipairs(tSubject.Districts) do
			if district.isBuilt then
				for _,building in ipairs(district.Buildings) do
					local buildingType:string = building.BuildingType;	
					if GameInfo.BuildingReplaces[ buildingType ] then buildingType = GameInfo.BuildingReplaces[ buildingType ].ReplacesBuildingType; end
					if buildingType == sBuildingType then
						YieldTableSetYield(tImpact, tMod.Arguments.YieldType, YieldTableGetYield(building.Yields, tMod.Arguments.YieldType)*tonumber(tMod.Arguments.Amount)/100.0); bApplied = true; break;
					end
				end
				if bApplied then break; end
			end -- isBuilt
		end
		
	elseif tMod.EffectType == "EFFECT_ADJUST_BUILDING_YIELD_MODIFIERS_FOR_DISTRICT" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		-- must use 3 arguments actually, plus replacements
		for _,district in ipairs(tSubject.Districts) do
			local districtType:string = district.DistrictType;
			if GameInfo.DistrictReplaces[ districtType ] then districtType = GameInfo.DistrictReplaces[ districtType ].ReplacesDistrictType; end
			if districtType == tMod.Arguments.DistrictType then -- DISTRICT_THEATER, etc.
				if district.isBuilt then
					local fYieldChange:number = 0.0;
					for _,building in ipairs(district.Buildings) do
						fYieldChange = fYieldChange + YieldTableGetYield(building.Yields, tMod.Arguments.YieldType) * tonumber(tMod.Arguments.Amount) / 100.0;
					end
					YieldTableSetYield(tImpact, tMod.Arguments.YieldType, fYieldChange);
					break;
				end -- isBuilt
			end
		end
		
	------------------------------ PRODUCTION ------------------------------------------------
	
	-- special effects to boost production
	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_PRODUCTION_BUILDING" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		if tSubject.CurrentProductionType == "BUILDING" then tImpact.PRODUCTION = tonumber(tMod.Arguments.Amount); end
		
	-- special effects to boost production
	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_PRODUCTION_DISTRICT" then
		--if CheckForMismatchError(SubjectTypes.City) then return nil; end
        -- 2021-05-14 Industrial minors fix
        if tSubject.SubjectType == SubjectTypes.City then
            if tSubject.CurrentProductionType == "DISTRICT" then tImpact.PRODUCTION = tonumber(tMod.Arguments.Amount); end
        elseif tSubject.SubjectType == SubjectTypes.District then
            tImpact.PRODUCTION = tonumber(tMod.Arguments.Amount);
        else
            print("ERROR: ApplyEffectAndCalculateImpact mismatch for subject", sSubjectType); dshowtable(tMod); return true;
        end
		
	-- special effects to boost production
	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_PRODUCTION_UNIT" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		if tSubject.CurrentProductionType == "UNIT" then tImpact.PRODUCTION = tonumber(tMod.Arguments.Amount); end
	
	------------------------------  HOUSING AMENITY LOYALTY ------------------------------------------------
	
	elseif tMod.EffectType == "EFFECT_ADJUST_BUILDING_HOUSING" then
		if CheckForMismatchError("City") then return nil; end
		-- two versions, one with BuildingType provided and the other unconditional
		if tMod.Arguments.BuildingType then
			local buildingInfo:table = GameInfo.Buildings[ tMod.Arguments.BuildingType ];
			if buildingInfo == nil then return nil; end
			if tSubject.City:GetBuildings():HasBuilding( buildingInfo.Index ) then
				tImpact.HOUSING = tonumber(tMod.Arguments.Amount);
			end
		else
			tImpact.HOUSING = tonumber(tMod.Arguments.Amount);
		end

	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_HOUSING_PER_DISTRICT" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		tImpact.HOUSING = tSubject.NumDistricts;
		
	elseif tMod.EffectType == "EFFECT_ADJUST_POLICY_HOUSING" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		tImpact.HOUSING = tonumber(tMod.Arguments.Amount);
		
	elseif tMod.EffectType == "EFFECT_ADJUST_POLICY_AMENITY" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		tImpact.AMENITY = tonumber(tMod.Arguments.Amount);

	elseif tMod.EffectType == "EFFECT_GOVERNOR_ADJUST_IDENITITY_PER_TITLE" then -- WARNING! Firaxis made typo here in IDENITITY
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		tImpact.LOYALTY = tSubject.NumGovernorPromotions * tonumber(tMod.Arguments.Amount);
		
	------------------------------ UNIT ------------------------------------------------
	
	elseif tMod.EffectType == "EFFECT_ADJUST_UNIT_MAINTENANCE_DISCOUNT" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		local iAmount:number = tonumber(tMod.Arguments.Amount);
		local iDiscount:number = 0;
		for _,unit in ipairs(tSubject.Units) do
			if not unit.IsCivilian then iDiscount = iDiscount + math.min(iAmount, unit.Maintenance); end
		end
		tImpact.GOLD = iDiscount;

	elseif tMod.EffectType == "EFFECT_ADJUST_PLAYER_WMD_MAINTENANCE_MODIFIER" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		tImpact.GOLD = tSubject.WMDs.Maintenance * tonumber(tMod.Arguments.Amount) / 100.0;

	------------------------------ ENVOY ------------------------------------------------
	
	elseif tMod.EffectType == "EFFECT_ADJUST_PLAYER_YIELD_CHANGE_PER_USED_INFLUENCE_TOKEN" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, tSubject.NumInfluenceTokensGiven * tonumber(tMod.Arguments.Amount));

	elseif tMod.EffectType == "EFFECT_ADJUST_PLAYER_YIELD_CHANGE_PER_TRIBUTARY" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, tSubject.NumSuzerainCityStates * tonumber(tMod.Arguments.Amount));
		
	elseif tMod.EffectType == "EFFECT_ADJUST_PLAYER_YIELD_MODIFIER_PER_TRIBUTARY" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		--print("FUN ApplyEffectAndCalculateImpact(mod,eff,sub)(subject)",tMod.ModifierId,tMod.EffectType,sSubjectType,tSubject.SubjectType,tSubject.Name);
		--print("EFFECT_ADJUST_PLAYER_YIELD_MODIFIER_PER_TRIBUTARY", tMod.Arguments.YieldType, tMod.Arguments.Amount, "city-states:", tSubject.NumSuzerainCityStates);
		--dshowyields(tSubject.Yields);
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, YieldTableGetYield(tSubject.Yields, tMod.Arguments.YieldType) * tSubject.NumSuzerainCityStates * tonumber(tMod.Arguments.Amount) / 100.0);

	------------------------------ TRADE ROUTE MODIFIERS ------------------------------------------------
	
	elseif tMod.EffectType == "EFFECT_ADJUST_PLAYER_TRADE_ROUTE_YIELD_MODIFIER" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		local bOrigin:boolean = true; -- apply to Outgoing routes (i.e. we are Origin)
		if tonumber(tMod.Arguments.Destination) == 1 then bOrigin = false;
		elseif tonumber(tMod.Arguments.Origin) == 1 then bOrigin = true; -- just making sure
		else return nil; end -- bad args
		for cityname,city in pairs(tSubject.Cities) do
			local tRoutes:table = city.OutgoingRoutes; -- default
			if not bOrigin then tRoutes = city.IncomingRoutes; end
			for _,route in ipairs(tRoutes) do
				local tSingleRouteImpact:table = YieldTableNew();
				--dprint("route yields for", route.Name); dshowyields(route.Yields);
				YieldTableSetYield(tSingleRouteImpact, tMod.Arguments.YieldType, YieldTableGetYield(route.Yields, tMod.Arguments.YieldType));
				YieldTablePercent(tSingleRouteImpact, tonumber(tMod.Arguments.Amount));
				--dprint("single impact is"); dshowyields(tSingleRouteImpact);
				YieldTableAdd(tImpact, tSingleRouteImpact);
			end
		end
	
	-- 230522 #3 Tokugawa and Portugal
	-- I've checked during a game that incoming routes are not affected
	elseif tMod.EffectType == "EFFECT_ADJUST_PLAYER_INTERNATIONAL_TRADE_ROUTE_YIELD_MODIFIER" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		-- sum yields from all outgoing international routes
		for _,city in pairs(tSubject.Cities) do
			for _,route in ipairs(city.OutgoingRoutes) do
				if not route.IsDomestic then YieldTableAdd(tImpact, route.Yields); end
			end
		end
		-- multiply total yields by the multi-modifier
		local tModifier: table = YieldTableNew();
		YieldTableSetMultipleYields(tModifier, tMod.Arguments.YieldType, tMod.Arguments.Amount);
		YieldTableMultiply(tModifier, 0.01);
		YieldTableMultiplyTable(tImpact, tModifier);
	
	------------------------------ TRADE ROUTE YIELDS ------------------------------------------------

	elseif tMod.EffectType == "EFFECT_ADJUST_TRADE_ROUTE_YIELD" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil end
		local iNum:number = 0
		for cityname,city in pairs(tSubject.Cities) do iNum = iNum + city.NumRoutes end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount));

	elseif tMod.EffectType == "EFFECT_ADJUST_PLAYER_TRADE_ROUTE_ORIGIN_YIELD_FOR_ALLY_ROUTE" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil end
		local iNum:number = 0
		for cityname,city in pairs(tSubject.Cities) do
			for _,route in ipairs(city.OutgoingRoutes) do
				if route.IsDestinationPlayerAlly then iNum = iNum + 1 end
			end
		end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount))

	-- 230521 #1 Wisselbanken
	elseif tMod.EffectType == "EFFECT_ADJUST_PLAYER_TRADE_ROUTE_ORIGIN_YIELD_FOR_SUZERAIN_ROUTE" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil end
		local iNum:number = 0
		for cityname,city in pairs(tSubject.Cities) do
			for _,route in ipairs(city.OutgoingRoutes) do
				if route.IsDestinationSuzerained then iNum = iNum + 1 end
			end
		end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount))

	-- 230521 #1 Wisselbanken
	elseif tMod.EffectType == "EFFECT_ADJUST_PLAYER_TRADE_ROUTE_DESTINATION_YIELD_FOR_ALLY_ROUTE" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil end
		YieldTableClear(tImpact); -- no gains for us

	-- 230521 #1 Wisselbanken
	elseif tMod.EffectType == "EFFECT_ADJUST_PLAYER_TRADE_ROUTE_DESTINATION_YIELD_FOR_SUZERAIN_ROUTE" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil end
		YieldTableClear(tImpact); -- no gains for us

	elseif tMod.EffectType == "EFFECT_ADJUST_TRADE_ROUTE_YIELD_FOR_DOMESTIC" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		local iNum:number = 0;
		for cityname,city in pairs(tSubject.Cities) do iNum = iNum + city.NumRoutesDomestic end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount));

	elseif tMod.EffectType == "EFFECT_ADJUST_TRADE_ROUTE_YIELD_FOR_INTERNATIONAL" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		local iNum:number = 0;
		for cityname,city in pairs(tSubject.Cities) do iNum = iNum + city.NumRoutesInternational end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount));
		
	elseif tMod.EffectType == "EFFECT_ADJUST_TRADE_ROUTE_YIELD_PER_SPECIALTY_DISTRICT_FOR_DOMESTIC" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		local iNum:number = 0;
		for cityname,city in pairs(tSubject.Cities) do
			for _,route in ipairs(city.OutgoingRoutes) do
				if route.IsDomestic then iNum = iNum + route.NumSpecialtyDistricts; end
			end
		end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount))

	elseif tMod.EffectType == "EFFECT_ADJUST_TRADE_ROUTE_YIELD_PER_SPECIALTY_DISTRICT_FOR_INTERNATIONAL" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		local iNum:number = 0;
		for cityname,city in pairs(tSubject.Cities) do
			for _,route in ipairs(city.OutgoingRoutes) do
				if not route.IsDomestic then iNum = iNum + route.NumSpecialtyDistricts; end
			end
		end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount))

	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_TRADE_ROUTE_YIELD_PER_DESTINATION_STRATEGIC_RESOURCE_FOR_INTERNATIONAL" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		local iNum:number = 0;
		for _,route in ipairs(tSubject.OutgoingRoutes) do
			if not route.IsDomestic then iNum = iNum + route.NumImprovedResourcesStrategic; end
		end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount));
		
	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_TRADE_ROUTE_YIELD_PER_DESTINATION_LUXURY_RESOURCE_FOR_INTERNATIONAL" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		local iNum:number = 0
		for _,route in ipairs(tSubject.OutgoingRoutes) do
			if not route.IsDomestic then iNum = iNum + route.NumImprovedResourcesLuxury; end
		end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount));

	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_TRADE_ROUTE_YIELD_PER_DESTINATION_STRATEGIC_RESOURCE_FOR_DOMESTIC" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		local iNum:number = 0;
		for _,route in ipairs(tSubject.OutgoingRoutes) do
			if route.IsDomestic then iNum = iNum + route.NumImprovedResourcesStrategic; end
		end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount));
		
	-- 230521 #15 University of Sankore, Surplus Logistics, Zheng He effects
	-- This effect is bugged in the engine - it ignores Domestic argument and works only for International TRs.
	elseif tMod.EffectType == "EFFECT_ADJUST_TRADE_ROUTE_YIELD_FROM_OTHERS" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		local iNum:number = 0;
		for _,route in ipairs(tSubject.IncomingRoutes) do
			if not route.IsDomestic then iNum = iNum + 1; end
		end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount));
		
	-- 230521 #15 University of Sankore, Surplus Logistics, Zheng He effects
	-- This effect handles both domestic and international TRs, but we gain only from domestic ones.
	elseif tMod.EffectType == "EFFECT_ADJUST_TRADE_ROUTE_YIELD_TO_OTHERS" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		if tMod.Arguments.Domestic and tonumber(tMod.Arguments.Domestic) == 1 then
			local iNum:number = 0;
			for _,route in ipairs(tSubject.IncomingRoutes) do
				if route.IsDomestic then iNum = iNum + 1; end
			end
			YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.Amount));
		end

	------------------------------ GREAT WORK and TOURISM ------------------------------------------------
	
	-- 2019-04-17 Added
	elseif tMod.EffectType == "EFFECT_ADJUST_PLAYER_TOURISM" then
		if CheckForMismatchError(SubjectTypes.Player) then return nil; end
		tImpact.TOURISM = tSubject.Yields.TOURISM * tonumber(tMod.Arguments.Amount) / 100;

	elseif tMod.EffectType == "EFFECT_ADJUST_DISTRICT_TOURISM_CHANGE" then
		if not( tSubject.SubjectType == SubjectTypes.City or tSubject.SubjectType == SubjectTypes.District ) then
			print("ERROR: ApplyEffectAndCalculateImpact mismatch for subject", tSubject.SubjectType); dshowtable(tMod); return nil;
		end
		tImpact.TOURISM = tonumber(tMod.Arguments.Amount);
	
	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_TOURISM" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		-- this effect is quite complex, it supports 4 argument types: BoostsWonders (=1), GreatWorkObjectType (=GREATWORKOBJECT_PORTRAIT), ImprovementType (=IMPROVEMENT_BEACH_RESORT), Religious (=1), ScalingFactor (=200)
		-- the key ones are GreatWorkObjectType and ScalingFactor used for "scale tourism from specific GW by X%"
		if tMod.Arguments.GreatWorkObjectType and tMod.Arguments.ScalingFactor then
			-- we must actualy count Tourism not GWs because each GW can have a different value (even if now they all are the same for a given object type)
			local function GetTourismFromGreatWorks(sGreatWorkObjectType:string)
				local iTourism:number = 0;
				--	return a table indexed by buildingType, with a table of GameInfo.GreatWorks in that building
				for buildingType,greatWorks in pairs(tSubject.GreatWorks) do
					for _,greatWork in ipairs(greatWorks) do -- this should give GameInfo.GreatWorks object
						if greatWork.GreatWorkObjectType == sGreatWorkObjectType then iTourism = iTourism + greatWork.Tourism; end
					end
				end
				--dprint("Tourism from GWs (type) in (city) is (num)", sGreatWorkObjectType, tSubject.Name, iTourism);
				return iTourism;
			end
			-- impact is only difference, hence -100, and for ScalingFactor<100 it is actualy a negative impact!
			tImpact.TOURISM = GetTourismFromGreatWorks(tMod.Arguments.GreatWorkObjectType) * (tonumber(tMod.Arguments.ScalingFactor)-100) / 100.0;
			-- TODO: don't know how stacking works - this assumes it additive (so, each modifier is applied to base yield)
			-- TODO: nothing about theming
		else
			-- other arguments
			-- ImprovementType is used by CRISTOREDENTOR_BEACHTOURISM (TODO: applied to all Beach Resorts)and TRAIT_WONDER_DOUBLETOURISM
			-- BoostsWonders is used by COMMEMORATION_TOURISM_GA_WONDERS
			-- Religious is used by STBASILS_ADDRELIGIOUSTOURISM (City level)
		end

	elseif tMod.EffectType == "EFFECT_ADJUST_CITY_GREATWORK_YIELD" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		local iNum:number = 0;
		if tMod.Arguments.YieldChange then
			-- version that adds flat yields
			for buildingType,greatWorks in pairs(tSubject.GreatWorks) do
				for _,greatWork in ipairs(greatWorks) do -- this should give GameInfo.GreatWorks object
					if greatWork.GreatWorkObjectType == tMod.Arguments.GreatWorkObjectType then iNum = iNum + 1; end
				end
			end
			YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * tonumber(tMod.Arguments.YieldChange));
		elseif tMod.Arguments.ScalingFactor then
			-- version that adds percentage on base yield
			for buildingType,greatWorks in pairs(tSubject.GreatWorks) do
				for _,greatWork in ipairs(greatWorks) do -- this should give GameInfo.GreatWorks object
					if greatWork.GreatWorkObjectType == tMod.Arguments.GreatWorkObjectType then
						-- get yield for this specific GW from external table
						for row in GameInfo.GreatWork_YieldChanges() do
							if row.GreatWorkType == greatWork.GreatWorkType and row.YieldType == tMod.Arguments.YieldType then iNum = iNum + row.YieldChange; end
						end
					end
				end
			end
			YieldTableSetYield(tImpact, tMod.Arguments.YieldType, iNum * (tonumber(tMod.Arguments.ScalingFactor)-100) / 100.0);
		end
	
	------------------------------  WONDER ------------------------------------------------
	
	elseif tMod.EffectType == "EFFECT_ADJUST_WONDER_YIELD_CHANGE" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, table.count(tSubject.Wonders) * tonumber(tMod.Arguments.Amount));
	
	------------------------------  RELIGION ------------------------------------------------
	
	elseif tMod.EffectType == "EFFECT_ADJUST_FOLLOWER_YIELD_MODIFIER" then
		if CheckForMismatchError(SubjectTypes.City) then return nil; end
		YieldTableSetYield(tImpact, tMod.Arguments.YieldType, YieldTableGetYield(tSubject.Yields, tMod.Arguments.YieldType) * tSubject.MajorityReligionFollowers * tonumber(tMod.Arguments.Amount) / 100.0);
	
	else
		-- do nothing here... probably will never implement all possible types
		return nil;
	end
	-- done!
	--dprint("  Impact for subject (type,name)",tSubject.SubjectType,tSubject.Name); dshowyields(tSubject.Yields); dshowyields(tImpact); -- debug
	return tImpact;
end


------------------------------------------------------------------------------
-- Main entry point for calculating effects for entire objects
-- returns effect:string, yields:table, tooltip:string
------------------------------------------------------------------------------
local TOOLTIP_SEP:string = "-------------------";

-- Tables with modifiers
local tModifiersTables:table = {
	["Belief"] = "BeliefModifiers", -- BeliefType
	["Building"] = "BuildingModifiers", -- BuildingType
	["Civic"] = "CivicModifiers", -- CivicType
	["District"] = "DistrictModifiers", -- DistrictType
	["Game"] = "GameModifiers", -- not shown in Pedia?
	--["GoodyHut"] = "GoodyHutSubTypes",
	["Government"] = "GovernmentModifiers", -- GovernmentType
	-- ["GreatPerson"] = GreatPersonIndividualBirthModifiers -- GreatPersonIndividualType
	["GreatPersonIndividual"] = "GreatPersonIndividualActionModifiers", -- GreatPersonIndividualType + AttachmentTargetType
	["Improvement"] = "ImprovementModifiers", -- ImprovementType
	-- ["Leader"] = "LeaderTraits" => "TraitModifiers" -- TraitType
	["Policy"] = "PolicyModifiers", -- PolicyType
	["Project"] = "ProjectCompletionModifiers", -- ProjectType
	["Technology"] = "TechnologyModifiers", -- TechnologyType
	["Trait"] = "TraitModifiers", -- TraitType
	["UnitAbility"] = "UnitAbilityModifiers", -- UnitAbilityType  via TypeTags, i.e. Unit -> Class(Tag) -> TypeTags
	["UnitPromotion"] = "UnitPromotionModifiers", -- UnitPromotionType
};

if bIsRiseAndFall then
	tModifiersTables["Alliance"] = "AllianceEffects"; -- no Pedia page for that!
	tModifiersTables["Commemoration"] = "CommemorationModifiers"; -- no Pedia page for that!
	tModifiersTables["Governor"] = "GovernorModifiers"; -- currently empty
	tModifiersTables["GovernorPromotion"] = "GovernorPromotionModifiers"; -- GovernorPromotionType
end

if bIsGatheringStorm then
	tModifiersTables["Resolution"] = "ResolutionEffects"; -- no Pedia page for that!
end

-- Tables with objects
local tObjectsTables:table = {
	["Belief"] = "Beliefs", -- BeliefType
	["Building"] = "Buildings", -- BuildingType
	["Civic"] = "Civics", -- CivicType
	["District"] = "Districts", -- DistrictType
	-- GameModifiers -- not shown in Pedia?
	["Government"] = "Governments", -- GovernmentType
	-- ["GreatPerson"] = GreatPersonIndividualBirthModifiers -- GreatPersonIndividualType
	["GreatPersonIndividual"] = "GreatPersonIndividuals", -- GreatPersonIndividualType + AttachmentTargetType
	["Improvement"] = "Improvements", -- ImprovementType
	-- ["Leader"] = "LeaderTraits" => "TraitModifiers" -- TraitType
	["Policy"] = "Policies", -- PolicyType
	["Project"] = "Projects", -- ProjectType
	["Technology"] = "Technologies", -- TechnologyType
	["Trait"] = "Traits", -- TraitType
	["UnitAbility"] = "UnitAbilities", -- UnitAbilityType  via TypeTags, i.e. Unit -> Class(Tag) -> TypeTags
	["UnitPromotion"] = "UnitPromotions", -- UnitPromotionType
}

if bIsRiseAndFall then
	tObjectsTables["Alliance"] = "Alliances"; -- no Pedia page for that!
	tObjectsTables["Commemoration"] = "CommemorationTypes"; -- no Pedia page for that!
	tObjectsTables["Governor"] = "Governors"; -- currently empty
	tObjectsTables["GovernorPromotion"] = "GovernorPromotions"; -- GovernorPromotionType
end

if bIsGatheringStorm then
	tObjectsTables["Resolution"] = "Resolutions"; -- no Pedia page for that!
	--tObjectsTables["Discussion"] = "Discussions"; -- no Pedia page for that!
end


-- for policies:  ("Policy",   policyType,   Game.GetLocalPlayer(), nil)
-- for governors: ("Governor", governorType, Game.GetLocalPlayer(), iCityID)
-- for city states: the 5th parameter is used to select proper modifiers, it is the ONLY place where it is used
function CalculateModifierEffect(sObject:string, sObjectType:string, ePlayerID:number, iCityID:number, sInfluence:string)
	--dprint("FUN CalculateModifierEffect(obj,obtype,pid,cid,infl)",sObject,sObjectType,ePlayerID,iCityID,sInfluence);
	local sModifiersTable:string = tModifiersTables[ sObject ];
	-- check if there are modifiers at all
	if sModifiersTable == nil then return "(error)", nil, "No modifiers' table for object "..sObject; end
	local sObjectTypeField:string = sObject.."Type"; -- simple version for starters
	
	-- iterate and find them
	--dprint("...calculating modifiers (obj,table,field)", sObject, sObjectType, ePlayerID, iCityID);
	--TimerStart(); -- debug
	local tTotalImpact:table = YieldTableNew();
	local tToolTip:table = {}; -- tooltip
	local bUnknownEffect:boolean = false;
	local tMPTLines:table = {};	-- [MPT 条目21优化] 扩展类型的文本行（卡面串与 tooltip 共用）
	local sSubjectFilter:string = ( sInfluence and "PLAYER_HAS_"..sInfluence.."_INFLUENCE" or nil );
	-- [MPT 条目21优化] 全表扫描 → 懒索引（见 MPT_GetObjectModifierIds；留痕：原循环
	-- for mod in GameInfo[sModifiersTable]() do ... 移入索引器，含 ModifierId/ModifierID 兼容）
	local tModIds:table = MPT_GetObjectModifierIds(sModifiersTable, sObjectTypeField, sObjectType);
	-- [MPT 条目21修复] 泛型 for 循环变量不带类型标注——原版 UI 无泛型 for 标注先例
	-- （数值 for 的 for i:number= 有先例，泛型未验证），不冒险
	-- for _,sModifierId:string in ipairs(tModIds) do
	for _,sModifierId in ipairs(tModIds) do
		--if mod[sObjectTypeField] == sObjectType then
			-- stupid Firaxis, some fields are named ModifierId and some ModifierID (sic!)
			-- local sModifierId:string = mod.ModifierId;
			-- if not sModifierId then sModifierId = mod.ModifierID; end -- fix for BeliefModifiers, GoodyHutSubTypes, ImprovementModifiers
			local sText:string, pYields:table, sAttachedId:string, bUnknown:boolean, tMod:table, tSubjects:table, sSubjectType:string = DecodeModifier(sModifierId, ePlayerID, iCityID);
			-- this the place to check for extra conditions
			if sSubjectFilter == nil or tMod.SubjectReqSetId == sSubjectFilter then
				table.insert(tToolTip, sText);
				-- [MPT 条目21优化] 扩展类型文本行（direct；ePlayerID 供动态计算类实时求值）
				local sMPTLine:string = MPT_GetModifierLine(tMod, ePlayerID);
				if sMPTLine then table.insert(tMPTLines, sMPTLine); end
				if sAttachedId then
					table.insert(tToolTip, "Attached modifier");
					-- in some cases the subjects will be passed down to be processed again
					-- when (a) collection was processed correctly (b) there's more than 1 subject
					if tSubjects ~= nil then
						sText, pYields, sAttachedId, bUnknown, tMod = DecodeModifier(sAttachedId, ePlayerID, iCityID, tSubjects, sSubjectType);
					else
						sText, pYields, sAttachedId, bUnknown, tMod = DecodeModifier(sAttachedId, ePlayerID, iCityID);
					end
					table.insert(tToolTip, sText);
					-- [MPT 条目21优化] 扩展类型文本行（attached，tMod 已是子 modifier）
					local sMPTLineAttached:string = MPT_GetModifierLine(tMod, ePlayerID);
					if sMPTLineAttached then table.insert(tMPTLines, sMPTLineAttached); end
					-- 2019-04-14 Reset yields to 0 if there are no valid subjects that qualify for attaching
					if tSubjects ~= nil and #tSubjects == 0 then
						pYields = nil;
						table.insert(tToolTip, "Attached modifier has NO valid subjects");
					end
				end
				if pYields then YieldTableAdd(tTotalImpact, pYields); end
				bUnknownEffect = bUnknownEffect or bUnknown;
				table.insert(tToolTip, TOOLTIP_SEP);
			end -- extra conditions
		--end -- [MPT] 类型过滤移入索引器
	end
	if #tToolTip == 0 then
		table.insert(tToolTip, "No modifiers for this object.");
	end
	
	-- generate total impact string
	--local sTotalImpact:string = "";
	local bImpact:boolean = false;
	--for yield,value in pairs(tTotalImpact) do
		--if value ~= 0 then sTotalImpact = sTotalImpact..(sTotalImpact=="" and "" or " ")..GetYieldString("YIELD_"..yield, value); end
	--end
	--for	_,yield in ipairs(YieldTypesOrder) do
		--if tTotalImpact[yield] ~= 0 then sTotalImpact = sTotalImpact..(sTotalImpact=="" and "" or " ")..GetYieldString("YIELD_"..yield, tTotalImpact[yield]); end
	--end
	local sTotalImpact:string = YieldTableGetInfo(tTotalImpact);
	-- [MPT 条目21优化] 扩展类型的文本行拼入卡面串（[NEWLINE] 分行，卡面 Effect 为
	-- auto 高多行 Label 自然分行显示；tooltip 的 tToolTip 已含同等信息）
	if #tMPTLines > 0 then
		local sMPT:string = table.concat(tMPTLines, "[NEWLINE]");
		sTotalImpact = (sTotalImpact ~= "" and sTotalImpact.."[NEWLINE]" or "")..sMPT;
	end
	if sTotalImpact == "" then
		--sTotalImpact = "-"; -- just to show that there's nothing; empty string could be misleading
		table.insert(tToolTip, "Yields not affected.");
	end
	if bUnknownEffect then
		--sTotalImpact = sTotalImpact.." [ICON_Exclamation]";
		table.insert(tToolTip, "[COLOR_Red]Unknown effect[ENDCOLOR] was not processed.");
	end
	
	--TimerTick("All modifiers for object "..sObject..":"..sObjectType); -- debug
	-- done!
	--for _,st in ipairs(tToolTip) do print(sObjectType, string.len(st), st); end -- debug
	return sTotalImpact, tTotalImpact, table.concat(tToolTip, "[NEWLINE]"), bUnknownEffect;
end

------------------------------------------------------------------------------
-- RefreshBaseData should be called when the window is open or after the data has changed
-- Probably could use a Lua event for that (TODO)
-- TODO: what about other players? probably will need multiple tables of cities, but let's start with LocalPlayer
function RefreshBaseData(ePlayerID:number)
	--dprint("FUN RefreshBaseData(player)",ePlayerID)
	local playerID:number = ePlayerID;
	if playerID == nil then playerID = Game.GetLocalPlayer(); end
	local pPlayer	:table = Players[playerID];
	local pCulture	:table = pPlayer:GetCulture();
	local pTreasury	:table = pPlayer:GetTreasury();
	local pReligion	:table = pPlayer:GetReligion();
	local pScience	:table = pPlayer:GetTechs();
	local pResources:table = pPlayer:GetResources();
	local pCities	:table = pPlayer:GetCities();

	tCities = {}; -- clear old values
	-- [MPT 条目21用户裁决] 基础数据重建时同步失效 MPT 行缓存与资源提取缓存（动态计算类的
	-- 数值随城市/地块变化，须跨回合重算）
	MPT_LineCache = {};
	MPT_ExtractCache = {};
	
	for _,pCity in pCities:Members() do	
		local cityName:string = pCity:GetName();

		-- Big calls, obtain city data and add report specific fields to it.
		local data:table = GetCityData( pCity );
		-- Add more data (not in CitySupport)
		--data.Resources			= GetCityResourceData( pCity );
		--data.WorkedTileYields, data.NumWorkedTiles = GetWorkedTileYieldData( pCity, pCulture );
		tCities[ cityName ] = data;
		--dprint("**** CITY DATA ****", cityName); -- debug
		--dshowrectable(data); -- debug
	end
	
	GetPlayerData(); -- for COLLECTION_OWNER as Player
	
	GetPlotsData(); -- for COLLECTION_PLAYER_PLOT_YIELDS
	
	bBaseDataDirty = false; -- clean :)
end

-- modifiers helper - could be time-consuming
-- looking for an object that has a specified modifier attached
function GetObjectNameForModifier(sModifierId:string)
	--print("looking for", sModifierId);
	for object,modtable in pairs(tModifiersTables) do
		--print("checking", object, modtable)
		for row in GameInfo[ modtable ]() do
			if row.ModifierId == sModifierId or row.ModifierID == sModifierId then
				--print("found", sModifierId, " for ", row[object.."Type"])
				if object == "Game" then return "[COLOR_Grey]Game[ENDCOLOR]"; end
				local objectInfo:table = GameInfo[ tObjectsTables[object] ][ row[object.."Type"] ];
				--print("   ...", object, objectInfo[object.."Type"], objectInfo.Name)
				if object == "Commemoration" then return Locale.Lookup(objectInfo.CategoryDescription); end
				if objectInfo.Name == nil then return "[COLOR_Grey]"..object.."[ENDCOLOR]"; end -- 2019-08-30 Some traits have no Name
				local sLocName:string = Locale.Lookup(objectInfo.Name);
				if sLocName == objectInfo.Name then return "[COLOR_Grey]"..object.."[ENDCOLOR]"; end-- LOC_ not defined
				return sLocName;
			end
		end
	end
	-- exception for 2nd table for GP modifiers, it contains multiple copies of modifiers, so there's no way to know from which GP the modifier comes anyway
	if string.find(sModifierId, "GREATPERSON") then return "[COLOR_Grey]"..Locale.Lookup("LOC_SLOT_GREAT_PERSON_NAME").."[ENDCOLOR]"; end
	-- check for GoodyHuts, modifiers for them are stored in a different manner
	for row in GameInfo.GoodyHutSubTypes() do 
		if row.ModifierID == sModifierId then return Locale.Lookup( GameInfo.Improvements["IMPROVEMENT_GOODY_HUT"].Name ); end
	end
	-- last try - this could an attached modifer via EFFECT_ATTACH_MODIFIER
	for row in GameInfo.ModifierArguments() do
		if row.Name == "ModifierId" and row.Value == sModifierId then return GetObjectNameForModifier(row.ModifierId); end -- recursive for main modifier
	end
	print("ERROR: GetObjectNameForModifier cannot find object for modifier", sModifierId);
	return "[COLOR_Red]unknown[ENDCOLOR]";
end


------------------------------------------------------------------------------
function Initialize()
	-- exposed members
	RMA.FetchAndCacheData = FetchAndCacheData;
	RMA.DecodeModifier  = DecodeModifier;
	RMA.RefreshBaseData = RefreshBaseData;
	RMA.CalculateModifierEffect = CalculateModifierEffect;
	RMA.GetObjectNameForModifier = GetObjectNameForModifier;
	RMA.YieldTableGetInfo = YieldTableGetInfo;
	
	-- add events that require the base data to be refreshed
	-- only set the dirty flag, the actual data will be refreshed when necessary
	Events.GovernmentChanged.Add(        function() bBaseDataDirty = true end );
	Events.GovernmentPolicyChanged.Add(  function() bBaseDataDirty = true end );
	Events.GovernmentPolicyObsoleted.Add(function() bBaseDataDirty = true end );
	Events.CityAddedToMap.Add(           function() bBaseDataDirty = true end );
	Events.CityFocusChanged.Add(         function() bBaseDataDirty = true end );
	Events.CityPopulationChanged.Add( 	 function() bBaseDataDirty = true end );
	Events.CityProductionChanged.Add(    function() bBaseDataDirty = true end );
	Events.CityProductionCompleted.Add(  function() bBaseDataDirty = true end );
	Events.CityWorkerChanged.Add(        function() bBaseDataDirty = true end );
	Events.DistrictDamageChanged.Add(    function() bBaseDataDirty = true end );
	Events.ImprovementChanged.Add(       function() bBaseDataDirty = true end );
	Events.PlayerResourceChanged.Add(    function() bBaseDataDirty = true end );
	Events.ResearchCompleted.Add(        function() bBaseDataDirty = true end );
	Events.CivicCompleted.Add(           function() bBaseDataDirty = true end );
	Events.TechBoostTriggered.Add( 		 function() bBaseDataDirty = true end );
	Events.CivicBoostTriggered.Add( 	 function() bBaseDataDirty = true end );
	Events.FaithChanged.Add(             function() bBaseDataDirty = true end );
	Events.TreasuryChanged.Add(          function() bBaseDataDirty = true end );
	Events.TradeRouteAddedToMap.Add(     function() bBaseDataDirty = true end );
	Events.TradeRouteRemovedFromMap.Add( function() bBaseDataDirty = true end );
	Events.PlotYieldChanged.Add(         function() bBaseDataDirty = true end );
    Events.GovernorAssigned.Add(         function() bBaseDataDirty = true end );
    Events.GovernorPromoted.Add(         function() bBaseDataDirty = true end );
	Events.PantheonFounded.Add(          function() bBaseDataDirty = true end );
	Events.ReligionFounded.Add(          function() bBaseDataDirty = true end );
	Events.CityReligionChanged.Add( 	 function() bBaseDataDirty = true end );
	Events.UnitAddedToMap.Add(           function() bBaseDataDirty = true end );
	Events.UnitRemovedFromMap.Add(       function() bBaseDataDirty = true end );
	Events.UnitMoveComplete.Add(         function() bBaseDataDirty = true end );
	Events.UnitGreatPersonActivated.Add( function() bBaseDataDirty = true end );
	Events.DiplomacyMeet.Add(            function() bBaseDataDirty = true end );
	Events.DiplomacyRelationshipChanged.Add( function() bBaseDataDirty = true end );
	Events.InfluenceGiven.Add(           function() bBaseDataDirty = true end );
	Events.ImprovementAddedToMap.Add( 	 function() bBaseDataDirty = true end );
	-- Rise & Fall
	if bIsRiseAndFall then
		Events.GovernorAssigned.Add(	 function() bBaseDataDirty = true end );
		Events.GovernorPromoted.Add(	 function() bBaseDataDirty = true end );
		Events.EmergencyStarted.Add( 	 function() bBaseDataDirty = true end );
		Events.EmergencyCompleted.Add( 	 function() bBaseDataDirty = true end );
	end
	
	-- PERFORMANCE TESTING
	--[[
	-- Reading all requirements - 90 ms -> 20 ms
	Timer1Reset(); Timer1Start();
	for req in GameInfo.Requirements() do
		_ = FetchAndCacheDataReq(req.RequirementId);
	end
	Timer1Tick(); Timer1Stop("requirements");
	-- Decoding all requirements - insignificant, 3 ms -> 2 ms
	-- Reading all requirement sets - 140 ms -> 15 ms
	Timer1Reset(); Timer1Start();
	for req in GameInfo.RequirementSets() do
		_ = FetchAndCacheDataReqSet(req.RequirementSetId);
	end
	Timer1Tick(); Timer1Stop("requirement sets");
	-- Reading all modifiers -  2200 ms -> 270 ms
	Timer1Reset(); Timer1Start();
	for mod in GameInfo.Modifiers() do
		_ = FetchAndCacheData(mod.ModifierId);
	end
	Timer1Tick(); Timer1Stop("modifiers");
	--]]
end
Initialize();

print("OK loaded Real Modifier Analysis.lua from Better Report Screen");
