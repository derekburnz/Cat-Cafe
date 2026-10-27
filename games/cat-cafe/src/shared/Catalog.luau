--!strict
-- Every catalog table from docs/design/cat-cafe/data-model.md (sections 2, 3, 5 to 9), design v0.3.
-- Pure data plus lookups. Ids never change once saved; display names can.
-- Model names derive from ids: cat "tabby" is ReplicatedStorage.Assets.CatCafe_Cat_Tabby.

local Types = require(script.Parent.Types)

local Catalog = {}

-- Section 2. circles and shrinkSeconds drive the net (section 10), fleeStuds is how far a stray sprints after a
-- missed catch before anyone can try again (v0.5, tries are unlimited), rescueHits the rescue bar (section 10b).
Catalog.rarities = {
	Common = {
		incomePerSecond = 1,
		circles = 1,
		shrinkSeconds = 1.40,
		fleeStuds = 12,
		rescueHits = 2,
		sellValue = 25,
		firstCatchReward = 50,
		color = "#8E97B2",
	},
	Rare = {
		incomePerSecond = 3,
		circles = 2,
		shrinkSeconds = 1.15,
		fleeStuds = 16,
		rescueHits = 3,
		sellValue = 150,
		firstCatchReward = 300,
		color = "#5FA8FF",
	},
	Epic = {
		incomePerSecond = 8,
		circles = 3,
		shrinkSeconds = 0.95,
		fleeStuds = 20,
		rescueHits = 4,
		sellValue = 600,
		firstCatchReward = 1500,
		color = "#C07CFF",
	},
	Legendary = {
		incomePerSecond = 25,
		circles = 4,
		shrinkSeconds = 0.80,
		fleeStuds = 26,
		rescueHits = 5,
		sellValue = 3000,
		firstCatchReward = 8000,
		color = "#FFC94D",
	},
	Mythical = {
		incomePerSecond = 75,
		circles = 5,
		shrinkSeconds = 0.65,
		fleeStuds = 32,
		rescueHits = 6,
		sellValue = 12000,
		firstCatchReward = 30000,
		color = "#FF5E7E",
	},
} :: { [string]: Types.RarityDef }

local rarityOrder: { Types.Rarity } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
Catalog.rarityOrder = rarityOrder
Catalog.rarityRank =
	{ Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5 } :: { [string]: number }

local function cat(
	id: string,
	name: string,
	rarity: Types.Rarity,
	area: Types.Area,
	favoriteRole: Types.Role,
	pattern: string,
	color: { number },
	description: string
): Types.CatDef
	return {
		id = id,
		name = name,
		rarity = rarity,
		incomePerSecond = Catalog.rarities[rarity].incomePerSecond,
		area = area,
		favoriteRole = favoriteRole,
		description = description,
		pattern = pattern,
		color = color,
	}
end

-- Section 3: 50 cats, 10 per area (four Common, two Rare, two Epic, one Legendary, one Mythical). Each lives in
-- exactly one area. Colors are the placeholder body's {r, g, b}.
Catalog.cats = {
	-- 3a. Alleyway, in the slice
	cat(
		"tabby",
		"Tabby",
		"Common",
		"alley",
		"barista",
		"stripes",
		{ 214, 140, 70 },
		"The starter. Stripes, snacks, naps."
	),
	cat(
		"tuxedo",
		"Tuxedo",
		"Common",
		"alley",
		"waiter",
		"patches",
		{ 35, 35, 40 },
		"Dressed for dinner, waiting for it."
	),
	cat(
		"ginger",
		"Ginger",
		"Common",
		"alley",
		"greeter",
		"solid",
		{ 235, 130, 50 },
		"Warm, round, always in the sun."
	),
	cat(
		"smoke",
		"Smoke",
		"Common",
		"alley",
		"entertainer",
		"solid",
		{ 120, 120, 130 },
		"Grey as a rainy morning."
	),
	cat(
		"calico",
		"Calico",
		"Rare",
		"alley",
		"greeter",
		"patches",
		{ 240, 190, 120 },
		"Three colors, three opinions."
	),
	cat(
		"tortie",
		"Tortie",
		"Rare",
		"alley",
		"barista",
		"patches",
		{ 110, 70, 45 },
		"Brindled and bossy."
	),
	cat(
		"sphynx",
		"Sphynx",
		"Epic",
		"alley",
		"entertainer",
		"solid",
		{ 230, 180, 170 },
		"No fur, all attitude."
	),
	cat(
		"maine_coon",
		"Maine Coon",
		"Epic",
		"alley",
		"waiter",
		"stripes",
		{ 125, 90, 60 },
		"Big as a backpack, gentle as a pillow."
	),
	cat(
		"void",
		"Void",
		"Legendary",
		"alley",
		"barista",
		"solid",
		{ 12, 12, 16 },
		"Pure black with glowing eyes. Makes the darkest espresso."
	),
	cat(
		"midnight",
		"Midnight",
		"Mythical",
		"alley",
		"greeter",
		"solid",
		{ 30, 30, 70 },
		"Fur like the night sky, freckled with stars."
	),
	-- 3b. Park, in the slice
	cat(
		"snow",
		"Snow",
		"Common",
		"park",
		"waiter",
		"solid",
		{ 250, 250, 252 },
		"All white, hates the muddy paths."
	),
	cat(
		"cream",
		"Cream",
		"Common",
		"park",
		"barista",
		"solid",
		{ 240, 220, 180 },
		"The color of a latte, and smells faintly of one."
	),
	cat(
		"brownie",
		"Brownie",
		"Common",
		"park",
		"entertainer",
		"stripes",
		{ 120, 75, 45 },
		"Chocolate stripes, chases every leaf."
	),
	cat(
		"blue",
		"Blue",
		"Common",
		"park",
		"greeter",
		"solid",
		{ 140, 155, 175 },
		"Silver-blue and very polite."
	),
	cat(
		"siamese",
		"Siamese",
		"Rare",
		"park",
		"barista",
		"points",
		{ 225, 205, 175 },
		"Loud. Supervises the espresso machine."
	),
	cat(
		"bengal",
		"Bengal",
		"Rare",
		"park",
		"entertainer",
		"spots",
		{ 200, 150, 80 },
		"Spotted and fast. Climbs everything."
	),
	cat(
		"ragdoll",
		"Ragdoll",
		"Epic",
		"park",
		"greeter",
		"points",
		{ 240, 235, 230 },
		"Huge, fluffy, goes limp when carried."
	),
	cat(
		"persian",
		"Persian",
		"Epic",
		"park",
		"waiter",
		"solid",
		{ 245, 230, 200 },
		"A cloud with a squashed face and opinions about cushions."
	),
	cat(
		"blossom",
		"Blossom",
		"Legendary",
		"park",
		"greeter",
		"patches",
		{ 245, 190, 200 },
		"Pink-cream fur, and petals follow her everywhere."
	),
	cat(
		"aurora",
		"Aurora",
		"Mythical",
		"park",
		"entertainer",
		"gradient",
		{ 110, 200, 190 },
		"Fur that shifts color like the northern lights."
	),
	-- 3c. Neighbourhood, Woods and Sewer: provisional names and roles that reserve the ids (after the slice)
	cat(
		"biscuit",
		"Biscuit",
		"Common",
		"neighbourhood",
		"barista",
		"solid",
		{ 220, 180, 120 },
		"A Neighbourhood regular. More soon."
	),
	cat(
		"pepper",
		"Pepper",
		"Common",
		"neighbourhood",
		"waiter",
		"solid",
		{ 110, 110, 115 },
		"A Neighbourhood regular. More soon."
	),
	cat(
		"socks",
		"Socks",
		"Common",
		"neighbourhood",
		"greeter",
		"patches",
		{ 40, 40, 45 },
		"A Neighbourhood regular. More soon."
	),
	cat(
		"butter",
		"Butter",
		"Common",
		"neighbourhood",
		"entertainer",
		"solid",
		{ 245, 215, 130 },
		"A Neighbourhood regular. More soon."
	),
	cat(
		"munchkin",
		"Munchkin",
		"Rare",
		"neighbourhood",
		"entertainer",
		"solid",
		{ 200, 140, 90 },
		"A Neighbourhood regular. More soon."
	),
	cat(
		"fold",
		"Fold",
		"Rare",
		"neighbourhood",
		"waiter",
		"solid",
		{ 170, 170, 180 },
		"A Neighbourhood regular. More soon."
	),
	cat(
		"chonk",
		"Chonk",
		"Epic",
		"neighbourhood",
		"barista",
		"solid",
		{ 230, 140, 60 },
		"A Neighbourhood regular. More soon."
	),
	cat(
		"postie",
		"Postie",
		"Epic",
		"neighbourhood",
		"greeter",
		"solid",
		{ 120, 130, 160 },
		"A Neighbourhood regular. More soon."
	),
	cat(
		"marshmallow",
		"Marshmallow",
		"Legendary",
		"neighbourhood",
		"waiter",
		"solid",
		{ 252, 248, 245 },
		"A Neighbourhood regular. More soon."
	),
	cat(
		"comet",
		"Comet",
		"Mythical",
		"neighbourhood",
		"entertainer",
		"solid",
		{ 150, 190, 255 },
		"A Neighbourhood regular. More soon."
	),
	cat(
		"moss",
		"Moss",
		"Common",
		"woods",
		"greeter",
		"solid",
		{ 120, 140, 90 },
		"Lives deep in the Woods. More soon."
	),
	cat(
		"acorn",
		"Acorn",
		"Common",
		"woods",
		"barista",
		"solid",
		{ 150, 100, 55 },
		"Lives deep in the Woods. More soon."
	),
	cat(
		"bramble",
		"Bramble",
		"Common",
		"woods",
		"waiter",
		"solid",
		{ 90, 65, 45 },
		"Lives deep in the Woods. More soon."
	),
	cat(
		"fern",
		"Fern",
		"Common",
		"woods",
		"entertainer",
		"solid",
		{ 110, 150, 100 },
		"Lives deep in the Woods. More soon."
	),
	cat(
		"pinecone",
		"Pinecone",
		"Rare",
		"woods",
		"barista",
		"solid",
		{ 130, 90, 60 },
		"Lives deep in the Woods. More soon."
	),
	cat(
		"forest_cat",
		"Forest Cat",
		"Rare",
		"woods",
		"greeter",
		"stripes",
		{ 140, 110, 80 },
		"Lives deep in the Woods. More soon."
	),
	cat(
		"toadstool",
		"Toadstool",
		"Epic",
		"woods",
		"entertainer",
		"spots",
		{ 210, 70, 60 },
		"Lives deep in the Woods. More soon."
	),
	cat(
		"firefly",
		"Firefly",
		"Epic",
		"woods",
		"waiter",
		"solid",
		{ 240, 220, 90 },
		"Lives deep in the Woods. More soon."
	),
	cat(
		"old_oak",
		"Old Oak",
		"Legendary",
		"woods",
		"barista",
		"solid",
		{ 100, 75, 50 },
		"Lives deep in the Woods. More soon."
	),
	cat(
		"wisp",
		"Wisp",
		"Mythical",
		"woods",
		"greeter",
		"solid",
		{ 200, 230, 255 },
		"Lives deep in the Woods. More soon."
	),
	cat(
		"rusty",
		"Rusty",
		"Common",
		"sewer",
		"waiter",
		"solid",
		{ 180, 90, 50 },
		"Found down in the Sewer. More soon."
	),
	cat(
		"soot",
		"Soot",
		"Common",
		"sewer",
		"barista",
		"solid",
		{ 45, 45, 50 },
		"Found down in the Sewer. More soon."
	),
	cat(
		"pipes",
		"Pipes",
		"Common",
		"sewer",
		"entertainer",
		"stripes",
		{ 130, 135, 140 },
		"Found down in the Sewer. More soon."
	),
	cat(
		"puddle",
		"Puddle",
		"Common",
		"sewer",
		"greeter",
		"solid",
		{ 110, 130, 150 },
		"Found down in the Sewer. More soon."
	),
	cat(
		"lantern",
		"Lantern",
		"Rare",
		"sewer",
		"waiter",
		"solid",
		{ 240, 180, 80 },
		"Found down in the Sewer. More soon."
	),
	cat(
		"bubbles",
		"Bubbles",
		"Rare",
		"sewer",
		"entertainer",
		"solid",
		{ 170, 210, 240 },
		"Found down in the Sewer. More soon."
	),
	cat(
		"gears",
		"Gears",
		"Epic",
		"sewer",
		"barista",
		"solid",
		{ 180, 140, 80 },
		"Found down in the Sewer. More soon."
	),
	cat(
		"glimmer",
		"Glimmer",
		"Epic",
		"sewer",
		"greeter",
		"solid",
		{ 200, 205, 215 },
		"Found down in the Sewer. More soon."
	),
	cat(
		"bottlecap",
		"Bottlecap King",
		"Legendary",
		"sewer",
		"waiter",
		"solid",
		{ 220, 180, 60 },
		"Found down in the Sewer. More soon."
	),
	cat(
		"eclipse",
		"Eclipse",
		"Mythical",
		"sewer",
		"barista",
		"solid",
		{ 25, 20, 30 },
		"Found down in the Sewer. More soon."
	),
} :: { Types.CatDef }

-- "tabby" -> "CatCafe_Cat_Tabby", "maine_coon" -> "CatCafe_Cat_MaineCoon"
function Catalog.catModelName(catId: string): string
	local words: { string } = {}
	for word in catId:gmatch("[^_]+") do
		table.insert(words, word:sub(1, 1):upper() .. word:sub(2))
	end
	return "CatCafe_Cat_" .. table.concat(words)
end

-- v0.5 F42: every cat's shiny coat is its own model on the same rig, "tabby" -> "CatCafe_Cat_Tabby_Shiny".
function Catalog.shinyModelName(catId: string): string
	return Catalog.catModelName(catId) .. "_Shiny"
end

Catalog.catsById = {} :: { [string]: Types.CatDef }
Catalog.catsByModelName = {} :: { [string]: Types.CatDef }
for _, def in Catalog.cats do
	Catalog.catsById[def.id] = def
	Catalog.catsByModelName[Catalog.catModelName(def.id)] = def
end

function Catalog.getCat(id: string): Types.CatDef?
	return Catalog.catsById[id]
end

-- Section 5: role slots in opening order and the tier that opens each (2, 4, 6, 8 and 10 slots per tier).
Catalog.spots = {
	{ id = "barista_1", spotType = "barista", tier = 1 },
	{ id = "waiter_1", spotType = "waiter", tier = 1 },
	{ id = "waiter_2", spotType = "waiter", tier = 2 },
	{ id = "greeter_1", spotType = "greeter", tier = 2 },
	{ id = "barista_2", spotType = "barista", tier = 3 },
	{ id = "entertainer_1", spotType = "entertainer", tier = 3 },
	{ id = "waiter_3", spotType = "waiter", tier = 4 },
	{ id = "greeter_2", spotType = "greeter", tier = 4 },
	{ id = "barista_3", spotType = "barista", tier = 5 },
	{ id = "entertainer_2", spotType = "entertainer", tier = 5 },
} :: { Types.SpotDef }

Catalog.spotsById = {} :: { [string]: Types.SpotDef }
for _, def in Catalog.spots do
	Catalog.spotsById[def.id] = def
end

function Catalog.getSpot(id: string): Types.SpotDef?
	return Catalog.spotsById[id]
end

-- Station furniture placed under a slot of each role. Baristas work the counter and waiters stand between the
-- tables, so neither adds furniture; the greeter's podium comes with the role stations.
Catalog.spotFurniture = {
	entertainer = "CatCafe_Furniture_CatTree",
} :: { [string]: string }

-- Section 5b
Catalog.tiers = {
	{
		tier = 1,
		name = "Corner Cafe",
		cost = 0,
		distinctCats = 0,
		slots = 2,
		multiplier = 1.00,
		area = "alley",
		caps = { tables = 2, espresso = 2, net = 1 },
	},
	{
		tier = 2,
		name = "Cozy Cafe",
		cost = 1500,
		distinctCats = 5,
		slots = 4,
		multiplier = 1.25,
		area = "park",
		caps = { tables = 4, espresso = 3, net = 2 },
	},
	{
		tier = 3,
		name = "Busy Cafe",
		cost = 8000,
		distinctCats = 12,
		needsRarity = "Epic",
		needsRarityCount = 1,
		slots = 6,
		multiplier = 1.50,
		area = "neighbourhood",
		caps = { tables = 6, espresso = 4, net = 3 },
	},
	{
		tier = 4,
		name = "Famous Cafe",
		cost = 30000,
		distinctCats = 20,
		needsRarity = "Legendary",
		needsRarityCount = 1,
		slots = 8,
		multiplier = 1.75,
		area = "woods",
		caps = { tables = 6, espresso = 5, net = 3 },
	},
	{
		tier = 5,
		name = "Grand Cafe",
		cost = 120000,
		distinctCats = 30,
		needsRarity = "Legendary",
		needsRarityCount = 2,
		slots = 10,
		multiplier = 2.00,
		area = "sewer",
		caps = { tables = 6, espresso = 5, net = 3 },
	},
} :: { Types.TierDef }

Catalog.maxTier = #Catalog.tiers

function Catalog.getTier(tier: number): Types.TierDef?
	return Catalog.tiers[tier]
end

-- Lowest tier whose shop cap allows `level` of a capped upgrade (tables, espresso, net); nil when no tier does.
function Catalog.tierForLevel(upgradeId: string, level: number): number?
	for _, def in Catalog.tiers do
		local cap = (def.caps :: any)[upgradeId]
		if type(cap) == "number" and level <= cap then
			return def.tier
		end
	end
	return nil
end

-- Section 6. requiresTierAtLevel is filled from the tier caps below, so the two tables cannot disagree.
Catalog.upgrades = {
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
		maxLevel = 5,
		costs = { 0, 300, 1200, 4000, 12000 },
		startLevel = 1,
	},
	{
		id = "net",
		name = "Net",
		description = "A better net: higher odds on every swing",
		maxLevel = 3,
		costs = { 500, 3000, 15000 },
		startLevel = 0,
	},
	{
		id = "lure_bowl", -- shown as Bait bowl; ids keep the lure_ prefix (data-model section 6)
		name = "Bait bowl",
		description = "Unlocks baiting with food at bait spots",
		maxLevel = 1,
		costs = { 400 },
		startLevel = 0,
	},
} :: { Types.UpgradeDef }

for _, def in Catalog.upgrades do
	local perLevel: { [number]: number } = {}
	local any = false
	for level = 1, def.maxLevel do
		local tier = Catalog.tierForLevel(def.id, level)
		if tier ~= nil and tier > 1 then
			perLevel[level] = tier
			any = true
		end
	end
	if any then
		def.requiresTierAtLevel = perLevel
	end
end

Catalog.upgradesById = {} :: { [string]: Types.UpgradeDef }
for _, def in Catalog.upgrades do
	Catalog.upgradesById[def.id] = def
end

function Catalog.getUpgrade(id: string): Types.UpgradeDef?
	return Catalog.upgradesById[id]
end

-- Upgrade ids renamed before launch, old id -> new id. ProfileSchema.migrate carries saved levels across.
Catalog.renamedUpgrades = { gloves = "net" } :: { [string]: string }

-- Section 7
Catalog.decor = {
	{
		id = "plants",
		name = "Window plants",
		cost = 150,
		category = "Plants",
		effect = "+5% tips",
		description = "Green in the window, warmth in the room.",
		requiresTier = 2,
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
		requiresTier = 2,
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
		requiresTier = 3,
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
		requiresTier = 4,
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

-- Sections 8 and 8b. Odds are shown before purchase. Shop foods are bought with BuyLure; dealer foods only from
-- the night dealer's stock.
Catalog.lures = {
	{
		id = "kibble",
		name = "Kibble",
		cost = 25,
		attracts = "Common",
		source = "shop",
		description = "Cheap and crunchy. Brings the regulars.",
		odds = { Common = 70, Rare = 25, Epic = 4, Legendary = 0.9, Mythical = 0.1 },
		asset = "CatCafe_Item_Kibble",
	},
	{
		id = "tuna",
		name = "Tuna",
		cost = 100,
		attracts = "Rare",
		source = "shop",
		description = "The good stuff. Rare cats come running.",
		odds = { Common = 40, Rare = 45, Epic = 12, Legendary = 2.6, Mythical = 0.4 },
		asset = "CatCafe_Item_TunaCan",
	},
	{
		id = "salmon",
		name = "Salmon",
		cost = 500,
		attracts = "Epic",
		source = "shop",
		description = "Nobody can resist it, not even the Void.",
		odds = { Common = 15, Rare = 45, Epic = 30, Legendary = 8.5, Mythical = 1.5 },
		asset = "CatCafe_Item_Salmon",
	},
	{
		id = "sardines",
		name = "Moonlit Sardines",
		cost = 800,
		attracts = "Rare",
		source = "dealer",
		description = "Silvery and still glowing a little.",
		odds = { Common = 30, Rare = 45, Epic = 20, Legendary = 4.5, Mythical = 0.5 },
		asset = "CatCafe_Item_Sardines",
	},
	{
		id = "caviar",
		name = "Caviar",
		cost = 3000,
		attracts = "Epic",
		source = "dealer",
		description = "Tiny, shiny and very fancy.",
		odds = { Common = 10, Rare = 35, Epic = 38, Legendary = 14, Mythical = 3 },
		asset = "CatCafe_Item_Caviar",
	},
	{
		id = "moon_milk",
		name = "Moon Milk",
		cost = 10000,
		attracts = "Epic",
		source = "dealer",
		description = "Nobody knows where he gets it.",
		odds = { Common = 0, Rare = 20, Epic = 45, Legendary = 28, Mythical = 7 },
		asset = "CatCafe_Item_MoonMilk",
	},
	{
		id = "star_treat",
		name = "Star Treat",
		cost = 40000,
		attracts = "Legendary",
		source = "dealer",
		description = "It twinkles. Mythical cats can smell it from the next area.",
		odds = { Common = 0, Rare = 0, Epic = 40, Legendary = 45, Mythical = 15 },
		asset = "CatCafe_Item_StarTreat",
	},
} :: { Types.LureDef }

Catalog.luresById = {} :: { [string]: Types.LureDef }
for _, def in Catalog.lures do
	Catalog.luresById[def.id] = def
end

function Catalog.getLure(id: string): Types.LureDef?
	return Catalog.luresById[id]
end

-- Section 8b: chance per dealer slot of each dealer food, by the player's tier.
Catalog.dealerSlotWeights = {
	{ sardines = 70, caviar = 25, moon_milk = 5, star_treat = 0 },
	{ sardines = 60, caviar = 30, moon_milk = 9, star_treat = 1 },
	{ sardines = 50, caviar = 33, moon_milk = 14, star_treat = 3 },
	{ sardines = 40, caviar = 35, moon_milk = 19, star_treat = 6 },
	{ sardines = 30, caviar = 36, moon_milk = 24, star_treat = 10 },
} :: { { [string]: number } }

-- Section 9. A full wave of waveSize strays spawns in every area at each night start, whether or not anyone has
-- it open. Neighbourhood, Woods and Sewer are grayboxes; their rescue spots are stand-ins until the traps (F27).
Catalog.areas = {
	{
		id = "alley",
		name = "Alleyway",
		tier = 1,
		spawnPoints = 24, -- v0.4 layout: two behind every cafe, eight in the Alley Square
		waveSize = 10,
		rescueSpots = 3,
		odds = { Common = 72, Rare = 22, Epic = 5, Legendary = 0.9, Mythical = 0.1 },
	},
	{
		id = "park",
		name = "Park",
		tier = 2,
		spawnPoints = 14,
		waveSize = 10,
		rescueSpots = 3,
		odds = { Common = 60, Rare = 28, Epic = 9, Legendary = 2.5, Mythical = 0.5 },
	},
	{
		id = "neighbourhood",
		name = "Neighbourhood",
		tier = 3,
		spawnPoints = 14,
		waveSize = 10,
		rescueSpots = 2,
		odds = { Common = 50, Rare = 32, Epic = 13, Legendary = 4, Mythical = 1 },
	},
	{
		id = "woods",
		name = "Woods",
		tier = 4,
		spawnPoints = 16,
		waveSize = 10,
		rescueSpots = 2,
		odds = { Common = 42, Rare = 34, Epic = 17, Legendary = 5.5, Mythical = 1.5 },
	},
	{
		id = "sewer",
		name = "Sewer",
		tier = 5,
		spawnPoints = 16,
		waveSize = 10,
		rescueSpots = 2,
		odds = { Common = 35, Rare = 35, Epic = 20, Legendary = 7.5, Mythical = 2.5 },
	},
} :: { Types.AreaDef }

Catalog.areasById = {} :: { [string]: Types.AreaDef }
for _, def in Catalog.areas do
	Catalog.areasById[def.id] = def
end

function Catalog.getArea(id: string): Types.AreaDef?
	return Catalog.areasById[id]
end

return Catalog
