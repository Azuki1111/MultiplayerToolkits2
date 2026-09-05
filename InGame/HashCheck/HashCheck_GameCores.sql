-- 条目34：反作弊监控——GameCore 代理 DLL 重定向（源：工坊 3775385784，条目34扩展起对齐
-- 作者本地新版 1.0.2「MzPanel」混淆重构版，DLL 换名 GameCore_XP2_Mz）。
-- 把 GS（Expansion2）引擎核心替换为本 mod Binaries/Win64/ 下的钩子 DLL：
-- DLL 代理原版 GameCore_XP2_FinalRelease.dll 并向 Lua 状态注入 Mzq 全局
-- （命令 a=Init / b=收远端证明 / c=比对哈希 / d=本机摘要 / e=取对方摘要），
-- 后台聚合哈希本机全部启用 mod / 二进制文件，联机交换证明供监测面板比对。
-- 经 modinfo ActionCriteria MPT_HASH_CHECK 门控（FE 侧 criteria 同样生效，条目34 实证）：
-- 不勾选 = 本 UPDATE 不执行 = 引擎不加载钩子 DLL，功能整体零加载零改动。
-- 注意：每个 GameCore 只有一个 DllPrefix，与其他替换 GameCore 的钩子类 mod 互斥（后加载者胜），
-- 启用本功能时应停用独立发行版（工坊 3775385784 旧版 / 本地 HashCheckMod 新版，同源 DLL 会形成双 DllPrefix 竞争）；
-- DLL 仅 Win64 可用，且依赖 Expansion2 行存在（无 GS 环境本 UPDATE 无效果，Lua 端优雅降级）。
UPDATE GameCores
SET PackageId = '00000000-7369-4685-ab5f-bf77bc22b54e',
    DllPrefix = 'GameCore_XP2_Mz'
WHERE GameCore = 'Expansion2';
