-- ============================================================================
-- 条目33：拯救开拓者（Gameplay 侧）
--
-- 移植工坊 2963626794 SaveSettler（号码菌）：SaveSettler.sql（同 criteria 门控）给
-- 开拓者加上原版伟人/考古学家同款 CanRetreatWhenCaptured 数据列
--（01_GameplaySchema.sql L2861，默认 0），被敌军擒获时不再被抢走而是撤退回城；本脚本
-- 监听引擎事件 GameEvents.OnUnitRetreated（亚历山大剧本官方用例，签名 owner+unitID），
-- 对撤退的开拓者：所在城市人口 -2，漂浮文本「开拓者返回了城市 / 城市人口-2」。
--
-- 条目33调整（用户裁决）：废止源实现「城市数 >= 3 时移除开拓者」分支——任何时候
-- 撤退回城都只扣 2 人口，开拓者永不移除（STR_DIED 文本与 UnitManager.Kill 路径已随
-- 本次调整清零）。
--
-- 相对源实现的三项修正（源实现无 nil 防御、硬编码中文、GetName 字符串比对）：
--   1. 开拓者判定 = UnitManager.GetTypeName(unit) == "UNIT_SETTLER"（原版
--      TutorialUIRoot L2437 同款类型名判定）；上下文无此函数时回退源实现的
--      GetName == "LOC_UNIT_SETTLER_NAME" 比对。自带撤退列的伟人/考古学家等
--      同样会进本事件，必须过滤。
--   2. FindID/pPlayer/pUnit/pCity 全链 nil 防御（源实现 GetName 在 nil 检查之前
--      调用，撤退单位已消亡时直接报错中断）。
--   3. 漂浮文本走 SQL 本地化（LOC tag 预加载 + Locale.Lookup，黑死病剧本
--      Gameplay 脚本同款用法）；颜色沿用源实现 ResGoldLabelCS（原版内置样式），
--      写在 SQL 文本内；开头空行文本为源实现的垂直留白 hack，原样保留。
--
-- 边界：撤退点无城市（pCity == nil，理论边界：撤退应落城内）时跳过人口惩罚
-- 保留单位——源实现在此必报错。
--
-- 确定性（联机无 OOS）：OnUnitRetreated 在确定性模拟中触发，全机同回合收到同一
-- 事件序列，分支判定与模拟变更（人口）各客户端一致；AddWorldViewText 仅本地
-- 视觉不入模拟。全房需同装本 mod（条目4.1 校验保证）。
-- ============================================================================

-- 漂浮文本预加载（脚本载入时 IG UpdateText 已就绪；无参数纯文本直接缓存）
local STR_RETURNED :string = Locale.Lookup("LOC_MPT_SAVESETTLER_RETURNED");
local STR_POP_LOSS :string = Locale.Lookup("LOC_MPT_SAVESETTLER_POPLOSS");

-- ============================================================================
-- 撤退事件主逻辑：过滤出开拓者后所在城市人口 -2（任何时候都扣，见条目33调整）
-- ============================================================================
local function MPT_SaveSettler_OnUnitRetreated(unitOwner :number, unitID :number)
	local pPlayer = Players[unitOwner];
	if pPlayer == nil then
		return;
	end
	local pUnit = pPlayer:GetUnits():FindID(unitID);
	if pUnit == nil then
		return;
	end

	-- 开拓者判定：原版教程脚本同款类型名判定，不可用时回退源实现的 GetName 比对
	local isSettler :boolean = false;
	if UnitManager.GetTypeName ~= nil then
		isSettler = (UnitManager.GetTypeName(pUnit) == "UNIT_SETTLER");
	else
		isSettler = (pUnit:GetName() == "LOC_UNIT_SETTLER_NAME");
	end
	if not isSettler then
		return;
	end

	local iX :number = pUnit:GetX();
	local iY :number = pUnit:GetY();

	-- 保开拓者代价：所在城市人口 -2（撤退点无城市则跳过惩罚保留单位，见边界说明）
	local pCity = CityManager.GetCityAt(iX, iY);
	if pCity ~= nil then
		pCity:ChangePopulation(-2);
		Game.AddWorldViewText(0, " ", iX, iY);
		Game.AddWorldViewText(0, STR_RETURNED, iX, iY);
		Game.AddWorldViewText(0, STR_POP_LOSS, iX, iY);
	end
end

GameEvents.OnUnitRetreated.Add(MPT_SaveSettler_OnUnitRetreated);

print("[MPT_SaveSettler] Gameplay script initialized (settler retreat protection enabled).");
