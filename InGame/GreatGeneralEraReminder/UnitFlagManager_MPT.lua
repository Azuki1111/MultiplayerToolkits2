-- ===========================================================================
-- 条目25：大将军时代提示（BER = Great General Era Reminder，移植联机工具箱 1.67
--   BER/UnitFlagManager_GreatGeneralEraReminder.lua，工坊 3693899014）
-- 大将军/海军统帅单位旗帜下沿显示所属时代名横幅；include 链首环叠加同批移植的
--   1.67 BCT 工人劳动力显示（../BuilderChargesDisplay/UnitFlagManager_BuilderCharges_MPT.lua，
--   与 1.67 BER+BCT 同装形态一致，未装 1.67 也自洽）。
-- 方案留痕（用户裁决）：回归 1.67 原版「复用晋升徽标控件改造」方案并原样保留——
--   Promotion_Flag 换 ActionPanel_TurnTimerFrame 纹理 + UnitNumPromotions 写时代名 +
--   非将军时按锚点判定还原；此前两轮「新建控件绑定父控件」实验（AddUserInterfaces
--   注入旗标上下文 / InGame 迷你上下文 + LookUpControl 路径取用 ChangeParent 挂载）
--   均实测未生效（引擎 addin 机制 = InGame.lua 348 行 LoadNewContext 硬编码挂 InGame
--   的 AdditionalUserInterfaces 成为独立 Lua 状态迷你上下文，模板/控件无法为旗标上下文
--   所用；git 条目25 两次提交留痕），实验文件已删除。
-- 注册：ReplaceUIScript 100000 + ImportFiles 100010 整文件替换 UnitFlagManager 上下文
--   （原版无通配 include 钩子，同条目15/17/21/22/24 模式；LoadOrder 压过 1.67 BER 10001
--   与 BCT 4000——同装时其两上下文均不再加载，其面板 BER 开关不再联动，开关以本 mod
--   条目12 面板为准；其 BCT 文件因链只探 MPT 名而不参与，功能由本 mod 同名 MPT 文件供给）。
-- 目录/命名（条目25优化，用户裁决）：目录改项目描述性命名——本文件 InGame/GreatGeneralEraReminder/，
--   BCT 文件 InGame/BuilderChargesDisplay/UnitFlagManager_BuilderCharges_MPT.lua（目录名
--   不参与加载机制，文件名保持功能性 MPT 名：LuaReplace 名 / include 链探测名，不随目录改）。
-- 开关：条目12 MPT_Settings 表 GreatGeneralEraReminder_Show（沿用 1.67 原 key，默认开），
--   LoadScreenClose 面板 ApplyAll 广播送达初值，勾选变化即时广播，单通道
--   MPT_Settings_Toggle（本 mod 自有事件，不联动 1.67）。
-- ===========================================================================
-- Copyright 2017-2019, Firaxis Games.
-- Unit Flag Manager：管理世界地图上所有单位的 2D 旗帜（承继原版上下文脚本职责）
-- ===========================================================================

-- ===========================================================================
-- Import base file
-- 沿 1.67 BER：按序尝试变体到原版，探测到 Initialize 定义即停；目标文件未注册或
-- 不存在时 include 静默跳过。首环 = 条目25 移植的 1.67 BCT 工人劳动力显示（MPT 命名，
-- 本 mod ImportFiles 注册）；BC 变体自身会 include 原版并叠加其覆写，本文件在其外再
-- 包一层，链序：本文件 → BCT → BC → 原版。
-- 原版全局（g_Units* 等）与库 include 均由链内 base 文件自带，此处不重复。
-- ===========================================================================
local files = {
	"UnitFlagManager_BuilderCharges_MPT.lua",
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

-- ===========================================================================
-- 条目25 设置开关
-- 默认 false，初值经条目12 面板 LoadScreenClose ApplyAll 广播送达（与 1.67 同款时序）
-- ===========================================================================
local Show_BER = false;

-- ===========================================================================
-- Overrides
-- ===========================================================================
-- 大将军/海军统帅且有对应个体：晋升徽标位改造为时代名横幅（Promotion_Flag 换
--   ActionPanel_TurnTimerFrame 纹理、UnitNumPromotions 写时代名，1.67 原样），return
--   短路不走 base；非将军且徽标曾被改造（锚点 C,B 判定）→ 还原原版纹理/锚点/尺寸。
--   1.67 原样逻辑（含还原分支在 Show_BER 门控内的原版行为，忠实移植不做修正）。
-- ===========================================================================
function UnitFlag.UpdatePromotions(self)
	if Show_BER then
		local unit = self:GetUnit();
		if unit ~= nil and unit:GetUnitType() ~= -1 then
			local unitType = GameInfo.Units[unit:GetUnitType()].UnitType;
			if unitType == "UNIT_GREAT_GENERAL" or unitType == "UNIT_GREAT_ADMIRAL" then
				local individual = unit:GetGreatPerson():GetIndividual();
				if individual >= 0 then
					local EraType = GameInfo.GreatPersonIndividuals[individual].EraType;
					local EraText = "[Size_14]"..Locale.Lookup(GameInfo.Eras[EraType].Name)
					self.m_Instance.UnitNumPromotions:SetText(EraText);
					self.m_Instance.UnitNumPromotions:SetColor(1,1,1)
					self.m_Instance.UnitNumPromotions:SetOffsetVal(0,1)
					self.m_Instance.Promotion_Flag:SetHide(false);
					self.m_Instance.Promotion_Flag:SetTexture("ActionPanel_TurnTimerFrame");
					self.m_Instance.Promotion_Flag:SetAnchor("C,B")
					self.m_Instance.Promotion_Flag:SetOffsetVal(0,-6)
					self.m_Instance.Promotion_Flag:SetSizeVal(110, 20)
					return;
				end
			else
				if self.m_Instance.Promotion_Flag:GetAnchor() == "C,B" then
					self.m_Instance.UnitNumPromotions:SetColor(0,0,0)
					self.m_Instance.UnitNumPromotions:SetOffsetVal(0,0)
					self.m_Instance.Promotion_Flag:SetTexture("UnitFlag_Promo.dds");
					self.m_Instance.Promotion_Flag:SetAnchor("R,C")
					self.m_Instance.Promotion_Flag:SetOffsetVal(-8,0)
					self.m_Instance.Promotion_Flag:SetSizeVal(20,25)
				end
			end
		end
	end
	MPT_BASE_UpdatePromotions(self)
end

-- ===========================================================================
-- 条目25 开关广播（条目12 MPT_Settings 面板单通道：LoadScreenClose ApplyAll 送达初值，
--   勾选变化即时广播）
-- ===========================================================================
function OnMPT_Settings_Toggle( ParameterId, Value )
	if ParameterId == "GreatGeneralEraReminder_Show" then
		Show_BER = Value;
	end
end
LuaEvents.MPT_Settings_Toggle.Add(OnMPT_Settings_Toggle);
