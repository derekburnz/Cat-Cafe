--!strict
-- #3396: the drawn pictures that the walk-up rings show on their cards (WorldBuilder, server) and that the client's
-- windows and menus show as badges (ShopIcons' Icon_Clean_* of the same name). One table, so a replaced upload
-- changes both. Sources and the upload runs: assets/cat-cafe/ui/icons-clean-2026-11-11/README.md.

local StationIcons = table.freeze({
	arcade = "rbxassetid://120353026211586",
	index = "rbxassetid://138454303453433",
	lostFound = "rbxassetid://106814161165186",
	museum = "rbxassetid://106957137610323",
	picnic = "rbxassetid://92455587075019",
	pond = "rbxassetid://116298242454261",
	spa = "rbxassetid://90117647745743",
	yardSale = "rbxassetid://132170661858712",
})

return StationIcons
