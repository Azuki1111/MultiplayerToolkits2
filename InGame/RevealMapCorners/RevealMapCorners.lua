-- ============================================================================
-- 条目5：显示地图角落（移植 1.67 RMC）
-- 目的：在游戏世界两极创建两个真实地图钉，撑开引擎小地图世界矩形，
--       使小地图以全球比例显示。
-- 原理（实测定论）：小地图世界矩形（UI.GetMinimapWorldRect）由引擎计算且只认
--       游戏世界数据——地图钉（PlayerConfigurations:GetMapPin(x,y) 为 create-or-get，
--       写入引擎层）坐标被纳入矩形计算；UI 控件（WorldAnchor 自绘实例）无论挂载
--       在哪个父容器/是否可见，都不参与包围盒计算（自制透明实例方案已实测无效，弃用）。
-- 实现：1.67 原版——LuaEvents.MapPinPopup_RequestMapPin(x,y) 创建 pin（会弹编辑弹窗），
--       随即 UIManager:DequeuePopup 弹掉弹窗；MapPinManager 自动在世界层渲染旗帜。
-- 用法：本文件经 AddUserInterfaces 注册的空 Context 自动执行，无外部接口。
-- ============================================================================

-- 幂等守卫：进游戏只打一次钉（Lua 状态跨房间存续，防止反复创建）
local m_anchored : boolean = false;

-- ============================================================================
-- 进游戏读盘完成：在两级角（首格与末格）创建地图钉并弹掉编辑弹窗
function OnLoadScreenClose()
	if m_anchored then return; end
	m_anchored = true;

	local plotFirst : table = Map.GetPlotByIndex( 0 );
	local plotLast  : table = Map.GetPlotByIndex( Map.GetPlotCount() - 1 );
	if plotFirst ~= nil and plotLast ~= nil then
		-- RequestMapPin 内部 GetMapPin(x,y) 为 create-or-get，创建 pin 数据（引擎层）
		LuaEvents.MapPinPopup_RequestMapPin( plotFirst:GetX(), plotFirst:GetY() );
		LuaEvents.MapPinPopup_RequestMapPin( plotLast:GetX(), plotLast:GetY() );
		-- 立即弹掉地图钉编辑弹窗（原版 RMC 手法）
		local popup : table = ContextPtr:LookUpControl( "/InGame/MapPinPopup" );
		if popup ~= nil then
			UIManager:DequeuePopup( popup );
		end
	end
end
Events.LoadScreenClose.Add( OnLoadScreenClose );
