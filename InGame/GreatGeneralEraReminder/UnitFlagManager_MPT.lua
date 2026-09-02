-- ===========================================================================
-- 条目25：大将军时代提示（BER = Great General Era Reminder，移植联机工具箱 1.67
--   BER/UnitFlagManager_GreatGeneralEraReminder.lua，工坊 3693899014）
-- 大将军/海军统帅单位旗帜下沿显示所属时代名横幅。
-- 实现与 1.67 的差异（用户裁决「新建控件」方案）：1.67 复用晋升徽标控件（Promotion_Flag
--   换纹理 + UnitNumPromotions 改文字 + 还原分支），本移植改官方蛮族氏族 DLC 同款
--   「实例模板新建控件」：EraBanner.xml 声明 MPTEraBanner 模板（注册机制见其文件头——
--   AddUserInterfaces 指向 UnitFlagManager 子上下文，官方无先例的扩展用法，失败则静默
--   关闭）、EraBanner.lua 持实例池，本文件在旗标上下文内取还（照抄原版官方动态实例
--   模式：构建后挂 FlagRoot，UnitFlag.destroy 时 ReleaseInstanceByParent 归还）。
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
-- Import base file：按序尝试 DLC 变体到原版，探测到 Initialize 定义即停；目标文件未注册
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
-- Overrides
-- ===========================================================================
-- 大将军/海军统帅且有对应个体：取（或复用）横幅实例写时代名并显示；其余情形隐藏横幅。
--   self.m_Instance.MPT_Era 三态：nil = 尚未尝试构建（非将军或构建时机未到）；
--   false = 已尝试但模板不可用（AddUserInterfaces 合并注册失败，静默降级）；
--   table = EraBanner.lua 的实例表。
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
						if MPT_ERA_Acquire ~= nil then
							pEra = MPT_ERA_Acquire(self.m_Instance.FlagRoot) or false;
						else
							pEra = false;
						end
						self.m_Instance.MPT_Era = pEra;
					end
					if pEra ~= false then
						local eraType = GameInfo.GreatPersonIndividuals[individual].EraType;
						pEra.EraLabel:SetText(Locale.Lookup(GameInfo.Eras[eraType].Name));
						pEra.EraBanner:SetHide(false);
						MPT_BASE_UpdatePromotions(self);
						return;
					end
				end
			end
		end
	end
	if pEra ~= nil and pEra ~= false then
		pEra.EraBanner:SetHide(true);
	end
	MPT_BASE_UpdatePromotions(self);
end

-- ===========================================================================
-- 旗标销毁：先归还时代横幅（ReleaseInstanceByParent 按父控件回池），再走原版销毁，
--   防旗标实例回池复用时残留横幅子控件导致重复构建（原版官方同款收尾，见原版
--   UnitFlag.destroy 对 AttentionMarkerInstance 的处理）。
-- ===========================================================================
function UnitFlag.destroy( self )
	local pEra = self.m_Instance.MPT_Era;
	if pEra ~= nil and pEra ~= false then
		if MPT_ERA_Release ~= nil then
			MPT_ERA_Release(self.m_Instance.FlagRoot);
		end
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
