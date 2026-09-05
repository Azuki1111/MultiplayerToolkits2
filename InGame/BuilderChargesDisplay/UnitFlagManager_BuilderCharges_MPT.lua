-- ===========================================================================
-- 条目25：工人劳动力查看助手（BCT = Builder Charges，移植联机工具箱 1.67
--   BCT/UnitFlagManager_BuilderCharges.lua，工坊 3693899014）——工人/军事工程师
--   单位旗帜晋升徽标位显示剩余劳动力（UnitNumPromotions 写充能数 + Promotion_Flag
--   显示），Events.UnitChargesChanged 即时刷新。
-- 注册：ImportFiles(100010) 以 MPT 命名登记（条目25规范，用户裁决：文件 _MPT 后缀；
--   条目25优化目录改描述性命名 BuilderChargesDisplay/）——UnitFlagManager_MPT.lua
--   （../GreatGeneralEraReminder/ 入口）的防御
--   include 链首环按此名探测命中，叠加链序 = 入口（大将军时代改造）→ 本文件
--   → BC → 原版，与 1.67 BER+BCT 同装形态一致（1.67 中 BER 10001 压过 BCT 4000 后
--   经链叠加）。与 1.67 同装：其 BCT 文件为另一 VFS 名（无 _MPT 后缀），链只探 MPT 名
--   不参与，无双重叠加。
-- 代码体 = 1.67 原样（Subscribe/Unsubscribe/GetUnitFlag 为上下文原版全局，保持原名
--   不做 MPT 化）。
-- ===========================================================================

-- =================================================================================
-- Import base file
-- =================================================================================
local files = {
    "UnitFlagManager_BarbarianClansMode.lua",
    "UnitFlagManager.lua",
}

for _, file in ipairs(files) do
    include(file)
    if Initialize then
        print("Loading " .. file .. " as base file");
        break
    end
end

-- =================================================================================
-- Cache base functions
-- =================================================================================
local BASE_Subscribe        = Subscribe;
local BASE_Unsubscribe      = Unsubscribe;
local BASE_UpdatePromotions	= UnitFlag.UpdatePromotions;

-- =================================================================================
-- Overrides
-- =================================================================================
function OnUnitChargesChanged(playerID, unitID)
    local flagInstance = GetUnitFlag(playerID, unitID);
    if flagInstance ~= nil then
        flagInstance:UpdatePromotions();
    end
end

function UnitFlag.UpdatePromotions(self)
    local unit = self:GetUnit();
    if unit ~= nil and unit:GetUnitType() ~= -1 then
        local unitType = GameInfo.Units[unit:GetUnitType()].UnitType;
        if unitType == "UNIT_BUILDER" or unitType == "UNIT_MILITARY_ENGINEER" then
            -- The unit is a builder or military engineer, try updating it's builder charges.
            local buildCharges = unit:GetBuildCharges();
            if buildCharges > 0 then
                -- Only need to update if has charges.
                self.m_Instance.UnitNumPromotions:SetText(buildCharges);
                self.m_Instance.Promotion_Flag:SetHide(false);
            end
            return;
        end
    end
    BASE_UpdatePromotions(self);
end

function Subscribe()
    BASE_Subscribe();
    Events.UnitChargesChanged.Add(OnUnitChargesChanged);
end

function Unsubscribe()
    BASE_Unsubscribe();
    Events.UnitChargesChanged.Remove(OnUnitChargesChanged);
end
