-- ============================================================================
-- 条目10：无法和解执行 SQL（移植 1.67 DDV/SQL/MAKE_PEACE_Disable.sql）
-- 配置 TPT_NO_MAKE_PEACE=NO_MAKE_PEACE 时经 ActionCriteria Diplomatic_MP_Off 条件执行：
-- 最短战争回合数拉到 9000（事实不可和解）+ 从外交行为/状态行为/AI 偏好三表删除「提议和平」
-- ============================================================================
UPDATE GlobalParameters SET Value='9000' WHERE Name='DIPLOMACY_WAR_MIN_TURNS';		-- 不可和解

DELETE from DiplomaticActions 		WHERE DiplomaticActionType='DIPLOACTION_PROPOSE_PEACE_DEAL';		-- 删除和解选项
DELETE from DiplomaticStateActions 	WHERE DiplomaticActionType='DIPLOACTION_PROPOSE_PEACE_DEAL';
DELETE from AiFavoredItems 			WHERE Item='DIPLOACTION_PROPOSE_PEACE_DEAL';
