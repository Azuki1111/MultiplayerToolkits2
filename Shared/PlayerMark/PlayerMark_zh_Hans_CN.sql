-- ============================================================================
-- 联机工具箱2.0 玩家标记管理文本（zh_Hans_CN 简体中文）
-- 规范：本文件为条目4.4 玩家标记管理功能专属文本（纯本地玩家档案，无数据表），
--       仅在 FrontEnd 上下文注册（面板仅前端使用），不进游戏内上下文。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- 入口按钮/面板标题
('LOC_MPT_PLAYERMARK_NAME', 'zh_Hans_CN', '玩家标记'),
('LOC_MPT_PLAYERMARK_TOOLTIP', 'zh_Hans_CN', '打开玩家标记管理面板'),
('LOC_MPT_PLAYERMARK_TITLE', 'zh_Hans_CN', '玩家标记管理'),
-- 条目4.8续：隐身开关（头部复选框）
('LOC_MPT_PLAYERMARK_HIDDEN_MARK', 'zh_Hans_CN', '隐藏我的标记'),
('LOC_MPT_PLAYERMARK_HIDDEN_MARK_TT', 'zh_Hans_CN', '默认情况下，其他玩家看不到你的特殊标记；取消勾选后广播「允许显示」，他人才可见'),
-- 条目4.9：左列双页签
('LOC_MPT_PLAYERMARK_TAB_SAVED', 'zh_Hans_CN', '存储标签'),
('LOC_MPT_PLAYERMARK_TAB_ROOM', 'zh_Hans_CN', '房间玩家'),
('LOC_MPT_PLAYERMARK_EMPTY_ROOM', 'zh_Hans_CN', '当前房间没有可标记的玩家'),
-- 搜索框（占位文本/提示）
('LOC_MPT_PLAYERMARK_SEARCH_NAME', 'zh_Hans_CN', '搜索昵称或ID'),
('LOC_MPT_PLAYERMARK_SEARCH_TT', 'zh_Hans_CN', '按昵称或 NetworkIdentifier 过滤左侧列表'),
-- 三个过滤复选框（默认全勾选）
('LOC_MPT_PLAYERMARK_FILTER_FRIEND', 'zh_Hans_CN', '好友'),
('LOC_MPT_PLAYERMARK_FILTER_NORMAL', 'zh_Hans_CN', '一般'),
('LOC_MPT_PLAYERMARK_FILTER_BLACK', 'zh_Hans_CN', '黑名单'),
('LOC_MPT_PLAYERMARK_FILTER_FRIEND_TT', 'zh_Hans_CN', '在列表中显示/隐藏好友标记的玩家'),
('LOC_MPT_PLAYERMARK_FILTER_NORMAL_TT', 'zh_Hans_CN', '在列表中显示/隐藏一般标记的玩家'),
('LOC_MPT_PLAYERMARK_FILTER_BLACK_TT', 'zh_Hans_CN', '在列表中显示/隐藏黑名单标记的玩家'),
-- 排序切换按钮（当前状态文案，点击切换方向）
('LOC_MPT_PLAYERMARK_SORT_DESC', 'zh_Hans_CN', '最新修改在前'),
('LOC_MPT_PLAYERMARK_SORT_ASC', 'zh_Hans_CN', '最早修改在前'),
('LOC_MPT_PLAYERMARK_SORT_TT', 'zh_Hans_CN', '按最近修改日期排序，点击切换升/降序'),
-- 添加按钮与弹窗
('LOC_MPT_PLAYERMARK_ADD', 'zh_Hans_CN', '添加玩家'),
('LOC_MPT_PLAYERMARK_MARK_THIS_TT', 'zh_Hans_CN', '点击将该玩家加入玩家标记'),
('LOC_MPT_PLAYERMARK_POPUP_TITLE', 'zh_Hans_CN', '添加玩家'),
('LOC_MPT_PLAYERMARK_POPUP_ID_TT', 'zh_Hans_CN', '玩家的网络标识：Steam 为 17 位纯数字，Epic 为 32 位字符'),
('LOC_MPT_PLAYERMARK_POPUP_NAME_TT', 'zh_Hans_CN', '备注用昵称，仅作显示，可随时修改'),
('LOC_MPT_PLAYERMARK_CREATE', 'zh_Hans_CN', '创建'),
-- 右侧字段标签
('LOC_MPT_PLAYERMARK_FIELD_ID', 'zh_Hans_CN', 'NetworkIdentifier'),
('LOC_MPT_PLAYERMARK_FIELD_NAME', 'zh_Hans_CN', '昵称'),
('LOC_MPT_PLAYERMARK_FIELD_TAG', 'zh_Hans_CN', '标签类型'),
('LOC_MPT_PLAYERMARK_FIELD_BRIEF', 'zh_Hans_CN', '简要描述'),
('LOC_MPT_PLAYERMARK_FIELD_DETAILS', 'zh_Hans_CN', '详细描述'),
('LOC_MPT_PLAYERMARK_MODIFIED_PREFIX', 'zh_Hans_CN', '最近修改：'),
-- 右侧操作按钮
('LOC_MPT_PLAYERMARK_SAVE', 'zh_Hans_CN', '保存'),
('LOC_MPT_PLAYERMARK_STEAM_PROFILE', 'zh_Hans_CN', 'Steam 主页'),
('LOC_MPT_PLAYERMARK_STEAM_PROFILE_TT', 'zh_Hans_CN', '打开该玩家的 Steam 个人主页（仅 17 位纯数字 ID 的 Steam 玩家可用）'),
('LOC_MPT_PLAYERMARK_DELETE', 'zh_Hans_CN', '删除玩家'),
('LOC_MPT_PLAYERMARK_DELETE_TT', 'zh_Hans_CN', '永久删除该玩家的全部记录（立即生效，不可撤销）'),
('LOC_MPT_PLAYERMARK_ADD_DETAIL', 'zh_Hans_CN', '添加'),
('LOC_MPT_PLAYERMARK_DETAIL_INPUT_TT', 'zh_Hans_CN', '输入一条新的详细描述，回车或点击「添加」（保存后生效）'),
('LOC_MPT_PLAYERMARK_DETAIL_DELETE_TT', 'zh_Hans_CN', '删除本条详细描述（保存后生效，取消可还原）'),
-- 标签三选一按钮提示
('LOC_MPT_PLAYERMARK_TAG_FRIEND_TT', 'zh_Hans_CN', '标记为好友（绿）'),
('LOC_MPT_PLAYERMARK_TAG_NORMAL_TT', 'zh_Hans_CN', '标记为一般（黄）'),
('LOC_MPT_PLAYERMARK_TAG_BLACK_TT', 'zh_Hans_CN', '标记为黑名单（红）'),
-- 空态提示
('LOC_MPT_PLAYERMARK_EMPTY_LIST', 'zh_Hans_CN', '暂无玩家记录[NEWLINE]点击下方「添加玩家」创建'),
('LOC_MPT_PLAYERMARK_EMPTY_SELECT', 'zh_Hans_CN', '在左侧列表选择一名玩家[NEWLINE]查看或编辑其信息'),
-- 校验/提示（内嵌 [color:] 颜色标签，Label SetColor 对文本无效为实测坑）
('LOC_MPT_PLAYERMARK_HINT_ID_INVALID', 'zh_Hans_CN', '[color:255,100,100,255]ID 格式无效：需 17 位纯数字（Steam）或 32 位字符（Epic）[ENDCOLOR]'),
('LOC_MPT_PLAYERMARK_HINT_NAME_EMPTY', 'zh_Hans_CN', '[color:255,100,100,255]昵称不能为空[ENDCOLOR]'),
('LOC_MPT_PLAYERMARK_HINT_ID_UNAVAILABLE', 'zh_Hans_CN', '无法获取ID'),
-- 房间玩家连接状态（图标内嵌 LOC 值；[icon_*]/[ICON_*] 为 UI 图标 tag）
('LOC_MPT_PLAYERMARK_CONN_ONLINE', 'zh_Hans_CN', '[icon_CheckmarkBlue]在线'),
('LOC_MPT_PLAYERMARK_CONN_OFFLINE', 'zh_Hans_CN', '[ICON_BULLETGLOW]离线'),
('LOC_MPT_PLAYERMARK_NOTICE_TITLE', 'zh_Hans_CN', '提示'),
-- 重复 ID 提示
('LOC_MPT_PLAYERMARK_EXISTS_TITLE', 'zh_Hans_CN', '记录已存在'),
('LOC_MPT_PLAYERMARK_EXISTS_TEXT', 'zh_Hans_CN', '该 ID 已有玩家记录，已为你切换到编辑该记录。'),
-- 确认框（删除整档 / 放弃未保存修改）
('LOC_MPT_PLAYERMARK_CONFIRM_DELETE_TITLE', 'zh_Hans_CN', '删除玩家记录'),
('LOC_MPT_PLAYERMARK_CONFIRM_DELETE_TEXT', 'zh_Hans_CN', '确定永久删除该玩家的全部记录？此操作立即生效且不可撤销。'),
('LOC_MPT_PLAYERMARK_CONFIRM_DISCARD_TITLE', 'zh_Hans_CN', '放弃修改'),
('LOC_MPT_PLAYERMARK_CONFIRM_DISCARD_TEXT', 'zh_Hans_CN', '当前玩家有未保存的修改，确定放弃这些修改？');
