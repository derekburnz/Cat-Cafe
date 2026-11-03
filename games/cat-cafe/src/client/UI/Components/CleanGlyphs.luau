--!strict
-- Which clean symbol (Components/ShopIcons.clean, assets/cat-cafe/ui/icons-clean-2026-11-03) stands in for a glyph
-- wherever Components/IconArt draws it: window badges, prize tiles, item icons and buttons, so the windows match the
-- clean HUD (Derek live v181, #1027: "old pics of tips and daily rewards are still not updaed"). A glyph without a
-- clean symbol keeps its old icon sheet cell until one is drawn. Theme.cleanGlyphs is built from these tables.

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
} :: { [string]: string }

-- Theme.foodIcons key -> clean symbol name
CleanGlyphs.foods = {
	kibble = "Bowl",
	caviar = "Caviar",
} :: { [string]: string }

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
