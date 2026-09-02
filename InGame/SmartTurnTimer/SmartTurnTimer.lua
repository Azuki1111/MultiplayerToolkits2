-- ===========================================================================
-- 条目20：智能回合计时器——移植自联机工具箱 1.67（工坊 3693899014 CC/Timer/TimerPro.lua
--   + NHK/UI/TurnTime_HotKey.lua 的加/减时热键与聊天框按钮部分）
-- 功能：房主在回合结束时以「半数真人玩家结束回合时已消耗的回合时间」为反馈量做 PID
--   调节，自动改写官方回合计时参数 TURN_TIMER_TIME 并 Network.BroadcastGameConfig()
--   广播全房；宣战/玩家掉线自动加时；世界议会投票阶段固定 120 秒；聊天指令
--   p+ / p+++ / p--；聊天框旁加时/减时快捷按钮（所有玩家可用，非房主自动代发聊天
--   指令由房主代执行）+ [ / ] 加/减时热键（房主直接改配置广播）。
-- 两项 Game 配置（条目20扩展2，GameOptions 组、ChangeableAfterGameStart=1 房主可
--   开局后在暂停菜单游戏选项中修改，广播全房；Config_SmartTimer.xml 注册）：
--   ① MPT_TIMER_CHAT 启用聊天指令（布尔，默认开）：p+/p+++/p-、快捷按钮、热键的
--      总开关（独立于模式——原「基础模式」语义由「任意模式+此开关」组合表达）
--   ② MPT_TIMER_MODE 工作模式（下拉三选一，默认智能计时器）：
--      OFF   关闭所有计时器——本 mod 完全不介入，回合时间由原版计时器参数决定
--            （聊天指令即使开启也不生效）
--      SMART 智能计时器——PID 自动平衡 + 宣战/掉线自动加时 + 投票阶段 120 秒 +
--            过时代前馈
--      TIERED 阶段计时器——回合节点平滑曲线：时间按回合节点表（SmartTurnTimer_Tiers.sql
--            建的 MPT_TimerTiers 表，Turn 回合数/Time 秒数）在相邻节点间线性插值，
--            首节点前保持首节点值、末节点后保持末节点值；默认节点 (30,30)/(50,80)/
--            (70,180) → 1~30T 保持 30 秒、30~50T 线性升至 80 秒、50~70T 线性升至
--            180 秒、之后保持；开局即强制标准计时并使首回合=曲线在回合 1 的值；
--            聊天指令的 p+/p-- 在本模式下按「下一回合曲线值 ±5/15」落实（与 SMART
--            手动修正量同幅），p+++ 下回合恢复标准计时
-- 加载机制：空 Context 经 AddUserInterfaces(Context=InGame) 注册，同名本文件自动作为
--   该 Context 脚本执行（同条目12/13 机制）；热键经 GameInfo.InputActions +
--   InputActionDefaultGestures 注册（SmartTurnTimer_InputActions.xml，前后端各注册一次，
--   主菜单按键绑定界面也要显示），Lua 侧 Input.GetActionId + Events.InputActionTriggered
--   消费。两文件合并单 Context（1.67 为 TimerPro/TurnTime_HotKey 两个独立 Context）。
-- 设置接入：两项参数经 Config_SmartTimer.xml FE UpdateDatabase 注册（条目16 CPL_NO_PINS
--   同款——Configuration 参数须前端注册，游戏侧经开局建库继承；GameConfiguration.GetValue
--   模式返回字符串、布尔返回 true/false）；节点表 MPT_TimerTiers 经
--   SmartTurnTimer_Tiers.sql InGameActions UpdateDatabase 注册（仅游戏内消费，
--   GameInfo.MPT_TimerTiers() 读取，开局后静态故懒加载缓存）；按钮显隐经
--   Events.GameConfigChanged 随配置广播刷新。
-- 与 1.67 的语义差异（留痕）：
--   1. 1.67 为布尔 TOOLS_COMMAND（仅开/关）；本 mod 拆为「聊天指令布尔 + 三值模式」
--      两项 Game 配置（条目20扩展2）——1.67 的「基础模式（仅聊天指令）」语义由
--      「任意模式 + 聊天指令关自动调节」组合表达，聊天指令的可用性不再与模式绑定
--      （阶段计时器亦可开聊天指令，1.67 固定曲线不含聊天的约束随拆分取消）。
--   2. 1.67 房主热键不受 TOOLS_COMMAND 限制；本文件热键统一由「聊天指令开关 + 模式
--      非 OFF」门控，语义一致。
--   3. 15 秒滴答音（TOOLS_15_TIME）按用户要求不移植；NHK 强制结束回合段落不移植
--      （条目12 FEB 已承担）。
--   4. 聊天指令链路不变：非房主按钮/热键发 p++/p-- 进公共聊天，房主开聊天指令且
--      模式非 OFF 才响应。
-- 相对 1.67 的优化：
--   1. 零全局污染：1.67 泄漏 ResetVariables/Cooldown/GetHumanNum/Initialize 等十余个
--      全局函数与全局状态变量，全部改 chunk local + MPT_Timer_ 前缀。
--   2. 魔法数 2133509568 → DB.MakeHash("TURNTIMER_STANDARD")（原版 ActionPanel.lua 同款
--      Hash 参数比较写法，SetTurnTimerType 内部用同一哈希函数）。
-- 条目20修复（初版移植笔误致功能缺失，用户实测反馈）：首回合初始化的类型比较误写为
--   ~= TURNTIMER_NONE 哈希并加「已是 NONE 即房主有意关闭不强制」曲解注释——原版默认
--   无限计时下条件恒为假，1.67 的「进入游戏后首次回合结束时把计时器类型替换成标准
--   回合时间（而不是无限回合时间）」整个失效（智能模式从第 2 回合起才有计时且起始
--   时间不归 30）。修正为 ~= TURNTIMER_STANDARD 哈希（已是标准则跳过）——即使哈希
--   算法有出入，最坏退化为「首次回合结束必定强制标准」，行为仍符合 1.67 观察语义。
-- 条目20修复2（用户实测：修正后仍未自动切换，明确期望时机=首次进入游戏后的下一个
--   回合开始时）：三处叠加问题——①时机不可靠：SMART 沿用 1.67 在首次回合「结束」
--   时切换（整个第 1 回合无计时），TIERED 在 LoadScreenClose 写配置可能被引擎后续
--   初始化覆盖且标志已消费不再重试 ②1.67 的 count>1 人数门槛误伤：单人测试多人局
--   （仅房主 1 真人）直接跳过 ③标志消费时机与写配置耦合，写失败即永不重试。重构为
--   回合开始事件驱动：初始化订阅提前到文件加载（LoadScreenClose 才订阅会漏接第 1
--   回合开始），首次回合开始时 SMART/TIERED 把非标准计时（原版默认无限）替换为标准
--   并设起始时间（SMART=30 秒起步/TIERED=曲线回合 1 值）；删除 SMART 首回合末与
--   TIERED 开局的两个转换块（统一收口到回合开始）；删除人数门槛（模式开关本身即
--   房主意图，联机门控已保证多人局）；「已是标准则不动」守卫保留——其真实用途是
--   读档/重进保护（重载后类型已是标准，不把平衡时间打回起点），非 OFF 模式中途
--   切换经未消费标志在下一回合开始自动接管。
-- 条目20扩展3（用户需求：监测房主是否手动修改了回合时间，智能计时器下手动更改后
--   下个回合开始时时间不变）：回合末平衡前比对 TURN_TIMER_TIME 与基线
--   MPT_PreTimeBase——不一致即回合内发生了本脚本未同步基线的修改 → 跳过本次 PID
--   平衡，下回合保持手动值，重新锚定基线后再下一回合恢复正常平衡（1.67 原为以手动
--   值为基准立即重新平衡）。判定通道：脚本自动调节均同步基线不触发保持（宣战 +20/
--   掉线 +30/投票 120/p-- 走平衡修正）；手动类触发保持一回合——聊天 p+ 不再回写
--   基线（1.67「p+ 仅当前回合生效」语义随本扩展取消）、热键直改、暂停菜单/控制台
--   等外部改动；回合开始初始化写入后同步基线，防止误判自身为手动修改。
--   3. 真人统计合并：1.67 在 GetHumanNum / 半数采样 / 回合开始重置 / 投票判定 四处
--      重复全遍历真人，合并为单一 MPT_Timer_CountHumans()（一次遍历同时返回总数与
--      已结束数）；首回合初始化人数判定也复用（1.67 该处未排除观察者，此处修正）。
--   4. PID 控制量 Kp*E+Ki*I+Kd*D 只算一次复用（1.67 抗饱和判定与限幅各算一遍）；
--      手动修正量懒计算（1.67 无采样回合也白算）。
--   5. nil/类型防御：TURN_TIMER_TIME 非 number 时兜底 60（前端预设默认值，条目2 同值；
--      1.67 直接参与算术，无标准计时开局读 nil 崩脚隐患）；PlayerConfigurations/
--      Players/Game.GetEras() 索引守卫（条目15/18 先例）；聊天文本 type 守卫；
--      模式值 type 守卫（参数未注册时兜底 OFF，fail-safe 不介入）；节点表行值
--      type 守卫（脏行跳过）。
--   6. 冷却计时 os.time()（墙钟，受改表/对时影响）→ UI.GetElapsedTime 单调真实时钟，
--      Lua 闭包包装（条目18修复同款，规避引擎 cfunction 类型检查）。
--   7. 联机门控：GameConfiguration.IsAnyMultiplayer() 为假时全部逻辑跳过——1.67 单人
--      局也空跑平衡并广播配置。
--   8. TurnTimerUpdated 1.67 双订阅（剩余时间记录 + 15 秒滴答音）→ 单订阅仅记录。
--   9. 按钮显隐 XML 默认 Hidden 防加载瞬间闪现，LateInitialize 刷一次 + 订阅
--      Events.GameConfigChanged 随配置广播刷新（含房主开局后切模式/开关）。
--   10. 1.67 文本 bug 修正：减时按钮 tooltip「下回合减少20秒」与实际 p-- 的 -15 秒
--       不符，本 mod 文本按实际值写。
-- 保留 1.67 语义（数值原样）：PID 参数 Kp=0.5/Ki=0.08/Kd=0.25、控制量限幅 [-10,+10]、
--   目标等待中位数 18 秒、一阶滤波 0.5、衰减 0.98、后期修正 0.05、最小回合时间 30 秒、
--   p+ 加 20 秒（剩余<8 秒时改 +24）、p+++ 本回合无回合时间（下回合恢复 STANDARD）、
--   p-- 下回合 -15 秒、大文明宣战 +20 秒（3 秒冷却）、剩余<10 秒对城邦宣战 +8 秒、
--   掉线 +30 秒、投票阶段 120 秒、首回合开始时把非标准计时（原版默认无限）替换为
--   标准（SMART 起步 30 秒/TIERED 取曲线回合 1 值，读档已标准则不动，条目20修复2）、
--   房主监听
--   仅公共频道（toPlayer == -1）、p+ 每回合一次。
-- 与 1.67 同装注意：双方计时器都会在回合结束改写 TURN_TIMER_TIME 并广播，互相拉扯
--   导致时间振荡（用户确认不管控），勿同时开启两边的智能计时器。
-- 注册：AddUserInterfaces(900, Context=InGame) + ImportFiles(900) 同名配对 +
--   UpdateDatabase(InputActions, 10) 前后端各一次 + UpdateDatabase(Config 参数, 10 FE)
--   + UpdateDatabase(节点表, 10 IG) + UpdateText(100) 前后端各一次。
-- ===========================================================================

-- ===========================================================================
-- 模式常量（值与 Config_SmartTimer.xml 的 DomainValues 对应）
-- ===========================================================================
local MPT_MODE_OFF		= "MPT_TIMER_MODE_OFF";		-- 关闭所有计时器
local MPT_MODE_SMART	= "MPT_TIMER_MODE_SMART";	-- 智能计时器（PID 调节）
local MPT_MODE_TIERED	= "MPT_TIMER_MODE_TIERED";	-- 阶段计时器（回合节点平滑线性曲线）

-- ===========================================================================
-- 常量（1.67 原值，调参处集中于此）
-- ===========================================================================
local MPT_MinTime			: number = 30;		-- 回合最小时间（秒）
local MPT_Target			: number = 18;		-- 目标：半数玩家结束回合时的等待时间中位数
local MPT_KP				: number = 0.5;		-- PID 比例环节
local MPT_KI				: number = 0.08;	-- PID 积分环节（消除稳态误差，后期起作用）
local MPT_KD				: number = 0.25;	-- PID 微分环节（超前控制）
local MPT_ControlMax		: number = 10;		-- 单回合控制量最大增幅
local MPT_ControlMin		: number = -10;		-- 单回合控制量最大降幅
local MPT_Filter			: number = 0.5;		-- 输入信号一阶滤波系数
local MPT_Attenuation		: number = 0.98;	-- 衰减比（抑制后期回合时间过长）
local MPT_TimeCorrection	: number = 0.05;	-- 后期修正：时间越长玩家用时越发散
local MPT_TimeFallback		: number = 60;		-- TURN_TIMER_TIME 非 number / 节点表为空时的兜底值（条目2 前端预设同值）
local MPT_TurnTimerStandardHash	: number = DB.MakeHash("TURNTIMER_STANDARD");	-- 优化2：1.67 魔法数 2133509568 的可读化（首回合「已是标准则不动」比较；条目20修复）

-- ===========================================================================
-- 状态（全 local——优化1）
-- ===========================================================================
local MPT_IsMultiplayer		: boolean = GameConfiguration.IsAnyMultiplayer();	-- 优化7：联机门控
local MPT_ActionAdd			: boolean = false;	-- p+ 加时指令标志（每回合一次）
local MPT_ActionNone		: boolean = false;	-- p+++ 无限时间标志
local MPT_ActionReduce		: boolean = false;	-- p-- 减时指令标志
local MPT_AllPlayerEndTurn	: boolean = false;	-- 全部真人结束回合标志（排除世界议会投票影响）
local MPT_FirstTurnInit		: boolean = true;	-- 首回合初始化标志
local MPT_PreTime			: number = 0;		-- 上次平衡计算的应用时间
local MPT_PreTimeBase		: number = 0;		-- 基准时间（与当前配置比对，检测外部手段修改）
local MPT_HalfPlayerUseTime	: number = nil;		-- 半数真人结束回合时的已耗时间（PID 反馈量）
local MPT_PreHalfPlayerUseTime	: number = nil;	-- 上回合的半数玩家用时（滤波用）
local MPT_EraReduce			: boolean = false;	-- 过时代后下一回合减时标志
local MPT_Integral			: number = 0;		-- PID 积分项
local MPT_LastError			: number = 0;		-- PID 上一次误差
local MPT_TurnTimer			: table = { ElapsedTime = 0, MaxTurnTime = 0, TimeRemaining = 0 };	-- 回合时钟记录
local MPT_Cooldowns			: table = {};		-- 冷却表（防同类型事件短时间多次触发）
local MPT_TierNodes			: table = nil;		-- 阶段曲线节点缓存（MPT_TimerTiers 表懒加载，开局建库后静态）
local MPT_AddTimeActionId	: number = -1;		-- 加时热键动作 ID（Initialize 时取）
local MPT_ReduceTimeActionId	: number = -1;	-- 减时热键动作 ID

-- 单调真实时钟（秒）：UI.GetElapsedTime Lua 闭包包装，缺 API 兜底 os.clock
-- （优化6；条目18修复同款——直接把 cfunction 赋给函数变量会触发引擎类型检查）
local MPT_Timer_GetTime = nil;
if UI ~= nil and UI.GetElapsedTime ~= nil then
	MPT_Timer_GetTime = function() return UI.GetElapsedTime(); end;
else
	MPT_Timer_GetTime = function() return os.clock(); end;
end

-- ============================================================================
-- MPT_Timer_GetMode()：读当前工作模式（Game 参数 MPT_TIMER_MODE 的 DomainValues 值）。
--   非 string（参数未注册/配置异常）时兜底 OFF——fail-safe 不介入（优化5）。
-- 用法：local mode = MPT_Timer_GetMode();
-- ============================================================================
local function MPT_Timer_GetMode()
	local value = GameConfiguration.GetValue("MPT_TIMER_MODE");
	if type(value) ~= "string" then
		return MPT_MODE_OFF;
	end
	return value;
end

-- ============================================================================
-- MPT_Timer_ChatEnabled()：聊天指令/快捷按钮/热键是否可用——「启用聊天指令」布尔
--   开启且模式非 OFF（关闭模式下 mod 完全不介入，条目20扩展2）。
-- 用法：if MPT_Timer_ChatEnabled() then ...
-- ============================================================================
local function MPT_Timer_ChatEnabled()
	if MPT_Timer_GetMode() == MPT_MODE_OFF then
		return false;
	end
	return GameConfiguration.GetValue("MPT_TIMER_CHAT") == true;
end

-- ============================================================================
-- MPT_Timer_GetConfigTime()：读当前回合时间配置（秒）。
--   TURN_TIMER_TIME 非 number 时兜底 MPT_TimeFallback（优化5：1.67 直接参与算术，
--   无标准计时开局读 nil 崩脚隐患）。
-- 用法：MPT_Timer_GetConfigTime()
-- ============================================================================
local function MPT_Timer_GetConfigTime()
	local value = GameConfiguration.GetValue("TURN_TIMER_TIME");
	if type(value) ~= "number" then
		return MPT_TimeFallback;
	end
	return value;
end

-- ============================================================================
-- MPT_Timer_GetTierNodes()：阶段曲线节点（MPT_TimerTiers 表，{Turn,Time} 升序）。
--   懒加载并缓存——开局建库后静态不变（条目20扩展2）；行值 type 守卫跳过脏行。
-- 用法：local nodes = MPT_Timer_GetTierNodes();
-- ============================================================================
local function MPT_Timer_GetTierNodes()
	if MPT_TierNodes == nil then
		MPT_TierNodes = {};
		local rows = GameInfo.MPT_TimerTiers();
		if rows ~= nil then
			for row in rows do
				if type(row.Turn) == "number" and type(row.Time) == "number" then
					table.insert(MPT_TierNodes, { Turn = row.Turn, Time = row.Time });
				end
			end
			table.sort(MPT_TierNodes, function(a, b) return a.Turn < b.Turn; end);
		end
	end
	return MPT_TierNodes;
end

-- ============================================================================
-- MPT_Timer_TieredTimeForTurn(turnNumber)：阶段计时器平滑曲线——回合节点表相邻两
--   节点间线性插值，首节点前保持首节点时间、末节点后保持末节点时间（条目20扩展2）。
--   表空/无有效行时兜底 MPT_TimeFallback。
-- 用法：MPT_Timer_TieredTimeForTurn(35) → 节点(30,30)/(50,80) 间插值 = 50
-- ============================================================================
local function MPT_Timer_TieredTimeForTurn(turnNumber)
	local nodes = MPT_Timer_GetTierNodes();
	if nodes == nil or #nodes == 0 then
		return MPT_TimeFallback;
	end
	if turnNumber <= nodes[1].Turn then
		return nodes[1].Time;	-- 首节点前：保持首节点值
	end
	for i = 2, #nodes do
		local prev = nodes[i - 1];
		local curr = nodes[i];
		if turnNumber <= curr.Turn then
			-- 相邻节点间线性插值（平滑曲线）
			local ratio :number = (turnNumber - prev.Turn) / (curr.Turn - prev.Turn);
			return math.floor(prev.Time + (curr.Time - prev.Time) * ratio + 0.5);
		end
	end
	return nodes[#nodes].Time;	-- 末节点后：保持末节点值
end

-- ============================================================================
-- MPT_Timer_IsCooldownReady(parameterId, delay)：事件冷却判定。
--   parameterId 冷却键；delay 冷却秒数（真实单调时钟，优化6）。
--   冷却中返回 false；冷却结束返回 true 并刷新时间戳。
-- 用法：if MPT_Timer_IsCooldownReady("MajorWar", 3) then ... end
-- ============================================================================
local function MPT_Timer_IsCooldownReady(parameterId, delay)
	local now = MPT_Timer_GetTime();
	if MPT_Cooldowns[parameterId] ~= nil and now < MPT_Cooldowns[parameterId] + delay then
		return false;
	end
	MPT_Cooldowns[parameterId] = now;
	return true;
end

-- ============================================================================
-- MPT_Timer_ResetVariables()：回合平衡后重置全部回合内状态。
--   g_PreTime/g_PreTimeBase 重新读配置（即刚写回的平衡值，下回合比对基准）。
-- 用法：MPT_Timer_ResetVariables()（回合平衡尾部 / 非房主回合末 / 模式关闭）
-- ============================================================================
local function MPT_Timer_ResetVariables()
	MPT_PreTime = MPT_Timer_GetConfigTime();
	MPT_PreTimeBase = MPT_PreTime;
	MPT_ActionAdd = false;
	MPT_ActionReduce = false;
	MPT_ActionNone = false;
	MPT_HalfPlayerUseTime = nil;
	MPT_AllPlayerEndTurn = false;
	MPT_EraReduce = false;
	MPT_TurnTimer.ElapsedTime = 0;
	MPT_TurnTimer.MaxTurnTime = 0;
	MPT_TurnTimer.TimeRemaining = 0;
end

-- ============================================================================
-- MPT_Timer_CountHumans()：统计真人主要文明玩家（排除观察者 LEADER_SPECTATOR）。
--   返回两个值：真人总数、其中已结束回合（非回合进行中）的人数——一次遍历同时
--   满足 1.67 四处扫描的全部口径（优化3）。
-- 用法：local total, ended = MPT_Timer_CountHumans();
-- ============================================================================
local function MPT_Timer_CountHumans()
	local total :number = 0;
	local ended :number = 0;
	local aliveMajorIDs = PlayerManager.GetAliveMajorIDs();
	if aliveMajorIDs == nil then
		return 0, 0;
	end
	for _, playerID in ipairs(aliveMajorIDs) do
		local playerConfig = PlayerConfigurations[playerID];
		if playerConfig ~= nil and playerConfig:IsHuman()
			and playerConfig:GetLeaderTypeName() ~= "LEADER_SPECTATOR" then
			total = total + 1;
			local player = Players[playerID];
			if player == nil or not player:IsTurnActive() then
				ended = ended + 1;
			end
		end
	end
	return total, ended;
end

-- ============================================================================
-- MPT_Timer_OnTurnTimerUpdated(elapsedTime, maxTurnTime)：回合时钟记录（剩余时间
--   供 p+ 尾秒判定/宣战/掉线加时阈值用）。优化8：1.67 同事件双订阅，此处单订阅
--   仅记录（15 秒滴答音不移植）。
-- ============================================================================
local function MPT_Timer_OnTurnTimerUpdated(elapsedTime, maxTurnTime)
	MPT_TurnTimer.ElapsedTime	= elapsedTime or 0;
	MPT_TurnTimer.MaxTurnTime	= maxTurnTime or 0;
	MPT_TurnTimer.TimeRemaining	= (maxTurnTime or 0) - (elapsedTime or 0);
end

-- ============================================================================
-- MPT_Timer_OnMultiplayerChat(fromPlayer, toPlayer, text, eTargetType)：聊天指令
--   （「启用聊天指令」开启且模式非 OFF 时；仅房主监听公共频道 toPlayer == -1，
--   1.67 同款链路）：
--   p+ / p++   加时 20 秒（剩余<8 秒时改 +24，每回合一次，立即广播；下回合经模式
--              各自的回合末逻辑小幅顺延）
--   p+++ / p++++ 本回合无回合时间（下回合恢复 STANDARD）
--   p- / p--   下回合 -15 秒（SMART 经平衡修正、TIERED 经曲线值直减）
-- ============================================================================
local function MPT_Timer_OnMultiplayerChat(fromPlayer, toPlayer, text, eTargetType)
	if not MPT_IsMultiplayer or not MPT_Timer_ChatEnabled()
		or Network.GetLocalPlayerID() ~= Network.GetGameHostPlayerID()
		or toPlayer ~= -1 or type(text) ~= "string" then
		return;
	end

	local lowerText = string.lower(text);
	if lowerText == "p+" or lowerText == "p++" then
		if not MPT_ActionAdd then
			local addTime :number = 20;
			if MPT_TurnTimer.MaxTurnTime > 0 and MPT_TurnTimer.TimeRemaining < 8 then
				addTime = 24;	-- 尾秒加时改 +24（1.67 原语义，其注释所写 30 为笔误）
			end
			GameConfiguration.SetValue("TURN_TIMER_TIME", MPT_Timer_GetConfigTime() + addTime);
			Network.BroadcastGameConfig();
			-- 条目20扩展3：不回写 MPT_PreTimeBase——聊天指令加时与热键直改/暂停菜单同样
			-- 视为房主手动修改，下回合开始时间保持（1.67 回写基线使 p+ 仅当前回合生效的
			-- 语义随本扩展取消）
			MPT_ActionAdd = true;
		end
		return;
	end

	if lowerText == "p+++" or lowerText == "p++++" then
		GameConfiguration.SetTurnTimerType("TURNTIMER_NONE");
		Network.BroadcastGameConfig();
		MPT_ActionNone = true;
		return;
	end

	if lowerText == "p-" or lowerText == "p--" then
		MPT_ActionReduce = true;
		return;
	end
end

-- ============================================================================
-- MPT_Timer_OnTurnEndTiered(currentTurn)：阶段计时器模式回合末（Events.TurnEnd，
--   仅房主写配置）——按下一回合的平滑曲线写 TURN_TIMER_TIME 并广播（条目20扩展2）。
--   首回合强制标准计时（阶段模式语义即「要有计时器」，LateInitialize 已在开局设置
--   过，此处兜底中途切模式场景）；聊天指令的「下一回合」效果在曲线值上落实：
--   p+ 顺延 +5 / p-- 减 15（与 SMART 手动修正量同幅，1.67 语义），下限最小时间。
-- ============================================================================
local function MPT_Timer_OnTurnEndTiered(currentTurn)
	if Network.GetLocalPlayerID() ~= Network.GetGameHostPlayerID() then
		return;
	end

	if MPT_ActionNone then
		GameConfiguration.SetTurnTimerType("TURNTIMER_STANDARD");	-- p+++ 仅本回合无计时，下回合恢复
	end

	local nextTurn :number = (currentTurn or 0) + 1;	-- 本回合末设置的是下一回合的时长
	local tierTime :number = MPT_Timer_TieredTimeForTurn(nextTurn);
	if MPT_ActionAdd then
		tierTime = tierTime + 5;
	end
	if MPT_ActionReduce then
		tierTime = tierTime - 15;
	end
	tierTime = math.ceil(math.max(tierTime, MPT_MinTime));
	GameConfiguration.SetValue("TURN_TIMER_TIME", tierTime);
	Network.BroadcastGameConfig();
	MPT_Timer_ResetVariables();
end

-- ============================================================================
-- MPT_Timer_OnTurnEndSmart()：智能计时器核心平衡（Events.TurnEnd，回合整体结束时）
--   ——仅房主执行；以半数真人结束回合时已耗时间为反馈量 → 一阶滤波 → PID（积分
--   抗饱和+限幅）→ 衰减 → 过时代前馈 → 首回合初始化 → 上限 30 秒取整写回
--   TURN_TIMER_TIME 并广播 → 重置回合内状态。
-- ============================================================================
local function MPT_Timer_OnTurnEndSmart()
	if Network.GetLocalPlayerID() ~= Network.GetGameHostPlayerID() then
		MPT_Timer_ResetVariables();
		return;
	end

	local configTime :number = MPT_Timer_GetConfigTime();
	if configTime ~= MPT_PreTimeBase then
		-- 条目20扩展3：回合内检测到房主手动/外部修改（热键直改、暂停菜单改时间、聊天
		-- 指令、控制台等本脚本未同步基线的改动）→ 本回合末跳过 PID 平衡，下回合开始
		-- 时间保持手动值；重新锚定基线，再下一回合恢复正常平衡（1.67 原为以手动值为
		-- 基准立即重新平衡，用户要求手动修改保持一回合不变）
		if MPT_ActionNone then
			GameConfiguration.SetTurnTimerType("TURNTIMER_STANDARD");	-- p+++ 的恢复不受跳过影响
		end
		MPT_PreTime = configTime;
		MPT_PreTimeBase = configTime;
		MPT_ActionAdd = false;
		MPT_ActionReduce = false;
		MPT_ActionNone = false;
		return;
	end
	local balancedTime :number = MPT_PreTime;	-- 基线一致（回合内无手动改动）→ 沿用上次平衡值

	-- 过时代倒计时（前馈控制：过渡回合加时，下一回合减时）
	local nextEraCountdown :number = -1;
	local gameEras = Game.GetEras();
	if gameEras ~= nil and gameEras.GetNextEraCountdown ~= nil then
		nextEraCountdown = gameEras:GetNextEraCountdown();
	end

	if MPT_HalfPlayerUseTime ~= nil then
		-- 手动修正量（优化4：懒计算——1.67 无采样回合也白算）
		local manualControl :number = math.min(MPT_TimeCorrection * balancedTime, 10)
			+ math.max(0, (8 - MPT_Timer_CountHumans()) * 1.5);	-- 人数<8 时补偿玩家用时差异
		if MPT_ActionAdd then
			manualControl = manualControl + 5;
		end
		if MPT_ActionReduce then
			manualControl = manualControl - 15;
		end

		-- 一阶滤波器平滑输入信号，PID 计算控制量（优化4：只算一次复用）
		local filteredHalf :number = MPT_Filter * MPT_HalfPlayerUseTime
			+ (1 - MPT_Filter) * (MPT_PreHalfPlayerUseTime or MPT_HalfPlayerUseTime);
		MPT_PreHalfPlayerUseTime = MPT_HalfPlayerUseTime;
		local errorValue :number = (MPT_Target + filteredHalf + manualControl) - balancedTime;
		local derivative :number = errorValue - MPT_LastError;
		MPT_LastError = errorValue;
		MPT_Integral = MPT_Integral + errorValue;
		local control :number = MPT_KP * errorValue + MPT_KI * MPT_Integral + MPT_KD * derivative;

		-- 积分抗饱和：控制量达幅值/低于最小时间下限/与误差同向扩大误差时清零积分
		local controlFloor :number = math.max(MPT_ControlMin, MPT_MinTime - balancedTime);
		if control >= MPT_ControlMax or control <= controlFloor or errorValue * control >= 0 then
			MPT_Integral = 0;
		end
		-- 接近时间下限时防俯冲，只保留向上的积分
		if balancedTime <= MPT_MinTime + MPT_Target then
			MPT_Integral = math.max(0, MPT_Integral);
		end

		balancedTime = balancedTime + math.min(math.max(control, MPT_ControlMin), MPT_ControlMax);
		balancedTime = MPT_Attenuation * balancedTime;	-- 衰减，抑制后期时间过长
	end

	if nextEraCountdown == 1 then
		balancedTime = balancedTime + 10;	-- 过时代倒计时最后 1 回合：前馈加时
	elseif nextEraCountdown == 0 then
		balancedTime = balancedTime + 20;	-- 过时代回合：前馈加时
	elseif MPT_EraReduce then
		balancedTime = balancedTime - 15;	-- 过时代后下一回合：减时
	end

	if MPT_ActionNone then
		GameConfiguration.SetTurnTimerType("TURNTIMER_STANDARD");	-- p+++ 仅本回合无计时，下回合恢复
	end

	balancedTime = math.ceil(math.max(balancedTime, MPT_MinTime));
	GameConfiguration.SetValue("TURN_TIMER_TIME", balancedTime);
	Network.BroadcastGameConfig();
	MPT_Timer_ResetVariables();

	if nextEraCountdown == 0 then
		MPT_EraReduce = true;	-- 重置后置位：下一回合减时（1.67 同款时序）
	end
end

-- ============================================================================
-- MPT_Timer_OnTurnEnd(currentTurn)：Events.TurnEnd 入口——按工作模式分发
--   （条目20扩展2）：SMART→PID 平衡；TIERED→阶段平滑曲线；OFF/未知→不介入
--   （仅清状态）。
-- ============================================================================
local function MPT_Timer_OnTurnEnd(currentTurn)
	if not MPT_IsMultiplayer then return; end
	local mode = MPT_Timer_GetMode();
	if mode == MPT_MODE_TIERED then
		MPT_Timer_OnTurnEndTiered(currentTurn);
	elseif mode == MPT_MODE_SMART then
		MPT_Timer_OnTurnEndSmart();
	else
		MPT_Timer_ResetVariables();	-- OFF / 未知值：仅清状态不写配置
	end
end

-- ============================================================================
-- MPT_Timer_OnDeclareWar(firstPlayerID, secondPlayerID)：宣战加时（仅 SMART——
--   自动调节属智能计时器）。大文明间宣战 +20 秒（3 秒冷却）；剩余<10 秒时对城邦
--   宣战 +8 秒（防卡秒顶城邦）。
-- ============================================================================
local function MPT_Timer_OnDeclareWar(firstPlayerID, secondPlayerID)
	if not MPT_IsMultiplayer or MPT_Timer_GetMode() ~= MPT_MODE_SMART
		or Network.GetLocalPlayerID() ~= Network.GetGameHostPlayerID() then
		return;
	end

	local firstPlayer = firstPlayerID ~= nil and Players[firstPlayerID] or nil;
	local secondPlayer = secondPlayerID ~= nil and Players[secondPlayerID] or nil;
	if firstPlayer == nil or secondPlayer == nil then return; end

	if firstPlayer:IsMajor() and secondPlayer:IsMajor() then
		if MPT_Timer_IsCooldownReady("MajorWar", 3) then
			GameConfiguration.SetValue("TURN_TIMER_TIME", MPT_Timer_GetConfigTime() + 20);
			Network.BroadcastGameConfig();
			MPT_PreTime = MPT_PreTime + 20;
			MPT_PreTimeBase = MPT_PreTimeBase + 20;
		end
		return;
	end

	if MPT_TurnTimer.MaxTurnTime > 0 and MPT_TurnTimer.TimeRemaining < 10 then
		if MPT_Timer_IsCooldownReady("OtherWar", 3) then
			GameConfiguration.SetValue("TURN_TIMER_TIME", MPT_Timer_GetConfigTime() + 8);
			Network.BroadcastGameConfig();
			MPT_PreTimeBase = MPT_PreTimeBase + 8;
		end
	end
end

-- ============================================================================
-- MPT_Timer_OnPrePlayerDisconnected(playerID)：玩家掉线加时（仅 SMART；房主自己
--   掉线不处理）。剩余<30 秒时 +30 秒并置加时标志（平衡时额外 +5 修正）。
-- ============================================================================
local function MPT_Timer_OnPrePlayerDisconnected(playerID)
	if not MPT_IsMultiplayer or MPT_Timer_GetMode() ~= MPT_MODE_SMART then return; end
	local localPlayerID :number = Network.GetLocalPlayerID();
	if localPlayerID ~= Network.GetGameHostPlayerID() or playerID == localPlayerID then
		return;	-- 仅房主处理他人掉线
	end

	if MPT_TurnTimer.MaxTurnTime > 0 and MPT_TurnTimer.TimeRemaining < 30 then
		GameConfiguration.SetValue("TURN_TIMER_TIME", MPT_Timer_GetConfigTime() + 30);
		Network.BroadcastGameConfig();
		MPT_ActionAdd = true;
		MPT_PreTimeBase = MPT_PreTimeBase + 30;
	end
end

-- ============================================================================
-- MPT_Timer_OnPlayerTurnEnd(ePlayer)：本地/远程玩家回合结束（两事件共用，仅 SMART
--   ——半数用时采样与投票标志只服务 PID 平衡/投票 120s）。统计真人结束回合比例
--   ≥0.5 时记录半数玩家用时（PID 反馈量，整回合只记首次）；全部真人结束置投票
--   阶段标志。ePlayer：RemotePlayerTurnEnd 传玩家 ID，LocalPlayerTurnEnd 无参
--   （本地兜底，1.67 同款）。
-- ============================================================================
local function MPT_Timer_OnPlayerTurnEnd(ePlayer)
	if not MPT_IsMultiplayer or MPT_Timer_GetMode() ~= MPT_MODE_SMART then return; end
	ePlayer = ePlayer or Network.GetLocalPlayerID();
	local playerConfig = PlayerConfigurations[ePlayer];
	if playerConfig == nil or not Players[ePlayer]:IsMajor()
		or not playerConfig:IsHuman()
		or playerConfig:GetLeaderTypeName() == "LEADER_SPECTATOR" then
		return;
	end

	local total, ended = MPT_Timer_CountHumans();
	if total <= 0 then return; end

	if MPT_HalfPlayerUseTime == nil and MPT_TurnTimer.MaxTurnTime > 0
		and ended / total >= 0.5 then
		MPT_HalfPlayerUseTime = MPT_TurnTimer.ElapsedTime;
	end

	if ended == total then
		MPT_AllPlayerEndTurn = true;
	end
end

-- ============================================================================
-- MPT_Timer_OnPlayerTurnBegin(ePlayer)：本地/远程玩家回合开始（两事件共用，仅
--   SMART）。投票阶段（上回合全员结束时置位）：全员都开始新回合后把时间固定
--   120 秒（3 秒冷却、真人>1）；正常回合：全员都在回合中（有玩家取消结束重开）
--   → 清空采样重新记录。
-- ============================================================================
local function MPT_Timer_OnPlayerTurnBegin(ePlayer)
	if not MPT_IsMultiplayer or MPT_Timer_GetMode() ~= MPT_MODE_SMART then return; end
	ePlayer = ePlayer or Network.GetLocalPlayerID();

	if MPT_AllPlayerEndTurn then	-- 投票阶段
		if Network.GetLocalPlayerID() == Network.GetGameHostPlayerID() then
			local total, ended = MPT_Timer_CountHumans();
			if total > 1 and ended <= 0 and MPT_Timer_IsCooldownReady("Vote", 3) then
				GameConfiguration.SetValue("TURN_TIMER_TIME", 120);
				Network.BroadcastGameConfig();
				MPT_PreTimeBase = 120;
			end
		end
		return;
	end

	local playerConfig = PlayerConfigurations[ePlayer];
	if playerConfig == nil or not Players[ePlayer]:IsMajor()
		or not playerConfig:IsHuman()
		or playerConfig:GetLeaderTypeName() == "LEADER_SPECTATOR" then
		return;
	end

	local total, ended = MPT_Timer_CountHumans();
	if total > 0 and ended <= 0 then
		MPT_HalfPlayerUseTime = nil;	-- 全员回合进行中：重新记录半数用时
	end
end

-- ============================================================================
-- MPT_Timer_OnInputActionTriggered(actionId)：[ / ] 加减时热键（「启用聊天指令」
--   开启且模式非 OFF；差异2：统一开关门控——1.67 房主热键不受 TOOLS_COMMAND 限制）。
--   加时 ]：房主直接 +20 秒广播；非房主代发聊天指令 p++（由房主监听执行）。
--   减时 [：房主 -10 秒（下限 40 秒，触底换提示音）；非房主代发 p--。
-- ============================================================================
local function MPT_Timer_OnInputActionTriggered(actionId)
	if not MPT_IsMultiplayer or not MPT_Timer_ChatEnabled() then return; end

	if actionId == MPT_AddTimeActionId then
		if Network.GetLocalPlayerID() == Network.GetGameHostPlayerID() then
			GameConfiguration.SetValue("TURN_TIMER_TIME", MPT_Timer_GetConfigTime() + 20);
			Network.BroadcastGameConfig();
			UI.PlaySound("Play_MP_Game_Launch_Timer_Beep");
		else
			Network.SendChat("p++", -2, -1);
			UI.PlaySound("Play_MP_Game_Launch_Timer_Beep");
		end
		return;
	end

	if actionId == MPT_ReduceTimeActionId then
		if Network.GetLocalPlayerID() == Network.GetGameHostPlayerID() then
			local configTime :number = MPT_Timer_GetConfigTime();
			if configTime > 40 then
				GameConfiguration.SetValue("TURN_TIMER_TIME", configTime - 10);
				UI.PlaySound("Play_MP_Game_Launch_Timer_Beep");
			else
				GameConfiguration.SetValue("TURN_TIMER_TIME", 40);
				UI.PlaySound("Play_MP_Game_Waiting_For_Player");
			end
			Network.BroadcastGameConfig();
		else
			Network.SendChat("p--", -2, -1);
			UI.PlaySound("Play_MP_Game_Launch_Timer_Beep");
		end
		return;
	end
end

-- ============================================================================
-- MPT_Timer_OnTurnBeginInit()：首回合开始初始化（条目20修复2）——SMART/TIERED 模式下
--   首次进入游戏后的下一个回合开始时，把非标准计时（原版默认无限计时）替换为标准：
--   SMART 起步 30 秒（1.67 原值）；TIERED 取曲线在回合 1 的值。仅房主写配置。
--   「已是标准则不动」守卫保留（MPT_TurnTimerStandardHash）：读档/重进时类型已是
--   标准，不把平衡时间打回起点——该守卫同时是重进保护，不可删。
--   订阅于文件加载（MPT_Timer_Initialize 内，早于 LoadScreenClose——否则会漏接第 1
--   回合开始）；OFF 模式不消费标志，中途切到 SMART/TIERED 后下一回合开始自动接管。
-- ============================================================================
local function MPT_Timer_OnTurnBeginInit()
	if not MPT_IsMultiplayer or not MPT_FirstTurnInit then return; end
	local mode = MPT_Timer_GetMode();
	if mode ~= MPT_MODE_SMART and mode ~= MPT_MODE_TIERED then return; end
	MPT_FirstTurnInit = false;	-- 消费标志（无论是否房主，防重复触发）
	if Network.GetLocalPlayerID() ~= Network.GetGameHostPlayerID() then return; end
	if GameConfiguration.GetTurnTimerType() == MPT_TurnTimerStandardHash then
		return;	-- 已是标准计时（读档/重进）：不动，防平衡时间被打回起点
	end
	GameConfiguration.SetTurnTimerType("TURNTIMER_STANDARD");
	if mode == MPT_MODE_TIERED then
		GameConfiguration.SetValue("TURN_TIMER_TIME", MPT_Timer_TieredTimeForTurn(1));
	else
		GameConfiguration.SetValue("TURN_TIMER_TIME", MPT_MinTime);
	end
	Network.BroadcastGameConfig();
	MPT_Timer_ResetVariables();	-- 同步基线，避免首回合末把初始化写入误判为手动修改（条目20扩展3）
end

-- ============================================================================
-- MPT_Timer_UpdateButtonsVisibility()：刷新聊天框旁加时/减时按钮显隐。
--   联机且 MPT_Timer_ChatEnabled() 时显示（优化9：XML 默认 Hidden 防闪现，
--   LateInitialize 刷一次 + GameConfigChanged 随房主配置广播刷新）。
--   Controls nil 守卫：广播可能早于按钮挂载到达。
-- 用法：MPT_Timer_UpdateButtonsVisibility()
-- ============================================================================
local function MPT_Timer_UpdateButtonsVisibility()
	if Controls.AddTimeButton == nil or Controls.ReduceTimeButton == nil then return; end
	local hide :boolean = not (MPT_IsMultiplayer and MPT_Timer_ChatEnabled());
	Controls.AddTimeButton:SetHide(hide);
	Controls.ReduceTimeButton:SetHide(hide);
end

-- ============================================================================
-- MPT_Timer_OnGameConfigChanged()：游戏配置广播（房主改任何配置都会触发）——
--   刷按钮显隐（两项参数 ChangeableAfterGameStart=1，房主可开局后在暂停菜单
--   游戏选项中切换，全房经此事件同步）。
-- ============================================================================
local function MPT_Timer_OnGameConfigChanged()
	MPT_Timer_UpdateButtonsVisibility();
end

-- ============================================================================
-- MPT_Timer_LateInitialize()：LoadScreenClose 后初始化（1.67 同款时序——确保
--   WorldTracker 上下文已加载，ChangeParent 才有挂载点）。
--   ①按钮挂到聊天框容器并注册点击（所有玩家点击都发聊天指令，房主由自己的聊天
--     监听代执行）②刷显隐 ③订阅全部游戏事件。
--   （首回合类型/起始时间初始化不在本函数——已统一收口到 MPT_Timer_OnTurnBeginInit，
--   条目20修复2：回合开始事件驱动，此处写配置可能被引擎后续初始化覆盖）
-- ============================================================================
local function MPT_Timer_LateInitialize()
	local chatContainer = ContextPtr:LookUpControl("/InGame/WorldTracker/ChatPanelContainer");
	if chatContainer ~= nil then
		if Controls.AddTimeButton ~= nil then
			Controls.AddTimeButton:ChangeParent(chatContainer);
		end
		if Controls.ReduceTimeButton ~= nil then
			Controls.ReduceTimeButton:ChangeParent(chatContainer);
		end
	end

	if Controls.AddTimeButton ~= nil then
		Controls.AddTimeButton:RegisterCallback(Mouse.eLClick, function()
			Network.SendChat("p++", -2, -1);
			UI.PlaySound("Play_MP_Game_Launch_Timer_Beep");
		end);
	end
	if Controls.ReduceTimeButton ~= nil then
		Controls.ReduceTimeButton:RegisterCallback(Mouse.eLClick, function()
			Network.SendChat("p--", -2, -1);
			UI.PlaySound("Play_MP_Game_Launch_Timer_Beep");
		end);
	end

	-- 首回合类型/起始时间的初始化已统一收口到 MPT_Timer_OnTurnBeginInit（条目20修复2：
	--   回合开始事件驱动，此处不再写配置——LoadScreenClose 时写可能被引擎后续初始化覆盖）
	MPT_Timer_UpdateButtonsVisibility();

	Events.TurnTimerUpdated.Add(MPT_Timer_OnTurnTimerUpdated);
	Events.MultiplayerChat.Add(MPT_Timer_OnMultiplayerChat);
	Events.DiplomacyDeclareWar.Add(MPT_Timer_OnDeclareWar);
	Events.MultiplayerPrePlayerDisconnected.Add(MPT_Timer_OnPrePlayerDisconnected);
	Events.TurnEnd.Add(MPT_Timer_OnTurnEnd);
	Events.LocalPlayerTurnEnd.Add(MPT_Timer_OnPlayerTurnEnd);
	Events.RemotePlayerTurnEnd.Add(MPT_Timer_OnPlayerTurnEnd);
	Events.LocalPlayerTurnBegin.Add(MPT_Timer_OnPlayerTurnBegin);
	Events.RemotePlayerTurnBegin.Add(MPT_Timer_OnPlayerTurnBegin);
	Events.InputActionTriggered.Add(MPT_Timer_OnInputActionTriggered);
	Events.GameConfigChanged.Add(MPT_Timer_OnGameConfigChanged);
end

-- ============================================================================
-- MPT_Timer_Initialize()：上下文脚本入口——取热键动作 ID（InputActions 已入库）、
--   初始化回合状态、挂 LoadScreenClose 延迟初始化。
-- ============================================================================
local function MPT_Timer_Initialize()
	MPT_AddTimeActionId = Input.GetActionId("HotKey_MPT_TurnTimeAdd");
	MPT_ReduceTimeActionId = Input.GetActionId("HotKey_MPT_TurnTimeReduce");
	Events.LocalPlayerTurnBegin.Add(MPT_Timer_OnTurnBeginInit);	-- 条目20修复2：早于 LoadScreenClose 订阅，确保捕获第 1 回合开始
	MPT_Timer_ResetVariables();
	Events.LoadScreenClose.Add(MPT_Timer_LateInitialize);
end
MPT_Timer_Initialize();
