--!strict
-- Every catalog table from docs/design/cat-cafe/data-model.md (sections 2, 3, 5 to 9), design v0.3.
-- Pure data plus lookups. Ids never change once saved; display names can.
-- Model names derive from ids: cat "tabby" is ReplicatedStorage.Assets.CatCafe_Cat_Tabby.

local Config = require(script.Parent.Config)
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
-- exactly one area. Colors are the placeholder body's {r, g, b}. Rares and up in the Alleyway and the Park are
-- themed cats with a signature prop (v0.5.2, Derek 2026-10-27); their ids keep the old breed names so saves and
-- models still match.
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
		"Pirate Cat",
		"Rare",
		"alley",
		"waiter",
		"patches",
		{ 240, 190, 120 },
		"Carries every tray like buried treasure."
	),
	cat(
		"tortie",
		"Rocker Cat",
		"Rare",
		"alley",
		"entertainer",
		"patches",
		{ 110, 70, 45 },
		"Knows one chord and plays it very loudly."
	),
	cat(
		"sphynx",
		"DJ Cat",
		"Epic",
		"alley",
		"greeter",
		"solid",
		{ 230, 180, 170 },
		"Drops a beat every time the door opens."
	),
	cat(
		"maine_coon",
		"Bandit Cat",
		"Epic",
		"alley",
		"barista",
		"stripes",
		{ 125, 90, 60 },
		"Sneaks extra foam onto every latte."
	),
	cat(
		"void",
		"Ninja Cat",
		"Legendary",
		"alley",
		"waiter",
		"solid",
		{ 12, 12, 16 },
		"Silent, fast and never spills a drop."
	),
	cat(
		"midnight",
		"Wizard Cat",
		"Mythical",
		"alley",
		"barista",
		"solid",
		{ 30, 30, 70 },
		"Stirs a little starlight into every cup."
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
		"Nerd Cat",
		"Rare",
		"park",
		"barista",
		"points",
		{ 225, 205, 175 },
		"Measures every latte to the last drop."
	),
	cat(
		"bengal",
		"Explorer Cat",
		"Rare",
		"park",
		"entertainer",
		"spots",
		{ 200, 150, 80 },
		"Tells tall tales about the wild side of the Park."
	),
	cat(
		"ragdoll",
		"Sleepy Cat",
		"Epic",
		"park",
		"greeter",
		"points",
		{ 240, 235, 230 },
		"Says hello with an enormous yawn."
	),
	cat(
		"persian",
		"Fancy Cat",
		"Epic",
		"park",
		"waiter",
		"solid",
		{ 245, 230, 200 },
		"Serves every cup on a silver tray."
	),
	cat(
		"blossom",
		"Fairy Cat",
		"Legendary",
		"park",
		"barista",
		"patches",
		{ 245, 190, 200 },
		"Leaves a petal on every saucer."
	),
	cat(
		"aurora",
		"Astro Cat",
		"Mythical",
		"park",
		"entertainer",
		"gradient",
		{ 110, 200, 190 },
		"Moonwalks between the tables."
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

-- v0.5 F42: every cat's gold coat is its own model on the same rig, "tabby" -> "CatCafe_Cat_Tabby_Gold".
function Catalog.goldModelName(catId: string): string
	return Catalog.catModelName(catId) .. "_Gold"
end

-- The seated body (B) of a walking model, "CatCafe_Cat_Tabby" -> "CatCafe_Cat_Tabby_Sit" and
-- "CatCafe_Cat_Tabby_Gold" -> "CatCafe_Cat_Tabby_Gold_Sit" (Derek 2026-10-27: A walks, B sits).
function Catalog.sitModelName(modelName: string): string
	return modelName .. "_Sit"
end

-- What a working cat wears at its station (features.md F25; Derek 2026-10-27: outfits by role, no collars on any
-- cat). Each piece is the asset CatCafe_Accessory_<Piece>, and each seated cat model (the _Sit bodies) carries an
-- Attachment named Outfit_<Piece> at that piece's slot (asset thread's sit_slots). Cats resting in the cat room wear
-- none.
Catalog.roleOutfits = {
	barista = { "Apron", "BaristaCap" },
	waiter = { "BowTie", "Vest" },
	greeter = { "Sash", "Boater" },
	entertainer = { "PartyHat", "Cape" },
} :: { [string]: { string } } -- keyed by Types.Role

-- Where each outfit piece sits, for the pieces that share a slot with a themed cat's prop (data-model section 3).
-- A cat model's PropSlot attribute names its prop's slot, and the role piece in that slot stays off. Face props
-- clash with nothing.
Catalog.outfitPieceSlots = {
	BaristaCap = "Head",
	Boater = "Head",
	PartyHat = "Head",
	Cape = "Back",
} :: { [string]: string }

function Catalog.accessoryModelName(piece: string): string
	return "CatCafe_Accessory_" .. piece
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
		description = "A bowl on your back step. Food in, a cat in 10 min",
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

-- Section 7. Shop decor has no `source`; Index decor says "index".
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
	-- Index decor (F48, section 11b): never sold, granted by an area's cats10 and gold10 Index rewards. A gold piece
	-- shares its normal piece's spot and stands in for it while both are placed, so only its +10% counts.
	{
		id = "index_alley",
		name = "Alley Mural Print",
		cost = 0,
		category = "Wall",
		effect = "+5% tips",
		description = "The Alleyway mural in a frame, for finding every alley cat.",
		bonus = 0.05,
		asset = "CatCafe_Decor_MuralPrint",
		source = "index",
	},
	{
		id = "index_park",
		name = "Park Bench",
		cost = 0,
		category = "Furniture",
		effect = "+5% tips",
		description = "A bench from the Park, for finding every park cat.",
		bonus = 0.05,
		asset = "CatCafe_Decor_ParkBench",
		source = "index",
	},
	{
		id = "index_neighbourhood",
		name = "Mailbox Planter",
		cost = 0,
		category = "Plants",
		effect = "+5% tips",
		description = "A mailbox full of flowers, for finding every Neighbourhood cat.",
		bonus = 0.05,
		asset = "CatCafe_Decor_MailboxPlanter",
		source = "index",
	},
	{
		id = "index_woods",
		name = "Mushroom Lamp",
		cost = 0,
		category = "Furniture",
		effect = "+5% tips",
		description = "A glowing toadstool, for finding every Woods cat.",
		bonus = 0.05,
		asset = "CatCafe_Decor_MushroomLamp",
		source = "index",
	},
	{
		id = "index_sewer",
		name = "Pipe Fountain",
		cost = 0,
		category = "Furniture",
		effect = "+5% tips",
		description = "A clean little fountain, for finding every Sewer cat.",
		bonus = 0.05,
		asset = "CatCafe_Decor_PipeFountain",
		source = "index",
	},
	{
		id = "index_alley_gold",
		name = "Gold Alley Mural Print",
		cost = 0,
		category = "Wall",
		effect = "+10% tips",
		description = "The same piece in gold, for finding every one of them as a gold cat.",
		bonus = 0.10,
		asset = "CatCafe_Decor_MuralPrint_Gold",
		source = "index",
		replaces = "index_alley",
	},
	{
		id = "index_park_gold",
		name = "Gold Park Bench",
		cost = 0,
		category = "Furniture",
		effect = "+10% tips",
		description = "The same piece in gold, for finding every one of them as a gold cat.",
		bonus = 0.10,
		asset = "CatCafe_Decor_ParkBench_Gold",
		source = "index",
		replaces = "index_park",
	},
	{
		id = "index_neighbourhood_gold",
		name = "Gold Mailbox Planter",
		cost = 0,
		category = "Plants",
		effect = "+10% tips",
		description = "The same piece in gold, for finding every one of them as a gold cat.",
		bonus = 0.10,
		asset = "CatCafe_Decor_MailboxPlanter_Gold",
		source = "index",
		replaces = "index_neighbourhood",
	},
	{
		id = "index_woods_gold",
		name = "Gold Mushroom Lamp",
		cost = 0,
		category = "Furniture",
		effect = "+10% tips",
		description = "The same piece in gold, for finding every one of them as a gold cat.",
		bonus = 0.10,
		asset = "CatCafe_Decor_MushroomLamp_Gold",
		source = "index",
		replaces = "index_woods",
	},
	{
		id = "index_sewer_gold",
		name = "Gold Pipe Fountain",
		cost = 0,
		category = "Furniture",
		effect = "+10% tips",
		description = "The same piece in gold, for finding every one of them as a gold cat.",
		bonus = 0.10,
		asset = "CatCafe_Decor_PipeFountain_Gold",
		source = "index",
		replaces = "index_sewer",
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
		description = "Nobody can resist it, not even the Ninja Cat.",
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
		description = "Tiny, glossy and very fancy.",
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

-- Section 11b (F47): the Tip Jar's twelve playtime gifts in step order, unlocked by minutes of the current session.
-- Coins scale with the day rate at claim time (shared/TipJar.coins); the dealer foods are fine here since they are
-- free. Nothing about the jar can be bought.
Catalog.tipJar = {
	{ step = 1, minutes = 2, kind = "coins", seconds = 30, minCoins = 50 },
	{ step = 2, minutes = 5, kind = "lure", lureId = "kibble", count = 2 },
	{ step = 3, minutes = 10, kind = "coins", seconds = 60, minCoins = 100 },
	{ step = 4, minutes = 15, kind = "lure", lureId = "tuna", count = 1 },
	{ step = 5, minutes = 20, kind = "coins", seconds = 90, minCoins = 150 },
	{ step = 6, minutes = 30, kind = "lure", lureId = "tuna", count = 2 },
	{ step = 7, minutes = 40, kind = "coins", seconds = 120, minCoins = 250 },
	{ step = 8, minutes = 50, kind = "lure", lureId = "salmon", count = 1 },
	{ step = 9, minutes = 60, kind = "coins", seconds = 180, minCoins = 400 },
	{ step = 10, minutes = 75, kind = "lure", lureId = "sardines", count = 1 },
	{ step = 11, minutes = 90, kind = "coins", seconds = 300, minCoins = 600, spins = 1 },
	{
		step = 12,
		minutes = 120,
		kind = "lure",
		lureId = "caviar",
		count = 1,
		spins = 1,
		fish = Config.TipJarStep12Fish, -- F52
	},
} :: { Types.TipJarStep }

-- Section 11c (F49): the Spin Wheel's six slices in order around the wheel. Free spins only: no Robux button, pass
-- or product gives spins (monetization-policy), and a spin never gives a cat. Frozen, like the Index prizes.
Catalog.spinWheel = {
	{ slice = 1, kind = "coins", seconds = 120, minCoins = 200, weight = 30 },
	{ slice = 2, kind = "lure", lureId = "tuna", count = 3, weight = 22 },
	{ slice = 3, kind = "coins", seconds = 600, minCoins = 1000, weight = 18 },
	{ slice = 4, kind = "lure", lureId = "salmon", count = 2, weight = 15 },
	{ slice = 5, kind = "lure", lureId = "sardines", count = 2, weight = 10 },
	{ slice = 6, kind = "lure", lureId = "caviar", count = 1, weight = 5 },
} :: { Types.SpinSlice }
for _, row in Catalog.spinWheel do
	table.freeze(row)
end
table.freeze(Catalog.spinWheel)

Catalog.luresById = {} :: { [string]: Types.LureDef }
for _, def in Catalog.lures do
	Catalog.luresById[def.id] = def
end

function Catalog.getLure(id: string): Types.LureDef?
	return Catalog.luresById[id]
end

-- Section 8b: chance per dealer slot of each dealer food. v0.5 F43: one row for everyone (the old Tier 3 row);
-- tiers no longer change the stock, so every player on every server sees the same three foods.
Catalog.dealerSlotWeights =
	{ sardines = 50, caviar = 33, moon_milk = 14, star_treat = 3 } :: { [string]: number }

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
		spawnPoints = 18,
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

-- Section 11b (F48): the four reward bar milestones every area page of the Index has, in order.
Catalog.indexMilestones = {
	{ id = "cats3", need = 3 },
	{ id = "cats6", need = 6 },
	{ id = "cats10", need = 10 },
	{ id = "gold10", need = 10, gold = true },
} :: { Types.IndexMilestone }

-- What each milestone pays per area (section 11b). Everything is free and only the server pays it. Named apart
-- from profile.indexRewards (the claims) and frozen, so a write meant for a profile errors instead of changing the
-- prize for everyone on the server (reviewer S61).
Catalog.indexPrizes = {
	alley = {
		cats3 = { coins = 300 },
		cats6 = { lures = { tuna = 2 } },
		cats10 = { lures = { salmon = 1 }, decorId = "index_alley" },
		gold10 = { decorId = "index_alley_gold" },
	},
	park = {
		cats3 = { coins = 1000 },
		cats6 = { lures = { salmon = 2 } },
		cats10 = { lures = { caviar = 1 }, decorId = "index_park" },
		gold10 = { decorId = "index_park_gold" },
	},
	neighbourhood = {
		cats3 = { coins = 3000 },
		cats6 = { lures = { caviar = 2 } },
		cats10 = { lures = { moon_milk = 1 }, decorId = "index_neighbourhood" },
		gold10 = { decorId = "index_neighbourhood_gold" },
	},
	woods = {
		cats3 = { coins = 10000 },
		cats6 = { lures = { moon_milk = 2 } },
		cats10 = { lures = { star_treat = 1 }, decorId = "index_woods" },
		gold10 = { decorId = "index_woods_gold" },
	},
	sewer = {
		cats3 = { coins = 30000 },
		cats6 = { lures = { star_treat = 2 } },
		cats10 = { lures = { star_treat = 2 }, decorId = "index_sewer" },
		gold10 = { decorId = "index_sewer_gold" },
	},
} :: { [string]: { [string]: Types.IndexPrize } }
for _, prizes in Catalog.indexPrizes do
	for _, prize in prizes do
		if prize.lures ~= nil then
			table.freeze(prize.lures)
		end
		table.freeze(prize)
	end
	table.freeze(prizes)
end
table.freeze(Catalog.indexPrizes)

function Catalog.getArea(id: string): Types.AreaDef?
	return Catalog.areasById[id]
end

-- Cafe Crates (F53, golden-fish.md section 4): a crate per zone and the Classic Crate, each with a golden version
-- that holds the same pieces at Epic or better odds and is never sold. A piece's chance is its rarity's odds split
-- equally among that rarity's pieces. Every crate shows these odds before it opens (monetization-policy).
local CRATE_ODDS =
	{ Common = 60, Rare = 27, Epic = 10, Legendary = 2.5, Mythical = 0.5 } :: { [string]: number }
local GOLDEN_CRATE_ODDS =
	{ Common = 0, Rare = 0, Epic = 80, Legendary = 17.5, Mythical = 2.5 } :: { [string]: number }
local CRATE_POOLS = {
	{ area = "alley", name = "Alley" },
	{ area = "park", name = "Park" },
	{ area = "neighbourhood", name = "Neighbourhood" },
	{ area = "woods", name = "Woods" },
	{ area = "sewer", name = "Sewer" },
	{ area = "classic", name = "Classic" },
}
-- The pieces in each pool (F53, golden-fish.md section 4): ten, two of each kind, 4 Common, 3 Rare and one each of
-- Epic, Legendary and Mythical. A wallpaper, floor or paint is a colour and a material on the cafe's tagged shell
-- parts; furniture and decorations are models (CatCafe_Decor_<Name>) on decor spots. The F48 Index pieces are their
-- zones' Epics and keep their ids, assets and spots. Every piece is a DecorDef in Catalog.crateDecor.
type PieceRow = {
	id: string,
	name: string?, -- nil on an F48 Index piece, which keeps its own
	kind: Types.DecorKind,
	rarity: Types.Rarity,
	color: Color3?,
	material: Enum.Material?,
	description: string?,
}
local CRATE_PIECES: { [string]: { PieceRow } } = {
	alley = {
		{
			id = "alley_brick_wall",
			name = "Brick Wall",
			kind = "wallpaper",
			rarity = "Common",
			color = Color3.fromRGB(170, 90, 70),
			material = Enum.Material.Brick,
			description = "Warm red brick, straight from the back alley.",
		},
		{
			id = "alley_midnight_sky",
			name = "Midnight Sky",
			kind = "wallpaper",
			rarity = "Mythical",
			color = Color3.fromRGB(30, 35, 80),
			material = Enum.Material.SmoothPlastic,
			description = "Stars twinkle and a moon drifts across the walls.",
		},
		{
			id = "alley_subway_tile",
			name = "Subway Tile",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(230, 230, 225),
			material = Enum.Material.CeramicTiles,
			description = "Clean white tiles, city style.",
		},
		{
			id = "alley_puddle_glass",
			name = "Puddle Glass",
			kind = "floor",
			rarity = "Rare",
			color = Color3.fromRGB(70, 80, 95),
			material = Enum.Material.Glass,
			description = "Shines like a wet street after rain.",
		},
		{
			id = "alley_fire_escape_red",
			name = "Fire Escape Red",
			kind = "paint",
			rarity = "Common",
			color = Color3.fromRGB(180, 50, 45),
			material = Enum.Material.SmoothPlastic,
			description = "The red of every fire escape on the block.",
		},
		{
			id = "alley_graffiti_pastel",
			name = "Graffiti Pastel",
			kind = "paint",
			rarity = "Rare",
			color = Color3.fromRGB(240, 170, 200),
			material = Enum.Material.SmoothPlastic,
			description = "Soft spray paint colours for the cafe front.",
		},
		{
			id = "alley_milk_crate_stools",
			name = "Milk Crate Stools",
			kind = "furniture",
			rarity = "Common",
			description = "Stacked crates with cushions on top.",
		},
		{
			id = "alley_retro_jukebox",
			name = "Retro Jukebox",
			kind = "furniture",
			rarity = "Legendary",
			description = "Plays the old songs, lights and all.",
		},
		{
			id = "alley_jar_lights",
			name = "Jar Lights",
			kind = "decoration",
			rarity = "Rare",
			description = "Fairy lights in old jam jars.",
		},
		{ id = "index_alley", kind = "decoration", rarity = "Epic" }, -- the F48 Index piece
	},
	park = {
		{
			id = "park_leafy_vines",
			name = "Leafy Vines",
			kind = "wallpaper",
			rarity = "Common",
			color = Color3.fromRGB(110, 150, 80),
			material = Enum.Material.Plaster,
			description = "Vines climbing every wall.",
		},
		{
			id = "park_meadow_mural",
			name = "Meadow Mural",
			kind = "wallpaper",
			rarity = "Rare",
			color = Color3.fromRGB(150, 200, 120),
			material = Enum.Material.Plaster,
			description = "A painted meadow all the way round.",
		},
		{
			id = "park_garden_path",
			name = "Garden Path",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(160, 150, 130),
			material = Enum.Material.Pebble,
			description = "Pebbles underfoot, like the Park.",
		},
		{
			id = "park_clover_carpet",
			name = "Clover Carpet",
			kind = "floor",
			rarity = "Rare",
			color = Color3.fromRGB(90, 160, 80),
			material = Enum.Material.Carpet,
			description = "Soft green, lucky to step on.",
		},
		{
			id = "park_meadow_green",
			name = "Meadow Green",
			kind = "paint",
			rarity = "Common",
			color = Color3.fromRGB(120, 180, 100),
			material = Enum.Material.SmoothPlastic,
			description = "Fresh grass green for the cafe front.",
		},
		{
			id = "park_duck_pond_blue",
			name = "Duck Pond Blue",
			kind = "paint",
			rarity = "Common",
			color = Color3.fromRGB(110, 170, 210),
			material = Enum.Material.SmoothPlastic,
			description = "The calm blue of the duck pond.",
		},
		{
			id = "park_picnic_table_set",
			name = "Picnic Table Set",
			kind = "furniture",
			rarity = "Rare",
			description = "A picnic table with a checked cloth.",
		},
		{ id = "index_park", kind = "furniture", rarity = "Epic" }, -- the F48 Index piece
		{
			id = "park_duck_fountain",
			name = "Duck Fountain",
			kind = "decoration",
			rarity = "Legendary",
			description = "A fountain the ducks would approve of.",
		},
		{
			id = "park_blossom_tree",
			name = "Blossom Tree",
			kind = "decoration",
			rarity = "Mythical",
			description = "A blossom tree with petals drifting down.",
		},
	},
	neighbourhood = {
		{
			id = "neighbourhood_picket_stripes",
			name = "Picket Stripes",
			kind = "wallpaper",
			rarity = "Common",
			color = Color3.fromRGB(240, 235, 225),
			material = Enum.Material.Plaster,
			description = "White stripes like a picket fence.",
		},
		{
			id = "neighbourhood_kitchen_gingham",
			name = "Kitchen Gingham",
			kind = "wallpaper",
			rarity = "Rare",
			color = Color3.fromRGB(220, 120, 120),
			material = Enum.Material.Fabric,
			description = "Red gingham, like a farmhouse kitchen.",
		},
		{
			id = "neighbourhood_checker_kitchen",
			name = "Checker Kitchen",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(235, 235, 235),
			material = Enum.Material.CeramicTiles,
			description = "A black and white kitchen checker.",
		},
		{
			id = "neighbourhood_porch_planks",
			name = "Porch Planks",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(170, 130, 90),
			material = Enum.Material.WoodPlanks,
			description = "Sun warmed porch boards.",
		},
		{
			id = "neighbourhood_pastel_pink",
			name = "Pastel Pink",
			kind = "paint",
			rarity = "Common",
			color = Color3.fromRGB(245, 190, 205),
			material = Enum.Material.SmoothPlastic,
			description = "A sweet pink cafe front.",
		},
		{
			id = "neighbourhood_rainbow_shimmer",
			name = "Rainbow Shimmer",
			kind = "paint",
			rarity = "Mythical",
			color = Color3.fromRGB(200, 160, 240),
			material = Enum.Material.SmoothPlastic,
			description = "A slow rainbow over the cafe front.",
		},
		{
			id = "neighbourhood_porch_swing",
			name = "Porch Swing",
			kind = "furniture",
			rarity = "Rare",
			description = "A swing seat for lazy afternoons.",
		},
		{
			id = "neighbourhood_ice_cream_counter",
			name = "Ice Cream Counter",
			kind = "furniture",
			rarity = "Legendary",
			description = "Every flavour, cats included.",
		},
		{
			id = "neighbourhood_bicycle_planter",
			name = "Bicycle Planter",
			kind = "decoration",
			rarity = "Rare",
			description = "An old bike with a basket of flowers.",
		},
		{ id = "index_neighbourhood", kind = "decoration", rarity = "Epic" }, -- the F48 Index piece
	},
	woods = {
		{
			id = "woods_birch_bark",
			name = "Birch Bark",
			kind = "wallpaper",
			rarity = "Common",
			color = Color3.fromRGB(225, 220, 205),
			material = Enum.Material.Wood,
			description = "Pale birch from the Woods.",
		},
		{
			id = "woods_aurora_sky",
			name = "Aurora Sky",
			kind = "wallpaper",
			rarity = "Mythical",
			color = Color3.fromRGB(40, 90, 110),
			material = Enum.Material.SmoothPlastic,
			description = "Northern lights ripple across the walls.",
		},
		{
			id = "woods_mossy_planks",
			name = "Mossy Planks",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(95, 110, 70),
			material = Enum.Material.WoodPlanks,
			description = "Old boards with a little moss.",
		},
		{
			id = "woods_leaf_litter",
			name = "Leaf Litter",
			kind = "floor",
			rarity = "Rare",
			color = Color3.fromRGB(160, 100, 50),
			material = Enum.Material.Ground,
			description = "Crunchy autumn leaves underfoot.",
		},
		{
			id = "woods_forest_green",
			name = "Forest Green",
			kind = "paint",
			rarity = "Common",
			color = Color3.fromRGB(50, 100, 60),
			material = Enum.Material.SmoothPlastic,
			description = "Deep pine green for the cafe front.",
		},
		{
			id = "woods_toadstool_red",
			name = "Toadstool Red",
			kind = "paint",
			rarity = "Rare",
			color = Color3.fromRGB(200, 50, 45),
			material = Enum.Material.SmoothPlastic,
			description = "Bright red with a toadstool spot or two.",
		},
		{
			id = "woods_log_stools",
			name = "Log Stools",
			kind = "furniture",
			rarity = "Common",
			description = "Sawn logs to sit on.",
		},
		{
			id = "woods_hollow_log_booth",
			name = "Hollow Log Booth",
			kind = "furniture",
			rarity = "Legendary",
			description = "A booth carved inside a giant log.",
		},
		{
			id = "woods_lantern_stump",
			name = "Lantern Stump",
			kind = "decoration",
			rarity = "Rare",
			description = "A tree stump holding a little lantern.",
		},
		{ id = "index_woods", kind = "decoration", rarity = "Epic" }, -- the F48 Index piece
	},
	sewer = {
		{
			id = "sewer_pipe_works",
			name = "Pipe Works",
			kind = "wallpaper",
			rarity = "Common",
			color = Color3.fromRGB(120, 130, 130),
			material = Enum.Material.Metal,
			description = "Pipes and valves along every wall.",
		},
		{
			id = "sewer_bottle_cap_mosaic",
			name = "Bottle Cap Mosaic",
			kind = "wallpaper",
			rarity = "Rare",
			color = Color3.fromRGB(200, 160, 60),
			material = Enum.Material.CeramicTiles,
			description = "A mosaic of bright bottle caps.",
		},
		{
			id = "sewer_canal_tile",
			name = "Canal Tile",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(90, 140, 140),
			material = Enum.Material.CeramicTiles,
			description = "Teal tiles from the canal walk.",
		},
		{
			id = "sewer_glimmer_canal",
			name = "Glimmer Canal",
			kind = "floor",
			rarity = "Mythical",
			color = Color3.fromRGB(60, 140, 180),
			material = Enum.Material.Glass,
			description = "Water shimmers under a glass floor.",
		},
		{
			id = "sewer_brass_teal",
			name = "Brass Teal",
			kind = "paint",
			rarity = "Common",
			color = Color3.fromRGB(60, 140, 130),
			material = Enum.Material.SmoothPlastic,
			description = "Teal with brass trim.",
		},
		{
			id = "sewer_copper_patina",
			name = "Copper Patina",
			kind = "paint",
			rarity = "Rare",
			color = Color3.fromRGB(100, 170, 150),
			material = Enum.Material.SmoothPlastic,
			description = "Old copper gone green.",
		},
		{
			id = "sewer_crate_shelf",
			name = "Crate Shelf",
			kind = "furniture",
			rarity = "Common",
			description = "Shelves made from salvaged crates.",
		},
		{
			id = "sewer_bathtub_sofa",
			name = "Bathtub Sofa",
			kind = "furniture",
			rarity = "Legendary",
			description = "A clawfoot tub full of cushions.",
		},
		{
			id = "sewer_rubber_duck_row",
			name = "Rubber Duck Row",
			kind = "decoration",
			rarity = "Rare",
			description = "A line of rubber ducks on parade.",
		},
		{ id = "index_sewer", kind = "decoration", rarity = "Epic" }, -- the F48 Index piece
	},
	classic = {
		{
			id = "classic_cream_stripes",
			name = "Cream Stripes",
			kind = "wallpaper",
			rarity = "Common",
			color = Color3.fromRGB(245, 235, 210),
			material = Enum.Material.Plaster,
			description = "Timeless cream stripes.",
		},
		{
			id = "classic_paw_print",
			name = "Paw Print",
			kind = "wallpaper",
			rarity = "Rare",
			color = Color3.fromRGB(230, 200, 180),
			material = Enum.Material.Fabric,
			description = "Little paw prints everywhere.",
		},
		{
			id = "classic_oak_boards",
			name = "Oak Boards",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(160, 115, 70),
			material = Enum.Material.WoodPlanks,
			description = "Honest oak floorboards.",
		},
		{
			id = "classic_black_white_tile",
			name = "Black and White Tile",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(240, 240, 240),
			material = Enum.Material.CeramicTiles,
			description = "The classic cafe floor.",
		},
		{
			id = "classic_latte_brown",
			name = "Latte Brown",
			kind = "paint",
			rarity = "Common",
			color = Color3.fromRGB(170, 125, 90),
			material = Enum.Material.SmoothPlastic,
			description = "The colour of a good latte.",
		},
		{
			id = "classic_gold_leaf",
			name = "Gold Leaf",
			kind = "paint",
			rarity = "Mythical",
			color = Color3.fromRGB(220, 180, 70),
			material = Enum.Material.Foil,
			description = "Gold trim that glints in the light.",
		},
		{
			id = "classic_bistro_set",
			name = "Bistro Set",
			kind = "furniture",
			rarity = "Rare",
			description = "A little round table and two chairs.",
		},
		{
			id = "classic_velvet_booth",
			name = "Velvet Booth",
			kind = "furniture",
			rarity = "Epic",
			description = "A deep red velvet booth.",
		},
		{
			id = "classic_hanging_plants",
			name = "Hanging Plants",
			kind = "decoration",
			rarity = "Rare",
			description = "Plants in macrame hangers.",
		},
		{
			id = "classic_cat_tree_tower",
			name = "Cat Tree Tower",
			kind = "decoration",
			rarity = "Legendary",
			description = "A cat tree that nearly touches the ceiling.",
		},
	},
}

local KIND_CATEGORY: { [string]: string } = {
	wallpaper = "Wallpaper",
	floor = "Flooring",
	paint = "Paint",
	furniture = "Furniture",
	decoration = "Decoration",
}

Catalog.crateDecor = {} :: { Types.DecorDef }
local poolPieces: { [string]: { string } } = {}
for _, pool in CRATE_POOLS do
	local ids: { string } = {}
	for _, row in CRATE_PIECES[pool.area] do
		local bonus = Config.CratePieceBonus[row.rarity]
		local effect = string.format("+%d%% tips while in use", math.floor(bonus * 100 + 0.5))
		local def: Types.DecorDef? = Catalog.decorById[row.id]
		if def ~= nil then
			def.crate, def.rarity, def.kind = pool.area, row.rarity, row.kind
			def.bonus, def.effect = bonus, effect
		else
			local name = row.name :: string
			local styled = row.kind == "wallpaper" or row.kind == "floor" or row.kind == "paint"
			local asset = (if styled then "CatCafe_Style_" else "CatCafe_Decor_")
				.. (name:gsub("[^%w]", ""))
			def = {
				id = row.id,
				name = name,
				cost = 0,
				category = KIND_CATEGORY[row.kind],
				effect = effect,
				description = row.description or "",
				bonus = bonus,
				asset = asset,
				source = "crate",
				crate = pool.area,
				rarity = row.rarity,
				kind = row.kind,
				color = row.color,
				material = row.material,
			}
			Catalog.decorById[row.id] = def :: Types.DecorDef
		end
		table.insert(Catalog.crateDecor, def :: Types.DecorDef)
		table.insert(ids, row.id)
	end
	poolPieces[pool.area] = ids
end

Catalog.crates = {} :: { Types.CrateDef }
for _, pool in CRATE_POOLS do
	table.insert(Catalog.crates, {
		id = pool.area .. "_crate",
		name = pool.name .. " Crate",
		area = pool.area,
		golden = false,
		price = Config.CratePrice,
		odds = CRATE_ODDS,
		pieces = poolPieces[pool.area],
	})
	table.insert(Catalog.crates, {
		id = pool.area .. "_golden_crate",
		name = "Golden " .. pool.name .. " Crate",
		area = pool.area,
		golden = true,
		price = nil,
		odds = GOLDEN_CRATE_ODDS,
		pieces = poolPieces[pool.area],
	})
end

Catalog.cratesById = {} :: { [string]: Types.CrateDef }
Catalog.cratePools = {} :: { [string]: boolean } -- the zone ids and "classic": crateLuck's keys
for _, def in Catalog.crates do
	Catalog.cratesById[def.id] = def
	Catalog.cratePools[def.area] = true
end

function Catalog.getCrate(id: string): Types.CrateDef?
	return Catalog.cratesById[id]
end

-- The Golden Fish Market (F53, golden-fish.md section 3): what golden fish buy. Crates open at once; a perk is
-- forever: Golden Espresso +5% tips a level, Big Bowl a shorter bait wait, Extra Decor Spot one more decor spot a
-- level.
Catalog.fishShop = {} :: { Types.FishShopRow }
local function shopRow(row: Types.FishShopRow)
	table.insert(Catalog.fishShop, row)
end
for _, def in Catalog.crates do
	if def.price ~= nil then
		shopRow({ id = def.id, kind = "crate", cost = def.price })
	end
end
shopRow({ id = "star_treat", kind = "lure", cost = 80 })
shopRow({ id = "golden_espresso", kind = "perk", costs = { 40, 80, 150, 250, 400 }, maxLevel = 5 })
shopRow({ id = "big_bowl", kind = "perk", costs = { 150 }, maxLevel = 1 })
shopRow({ id = "extra_decor_spot", kind = "perk", costs = { 100, 250 }, maxLevel = 2 })

Catalog.fishShopById = {} :: { [string]: Types.FishShopRow }
for _, row in Catalog.fishShop do
	Catalog.fishShopById[row.id] = row
end

function Catalog.getFishShopRow(id: string): Types.FishShopRow?
	return Catalog.fishShopById[id]
end

return Catalog
