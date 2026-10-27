--!strict
-- Visual tokens for the cat cafe UI. "Cozy Cream" from the concept sketches is the default.
-- Change colors here, not in screens. Rarity colors are shared with the collection, shop and catch prompt.

local Theme = {}

Theme.name = "Cozy Cream"
Theme.currencySymbol = "$"

-- Palette (hex from docs/concepts: Cozy Cream)
Theme.colors = {
	cream = Color3.fromHex("F6EBDD"),
	paper = Color3.fromHex("FFF9F2"),
	caramel = Color3.fromHex("C98A4B"),
	caramelDark = Color3.fromHex("A86F3E"),
	mint = Color3.fromHex("8FD3C1"),
	mintDark = Color3.fromHex("5FB3A0"),
	pink = Color3.fromHex("E8A0A0"),
	cocoa = Color3.fromHex("5E4634"),
	cocoaDeep = Color3.fromHex("3A2E2A"),
	ink = Color3.fromHex("2B2420"),
	muted = Color3.fromHex("8A7B6E"),
	line = Color3.fromHex("E3D2BC"),
	-- semantic
	good = Color3.fromHex("3FA868"),
	goodDark = Color3.fromHex("2B7F4C"),
	goodText = Color3.fromHex("0E2A16"),
	warn = Color3.fromHex("E07A3A"),
	warnDark = Color3.fromHex("B65C24"),
	gold = Color3.fromHex("FFC94D"),
	goldDark = Color3.fromHex("D19E22"),
	goldText = Color3.fromHex("3A2A00"),
	sky = Color3.fromHex("5FA8FF"),
	skyDark = Color3.fromHex("3B7FD1"),
	skyText = Color3.fromHex("0B1F3A"),
	disabled = Color3.fromHex("CFC2B4"),
	disabledDark = Color3.fromHex("B5A595"),
	disabledText = Color3.fromHex("7E7267"),
	white = Color3.fromHex("FFFFFF"),
	black = Color3.fromHex("000000"),
	-- v2 style: the warm near-black outline round buttons, panels and text (the Roblox simulator look)
	outline = Color3.fromHex("2A1C15"),
	red = Color3.fromHex("F0524F"),
	redDark = Color3.fromHex("BE3330"),
	berry = Color3.fromHex("F2679E"),
	berryDark = Color3.fromHex("C2477A"),
}

-- HUD panels float over the 3D world, so they are dark and solid for contrast, with a thick dark outline
-- and a lighter top edge like the HUDs of popular Roblox simulators.
Theme.hud = {
	panel = Theme.colors.cocoaDeep,
	-- opaque: world BillboardGuis (slot labels, name tags) render under the HUD and ghosted through at 0.12
	panelTransparency = 0,
	stroke = Theme.colors.outline,
	strokeTransparency = 0,
	text = Theme.colors.paper,
	subtext = Color3.fromHex("E6D8C6"),
	income = Color3.fromHex("8DE0A5"),
}

-- Modal windows sit on a dim backdrop and use the light cafe palette.
Theme.modal = {
	backdrop = Theme.colors.ink,
	backdropTransparency = 0.45,
	panel = Theme.colors.cream,
	header = Theme.colors.caramel,
	headerText = Theme.colors.paper,
	card = Theme.colors.paper,
	cardStroke = Color3.fromHex("CDB08E"), -- warm caramel edge so cards read as chunky tiles
	text = Theme.colors.ink,
	subtext = Theme.colors.muted,
}

Theme.rarity = {
	Common = { color = Color3.fromHex("8E97B2"), text = Color3.fromHex("FFFFFF") },
	Rare = { color = Color3.fromHex("5FA8FF"), text = Color3.fromHex("FFFFFF") },
	Epic = { color = Color3.fromHex("C07CFF"), text = Color3.fromHex("FFFFFF") },
	Legendary = { color = Color3.fromHex("FFC94D"), text = Color3.fromHex("3A2A00") },
	-- v0.3: Mythical replaces Secret (data-model section 2; the designer's proposed color)
	Mythical = { color = Color3.fromHex("FF5E7E"), text = Color3.fromHex("FFFFFF") },
}
Theme.rarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

-- Each area's colour, close to its ground in the world (style guide palette): area cards and title cards.
Theme.areaColors = {
	alley = Color3.fromHex("8A7B6E"),
	park = Color3.fromHex("5FB3A0"),
	neighbourhood = Color3.fromHex("5FA8FF"),
	woods = Color3.fromHex("2B7F4C"),
	sewer = Color3.fromHex("6E7F86"),
} :: { [string]: Color3 }

-- Fonts. Fredoka One for numbers and titles, Nunito for everything else (both ship with Roblox).
Theme.fonts = {
	display = Font.new(
		"rbxasset://fonts/families/FredokaOne.json",
		Enum.FontWeight.Regular,
		Enum.FontStyle.Normal
	),
	body = Font.new(
		"rbxasset://fonts/families/Nunito.json",
		Enum.FontWeight.SemiBold,
		Enum.FontStyle.Normal
	),
	bodyBold = Font.new(
		"rbxasset://fonts/families/Nunito.json",
		Enum.FontWeight.Bold,
		Enum.FontStyle.Normal
	),
}

-- Sizes are design pixels at 1280x720. Scale.luau maps them to the device.
Theme.sizes = {
	radius = 12,
	radiusSmall = 8,
	radiusPill = 999,
	stroke = 2,
	outline = 3, -- dark outline round buttons and panels
	textOutline = 2, -- dark outline round display text
	buttonDepth = 5, -- the chunky bottom edge under buttons
	touchMin = 44,
	textTitle = 26,
	textLarge = 22,
	textBody = 16,
	textSmall = 14,
	textTiny = 12,
	padding = 12,
	gap = 8,
}

-- Icon glyphs for buttons and chips. Colour emoji render on every Roblox platform, so they stand in until
-- the asset thread draws real icons.
Theme.icons = {
	upgrades = "⬆️",
	decor = "🪴",
	cats = "🐱",
	collection = "📖",
	travel = "🧭",
	home = "🏠",
	alley = "🐾",
	park = "🌳",
	neighbourhood = "🏘️",
	woods = "🌲",
	sewer = "🕳️",
	lock = "🔒",
	food = "🐟",
	moon = "🌙",
	invite = "👥",
	equipBest = "✨",
	drop = "⬇️",
}

-- A glyph per food for shop rows until the asset thread's item model is in ReplicatedStorage.Assets
Theme.foodIcons = {
	kibble = "🥣",
	tuna = "🥫",
	salmon = "🍣",
	sardines = "🐟",
	caviar = "🦪",
	moon_milk = "🥛",
	star_treat = "⭐",
} :: { [string]: string }

function Theme.rarityColor(rarity: string?): Color3
	local entry = (Theme.rarity :: any)[rarity or "Common"]
	if entry then
		return entry.color
	end
	return Theme.rarity.Common.color
end

function Theme.rarityTextColor(rarity: string?): Color3
	local entry = (Theme.rarity :: any)[rarity or "Common"]
	if entry then
		return entry.text
	end
	return Theme.rarity.Common.text
end

return Theme
