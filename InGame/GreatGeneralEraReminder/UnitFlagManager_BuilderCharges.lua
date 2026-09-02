-- ===========================================================================
-- 条目25：工人劳动力查看助手（BCT = Builder Charges，移植联机工具箱 1.67
--   BCT/UnitFlagManager_BuilderCharges.lua，工坊 3693899014）——工人/军事工程师
--   单位旗帜晋升徽标位显示剩余劳动力（UnitNumPromotions 写充能数 + Promotion_Flag
--   显示），Events.UnitChargesChanged 即时刷新。
-- 注册：ImportFiles(100010) 以 VFS 原名 UnitFlagManager_BuilderCharges.lua 登记——
--   UnitFlagManager_MPT.lua 的防御 include 链（1.67 BER 原样）首环按文件名探测命中，
--   叠加链序 = 本文件入口（BER 大将军时代改造）→ BCT → BC → 原版，与 1.67 BER+BCT
--   同装形态一致（1.67 中 BER 10001 压过 BCT 4000 后经链叠加）。
-- 与 1.67 同装：双方 ImportFiles 同名文件，本 mod LoadOrder 100010 压过其注册，
--   内容一致幂等。代码体 = 1.67 原样（Subscribe/Unsubscribe/GetUnitFlag 为上下文
--   原版全局，保持原名不做 MPT 化）。
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
