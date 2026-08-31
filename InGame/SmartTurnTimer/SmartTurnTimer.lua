-- ===========================================================================
-- 条目20：智能回合计时器——移植自联机工具箱 1.67（工坊 3693899014 CC/Timer/TimerPro.lua
--   + NHK/UI/TurnTime_HotKey.lua 的加/减时热键与聊天框按钮部分）
-- 功能：房主在回合结束时以「半数真人玩家结束回合时已消耗的回合时间」为反馈量做 PID
--   调节，自动改写官方回合计时参数 TURN_TIMER_TIME 并 Network.BroadcastGameConfig()
--   广播全房；宣战/玩家掉线自动加时；世界议会投票阶段固定 120 秒；聊天指令
--   p+ / p+++ / p--；聊天框旁「P++/P--」快捷按钮（所有玩家可用，非房主自动代发聊天
--   指令由房主代执行）+ [ / ] 加/减时热键（房主直接改配置广播）。
-- 加载机制：空 Context 经 AddUserInterfaces(Context=InGame) 注册，同名本文件自动作为
--   该 Context 脚本执行（同条目12/13 机制）；热键经 GameInfo.InputActions +
--   InputActionDefaultGestures 注册（SmartTurnTimer_InputActions.xml，前后端各注册一次，
--   主菜单按键绑定界面也要显示），Lua 侧 Input.GetActionId + Events.InputActionTriggered
--   消费。两文件合并单 Context（1.67 为 TimerPro/TurnTime_HotKey 两个独立 Context）。
-- 设置接入：条目12 设置面板 MPT_Settings 表加行（ParameterId 沿用 1.67 原 key
--   TOOLS_COMMAND，默认 1=开启）；面板 LoadScreenClose 的 ApplyAll 全量广播自动送达
--   初始状态，本文件无需自读存档。开关为每玩家本地开关：房主侧控制自动平衡/聊天
--   指令/热键直改，非房主侧仅控制自己的按钮显隐与热键代发。
-- 与 1.67 的语义差异（留痕）：
--   1. 开关从全局 Game 参数（GameOptions 组、建房可改、广播全房）改为条目12 每玩家
--      本地开关——各客户端只看自己的开关；房主关开关即停自动平衡，非房主关开关仅藏
--      自己的按钮（1.67 按钮显隐随房主的 Game 配置全房同步）。
--   2. 1.67 房主热键不受 TOOLS_COMMAND 限制；本文件热键（含房主直改路径）统一由
--      本机开关门控，开关语义一致。
--   3. 15 秒滴答音（TOOLS_15_TIME）按用户要求不移植；NHK 强制结束回合段落不移植
--      （条目12 FEB 已承担）。
--   4. 聊天指令链路不变：非房主按钮/热键发 p++/p-- 进公共聊天，仍需房主开智能计时器
--      才生效（1.67 同款）。
-- 相对 1.67 的优化：
--   1. 零全局污染：1.67 泄漏 ResetVariables/Cooldown/GetHumanNum/Initialize 等十余个
--      全局函数与全局状态变量，全部改 chunk local + MPT_Timer_ 前缀。
--   2. 魔法数 2133509568 → DB.MakeHash("TURNTIMER_NONE")（原版 ActionPanel.lua 同款
--      Hash 参数比较写法，SetTurnTimerType 内部用同一哈希函数）。
--   3. 真人统计合并：1.67 在 GetHumanNum / 半数采样 / 回合开始重置 / 投票判定 四处
--      重复全遍历真人，合并为单一 MPT_Timer_CountHumans()（一次遍历同时返回总数与
--      已结束数）；首回合初始化人数判定也复用（1.67 该处未排除观察者，此处修正）。
--   4. PID 控制量 Kp*E+Ki*I+Kd*D 只算一次复用（1.67 抗饱和判定与限幅各算一遍）；
--      手动修正量懒计算（1.67 无采样回合也白算）。
--   5. nil/类型防御：TURN_TIMER_TIME 非 number 时兜底 60（前端预设默认值，条目2 同值；
--      1.67 直接参与算术，无标准计时开局读 nil 崩脚隐患）；PlayerConfigurations/
--      Players/Game.GetEras() 索引守卫（条目15/18 先例）；聊天文本 type 守卫。
--   6. 冷却计时 os.time()（墙钟，受改表/对时影响）→ UI.GetElapsedTime 单调真实时钟，
--      Lua 闭包包装（条目18修复同款，规避引擎 cfunction 类型检查）。
--   7. 联机门控：GameConfiguration.IsAnyMultiplayer() 为假时全部逻辑跳过——1.67 单人
--      局也空跑平衡并广播配置。
--   8. TurnTimerUpdated 1.67 双订阅（剩余时间记录 + 15 秒滴答音）→ 单订阅仅记录。
--   9. 按钮显隐从 Events.GameConfigChanged（全局配置广播，本地开关下不再变化）改为
--      LuaEvents.MPT_Settings_Toggle；XML 默认 Hidden 防加载瞬间闪现。
--   10. 1.67 文本 bug 修正：减时按钮 tooltip「下回合减少20秒」与实际 p-- 的 -15 秒
--       不符，本 mod 文本按实际值写。
-- 保留 1.67 语义（数值原样）：PID 参数 Kp=0.5/Ki=0.08/Kd=0.25、控制量限幅 [-10,+10]、
--   目标等待中位数 18 秒、一阶滤波 0.5、衰减 0.98、后期修正 0.05、最小回合时间 30 秒、
--   p+ 加 20 秒（剩余<8 秒时改 +24）、p+++ 本回合无回合时间（下回合恢复 STANDARD）、
--   p-- 下回合 -15 秒、大文明宣战 +20 秒（3 秒冷却）、剩余<10 秒对城邦宣战 +8 秒、
--   掉线 +30 秒、投票阶段 120 秒、首回合多人强制 STANDARD 并以 30 秒起步、房主监听
--   仅公共频道（toPlayer == -1）、p+ 每回合一次。
-- 与 1.67 同装注意：双方计时器都会在回合结束改写 TURN_TIMER_TIME 并广播，互相拉扯
--   导致时间振荡（用户确认不管控），勿同时开启两边的智能计时器开关。
-- 注册：AddUserInterfaces(900, Context=InGame) + ImportFiles(900) 同名配对 +
--   UpdateDatabase(InputActions, 10) 前后端各一次 + UpdateText(100) 前后端各一次。
-- ===========================================================================

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
local MPT_TimeFallback		: number = 60;		-- TURN_TIMER_TIME 非 number 时的兜底值（条目2 前端预设同值）
local MPT_TurnTimerNoneHash	: number = DB.MakeHash("TURNTIMER_NONE");	-- 优化2：替代 1.67 魔法数 2133509568

-- ===========================================================================
-- 状态（全 local——优化1）
-- ===========================================================================
local MPT_IsMultiplayer		: boolean = GameConfiguration.IsAnyMultiplayer();	-- 优化7：联机门控
local MPT_TimerEnabled		: boolean = false;	-- 本机开关（条目12 面板 TOOLS_COMMAND 广播驱动，初始经 ApplyAll 送达）
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
-- 用法：MPT_Timer_ResetVariables()（回合平衡尾部 / 非房主回合末）
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
-- MPT_Timer_OnMultiplayerChat(fromPlayer, toPlayer, text, eTargetType)：聊天指令。
--   仅房主监听公共频道（toPlayer == -1）且本机开关开启时响应（1.67 同款链路）：
--   p+ / p++   加时 20 秒（剩余<8 秒时改 +24，每回合一次，立即广播）
--   p+++ / p++++ 本回合无回合时间（下回合平衡时恢复 STANDARD）
--   p- / p--   下回合平衡时 -15 秒
-- ============================================================================
local function MPT_Timer_OnMultiplayerChat(fromPlayer, toPlayer, text, eTargetType)
	if not MPT_IsMultiplayer or not MPT_TimerEnabled
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
			MPT_PreTimeBase = MPT_PreTimeBase + addTime;
			Network.BroadcastGameConfig();
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
-- MPT_Timer_OnTurnEndBalance()：核心平衡（Events.TurnEnd，回合整体结束时）。
--   仅房主且开关开启时执行；以半数真人结束回合时已耗时间为反馈量 → 一阶滤波 →
--   PID（积分抗饱和+限幅）→ 衰减 → 过时代前馈 → 首回合初始化 → 上限 30 秒取整
--   写回 TURN_TIMER_TIME 并广播 → 重置回合内状态。
-- ============================================================================
local function MPT_Timer_OnTurnEndBalance()
	if not MPT_IsMultiplayer then return; end
	if Network.GetLocalPlayerID() ~= Network.GetGameHostPlayerID() or not MPT_TimerEnabled then
		MPT_Timer_ResetVariables();
		return;
	end

	local configTime :number = MPT_Timer_GetConfigTime();
	-- 最终应用的时间：未被外部手段（其他 mod/控制台）修改过则沿用上次计算值，否则以当前配置为准
	local balancedTime :number = (MPT_PreTimeBase == configTime) and MPT_PreTime or configTime;

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

	if MPT_FirstTurnInit then
		MPT_FirstTurnInit = false;
		-- 多人局强制标准计时并以最小时间起步（计时器已是 NONE 即房主有意关闭，不强制）
		local totalHumans = MPT_Timer_CountHumans();
		if totalHumans > 1 and GameConfiguration.GetTurnTimerType() ~= MPT_TurnTimerNoneHash then
			GameConfiguration.SetTurnTimerType("TURNTIMER_STANDARD");
			balancedTime = MPT_MinTime;
		end
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
-- MPT_Timer_OnDeclareWar(firstPlayerID, secondPlayerID)：宣战加时。
--   大文明间宣战 +20 秒（3 秒冷却）；剩余<10 秒时对城邦宣战 +8 秒（防卡秒顶城邦）。
-- ============================================================================
local function MPT_Timer_OnDeclareWar(firstPlayerID, secondPlayerID)
	if not MPT_IsMultiplayer or not MPT_TimerEnabled
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
-- MPT_Timer_OnPrePlayerDisconnected(playerID)：玩家掉线加时（房主自己掉线不处理）。
--   剩余<30 秒时 +30 秒并置加时标志（平衡时额外 +5 修正）。
-- ============================================================================
local function MPT_Timer_OnPrePlayerDisconnected(playerID)
	if not MPT_IsMultiplayer or not MPT_TimerEnabled then return; end
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
-- MPT_Timer_OnPlayerTurnEnd(ePlayer)：本地/远程玩家回合结束（两事件共用）。
--   统计真人结束回合比例 ≥0.5 时记录半数玩家用时（PID 反馈量，整回合只记首次）；
--   全部真人结束置投票阶段标志。ePlayer：RemotePlayerTurnEnd 传玩家 ID，
--   LocalPlayerTurnEnd 无参（本地兜底，1.67 同款）。
-- ============================================================================
local function MPT_Timer_OnPlayerTurnEnd(ePlayer)
	if not MPT_IsMultiplayer then return; end
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
-- MPT_Timer_OnPlayerTurnBegin(ePlayer)：本地/远程玩家回合开始（两事件共用）。
--   投票阶段（上回合全员结束时置位）：全员都开始新回合后把时间固定 120 秒（3 秒
--   冷却、真人>1）；正常回合：全员都在回合中（有玩家取消结束重开）→ 清空采样重新
--   记录。
-- ============================================================================
local function MPT_Timer_OnPlayerTurnBegin(ePlayer)
	if not MPT_IsMultiplayer then return; end
	ePlayer = ePlayer or Network.GetLocalPlayerID();

	if MPT_AllPlayerEndTurn then	-- 投票阶段
		if Network.GetLocalPlayerID() == Network.GetGameHostPlayerID() and MPT_TimerEnabled then
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
-- MPT_Timer_OnInputActionTriggered(actionId)：[ / ] 加减时热键（差异2：统一本机
--   开关门控——1.67 房主热键不受 TOOLS_COMMAND 限制）。
--   加时 ]：房主直接 +20 秒广播；非房主代发聊天指令 p++（由房主监听执行）。
--   减时 [：房主 -10 秒（下限 40 秒，触底换提示音）；非房主代发 p--。
-- ============================================================================
local function MPT_Timer_OnInputActionTriggered(actionId)
	if not MPT_IsMultiplayer or not MPT_TimerEnabled then return; end

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
-- MPT_Timer_UpdateButtonsVisibility()：刷新聊天框旁 P++/P-- 按钮显隐。
--   本机开关开启且联机时显示（优化9：1.67 经 Events.GameConfigChanged 随全局配置
--   同步，本地开关下改经 MPT_Settings_Toggle 广播驱动；XML 默认 Hidden 防闪现）。
--   Controls nil 守卫：设置面板 LoadScreenClose 的 ApplyAll 广播早于按钮挂载。
-- 用法：MPT_Timer_UpdateButtonsVisibility()
-- ============================================================================
local function MPT_Timer_UpdateButtonsVisibility()
	if Controls.AddTimeButton == nil or Controls.ReduceTimeButton == nil then return; end
	local hide :boolean = not (MPT_TimerEnabled and MPT_IsMultiplayer);
	Controls.AddTimeButton:SetHide(hide);
	Controls.ReduceTimeButton:SetHide(hide);
end

-- ===========================================================================
-- 设置接入：条目12 设置面板广播 LuaEvents.MPT_Settings_Toggle(ParameterId, Value)
--   （ParameterId 沿用 1.67 原 key TOOLS_COMMAND，默认 1=开启）。文件加载即订阅
--   （早于面板 LoadScreenClose 的 ApplyAll 全量广播，初始状态必达）；Controls nil
--   守卫保证广播先于按钮挂载到达时不崩脚。
-- ===========================================================================
LuaEvents.MPT_Settings_Toggle.Add(function(ParameterId, Value)
	if ParameterId == "TOOLS_COMMAND" then
		MPT_TimerEnabled = (Value == true or Value == 1);
		MPT_Timer_UpdateButtonsVisibility();
	end
end);

-- ============================================================================
-- MPT_Timer_LateInitialize()：LoadScreenClose 后初始化（1.67 同款时序——确保
--   WorldTracker 上下文已加载，ChangeParent 才有挂载点）。
--   ①按钮挂到聊天框容器并注册点击（所有玩家点击都发聊天指令，房主由自己的聊天
--     监听代执行）②刷显隐 ③订阅全部游戏事件。
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
	MPT_Timer_UpdateButtonsVisibility();

	Events.TurnTimerUpdated.Add(MPT_Timer_OnTurnTimerUpdated);
	Events.MultiplayerChat.Add(MPT_Timer_OnMultiplayerChat);
	Events.DiplomacyDeclareWar.Add(MPT_Timer_OnDeclareWar);
	Events.MultiplayerPrePlayerDisconnected.Add(MPT_Timer_OnPrePlayerDisconnected);
	Events.TurnEnd.Add(MPT_Timer_OnTurnEndBalance);
	Events.LocalPlayerTurnEnd.Add(MPT_Timer_OnPlayerTurnEnd);
	Events.RemotePlayerTurnEnd.Add(MPT_Timer_OnPlayerTurnEnd);
	Events.LocalPlayerTurnBegin.Add(MPT_Timer_OnPlayerTurnBegin);
	Events.RemotePlayerTurnBegin.Add(MPT_Timer_OnPlayerTurnBegin);
	Events.InputActionTriggered.Add(MPT_Timer_OnInputActionTriggered);
end

-- ============================================================================
-- MPT_Timer_Initialize()：上下文脚本入口——取热键动作 ID（InputActions 已入库）、
--   初始化回合状态、挂 LoadScreenClose 延迟初始化。
-- ============================================================================
local function MPT_Timer_Initialize()
	MPT_AddTimeActionId = Input.GetActionId("HotKey_MPT_TurnTimeAdd");
	MPT_ReduceTimeActionId = Input.GetActionId("HotKey_MPT_TurnTimeReduce");
	MPT_Timer_ResetVariables();
	Events.LoadScreenClose.Add(MPT_Timer_LateInitialize);
end
MPT_Timer_Initialize();
