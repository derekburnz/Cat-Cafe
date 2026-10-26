--!strict
-- Every catalog table from docs/design/cat-cafe/data-model.md (sections 2, 3, 5 to 9).
-- Pure data plus lookups. Ids never change once saved; display names can.
-- Model names derive from ids: cat "tabby" is ReplicatedStorage.Assets.CatCafe_Cat_Tabby.

local Types = require(script.Parent.Types)

local Catalog = {}

-- Section 2
Catalog.rarities = {
	Common = {
		incomePerSecond = 1,
		baseCatchChance = 0.90,
		fleesOnMiss = false,
		sellValue = 25,
		firstCatchReward = 50,
		color = "#8E97B2",
	},
	Rare = {
		incomePerSecond = 3,
		baseCatchChance = 0.65,
		fleesOnMiss = true,
		sellValue = 150,
		firstCatchReward = 300,
		color = "#5FA8FF",
	},
	Epic = {
		incomePerSecond = 8,
		baseCatchChance = 0.45,
		fleesOnMiss = true,
		sellValue = 600,
		firstCatchReward = 1500,
		color = "#C07CFF",
	},
	Legendary = {
		incomePerSecond = 25,
		baseCatchChance = 0.25,
		fleesOnMiss = true,
		sellValue = 3000,
		firstCatchReward = 8000,
		color = "#FFC94D",
	},
	Secret = {
		incomePerSecond = 60,
		baseCatchChance = 0.20,
		fleesOnMiss = true,
		sellValue = 10000,
		firstCatchReward = 25000,
		color = "#3FD0B5",
	},
} :: { [string]: Types.RarityDef }

Catalog.rarityOrder = { "Common", "Rare", "Epic", "Legendary", "Secret" } :: { Types.Rarity }
Catalog.rarityRank =
	{ Common = 1, Rare = 2, Epic = 3, Legendary = 4, Secret = 5 } :: { [string]: number }

local function cat(
	id: string,
	name: string,
	rarity: Types.Rarity,
	area: Types.Area,
	favoriteSpot: Types.SpotType,
	description: string,
	pattern: string,
	color: { number }
): Types.CatDef
	return {
		id = id,
		name = name,
		rarity = rarity,
		incomePerSecond = Catalog.rarities[rarity].incomePerSecond,
		area = area,
		favoriteSpot = favoriteSpot,
		description = description,
		pattern = pattern,
		color = color,
	}
end

-- Section 3 (12 cats in the slice)
Catalog.cats = {
	cat(
		"tabby",
		"Tabby",
		"Common",
		"both",
		"counter",
		"The starter. Stripes, snacks, naps.",
		"stripes",
		{ 214, 140, 70 }
	),
	cat(
		"tuxedo",
		"Tuxedo",
		"Common",
		"both",
		"window",
		"Dressed for dinner, waiting for it.",
		"patches",
		{ 35, 35, 40 }
	),
	cat(
		"ginger",
		"Ginger",
		"Common",
		"both",
		"cushion",
		"Warm, round, always in the sun.",
		"solid",
		{ 235, 130, 50 }
	),
	cat(
		"smoke",
		"Smoke",
		"Common",
		"both",
		"shelf",
		"Grey as a rainy morning.",
		"solid",
		{ 120, 120, 130 }
	),
	cat(
		"snow",
		"Snow",
		"Common",
		"both",
		"window",
		"All white, hates the alley puddles.",
		"solid",
		{ 250, 250, 252 }
	),
	cat(
		"calico",
		"Calico",
		"Rare",
		"both",
		"cushion",
		"Three colors, three opinions.",
		"patches",
		{ 240, 190, 120 }
	),
	cat(
		"siamese",
		"Siamese",
		"Rare",
		"both",
		"counter",
		"Loud. Supervises the espresso machine.",
		"points",
		{ 225, 205, 175 }
	),
	cat(
		"tortie",
		"Tortie",
		"Rare",
		"park",
		"shelf",
		"Brindled and bossy.",
		"patches",
		{ 110, 70, 45 }
	),
	cat(
		"bengal",
		"Bengal",
		"Rare",
		"park",
		"cattree",
		"Spotted and fast. Climbs everything.",
		"spots",
		{ 200, 150, 80 }
	),
	cat(
		"sphynx",
		"Sphynx",
		"Epic",
		"both",
		"cushion",
		"No fur, all attitude. Loves the warm cushion.",
		"solid",
		{ 230, 180, 170 }
	),
	cat(
		"ragdoll",
		"Ragdoll",
		"Epic",
		"park",
		"cattree",
		"Huge, fluffy, goes limp when carried.",
		"points",
		{ 240, 235, 230 }
	),
	cat(
		"void",
		"Void",
		"Legendary",
		"both",
		"shelf",
		"Pure black with glowing eyes. Appears when you stop looking.",
		"solid",
		{ 12, 12, 16 }
	),
} :: { Types.CatDef }

Catalog.catsById = {} :: { [string]: Types.CatDef }
for _, def in Catalog.cats do
	Catalog.catsById[def.id] = def
end

function Catalog.getCat(id: string): Types.CatDef?
	return Catalog.catsById[id]
end

-- "tabby" -> "CatCafe_Cat_Tabby"
function Catalog.catModelName(catId: string): string
	return "CatCafe_Cat_" .. catId:sub(1, 1):upper() .. catId:sub(2)
end

-- Section 5: spots and the cafe level that opens them
Catalog.spots = {
	{ id = "counter_1", spotType = "counter", cafeLevel = 1 },
	{ id = "window_1", spotType = "window", cafeLevel = 1 },
	{ id = "cushion_1", spotType = "cushion", cafeLevel = 2 },
	{ id = "shelf_1", spotType = "shelf", cafeLevel = 3 },
	{ id = "cattree_1", spotType = "cattree", cafeLevel = 4 },
	{ id = "patio_1", spotType = "patio", cafeLevel = 5 },
	{ id = "patio_2", spotType = "patio", cafeLevel = 5 },
} :: { Types.SpotDef }

Catalog.spotsById = {} :: { [string]: Types.SpotDef }
for _, def in Catalog.spots do
	Catalog.spotsById[def.id] = def
end

function Catalog.getSpot(id: string): Types.SpotDef?
	return Catalog.spotsById[id]
end

-- Furniture model shown at each spot type
Catalog.spotFurniture = {
	counter = "CatCafe_Furniture_Counter",
	window = "CatCafe_Furniture_WindowSeat",
	cushion = "CatCafe_Furniture_Cushion",
	shelf = "CatCafe_Furniture_WallShelf",
	cattree = "CatCafe_Furniture_CatTree",
	patio = "CatCafe_Furniture_PatioBench",
} :: { [string]: string }

-- Section 6
Catalog.upgrades = {
	{
		id = "cafe_level",
		name = "Cafe level",
		description = "Opens new cat spots and unlocks more of the shop",
		maxLevel = 5,
		costs = { 0, 250, 800, 2500, 8000 },
		startLevel = 1,
	},
	{
		id = "tables",
		name = "Tables",
		description = "Each table seats two more customers and adds tips",
		maxLevel = 6,
		costs = { 100, 250, 600, 1500, 3500, 8000 },
		startLevel = 0,
	},
	{
		id = "espresso",
		name = "Espresso machine",
		description = "Better coffee, bigger tips from every cat",
		maxLevel = 3,
		costs = { 0, 300, 1200, 4000, 12000 },
		startLevel = 1,
		requiresCafeLevelAtLevel = { [3] = 3 },
	},
	{
		id = "gloves",
		name = "Catching gloves",
		description = "Steadier hands: better odds on every grab",
		maxLevel = 3,
		costs = { 500, 2500, 10000 },
		startLevel = 0,
	},
	{
		id = "lure_bowl",
		name = "Lure bowl",
		description = "Unlocks luring with food at lure spots",
		maxLevel = 1,
		costs = { 400 },
		startLevel = 0,
		requiresCafeLevel = 2,
	},
	{
		id = "park_access",
		name = "Park pass",
		description = "Opens the park, where rarer cats roam",
		maxLevel = 1,
		costs = { 1000 },
		startLevel = 0,
		requiresCafeLevel = 3,
	},
} :: { Types.UpgradeDef }

Catalog.upgradesById = {} :: { [string]: Types.UpgradeDef }
for _, def in Catalog.upgrades do
	Catalog.upgradesById[def.id] = def
end

function Catalog.getUpgrade(id: string): Types.UpgradeDef?
	return Catalog.upgradesById[id]
end

-- Section 7
Catalog.decor = {
	{
		id = "plants",
		name = "Window plants",
		cost = 150,
		category = "Plants",
		effect = "+5% tips",
		description = "Green in the window, warmth in the room.",
		bonus = 0.05,
		asset = "CatCafe_Decor_WindowPlants",
	},
	{
		id = "rug",
		name = "Cozy rug",
		cost = 400,
		category = "Floor",
		effect = "+5% tips",
		description = "Warm paws, generous customers.",
		bonus = 0.05,
		asset = "CatCafe_Decor_Rug",
	},
	{
		id = "neon_sign",
		name = "Neon cat sign",
		cost = 1500,
		category = "Wall",
		effect = "+10% tips",
		description = "Seen from the far end of the street.",
		requiresCafeLevel = 4,
		bonus = 0.10,
		asset = "CatCafe_Decor_NeonSign",
	},
	{
		id = "fish_tank",
		name = "Fish tank",
		cost = 5000,
		category = "Furniture",
		effect = "+10% tips, cats stare at it",
		description = "The fish are fine. Probably.",
		requiresCafeLevel = 4,
		bonus = 0.10,
		asset = "CatCafe_Decor_FishTank",
	},
} :: { Types.DecorDef }

Catalog.decorById = {} :: { [string]: Types.DecorDef }
for _, def in Catalog.decor do
	Catalog.decorById[def.id] = def
end

function Catalog.getDecor(id: string): Types.DecorDef?
	return Catalog.decorById[id]
end

-- Section 8. Odds are shown before purchase.
Catalog.lures = {
	{
		id = "kibble",
		name = "Kibble",
		cost = 25,
		attracts = "Common",
		description = "Cheap and crunchy. Brings the regulars.",
		odds = { Common = 70, Rare = 26, Epic = 3.5, Legendary = 0.5 },
		asset = "CatCafe_Item_Kibble",
	},
	{
		id = "tuna",
		name = "Tuna",
		cost = 100,
		attracts = "Rare",
		description = "The good stuff. Rare cats come running.",
		odds = { Common = 45, Rare = 42, Epic = 11, Legendary = 2 },
		asset = "CatCafe_Item_TunaCan",
	},
	{
		id = "salmon",
		name = "Salmon",
		cost = 500,
		attracts = "Epic",
		description = "Nobody can resist it, not even the Void.",
		odds = { Common = 15, Rare = 50, Epic = 28, Legendary = 7 },
		asset = "CatCafe_Item_Salmon",
	},
} :: { Types.LureDef }

Catalog.luresById = {} :: { [string]: Types.LureDef }
for _, def in Catalog.lures do
	Catalog.luresById[def.id] = def
end

function Catalog.getLure(id: string): Types.LureDef?
	return Catalog.luresById[id]
end

-- Section 9
Catalog.areas = {
	{
		id = "alley",
		name = "Alley",
		unlock = nil,
		spawnPoints = 8,
		maxStrays = 6,
		spawnInterval = 20,
		despawnAfter = 120,
		odds = { Common = 75, Rare = 20, Epic = 4.5, Legendary = 0.5 },
	},
	{
		id = "park",
		name = "Park",
		unlock = "park_access",
		spawnPoints = 10,
		maxStrays = 6,
		spawnInterval = 20,
		despawnAfter = 120,
		odds = { Common = 55, Rare = 32, Epic = 10, Legendary = 3 },
	},
} :: { Types.AreaDef }

Catalog.areasById = {} :: { [string]: Types.AreaDef }
for _, def in Catalog.areas do
	Catalog.areasById[def.id] = def
end

function Catalog.getArea(id: string): Types.AreaDef?
	return Catalog.areasById[id]
end

Catalog.lureSpotsPerArea = { alley = 2, park = 3 } :: { [string]: number }

return Catalog
