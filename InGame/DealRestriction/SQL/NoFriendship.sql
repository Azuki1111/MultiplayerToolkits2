-- ============================================================================
-- 条目10：禁止宣布友谊执行 SQL（移植 1.67 DDV/SQL/mph_diplomacy_no_fs.sql，原作 MPH）
-- 配置 TPT_NO_FRIENDSHIP=1 时经 ActionCriteria Diplomatic_FS_Off 条件执行：
-- 从外交行为/状态行为/AI 偏好三表删除「宣布友谊」
-- ============================================================================
DELETE from DiplomaticActions 		WHERE DiplomaticActionType='DIPLOACTION_DECLARE_FRIENDSHIP';
DELETE from DiplomaticStateActions 	WHERE DiplomaticActionType='DIPLOACTION_DECLARE_FRIENDSHIP';
DELETE from AiFavoredItems 			WHERE Item='DIPLOACTION_DECLARE_FRIENDSHIP';
