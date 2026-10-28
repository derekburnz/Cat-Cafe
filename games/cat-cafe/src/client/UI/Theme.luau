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

-- Button fills (Derek 2026-10-27: "copy the ui button background from the popular games"): each face is a
-- gradient from `top` to `bottom` over a darker `depth` lip, under faint tile marks, a light rim and a gloss
-- (Components/Button). Brighter than the cafe palette above, as in popular simulators, in the same hues.
Theme.button = {
	primary = {
		top = Color3.fromHex("7BE85A"),
		bottom = Color3.fromHex("3DBF3F"),
		depth = Color3.fromHex("2A8A2E"),
	},
	secondary = {
		top = Color3.fromHex("5CC8FF"),
		bottom = Color3.fromHex("2E8FEA"),
		depth = Color3.fromHex("1F66B8"),
	},
	gold = {
		top = Color3.fromHex("FFE14A"),
		bottom = Color3.fromHex("FFAE1F"),
		depth = Color3.fromHex("D9820F"),
	},
	berry = {
		top = Color3.fromHex("FF86CF"),
		bottom = Color3.fromHex("F0479F"),
		depth = Color3.fromHex("B8336F"),
	},
	ghost = {
		top = Color3.fromHex("FFF8EE"),
		bottom = Color3.fromHex("EFE0CB"),
		depth = Color3.fromHex("D2B895"),
	},
	danger = {
		top = Color3.fromHex("FFAD55"),
		bottom = Color3.fromHex("FF7A26"),
		depth = Color3.fromHex("C9561A"),
	},
	close = {
		top = Color3.fromHex("FF7062"),
		bottom = Color3.fromHex("E83A3A"),
		depth = Color3.fromHex("A82525"),
	},
	disabled = {
		top = Color3.fromHex("D8CDBF"),
		bottom = Color3.fromHex("C2B5A6"),
		depth = Color3.fromHex("A6978A"),
	},
} :: { [string]: { top: Color3, bottom: Color3, depth: Color3 } }

-- Golden fish (F52, golden-fish.md section 1): the rare currency's coin (Components/FishCoin) and its counter text.
Theme.fish = {
	coin = Color3.fromHex("FFB627"),
	rim = Color3.fromHex("FFE08A"),
	text = Color3.fromHex("FFD966"),
}

-- Uploaded images. Empty until the image is on Roblox; whatever uses one draws without it until then.
Theme.textures = {
	-- the faint L-shaped tile mark repeated over button faces (assets/cat-cafe/ui/textures/UI_ButtonTiles.png)
	buttonTiles = "rbxassetid://79710930693221",
	-- the golden fish coin with its cat face and ears (assets/cat-cafe/exports/icons/CatCafe_Icon_GoldenFish.png)
	fishCoin = "rbxassetid://77287948377172",
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
-- Derek 2026-10-27: "the menu's should be less bright and easier to read through". The window body is a toasted
-- latte instead of bright cream, cards sit a step lighter so rows stand apart, and small grey text is dark enough
-- to read on both (6A5B4F is 4.7:1 on the body and 5.9:1 on a card; the old 8A7B6E was 3.5:1 on cream).
Theme.modal = {
	backdrop = Theme.colors.ink,
	backdropTransparency = 0.45,
	panel = Color3.fromHex("E9DAC6"),
	header = Theme.colors.caramel,
	headerText = Theme.colors.paper,
	card = Color3.fromHex("FAF3E8"),
	cardStroke = Color3.fromHex("C4A57F"), -- warm caramel edge so cards read as chunky tiles
	text = Theme.colors.ink,
	subtext = Color3.fromHex("6A5B4F"),
}

-- `ink` is the rarity as text on a light card (odds rows, Derek 2026-10-28), dark enough to read at 14 px
Theme.rarity = {
	Common = {
		color = Color3.fromHex("8E97B2"),
		text = Color3.fromHex("FFFFFF"),
		ink = Color3.fromHex("6E7691"),
	},
	Rare = {
		color = Color3.fromHex("5FA8FF"),
		text = Color3.fromHex("FFFFFF"),
		ink = Color3.fromHex("2F80E0"),
	},
	Epic = {
		color = Color3.fromHex("C07CFF"),
		text = Color3.fromHex("FFFFFF"),
		ink = Color3.fromHex("9A52E0"),
	},
	Legendary = {
		color = Color3.fromHex("FFC94D"),
		text = Color3.fromHex("3A2A00"),
		ink = Color3.fromHex("9E7208"),
	},
	-- v0.3: Mythical replaces Secret (data-model section 2; the designer's proposed color)
	Mythical = {
		color = Color3.fromHex("FF5E7E"),
		text = Color3.fromHex("FFFFFF"),
		ink = Color3.fromHex("E23D62"),
	},
}
Theme.rarityOrder = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

-- Each area's colour, close to its ground in the world (style guide palette): area cards and title cards.
Theme.areaColors = {
	alley = Color3.fromHex("8A7B6E"),
	park = Color3.fromHex("5FB3A0"),
	neighbourhood = Color3.fromHex("5FA8FF"),
	woods = Color3.fromHex("2B7F4C"),
	sewer = Color3.fromHex("6E7F86"),
	all = Color3.fromHex("F2679E"), -- the Index's All Cats page (F54), in berry
	spare = Color3.fromHex("9C88C4"), -- the Index's Spare page (F78), in lavender
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
	unlock = "🔓",
	food = "🐟",
	moon = "🌙",
	invite = "💌",
	equipBest = "✨",
	drop = "⬇️",
	settings = "⚙️",
	gifts = "🎁",
	spin = "🎡",
	goldenFish = "🐟", -- in text only; tiles and the HUD draw the cat-face coin (Components/FishCoin)
	crate = "📦",
	tag = "🏷️",
	potion = "🧪", -- v0.10 potions in prizes until the asset thread draws the bottles
	tutorial = "?", -- F72: the Tutorial tile's big question mark, drawn in the display font
	replay = "🎬", -- F72: Settings' Replay tutorial row
}

-- The drawn icon sheet (assets/cat-cafe/ui/icons/UI_IconSheet.png, Derek 2026-10-27: "a lot of the symbols like
-- index upgrades and cats could use a tiny bit more quality also"): sixteen 256 px icons in a 4 x 4 grid, one upload.
-- Each glyph above that has a picture maps to its cell (column, row); Components/IconArt draws the picture over the
-- glyph wherever a button, window badge, prize tile or place icon shows it, with the emoji as the fallback.
Theme.iconSheet = {
	image = "rbxassetid://105899778786945",
	cell = 256,
	cells = {
		[Theme.icons.cats] = Vector2.new(0, 0),
		[Theme.icons.collection] = Vector2.new(1, 0),
		[Theme.icons.upgrades] = Vector2.new(2, 0),
		[Theme.icons.decor] = Vector2.new(3, 0),
		[Theme.icons.home] = Vector2.new(0, 1),
		[Theme.icons.travel] = Vector2.new(1, 1),
		[Theme.icons.alley] = Vector2.new(2, 1),
		[Theme.icons.equipBest] = Vector2.new(3, 1),
		[Theme.icons.gifts] = Vector2.new(0, 2),
		[Theme.icons.settings] = Vector2.new(1, 2),
		[Theme.icons.invite] = Vector2.new(2, 2),
		[Theme.icons.tutorial] = Vector2.new(3, 2),
		[Theme.icons.spin] = Vector2.new(0, 3),
		[Theme.icons.lock] = Vector2.new(1, 3),
		[Theme.icons.crate] = Vector2.new(2, 3),
		[Theme.icons.potion] = Vector2.new(3, 3),
	} :: { [string]: Vector2 },
}

-- A glyph per upgrade and per role for the Upgrades rows until the asset thread renders icons
Theme.upgradeIcons = {
	tables = "🪑",
	espresso = "☕",
	net = "🥅",
	lure_bowl = "🥣",
} :: { [string]: string }

Theme.roleIcons = {
	barista = "☕",
	waiter = "🍰",
	greeter = "👋",
	entertainer = "🎈",
} :: { [string]: string }

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

function Theme.rarityInk(rarity: string?): Color3
	local entry = (Theme.rarity :: any)[rarity or "Common"]
	if entry then
		return entry.ink
	end
	return Theme.rarity.Common.ink
end

return Theme
