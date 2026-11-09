--!strict
-- shared/LateTiers.luau: Tier 6 (the Desert, Sunstone Cafe) and Tier 7 (the Ruins, Wonder Cafe) as data, staged
-- before they open (tier6-7-areas.md sections 1, 2, 4, 5 and 6; epic #2580, claim #2651). Nothing in the game reads
-- this yet: a cat here never spawns, counts toward no Index total and isn't in Catalog.cats. Opening them (part 3)
-- moves these rows into Catalog.cats, Catalog.areas and Catalog.tiers and bumps the save version, because an older
-- server would drop the new cat ids from a save. The costs, caps and wave sizes are the draft's until the Pace run.
local Shared = script.Parent
local Catalog = require(Shared.Catalog)
local Types = require(Shared.Types)

local LateTiers = {}

-- The area ids, in tier order. Types.Area gains them when they open.
LateTiers.AREAS = { "desert", "ruins" }

-- Section 1: each area pays three times the one before (Sewer 81).
LateTiers.AREA_INCOME = { desert = 243, ruins = 729 } :: { [string]: number }

export type LateArea = {
	id: string,
	name: string,
	tier: number,
	spawnPoints: number,
	waveSize: number,
	rescueSpots: number,
	odds: Types.LureOdds,
	incomeMultiplier: number,
	centre: { x: number, z: number }, -- the draft centre, about 2000 studs out on a free diagonal (section 2)
	size: { width: number, depth: number }, -- the long axis runs along world Z
	pityWeight: number, -- PityAreaWeights (section 7)
}

export type LateTier = {
	tier: number,
	name: string,
	cost: number,
	distinctCats: number,
	needsRarity: Types.Rarity,
	needsRarityCount: number,
	slots: number,
	multiplier: number,
	area: string,
	caps: { tables: number, espresso: number, net: number, lure_bowl: number, lucky_cat: number },
}

export type LateCat = {
	id: string,
	name: string,
	rarity: Types.Rarity,
	incomePerSecond: number,
	area: string,
	favoriteRole: Types.Role,
	description: string,
	pattern: string,
	color: { number }, -- the fur {r, g, b} for the placeholder body; the model uses the nearest swatch (6b)
}

-- every area since #1452 uses the same odds
local ODDS: Types.LureOdds = { Common = 54, Rare = 29, Epic = 11, Legendary = 4.8, Mythical = 1.2 }

LateTiers.areas = {
	{
		id = "desert",
		name = "Desert",
		tier = 6,
		spawnPoints = 66, -- 26 near the camp, 40 deep (section 4)
		waveSize = 11, -- the current per-area wave (#2557)
		rescueSpots = 5, -- two dunes, two clay urns and a collapsed canopy
		odds = ODDS,
		incomeMultiplier = LateTiers.AREA_INCOME.desert,
		centre = { x = 1400, z = -1400 }, -- south-east, the barrel at about 129 degrees
		size = { width = 150, depth = 560 },
		pityWeight = 35,
	},
	{
		id = "ruins",
		name = "Ruins",
		tier = 7,
		spawnPoints = 70, -- 28 near, 42 deep (section 5)
		waveSize = 11,
		rescueSpots = 5, -- two rubble piles, two stone urns and the broken bridge ledge
		odds = ODDS,
		incomeMultiplier = LateTiers.AREA_INCOME.ruins,
		centre = { x = 1400, z = 1400 }, -- north-east, the barrel at about 51.5 degrees
		size = { width = 140, depth = 600 },
		pityWeight = 40,
	},
} :: { LateArea }

-- Section 1 and section 9 (names decided for Derek2, 2026-11-09). The caps follow Tier 5's until the Pace run.
LateTiers.tiers = {
	{
		tier = 6,
		name = "Sunstone Cafe",
		cost = 70000000000, -- draft ~70B
		distinctCats = 42,
		needsRarity = "Mythical",
		needsRarityCount = 2,
		slots = 12,
		multiplier = 2.25,
		area = "desert",
		caps = { tables = 6, espresso = 5, net = 3, lure_bowl = 5, lucky_cat = 6 },
	},
	{
		tier = 7,
		name = "Wonder Cafe",
		cost = 1800000000000, -- draft ~1.8T
		distinctCats = 52,
		needsRarity = "Mythical",
		needsRarityCount = 3,
		slots = 14,
		multiplier = 2.50,
		area = "ruins",
		caps = { tables = 6, espresso = 5, net = 3, lure_bowl = 5, lucky_cat = 7 },
	},
} :: { LateTier }

local function cat(
	id: string,
	name: string,
	rarity: Types.Rarity,
	area: string,
	favoriteRole: Types.Role,
	pattern: string,
	color: { number },
	description: string
): LateCat
	return {
		id = id,
		name = name,
		rarity = rarity,
		incomePerSecond = Catalog.rarities[rarity].incomePerSecond * LateTiers.AREA_INCOME[area],
		area = area,
		favoriteRole = favoriteRole,
		description = description,
		pattern = pattern,
		color = color,
	}
end

-- Section 6: ten per area, four Common (one per role), two Rare, two Epic, one Legendary, one Mythical. Model-Agent
-- built them as CatCafe_Cat_<Name> with _Sit, _Work and gold twins (#2611, #2640).
LateTiers.cats = {
	-- 6a. the Desert
	cat(
		"sandy",
		"Sandy",
		"Common",
		"desert",
		"barista",
		"solid",
		{ 226, 196, 140 },
		"Shakes a little sand out of every cup."
	),
	cat(
		"dune",
		"Dune",
		"Common",
		"desert",
		"waiter",
		"stripes",
		{ 214, 168, 110 },
		"Stripes like wind on a dune."
	),
	cat(
		"dusty",
		"Dusty",
		"Common",
		"desert",
		"greeter",
		"patches",
		{ 190, 160, 130 },
		"Waves hello in a little puff of dust."
	),
	cat(
		"sunny",
		"Sunny",
		"Common",
		"desert",
		"entertainer",
		"points",
		{ 250, 230, 180 },
		"Always finds the warmest spot."
	),
	cat(
		"fennec",
		"Fennec Cat",
		"Rare",
		"desert",
		"greeter",
		"solid",
		{ 232, 196, 150 },
		"Those ears hear a tip from across town."
	),
	cat(
		"camel",
		"Camel Cat",
		"Rare",
		"desert",
		"waiter",
		"patches",
		{ 196, 150, 100 },
		"Carries three trays at once on its saddle."
	),
	cat(
		"scarab",
		"Scarab Cat",
		"Epic",
		"desert",
		"barista",
		"gradient",
		{ 40, 120, 110 },
		"Shiny as a beetle, twice as busy."
	),
	cat(
		"mirage",
		"Mirage Cat",
		"Epic",
		"desert",
		"entertainer",
		"gradient",
		{ 240, 200, 160 },
		"Now you see it, now it's serving you."
	),
	cat(
		"pharaoh",
		"Pharaoh Cat",
		"Legendary",
		"desert",
		"waiter",
		"solid",
		{ 40, 40, 50 },
		"Rules the cafe from a cushion."
	),
	-- not the DJ Cat's `sphynx` (the breed): CatCafe_Cat_Sphinx and CatCafe_Cat_Sphynx stay apart
	cat(
		"sphinx",
		"Sphinx",
		"Mythical",
		"desert",
		"barista",
		"solid",
		{ 210, 170, 110 },
		"Asks a riddle before every order."
	),
	-- 6b. the Ruins
	cat(
		"pebble",
		"Pebble",
		"Common",
		"ruins",
		"barista",
		"solid",
		{ 140, 140, 135 },
		"Small, grey and very hard to move off the counter."
	),
	cat(
		"rubble",
		"Rubble",
		"Common",
		"ruins",
		"waiter",
		"patches",
		{ 160, 150, 135 },
		"A little bit of everything, held together by naps."
	),
	cat(
		"clay",
		"Clay",
		"Common",
		"ruins",
		"greeter",
		"solid",
		{ 190, 110, 70 },
		"Warm as a fresh pot."
	),
	cat(
		"ivy",
		"Ivy",
		"Common",
		"ruins",
		"entertainer",
		"stripes",
		{ 120, 130, 110 },
		"Climbs everything, falls off nothing."
	),
	cat(
		"glyph",
		"Hieroglyph Cat",
		"Rare",
		"ruins",
		"barista",
		"patches",
		{ 222, 196, 150 },
		"Its coat tells the whole cafe's story."
	),
	cat(
		"torch",
		"Torch Cat",
		"Rare",
		"ruins",
		"greeter",
		"solid",
		{ 120, 80, 60 },
		"Lights the way to your table."
	),
	cat(
		"gargoyle",
		"Gargoyle Cat",
		"Epic",
		"ruins",
		"waiter",
		"solid",
		{ 110, 115, 120 },
		"Sits so still you'll think it's a statue."
	),
	cat(
		"mosaic",
		"Mosaic Cat",
		"Epic",
		"ruins",
		"entertainer",
		"patches",
		{ 60, 120, 170 },
		"Made of a thousand tiny tiles."
	),
	cat(
		"golem",
		"Golem Cat",
		"Legendary",
		"ruins",
		"barista",
		"solid",
		{ 130, 125, 115 },
		"Big, gentle and very good at carrying trays."
	),
	cat(
		"jade_guardian",
		"Jade Guardian",
		"Mythical",
		"ruins",
		"greeter",
		"gradient",
		{ 70, 160, 120 },
		"The temple's oldest guard, awake at last."
	),
} :: { LateCat }

LateTiers.catsById = {} :: { [string]: LateCat }
for _, def in LateTiers.cats do
	LateTiers.catsById[def.id] = def
end

return LateTiers
