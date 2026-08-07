-- ============================================================================
-- 联机工具箱2.0：Config 新增参数的本地化文本（LeaderPoolBan 禁用领袖池）
-- 规范：本 mod 所有文本更改一律采用 SQL 格式（INSERT OR REPLACE INTO LocalizedText），
--       挂 FrontEndActions <UpdateText>，LoadOrder 100–999。
-- ============================================================================
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text)
VALUES ('LOC_LEADER_POOL_BAN_NAME', 'zh_Hans_CN', '禁用领袖');
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text)
VALUES ('LOC_LEADER_POOL_BAN_NAME', 'en_US', 'Banned Leaders');
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text)
VALUES ('LOC_LEADER_POOL_BAN_DESC', 'zh_Hans_CN', '被选中的领袖在本局中不可选用');
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text)
VALUES ('LOC_LEADER_POOL_BAN_DESC', 'en_US', 'Selected leaders cannot be chosen in this game');
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text)
VALUES ('LOC_LEADER_POOL_BAN_TOOLTIP', 'zh_Hans_CN', '[COLOR_RED]领袖不可用[ENDCOLOR]');
INSERT OR REPLACE INTO LocalizedText (Tag, Language, Text)
VALUES ('LOC_LEADER_POOL_BAN_TOOLTIP', 'en_US', '[COLOR_RED]Leader unavailable[ENDCOLOR]');
