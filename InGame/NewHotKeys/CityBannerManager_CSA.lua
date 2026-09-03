-- ===========================================================================
-- 条目28：城市远程攻击热键（移植 1.65 NHK/UI/CityBannerManager_CSA.lua 原样，11 行）
--
-- 功能：原版远程攻击动作（RangedAttack，默认 R 键）触发时，若当前选中的是城市且
--   CanRangeAttack 可攻击，则进入城市远程攻击模式——让原版对单位的远程攻击键位
--   直接对城市生效（否则只能点横幅按钮）。
-- 注入机制：文件名前缀 CityBannerManager_ 被原版 CityBannerManager.lua 末尾通配
--   include("CityBannerManager_", true) 拉入同上下文（同条目7/18/19 机制），
--   modinfo 仅 ImportFiles(1000) 导入 VFS（在条目18 MPT 1010 之前，链序在前无依赖）；
--   CanRangeAttack 为 CityBannerManager 上下文全局函数（可直接调用）。
-- 与 1.65 差异（逐条留痕）：
--   1) 零全局污染：1.65 泄漏全局函数 OnInputActionTriggered_CSA（与 1.65 CSB/CSA 等
--      同上下文补丁撞名风险，条目18 头注释警告对象），本文件改 local（条目18 同款约定）
-- 相对 1.65 的让位（criteria=Disable_TPT，modinfo 配置；条目28调整后不受「更多快捷键」
--   开关影响）：1.65 在装时本文件不导入（其原版
--   同名文件继续服务，避免双注册；双注册本身幂等无害，让位仅保持单一事实来源）。
-- ===========================================================================

local m_RangedAttackActionId : number = Input.GetActionId("RangedAttack");

local function OnInputActionTriggered_CSA(actionId : number)
	if actionId == m_RangedAttackActionId then
		local pCity : table = UI.GetHeadSelectedCity()
		-- CanRangeAttack nil 守卫（上下文变体缺该全局时静默跳过，1.65 直接调用）
		if CanRangeAttack ~= nil and CanRangeAttack(pCity) then
			UI.SetInterfaceMode(InterfaceModeTypes.CITY_RANGE_ATTACK);
		end
		return
	end
end
Events.InputActionTriggered.Add(OnInputActionTriggered_CSA)
