-- ===========================================================================
-- 条目17：建立城市免确认（RCT）——移植自联机工具箱 1.67（工坊 3693899014 RCT 目录）
-- 点击「建立城市」不再弹出确认弹窗（含「将移除地貌」提示），直接执行坐城操作。
-- 实现：ReplaceUIScript 抢占 UnitPanel 上下文入口（原版入口脚本不再运行）→ 手动重建
-- 原版 include 链 → 重定义全局 OnUnitActionClicked_FoundCity（原版按钮回调注册的是
-- 匿名闭包，点击时才解析全局名，include 完成后重定义即生效，无需重建动作表）。
-- 相对 1.67（UnitPanel_TPT.lua）的优化：
--   1. 修复 m_HexColoringWaterAvail 隐患——原版 UnitPanel.lua 中为 local（跨 include
--      不可见），1.67 直接引用得到 nil，尾部 UILens.IsLayerOn(nil) 报错被引擎吞掉，
--      坐城后「可坐城水域」高亮层不关闭、镜头不回默认；本文件按原版同名参数自建
--   2. 删除死代码：弹窗移除后 popupString 两次 Locale.Lookup 拼接结果无任何消费方
--      （kResults 分支整体删除，kResults 参数仅为兼容原版调用签名保留）
--   3. 注释尸体清理：1.67 为原版函数整段拷贝再注释弹窗，本文件整体重写，
--      原版弹窗逻辑以修改留痕横幅保留
--   4. include 链补注释（优先级即兼容优先级、break 防重复执行），print 加 MPT 前缀
-- 注册：ReplaceUIScript(LuaContext=UnitPanel, LoadOrder 100000，压过 1.67 同类替换的
--   11000) + ImportFiles(100010)；无条件常开（同 1.67，无配置开关）
-- ===========================================================================

-- ===========================================================================
-- INCLUDES（重建 UnitPanel 原版 include 链：命中任一入口后原版 Initialize() 已完整
--   执行，全局 Initialize 出现即 break，防止链条重复加载造成事件重复订阅）
-- 优先级即兼容优先级：BSM 观战（unitpanel_spec）→ XP2 → XP1 → Base；
--   include() 对不存在的文件仅告警不报错，天然适配有无 BSM/资料片的各环境
--   （BSM 的 unitpanel_spec 优先级无法用 modinfo criteria 静态表达，运行时自适应更稳）
-- ===========================================================================
local files = {
	"unitpanel_spec.lua",		-- BSM（Better Spectator Mod）观战兼容入口（BSM 启用时其 ImportFiles 已把该文件送入 VFS）
	"UnitPanel_Expansion2.lua",	-- 原版 XP2 入口（内部继续 include XP1/Base，以 BASE_ 局部保存+重定义方式扩展）
	"UnitPanel_Expansion1.lua",	-- 原版 XP1 入口（内部 include Base）
	"UnitPanel.lua",			-- 原版 Base 本体
};

for _, file in ipairs(files) do
	include(file);
	if Initialize ~= nil then
		print("MPT: Loading " .. file .. " as UnitPanel base file");
		break;
	end
end

-- ===========================================================================
-- OVERRIDES
-- ===========================================================================
-- 「可坐城水域」Lens 层 hash：原版为 UnitPanel.lua 顶部 local（跨 include 不可见——
--   优化1），此处按原版同名引擎参数自建（原版拼写 Availablity 照抄，引擎字符串如此）
local MPT_HexColoringWaterAvail : number = UILens.CreateLensLayerHash("Hex_Coloring_Water_Availablity");

-- ============================================================================
-- OnUnitActionClicked_FoundCity(kResults)：「建立城市」按钮点击回调（函数名保持原版
--   全局名，原版回调闭包点击时才解析，此处重定义即生效）。
--   移除确认弹窗（含地貌移除提示），直接请求坐城操作。
-- 修改留痕：注释段为原版 Base UnitPanel.lua 的弹窗逻辑（1.67 即注释此段实现同效果）
-- ============================================================================
function OnUnitActionClicked_FoundCity(kResults : table)
	if (g_isOkayToProcess) then
		local pSelectedUnit = UI.GetHeadSelectedUnit();
		if ( pSelectedUnit ~= nil ) then
			-- ==== 条目17：移除建立城市确认弹窗，直接坐城（原版弹窗逻辑保留备查） ====
			-- if (kResults ~= nil and table.count(kResults) ~= 0) then
			-- 	local popupString : string = Locale.Lookup("LOC_FOUND_CITY_CONFIRM_POPUP");
			-- 	if (kResults[UnitOperationResults.FEATURE_TYPE] ~= nil) then
			-- 		local featureName = GameInfo.Features[kResults[UnitOperationResults.FEATURE_TYPE]].Name;
			-- 		popupString = popupString .. "[NEWLINE]" .. Locale.Lookup("LOC_FOUND_CITY_WILL_REMOVE_FEATURE", featureName);
			-- 	end
			-- 	local pPopupDialog : table = PopupDialogInGame:new("FoundCityAt");	-- unique identifier
			-- 	pPopupDialog:AddText(popupString);
			-- 	pPopupDialog:AddConfirmButton(Locale.Lookup("LOC_YES"), function()
			-- 		UnitManager.RequestOperation(pSelectedUnit, UnitOperationTypes.FOUND_CITY);
			-- 	end);
			-- 	pPopupDialog:AddCancelButton(Locale.Lookup("LOC_NO"), nil);
			-- 	pPopupDialog:Open();
			-- else
			-- 	UnitManager.RequestOperation(pSelectedUnit, UnitOperationTypes.FOUND_CITY);
			-- end
			-- ----
			UnitManager.RequestOperation(pSelectedUnit, UnitOperationTypes.FOUND_CITY);
		end
	end
	-- 坐城后收起「可坐城水域」高亮层并回到默认镜头层（原版尾部逻辑；使用上方自建
	--   hash 替代跨 chunk 不可见的原版 local——优化1）
	if UILens.IsLayerOn(MPT_HexColoringWaterAvail) then
		UILens.ToggleLayerOff(MPT_HexColoringWaterAvail);
	end
	UILens.SetActive("Default");
end
