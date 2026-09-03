-- ============================================================================
-- 联机工具箱2.0 玩家标记管理文本（en_US English）
-- 规范：本文件为条目4.4 玩家标记管理功能专属文本（纯本地玩家档案，无数据表），
--       仅在 FrontEnd 上下文注册（面板仅前端使用），不进游戏内上下文。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text) VALUES
-- Entry button / panel title
('LOC_MPT_PLAYERMARK_NAME', 'en_US', 'Player Marks'),
('LOC_MPT_PLAYERMARK_TOOLTIP', 'en_US', 'Open the player mark manager (local player records: friend / normal / blacklist marks and notes)'),
('LOC_MPT_PLAYERMARK_TITLE', 'en_US', 'Player Mark Manager'),
-- Search box (placeholder / tooltip)
('LOC_MPT_PLAYERMARK_SEARCH_NAME', 'en_US', 'Search name or ID'),
('LOC_MPT_PLAYERMARK_SEARCH_TT', 'en_US', 'Filter the list by nickname or NetworkIdentifier'),
-- Three filter checkboxes (all checked by default)
('LOC_MPT_PLAYERMARK_FILTER_FRIEND', 'en_US', 'Friend'),
('LOC_MPT_PLAYERMARK_FILTER_NORMAL', 'en_US', 'Normal'),
('LOC_MPT_PLAYERMARK_FILTER_BLACK', 'en_US', 'Blacklist'),
('LOC_MPT_PLAYERMARK_FILTER_FRIEND_TT', 'en_US', 'Show / hide players marked as friend'),
('LOC_MPT_PLAYERMARK_FILTER_NORMAL_TT', 'en_US', 'Show / hide players marked as normal'),
('LOC_MPT_PLAYERMARK_FILTER_BLACK_TT', 'en_US', 'Show / hide players marked as blacklist'),
-- Sort toggle button (current-state label, click to switch direction)
('LOC_MPT_PLAYERMARK_SORT_DESC', 'en_US', 'Newest first'),
('LOC_MPT_PLAYERMARK_SORT_ASC', 'en_US', 'Oldest first'),
('LOC_MPT_PLAYERMARK_SORT_TT', 'en_US', 'Sort by last modified date; click to switch ascending / descending'),
-- Add button and popup
('LOC_MPT_PLAYERMARK_ADD', 'en_US', 'Add Player'),
('LOC_MPT_PLAYERMARK_MARK_THIS_TT', 'en_US', 'Click to add this player to Player Marks (auto-fills network ID and nickname)'),
('LOC_MPT_PLAYERMARK_POPUP_TITLE', 'en_US', 'Add Player'),
('LOC_MPT_PLAYERMARK_POPUP_ID_TT', 'en_US', 'Player network identifier: 17 digits for Steam, 32 characters for Epic'),
('LOC_MPT_PLAYERMARK_POPUP_NAME_TT', 'en_US', 'Nickname for your notes, display only, editable anytime'),
('LOC_MPT_PLAYERMARK_CREATE', 'en_US', 'Create'),
-- Right-side field labels
('LOC_MPT_PLAYERMARK_FIELD_ID', 'en_US', 'NetworkIdentifier'),
('LOC_MPT_PLAYERMARK_FIELD_NAME', 'en_US', 'Nickname'),
('LOC_MPT_PLAYERMARK_FIELD_TAG', 'en_US', 'Mark Type'),
('LOC_MPT_PLAYERMARK_FIELD_BRIEF', 'en_US', 'Brief Description'),
('LOC_MPT_PLAYERMARK_FIELD_DETAILS', 'en_US', 'Detailed Notes'),
('LOC_MPT_PLAYERMARK_MODIFIED_PREFIX', 'en_US', 'Last modified: '),
-- Right-side action buttons
('LOC_MPT_PLAYERMARK_SAVE', 'en_US', 'Save'),
('LOC_MPT_PLAYERMARK_STEAM_PROFILE', 'en_US', 'Steam Profile'),
('LOC_MPT_PLAYERMARK_STEAM_PROFILE_TT', 'en_US', "Open this player's Steam profile (only available for Steam players with 17-digit numeric ID)"),
('LOC_MPT_PLAYERMARK_DELETE', 'en_US', 'Delete Player'),
('LOC_MPT_PLAYERMARK_DELETE_TT', 'en_US', 'Permanently delete all records of this player (takes effect immediately, cannot be undone)'),
('LOC_MPT_PLAYERMARK_ADD_DETAIL', 'en_US', 'Add'),
('LOC_MPT_PLAYERMARK_DETAIL_INPUT_TT', 'en_US', 'Type a new detailed note, then press Enter or click "Add" (applied after Save)'),
('LOC_MPT_PLAYERMARK_DETAIL_DELETE_TT', 'en_US', 'Delete this note (applied after Save; Cancel restores)'),
-- Tag selector button tooltips
('LOC_MPT_PLAYERMARK_TAG_FRIEND_TT', 'en_US', 'Mark as friend (green)'),
('LOC_MPT_PLAYERMARK_TAG_NORMAL_TT', 'en_US', 'Mark as normal (yellow)'),
('LOC_MPT_PLAYERMARK_TAG_BLACK_TT', 'en_US', 'Mark as blacklist (red)'),
-- Empty states
('LOC_MPT_PLAYERMARK_EMPTY_LIST', 'en_US', 'No player records yet[NEWLINE]Click "Add Player" below to create one'),
('LOC_MPT_PLAYERMARK_EMPTY_SELECT', 'en_US', 'Select a player in the list on the left[NEWLINE]to view or edit their info'),
-- Validation / notices (embedded [color:] tags; Label SetColor does not work on text)
('LOC_MPT_PLAYERMARK_HINT_ID_INVALID', 'en_US', '[color:255,100,100,255]Invalid ID: must be 17 digits (Steam) or 32 characters (Epic)[ENDCOLOR]'),
('LOC_MPT_PLAYERMARK_HINT_NAME_EMPTY', 'en_US', '[color:255,100,100,255]Nickname cannot be empty[ENDCOLOR]'),
('LOC_MPT_PLAYERMARK_HINT_ID_UNAVAILABLE', 'en_US', 'Unable to retrieve ID'),
-- Room player connection status (icons embedded in LOC value)
('LOC_MPT_PLAYERMARK_CONN_ONLINE', 'en_US', '[icon_CheckmarkBlue]Online'),
('LOC_MPT_PLAYERMARK_CONN_OFFLINE', 'en_US', '[ICON_BULLETGLOW]Offline'),
('LOC_MPT_PLAYERMARK_NOTICE_TITLE', 'en_US', 'Notice'),
-- Duplicate ID notice
('LOC_MPT_PLAYERMARK_EXISTS_TITLE', 'en_US', 'Record Exists'),
('LOC_MPT_PLAYERMARK_EXISTS_TEXT', 'en_US', 'A record with this ID already exists; switched to editing it.'),
-- Confirm dialogs (delete record / discard unsaved changes)
('LOC_MPT_PLAYERMARK_CONFIRM_DELETE_TITLE', 'en_US', 'Delete Player Record'),
('LOC_MPT_PLAYERMARK_CONFIRM_DELETE_TEXT', 'en_US', 'Permanently delete all records of this player? This takes effect immediately and cannot be undone.'),
('LOC_MPT_PLAYERMARK_CONFIRM_DISCARD_TITLE', 'en_US', 'Discard Changes'),
('LOC_MPT_PLAYERMARK_CONFIRM_DISCARD_TEXT', 'en_US', 'This player has unsaved changes. Discard them?'),
-- 条目4.8续：隐身开关（头部复选框）
('LOC_MPT_PLAYERMARK_HIDDEN_MARK', 'en_US', 'Hide my marks'),
('LOC_MPT_PLAYERMARK_HIDDEN_MARK_TT', 'en_US', 'By default, other players cannot see your special marks; unchecking broadcasts an "allow display" signal that makes them visible to others'),
-- 条目4.9：左列双页签
('LOC_MPT_PLAYERMARK_TAB_SAVED', 'en_US', 'Saved Marks'),
('LOC_MPT_PLAYERMARK_TAB_ROOM', 'en_US', 'Room Players'),
('LOC_MPT_PLAYERMARK_EMPTY_ROOM', 'en_US', 'No players in the room to mark');
