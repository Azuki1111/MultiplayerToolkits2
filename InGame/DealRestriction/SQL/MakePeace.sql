-- ============================================================================
-- 条目10：允许和解执行 SQL（移植 1.67 DDV/SQL/MAKE_PEACE.sql）
-- 配置 TPT_NO_MAKE_PEACE=CAN_MAKE_PEACE 时经 ActionCriteria Diplomatic_MP_ON 条件执行：
-- 恢复原版最短战争回合数（LoadOrder 999999 强制后置，压过其他 mod 的改动）
-- ============================================================================
UPDATE GlobalParameters SET Value='10' WHERE Name='DIPLOMACY_WAR_MIN_TURNS';		-- 恢复至原版
