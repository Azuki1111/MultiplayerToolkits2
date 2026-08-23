-- ============================================================================
-- 条目5实验：注入 MapPinManager 上下文，验证能否访问其全局（GetMapPinFlag）
-- 经 ImportFiles LuaContext=MapPinManager 追加注入（模式4），与 MapPinManager 同一 Lua 状态。
-- 目的：确认单独控制 pin 实例（GetMapPinFlag）在此 VM 中可用，为后续偏移逻辑铺路。
-- ============================================================================
print( "[MPT_RMC] MPT_MapPinOffset.lua 顶层执行（注入 MapPinManager 上下文）" );
print( "[MPT_RMC] 注入VM诊断: type(GetMapPinFlag)=" .. tostring(type(GetMapPinFlag)) .. " type(MapPinFlag)=" .. tostring(type(MapPinFlag)) );
