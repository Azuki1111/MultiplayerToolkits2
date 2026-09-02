-- ===========================================================================
-- 条目25：大将军时代提示 横幅池上下文（BER = Great General Era Reminder，移植 1.67
--   BER/UnitFlagManager_GreatGeneralEraReminder.lua，工坊 3693899014）
-- 本文件与同名 EraBanner.xml 成对，经 AddUserInterfaces 注册进 InGame（与条目12 FEB 同桶
--   同机制）——引擎 InGame.lua 348 行 LoadNewContext 把每个 addin 挂到 AdditionalUserInterfaces
--   容器下成为独立隐藏迷你上下文，节点名 = ContextPath 无扩展名末段（RevealMapCorners 同
--   机制日志实证），即本上下文 = /InGame/AdditionalUserInterfaces/EraBanner。
-- 条目25修复：首版把本对注册到 Context=UnitFlagManager 期望模板并入旗标上下文，实测不生效
--   （Context 指向子上下文时 addin 不入 InGame 桶，Lua.log 无加载痕迹）；改为池内预声明
--   40 面唯一 ID 横幅（EraBanner_1..40），由 UnitFlagManager_MPT.lua（旗标上下文）按路径
--   LookUpControl 取代理后 ChangeParent 挂旗标（原版先例 PartialScreenHooks.lua 64 行按名
--   寻址本容器下的追加上下文）。
-- 本脚本职责仅诊断（横幅确认实测生效后整段移除）：确认池上下文加载与控件齐全。
-- ===========================================================================
function LateInitialize()
	print("MPT_ERA: pool context loaded, MPT_ERA_Pool = " .. tostring(Controls.MPT_ERA_Pool ~= nil));
end

function Initialize()
	Events.LoadScreenClose.Add(LateInitialize);
end
Initialize();
