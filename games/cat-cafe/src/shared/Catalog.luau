--!strict
-- Every catalog table from docs/design/cat-cafe/data-model.md (sections 2, 3, 5 to 9), design v0.3.
-- Pure data plus lookups. Ids never change once saved; display names can.
-- Model names derive from ids: cat "tabby" is ReplicatedStorage.Assets.CatCafe_Cat_Tabby.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Catalog = {}

-- Section 2. circles and shrinkSeconds drive the net (section 10), catchWindow narrows the net's Perfect and Good
-- for a cat of that rarity (v0.13.15 F83, Derek: "make the catching and rescue games harder"), fleeStuds is how far a
-- stray sprints after a missed catch before anyone can try again (v0.5, tries are unlimited; doubled in v0.8 F57,
-- Gavin round 3 Q3), rescueHits the rescue bar (section 10b). F93 (catch-rework.md section 2, Derek 2026-10-28
-- 14:20: "start the amounts of bubbles higher" and "make each rarity faster"): 3 to 7 circles, each rarity faster, and
-- one more rescue hit at every rarity.
Catalog.rarities = {
	Common = {
		incomePerSecond = 1,
		circles = 3,
		shrinkSeconds = 1.20,
		catchWindow = 1.1,
		fleeStuds = 24,
		rescueHits = 3,
		sellValue = 25,
		firstCatchReward = 50,
		color = "#8E97B2",
	},
	Rare = {
		incomePerSecond = 3,
		circles = 4,
		shrinkSeconds = 1.00,
		catchWindow = 0.95,
		fleeStuds = 32,
		rescueHits = 4,
		sellValue = 150,
		firstCatchReward = 300,
		color = "#5FA8FF",
	},
	Epic = {
		incomePerSecond = 8,
		circles = 5,
		shrinkSeconds = 0.82,
		catchWindow = 0.82,
		fleeStuds = 40,
		rescueHits = 5,
		sellValue = 600,
		firstCatchReward = 1500,
		color = "#C07CFF",
	},
	Legendary = {
		incomePerSecond = 25,
		circles = 6,
		shrinkSeconds = 0.68,
		catchWindow = 0.70,
		fleeStuds = 52,
		rescueHits = 6,
		sellValue = 3000,
		firstCatchReward = 8000,
		color = "#FFC94D",
	},
	Mythical = {
		incomePerSecond = 75,
		circles = 7,
		shrinkSeconds = 0.56,
		catchWindow = 0.60,
		fleeStuds = 64,
		rescueHits = 7,
		sellValue = 12000,
		firstCatchReward = 30000,
		color = "#FF5E7E",
	},
} :: { [string]: Types.RarityDef }

local rarityOrder: { Types.Rarity } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
Catalog.rarityOrder = rarityOrder
Catalog.rarityRank =
	{ Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5 } :: { [string]: number }

-- Data-model v0.13.7 (Derek 2026-10-28 01:50: "just make the base money generation more from further areas"): a
-- cat earns its rarity's income times its area's multiplier. Catalog.areas carries the same numbers. F95 (the money
-- ladder, economy-ladder.md section 1): each area pays three times the one before, so one step up in area is worth
-- one step up in rarity ("mythical from T1 should be about as good as legendary from T2 or epic from T3").
local AREA_INCOME: { [string]: number } = {
	alley = 1,
	park = 3,
	neighbourhood = 9,
	woods = 27,
	sewer = 81,
}

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
		incomePerSecond = Catalog.rarities[rarity].incomePerSecond * (AREA_INCOME[area] or 1),
		area = area,
		favoriteRole = favoriteRole,
		description = description,
		pattern = pattern,
		color = color,
	}
end

-- Section 3d: a cat moved to the spare pool never spawns (no wave, bait, rescue or prize) but stays exactly as it was
-- for whoever owns it, earning at the area it came from (`incomeArea`).
local function spare(def: Types.CatDef): Types.CatDef
	def.incomeArea = def.area :: Types.Area
	def.area = "spare"
	return def
end

-- F95 and F96: a cat that never spawns (no wave, bait, rescue or prize) and is only given or sold. It earns like a
-- cat of its rarity from the owner's newest area (CatStats.areaMultiplier), counts toward no "different cats", Index
-- page or Index milestone, and cannot be sold or offered to the Cat Collector.
local function exclusive(def: Types.CatDef, source: Types.CatSource): Types.CatDef
	def.area = "exclusive"
	def.exclusive = true
	def.source = source
	return def
end

-- Section 3: 50 cats, 10 per area (four Common, two Rare, two Epic, one Legendary, one Mythical), then the ten of
-- the spare pool (3d). Each lives in exactly one area. Colors are the placeholder body's {r, g, b}. Rares and up in the Alleyway and the Park are
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
		"binbag",
		"Garbage Bag Cat",
		"Rare",
		"alley",
		"waiter",
		"stripes",
		{ 150, 145, 140 },
		"Found the comfiest bin bag in the alley and wears it everywhere."
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
		"taxi",
		"Taxi Cat",
		"Epic",
		"alley",
		"greeter",
		"stripes",
		{ 225, 140, 60 },
		"Picks up every customer right at the door."
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
		"neon",
		"Jazz Cat",
		"Mythical",
		"alley",
		"barista",
		"stripes",
		{ 45, 35, 110 },
		"Plays a soft tune while the coffee brews."
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
		"birdwatch",
		"Birdwatcher Cat",
		"Rare",
		"park",
		"barista",
		"stripes",
		{ 215, 185, 135 },
		"Watches the milk foam like it is a rare bird."
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
		"duckling",
		"Duckling Cat",
		"Epic",
		"park",
		"waiter",
		"patches",
		{ 240, 240, 240 },
		"Brings a duckling along to every table."
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
		"balloon",
		"Balloon Cat",
		"Mythical",
		"park",
		"entertainer",
		"patches",
		{ 245, 190, 210 },
		"Floats in on a bunch of balloons and makes everyone smile."
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
		"builder",
		"Construction Cat",
		"Rare",
		"neighbourhood",
		"waiter",
		"stripes",
		{ 140, 95, 60 },
		"Stacks plates as neatly as bricks."
	),
	cat(
		"gardener",
		"Gardener Cat",
		"Epic",
		"neighbourhood",
		"barista",
		"patches",
		{ 230, 215, 185 },
		"Waters the flowers between every latte."
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
		"gnome",
		"Gnome Cat",
		"Legendary",
		"neighbourhood",
		"waiter",
		"patches",
		{ 165, 165, 170 },
		"Stands perfectly still in the garden until someone needs a refill."
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
		"plumber",
		"Plumber Cat",
		"Rare",
		"sewer",
		"waiter",
		"patches",
		{ 105, 115, 125 },
		"Fixes every leaky pipe on the way to the table."
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
	-- 3d. The spare pool (v0.13, Derek 2026-10-27 23:59): the ten cats the area-themed ones replaced
	spare(
		cat(
			"calico",
			"Pirate Cat",
			"Rare",
			"alley",
			"waiter",
			"patches",
			{ 240, 190, 120 },
			"Carries every tray like buried treasure."
		)
	),
	spare(
		cat(
			"sphynx",
			"DJ Cat",
			"Epic",
			"alley",
			"greeter",
			"solid",
			{ 230, 180, 170 },
			"Drops a beat every time the door opens."
		)
	),
	spare(
		cat(
			"midnight",
			"Wizard Cat",
			"Mythical",
			"alley",
			"barista",
			"solid",
			{ 30, 30, 70 },
			"Stirs a little starlight into every cup."
		)
	),
	spare(
		cat(
			"siamese",
			"Nerd Cat",
			"Rare",
			"park",
			"barista",
			"points",
			{ 225, 205, 175 },
			"Measures every latte to the last drop."
		)
	),
	spare(
		cat(
			"persian",
			"Fancy Cat",
			"Epic",
			"park",
			"waiter",
			"solid",
			{ 245, 230, 200 },
			"Serves every cup on a silver tray."
		)
	),
	spare(
		cat(
			"aurora",
			"Astro Cat",
			"Mythical",
			"park",
			"entertainer",
			"gradient",
			{ 110, 200, 190 },
			"Moonwalks between the tables."
		)
	),
	spare(
		cat(
			"fold",
			"Fold",
			"Rare",
			"neighbourhood",
			"waiter",
			"solid",
			{ 170, 170, 180 },
			"A Neighbourhood regular. More soon."
		)
	),
	spare(
		cat(
			"chonk",
			"Chonk",
			"Epic",
			"neighbourhood",
			"barista",
			"solid",
			{ 230, 140, 60 },
			"A Neighbourhood regular. More soon."
		)
	),
	spare(
		cat(
			"marshmallow",
			"Marshmallow",
			"Legendary",
			"neighbourhood",
			"waiter",
			"solid",
			{ 252, 248, 245 },
			"A Neighbourhood regular. More soon."
		)
	),
	spare(
		cat(
			"lantern",
			"Lantern",
			"Rare",
			"sewer",
			"waiter",
			"solid",
			{ 240, 180, 80 },
			"Found down in the Sewer. More soon."
		)
	),
	-- The free Bellhop Cat (F96, starter-cat.md): one per account from its stand in the Town Square, at the Rare
	-- rate (3 a second at Tier 1, 243 at Tier 5), never gold. Its models are CatCafe_Cat_BellhopCat and _Sit.
	exclusive(
		cat(
			"bellhop_cat",
			"Bellhop Cat",
			"Rare",
			"alley",
			"greeter",
			"socks", -- ginger and white, white socks
			{ 232, 150, 80 },
			"Rings its bell for every customer and tips its cap as they pass."
		),
		"free"
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

-- The standing worker (body S, Model-Agent #826; Derek picked S on 2026-11-02) of a walking model, "CatCafe_Cat_Tabby"
-- -> "CatCafe_Cat_Tabby_Work" and "CatCafe_Cat_Tabby_Gold" -> "CatCafe_Cat_Tabby_Gold_Work".
function Catalog.workModelName(modelName: string): string
	return modelName .. "_Work"
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
-- A cat model's PropSlot and PropSlot2 attributes name its props' slots, and the role piece in either slot stays off
-- (CatDress.plan, with F71's Entertainer exception). Face props clash with nothing.
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
		caps = { tables = 2, espresso = 2, net = 1, lure_bowl = 1, lucky_cat = 1 },
	},
	{
		tier = 2,
		name = "Cozy Cafe",
		cost = 12000, -- F95 v2.1 (QA's Pace with cannon trips: 9.8 min, under the 10 min floor; was 10,000)
		distinctCats = 5,
		slots = 4,
		multiplier = 1.25,
		area = "park",
		caps = { tables = 4, espresso = 3, net = 2, lure_bowl = 2, lucky_cat = 2 },
	},
	{
		tier = 3,
		name = "Busy Cafe",
		cost = 500000, -- F95 v2 (was 350,000; 80,000 before F95)
		distinctCats = 12,
		needsRarity = "Epic",
		needsRarityCount = 1,
		slots = 6,
		multiplier = 1.50,
		area = "neighbourhood",
		caps = { tables = 6, espresso = 4, net = 3, lure_bowl = 3, lucky_cat = 3 },
	},
	{
		tier = 4,
		name = "Famous Cafe",
		cost = 40000000, -- F95 v2 (was 27,000,000; 700,000 before F95)
		distinctCats = 20,
		needsRarity = "Legendary",
		needsRarityCount = 1,
		slots = 8,
		multiplier = 1.75,
		area = "woods",
		caps = { tables = 6, espresso = 5, net = 3, lure_bowl = 4, lucky_cat = 4 },
	},
	{
		tier = 5,
		name = "Grand Cafe",
		cost = 1200000000, -- F95 v2 (was 800,000,000; 5,000,000 before F95)
		distinctCats = 30,
		needsRarity = "Legendary",
		needsRarityCount = 2,
		slots = 10,
		multiplier = 2.00,
		area = "sewer",
		caps = { tables = 6, espresso = 5, net = 3, lure_bowl = 5, lucky_cat = 5 },
	},
} :: { Types.TierDef }

Catalog.maxTier = #Catalog.tiers

function Catalog.getTier(tier: number): Types.TierDef?
	return Catalog.tiers[tier]
end

-- Lowest tier whose shop cap allows `level` of a capped upgrade (tables, espresso, net, lure_bowl, lucky_cat); nil when no tier
-- does.
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
		description = "Each table seats two more customers and brings in more money",
		maxLevel = 6,
		costs = { 150, 600, 3000, 10000, 200000, 600000 }, -- F95: levels 5 and 6 four times (section 4)
		startLevel = 0,
	},
	{
		id = "espresso",
		name = "Espresso machine",
		description = "Better coffee, more money from every cat",
		maxLevel = 5,
		costs = { 0, 2000, 15000, 400000, 6000000 }, -- F95: level 4 four times, 5 (Tier 4) 7.5 times
		startLevel = 1,
	},
	{
		id = "net",
		name = "Net",
		description = "A better net: higher odds on every swing",
		maxLevel = 3,
		costs = { 2500, 25000, 800000 }, -- F95: the Master Net four times
		startLevel = 0,
	},
	{
		id = "lure_bowl", -- shown as Bait bowl; ids keep the lure_ prefix (data-model section 6)
		name = "Bait bowl",
		-- F82 (v0.13.15): five levels, each tier opening one, the names in Bait.bowlName
		description = "A bowl on your back step. Each level brings bait cats sooner and rarer",
		maxLevel = 5,
		costs = { 600, 6000, 240000, 4000000, 50000000 }, -- F95: Fancy, Deluxe and Royal Bowls
		startLevel = 0,
	},
	{
		id = "lucky_cat", -- F88 (luck-and-rare-moments.md 1a): the statue by the front door, shared/Luck
		name = "Lucky Cat",
		description = "A beckoning cat by your front door. Each level adds x0.1 Luck: rarer bait cats and crate finds",
		maxLevel = 5,
		-- level n needs Tier n; levels 3 to 5 at economy-ladder.md section 4's prices
		costs = { 2000, 20000, 600000, 8000000, 80000000 },
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

-- Section 7: the four pieces of the old coin Decor shop. Since F97 (notes-10-28-to-10-30.md section 2) they are
-- found only in the Classic Crate, at their rarity, and keep their bonuses and their own anchors (no decor spot);
-- players who bought them keep them. The crate pieces (F53), the F48 Index pieces among them, are in
-- Catalog.crateDecor below.
Catalog.decor = {
	{
		id = "plants",
		name = "Window plants",
		cost = 0, -- F97: never sold
		category = "Plants",
		effect = "+5% money",
		description = "Green in the window, warmth in the room.",
		bonus = 0.05,
		asset = "CatCafe_Decor_WindowPlants",
		source = "crate",
		crate = "classic",
		rarity = "Common",
	},
	{
		id = "rug",
		name = "Cozy rug",
		cost = 0, -- F97: never sold
		category = "Floor",
		effect = "+5% money",
		description = "Warm paws, generous customers.",
		bonus = 0.05,
		asset = "CatCafe_Decor_Rug",
		source = "crate",
		crate = "classic",
		rarity = "Common",
	},
	{
		id = "neon_sign",
		name = "Neon cat sign",
		cost = 0, -- F97: never sold
		category = "Wall",
		effect = "+10% money",
		description = "Seen from the far end of the street.",
		bonus = 0.10,
		asset = "CatCafe_Decor_NeonSign",
		source = "crate",
		crate = "classic",
		rarity = "Rare",
	},
	{
		id = "fish_tank",
		name = "Fish tank",
		cost = 0, -- F97: never sold
		category = "Furniture",
		effect = "+10% money, cats stare at it",
		description = "The fish are fine. Probably.",
		bonus = 0.10,
		asset = "CatCafe_Decor_FishTank",
		source = "crate",
		crate = "classic",
		rarity = "Epic",
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
		cost = 100, -- F97: about four times 30; Economy.foodPrice grows it by tier
		sortOrder = 1,
		attracts = "Common",
		rarity = "Common",
		source = "shop",
		description = "Cheap and crunchy. Brings the regulars.",
		odds = { Common = 70, Rare = 25, Epic = 4, Legendary = 0.9, Mythical = 0.1 },
		asset = "CatCafe_Item_Kibble",
	},
	{
		id = "tuna",
		name = "Tuna",
		cost = 500, -- F97: about four times 125; Economy.foodPrice grows it by tier
		sortOrder = 2,
		attracts = "Rare",
		rarity = "Rare",
		source = "shop",
		description = "The good stuff. Rare cats come running.",
		odds = { Common = 40, Rare = 45, Epic = 12, Legendary = 2.6, Mythical = 0.4 },
		asset = "CatCafe_Item_TunaCan",
	},
	{
		id = "salmon",
		name = "Salmon",
		cost = 2500, -- F97: about four times 625; Economy.foodPrice grows it by tier
		sortOrder = 4,
		attracts = "Epic",
		rarity = "Epic",
		source = "shop",
		description = "Nobody can resist it, not even the Ninja Cat.",
		odds = { Common = 15, Rare = 45, Epic = 30, Legendary = 8.5, Mythical = 1.5 },
		asset = "CatCafe_Item_Salmon",
	},
	{
		id = "sardines",
		name = "Moonlit Sardines",
		cost = 4000, -- F97: about four times 1000; Economy.foodPrice grows it by tier
		sortOrder = 3,
		attracts = "Rare",
		rarity = "Rare",
		source = "dealer",
		description = "Silvery and still glowing a little.",
		odds = { Common = 30, Rare = 45, Epic = 20, Legendary = 4.5, Mythical = 0.5 },
		asset = "CatCafe_Item_Sardines",
	},
	{
		id = "caviar",
		name = "Caviar",
		cost = 15000, -- F97: about four times 3750; Economy.foodPrice grows it by tier
		sortOrder = 5,
		attracts = "Epic",
		rarity = "Epic",
		source = "dealer",
		description = "Tiny, glossy and very fancy.",
		odds = { Common = 10, Rare = 35, Epic = 38, Legendary = 14, Mythical = 3 },
		asset = "CatCafe_Item_Caviar",
	},
	{
		id = "moon_milk",
		name = "Moon Milk",
		cost = 50000, -- F97: about four times 12500; Economy.foodPrice grows it by tier
		sortOrder = 6,
		attracts = "Epic",
		rarity = "Legendary",
		source = "dealer",
		description = "Nobody knows where he gets it.",
		odds = { Common = 0, Rare = 20, Epic = 45, Legendary = 28, Mythical = 7 },
		asset = "CatCafe_Item_MoonMilk",
	},
	{
		id = "star_treat",
		name = "Star Treat",
		cost = 200000, -- F97: about four times 50000; Economy.foodPrice grows it by tier
		sortOrder = 7,
		attracts = "Legendary",
		rarity = "Mythical",
		source = "dealer",
		description = "It twinkles. Mythical cats can smell it from the next area.",
		odds = { Common = 0, Rare = 0, Epic = 40, Legendary = 45, Mythical = 15 },
		asset = "CatCafe_Item_StarTreat",
	},
} :: { Types.LureDef }

-- Section 11b (F47): the Tip Jar's twelve playtime gifts in step order, unlocked by minutes of the current session.
-- Coins scale with the day rate at claim time (shared/TipJar.coins); the dealer foods are fine here since they are
-- free. Nothing about the jar can be bought. F95 (economy-ladder.md section 6b, Derek 2026-10-30 00:27): every prize
-- paid in seconds of day rate in this file (the jar, the Daily Treat, quests, the wheel, achievements, the Index
-- milestones and codes) pays half the seconds it did; the minimum coins stay. F94 (rewards-and-shops.md section 2a):
-- small amounts of golden fish in place of shop food, and at most three pictures on the two hour gift.
Catalog.tipJar = {
	{ step = 1, minutes = 2, prize = { coins = 50, coinSeconds = 15 } },
	{ step = 2, minutes = 5, prize = { fish = 2 } },
	{ step = 3, minutes = 10, prize = { coins = 100, coinSeconds = 30 } },
	{ step = 4, minutes = 15, prize = { fish = 2 } },
	{ step = 5, minutes = 20, prize = { coins = 150, coinSeconds = 45 } },
	{ step = 6, minutes = 30, prize = { spins = 1 } },
	{ step = 7, minutes = 40, prize = { coins = 250, coinSeconds = 60 } },
	{ step = 8, minutes = 50, prize = { fish = 3 } },
	-- v0.10 (F68, round 4 Q10): a pretty good gift at one hour
	{ step = 9, minutes = 60, prize = { coins = 1000, coinSeconds = 300, fish = 10 } },
	{ step = 10, minutes = 75, prize = { fish = 5 } },
	{ step = 11, minutes = 90, prize = { coins = 600, coinSeconds = 150, spins = 1 } },
	-- and a really good one at two hours
	{ step = 12, minutes = 120, prize = { crates = { classic_crate = 1 }, fish = 30 } },
} :: { Types.TipJarStep }

-- Section 11e (F70, round 4 Q9): the Daily Treat card, one stamp per UTC day played and never reset. Days 2 and 4
-- are pretty good and day 7 really good: a Golden Classic Crate and a Star Treat, the night dealer's best bait, for a
-- real shot at a top cat while cats still come only from catching, rescue and bait. Earned only (monetization-policy).
-- F94 (rewards-and-shops.md section 2c): no shop food, and day 7 drops its spins to three pictures.
Catalog.dailyTreat = {
	{ day = 1, prize = { coins = 300, coinSeconds = 150 } },
	{ day = 2, prize = { fish = 15, spins = 1 } },
	{ day = 3, prize = { coins = 600, coinSeconds = 300 } },
	{ day = 4, prize = { crates = { classic_crate = 1 }, spins = 1 } },
	{ day = 5, prize = { coins = 1000, coinSeconds = 450 } },
	{ day = 6, prize = { potions = { lucky_potion = 1 }, fish = 10 } },
	{
		day = 7,
		prize = {
			crates = { classic_golden_crate = 1 },
			lures = { star_treat = 1 },
			fish = 50,
		},
	},
} :: { Types.DailyTreatDay }

-- Section 11c (F49): the Spin Wheel's six slices in order around the wheel. Free spins only: no Robux button, pass
-- or product gives spins (monetization-policy), and a spin never gives a cat. Frozen, like the Index prizes. F94
-- (rewards-and-shops.md section 2b): golden fish and a Caviar in place of the shop food.
Catalog.spinWheel = {
	{ slice = 1, kind = "coins", seconds = 120, minCoins = 200, weight = 30 },
	{ slice = 2, kind = "fish", count = 3, weight = 22 }, -- F94 (was 3 Tuna)
	{ slice = 3, kind = "coins", seconds = 600, minCoins = 1000, weight = 18 },
	{ slice = 4, kind = "lure", lureId = "caviar", count = 1, weight = 15 }, -- F94 (was 2 Salmon)
	{ slice = 5, kind = "fish", count = 8, weight = 10 }, -- F54 (was 2 Moonlit Sardines), 8 since F94 (was 4)
	{ slice = 6, kind = "crate", crate = "highest", count = 1, weight = 5 }, -- F54 (was 1 Caviar)
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

-- Section 12b (F64): the potions, in the bag's order. A potion runs `minutes` of play time once drunk (UsePotion);
-- drinking another of a running kind adds its time, up to Config.PotionMaxMinutes. Earned only (Tip Jar, codes,
-- Mystery gifts), never sold: one for Robux would change income or catch odds and needs the monetization review.
-- F94 (rewards-and-shops.md section 5): the Tip Potions read Money Potions; their ids stay so saves keep working.
Catalog.potions = {
	{
		id = "tip_potion",
		name = "Money Potion",
		minutes = 10,
		effect = "+25% money",
		tips = Config.TipPotionBonus,
	},
	{
		id = "lucky_potion",
		name = "Lucky Potion",
		minutes = 10,
		effect = "Luck +0.5 and double gold chance on bait", -- F88: Config.LuckyPotionLuck
	},
	{ id = "swift_potion", name = "Swift Potion", minutes = 5, effect = "+4 walk speed" },
	{
		id = "steady_potion",
		name = "Steady Paw Potion",
		minutes = 10,
		effect = "Easier catch circles",
	},
	-- F73 (quests.md section 4): the quest potions, paid only by full quest sets and achievements
	{
		id = "big_tip_potion",
		name = "Big Money Potion",
		minutes = 30,
		effect = "+50% money",
		tips = 0.5,
		quest = true,
	},
	{
		id = "gold_rush_potion",
		name = "Gold Rush Potion",
		minutes = 30,
		effect = "+25% gold luck",
		goldLuck = 0.25,
		quest = true,
	},
	{
		id = "quick_bait_potion",
		name = "Quick Bait Potion",
		minutes = 30,
		effect = "Bait ready 25% sooner",
		baitSpeed = 0.25,
		quest = true,
	},
} :: { Types.PotionDef }
Catalog.potionsById = {} :: { [string]: Types.PotionDef }
for _, def in Catalog.potions do
	Catalog.potionsById[def.id] = def
end
for _, def in Catalog.potions do
	table.freeze(def)
end
table.freeze(Catalog.potions)

function Catalog.getPotion(id: string): Types.PotionDef?
	return Catalog.potionsById[id]
end

-- Quests and achievements (F73, quests.md sections 2, 3 and 5, approved by Derek 2026-10-27 22:14). Each day picks
-- one quest per slot from its pool, in Quests.DAILY_POOLS order (two Streets, Cafe, Extra, the Big Request), each week
-- one from each weekly pool. Coins quests fix their needs from the day rate when picked.
Catalog.quests = {
	daily = {
		streets = {
			{ id = "d_catch5", text = "Catch 5 cats", stat = "catsCaught", needs = 5 },
			{
				id = "d_perfect10",
				text = "Land 10 perfect circles",
				stat = "perfectCircles",
				needs = 10,
			},
			{ id = "d_rescue2", text = "Rescue 2 stuck cats", stat = "rescues", needs = 2 },
			{
				id = "d_rare1",
				text = "Catch a Rare or better cat",
				stat = "rareCatches",
				needs = 1,
			},
		},
		cafe = {
			{
				id = "d_coins",
				text = "Earn coins",
				stat = "lifetimeCoins",
				needsSeconds = 600,
				needsMin = 500,
			},
			{ id = "d_tips6", text = "Collect 6 tip piles", stat = "tipPilesCollected", needs = 6 },
			{
				id = "d_bait1",
				text = "Tame a cat at your bait bowl",
				stat = "baitsTamed",
				needs = 1,
				requires = { upgrade = "lure_bowl" },
			},
			{
				id = "d_food2",
				text = "Put 2 foods in your bait bowl",
				stat = "luresUsed",
				needs = 2,
				requires = { upgrade = "lure_bowl" },
			},
		},
		extra = {
			{ id = "d_spin1", text = "Spin the wheel", stat = "spins", needs = 1 },
			{ id = "d_tipjar3", text = "Claim 3 Tip Jar gifts", stat = "tipJarClaims", needs = 3 },
			{ id = "d_fish5", text = "Earn 5 golden fish", stat = "fishEarned", needs = 5 },
			{
				id = "d_crate1",
				text = "Open a Cafe Crate",
				stat = "cratesOpened",
				needs = 1,
				requires = { fishOrCrate = true },
			},
			{ id = "d_levelup1", text = "Level up a cat", stat = "catLevelUps", needs = 1 },
		},
		big = {
			{
				id = "d_rare3",
				text = "Catch 3 Rare or better cats",
				stat = "rareCatches",
				needs = 3,
			},
			{ id = "d_catch12", text = "Catch 12 cats", stat = "catsCaught", needs = 12 },
			{ id = "d_rescue5", text = "Rescue 5 stuck cats", stat = "rescues", needs = 5 },
			{
				id = "d_perfect30",
				text = "Land 30 perfect circles",
				stat = "perfectCircles",
				needs = 30,
			},
			{
				id = "d_coinsbig",
				text = "Earn coins",
				stat = "lifetimeCoins",
				needsSeconds = 1500,
				needsMin = 1500,
			},
		},
	},
	weekly = {
		a = {
			{ id = "w_catch60", text = "Catch 60 cats", stat = "catsCaught", needs = 60 },
			{
				id = "w_perfect150",
				text = "Land 150 perfect circles",
				stat = "perfectCircles",
				needs = 150,
			},
			{ id = "w_rescue15", text = "Rescue 15 stuck cats", stat = "rescues", needs = 15 },
		},
		b = {
			{
				id = "w_coins",
				text = "Earn coins",
				stat = "lifetimeCoins",
				needsSeconds = 10800,
				needsMin = 10000,
			},
			{
				id = "w_bait10",
				text = "Tame 10 cats at your bait bowl",
				stat = "baitsTamed",
				needs = 10,
				requires = { upgrade = "lure_bowl" },
			},
			{
				id = "w_tips60",
				text = "Collect 60 tip piles",
				stat = "tipPilesCollected",
				needs = 60,
			},
		},
		c = {
			{
				id = "w_new2",
				text = "Find 2 new cats",
				stat = "distinctCats",
				needs = 2,
				requires = { uncaught = 2 },
			},
			{ id = "w_gold2", text = "Catch 2 gold cats", stat = "goldCatches", needs = 2 },
			{
				id = "w_daily15",
				text = "Finish 15 daily quests",
				stat = "dailyQuestsDone",
				needs = 15,
			},
			{
				id = "w_sets3",
				text = "Finish all your dailies on 3 days",
				stat = "dailySetsDone",
				needs = 3,
			},
		},
	},
} :: {
	daily: { [string]: { Types.QuestDef } },
	weekly: { [string]: { Types.QuestDef } },
}

-- What finishing a quest pays, in the Index prize shape: coins are `coinSeconds` of the day rate when claimed, at
-- least `coins`. F94 (rewards-and-shops.md section 2d): no shop food and no spins, two pictures a quest and three on
-- the sets.
Catalog.questPrizes = {
	daily = { coins = 200, coinSeconds = 90, fish = 2 },
	dailyBig = { coins = 400, coinSeconds = 150, fish = 5 },
	dailySet = { potions = { big_tip_potion = 1, gold_rush_potion = 1 }, fish = 10 },
	weekly = { coins = 2000, coinSeconds = 600, fish = 15 },
	weeklySet = {
		potions = { big_tip_potion = 3 },
		crates = { classic_golden_crate = 1 },
		fish = 40,
	},
} :: { [string]: Types.IndexPrize }

-- The 44 achievements, each on its own and paid once, in the design's table order.
Catalog.achievements = {
	{
		id = "a_first_catch",
		name = "First Catch",
		text = "Catch your first cat",
		measure = "catsCaught",
		needs = 1,
		size = "S",
	},
	{
		id = "a_catch100",
		name = "Cat Catcher",
		text = "Catch 100 cats",
		measure = "catsCaught",
		needs = 100,
		size = "M",
	},
	{
		id = "a_catch1k",
		name = "Cat Wrangler",
		text = "Catch 1,000 cats",
		measure = "catsCaught",
		needs = 1000,
		size = "L",
	},
	{
		id = "a_catch10k",
		name = "Cat Legend",
		text = "Catch 10,000 cats",
		measure = "catsCaught",
		needs = 10000,
		size = "XL",
	},
	{
		id = "a_rare1",
		name = "Rare Find",
		text = "Catch a Rare or better cat",
		measure = "rareCatches",
		needs = 1,
		size = "S",
	},
	{
		id = "a_rare100",
		name = "Rare Hunter",
		text = "Catch 100 Rare or better cats",
		measure = "rareCatches",
		needs = 100,
		size = "L",
	},
	{
		id = "a_gold1",
		name = "Golden Paws",
		text = "Catch a gold cat",
		measure = "goldCatches",
		needs = 1,
		size = "M",
	},
	{
		id = "a_gold50",
		name = "Gold Rush",
		text = "Catch 50 gold cats",
		measure = "goldCatches",
		needs = 50,
		size = "XL",
	},
	{
		id = "a_perfect1",
		name = "Perfect Circle",
		text = "Land a perfect circle",
		measure = "perfectCircles",
		needs = 1,
		size = "S",
	},
	{
		id = "a_perfect500",
		name = "Perfect Paws",
		text = "Land 500 perfect circles",
		measure = "perfectCircles",
		needs = 500,
		size = "L",
	},
	{
		id = "a_perfect5k",
		name = "Steady Hands",
		text = "Land 5,000 perfect circles",
		measure = "perfectCircles",
		needs = 5000,
		size = "XL",
	},
	{
		id = "a_rescue1",
		name = "First Rescue",
		text = "Rescue a stuck cat",
		measure = "rescues",
		needs = 1,
		size = "S",
	},
	{
		id = "a_rescue250",
		name = "Rescue Hero",
		text = "Rescue 250 stuck cats",
		measure = "rescues",
		needs = 250,
		size = "L",
	},
	{
		id = "a_bait1",
		name = "Bait Beginner",
		text = "Tame a cat at your bait bowl",
		measure = "baitsTamed",
		needs = 1,
		size = "S",
	},
	{
		id = "a_bait200",
		name = "Bait Master",
		text = "Tame 200 cats at your bait bowl",
		measure = "baitsTamed",
		needs = 200,
		size = "L",
	},
	{
		id = "a_cats10",
		name = "Growing Family",
		text = "Find 10 different cats",
		measure = "distinctCats",
		needs = 10,
		size = "S",
	},
	{
		id = "a_cats25",
		name = "Big Family",
		text = "Find 25 different cats",
		measure = "distinctCats",
		needs = 25,
		size = "M",
	},
	{
		id = "a_cats50",
		name = "Every Cat",
		text = "Find all 50 cats",
		measure = "distinctCats",
		needs = 50,
		size = "XL",
	},
	{
		id = "a_goldcats10",
		name = "Gold Collector",
		text = "Find 10 different gold cats",
		measure = "goldCats",
		needs = 10,
		size = "L",
	},
	{
		id = "a_mythical",
		name = "Mythical Friend",
		text = "Find a Mythical cat",
		measure = "mythicalCats",
		needs = 1,
		size = "L",
	},
	{
		id = "a_tier2",
		name = "Open for Business",
		text = "Reach Cozy Cafe (Tier 2)",
		measure = "tier",
		needs = 2,
		size = "S",
	},
	{
		id = "a_tier3",
		name = "Busy Bee",
		text = "Reach Busy Cafe (Tier 3)",
		measure = "tier",
		needs = 3,
		size = "M",
	},
	{
		id = "a_tier4",
		name = "Famous",
		text = "Reach Famous Cafe (Tier 4)",
		measure = "tier",
		needs = 4,
		size = "L",
	},
	{
		id = "a_tier5",
		name = "Grand Opening",
		text = "Reach Grand Cafe (Tier 5)",
		measure = "tier",
		needs = 5,
		size = "XL",
	},
	{
		id = "a_coins10k",
		name = "Pocket Money",
		text = "Earn 10,000 coins",
		measure = "lifetimeCoins",
		needs = 10000,
		size = "S",
	},
	{
		id = "a_coins1m",
		name = "Big Earner",
		text = "Earn 1,000,000 coins",
		measure = "lifetimeCoins",
		needs = 1000000,
		size = "L",
	},
	{
		id = "a_coins100m",
		name = "Coin Mountain",
		text = "Earn 100,000,000 coins",
		measure = "lifetimeCoins",
		needs = 100000000,
		size = "XL",
	},
	{
		id = "a_tips100",
		name = "Tip Collector",
		text = "Collect 100 tip piles",
		measure = "tipPilesCollected",
		needs = 100,
		size = "M",
	},
	{
		id = "a_tips2k",
		name = "Head Waiter",
		text = "Collect 2,000 tip piles",
		measure = "tipPilesCollected",
		needs = 2000,
		size = "L",
	},
	{
		id = "a_net",
		name = "Master Net",
		text = "Get the Master Net",
		measure = "upgrade:net",
		needs = 3,
		size = "M",
	},
	{
		id = "a_tables",
		name = "Full House",
		text = "Get every table",
		measure = "upgrade:tables",
		needs = 6,
		size = "M",
	},
	{
		id = "a_spins50",
		name = "Lucky Spinner",
		text = "Spin the wheel 50 times",
		measure = "spins",
		needs = 50,
		size = "M",
	},
	{
		id = "a_crates25",
		name = "Crate Opener",
		text = "Open 25 Cafe Crates",
		measure = "cratesOpened",
		needs = 25,
		size = "M",
	},
	{
		id = "a_decor30",
		name = "Decorator",
		text = "Own 30 decor pieces",
		measure = "decorOwned",
		needs = 30,
		size = "L",
	},
	{
		id = "a_potions25",
		name = "Potion Brewer",
		text = "Drink 25 potions",
		measure = "potionsUsed",
		needs = 25,
		size = "M",
	},
	{
		id = "a_trades5",
		name = "Collector's Friend",
		text = "Trade 5 cats with the Cat Collector",
		measure = "collectorTrades",
		needs = 5,
		size = "M",
	},
	{
		id = "a_gifts10",
		name = "Mystery Fan",
		text = "Open 10 Mystery Visitor gifts",
		measure = "mysteryGifts",
		needs = 10,
		size = "M",
	},
	{
		id = "a_hours10",
		name = "Cafe Regular",
		text = "Play for 10 hours",
		measure = "playtimeSeconds",
		needs = 36000,
		size = "M",
	},
	{
		id = "a_hours100",
		name = "Devoted",
		text = "Play for 100 hours",
		measure = "playtimeSeconds",
		needs = 360000,
		size = "XL",
	},
	{
		id = "a_quests100",
		name = "Quest Keeper",
		text = "Finish 100 daily quests",
		measure = "dailyQuestsDone",
		needs = 100,
		size = "L",
	},
	{
		id = "a_week1",
		name = "Full Week",
		text = "Finish every weekly quest in a week",
		measure = "weeklySetsDone",
		needs = 1,
		size = "M",
	},
	{
		id = "a_week10",
		name = "Week Champion",
		text = "Finish every weekly quest in 10 weeks",
		measure = "weeklySetsDone",
		needs = 10,
		size = "XL",
	},
	{
		id = "a_level25",
		name = "Top Cat",
		text = "Raise a cat to level 25",
		measure = "topCatLevel",
		needs = 25,
		size = "L",
	},
	{
		id = "a_level50",
		name = "Master Cat",
		text = "Raise a cat to level 50",
		measure = "topCatLevel",
		needs = 50,
		size = "XL",
	},
} :: { Types.AchievementDef }

-- An achievement's prize by its size; coins scale with the day rate when claimed. F94 (rewards-and-shops.md section
-- 2d): two pictures, three on XL.
Catalog.achievementPrizes = {
	S = { coins = 300, coinSeconds = 150, spins = 1 },
	M = { coins = 1000, coinSeconds = 450, potions = { tip_potion = 1 } },
	L = { coins = 2500, coinSeconds = 900, crates = { classic_crate = 1 } },
	XL = {
		coins = 5000,
		coinSeconds = 1800,
		crates = { classic_golden_crate = 1 },
		potions = { big_tip_potion = 1 },
	},
} :: { [string]: Types.IndexPrize }

Catalog.questsById = {} :: { [string]: Types.QuestDef }
Catalog.questPools = {} :: { [string]: string } -- quest id -> its pool
for _, pools in { Catalog.quests.daily, Catalog.quests.weekly } do
	for pool, rows in pools do
		for _, row in rows do
			Catalog.questsById[row.id] = row
			Catalog.questPools[row.id] = pool
			if row.requires ~= nil then
				table.freeze(row.requires)
			end
			table.freeze(row)
		end
		table.freeze(rows)
	end
	table.freeze(pools)
end
table.freeze(Catalog.quests)
Catalog.achievementsById = {} :: { [string]: Types.AchievementDef }
for _, def in Catalog.achievements do
	Catalog.achievementsById[def.id] = def
	table.freeze(def)
end
table.freeze(Catalog.achievements)
for _, prizes in { Catalog.questPrizes, Catalog.achievementPrizes } do
	for _, prize in prizes do
		for _, part in prize :: { [string]: any } do
			if type(part) == "table" then
				table.freeze(part)
			end
		end
		table.freeze(prize)
	end
	table.freeze(prizes)
end

function Catalog.getQuest(id: string): Types.QuestDef?
	return Catalog.questsById[id]
end

function Catalog.getAchievement(id: string): Types.AchievementDef?
	return Catalog.achievementsById[id]
end

-- Section 12b (F64): what a Mystery Visitor's gift holds, rolled when it appears and shown before it is opened.
-- Chances in percent; a potion is one of Catalog.potions at even odds. F94 (rewards-and-shops.md section 2f): the 2
-- Salmon go to the golden fish (was 10%).
Catalog.mysteryGift = {
	{ kind = "potion", count = 1, chance = 60 },
	{ kind = "fish", count = 10, chance = 30 },
	{ kind = "spin", count = 1, chance = 10 },
} :: { Types.MysteryGiftRow }
for _, row in Catalog.mysteryGift do
	table.freeze(row)
end
table.freeze(Catalog.mysteryGift)

-- Section 12b (F63): the Cat Collector's offers by the value he puts on the cat, lowest first. He offers the best row
-- his value reaches, and the first below that, so a Common always gets 5 golden fish. The crate rows start at 6 and 11
-- (Design #500), so every Epic gets a crate and its best rolls 20 fish with it. A zone crate is the crate of
-- the cat's own area and a golden crate its golden version (golden-fish.md section 4). F94 (rewards-and-shops.md
-- section 2f): value 2 pays 10 golden fish (was 3 Tuna and a spin).
Catalog.collectorOffers = {
	{ value = 1, fish = 5 },
	{ value = 2, fish = 10 },
	{ value = 4, fish = 15 },
	{ value = 6, crates = { zone = 1 } },
	{ value = 11, crates = { zone = 1 }, fish = 20 },
	{ value = 20, crates = { zone = 2 } },
	{ value = 35, crates = { golden = 1 } },
	{ value = 60, crates = { golden = 1 }, fish = 50 },
	{ value = 120, crates = { golden = 2 }, fish = 100 },
} :: { Types.CollectorOffer }
for _, row in Catalog.collectorOffers do
	table.freeze(row)
end
table.freeze(Catalog.collectorOffers)

-- Section 8b: chance per dealer slot of each dealer food. v0.5 F43: one row for everyone (the old Tier 3 row).
-- Retired by v0.8 F59 (the amounts below); only the UI's offline demo still reads it.
Catalog.dealerSlotWeights =
	{ sardines = 50, caviar = 33, moon_milk = 14, star_treat = 3 } :: { [string]: number }

-- Section 8b v0.8 (F59, round 3 Q5): the chance in percent that a stock holds 0, 1, 2, 3 or 4 of each dealer food.
-- Averages 1.85, 0.95, 0.45 and 0.10: a Star Treat turns up about one night in ten. F94 (rewards-and-shops.md
-- section 4): each server rolls one stock at dusk that holds all night (was every 5 minutes).
Catalog.dealerAmountWeights = {
	sardines = { 15, 25, 30, 20, 10 },
	caviar = { 35, 40, 20, 5, 0 },
	moon_milk = { 60, 35, 5, 0, 0 },
	star_treat = { 90, 10, 0, 0, 0 },
} :: { [string]: { number } }

-- Section 9. Every area has the same odds since v0.13.7 (Derek 2026-10-28 01:50: rare cats come mainly from food
-- and time); farther areas pay more through incomeMultiplier instead. A full wave of waveSize strays spawns in every area at each sunrise, whether or not anyone has it
-- open, with no top-ups during the day. Data-model 9 v0.13.5 (Derek 2026-10-28 01:34, "way too many"): 6, 5, 5, 4
-- and 4, 24 a day in all (was 10 each). Every side area's spawn points are its kit set's cat spots (Model-Agent
-- #401, the Park's, the Woods', the Sewer's and the Neighbourhood's v3.2 sets #460, #470, #491 and #505).
Catalog.areas = {
	{
		id = "alley",
		name = "Alleyway",
		tier = 1,
		-- two on the lanes for each cafe's old place, eight nooks at the far end and eight `near` points by the camp for
		-- the tutorial stray only (layout v3.1; v4, F84, data-model section 9 v0.13.18)
		spawnPoints = 32,
		waveSize = 6,
		rescueSpots = 3,
		odds = { Common = 72, Rare = 22, Epic = 5, Legendary = 0.9, Mythical = 0.1 },
		incomeMultiplier = AREA_INCOME.alley,
	},
	{
		id = "park",
		name = "Park",
		tier = 2,
		spawnPoints = 48, -- F85's long set's cat spots, 20 near the camp and 28 deep
		waveSize = 5,
		rescueSpots = 5,
		odds = { Common = 72, Rare = 22, Epic = 5, Legendary = 0.9, Mythical = 0.1 },
		incomeMultiplier = AREA_INCOME.park,
	},
	{
		id = "neighbourhood",
		name = "Neighbourhood",
		tier = 3,
		spawnPoints = 77, -- F85's long set's cat spots, 32 near the camp and 45 deep (side paths for porches, #905)
		waveSize = 5,
		rescueSpots = 4, -- two sheds and two gutters
		odds = { Common = 72, Rare = 22, Epic = 5, Legendary = 0.9, Mythical = 0.1 },
		incomeMultiplier = AREA_INCOME.neighbourhood,
	},
	{
		id = "woods",
		name = "Woods",
		tier = 4,
		spawnPoints = 72, -- F85's long set's cat spots, 28 near the camp, 43 deep and the Great Oak's top
		waveSize = 4,
		rescueSpots = 5, -- two hollow logs, two bramble bushes and the tree house branch
		odds = { Common = 72, Rare = 22, Epic = 5, Legendary = 0.9, Mythical = 0.1 },
		incomeMultiplier = AREA_INCOME.woods,
	},
	{
		id = "sewer",
		name = "Sewer",
		tier = 5,
		spawnPoints = 60, -- F85's long set's cat spots, 25 near the camp and 35 deep
		waveSize = 4,
		rescueSpots = 4, -- two grates and two drain pipes
		odds = { Common = 72, Rare = 22, Epic = 5, Legendary = 0.9, Mythical = 0.1 },
		incomeMultiplier = AREA_INCOME.sewer,
	},
} :: { Types.AreaDef }

Catalog.areasById = {} :: { [string]: Types.AreaDef }
for _, def in Catalog.areas do
	Catalog.areasById[def.id] = def
end

-- Section 11b and golden-fish.md sections 5 and 5b (F54): every Index milestone, in order. An area page has the
-- normal track (its cats) and the gold track (its gold cats), the All Cats page (area id "all") counts different
-- cats across every area, a Decor Index page (area id "decor_<pool>") counts that crate's pieces owned and the
-- Rainbow page (area id "rainbow", F99) counts different rainbow cats across every area. A page shows the milestones
-- it has a prize for.
Catalog.indexMilestones = {
	{ id = "cats3", track = "normal", needs = 3 },
	{ id = "cats6", track = "normal", needs = 6 },
	{ id = "cats10", track = "normal", needs = 10 },
	{ id = "gold1", track = "gold", needs = 1 },
	{ id = "gold2", track = "gold", needs = 2 },
	{ id = "gold4", track = "gold", needs = 4 },
	{ id = "gold6", track = "gold", needs = 6 },
	{ id = "gold8", track = "gold", needs = 8 },
	{ id = "gold10", track = "gold", needs = 10 },
	{ id = "total5", track = "normal", needs = 5 },
	{ id = "total10", track = "normal", needs = 10 },
	{ id = "total15", track = "normal", needs = 15 },
	{ id = "total20", track = "normal", needs = 20 },
	{ id = "total25", track = "normal", needs = 25 },
	{ id = "total30", track = "normal", needs = 30 },
	{ id = "total35", track = "normal", needs = 35 },
	{ id = "total40", track = "normal", needs = 40 },
	{ id = "total45", track = "normal", needs = 45 },
	{ id = "total50", track = "normal", needs = 50 },
	{ id = "decor5", track = "decor", needs = 5 },
	-- every piece of the page: 12 since F80 (golden-fish.md 4b), and 16 on the Classic page since F97 (`whole`)
	{ id = "decor10", track = "decor", needs = 12, whole = true },
	-- F99 (rainbow-coat.md section 4): one track for the whole Index, since one rainbow Mythical can take weeks
	{ id = "rainbow1", track = "rainbow", needs = 1 },
	{ id = "rainbow3", track = "rainbow", needs = 3 },
	{ id = "rainbow5", track = "rainbow", needs = 5 },
	{ id = "rainbow10", track = "rainbow", needs = 10 },
	{ id = "rainbow25", track = "rainbow", needs = 25 },
} :: { Types.IndexMilestone }

-- What each milestone pays per page (golden-fish.md sections 4, 5 and 5b). Everything is free and only the server
-- pays it. The normal track adds tips forever (`bonus`), the gold track gold luck (`goldLuck`) and All Cats faster
-- bait (`baitSpeed`). Named apart from profile.indexRewards (the claims) and frozen, so a write meant for a profile
-- errors instead of changing the prize for everyone on the server (reviewer S61). F94 (rewards-and-shops.md section
-- 2e): no shop food or spins beside a crate, so a prize shows two pictures and a track's last milestone three.
Catalog.indexPrizes = {
	alley = {
		cats3 = { coins = 300, coinSeconds = 300, fish = 5 },
		cats6 = { crates = { alley_crate = 1 }, fish = 5, bonus = 0.02 },
		cats10 = {
			crates = { alley_crate = 2, alley_golden_crate = 1 },
			fish = 25,
			bonus = 0.05,
		},
		gold1 = { fish = 10, crates = { alley_crate = 1 }, goldLuck = 0.02 },
		gold2 = { coins = 1000, coinSeconds = 450, fish = 15, goldLuck = 0.03 },
		gold4 = { crates = { alley_golden_crate = 1 }, fish = 25, goldLuck = 0.05 },
		gold6 = {
			coins = 2000,
			coinSeconds = 900,
			fish = 50,
			goldLuck = 0.05,
		},
		gold8 = { crates = { alley_golden_crate = 1 }, fish = 60, goldLuck = 0.05 },
		gold10 = {
			coins = 5000,
			coinSeconds = 1800,
			crates = { alley_golden_crate = 2 },
			fish = 100,
			tag = "Alleyway Gold Master",
			goldLuck = 0.10,
		},
	},
	park = {
		cats3 = { coins = 1000, coinSeconds = 300, fish = 10 },
		cats6 = { crates = { park_crate = 1 }, fish = 10, bonus = 0.02 },
		cats10 = {
			crates = { park_crate = 2, park_golden_crate = 1 },
			fish = 35,
			bonus = 0.05,
		},
		gold1 = { fish = 15, crates = { park_crate = 1 }, goldLuck = 0.02 },
		gold2 = { coins = 3000, coinSeconds = 450, fish = 20, goldLuck = 0.03 },
		gold4 = { crates = { park_golden_crate = 1 }, fish = 35, goldLuck = 0.05 },
		gold6 = {
			coins = 6000,
			coinSeconds = 900,
			fish = 60,
			goldLuck = 0.05,
		},
		gold8 = { crates = { park_golden_crate = 1 }, fish = 75, goldLuck = 0.05 },
		gold10 = {
			coins = 15000,
			coinSeconds = 1800,
			crates = { park_golden_crate = 2 },
			fish = 125,
			tag = "Park Gold Master",
			goldLuck = 0.10,
		},
	},
	neighbourhood = {
		cats3 = { coins = 3000, coinSeconds = 300, fish = 15 },
		cats6 = { crates = { neighbourhood_crate = 1 }, lures = { caviar = 2 }, bonus = 0.02 },
		cats10 = {
			crates = { neighbourhood_crate = 2, neighbourhood_golden_crate = 1 },
			fish = 50,
			bonus = 0.05,
		},
		gold1 = { fish = 20, crates = { neighbourhood_crate = 1 }, goldLuck = 0.02 },
		gold2 = { coins = 10000, coinSeconds = 450, fish = 30, goldLuck = 0.03 },
		gold4 = { crates = { neighbourhood_golden_crate = 1 }, fish = 45, goldLuck = 0.05 },
		gold6 = {
			coins = 20000,
			coinSeconds = 900,
			fish = 70,
			goldLuck = 0.05,
		},
		gold8 = { crates = { neighbourhood_golden_crate = 1 }, fish = 90, goldLuck = 0.05 },
		gold10 = {
			coins = 50000,
			coinSeconds = 1800,
			crates = { neighbourhood_golden_crate = 2 },
			fish = 150,
			tag = "Neighbourhood Gold Master",
			goldLuck = 0.10,
		},
	},
	woods = {
		cats3 = { coins = 10000, coinSeconds = 300, fish = 20 },
		cats6 = { crates = { woods_crate = 1 }, lures = { moon_milk = 2 }, bonus = 0.02 },
		cats10 = {
			crates = { woods_crate = 2, woods_golden_crate = 1 },
			fish = 75,
			bonus = 0.05,
		},
		gold1 = { fish = 25, crates = { woods_crate = 1 }, goldLuck = 0.02 },
		gold2 = { coins = 30000, coinSeconds = 450, fish = 40, goldLuck = 0.03 },
		gold4 = { crates = { woods_golden_crate = 1 }, fish = 60, goldLuck = 0.05 },
		gold6 = {
			coins = 60000,
			coinSeconds = 900,
			fish = 90,
			goldLuck = 0.05,
		},
		gold8 = { crates = { woods_golden_crate = 1 }, fish = 120, goldLuck = 0.05 },
		gold10 = {
			coins = 150000,
			coinSeconds = 1800,
			crates = { woods_golden_crate = 2 },
			fish = 200,
			tag = "Woods Gold Master",
			goldLuck = 0.10,
		},
	},
	sewer = {
		cats3 = { coins = 30000, coinSeconds = 300, fish = 25 },
		cats6 = { crates = { sewer_crate = 1 }, lures = { star_treat = 2 }, bonus = 0.02 },
		cats10 = {
			crates = { sewer_crate = 2, sewer_golden_crate = 1 },
			fish = 100,
			bonus = 0.05,
		},
		gold1 = { fish = 30, crates = { sewer_crate = 1 }, goldLuck = 0.02 },
		gold2 = { coins = 100000, coinSeconds = 450, fish = 50, goldLuck = 0.03 },
		gold4 = { crates = { sewer_golden_crate = 1 }, fish = 75, goldLuck = 0.05 },
		gold6 = {
			coins = 200000,
			coinSeconds = 900,
			fish = 110,
			goldLuck = 0.05,
		},
		gold8 = { crates = { sewer_golden_crate = 1 }, fish = 150, goldLuck = 0.05 },
		gold10 = {
			coins = 500000,
			coinSeconds = 1800,
			crates = { sewer_golden_crate = 2 },
			fish = 250,
			tag = "Sewer Gold Master",
			goldLuck = 0.10,
		},
	},
	all = {
		total5 = { fish = 10, spins = 1, baitSpeed = 0.02 },
		total10 = { fish = 15, crates = { classic_crate = 1 }, baitSpeed = 0.02 },
		total15 = { fish = 20, spins = 2, baitSpeed = 0.02 },
		total20 = { fish = 25, crates = { classic_crate = 1 }, baitSpeed = 0.03 },
		total25 = { fish = 30, crates = { classic_golden_crate = 1 }, baitSpeed = 0.03 },
		total30 = { fish = 40, crates = { highest = 1 }, baitSpeed = 0.03 },
		total35 = { fish = 50, spins = 3, baitSpeed = 0.04 },
		total40 = { fish = 60, crates = { classic_golden_crate = 1 }, baitSpeed = 0.04 },
		total45 = { fish = 75, spins = 3, baitSpeed = 0.05 },
		total50 = {
			fish = 150,
			crates = { classic_golden_crate = 2 },
			spins = 10,
			tag = "Cat Master",
			baitSpeed = 0.10,
		},
	},
	decor_alley = {
		decor5 = { fish = Config.DecorIndexHalfFish },
		decor10 = { bonus = Config.DecorIndexBonus },
	},
	decor_park = {
		decor5 = { fish = Config.DecorIndexHalfFish },
		decor10 = { bonus = Config.DecorIndexBonus },
	},
	decor_neighbourhood = {
		decor5 = { fish = Config.DecorIndexHalfFish },
		decor10 = { bonus = Config.DecorIndexBonus },
	},
	decor_woods = {
		decor5 = { fish = Config.DecorIndexHalfFish },
		decor10 = { bonus = Config.DecorIndexBonus },
	},
	decor_sewer = {
		decor5 = { fish = Config.DecorIndexHalfFish },
		decor10 = { bonus = Config.DecorIndexBonus },
	},
	decor_classic = {
		decor5 = { fish = Config.DecorIndexHalfFish },
		decor10 = { bonus = Config.DecorIndexBonus },
	},
	decor_rally = { -- F101: the Rally Crate's own page
		decor5 = { fish = Config.DecorIndexHalfFish },
		decor10 = { bonus = Config.DecorIndexBonus },
	},
	-- F99 (rainbow-coat.md section 4): the three luck steps add up to RainbowLuckMax (+100%)
	rainbow = {
		rainbow1 = { fish = 25, tag = "Rainbow Finder" },
		rainbow3 = { fish = 50, crates = { classic_golden_crate = 1 } },
		rainbow5 = { fish = 75, rainbowLuck = 0.2 },
		rainbow10 = { fish = 100, crates = { classic_golden_crate = 2 }, rainbowLuck = 0.3 },
		rainbow25 = {
			fish = 150,
			crates = { classic_golden_crate = 3 },
			tag = "Rainbow Master",
			rainbowLuck = 0.5,
		},
	},
} :: { [string]: { [string]: Types.IndexPrize } }
for _, prizes in Catalog.indexPrizes do
	for _, prize in prizes do
		if prize.lures ~= nil then
			table.freeze(prize.lures)
		end
		if prize.crates ~= nil then
			table.freeze(prize.crates)
		end
		table.freeze(prize)
	end
	table.freeze(prizes)
end
table.freeze(Catalog.indexPrizes)

-- Codes (F65, data-model section 11d), keyed by the lowercased code a player types at the Codes Cat. The prize uses
-- the Index prize shape and pays once per player. #1118 (the friend, 11-04, for the store page's codes line):
-- `release` is the release code, `playtest` and `playtest2` stay active for everyone, and `group` is open to members
-- of the community group only (requiresGroup, Config.GroupId; a non-member keeps it unused). `launch` switches on that
-- day. F64 adds the potions to playtest and group, and `playtest2` with two of each so
-- testers who redeemed playtest before potions existed still get them (data-model 11d). Rows can be added without
-- new code.
Catalog.codes = {
	playtest = {
		id = "playtest",
		active = true,
		prize = {
			coins = 5000,
			fish = 300,
			spins = 10,
			crates = { classic_crate = 3, alley_crate = 1, classic_golden_crate = 1 },
			lures = { tuna = 3, salmon = 2, caviar = 1 },
			potions = { tip_potion = 1, lucky_potion = 1, swift_potion = 1, steady_potion = 1 },
		},
	},
	playtest2 = {
		id = "playtest2",
		active = true,
		prize = {
			potions = { tip_potion = 2, lucky_potion = 2, swift_potion = 2, steady_potion = 2 },
		},
	},
	-- #1118: about ten minutes of the player's own income, golden fish and two Tip Potions; nothing random, and three
	-- pictures as a big prize may show (rewards rule 3), no shop food (rule 1)
	release = {
		id = "release",
		active = true,
		prize = { coins = 2000, coinSeconds = 600, fish = 60, potions = { tip_potion = 2 } },
	},
	launch = {
		id = "launch",
		active = false,
		prize = { coins = 1000, coinSeconds = 300, fish = 25 }, -- F94 (was also 2 spins and 3 Tuna)
	},
	group = {
		id = "group",
		active = true, -- #1118: on since the game's group (Config.GroupId) is set
		requiresGroup = true,
		-- F94 (was also 5 spins, 2 Caviar and a Tip Potion)
		prize = { coins = 2500, coinSeconds = 900, fish = 100, crates = { classic_crate = 1 } },
	},
} :: { [string]: Types.CodeDef }
for _, code in Catalog.codes do
	local prize = code.prize
	if prize.lures ~= nil then
		table.freeze(prize.lures)
	end
	if prize.crates ~= nil then
		table.freeze(prize.crates)
	end
	if prize.potions ~= nil then
		table.freeze(prize.potions)
	end
	table.freeze(prize)
	table.freeze(code)
end
table.freeze(Catalog.codes)

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
-- F101: the Rally Crate is never sold and has no golden twin (`sold` and `golden` false).
local CRATE_POOLS: { { area: string, name: string, sold: boolean?, golden: boolean? } } = {
	{ area = "alley", name = "Alley" },
	{ area = "park", name = "Park" },
	{ area = "neighbourhood", name = "Neighbourhood" },
	{ area = "woods", name = "Woods" },
	{ area = "sewer", name = "Sewer" },
	{ area = "classic", name = "Classic" },
	{ area = "rally", name = "Rally", sold = false, golden = false },
}

-- The Rescue Rally's crate pool (F101): open from Tier 1 like the Classic Crate, banked by the Rally's 100% step.
Catalog.RALLY_POOL = "rally"
-- The pieces in each pool (F53, golden-fish.md section 4): ten, two of each kind, 4 Common, 3 Rare and one each of
-- Epic, Legendary and Mythical, then since F80 (section 4b) a door set and a cat flap, one Common and one Rare, so
-- twelve with 5 Common and 4 Rare. A wallpaper, floor or paint is a colour and a material on the cafe's tagged shell
-- parts; furniture and decorations are models (CatCafe_Decor_<Name>) on decor spots; a door set is a model
-- (CatCafe_Door_<Name>, the name less " Door") in both doorways and a cat flap one (CatCafe_CatFlap_<Name>, less
-- " Flap") low in the back door. The F48 Index pieces are their zones' Epics and keep their ids, models and anchors
-- (F54: no Index prize hands out decor any more). Every piece is a DecorDef in Catalog.crateDecor.
type PieceRow = {
	id: string,
	name: string,
	kind: Types.DecorKind,
	rarity: Types.Rarity,
	color: Color3?,
	material: Enum.Material?,
	asset: string?, -- an F48 Index piece keeps its model; the rest are named after the piece
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
		{
			id = "index_alley",
			name = "Alley Mural Print",
			kind = "decoration",
			rarity = "Epic",
			asset = "CatCafe_Decor_MuralPrint", -- the F48 Index piece, on its own anchor
			description = "The Alleyway mural in a frame.",
		},
		{
			id = "alley_fire_escape_door",
			name = "Fire Escape Door",
			kind = "door",
			rarity = "Common",
			description = "A red steel door with rivets and a small wired window.",
		},
		{
			id = "alley_neon_paw_flap",
			name = "Neon Paw Flap",
			kind = "catflap",
			rarity = "Rare",
			description = "A dark flap with a neon paw outline that glows at night.",
		},
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
		{
			id = "index_park",
			name = "Park Bench",
			kind = "furniture",
			rarity = "Epic",
			asset = "CatCafe_Decor_ParkBench", -- the F48 Index piece, on its own anchor
			description = "A bench from the Park, for long afternoons.",
		},
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
		{
			id = "park_garden_gate_door",
			name = "Garden Gate Door",
			kind = "door",
			rarity = "Common",
			description = "A green plank door with a little window of leaves.",
		},
		{
			id = "park_birdhouse_flap",
			name = "Birdhouse Flap",
			kind = "catflap",
			rarity = "Rare",
			description = "The flap framed like a birdhouse, with a tiny roof.",
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
		{
			id = "index_neighbourhood",
			name = "Mailbox Planter",
			kind = "decoration",
			rarity = "Epic",
			asset = "CatCafe_Decor_MailboxPlanter", -- the F48 Index piece, on its own anchor
			description = "A mailbox full of flowers.",
		},
		{
			id = "neighbourhood_front_porch_door",
			name = "Front Porch Door",
			kind = "door",
			rarity = "Rare",
			description = "A white door with a fanlight window and a wreath.",
		},
		{
			id = "neighbourhood_mail_slot_flap",
			name = "Mail Slot Flap",
			kind = "catflap",
			rarity = "Common",
			description = "A brass flap like a letterbox.",
		},
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
		{
			id = "index_woods",
			name = "Mushroom Lamp",
			kind = "decoration",
			rarity = "Epic",
			asset = "CatCafe_Decor_MushroomLamp", -- the F48 Index piece, on its own anchor
			description = "A glowing toadstool from the Woods.",
		},
		{
			id = "woods_log_cabin_door",
			name = "Log Cabin Door",
			kind = "door",
			rarity = "Common",
			description = "Split logs with iron hinges.",
		},
		{
			id = "woods_tree_stump_flap",
			name = "Tree Stump Flap",
			kind = "catflap",
			rarity = "Rare",
			description = "The flap set in a carved stump ring with moss.",
		},
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
		{
			id = "index_sewer",
			name = "Pipe Fountain",
			kind = "decoration",
			rarity = "Epic",
			asset = "CatCafe_Decor_PipeFountain", -- the F48 Index piece, on its own anchor
			description = "A clean little fountain made of pipes.",
		},
		{
			id = "sewer_porthole_hatch_door",
			name = "Porthole Hatch Door",
			kind = "door",
			rarity = "Rare",
			description = "A round-windowed hatch with a wheel handle.",
		},
		{
			id = "sewer_pipe_ring_flap",
			name = "Pipe Ring Flap",
			kind = "catflap",
			rarity = "Common",
			description = "The flap in a bolted pipe ring.",
		},
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
		{
			id = "classic_paned_glass_door",
			name = "Paned Glass Door",
			kind = "door",
			rarity = "Common",
			description = "A cream door with glass panes and a brass knob.",
		},
		{
			id = "classic_bell_flap",
			name = "Bell Flap",
			kind = "catflap",
			rarity = "Rare",
			description = "A pastel flap with a tiny gold bell on top.",
		},
	},
	-- The Rally Crate (F101, rescue-rally.md section 3; Model-Agent #759 and #766): the Rescue Rally's own twelve, in
	-- the Rally's red, navy, blue and gold, at the Classic Crate's rarity odds. It only comes from the Rally.
	rally = {
		{
			id = "rally_pennant_wall",
			name = "Pennant Wall",
			kind = "wallpaper",
			rarity = "Common",
			color = Color3.fromRGB(217, 72, 59),
			material = Enum.Material.Fabric,
			description = "Red felt like a team pennant.",
		},
		{
			id = "rally_team_banner",
			name = "Team Banner",
			kind = "wallpaper",
			rarity = "Rare",
			color = Color3.fromRGB(47, 62, 92),
			material = Enum.Material.Fabric,
			description = "Deep navy banner cloth for the big game.",
		},
		{
			id = "rally_running_track",
			name = "Running Track",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(196, 84, 62),
			material = Enum.Material.Rubber,
			description = "Springy red track, made for zoomies.",
		},
		{
			id = "rally_gym_floor",
			name = "Gym Floor",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(214, 170, 110),
			material = Enum.Material.WoodPlanks,
			description = "Polished boards that squeak under paws.",
		},
		{
			id = "rally_team_stripes",
			name = "Team Stripes",
			kind = "paint",
			rarity = "Common",
			color = Color3.fromRGB(60, 125, 217),
			material = Enum.Material.SmoothPlastic,
			description = "Bright blue trim in the team colours.",
		},
		{
			id = "rally_trophy_gold",
			name = "Trophy Gold",
			kind = "paint",
			rarity = "Mythical",
			color = Color3.fromRGB(255, 201, 77),
			material = Enum.Material.Foil,
			description = "Shines like a first-place cup.",
		},
		{
			id = "rally_bleacher_bench",
			name = "Bleacher Bench",
			kind = "furniture",
			rarity = "Rare",
			description = "Tiered seats for the home crowd.",
		},
		{
			id = "rally_trophy_shelf",
			name = "Trophy Shelf",
			kind = "furniture",
			rarity = "Epic",
			description = "A shelf of bright cups and ribbons.",
		},
		{
			id = "rally_cheer_bunting",
			name = "Cheer Bunting",
			kind = "decoration",
			rarity = "Rare",
			description = "Red and blue flags strung up for the big day.",
		},
		{
			id = "rally_victory_podium",
			name = "Victory Podium",
			kind = "decoration",
			rarity = "Legendary",
			description = "First, second and third, with a cup that spins.",
		},
		{
			id = "rally_medal_door",
			name = "Medal Door",
			kind = "door",
			rarity = "Common",
			description = "A team door with a gold medal on it.",
		},
		{
			id = "rally_finish_line_flap",
			name = "Finish Line Flap",
			kind = "catflap",
			rarity = "Rare",
			description = "A checked flap for a winning dash.",
		},
	},
}

local KIND_CATEGORY: { [string]: string } = {
	wallpaper = "Wallpaper",
	floor = "Flooring",
	paint = "Paint",
	door = "Door",
	catflap = "Cat flap",
	furniture = "Furniture",
	decoration = "Decoration",
}

Catalog.crateDecor = {} :: { Types.DecorDef }
local poolPieces: { [string]: { string } } = {}
for _, pool in CRATE_POOLS do
	local ids: { string } = {}
	for _, row in CRATE_PIECES[pool.area] do
		local bonus = Config.CratePieceBonus[row.rarity]
		local effect = string.format("+%d%% money while in use", math.floor(bonus * 100 + 0.5))
		local styled = row.kind == "wallpaper" or row.kind == "floor" or row.kind == "paint"
		local plain = row.name:gsub("[^%w]", "")
		local asset = if row.kind == "door"
			then "CatCafe_Door_" .. (row.name:gsub(" Door$", ""):gsub("[^%w]", ""))
			elseif row.kind == "catflap" then "CatCafe_CatFlap_" .. (row.name
				:gsub(" Flap$", "")
				:gsub("[^%w]", ""))
			elseif styled then "CatCafe_Style_" .. plain
			else "CatCafe_Decor_" .. plain
		local def: Types.DecorDef = {
			id = row.id,
			name = row.name,
			cost = 0,
			category = KIND_CATEGORY[row.kind],
			effect = effect,
			description = row.description or "",
			bonus = bonus,
			asset = row.asset or asset,
			source = "crate",
			crate = pool.area,
			rarity = row.rarity,
			kind = row.kind,
			color = row.color,
			material = row.material,
		}
		Catalog.decorById[row.id] = def
		table.insert(Catalog.crateDecor, def)
		table.insert(ids, row.id)
	end
	poolPieces[pool.area] = ids
end
-- F97 section 2: the old coin pieces join the Classic Crate's rows at their rarity, so its Decor Index page has
-- sixteen pieces (decor10 still needs twelve). They are not in Catalog.crateDecor: no `kind` (their own anchors, no
-- decor spot) and their old bonuses, not CratePieceBonus.
for _, def in Catalog.decor do
	if def.crate ~= nil then
		table.insert(poolPieces[def.crate], def.id)
	end
end

Catalog.crates = {} :: { Types.CrateDef }
for _, pool in CRATE_POOLS do
	table.insert(Catalog.crates, {
		id = pool.area .. "_crate",
		name = pool.name .. " Crate",
		area = pool.area,
		golden = false,
		price = if pool.sold == false then nil else Config.CratePrice,
		odds = CRATE_ODDS,
		pieces = poolPieces[pool.area],
	})
	if pool.golden == false then
		continue
	end
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
Catalog.cratePools = {} :: { [string]: boolean } -- the zone ids, "classic" and "rally": crateLuck's keys
for _, def in Catalog.crates do
	Catalog.cratesById[def.id] = def
	Catalog.cratePools[def.area] = true
end

function Catalog.getCrate(id: string): Types.CrateDef?
	return Catalog.cratesById[id]
end

-- The Rescue Rally's steps (F101, rescue-rally.md section 3), in order: at a quarter of the goal 5 golden fish, at half
-- 10 and a Money Potion for the bag, at the full bar a Rally Crate for the Market and 15. The bar then empties for the
-- next lap.
Catalog.rallySteps = {
	{ share = 0.25, prize = { fish = 5 } },
	{ share = 0.5, prize = { fish = 10, potions = { tip_potion = 1 } } },
	{ share = 1, prize = { fish = 15, crates = { rally_crate = 1 } } },
} :: { Types.RallyStep }

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

-- F94 (rewards-and-shops.md section 3): the Fresh Catch shelf at the Golden Fish Market, sold by day for golden fish
-- in this order, each row's amount in a window rolled from Config.FreshCatchAmountWeights (shared/FreshCatch). A
-- row's id is its potion's id. No crate since #1051 (crate-prices.md section 4: the Market's 40 is the one price).
-- The Gold Rush Potion sends a ShopAlert. Earned only: golden fish are never sold for Robux.
Catalog.freshCatch = {
	{ id = "tip_potion", kind = "potion", potionId = "tip_potion", fish = 10 },
	{ id = "swift_potion", kind = "potion", potionId = "swift_potion", fish = 6 },
	{ id = "steady_potion", kind = "potion", potionId = "steady_potion", fish = 12 },
	{ id = "quick_bait_potion", kind = "potion", potionId = "quick_bait_potion", fish = 15 },
	{ id = "big_tip_potion", kind = "potion", potionId = "big_tip_potion", fish = 25 },
	{ id = "lucky_potion", kind = "potion", potionId = "lucky_potion", fish = 25 },
	{
		id = "gold_rush_potion",
		kind = "potion",
		potionId = "gold_rush_potion",
		fish = 30,
		alert = true,
	},
} :: { Types.FreshCatchRow }
Catalog.freshCatchById = {} :: { [string]: Types.FreshCatchRow }
for _, row in Catalog.freshCatch do
	Catalog.freshCatchById[row.id] = row
	table.freeze(row)
end
table.freeze(Catalog.freshCatch)

function Catalog.getFreshCatchRow(id: string): Types.FreshCatchRow?
	return Catalog.freshCatchById[id]
end

-- The Corner Shop (corner-shop.md section 2, #1052): sold for coins only, in this order, each row's amount in a window
-- rolled from Config.CornerShopAmountWeights (shared/CornerShop). `seconds` is the price in seconds of the day rate,
-- `atLeast` the floor. Nothing random, nothing that raises income, nothing for golden fish or Robux.
Catalog.cornerShop = {
	{
		id = "swift_potion",
		name = "Swift Potion",
		kind = "potion",
		potionId = "swift_potion",
		seconds = 120,
		atLeast = 200,
	},
	{
		id = "cat_snack",
		name = "Cat Snack",
		kind = "snack",
		xp = 1200,
		seconds = 300,
		atLeast = 500,
	},
	{
		id = "big_cat_snack",
		name = "Big Cat Snack",
		kind = "snack",
		xp = 6000,
		seconds = 1200,
		atLeast = 2500,
	},
	{
		id = "bubble_machine",
		name = "Bubble Machine",
		kind = "show",
		showId = "bubbles",
		showSeconds = 600,
		seconds = 600,
		atLeast = 1000,
	},
	{
		id = "cafe_fireworks",
		name = "Cafe Fireworks",
		kind = "show",
		showId = "fireworks",
		showSeconds = 20,
		seconds = 900,
		atLeast = 1500,
	},
} :: { Types.CornerShopRow }
Catalog.cornerShopById = {} :: { [string]: Types.CornerShopRow }
for _, row in Catalog.cornerShop do
	Catalog.cornerShopById[row.id] = row
	table.freeze(row)
end
table.freeze(Catalog.cornerShop)

function Catalog.getCornerShopRow(id: string): Types.CornerShopRow?
	return Catalog.cornerShopById[id]
end

-- #1182 step 1: the developer products whose contents are set (shop-and-pass-plan 2026-11-01; Potion Pack M and L,
-- the Starter Bundle and the Cafe Pass paid tier wait on Derek). Each sells under Config.ProductIds[id] once it is
-- made in Creator Hub; until then its id is 0 and it is never granted.
Catalog.products = {
	{
		id = "potion_pack_xs",
		name = "Potion Pack XS",
		prize = { potions = { big_tip_potion = 2 } },
	},
	{
		id = "potion_pack_s",
		name = "Potion Pack S",
		prize = { potions = { big_tip_potion = 3, swift_potion = 1, steady_potion = 1 } },
	},
} :: { Types.ProductDef }
Catalog.productsById = {} :: { [string]: Types.ProductDef }
for _, product in Catalog.products do
	Catalog.productsById[product.id] = product
	table.freeze(product.prize.potions)
	table.freeze(product.prize)
	table.freeze(product)
end
table.freeze(Catalog.products)

function Catalog.getProduct(id: string): Types.ProductDef?
	return Catalog.productsById[id]
end

-- F90 (cats-make-orders.md section 1): the menu, which grows with the cafe's tier. A customer picks evenly among the
-- items its cafe's tier has opened (menuFor); the rich customer orders the newest one (newestMenuItem) on the gold
-- plate. A drink (espresso machine or counter) takes 2 s to make, a bake (oven) 3 s. Client only and cosmetic.
Catalog.menu = {
	{
		id = "coffee",
		name = "Coffee",
		tier = 1,
		station = "espresso",
		makeSeconds = 2,
		model = "Coffee",
		glyph = "☕",
	},
	{
		id = "milk",
		name = "Milk",
		tier = 1,
		station = "counter",
		makeSeconds = 2,
		model = "Milk",
		glyph = "🥛",
	},
	{
		id = "cake_slice",
		name = "Cake Slice",
		tier = 1,
		station = "oven",
		makeSeconds = 3,
		model = "CakeSlice",
		glyph = "🍰",
	},
	{
		id = "paw_cookie",
		name = "Paw Cookie",
		tier = 1,
		station = "oven",
		makeSeconds = 3,
		model = "PawCookie",
		glyph = "🍪",
	},
	{
		id = "tea",
		name = "Tea",
		tier = 2,
		station = "espresso",
		makeSeconds = 2,
		model = "Tea",
		glyph = "🍵",
	},
	{
		id = "fish_biscuit",
		name = "Fish Biscuit",
		tier = 2,
		station = "oven",
		makeSeconds = 3,
		model = "FishBiscuit",
		glyph = "🐟",
	},
	{
		id = "kitty_cupcake",
		name = "Kitty Cupcake",
		tier = 3,
		station = "oven",
		makeSeconds = 3,
		model = "KittyCupcake",
		glyph = "🧁",
	},
	{
		id = "hot_cocoa",
		name = "Hot Cocoa",
		tier = 3,
		station = "espresso",
		makeSeconds = 2,
		model = "HotCocoa",
		glyph = "☕",
	},
	{
		id = "pancake_stack",
		name = "Pancake Stack",
		tier = 4,
		station = "oven",
		makeSeconds = 3,
		model = "PancakeStack",
		glyph = "🥞",
	},
	{
		id = "sundae",
		name = "Ice Cream Sundae",
		tier = 4,
		station = "counter",
		makeSeconds = 2,
		model = "Sundae",
		glyph = "🍨",
	},
	{
		id = "strawberry_roll",
		name = "Strawberry Roll",
		tier = 5,
		station = "oven",
		makeSeconds = 3,
		model = "StrawberryRoll",
		glyph = "🍓",
	},
	{
		id = "rainbow_cake",
		name = "Rainbow Cake",
		tier = 5,
		station = "oven",
		makeSeconds = 3,
		model = "RainbowCake",
		glyph = "🎂",
	},
} :: { Types.MenuItem }
Catalog.menuById = {} :: { [string]: Types.MenuItem }
for _, item in Catalog.menu do
	Catalog.menuById[item.id] = item
	table.freeze(item)
end
table.freeze(Catalog.menu)

function Catalog.getMenuItem(id: string): Types.MenuItem?
	return Catalog.menuById[id]
end

-- The items a cafe of `tier` serves, in menu order (Tier 1's four at least).
function Catalog.menuFor(tier: number): { Types.MenuItem }
	local open: { Types.MenuItem } = {}
	for _, item in Catalog.menu do
		if item.tier <= math.max(1, tier) then
			table.insert(open, item)
		end
	end
	return open
end

-- The newest item a cafe of `tier` has opened: the rich customer's order.
function Catalog.newestMenuItem(tier: number): Types.MenuItem
	local open = Catalog.menuFor(tier)
	return open[#open]
end

-- The asset of a menu item on its plate, and the plates and carriers around it (Model-Agent's F90 sheet).
function Catalog.menuModelName(item: Types.MenuItem): string
	return "CatCafe_Menu_" .. item.model
end

Catalog.menuGoldPlate = "CatCafe_Menu_GoldPlate"
Catalog.menuTray = "CatCafe_Menu_Tray"
Catalog.menuCoinBag = "CatCafe_Menu_CoinBag"
Catalog.ovenModel = "CatCafe_Cafe_Oven"

-- The camp extras (F100, camp-extras.md section 2), one at each camp from the Park on, in tier order. Model-Agent's
-- models (#750) stand at Layout.campExtras; shared/CampExtras holds their rules.
Catalog.campExtras = {
	{
		id = "picnic",
		area = "park",
		name = "Picnic Basket",
		model = "CatCafe_Camp_Park_PicnicBasket",
		kind = "collect",
	},
	{
		id = "yardSale",
		area = "neighbourhood",
		name = "Yard Sale",
		model = "CatCafe_Camp_Neighbourhood_YardSale",
		kind = "shop",
	},
	{
		id = "pond",
		area = "woods",
		name = "Fish Pond",
		model = "CatCafe_Camp_Woods_FishPond",
		kind = "collect",
	},
	{
		id = "lostFound",
		area = "sewer",
		name = "Lost and Found",
		model = "CatCafe_Camp_Sewer_LostFound",
		kind = "collect",
	},
} :: { Types.CampExtraDef }

Catalog.campExtrasById = {} :: { [string]: Types.CampExtraDef }
for _, def in Catalog.campExtras do
	Catalog.campExtrasById[def.id] = def
end

function Catalog.getCampExtra(id: string): Types.CampExtraDef?
	return Catalog.campExtrasById[id]
end

-- The front lawn (F91, front-lawn.md section 2): pieces for the six lawn spots (shared/Lawn.SPOTS) and the path and
-- fence styles, bought with coins in the Decor screen's Front lawn tab at the tier that sells them. No tip bonus: the
-- lawn is looks only. Prices are section 2's, times 4 at Tier 3, 8 at Tier 4 and 16 at Tier 5 (economy-ladder.md
-- section 4, which wins; its example rounds the Golden Paw Statue's 48,000,000 to 50,000,000, as the Royal Bowl's).
-- Models are Model-Agent's (#673, style guide section 13).
Catalog.lawn = {
	{
		id = "tulip_bed",
		name = "Tulip Bed",
		spot = "small",
		tier = 1,
		price = 500,
		model = "CatCafe_Lawn_TulipBed",
	},
	{
		id = "sandwich_board",
		name = "Sandwich Board",
		spot = "small",
		tier = 1,
		price = 500,
		model = "CatCafe_Lawn_SandwichBoard",
	},
	{
		id = "potted_cat_topiary",
		name = "Potted Cat Topiary",
		spot = "small",
		tier = 1,
		price = 1000,
		model = "CatCafe_Lawn_PottedCatTopiary",
	},
	{
		id = "mailbox",
		name = "Mailbox",
		spot = "small",
		tier = 1,
		price = 1000,
		model = "CatCafe_Lawn_Mailbox",
	},
	{
		id = "lamp_post",
		name = "Lamp Post",
		spot = "small",
		tier = 2,
		price = 3000,
		model = "CatCafe_Lawn_LampPost",
	},
	{
		id = "bird_bath",
		name = "Bird Bath",
		spot = "small",
		tier = 2,
		price = 3000,
		model = "CatCafe_Lawn_BirdBath",
	},
	{
		id = "garden_gnome_cat",
		name = "Garden Gnome Cat",
		spot = "small",
		tier = 2,
		price = 5000,
		model = "CatCafe_Lawn_GardenGnomeCat",
	},
	{
		id = "bicycle_with_basket",
		name = "Bicycle with Basket",
		spot = "big",
		tier = 2,
		price = 8000,
		model = "CatCafe_Lawn_BicycleWithBasket",
	},
	{
		id = "garden_bench",
		name = "Garden Bench",
		spot = "big",
		tier = 2,
		price = 8000,
		model = "CatCafe_Lawn_GardenBench",
	},
	{
		id = "umbrella_table",
		name = "Umbrella Table",
		spot = "big",
		tier = 3,
		price = 100000,
		model = "CatCafe_Lawn_UmbrellaTable",
	},
	{
		id = "little_fountain",
		name = "Little Fountain",
		spot = "big",
		tier = 3,
		price = 160000,
		model = "CatCafe_Lawn_LittleFountain",
	},
	{
		id = "fairy_light_arch",
		name = "Fairy Light Arch",
		spot = "big",
		tier = 4,
		price = 1200000,
		model = "CatCafe_Lawn_FairyLightArch",
	},
	{
		id = "flower_cart",
		name = "Flower Cart",
		spot = "big",
		tier = 4,
		price = 1600000,
		model = "CatCafe_Lawn_FlowerCart",
	},
	{
		id = "balloon_bunch",
		name = "Balloon Bunch",
		spot = "small",
		tier = 4,
		price = 800000,
		model = "CatCafe_Lawn_BalloonBunch",
	},
	{
		id = "cat_tree_sign",
		name = "Cat Tree Sign",
		spot = "big",
		tier = 5,
		price = 16000000,
		model = "CatCafe_Lawn_CatTreeSign",
	},
	{
		id = "golden_paw_statue",
		name = "Golden Paw Statue",
		spot = "big",
		tier = 5,
		price = 50000000,
		model = "CatCafe_Lawn_GoldenPawStatue",
	},
} :: { Types.LawnPieceDef }

-- One path and one fence at a time. Grey Slabs is free and laid at every cafe; a cafe starts with no fence.
Catalog.lawnStyles = {
	{
		id = "grey_slabs",
		name = "Grey Slabs",
		kind = "path",
		tier = 1,
		price = 0,
		model = "CatCafe_Lawn_Path_GreySlabs",
	},
	{
		id = "red_brick",
		name = "Red Brick",
		kind = "path",
		tier = 1,
		price = 2000,
		model = "CatCafe_Lawn_Path_RedBrick",
	},
	{
		id = "stepping_stones",
		name = "Stepping Stones",
		kind = "path",
		tier = 2,
		price = 10000,
		model = "CatCafe_Lawn_Path_SteppingStones",
	},
	{
		id = "paw_print_path",
		name = "Paw Print Path",
		kind = "path",
		tier = 3,
		price = 200000,
		model = "CatCafe_Lawn_Path_PawPrintPath",
	},
	{
		id = "white_picket",
		name = "White Picket",
		kind = "fence",
		tier = 1,
		price = 2000,
		model = "CatCafe_Lawn_Fence_WhitePicket",
	},
	{
		id = "low_hedge",
		name = "Low Hedge",
		kind = "fence",
		tier = 2,
		price = 10000,
		model = "CatCafe_Lawn_Fence_LowHedge",
	},
	{
		id = "iron_railing",
		name = "Iron Railing",
		kind = "fence",
		tier = 3,
		price = 200000,
		model = "CatCafe_Lawn_Fence_IronRailing",
	},
	{
		id = "flower_box_fence",
		name = "Flower Box Fence",
		kind = "fence",
		tier = 4,
		price = 1600000,
		model = "CatCafe_Lawn_Fence_FlowerBoxFence",
	},
} :: { Types.LawnStyleDef }

Catalog.lawnById = {} :: { [string]: Types.LawnPieceDef }
for _, def in Catalog.lawn do
	Catalog.lawnById[def.id] = def
end
Catalog.lawnStylesById = {} :: { [string]: Types.LawnStyleDef }
for _, def in Catalog.lawnStyles do
	Catalog.lawnStylesById[def.id] = def
end

function Catalog.getLawn(id: string): Types.LawnPieceDef?
	return Catalog.lawnById[id]
end

function Catalog.getLawnStyle(id: string): Types.LawnStyleDef?
	return Catalog.lawnStylesById[id]
end

return Catalog
