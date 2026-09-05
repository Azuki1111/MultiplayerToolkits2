-- ===========================================================================
-- 条目35：城市横幅增强（CSB）——移植自联机工具箱 1.67（工坊 3693899014
--   CSB/UI/CityBannerManager_TPT.lua，「调整城墙射击按钮」）
-- 做什么（均作用于城市横幅 CityBanner）：
--   ①城墙射击按钮位置调整：原版按钮悬在横幅底部中央（CityBannerInstances.xml
--     CityStrike C,B / 0,-6 + CityStrikeButton C,B / 0,10），默认挪到横幅右侧
--     （R,C / -32,0，远离横幅中部信息区）；条目12设置面板「恢复城市远程攻击按钮
--     位置」（CityStrikeButton_Back，沿用 1.67 原 key，默认关）勾选后收回原版坐标
--   ②万神殿信条提示补全：原版无主流宗教城市的万神殿图标 tooltip 只有信条名
--     （LOC_HUD_CITY_PANTHEON_TT），追加信条描述一行
--   ③有主流宗教城市补显万神殿图标：原版 UpdateInfo 信条图标二选一（有主流宗教
--     显宗教图标 / 无主流宗教才显万神殿图标），而城市转信他人宗教后本地万神殿
--     信条（如海神+产量）仍然生效——此场景在信息区补一个万神殿图标，
--     tooltip = 信条名+描述，点击同原版宗教图标（OnReligionIconClicked）
-- 注入机制：文件名前缀 CityBannerManager_ 被原版 CityBannerManager.lua 末尾通配
--   include("CityBannerManager_", true) 拉入同上下文（同条目18/28 机制），
--   modinfo 仅 ImportFiles(1020) 导入 VFS——在条目18 PCF(1010) 之后、链序无依赖；
--   OnReligionIconClicked / RefreshPlayerBanners 均为上下文原版全局（后者对
--   playerID=-1 观察者首行即 return，观察者天然安全）
-- 与 1.67 差异（逐条留痕）：
--   1) COLOR_HOLY_SITE 修正：原版该色值是 CityBannerManager.lua 的 chunk 局部
--      （XP2 L35 local），通配注入文件跨 chunk 取不到恒为 nil（1.67 原样引用
--      =SetColor(nil) 静默失效），本文件自取同字面量 UI.GetColorValueFromHexLiteral
--      (0xFFFFFFFF)
--   2) 零全局污染：1.67 泄漏 BASE_CityBanner_UpdateRangeStrike / BASE_UpdateInfo /
--      OnTPT_Settings_Toggle 三全局（同上下文其他 CityBannerManager_* 补丁撞名
--      风险，条目18 头注释警告对象），本文件全 local（chunk 内包装无需跨文件共享）
--   3) 开关单通道：LuaEvents.TPT_Settings_Toggle 双通道订阅改 MPT_Settings_Toggle
--      单通道（条目25/26规范裁决）；初值由条目12面板 LoadScreenClose ApplyAll
--      送达，勾选变化即时广播并调 RefreshPlayerBanners 重摆全部横幅按钮
--   4) pCity nil 守卫（条目33 全链防御惯例）：UpdateInfo 包装体内先验空
--   5) 删 1.67 Part2 的额外 self:Resize()（BASE_UpdateInfo 末尾恒有 Resize，冗余）
--   6) 兼容守卫保留：Sukritact Simple UI Adjustments 在装时跳过两处包装（其同区
--      改横幅，Modding.IsModActive 探测，1.67 同款）
-- 与 1.67 同装注意：两文件都会被通配 include 拉入，「有主流宗教+万神殿生效」场景
--   会补出双万神殿图标（条目10/28调整裁决不再做让位兼容），建议二选一启用
-- 注册：ImportFiles(1020) 通配注入不占 LuaContext（1.67 同款机制）
-- ===========================================================================

-- Sukritact Simple UI Adjustments 同区改城市横幅（射击按钮/信息图标），在装时本功能整体让位
local MPT_SukUIInUse : boolean = Modding.IsModActive("805cc499-c534-4e0a-bdce-32fb3c53ba38");

local MPT_BASE_UpdateRangeStrike = CityBanner.UpdateRangeStrike;	-- 原版：仅管显隐，锚点来自 CityBannerInstances.xml
local MPT_BASE_UpdateInfo = CityBanner.UpdateInfo;

local MPT_COLOR_HOLY_SITE : number = UI.GetColorValueFromHexLiteral(0xFFFFFFFF);	-- 原版 chunk 局部色值同字面量（差异1）

-- CityStrikeButton_Back 开关当前值（false=按钮挪右侧默认态 / true=收回原版位置），
-- 初值由条目12设置面板 LoadScreenClose 广播送达
local MPT_CanCityStrikeButtonRevoke : boolean = false;

if not MPT_SukUIInUse then

	-- ===========================================================================
	-- ①城墙射击按钮重定位：BASE 先行（显隐判定），后按开关摆锚点——
	--   收回=true → CityStrike C,B + (0,-6)、CityStrikeButton C,B + (0,10)
	--   = CityBannerInstances.xml 原版坐标；默认=false → R,C + (-32,0)/(L,C + 6,0)
	--   挪到横幅右侧（1.67 同款坐标）
	-- ===========================================================================
	function CityBanner.UpdateRangeStrike( self )
		MPT_BASE_UpdateRangeStrike( self );

		local tBanner : table = self.m_Instance;
		if tBanner.CityStrike ~= nil then
			if MPT_CanCityStrikeButtonRevoke then
				tBanner.CityStrike:SetAnchor( "C,B" );
				tBanner.CityStrike:SetOffsetVal( 0, -6 );
				tBanner.CityStrikeButton:SetAnchor( "C,B" );
				tBanner.CityStrikeButton:SetOffsetVal( 0, 10 );
			else
				tBanner.CityStrike:SetAnchor( "R,C" );
				tBanner.CityStrike:SetOffsetVal( -32, 0 );
				tBanner.CityStrikeButton:SetAnchor( "L,C" );
				tBanner.CityStrikeButton:SetOffsetVal( 6, 0 );
			end
		end
	end

	-- ===========================================================================
	-- ②③万神殿信条提示：BASE 先行（原生图标逻辑+末尾 Resize），后——
	--   ②遍历信息栈子控件按「tooltip==信条名」比对定位原版万神殿图标（无主流宗教
	--     分支），命中即拼信条描述行（BASE 每次先 ResetInstances 重建，无累积）
	--   ③有主流宗教（m_eMajorityReligion > 0）且万神殿仍生效 → 补一个万神殿图标
	--     （ICON_RELIGION_PANTHEON / 白色 / Banner_TypeSlot_Religion 底座，点击进
	--     宗教总览或镜头跟随，同原版 OnReligionIconClicked 口径）
	-- ===========================================================================
	function CityBanner.UpdateInfo( self, pCity )
		MPT_BASE_UpdateInfo( self, pCity );
		if pCity == nil then return; end	-- 差异4

		local pCityReligion : table = pCity:GetReligion();
		local activePantheon : number = pCityReligion:GetActivePantheon();
		if activePantheon < 0 then return; end

		-- ②原版万神殿图标 tooltip 追加信条描述（1.67 同款比对式定位，信条名串提出循环外）
		local pantheonTooltip : string = Locale.Lookup( "LOC_HUD_CITY_PANTHEON_TT", GameInfo.Beliefs[activePantheon].Name );
		local kChildren : table = self.m_Instance.CityInfoStack:GetChildren();
		for i, kChild in ipairs( kChildren ) do
			if kChild:GetToolTipString() == pantheonTooltip then
				kChild:SetToolTipString( kChild:GetToolTipString() .. "[NEWLINE]" .. Locale.Lookup( GameInfo.Beliefs[activePantheon].Description ) );
			end
		end

		-- ③有主流宗教仍补显万神殿图标（原版此场景不显示）
		local eMajorityReligion : number = self.m_eMajorityReligion;
		if eMajorityReligion > 0 then
			local instance : table = self.m_InfoIconIM:GetInstance();
			instance.Icon:SetIcon( "ICON_" .. GameInfo.Religions[0].ReligionType );
			instance.Icon:SetColor( MPT_COLOR_HOLY_SITE );
			instance.Button:SetTexture( "Banner_TypeSlot_Religion" );
			instance.Button:SetToolTipString( pantheonTooltip .. "[NEWLINE]" .. Locale.Lookup( GameInfo.Beliefs[activePantheon].Description ) );
			instance.Button:RegisterCallback( Mouse.eLClick, OnReligionIconClicked );
			instance.Button:SetVoid1( pCity:GetOwner() );
			instance.Button:SetVoid2( pCity:GetID() );
			-- 差异5：不重复 Resize（BASE_UpdateInfo 末尾恒有）
		end
	end

end

-- ===========================================================================
-- 条目35 开关广播（条目12 MPT_Settings 面板单通道，差异3）：CityStrikeButton_Back
--   勾选=收回原位；即时 RefreshPlayerBanners 重摆全部横幅按钮（原版对 -1 观察者
--   首行 return，初值广播时横幅未建则循环空转，均安全）
-- ===========================================================================
local function OnMPT_Settings_Toggle( ParameterId, Value )
	if ParameterId == "CityStrikeButton_Back" then
		MPT_CanCityStrikeButtonRevoke = Value;
		RefreshPlayerBanners( Game.GetLocalPlayer() );
		return;
	end
end
LuaEvents.MPT_Settings_Toggle.Add( OnMPT_Settings_Toggle );
