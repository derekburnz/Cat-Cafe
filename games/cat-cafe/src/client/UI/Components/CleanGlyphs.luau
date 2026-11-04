--!strict
-- Which clean symbol (Components/ShopIcons.clean, assets/cat-cafe/ui/icons-clean-2026-11-03) stands in for a glyph
-- wherever Components/IconArt draws it: window badges, prize tiles, item icons and buttons, so the windows match the
-- clean HUD (Derek live v181, #1027: "old pics of tips and daily rewards are still not updaed"). A glyph without a
-- clean symbol keeps its old icon sheet cell (Theme.iconSheet.cells) until one is drawn; since #1136 every sheet cell
-- has one, so no glyph reaches the sheet. Theme.cleanGlyphs is built from these tables.

local CleanGlyphs = {}

-- Theme.icons key -> clean symbol name
CleanGlyphs.icons = {
	cats = "Cats",
	collection = "Index",
	upgrades = "Upgrades",
	decor = "Decor",
	home = "Home",
	travel = "Areas",
	cannon = "Cannon",
	feedback = "Feedback",
	gifts = "Rewards", -- the Tip Jar's gifts
	daily = "Rewards", -- the Daily Treat shares the HUD's Rewards tile
	crate = "Crate",
	potion = "Potion",
	quests = "Quests",
	tutorial = "Tutorial",
	store = "Store", -- the Store window's badge: the HUD tile's chest
	-- the last three sheet glyphs that already had a clean symbol (Derek live v187: "still shows the old images on ui
	-- buttons"): the Settings gear, the Spin wheel and the Alley's paw door
	settings = "Menu",
	spin = "Spin",
	alley = "Catflap",
	-- #1136: the three drawn for this map (sparkles, an envelope with a heart seal, a gold padlock)
	equipBest = "EquipBest",
	invite = "Invite",
	lock = "Lock",
} :: { [string]: string }

-- Theme.foodIcons key -> clean symbol name
CleanGlyphs.foods = {
	kibble = "Bowl",
	caviar = "Caviar",
} :: { [string]: string }

-- Theme.icons key -> its cell (column, row) on the old 2026-10-27 icon sheet (Theme.iconSheet), kept here so the cloud
-- spec can check every cell has a clean symbol above (Theme itself needs Font, which the cloud runner lacks)
CleanGlyphs.sheetCells = {
	cats = Vector2.new(0, 0),
	collection = Vector2.new(1, 0),
	upgrades = Vector2.new(2, 0),
	decor = Vector2.new(3, 0),
	home = Vector2.new(0, 1),
	travel = Vector2.new(1, 1),
	alley = Vector2.new(2, 1),
	equipBest = Vector2.new(3, 1),
	gifts = Vector2.new(0, 2),
	settings = Vector2.new(1, 2),
	invite = Vector2.new(2, 2),
	tutorial = Vector2.new(3, 2),
	spin = Vector2.new(0, 3),
	lock = Vector2.new(1, 3),
	crate = Vector2.new(2, 3),
	potion = Vector2.new(3, 3),
} :: { [string]: Vector2 }

-- glyph -> sheet cell, from Theme.icons
function CleanGlyphs.sheet(icons: { [string]: string }): { [string]: Vector2 }
	local out: { [string]: Vector2 } = {}
	for key, cell in CleanGlyphs.sheetCells do
		local glyph = icons[key]
		if glyph then
			out[glyph] = cell
		end
	end
	return out
end

-- glyph -> clean symbol name, from Theme.icons and Theme.foodIcons
function CleanGlyphs.map(
	icons: { [string]: string },
	foodIcons: { [string]: string }
): { [string]: string }
	local out: { [string]: string } = {}
	for key, name in CleanGlyphs.icons do
		local glyph = icons[key]
		if glyph then
			out[glyph] = name
		end
	end
	for key, name in CleanGlyphs.foods do
		local glyph = foodIcons[key]
		if glyph then
			out[glyph] = name
		end
	end
	return out
end

return CleanGlyphs
