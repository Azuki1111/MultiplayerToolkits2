-- ===========================================================================
-- 条目25：大将军时代提示 横幅实例池（BER = Great General Era Reminder，移植 1.67
--   BER/UnitFlagManager_GreatGeneralEraReminder.lua，工坊 3693899014）
-- 本文件与同名 EraBanner.xml 成对（条目12/13/20 机制）：XML 声明 MPTEraBanner 实例
--   模板与实例池容器 MPT_ERA_Pool，本脚本持池对外提供取还两个接口。
-- 取还协议照抄原版官方动态实例模式（原版 UnitFlagManager.lua 的 AttentionMarkerInstance：
--   构建后 ChangeParent 挂旗标 FlagRoot，UnitFlag.destroy 时 ReleaseInstanceByParent
--   按父控件归还——旗标实例回收复用不残留旧子控件，也就不会重复构建）。
-- 调用方 = UnitFlagManager_MPT.lua（ReplaceUIScript 注入 UnitFlagManager 上下文）；
--   本脚本经 AddUserInterfaces(Context=UnitFlagManager) 与模板一并注入同一上下文，
--   同上下文直接全局调用。若引擎未把追加布局合并注册进目标上下文（官方此 action
--   仅用过 InGame，属扩展用法，见 EraBanner.xml 文件头），本脚本所在上下文与旗标
--   上下文隔离，全局函数对调用方不可见，调用方 nil 防御跳过，功能静默关闭。
-- ===========================================================================
include("InstanceManager");

local MPT_ERA_IM = InstanceManager:new("MPTEraBanner", "EraBanner", Controls.MPT_ERA_Pool);

-- 取一面时代横幅并挂到旗标根控件下（pFlagRoot = 旗标实例的 FlagRoot 控件）。
--   返回实例表（EraBanner/EraLabel 两控件键），模板不可用或构建失败返回 nil。
--   显隐由调用方在每次刷新时幂等设置，本函数只负责构建与挂载。
function MPT_ERA_Acquire(pFlagRoot)
	local pInstance = MPT_ERA_IM:GetInstance();
	if pInstance ~= nil and pInstance.EraBanner ~= nil then
		pInstance.EraBanner:ChangeParent(pFlagRoot);
		return pInstance;
	end
	return nil;
end

-- 归还挂在 pFlagRoot 下的时代横幅（旗标销毁时调用，实例回池待复用）。
function MPT_ERA_Release(pFlagRoot)
	MPT_ERA_IM:ReleaseInstanceByParent(pFlagRoot);
end
