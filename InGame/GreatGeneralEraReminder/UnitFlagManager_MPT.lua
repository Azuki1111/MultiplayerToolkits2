-- ===========================================================================
-- 条目25：大将军时代提示（BER = Great General Era Reminder，移植联机工具箱 1.67
--   BER/UnitFlagManager_GreatGeneralEraReminder.lua，工坊 3693899014）
-- 大将军/海军统帅单位旗帜下沿显示所属时代名横幅。
-- 实现与 1.67 的差异（用户裁决「新建控件」方案）：1.67 复用晋升徽标控件（Promotion_Flag
--   换纹理 + UnitNumPromotions 改文字 + 还原分支），本移植改「新建控件」：横幅池由
--   EraBanner.xml 预声明 40 面唯一 ID 横幅（EraBanner_1..40，注册机制见其文件头——
--   AddUserInterfaces 注册进 InGame 成为迷你上下文，寻址路径
--   /InGame/AdditionalUserInterfaces/EraBanner/MPT_ERA_Pool）。
--   取挂协议（条目25修复定稿）：本文件（旗标上下文）按路径 ContextPtr:LookUpControl
--   取横幅代理 → ChangeParent 挂旗标 FlagRoot，此后代理常驻本状态直读直写零跨状态调用；
--   归还 = SetHide 后 ChangeParent 回池容器（原版先例 PartialScreenHooks.lua 64 行按名
--   寻址 AdditionalUserInterfaces 下追加上下文；FEB 证实 ChangeParent 后原状态代理与
--   显示均持续有效）。原版官方同款参照：AttentionMarkerInstance 构建后挂 FlagRoot、
--   UnitFlag.destroy 时按父控件归还，旗标实例回收复用零残留零重复构建。
--   好处：原版晋升徽标零改动（base 无条件调用，大将军无经验槽其徽标自然隐藏）、
--   无 1.67 的还原分支（1.67 关开关后已改造旗帜永不还原，本方案每次刷新幂等 SetHide）。
-- 注册：ReplaceUIScript 100000 + ImportFiles 100010 整文件替换 UnitFlagManager 上下文
--   （原版无通配 include 钩子，同条目15/17/21/22/24 模式；LoadOrder 压过 1.67 BER 的
--   10001——同装时其 BER 上下文不再加载，其设置面板的 BER 开关失联属预期，开关以
--   本 mod 条目12 面板为准）。
-- 开关：条目12 MPT_Settings 表 GreatGeneralEraReminder_Show（沿用 1.67 原 key，默认开），
--   LoadScreenClose 面板 ApplyAll 广播送达初值，勾选变化即时广播。
-- ===========================================================================
-- Copyright 2017-2019, Firaxis Games.
-- Unit Flag Manager：管理世界地图上所有单位的 2D 旗帜（承继原版上下文脚本职责）
-- ===========================================================================

-- ===========================================================================
-- Import base file
-- 沿 1.67 BER：按序尝试 DLC 变体到原版，探测到 Initialize 定义即停；目标文件未注册
-- 或不存在时 include 静默跳过（BuilderCharges 为未安装 DLC 包预留位）。BC 变体自身
-- 会 include 原版并叠加其覆写，本文件在其外再包一层，链序：本文件 → BC → 原版。
-- 原版全局（g_Units* 等）与库 include 均由链内 base 文件自带，此处不重复。
-- ===========================================================================
local files = {
	"UnitFlagManager_BuilderCharges.lua",
	"UnitFlagManager_BarbarianClansMode.lua",
	"UnitFlagManager.lua",
}

for _, file in ipairs(files) do
	include(file);
	if Initialize then
		print("Loading " .. file .. " as base file");
		break
	end
end

-- ===========================================================================
-- Cache base functions
-- ===========================================================================
local MPT_BASE_UpdatePromotions = UnitFlag.UpdatePromotions;
local MPT_BASE_FlagDestroy = UnitFlag.destroy;

-- ===========================================================================
-- 条目25 设置开关
-- 默认 false，初值经条目12 面板 LoadScreenClose ApplyAll 广播送达（与 1.67 同款时序）
-- ===========================================================================
local MPT_Show_BER = false;

-- ===========================================================================
-- 条目25 横幅池取还
-- 池路径候选：EraBanner 迷你上下文在 AdditionalUserInterfaces 下的节点名 = 文件名
--   （InGame.lua 348 行以 ContextPath 无扩展名末段为 ID，RevealMapCorners 同机制实证）；
--   第二候选防注册形态变化。懒解析一次并缓存；解析失败静默降级（功能关闭不崩）。
-- ===========================================================================
local MPT_ERA_POOL_SIZE = 40;		-- 池容量：20 人房 × 大将军/海军统帅两类同屏上限
local MPT_ERA_Used = {};			-- [k] = true 占用表（本状态自持，旗标销毁归还）
local MPT_ERA_PoolPath = false;		-- false = 未解析 / nil = 解析失败 / string = 池路径
local MPT_ERA_PoolCtrl = nil;		-- 池容器控件（归还时的 ChangeParent 目标）

local MPT_ERA_POOL_CANDIDATES = {
	"/InGame/AdditionalUserInterfaces/EraBanner/MPT_ERA_Pool",
	"/InGame/MPT_ERA_Pool",
};

-- 懒解析池路径与池控件（首次取横幅时探测一次）
local function MPT_ERA_ResolvePool()
	if MPT_ERA_PoolPath == false then
		MPT_ERA_PoolPath = nil;
		for _, sPath in ipairs(MPT_ERA_POOL_CANDIDATES) do
			local pCtrl = ContextPtr:LookUpControl(sPath);
			if pCtrl ~= nil then
				MPT_ERA_PoolPath = sPath;
				MPT_ERA_PoolCtrl = pCtrl;
				break;
			end
		end
		print("MPT_ERA: pool resolve = " .. tostring(MPT_ERA_PoolPath));	-- 条目25修复诊断，实测确认后删
	end
	return MPT_ERA_PoolPath;
end

-- 取一面空闲横幅改挂到 pFlagRoot（旗标实例的 FlagRoot）下。
--   返回 {k=序号, Banner=横幅, Label=文字} 或 nil（池不可用/耗尽——静默无横幅）。
--   显隐与文字由调用方在每次刷新时幂等设置，本函数只负责取用与挂载。
function MPT_ERA_Take(pFlagRoot)
	local sPath = MPT_ERA_ResolvePool();
	if sPath == nil then
		return nil;
	end
	for k = 1, MPT_ERA_POOL_SIZE, 1 do
		if MPT_ERA_Used[k] == nil then
			local pBanner = ContextPtr:LookUpControl(sPath .. "/EraBanner_" .. k);
			local pLabel = ContextPtr:LookUpControl(sPath .. "/EraBanner_" .. k .. "/EraLabel_" .. k);
			if pBanner ~= nil and pLabel ~= nil then
				MPT_ERA_Used[k] = true;
				pBanner:ChangeParent(pFlagRoot);
				return { k = k, Banner = pBanner, Label = pLabel };
			end
			return nil;	-- 池在而横幅缺（XML 与本文件约定不一致），不再尝试其余序号
		end
	end
	return nil;	-- 池耗尽
end

-- 归还横幅回池（旗标销毁时调用；先隐藏再 ChangeParent 回池容器）
function MPT_ERA_GiveBack(pEra)
	if MPT_ERA_PoolCtrl ~= nil then
		pEra.Banner:SetHide(true);
		pEra.Banner:ChangeParent(MPT_ERA_PoolCtrl);
	end
	MPT_ERA_Used[pEra.k] = nil;
end

-- ===========================================================================
-- Overrides
-- ===========================================================================
-- 大将军/海军统帅且有对应个体：取（或复用）横幅写时代名并显示；其余情形隐藏横幅。
--   self.m_Instance.MPT_Era 三态：nil = 尚未尝试取用（非将军或取用时机未到）；
--   false = 已尝试但池不可用/耗尽（静默降级）；table = MPT_ERA_Take 的横幅表。
--   base 无条件调用：原版晋升徽标逻辑零改动，征调/晋升计数显示不受影响。
-- ===========================================================================
function UnitFlag.UpdatePromotions( self )
	local pEra = self.m_Instance.MPT_Era;
	if MPT_Show_BER then
		local unit = self:GetUnit();
		if unit ~= nil and unit:GetUnitType() ~= -1 then
			local unitType = GameInfo.Units[unit:GetUnitType()].UnitType;
			if unitType == "UNIT_GREAT_GENERAL" or unitType == "UNIT_GREAT_ADMIRAL" then
				local individual = unit:GetGreatPerson():GetIndividual();
				if individual >= 0 then
					if pEra == nil then
						pEra = MPT_ERA_Take(self.m_Instance.FlagRoot) or false;
						self.m_Instance.MPT_Era = pEra;
					end
					if pEra ~= false then
						local eraType = GameInfo.GreatPersonIndividuals[individual].EraType;
						pEra.Label:SetText(Locale.Lookup(GameInfo.Eras[eraType].Name));
						pEra.Banner:SetHide(false);
						MPT_BASE_UpdatePromotions(self);
						return;
					end
				end
			end
		end
	end
	if pEra ~= nil and pEra ~= false then
		pEra.Banner:SetHide(true);
	end
	MPT_BASE_UpdatePromotions(self);
end

-- ===========================================================================
-- 旗标销毁：先归还时代横幅（隐藏 + ChangeParent 回池），再走原版销毁，防旗标实例
--   回池复用时残留横幅子控件导致重复取用（原版官方同款收尾，见原版 UnitFlag.destroy
--   对 AttentionMarkerInstance 的处理）。
-- ===========================================================================
function UnitFlag.destroy( self )
	local pEra = self.m_Instance.MPT_Era;
	if pEra ~= nil and pEra ~= false then
		MPT_ERA_GiveBack(pEra);
		self.m_Instance.MPT_Era = nil;
	end
	MPT_BASE_FlagDestroy(self);
end

-- ===========================================================================
-- 条目25 开关广播（条目12 MPT_Settings 面板：LoadScreenClose ApplyAll 送达初值，
--   勾选变化即时广播）
-- ===========================================================================
function OnMPT_Settings_Toggle( ParameterId, Value )
	if ParameterId == "GreatGeneralEraReminder_Show" then
		MPT_Show_BER = Value;
	end
end
LuaEvents.MPT_Settings_Toggle.Add(OnMPT_Settings_Toggle);
