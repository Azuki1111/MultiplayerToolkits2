-- ============================================================================
-- 条目16：禁用地图钉（RMP，移植 1.67 RMP/UI/Hide_MapPinListButton.lua）
-- 进局后隐藏左下角小地图面板的「地图钉列表」按钮（MapPinListPanel 的入口）。
-- 本 Context 经 AddUserInterfaces + criteria=No_Map_Pins 挂载：仅勾选高级选项「禁用地图钉」时存在。
-- ============================================================================
-- 旧代码（1.67 原样）：
-- function OnLoadScreenClose()
-- 	local MapPinListButton = ContextPtr:LookUpControl("/InGame/MinimapPanel/MapPinListButton")
-- 	MapPinListButton:SetHide(true);
-- end
-- Events.LoadScreenClose.Add(OnLoadScreenClose)
-- ----
-- 新代码：函数 MPT 前缀；LookUpControl 找不到控件时 nil 防御（HUD 隐藏/布局变体不报错）
function MPT_OnLoadScreenClose()
	local MapPinListButton : table = ContextPtr:LookUpControl("/InGame/MinimapPanel/MapPinListButton");
	if MapPinListButton ~= nil then
		MapPinListButton:SetHide(true);
	end
end
Events.LoadScreenClose.Add(MPT_OnLoadScreenClose);
