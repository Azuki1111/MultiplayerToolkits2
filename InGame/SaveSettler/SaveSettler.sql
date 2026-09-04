-- 条目33：拯救开拓者数据（移植工坊 2963626794 号码菌 SaveSettler）——给开拓者加上原版
-- 伟人/考古学家同款 CanRetreatWhenCaptured 列（01_GameplaySchema.sql L2861，默认 0）：
-- 被敌军擒获时撤退回城而非被抢走；随行 Lua（SaveSettler_Gameplay.lua）监听
-- OnUnitRetreated 实现回城所在城市人口-2 惩罚（条目33调整：任何时候都扣）。
-- modinfo 同名 criteria 门控，不勾选零改动。
UPDATE Units SET CanRetreatWhenCaptured=1 WHERE UnitType='UNIT_SETTLER';
