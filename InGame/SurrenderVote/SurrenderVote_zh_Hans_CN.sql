-- ============================================================================
-- 条目8续：投降投票文本（zh_Hans_CN）
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_VOTE_TITLE',			'zh_Hans_CN',	'投降投票'),
	('LOC_MPT_VOTE_AGREE',			'zh_Hans_CN',	'同意'),
	('LOC_MPT_VOTE_DISAGREE',		'zh_Hans_CN',	'反对'),
	('LOC_MPT_VOTE_PROGRESS',		'zh_Hans_CN',	'进度 {1_Num}/{2_Num}'),
	('LOC_MPT_VOTE_NOT_STARTED',	'zh_Hans_CN',	'点击「投降」发起本队投降投票'),
	('LOC_MPT_VOTE_PASSED',			'zh_Hans_CN',	'本队已投降'),
	('LOC_MPT_VOTE_ALREADY',		'zh_Hans_CN',	'本时代已发起过投票'),
	('LOC_MPT_SURRENDER_TEAM',		'zh_Hans_CN',	'队伍已投降'),
	-- 发起投降按钮 tooltip（按状态显示原因）
	('LOC_MPT_SURRENDER_TT_DEFAULT',	'zh_Hans_CN',	'发起本队投降投票'),
	('LOC_MPT_SURRENDER_TT_OBSERVER',	'zh_Hans_CN',	'观察者不能发起投降投票'),
	('LOC_MPT_SURRENDER_TT_DEAD',		'zh_Hans_CN',	'已败亡，不能发起投降投票'),
	('LOC_MPT_SURRENDER_TT_ALREADY',	'zh_Hans_CN',	'本时代本队已发起过投票，下个时代才能再次发起'),
	('LOC_MPT_SURRENDER_TT_SURRENDERED','zh_Hans_CN',	'本队已投降'),
	-- 重新开始投票（条目8续2）文本
	('LOC_MPT_RESTART_TITLE',		'zh_Hans_CN',	'重新开始投票'),
	('LOC_MPT_RESTART_PASSED',		'zh_Hans_CN',	'重新开始已通过，游戏即将重启'),
	('LOC_MPT_RESTART_TT_DEFAULT',	'zh_Hans_CN',	'发起重新开始投票（投票过半后重启，地图相同）'),
	('LOC_MPT_RESTART_TT_OBSERVER',	'zh_Hans_CN',	'观察者不能发起重新开始投票'),
	('LOC_MPT_RESTART_TT_DEAD',		'zh_Hans_CN',	'已败亡，不能发起重新开始投票'),
	('LOC_MPT_RESTART_TT_SINGLE',	'zh_Hans_CN',	'单人局不能发起重新开始投票'),
	('LOC_MPT_RESTART_TT_PASSED',	'zh_Hans_CN',	'重新开始已通过，游戏即将重启'),
	('LOC_MPT_RESTART_TT_ALREADY',	'zh_Hans_CN',	'本时代已发起过重新开始投票'),
	('LOC_MPT_RESTART_TT_HOST_ONLY','zh_Hans_CN',	'仅房主可发起重新开始投票'),
	('LOC_MPT_RESTART_COUNTDOWN',	'zh_Hans_CN',	'重新开始倒计时：{1_Num} 秒');
