-- ============================================================================
-- 条目5：显示地图角落（移植 1.67 RMC，自制透明实例版）
-- 目的：在游戏世界两极锚定两个透明 WorldAnchor 实例，撑开相机包围盒，
--       使小地图以全球比例显示（1.67 用真实地图钉实现，本版自绘不留 pin 数据）。
-- 原理：WorldAnchor 控件将 3D 世界坐标投影到屏幕；UI.GridToWorld(plotIndex)
--       把格子索引转世界坐标，Anchor:SetWorldPositionVal 完成锚定。
-- 用法：本文件经 AddUserInterfaces 注册的空 Context 自动执行，无外部接口。
-- ============================================================================
include( "InstanceManager" );

-- 实例管理器：实例模板 MPT_WorldAnchorInstance，关键控件 "Anchor"（WorldAnchor）
local m_AnchorIM : table = InstanceManager:new( "MPT_WorldAnchorInstance", "Anchor", Controls.MPT_WorldAnchorRoot );

-- 幂等守卫：进游戏只锚定一次（Lua 状态跨房间存续，防止反复创建实例）
local m_anchored : boolean = false;

-- ============================================================================
-- 在指定格子创建透明实例并锚定
function AnchorInstance( plotIndex : number )
	local worldX : number, worldY : number = UI.GridToWorld( plotIndex );
	local pInstance : table = m_AnchorIM:GetInstance();
	pInstance.Anchor:SetWorldPositionVal( worldX, worldY, 0 );
end

-- ============================================================================
-- 进游戏读盘完成：锚定两极角（首格与末格）
function OnLoadScreenClose()
	if m_anchored then return; end
	m_anchored = true;
	local plotFirst : table = Map.GetPlotByIndex( 0 );
	local plotLast  : table = Map.GetPlotByIndex( Map.GetPlotCount() - 1 );
	AnchorInstance( plotFirst:GetIndex() );
	AnchorInstance( plotLast:GetIndex() );
end
Events.LoadScreenClose.Add( OnLoadScreenClose );
