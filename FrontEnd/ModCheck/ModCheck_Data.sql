-- ============================================================================
-- 联机工具箱2.0 模组版本校验注册表 MPT_ModCheck（条目4.1）
-- 用途：准备房间版本一致性校验的校验清单。凡登记在此表中的 mod（且当前房间已启用），
--      房主会广播其 modId 与版本指纹，要求全房间玩家回报本机版本进行比对。
-- 第三方接入：在自己的 mod 中用相同的 CREATE TABLE IF NOT EXISTS + INSERT OR REPLACE
--      登记自己的 modId（IF NOT EXISTS 保证与本 mod 的加载顺序无关）；
--      并在自己的 modinfo <Properties> 中填写 <Version> 作为版本指纹（未填按 "?" 处理）。
--      注意：ModId 大小写须与 GameConfiguration.GetEnabledMods() 返回的 Id 完全一致
--      （校验清单按字符串相等做 注册表∩已启用 匹配，大小写不符会被静默漏检）。
-- ============================================================================
CREATE TABLE IF NOT EXISTS MPT_ModCheck (
	ModId TEXT PRIMARY KEY
);
INSERT OR REPLACE INTO MPT_ModCheck (ModId) VALUES
('00000000-7369-4685-ab5f-bf77bc22b54e');
