-- ============================================================================
-- 条目10：无代表团执行 SQL（移植 1.67 DDV/SQL/TPT_Diplomacy_No_delegation.sql）
-- 配置 TPT_NO_DELEGATION=1 时经 ActionCriteria Diplomatic_delegation_Off 条件执行：
-- 从外交行为/状态行为/AI 偏好三表删除「派遣代表团」（大使馆不受影响）
-- ============================================================================
DELETE from DiplomaticActions 		WHERE DiplomaticActionType='DIPLOACTION_DIPLOMATIC_DELEGATION';
DELETE from DiplomaticStateActions 	WHERE DiplomaticActionType='DIPLOACTION_DIPLOMATIC_DELEGATION';
DELETE from AiFavoredItems 			WHERE Item='DIPLOACTION_DIPLOMATIC_DELEGATION';
