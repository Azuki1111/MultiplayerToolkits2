-- ============================================================================
-- 条目8续：投降投票文本（en_US）
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_VOTE_TITLE',			'en_US',	'Surrender Vote'),
	('LOC_MPT_VOTE_AGREE',			'en_US',	'Agree'),
	('LOC_MPT_VOTE_DISAGREE',		'en_US',	'Disagree'),
	('LOC_MPT_VOTE_PROGRESS',		'en_US',	'Progress {1_Num}/{2_Num}'),
	('LOC_MPT_VOTE_NOT_STARTED',	'en_US',	'Click Surrender to start a team surrender vote'),
	('LOC_MPT_VOTE_PASSED',			'en_US',	'Your team has surrendered'),
	('LOC_MPT_VOTE_ALREADY',		'en_US',	'A vote was already started this era'),
	('LOC_MPT_SURRENDER_TEAM',		'en_US',	'Team has surrendered'),
	-- Surrender button tooltips (reason by state)
	('LOC_MPT_SURRENDER_TT_DEFAULT',	'en_US',	'Start a team surrender vote'),
	('LOC_MPT_SURRENDER_TT_OBSERVER',	'en_US',	'Observers cannot start a surrender vote'),
	('LOC_MPT_SURRENDER_TT_DEAD',		'en_US',	'You have been defeated and cannot start a vote'),
	('LOC_MPT_SURRENDER_TT_ALREADY',	'en_US',	'A vote was already started this era; the next era unlocks it'),
	('LOC_MPT_SURRENDER_TT_SURRENDERED','en_US',	'Your team has already surrendered'),
	-- Restart vote (item 8-2) text
	('LOC_MPT_RESTART_TITLE',		'en_US',	'Restart Vote'),
	('LOC_MPT_RESTART_PASSED',		'en_US',	'Restart approved, game is restarting'),
	('LOC_MPT_RESTART_TT_DEFAULT',	'en_US',	'Start a restart vote'),
	('LOC_MPT_RESTART_TT_OBSERVER',	'en_US',	'Observers cannot start a restart vote'),
	('LOC_MPT_RESTART_TT_DEAD',		'en_US',	'You have been defeated and cannot start a restart vote'),
	('LOC_MPT_RESTART_TT_SINGLE',	'en_US',	'Single-player games cannot start a restart vote'),
	('LOC_MPT_RESTART_TT_PASSED',	'en_US',	'Restart approved, game is restarting'),
	('LOC_MPT_RESTART_TT_ALREADY',	'en_US',	'A restart vote was already started this era'),
	('LOC_MPT_RESTART_TT_HOST_ONLY','en_US',	'Only the host can start a restart vote'),
	('LOC_MPT_RESTART_COUNTDOWN',	'en_US',	'Restarting in {1_Num}s'),
	('LOC_MPT_RESTART_WAITING',		'en_US',	'Waiting for the host to restart…');
