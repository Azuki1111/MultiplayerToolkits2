-- ===========================================================================
-- 条目18：城市横幅刷新（PCF）——移植自联机工具箱 1.67（工坊 3693899014 PCF 目录，
--   pk-civ6 皮皮凯「城市横幅刷新修复」）
-- 修什么：原版 CityBannerManager 不订阅 CityWorkerChanged（市民变动后横幅产出滞后）；
--   城界扩张/人口增长/地块产出变化（改良建成/被劫/修复等）后市民不自动重排到最优地块。
-- 做什么：
--   ①CityWorkerChanged → 延时去抖后单城横幅刷新（原版全局 RefreshBanner = UpdateStats
--     + UpdateRangeStrike + UpdateName）
--   ②CityTileOwnershipChanged / CityPopulationChanged / PlotYieldChanged → 延时去抖后
--     向城市下发 MANAGE 公民指令（原版点击市民同款 CityCommandTypes.MANAGE 命令），
--     促使引擎把市民重新分配到最优地块（横幅随后经①自动跟进）
-- 注入机制：文件名前缀 CityBannerManager_ 被原版 CityBannerManager.lua 末尾通配
--   include("CityBannerManager_", true) 拉入同上下文（官方预留钩子，同条目7
--   EndGameMenu 机制），可直接调用上下文全局 RefreshBanner/GetCityBanner 等；
--   modinfo 仅 ImportFiles 导入 VFS，无需 LuaContext 注册
-- 相对 1.67（CityBannerManager_PCF.lua + 皮皮凯 LuaTimer）的优化：
--   1. 单订阅调度器：1.67 每挂一个定时器就 Add/Remove 一条 GameCoreEventPublishComplete
--      订阅（事件风暴下反复订阅/退订）；本文件全局仅一条订阅驱动任务表，O(1) 增删
--   2. 真实时间基：1.67 以「发布周期计数」当地秒——事件批节奏不匀，2 周期可能是
--      0.2s 也可能是 10s，延时语义失真；改用单调时钟 UI.GetElapsedTime（原版
--      PlotToolTip 5 秒超时同款，缺 API 时兜底 os.clock），2 秒即真 2 秒
--   3. 零全局污染：1.67 的 AddTimer/RemoveTimer/RemoveAllTimer/CallbackDict 等 6 个
--      全局与同上下文其他 CityBannerManager_* 补丁（1.67 CSB/CSA）有名字冲突风险；
--      本文件全部 local（通配注入的各文件共享全局表、chunk 局部彼此隔离）
--   4. 去重键规范化：1.67 PlotYieldChanged 路径用裸 cityID 当键、其余路径用前缀串，
--      同城多类型任务可能互吞；统一 MPT_Refresh_/MPT_Rearrange_ 前缀命名空间
--   5. 重排指令后兜底挂一次横幅刷新（1.67 仅依赖重排引发 CityWorkerChanged 才刷新，
--      引擎未发布该事件时横幅仍滞留旧值；与①同键去抖不增调用）
--   6. 防御补全：重排前城市 nil 检查（延时期间被毁/易主）、PlotYieldChanged 地块
--      nil 检查、观察者（Game.GetLocalPlayer()=-1）天然跳过（条目7 观战场景）
-- 保留 1.67 语义：本地回合开始 1 秒冷却（官方回合切换整批刷新，此时动作纯属浪费）、
--   本地回合结束清空未到期任务（跨回合执行已无意义）
-- 条目18调优：去抖延时 1.67 的 4/2/2 周期计数过慢——横幅刷新 0.1 秒近实时、重排指令
--   统一 0.5 秒合并窗口（MPT_REFRESH_DELAY/MPT_REARRANGE_DELAY 常量，可调）
-- 调试：关键路径留 print（MPT_Banner: 前缀），实测确认后可删
-- 与 1.67 同装注意：两个补丁文件都会被通配 include 拉入（各自去重、重复执行无害），
--   建议二选一启用
-- 注册：ImportFiles(1010) 通配注入不占 LuaContext（1.67 同款机制）
-- ===========================================================================

-- ===========================================================================
-- MPT 调度器（优化1/2/4：单订阅 + 真实时间 + 键覆盖去抖）
-- ===========================================================================

-- 单调时钟：优先 UI.GetElapsedTime（原版 PlotToolTip 同款），缺 API 兜底 os.clock。
-- 条目18修复：cfunction 不能赋给 ifunction 标注变量（引擎类型检查报
--   Type check failed: expected 'ifunction', but got 'cfunction' → 整个文件 chunk
--   中止、通配 include 失败、全部功能未加载，Lua.log 43 行实证）——包一层 Lua 闭包
--   即为 ifunction，兼做调用时 API 探测
local MPT_ClockName : string = (UI.GetElapsedTime ~= nil) and "UI.GetElapsedTime" or "os.clock";
local MPT_GetTime : ifunction = function()
	if UI.GetElapsedTime ~= nil then
		return UI.GetElapsedTime();
	end
	return os.clock();
end;

-- 到期任务表：[任务键] = { Deadline=到期限（秒）, Func=回调, Values=参数表, Unpack=拆包 }
local MPT_PendingTasks : table = {};

-- 去抖延时（条目18调优：1.67 的 4/2/2 发布周期计数在真实时钟下过慢——横幅刷新 0.1 秒
--   近实时（实际执行时刻=0.1 秒后首个事件批结束 tick，事件到达后本就紧跟批结束，体感即近
--   实时）；重排指令统一 0.5 秒合并窗口，防同批边界/产出事件多次下发 MANAGE）
local MPT_REFRESH_DELAY		: number = 0.1;
local MPT_REARRANGE_DELAY	: number = 0.5;

-- ============================================================================
-- MPT_ScheduleTask(fDelaySeconds, callbackFunc, taskID, Values, Needunpack)：
--   fDelaySeconds 秒后执行一次 callbackFunc；同 taskID 重挂自动覆盖旧任务（去抖合并，
--   语义同 1.67 AddTimer 的同名 FuncID 移除重建）。Values + Needunpack=true 时拆包传参。
-- 用法：MPT_ScheduleTask(0.1, RefreshBanner, "MPT_Refresh_12", {playerID, cityID}, true)
-- ============================================================================
local function MPT_ScheduleTask(fDelaySeconds : number, callbackFunc : ifunction, taskID : string, Values : table, Needunpack : boolean)
	MPT_PendingTasks[taskID] = {
		Deadline = MPT_GetTime() + fDelaySeconds;
		Func	 = callbackFunc;
		Values	 = Values;
		Unpack	 = Needunpack;
	};
	print("MPT_Banner: schedule " .. taskID .. " +" .. fDelaySeconds .. "s");	-- 条目18调试 print
end

-- 调度器 tick（本文件唯一一条 GameCoreEventPublishComplete 订阅——优化1）：
--   每次游戏事件批结束后扫描到期任务；先出表再执行（执行中重挂同键不被误清）
local function MPT_OnSchedulerTick()
	local fNow : number = MPT_GetTime();
	for taskID, task in pairs(MPT_PendingTasks) do
		if fNow >= task.Deadline then
			MPT_PendingTasks[taskID] = nil;
			print("MPT_Banner: run " .. taskID);	-- 条目18调试 print
			if task.Unpack and task.Values ~= nil then
				task.Func(unpack(task.Values));
			else
				task.Func(task.Values);
			end
		end
	end
end
Events.GameCoreEventPublishComplete.Add(MPT_OnSchedulerTick);

-- 本地回合开始 1 秒冷却：回合切换官方整批刷新，期间触发的重排/刷新纯属浪费（1.67 同语义）
local MPT_CoolDownUntil : number = 0;
Events.LocalPlayerTurnBegin.Add(function()
	MPT_CoolDownUntil = MPT_GetTime() + 1;
	print("MPT_Banner: LocalPlayerTurnBegin, cooldown until " .. MPT_CoolDownUntil);	-- 条目18调试 print
end);
-- 本地回合结束清空未到期任务（跨回合执行已无意义；1.67 RemoveAllTimer 同语义）
Events.TurnEnd.Add(function()
	MPT_PendingTasks = {};
	print("MPT_Banner: TurnEnd, pending tasks cleared");	-- 条目18调试 print
end);

-- ===========================================================================
-- 功能：市民自动重排 + 横幅刷新
-- ===========================================================================

-- ============================================================================
-- MPT_RequestCitizenRearrange(playerID, cityID)：向城市下发 MANAGE 公民指令
--   （原版 PlotInfo 点击市民同款命令构建，坐标取城市中心——1.67 OnTPT_ClickCitizen
--   原样机制），促使引擎重新分配市民到最优地块。
-- 用法：作为 MPT_ScheduleTask 延时回调（Values={playerID, cityID} 拆包传入）
-- ============================================================================
local function MPT_RequestCitizenRearrange(playerID : number, cityID : number)
	local pSelectedCity = CityManager.GetCity(playerID, cityID);
	if pSelectedCity == nil then return; end	-- 优化6：延时期间城市可能已被毁/易主
	local tParameters	:table = {};
	tParameters[CityCommandTypes.PARAM_MANAGE_CITIZEN] = UI.GetInterfaceModeParameter(CityCommandTypes.PARAM_MANAGE_CITIZEN);
	tParameters[CityCommandTypes.PARAM_X] = pSelectedCity:GetX();
	tParameters[CityCommandTypes.PARAM_Y] = pSelectedCity:GetY();
	CityManager.RequestCommand( pSelectedCity, CityCommandTypes.MANAGE, tParameters );
	print("MPT_Banner: MANAGE command -> city " .. cityID);	-- 条目18调试 print
	-- 优化5：重排后兜底横幅刷新（引擎未发 CityWorkerChanged 时 1.67 会滞留旧值；
	--   与①路径同键去抖，不产生重复刷新）
	MPT_ScheduleTask(MPT_REFRESH_DELAY, RefreshBanner, "MPT_Refresh_" .. tostring(cityID), {playerID, cityID}, true);
end

-- ① 市民变动 → 横幅刷新（0.1 秒去抖近实时；原版 CityBannerManager 不订阅此事件，产出滞后元凶）
local function MPT_OnCityWorkerChanged(playerID : number, cityID : number)
	if playerID == Game.GetLocalPlayer() then
		print("MPT_Banner: CityWorkerChanged city=" .. cityID .. " cooldownActive=" .. tostring(MPT_GetTime() <= MPT_CoolDownUntil));	-- 条目18调试 print
	end
	if playerID == Game.GetLocalPlayer() and MPT_GetTime() > MPT_CoolDownUntil then
		MPT_ScheduleTask(MPT_REFRESH_DELAY, RefreshBanner, "MPT_Refresh_" .. tostring(cityID), {playerID, cityID}, true);
	end
end
Events.CityWorkerChanged.Add(MPT_OnCityWorkerChanged);

-- ② 城界扩张 → 市民重排（0.5 秒去抖合并窗口，1.67 为 4 秒——条目18调优）
local function MPT_OnCityTileOwnershipChanged(playerID : number, cityID : number)
	if playerID == Game.GetLocalPlayer() then
		print("MPT_Banner: CityTileOwnershipChanged city=" .. cityID .. " cooldownActive=" .. tostring(MPT_GetTime() <= MPT_CoolDownUntil));	-- 条目18调试 print
	end
	if playerID == Game.GetLocalPlayer() and MPT_GetTime() > MPT_CoolDownUntil then
		MPT_ScheduleTask(MPT_REARRANGE_DELAY, MPT_RequestCitizenRearrange, "MPT_Rearrange_" .. tostring(cityID), {playerID, cityID}, true);
	end
end
Events.CityTileOwnershipChanged.Add(MPT_OnCityTileOwnershipChanged);

-- ③ 人口增长 → 市民重排（0.5 秒去抖，1.67 为 4 秒——条目18调优）
local function MPT_OnCityPopulationChanged(playerID : number, cityID : number)
	if playerID == Game.GetLocalPlayer() then
		print("MPT_Banner: CityPopulationChanged city=" .. cityID .. " cooldownActive=" .. tostring(MPT_GetTime() <= MPT_CoolDownUntil));	-- 条目18调试 print
	end
	if playerID == Game.GetLocalPlayer() and MPT_GetTime() > MPT_CoolDownUntil then
		MPT_ScheduleTask(MPT_REARRANGE_DELAY, MPT_RequestCitizenRearrange, "MPT_Rearrange_" .. tostring(cityID), {playerID, cityID}, true);
	end
end
Events.CityPopulationChanged.Add(MPT_OnCityPopulationChanged);

-- ④ 地块产出变化（改良建成/被劫/修复等）→ 市民重排（0.5 秒去抖，1.67 为 2 秒——条目18调优）
local function MPT_OnPlotYieldChanged(x : number, y : number)
	if MPT_GetTime() <= MPT_CoolDownUntil then return; end
	local pPlot = Map.GetPlot(x, y);
	if pPlot == nil then return; end	-- 优化6
	local playerID : number = pPlot:GetOwner();
	if playerID == Game.GetLocalPlayer() then
		local pCity = Cities.GetPlotPurchaseCity(pPlot);
		if pCity ~= nil then
			local cityID : number = pCity:GetID();
			print("MPT_Banner: PlotYieldChanged (" .. x .. "," .. y .. ") -> city=" .. cityID);	-- 条目18调试 print
			MPT_ScheduleTask(MPT_REARRANGE_DELAY, MPT_RequestCitizenRearrange, "MPT_Rearrange_" .. tostring(cityID), {playerID, cityID}, true);
		end
	end
end
Events.PlotYieldChanged.Add(MPT_OnPlotYieldChanged);

-- 加载留痕（通配 include 是否成功在此一行可见）
print("MPT_Banner: loaded via CityBannerManager wildcard include, clock=" .. MPT_ClockName .. " now=" .. MPT_GetTime());	-- 条目18调试 print
