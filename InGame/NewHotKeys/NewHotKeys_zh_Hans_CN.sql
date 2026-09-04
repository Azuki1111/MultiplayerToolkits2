-- ============================================================================
-- 条目28：更多快捷键（NHK）文本（zh_Hans_CN 简体中文）
-- 动作名/描述：设置→按键绑定列表显示（前后端各注册，主菜单也要显示）；
--   开关文案：高级选项「更多快捷键」复选框。
-- tag 沿用策略（条目16/24 先例）：与 1.65 共享的动作沿用 1.65 原 tag（zh 照抄原文案，
--   本 mod 补 en），DMT 类 tag 为 DMT 地图钉 mod 原名（同装幂等）；CHS 专属动作内嵌
--   中文不可本地化，改用 LOC_MPT_NHK_* 自造 tag；Corps/Army/Wake/Teleport/升级/晋升/
--   取消走原版现成 tag（不重复登记）。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText(Tag, Language, Text)
VALUES
	('LOC_MPT_NEW_HOTKEYS_NAME',							'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]更多快捷键[ENDCOLOR]'),
	('LOC_MPT_NEW_HOTKEYS_DESC',							'zh_Hans_CN',	'启用后本条目的单位快捷键可用：掠夺/升级/晋升/取消等 13 个单位命令热键与随机晋升[newline][newline]自动招募伟人、强制结束回合、地图钉与城市远程攻击不受此开关影响'),
	('LOC_TPT_UNITCOMMAND_PROMOTE_OR_REPAIR_NAME',			'zh_Hans_CN',	'掠夺'),
	('LOC_TPT_UNITCOMMAND_PROMOTE_OR_REPAIR_DESC',			'zh_Hans_CN',	'掠夺或修理单元格'),
	('LOC_FAST_PROMOTE_NAME',								'zh_Hans_CN',	'随机升级'),
	('LOC_FAST_PROMOTE_DESC',								'zh_Hans_CN',	'快速随机选择一项升级，不需要点击升级树'),
	('LOC_TURNTIME_FORCED_TURNEND_NAME',					'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]强制结束回合[ENDCOLOR]'),
	('LOC_TURNTIME_FORCED_TURNEND_DESCRIPTION',				'zh_Hans_CN',	'立即结束回合并进入自动模式，此后每回合自动结束，再按一次取消'),
	('LOC_HOTKEY_AUTO_RECRUIT_NAME',						'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]切换自动招募伟人[ENDCOLOR]'),
	('LOC_HOTKEY_AUTO_RECRUIT_DESCRIPTION',					'zh_Hans_CN',	'切换至自动招募模式，符合条件时自动招募伟人[newline][newline]你是唯一可招募或点数最高时'),
	('LOC_DMT_OPTIONS_HOTKEY_CATEGORY',						'zh_Hans_CN',	'地图钉'),
	('LOC_DMT_OPTIONS_HOTKEY_ADD_MESSAGE_TACK',				'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]发送聊天坐标[ENDCOLOR]'),
	('LOC_DMT_OPTIONS_HOTKEY_ADD_MAP_TACK',					'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]添加地图钉[ENDCOLOR]'),
	('LOC_DMT_OPTIONS_HOTKEY_DELETE_MAP_TACK',				'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]删除地图钉[ENDCOLOR]'),
	('LOC_DMT_OPTIONS_HOTKEY_TOGGLE_MAP_TACK_VISIBILITY_NAME',	'zh_Hans_CN',	'[COLOR:ResGoldLabelCS]显示/隐藏所有地图钉[ENDCOLOR]'),
	('LOC_DMT_OPTIONS_HOTKEY_TOGGLE_MAP_TACK_VISIBILITY_DESC',	'zh_Hans_CN',	'显示/隐藏所有地图钉'),
	('LOC_MPT_NHK_PILLAGE_ROAD_NAME',						'zh_Hans_CN',	'破坏/修复道路'),
	('LOC_MPT_NHK_PILLAGE_ROAD_DESC',						'zh_Hans_CN',	'破坏或修复道路/建立贸易路线'),
	('LOC_MPT_NHK_PLUNDER_ROUTE_NAME',						'zh_Hans_CN',	'掠夺贸易路线'),
	('LOC_MPT_NHK_PLUNDER_ROUTE_DESC',						'zh_Hans_CN',	'掠夺贸易路线'),
	('LOC_MPT_NHK_FORMATION_NAME',							'zh_Hans_CN',	'绑定或解绑单位'),
	('LOC_MPT_NHK_FORMATION_DESC',							'zh_Hans_CN',	'绑定或解绑单位（编队/解编）'),
	('LOC_MPT_NHK_REMOVE_FEATURE_NAME',						'zh_Hans_CN',	'删除地貌'),
	('LOC_MPT_NHK_REMOVE_FEATURE_DESC',						'zh_Hans_CN',	'移除格位上的地貌（砍伐森林、疏浚沼泽等）并获得对应产出'),
	('LOC_MPT_NHK_HARVEST_NAME',							'zh_Hans_CN',	'收获资源'),
	('LOC_MPT_NHK_HARVEST_DESC',							'zh_Hans_CN',	'收获格位上的可收获资源（鹿、石头等）并获得对应产出');
