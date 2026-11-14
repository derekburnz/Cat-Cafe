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
		catchWindow = 1.15, -- #1884 re-fit for the trust bar (catch-rework.md 7b)
		trustNeed = 11, -- #2005: TrustStart + TrustPerfect x circles
		moods = { Sleepy = 55, Curious = 45, Skittish = 0 }, -- #1884 (catch-rework.md 7a)
		doubleRings = false, -- #1884 (7c)
		pawRings = false,
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
		catchWindow = 1.032, -- #1884 re-fit for the trust bar (catch-rework.md 7b)
		trustNeed = 14, -- #2005
		moods = { Sleepy = 55, Curious = 45, Skittish = 0 }, -- #1884 (catch-rework.md 7a)
		doubleRings = false, -- #1884 (7c)
		pawRings = false,
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
		catchWindow = 0.908, -- #1884 re-fit for the trust bar (catch-rework.md 7b)
		trustNeed = 17, -- #2005
		moods = { Sleepy = 30, Curious = 35, Skittish = 35 }, -- #1884 (catch-rework.md 7a)
		doubleRings = true, -- #1884 (7c)
		pawRings = false,
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
		catchWindow = 0.742, -- #1884 re-fit for the trust bar and paw rings (catch-rework.md 7b, 7c)
		trustNeed = 20, -- #2005
		moods = { Sleepy = 20, Curious = 30, Skittish = 50 }, -- #1884 (catch-rework.md 7a)
		doubleRings = true, -- #1884 (7c)
		pawRings = true,
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
		-- #2005 (Derek2: "mythic feels impossible"): 0.636 to 0.68 with the bigger Perfect and Good, a Basic Net
		-- Mythical at 50 ms from 19% to about 36% a try (the other rarities keep their windows and gain a little)
		catchWindow = 0.68,
		trustNeed = 23, -- #2005
		moods = { Sleepy = 20, Curious = 30, Skittish = 50 }, -- #1884 (catch-rework.md 7a)
		doubleRings = true, -- #1884 (7c)
		pawRings = true,
		fleeStuds = 64,
		rescueHits = 7,
		sellValue = 12000,
		firstCatchReward = 30000,
		color = "#FF5E7E",
	},
	-- #3470 (Derek 2026-11-12, from a player's idea: "a secret tier of pet that is out of index can spawn on any area
	-- and its super rare like 100x rarer then mythic but its better then all current mythics"): four times a
	-- Mythical's income, at the owner's best open area (CatStats.areaMultiplier), and a harder catch in the same
	-- game. Design-Agent's numbers on #3470.
	Secret = {
		incomePerSecond = 300,
		circles = 8,
		shrinkSeconds = 0.50,
		catchWindow = 0.64,
		trustNeed = 26,
		moods = { Sleepy = 0, Curious = 38, Skittish = 62 }, -- #3545: never Sleepy, so it always roams
		doubleRings = true,
		pawRings = true,
		fleeStuds = 72,
		rescueHits = 8,
		sellValue = 60000,
		firstCatchReward = 150000,
		color = "#16161D", -- tags and cards only (white stroke); effects use a pale starlight (Effects/Presets)
	},
} :: { [string]: Types.RarityDef }

-- The five rarities an odds table rolls (areas, foods, crates, decor), commonest first. #3470: Secret is not in it
-- on purpose, so every odds loop stays as it was; it has a rank (6) for "this rarity or better" checks and sorts.
local rarityOrder: { Types.Rarity } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
Catalog.rarityOrder = rarityOrder
Catalog.rarityRank = {
	Common = 1,
	Rare = 2,
	Epic = 3,
	Legendary = 4,
	Mythical = 5,
	Secret = 6,
} :: { [string]: number }
-- #3470: every cat rarity, commonest first (rarityOrder and Secret)
Catalog.catRarityOrder =
	{ "Common", "Rare", "Epic", "Legendary", "Mythical", "Secret" } :: { Types.Rarity }
Catalog.SECRET = "Secret" :: Types.Rarity
-- #3470: the share of rolled Mythicals that turn Secret (wild strays, bait and rescues), so a source's Secret chance
-- is its Mythical chance over 100 and no other rarity moves. Only while the `secretCats` switch is on.
Catalog.secretPerMythical = 0.01

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
	desert = 243, -- #2651 (tier6-7-areas.md section 1): Tier 6
	ruins = 729, -- Tier 7
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

-- #3470: a Secret cat. It belongs to no area (`area = "secret"`), so no wave, bait or rescue table and no Index page
-- or count lists it; Catching.secret picks one in place of a rolled Mythical. Its rate here is the rarity's own, and
-- an owner's best open area multiplies it (CatStats.areaMultiplier). #4221: `home` is the one area whose rolled
-- Mythicals it can take the place of (its `secretArea`); its `area` still says "secret".
local function secret(def: Types.CatDef, home: Types.Area): Types.CatDef
	def.area = "secret"
	def.secretArea = home
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
	-- #2651 (tier6-7-areas.md section 6): the Desert's and the Ruins' ten each, Model-Agent's CatCafe_Cat_<Name> with
	-- _Sit, _Work and gold twins (#2611, #2640)
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
		"Bright as a beetle, twice as busy."
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
	-- #1447 (store-skus.md, #1191): the shop-only cats on game passes, given by ShopCatService (shared/ShopCats). Each
	-- earns like its rarity from the owner's newest area, so its rate climbs with every area opened. Models
	-- CatCafe_Cat_DuchessMarzipan and CatCafe_Cat_KingCroissant (with _Sit and _Work); never gold.
	exclusive(
		cat(
			"duchess_marzipan",
			"Duchess Marzipan",
			"Legendary",
			"alley",
			"greeter",
			"solid", -- lilac silver, a pearl tiara and a velvet cape
			{ 203, 196, 219 },
			"The Royal Cat. Greets every guest with a slow, gracious blink."
		),
		"shop"
	),
	exclusive(
		cat(
			"king_croissant",
			"King Croissant",
			"Mythical",
			"alley",
			"entertainer",
			"stripes", -- golden croissant fur with flaky dark stripes, a crown and a red cape
			{ 231, 169, 78 },
			"The King Cat. Holds court from his velvet cushion, crown and all."
		),
		"shop"
	),
	-- #1625 (store-skus.md, #1191, built in #1244): the Starter Bundle's cat, given once with its receipt by
	-- ProductService; earns like an Epic from the owner's newest area. Model CatCafe_Cat_Sprinkles (with _Sit and _Work).
	exclusive(
		cat(
			"sprinkles",
			"Sprinkles",
			"Epic",
			"alley",
			"barista",
			"patches", -- custard with caramel patches, a sprinkle apron and a tilted pastry chef hat
			{ 248, 228, 190 },
			"The Starter Bundle's baker. Tosses sprinkles over every table that pays."
		),
		"shop"
	),
	-- #1626 (Design #1630, Model #1637): the Cafe Pass season cat, on the paid track at level 30 (CafePassService).
	-- Earns like a Legendary from the owner's newest area. Model CatCafe_Cat_MapleMuffin (with _Sit and _Work), in
	-- its Leaf Beret; until the art lands it shows as the placeholder body. Never traded, gifted or gold.
	exclusive(
		cat(
			"maple_muffin",
			"Maple Muffin",
			"Legendary",
			"alley",
			"waiter",
			"stripes", -- a ginger tabby with cream paws and a knitted maple-leaf beret
			{ 214, 128, 62 },
			"Season 1's cat. Brings every order with a maple leaf on top."
		),
		"pass"
	),
	-- #3470: the first three Secret cats (Design-Agent's names and looks; Model-Agent's CatCafe_Cat_Nebula, _Glitch
	-- and _CafeGhost, the placeholder body until they land). The `alley` here only feeds the helper: `secret` takes
	-- the area away. #4221: one Secret per area (Design-Agent's secret-per-area spec): Cafe Ghost is the Alleyway's,
	-- Glitch the Neighbourhood's and Nebula the Snowy Mountain's.
	secret(
		cat(
			"nebula",
			"Nebula",
			"Secret",
			"alley",
			"entertainer",
			"solid", -- a deep space coat with slow drifting stars and a faint purple glow
			{ 38, 26, 84 },
			"Came down with the night sky and stayed for the milk."
		),
		"snowy"
	),
	secret(
		cat(
			"glitch",
			"Glitch",
			"Secret",
			"alley",
			"barista",
			"patches", -- teal and magenta, shimmering in little squares
			{ 40, 200, 190 },
			"Nobody is sure it is meant to be here."
		),
		"neighbourhood"
	),
	secret(
		cat(
			"cafe_ghost",
			"Cafe Ghost",
			"Secret",
			"alley",
			"greeter",
			"solid", -- pale and see-through, with a tiny chef hat
			{ 232, 238, 248 },
			"Has worked here longer than the cafe has."
		),
		"alley"
	),
} :: { Types.CatDef }

-- #3470: the Secret cats, in catalog order
Catalog.secretCats = {} :: { Types.CatDef }
for _, def in Catalog.cats do
	if def.rarity == "Secret" then
		table.insert(Catalog.secretCats, def)
	end
end

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
	-- #2651 (tier6-7-areas.md section 1, Design-Agent): Tier 6 and 7 add two each, and the pass still adds two at every
	-- tier. The first two are #1624's waiters, pass-only while Tier 5 was the top, so a Tier 5 save's extra slots keep
	-- the stations they had; Tier 7's are two of Model-Agent's new stations, and the other two are the pass's now.
	{ id = "waiter_4", spotType = "waiter", tier = 6 },
	{ id = "waiter_5", spotType = "waiter", tier = 6 },
	{ id = "barista_4", spotType = "barista", tier = 7 },
	{ id = "greeter_3", spotType = "greeter", tier = 7 },
} :: { Types.SpotDef }

-- #1624 (economy-ladder.md section 6, section 6a): two role slots only extra slots reach, for a top-tier cafe with
-- Grand Cafe and the Extra Slot pass; below the top tier the extra slots open the next tier's spots early instead.
-- Kept apart from the tier slots so the Staff list shows them only once the client knows about extra slots. Since
-- #2651 they are Model-Agent's two newest stations; waiter_4 and waiter_5 became Tier 6's.
Catalog.passSpots = {
	{ id = "entertainer_3", spotType = "entertainer", tier = 8, passOnly = true }, -- #2651: was waiter_4 and waiter_5
	{ id = "waiter_6", spotType = "waiter", tier = 8, passOnly = true },
} :: { Types.SpotDef }

-- Every role slot in opening order: the tier slots, then the pass-only ones.
Catalog.allSpots = table.clone(Catalog.spots)
for _, def in Catalog.passSpots do
	table.insert(Catalog.allSpots, def)
end

Catalog.spotsById = {} :: { [string]: Types.SpotDef }
for _, def in Catalog.allSpots do
	Catalog.spotsById[def.id] = def
end

function Catalog.getSpot(id: string): Types.SpotDef?
	return Catalog.spotsById[id]
end

-- #1624: how many role slots are open at `tier` with `extra` extra slots (Economy.extraSlots): the tier's own (every
-- spot of that tier or below) plus the extras, at most every spot there is. Catalog.allSpots is in opening order, so
-- the open ones are its first `count`, and an extra slot opens the next tier's spot early.
function Catalog.openSlotCount(tier: number, extra: number): number
	local count = 0
	for _, spot in Catalog.allSpots do
		if spot.tier <= tier then
			count += 1
		end
	end
	return math.min(count + math.max(0, math.floor(extra)), #Catalog.allSpots)
end

-- Whether role slot `spotId` is open at `tier` with `extra` extra slots. The server asks through Economy.spotIsOpen;
-- the client's slot lists ask with PlayerState.tier and PlayerState.extraSlots.
function Catalog.slotIsOpen(spotId: string, tier: number, extra: number): boolean
	local open = Catalog.openSlotCount(tier, extra)
	for index, spot in Catalog.allSpots do
		if spot.id == spotId then
			return index <= open
		end
	end
	return false
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
		cost = 1500, -- #4188 (Derek 2026-11-14: "build the cheaper tier 2 we need to get them into the next area's asap"; Pace's focused player holds about 1,660 at 150 s of play, 30 s after the tutorial's bait cat at about 120 s): 7,500 before; #4098 (Derek 2026-11-14: "Tier 2 is another huge fall off"; Design-Agent's Pace runs: the focused player 9.7 to 5.4 min, the buy-everything player 10.3 to 8.3, below 7,500 barely helps): 13,500 before; #3195 (Design-Agent: nights 45 s give more daytime; holds Tier 2 near 8.5 min): 12,000 before; #2915 (Design-Agent: Tier 2 at a 9 to 12 min median; Pace's 4 catches a day had coins at 14.8 min against the 5th cat at 5.5, so the coins were the gate): 22,000 before; #2683 (Derek2 2026-11-09: Tiers 2 to 5 "significantly easier"): 30,000 before; #1499 (economy-ladder 3 v3.1, dearer bait): 28,000 for #1452, 13,500 for #1162, 10,000 before
		distinctCats = 3, -- #4188: the tutorial cat, the second cat and the bait cat (always a new kind); 4 for #4098, 5 before
		slots = 4,
		multiplier = 1.25,
		area = "park",
		-- #1896 (first-hour.md 4): Tables 5, Espresso 4, Lucky Cat 3; #2121 (4d): Bait Bowl 3 too
		-- #3204 (Derek2 2026-11-11: "move some of the upgrades around and net upgrades later on in tiers"): each tier opens
		-- a handful; Net 2 at Tier 3 and Net 3 at Tier 5 (were 2 and 3). Caps gate buying only: a level owned above
		-- one is kept.
		caps = { tables = 4, espresso = 3, net = 1, lure_bowl = 2, lucky_cat = 2 },
	},
	{
		tier = 3,
		name = "Busy Cafe",
		cost = 150000, -- #4189 (Derek 2026-11-14: "we need to get them into the next area's asap", "lower for right now by a decent bit", then "its fine to make less hours of play": Tier 3 near 12 min): 300,000 at first, 520,000 before; #3195 + #3204 (Design-Agent: nights 45 s and the Tier 2 caps brought Tier 3 to 27.7 min; 520,000 gives about 30, and 560,000 only 1.2 min more): 420,000 before; #2895 (Derek2 2026-11-10: "lower the 3-6 tier costs", 30% off): 600,000 before; #2683: 1,240,000 before; #2559 (Derek2 2026-11-09: "increase tier 2 to tier 3 by 35%"): 920,000 before; #2230 (Derek2 2026-11-07: "slightly" harder): 800,000 before; #1896 re-fit with Catch v3 (#1884): 900,000 before; 700,000 for #1452 (economy-ladder 3 v3); F95 v2 500,000 (350,000; 80,000)
		distinctCats = 8, -- #4189: 10 before; #3111 (Derek2 2026-11-10: "lower the different cats requirement a little bit between 3-7"): 11 before; #2683: 13 before; #2230: 12 before
		needsRarity = "Epic",
		needsRarityCount = 1,
		slots = 6,
		multiplier = 1.50,
		area = "neighbourhood",
		caps = { tables = 6, espresso = 4, net = 2, lure_bowl = 3, lucky_cat = 3 }, -- #3204
	},
	{
		tier = 4,
		name = "Famous Cafe",
		cost = 4000000, -- #4189: 8,000,000 at first, 16,800,000 before; #2895 (30% off): 24,000,000 before; #2683: 48,000,000 before; #2559 (Derek2 2026-11-09: "lower the Tier 3 to tier 4 jump by about 70%"): 160,000,000 before; #2496 (Derek2: "more money"; Design 160M, Pace Tier 4 5 h 15): 90,000,000 before; #2230 ("a lot" harder): 60,000,000 before; #1452 (economy-ladder 3 v3); F95 v2 40,000,000 (was 27,000,000; 700,000 before F95)
		distinctCats = 17, -- #4189 (the 4x Money 2 hour floor is dropped): 22 before; #3111: stays 22 (21 or 20 puts Tier 5 under Pace's 2 hour floor for 4x Money); #2683: 25 before; #2230: 20 before
		needsRarity = "Mythical", -- #2496 (Derek2: "requires at least 1 mythic"): Legendary before
		needsRarityCount = 1,
		slots = 8,
		multiplier = 1.75,
		area = "woods",
		caps = { tables = 6, espresso = 5, net = 2, lure_bowl = 4, lucky_cat = 4 }, -- #3204
	},
	{
		tier = 5,
		name = "Grand Cafe",
		cost = 90000000, -- #4189: 180,000,000 at first, 390,000,000 before; #3360 (money bags wait 3 min and stack, so fewer are missed; keeps the 4x Money floor of 2 h): 370,000,000 before; #3195 (Design-Agent: keeps the 4x Money Tier 5 floor of 2 h with 45 s nights): 350,000,000 before; #2895 (Derek2 2026-11-10: "do 50% 30% 10% cheaper for T5/6/7", 50% off): 700,000,000 before; #2683: 2,300,000,000 before; #2230 ("slightly" harder): 2,000,000,000 before; #1452 (economy-ladder 3 v3); F95 v2 1,200,000,000 (was 800,000,000; 5,000,000 before F95)
		distinctCats = 20, -- #4189: 26 before; #3111: 28 before; #2683: 33 before; #2230: 30 before
		needsRarity = "Legendary",
		needsRarityCount = 2,
		slots = 10,
		multiplier = 2.00,
		area = "sewer",
		caps = { tables = 6, espresso = 5, net = 3, lure_bowl = 5, lucky_cat = 5 },
	},
	-- #2651 (tier6-7-areas.md sections 1, 7b and 9): Tier 6 and 7 at QA-Planner's Pace fit (Tier 6 about 6.4 h after
	-- Tier 5, Tier 7 about 10 h after Tier 6; the drafts 70B and 1.8T took 29 h and more than 40 h); the caps raise
	-- the Espresso machine and the Lucky Cat one level a tier
	{
		tier = 6,
		name = "Sunstone Cafe",
		cost = 1250000000, -- #4189: 2,500,000,000 at first, 5,600,000,000 before; #2895 (30% off): 8,000,000,000 before; #2683: 9,000,000,000 before, so the gap after the earlier Tier 5 stays 5 to 7 h
		distinctCats = 30, -- #4189: 38 before; #3111: 42 before
		needsRarity = "Mythical",
		needsRarityCount = 2,
		slots = 12,
		multiplier = 2.25,
		area = "desert",
		caps = { tables = 6, espresso = 6, net = 3, lure_bowl = 5, lucky_cat = 6 },
	},
	{
		tier = 7,
		name = "Wonder Cafe",
		cost = 12500000000, -- #4189: 25,000,000,000 at first, 54,000,000,000 before; #2895 (10% off): 60,000,000,000 before
		distinctCats = 38, -- #4189: 47 before; #3111: 52 before
		needsRarity = "Mythical",
		needsRarityCount = 3,
		slots = 14,
		multiplier = 2.50,
		area = "ruins",
		caps = { tables = 6, espresso = 7, net = 3, lure_bowl = 5, lucky_cat = 7 },
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
		-- F95: levels 5 and 6 four times (section 4); #1896 (first-hour.md 4): level 5 170,000 (was 200,000), now Tier 2
		costs = { 150, 600, 3000, 10000, 170000, 600000 },
		startLevel = 0,
	},
	{
		id = "espresso",
		name = "Espresso machine",
		description = "Better coffee, more money from every cat",
		maxLevel = 7,
		-- F95: level 4 four times, 5 (Tier 4) 7.5 times; #1896 (first-hour.md 4): level 4 700,000 (was 400,000), now Tier 2
		-- #2651 (tier6-7-areas.md 7b): levels 6 and 7 at Tier 6 and 7, scaled with the tiers' Pace fit
		costs = { 0, 2000, 15000, 550000, 6000000, 200000000, 1300000000 }, -- #1896 re-fit with Catch v3: Espresso 4 700,000 before
		startLevel = 1,
	},
	{
		id = "net",
		name = "Net",
		description = "A better net: higher odds on every swing",
		maxLevel = 3,
		-- F95: the Master Net four times; #3204: Net 2 at Tier 3 for 200,000 and Net 3 at Tier 5 for 60,000,000 (were
		-- 25,000 and 800,000, which would be pocket change that late)
		costs = { 2500, 200000, 60000000 },
		startLevel = 0,
	},
	{
		id = "lure_bowl", -- shown as Bait bowl; ids keep the lure_ prefix (data-model section 6)
		name = "Bait bowl",
		-- F82 (v0.13.15): five levels, each tier opening one, the names in Bait.bowlName
		description = "A bowl on your back step. Each level brings bait cats sooner and rarer",
		maxLevel = 5,
		-- F95: Fancy, Deluxe and Royal Bowls; #2121 (first-hour.md 4d): level 3 opens at Tier 2, fitted into
		-- the 31 to 42 minute gap at 150,000 (240,000 at Tier 3 before; 70,000 landed at minute 18, inside a busy stretch)
		costs = { 600, 6000, 150000, 4000000, 50000000 },
		startLevel = 0,
	},
	{
		id = "lucky_cat", -- F88 (luck-and-rare-moments.md 1a): the statue by the front door, shared/Luck
		name = "Lucky Cat",
		description = "A beckoning cat by your front door. Each level adds +10% Luck: rarer bait cats and crate finds",
		maxLevel = 7,
		-- level n needs Tier n, but level 3 comes at Tier 2 (#1896 follow-up, a buy inside the Tier 3 save, fitted to
		-- minute 32 at 300,000; 600,000 before); levels 4 and 5 at economy-ladder.md section 4's prices; #2651 (tier6-7-
		-- areas.md 7b): 6 and 7 at Tier 6 and 7, scaled with the tiers' Pace fit
		costs = { 2000, 20000, 300000, 8000000, 80000000, 250000000, 1700000000 },
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
-- found only in the Classic Crate, at their rarity, and keep their own anchors (no decor spot); players who bought them
-- keep them. #2053 (Derek2: the boost "doesn't match rarity"): the bonus rises with the rarity, Common 5%, Rare 8% and
-- Epic 12% (the Rare and the Epic were both 10%), so the set of four still adds up to +30%. The crate pieces (F53), the F48 Index pieces among them, are in
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
		effect = "+8% money",
		description = "Seen from the far end of the street.",
		bonus = 0.08,
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
		effect = "+12% money, cats stare at it",
		description = "The fish are fine. Probably.",
		bonus = 0.12,
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

-- Sections 8 and 8b. Odds are shown before purchase. Shop foods are bought at the Corner Shop (#1281, its "bait" rows;
-- BuyLure refuses since); dealer foods only from the night dealer's stock.
Catalog.lures = {
	{
		id = "kibble",
		name = "Kibble",
		cost = 100, -- F97, kept by #1389 (Economy.spec step 7); Economy.foodPrice grows it by tier
		sortOrder = 1,
		attracts = "Common",
		rarity = "Common",
		source = "shop",
		description = "Cheap and crunchy. Brings the regulars.",
		odds = { Common = 70.375, Rare = 25.375, Epic = 3.4, Legendary = 0.765, Mythical = 0.085 }, -- #2239: was 70/25/4/0.9/0.1
		asset = "CatCafe_Item_Kibble",
	},
	{
		id = "tuna",
		name = "Tuna",
		cost = 5000, -- #1389 (x10 on F97's 500); Economy.foodPrice grows it by tier
		sortOrder = 2,
		attracts = "Rare",
		rarity = "Rare",
		source = "shop",
		description = "The good stuff. Rare cats come running.",
		odds = { Common = 41.125, Rare = 46.125, Epic = 10.2, Legendary = 2.21, Mythical = 0.34 }, -- #2239: was 40/45/12/2.6/0.4
		asset = "CatCafe_Item_TunaCan",
	},
	{
		id = "salmon",
		name = "Salmon",
		cost = 50000, -- #1389 (x20 on F97's 2,500); Economy.foodPrice grows it by tier
		sortOrder = 4,
		attracts = "Epic",
		rarity = "Epic",
		source = "shop",
		description = "Nobody can resist it, not even the Ninja Cat.",
		odds = { Common = 18, Rare = 48, Epic = 25.5, Legendary = 7.225, Mythical = 1.275 }, -- #2239: was 15/45/30/8.5/1.5
		asset = "CatCafe_Item_Salmon",
	},
	{
		id = "sardines",
		name = "Moonlit Sardines",
		cost = 80000, -- #1389 (x20 on F97's 4,000); Economy.foodPrice grows it by tier
		sortOrder = 3,
		attracts = "Rare",
		rarity = "Rare",
		source = "dealer",
		description = "Silvery and still glowing a little.",
		odds = { Common = 31.875, Rare = 46.875, Epic = 17, Legendary = 3.825, Mythical = 0.425 }, -- #2239: was 30/45/20/4.5/0.5
		asset = "CatCafe_Item_Sardines",
	},
	{
		id = "caviar",
		name = "Caviar",
		cost = 600000, -- #1389 (x40 on F97's 15,000); Economy.foodPrice grows it by tier
		sortOrder = 5,
		attracts = "Epic",
		rarity = "Epic",
		source = "dealer",
		description = "Tiny, glossy and very fancy.",
		odds = { Common = 16.55, Rare = 34, Epic = 35, Legendary = 11.9, Mythical = 2.55 }, -- #2239: was 10/35/38/14/3 (Epic stays the likeliest)
		asset = "CatCafe_Item_Caviar",
	},
	{
		id = "moon_milk",
		name = "Moon Milk",
		cost = 2000000, -- #1389 (x40 on F97's 50,000); Economy.foodPrice grows it by tier
		sortOrder = 6,
		attracts = "Epic",
		rarity = "Legendary",
		source = "dealer",
		description = "Nobody knows where he gets it.",
		odds = { Common = 0, Rare = 32, Epic = 38.25, Legendary = 23.8, Mythical = 5.95 }, -- #2239: was 0/20/45/28/7
		asset = "CatCafe_Item_MoonMilk",
	},
	{
		id = "star_treat",
		name = "Star Treat",
		cost = 8000000, -- #1389 (x40 on F97's 200,000); Economy.foodPrice grows it by tier
		sortOrder = 7,
		attracts = "Legendary",
		rarity = "Mythical",
		source = "dealer",
		description = "It twinkles. Mythical cats can smell it from the next area.",
		odds = { Common = 0, Rare = 0, Epic = 43.25, Legendary = 44, Mythical = 12.75 }, -- #2239: was 0/0/40/45/15 (Legendary stays the likeliest)
		asset = "CatCafe_Item_StarTreat",
	},
	-- #3462 (Derek 2026-11-12: "add better items to day cart like legendary bait and better potions but make it for
	-- more money", then "move all of those items to be in the billions" and "tier 6+"): the Day Cart's own two baits,
	-- a little better at the top end than the dealer's best, sold only there (source "cart") at a flat `cost` that
	-- no tier scales (Economy.foodPrice). Names, odds and the swap away from the dealer's foods are Design-Agent's,
	-- made while Derek was away. #3945: each sits in the bowl as its own model (they wore Moon Milk's and Star Treat's).
	{
		id = "honey_cream",
		name = "Honey Cream",
		cost = 1000000000,
		sortOrder = 8,
		attracts = "Epic",
		rarity = "Legendary",
		source = "cart",
		description = "Thick, sweet and gone in one lick.",
		odds = { Common = 0, Rare = 20, Epic = 40, Legendary = 32, Mythical = 8 },
		asset = "CatCafe_Item_HoneyCream",
	},
	{
		id = "comet_treat",
		name = "Comet Treat",
		cost = 3000000000,
		sortOrder = 9,
		attracts = "Legendary",
		rarity = "Mythical",
		source = "cart",
		description = "Still warm from the sky.",
		odds = { Common = 0, Rare = 0, Epic = 35, Legendary = 48, Mythical = 17 },
		asset = "CatCafe_Item_CometTreat",
	},
} :: { Types.LureDef }

-- Section 11b (F47): the Tip Jar's twelve playtime gifts in step order, unlocked by minutes of the current session.
-- Coins scale with the day rate at claim time (shared/TipJar.coins); the dealer foods are fine here since they are
-- free. Nothing about the jar can be bought. F95 (economy-ladder.md section 6b, Derek 2026-10-30 00:27): every prize
-- paid in seconds of day rate in this file (the jar, the Daily Treat, quests, the wheel, achievements, the Index
-- milestones and codes) pays half the seconds it did; the minimum coins stay. F94 (rewards-and-shops.md section 2a):
-- small amounts of golden fish in place of shop food, and at most three pictures on the two hour gift.
Catalog.tipJar = {
	-- v2 (#1414, rewards-and-shops.md section 2a): coins 2x, golden fish 5x, spins 5x and the crate 2x
	{ step = 1, minutes = 2, prize = { coins = 100, coinSeconds = 30 } },
	{ step = 2, minutes = 5, prize = { fish = 5 } }, -- #2237: fish about 60% (10, 10, 15, 50, 25, 150)
	{ step = 3, minutes = 10, prize = { coins = 200, coinSeconds = 60 } },
	{ step = 4, minutes = 15, prize = { fish = 5 } },
	{ step = 5, minutes = 20, prize = { coins = 300, coinSeconds = 90 } },
	{ step = 6, minutes = 30, prize = { spins = 5 } },
	{ step = 7, minutes = 40, prize = { coins = 500, coinSeconds = 120 } },
	{ step = 8, minutes = 50, prize = { fish = 10 } },
	-- v0.10 (F68, round 4 Q10): a pretty good gift at one hour
	{ step = 9, minutes = 60, prize = { coins = 2000, coinSeconds = 600, fish = 30 } },
	{ step = 10, minutes = 75, prize = { fish = 15 } },
	{ step = 11, minutes = 90, prize = { coins = 1200, coinSeconds = 300, spins = 5 } },
	-- and a really good one at two hours
	{ step = 12, minutes = 120, prize = { crates = { classic_crate = 2 }, fish = 90 } },
} :: { Types.TipJarStep }

-- Section 11e (F70, round 4 Q9): the Daily Treat card, one stamp per UTC day played and never reset. Days 2 and 4
-- are pretty good and day 7 really good: a Golden Classic Crate and a Star Treat, the night dealer's best bait, for a
-- real shot at a top cat while cats still come only from catching, rescue and bait. Earned only (monetization-policy).
-- F94 (rewards-and-shops.md section 2c): no shop food, and day 7 drops its spins to three pictures.
Catalog.dailyTreat = {
	-- #1181 (corner-shop-v2.md section 3): days 1, 3 and 5 give cat food beside their coins
	{ day = 1, prize = { coins = 300, coinSeconds = 150, catFood = { small_cat_snack = 2 } } },
	{ day = 2, prize = { fish = 10, spins = 1 } }, -- #2237: was 15
	{ day = 3, prize = { coins = 600, coinSeconds = 300, catFood = { cat_snack = 1 } } },
	{ day = 4, prize = { crates = { classic_crate = 1 }, spins = 1 } },
	{ day = 5, prize = { coins = 1000, coinSeconds = 450, catFood = { cat_snack = 1 } } },
	{ day = 6, prize = { potions = { lucky_potion = 1 }, fish = 5 } }, -- #2237: was 10
	{
		day = 7,
		prize = {
			crates = { classic_golden_crate = 1 },
			lures = { star_treat = 1 },
			fish = 30, -- #2237: was 50
		},
	},
} :: { Types.DailyTreatDay }

-- Section 11c (F49): the Spin Wheel's slices in order around the wheel. Free spins only: no Robux button, pass
-- or product gives spins (monetization-policy), and a spin never gives a cat. Frozen, like the Index prizes.
-- v2 (#1500, rewards-and-shops.md section 2b v2, the friend 2026-11-05): 8 slices, coins on 69% of spins and two
-- 0.5% jackpots to chase. Weights are in half-percents (total 200). The world wheel's slices follow this order
-- (spinwheel.py; the jackpots are the two narrow gold wedges, SliceSpans "52,52,52,52,52,52,24,24").
Catalog.spinWheel = {
	{ slice = 1, kind = "coins", seconds = 120, minCoins = 200, weight = 70 }, -- 35%
	{ slice = 2, kind = "coins", seconds = 600, minCoins = 1000, weight = 44 }, -- 22%
	{ slice = 3, kind = "fish", count = 3, weight = 30 }, -- 15%; #2237: was 5
	{ slice = 4, kind = "coins", seconds = 1800, minCoins = 3000, weight = 24 }, -- 12%, new in v2
	{ slice = 5, kind = "lure", lureId = "caviar", count = 1, weight = 18 }, -- 9%
	{ slice = 6, kind = "crate", crate = "highest", count = 1, weight = 12 }, -- 6%
	{ slice = 7, kind = "crate", crate = "highest_golden", count = 1, weight = 1, jackpot = true }, -- 0.5%
	{ slice = 8, kind = "fish", count = 60, weight = 1, jackpot = true }, -- 0.5%; #2237: was 100
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
		effect = "+50% Luck and double gold chance on bait", -- F88: Config.LuckyPotionLuck
	},
	-- corner-shop-v2.md section 1: the regular Swift Potion runs 10 minutes (was 5)
	{ id = "swift_potion", name = "Swift Potion", minutes = 10, effect = "+4 walk speed" },
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
	-- corner-shop-v2.md section 1 (#1180): the Corner Shop's Small and Big sizes. A size runs its regular potion's
	-- timer (`buff`), so one chip shows the summed minutes; all of these are sold only there, never in a Mystery gift
	-- (`shopOnly`). #2891 (Derek2 2026-11-09: "it's just not needed"): the Cat Whistle and its sizes are retired, and
	-- the ones a save held are refunded as it loads (ProfileSchema.RETIRED_POTIONS).
	{
		id = "swift_potion_small",
		name = "Small Swift Potion",
		minutes = 3,
		effect = "+4 walk speed",
		buff = "swift_potion",
		shopOnly = true,
	},
	{
		id = "swift_potion_big",
		name = "Big Swift Potion",
		minutes = 30,
		effect = "+4 walk speed",
		buff = "swift_potion",
		shopOnly = true,
	},
	{
		id = "steady_potion_small",
		name = "Small Steady Paw Potion",
		minutes = 5,
		effect = "Easier catch circles",
		buff = "steady_potion",
		shopOnly = true,
	},
	{
		id = "steady_potion_big",
		name = "Big Steady Paw Potion",
		minutes = 30,
		effect = "Easier catch circles",
		buff = "steady_potion",
		shopOnly = true,
	},
	{
		id = "quick_bait_potion_small",
		name = "Small Quick Bait Potion",
		minutes = 10,
		effect = "Bait ready 25% sooner",
		buff = "quick_bait_potion",
		shopOnly = true,
	},
	{
		id = "quick_bait_potion_big",
		name = "Big Quick Bait Potion",
		minutes = 60,
		effect = "Bait ready 25% sooner",
		buff = "quick_bait_potion",
		shopOnly = true,
	},
	-- #3462 (Derek 2026-11-12: "add better items to day cart like legendary bait and better potions but make it for
	-- more money", "move all of those items to be in the billions", "tier 6+"): the Day Cart's three Tier 6 potions,
	-- each a stronger kind with its own 30 minute timer, sold only there (`shopOnly`). Design-Agent's list.
	--   Big Lucky: its Luck takes the place of a running Lucky Potion's, never on top (Potions.luck)
	--   Big Gold Rush: adds to a running Gold Rush Potion's gold luck, as every `goldLuck` does
	--   Mega Money: with the other money potions still at most Config.TimedTipsMax, so on its own it fills the cap
	{
		id = "big_lucky_potion",
		name = "Big Lucky Potion",
		minutes = 30,
		effect = "+75% Luck, 2x bait gold",
		luck = 0.75,
		shopOnly = true,
	},
	{
		id = "big_gold_rush_potion",
		name = "Big Gold Rush Potion",
		minutes = 30,
		effect = "+50% gold luck",
		goldLuck = 0.5,
		shopOnly = true,
	},
	{
		id = "mega_tip_potion",
		name = "Mega Money Potion",
		minutes = 30,
		effect = "+100% money, the most potions can add",
		tips = 1,
		shopOnly = true,
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
-- #1645 (quests.md section 8): each also pays Cafe Pass XP (passXp). #2070 (Derek2: "make the xp more from quests"):
-- 1.5x, so 1,200 for a full day and 2,400 for a full week (were 800 and 1,600), about 18 days of full play for the
-- 34 levels' 27,200 XP (was about 26).
Catalog.questPrizes = {
	daily = { coins = 200, coinSeconds = 90, fish = 1, passXp = 150 }, -- #2237 fish: was 2, 5, 10, 15, 40
	dailyBig = { coins = 400, coinSeconds = 150, fish = 3, passXp = 300 },
	dailySet = { potions = { big_tip_potion = 1, gold_rush_potion = 1 }, fish = 6, passXp = 300 },
	weekly = { coins = 2000, coinSeconds = 600, fish = 10, passXp = 600 },
	weeklySet = {
		potions = { big_tip_potion = 3 },
		crates = { classic_golden_crate = 1 },
		fish = 25,
		passXp = 600,
	},
} :: { [string]: Types.IndexPrize }

-- The Cafe Pass seasons (#1645, #1626; cafe-pass.md sections 2 and 3), by season number (CafePass.seasonDef wraps
-- round, so a later season can rerun one). The free track rewards every level (every second one before #1883) and may
-- be random (nobody pays for it); the paid track rewards every level with fixed things only: Big Money, Swift and
-- Steady Paw potions and named items, never crates, spins, golden fish, coins, minutes of income or Lucky Potions
-- (CafePass.spec walks it).
-- "Minutes of income" is coinSeconds of the day rate.
local function item(kind: Types.PassItemKind, id: string, name: string): Types.PassReward
	return { item = { kind = kind, id = id, name = name } }
end
local function potions(set: { [string]: number }): Types.PassReward
	return { prize = { potions = set } }
end
Catalog.passSeasons = {
	{
		id = "season_1",
		name = "Season 1: Maple",
		free = {
			[1] = { prize = { fish = 5 } }, -- #2237: free track fish about 60%; #1883: odd levels added (free, resources only)
			[2] = { prize = { spins = 1 } },
			[3] = { prize = { coinSeconds = 300 } },
			[4] = { prize = { fish = 10 } },
			[5] = potions({ tip_potion = 1 }),
			[6] = potions({ lucky_potion = 1 }),
			[7] = { prize = { spins = 1 } },
			[8] = { prize = { coinSeconds = 600 } },
			[9] = { prize = { fish = 10 } },
			[10] = { prize = { crates = { classic_crate = 1 } } },
			[11] = { prize = { coinSeconds = 600 } },
			[12] = { prize = { spins = 1 } },
			[13] = potions({ swift_potion = 1 }),
			[14] = { prize = { fish = 15 } },
			[15] = { prize = { crates = { highest = 1 } } }, -- the highest open zone's crate (Design-Agent on #1883)
			[16] = potions({ tip_potion = 1, swift_potion = 1 }),
			[17] = { prize = { fish = 10 } },
			[18] = { prize = { coinSeconds = 1200 } },
			[19] = { prize = { coinSeconds = 900 } },
			[20] = { prize = { crates = { classic_crate = 1 } } },
			[21] = potions({ swift_potion = 1 }),
			[22] = { prize = { spins = 2 } },
			[23] = { prize = { spins = 1 } },
			[24] = { prize = { fish = 25 } },
			[25] = { prize = { crates = { highest = 1 } } },
			[26] = potions({ lucky_potion = 1, steady_potion = 1 }),
			[27] = { prize = { fish = 20 } },
			[28] = { prize = { coinSeconds = 1800 } },
			[29] = { prize = { coinSeconds = 1500 } },
			[30] = { prize = { crates = { classic_crate = 1 }, fish = 30 } },
			-- #1883 part C: the four levels added with the Maple showpieces (free, resources only)
			[31] = { prize = { fish = 20 } },
			[32] = potions({ swift_potion = 1 }),
			[33] = { prize = { coinSeconds = 1800 } },
			[34] = { prize = { crates = { highest = 1 } } },
		},
		paid = {
			[1] = item("tag", "tag_maple", "Season 1 chat tag [Maple]"),
			[2] = potions({ big_tip_potion = 1, swift_potion = 1 }), -- #1883: +1 on the potion levels (a Swift here keeps
			-- Pace.spec's level 6 money cap; a second Big Money would pay 37.5 income minutes, over 24)
			[3] = item("uniform", "uniform_pumpkin", "Uniform colour: Pumpkin"),
			[4] = potions({ swift_potion = 2 }),
			[5] = item("accessory", "acc_leaf_beret", "Leaf Beret"),
			[6] = potions({ steady_potion = 2 }),
			[7] = item("decor", "decor_pumpkin_lantern", "Pumpkin Lantern"),
			[8] = potions({ big_tip_potion = 2 }),
			[9] = item("uniform", "uniform_acorn_brown", "Uniform colour: Acorn Brown"),
			[10] = item("accessory", "acc_mushroom_cap", "Mushroom Cap"),
			[11] = potions({ swift_potion = 2 }),
			[12] = item("decor", "decor_fallen_leaf_rug", "Fallen Leaf Rug"),
			[13] = potions({ big_tip_potion = 2 }),
			[14] = item("uniform", "uniform_forest_green", "Uniform colour: Forest Green"),
			[15] = item("decor", "decor_cosy_knit_cushion", "Cosy Knit Cushion"),
			[16] = item("accessory", "acc_acorn_hair_clip", "Acorn Hair Clip"),
			[17] = potions({ steady_potion = 2 }),
			[18] = item("decor", "decor_hay_bale_seat", "Hay Bale Seat"),
			[19] = potions({ big_tip_potion = 2 }),
			[20] = item("uniform", "uniform_cranberry", "Uniform colour: Cranberry"),
			[21] = potions({ swift_potion = 1, steady_potion = 1 }),
			[22] = item("accessory", "acc_round_reading_glasses", "Round Reading Glasses"),
			[23] = potions({ big_tip_potion = 1 }),
			[24] = item("decor", "decor_apple_crate_shelf", "Apple Crate Shelf"),
			[25] = potions({ big_tip_potion = 3 }),
			[26] = item("accessory", "acc_tiny_lantern", "Tiny Lantern"),
			[27] = potions({ steady_potion = 1, swift_potion = 1 }),
			[28] = item("decor", "decor_maple_tree_planter", "Maple Tree Planter"),
			[29] = item("frame", "frame_golden_leaf", "Name plate frame: Golden Leaf"),
			[30] = item("cat", "maple_muffin", "Season cat: Maple Muffin"),
			-- #1883 part C (Model-Agent's art, #1921): the paid track ends on four Maple showpieces
			[31] = item("accessory", "acc_leaf_crown", "Autumn Leaf Crown"),
			[32] = item("decor", "decor_maple_leaf_lamp", "Maple Leaf Lamp"),
			[33] = item("decor", "decor_harvest_cider_cart", "Harvest Cider Cart"),
			[34] = item("frame", "sign_maple_board", "Cafe sign: Maple Board"),
		},
	},
} :: { Types.PassSeasonDef }

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
		-- #3694: a step between, so one is always close
		id = "a_catch25",
		name = "Cat Spotter",
		text = "Catch 25 cats",
		measure = "catsCaught",
		needs = 25,
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
		-- #3694: a step between, so one is always close
		id = "a_catch250",
		name = "Cat Herder",
		text = "Catch 250 cats",
		measure = "catsCaught",
		needs = 250,
		size = "M",
	},
	{
		id = "a_catch1k",
		name = "Cat Wrangler",
		text = "Catch 500 cats",
		measure = "catsCaught",
		needs = 500,
		size = "L",
	},
	{
		-- #3694: a step between, so one is always close
		id = "a_catch1000",
		name = "Cat Tamer",
		text = "Catch 1,000 cats",
		measure = "catsCaught",
		needs = 1000,
		size = "L",
	},
	{
		id = "a_catch10k",
		name = "Cat Legend",
		text = "Catch 2,500 cats",
		measure = "catsCaught",
		needs = 2500,
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
		-- #3694: a step between, so one is always close
		id = "a_rare25",
		name = "Rare Seeker",
		text = "Catch 25 Rare or better cats",
		measure = "rareCatches",
		needs = 25,
		size = "M",
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
		-- #3694: a step between, so one is always close
		id = "a_gold10",
		name = "Gold Seeker",
		text = "Catch 10 gold cats",
		measure = "goldCatches",
		needs = 10,
		size = "L",
	},
	{
		id = "a_gold50",
		name = "Gold Rush",
		text = "Catch 25 gold cats",
		measure = "goldCatches",
		needs = 25,
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
		-- #3694: a step between, so one is always close
		id = "a_perfect100",
		name = "Sure Paws",
		text = "Land 100 perfect circles",
		measure = "perfectCircles",
		needs = 100,
		size = "M",
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
		text = "Land 2,000 perfect circles",
		measure = "perfectCircles",
		needs = 2000,
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
		-- #3694: a step between, so one is always close
		id = "a_rescue25",
		name = "Helping Hand",
		text = "Rescue 25 stuck cats",
		measure = "rescues",
		needs = 25,
		size = "M",
	},
	{
		id = "a_rescue250",
		name = "Rescue Hero",
		text = "Rescue 100 stuck cats",
		measure = "rescues",
		needs = 100,
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
		-- #3694: a step between, so one is always close
		id = "a_bait25",
		name = "Bowl Regular",
		text = "Tame 25 cats at your bait bowl",
		measure = "baitsTamed",
		needs = 25,
		size = "M",
	},
	{
		id = "a_bait200",
		name = "Bait Master",
		text = "Tame 100 cats at your bait bowl",
		measure = "baitsTamed",
		needs = 100,
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
		text = "Collect 1,000 tip piles",
		measure = "tipPilesCollected",
		needs = 1000,
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
		-- #3694: a step between, so one is always close
		id = "a_hours1",
		name = "Settling In",
		text = "Play for 1 hour",
		measure = "playtimeSeconds",
		needs = 3600,
		size = "S",
	},
	{
		-- #3694: a step between, so one is always close
		id = "a_hours5",
		name = "Happy Visitor",
		text = "Play for 5 hours",
		measure = "playtimeSeconds",
		needs = 18000,
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
		-- #3694: a step between, so one is always close
		id = "a_hours25",
		name = "Cafe Fixture",
		text = "Play for 25 hours",
		measure = "playtimeSeconds",
		needs = 90000,
		size = "L",
	},
	{
		id = "a_hours100",
		name = "Devoted",
		text = "Play for 50 hours",
		measure = "playtimeSeconds",
		needs = 180000,
		size = "XL",
	},
	{
		-- #3694: a step between, so one is always close
		id = "a_quests10",
		name = "Quest Starter",
		text = "Finish 10 daily quests",
		measure = "dailyQuestsDone",
		needs = 10,
		size = "S",
	},
	{
		-- #3694: a step between, so one is always close
		id = "a_quests30",
		name = "Quest Fan",
		text = "Finish 30 daily quests",
		measure = "dailyQuestsDone",
		needs = 30,
		size = "M",
	},
	{
		id = "a_quests100",
		name = "Quest Keeper",
		text = "Finish 60 daily quests",
		measure = "dailyQuestsDone",
		needs = 60,
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
		-- #3694: a step between, so one is always close
		id = "a_week3",
		name = "Week Keeper",
		text = "Finish every weekly quest in 3 weeks",
		measure = "weeklySetsDone",
		needs = 3,
		size = "L",
	},
	{
		id = "a_week10",
		name = "Week Champion",
		text = "Finish every weekly quest in 5 weeks",
		measure = "weeklySetsDone",
		needs = 5,
		size = "XL",
	},
	{
		-- #3694: a step between, so one is always close
		id = "a_level10",
		name = "Rising Star",
		text = "Raise a cat to level 10",
		measure = "topCatLevel",
		needs = 10,
		size = "M",
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
	-- #3694 section 3: the newer features. `flag` is the feature's live switch: while it is off the achievement is
	-- hidden and not counted (Quests.achievementShown). Pet your cats (a_pet25) waits for the petCats server build.
	{
		id = "a_bin10",
		name = "Bin Diver",
		text = "Win 10 rummages at the Rummage Bin",
		measure = "binWins",
		needs = 10,
		size = "M",
		flag = "alleyBin",
	},
	{
		id = "a_bin50",
		name = "Treasure Hunter",
		text = "Win 50 rummages at the Rummage Bin",
		measure = "binWins",
		needs = 50,
		size = "L",
		flag = "alleyBin",
	},
	{
		id = "a_yard10",
		name = "Lucky Picker",
		text = "Take 10 Yard Sale lucky picks",
		measure = "yardPicks",
		needs = 10,
		size = "M",
		flag = "yardSaleRoll",
	},
	{
		id = "a_traits10",
		name = "Pool Regular",
		text = "Roll 10 traits at the Mystic Pool",
		measure = "traitRolls",
		needs = 10,
		size = "M",
		flag = "traits",
	},
	{
		id = "a_traits50",
		name = "Pool Wizard",
		text = "Roll 50 traits at the Mystic Pool",
		measure = "traitRolls",
		needs = 50,
		size = "L",
		flag = "traits",
	},
	{
		id = "a_dash10",
		name = "Mouse Chaser",
		text = "Play 10 games of Mouse Dash",
		measure = "dashRuns",
		needs = 10,
		size = "M",
		flag = "mouseDash",
	},
	{
		id = "a_secret1",
		name = "Secret Spotter",
		text = "Find a Secret cat",
		measure = "secretCats",
		needs = 1,
		size = "L",
		flag = "secretCats",
	},
	{
		id = "a_secret3",
		name = "Secret Keeper",
		text = "Find all three Secret cats",
		measure = "secretCats",
		needs = 3,
		size = "XL",
		flag = "secretCats",
	},
	{
		id = "a_rest1h",
		name = "Cozy Napper",
		text = "Rest in your cafe for 1 hour in total",
		measure = "restSeconds",
		needs = 3600,
		size = "M",
		flag = "afkCafe",
	},
	{
		id = "a_goldcrate5",
		name = "Golden Opener",
		text = "Open 5 golden crates",
		measure = "goldenCratesOpened",
		needs = 5,
		size = "L",
	},
} :: { Types.AchievementDef }

-- An achievement's prize by its size; coins scale with the day rate when claimed. F94 (rewards-and-shops.md section
-- 2d): two pictures, three on XL. #2070 (Derek2: "make pass xp also come from achievements"): each also pays Cafe Pass
-- XP for the running season through Payout, like a quest: 50, 150, 300 and 600 by size.
Catalog.achievementPrizes = {
	S = { coins = 300, coinSeconds = 150, spins = 1, passXp = 50 },
	M = { coins = 1000, coinSeconds = 450, potions = { tip_potion = 1 }, passXp = 150 },
	L = { coins = 2500, coinSeconds = 900, crates = { classic_crate = 1 }, passXp = 300 },
	XL = {
		coins = 5000,
		coinSeconds = 1800,
		crates = { classic_golden_crate = 1 },
		potions = { big_tip_potion = 1 },
		passXp = 600,
	},
} :: { [string]: Types.IndexPrize }

-- #3694 (Derek 2026-11-12: "make the rewards slightly more unique/diff"; achievements-v2.md section 4): the coins,
-- coinSeconds and pass XP stay by size, and the item comes from the achievement's line, keyed by its measure. A line
-- with no row for a size, or a measure with no line, pays the size's item as before. "highest" is the crate of the
-- player's best open area and "highest_golden" its golden crate (shared/Prizes). Everything here is earned in play;
-- none of it is sold for Robux.
type AchievementLine = { [string]: Types.IndexPrize }
local CATCHING: AchievementLine = {
	S = { lures = { tuna = 2 } },
	M = { lures = { salmon = 1, tuna = 1 } },
	L = { crates = { highest = 1 } },
	XL = { crates = { highest_golden = 1 }, lures = { caviar = 1 } },
}
local FINDING: AchievementLine = {
	S = { spins = 1 },
	M = { crates = { highest = 1 } },
	L = { crates = { highest_golden = 1 } },
	XL = { crates = { highest_golden = 2 } },
}
local QUESTS: AchievementLine = {
	S = { spins = 2 },
	M = { spins = 3 },
	L = { spins = 5, fish = 10 },
	XL = { crates = { classic_golden_crate = 1 }, spins = 5 },
}
local PLAYING: AchievementLine = {
	S = { fish = 5 },
	M = { fish = 10 },
	L = { fish = 25, potions = { tip_potion = 1 } },
	XL = { fish = 50, potions = { big_tip_potion = 1 } },
}
local ACHIEVEMENT_LINES: { [string]: AchievementLine } = {
	catsCaught = CATCHING,
	rareCatches = CATCHING,
	goldCatches = {
		M = { potions = { lucky_potion = 1 } },
		L = { potions = { lucky_potion = 2 } },
		XL = { crates = { classic_golden_crate = 1 }, potions = { gold_rush_potion = 1 } },
	},
	perfectCircles = {
		S = { potions = { steady_potion = 1 } },
		M = { potions = { steady_potion = 2 } },
		L = { potions = { steady_potion = 3 }, fish = 10 },
		XL = { crates = { classic_golden_crate = 1 }, potions = { steady_potion = 3 } },
	},
	rescues = {
		S = { potions = { swift_potion = 1 } },
		M = { potions = { swift_potion = 2 } },
		L = { potions = { swift_potion = 3 }, crates = { classic_crate = 1 } },
	},
	baitsTamed = {
		S = { lures = { tuna = 2 } },
		M = { lures = { salmon = 2 } },
		L = { lures = { caviar = 1, salmon = 1 } },
	},
	distinctCats = FINDING,
	goldCats = FINDING,
	mythicalCats = FINDING,
	dailyQuestsDone = QUESTS,
	weeklySetsDone = QUESTS,
	playtimeSeconds = PLAYING,
	restSeconds = PLAYING, -- #3694 section 3: resting counts as play time
	secretCats = FINDING,
	-- #3694 section 3: the Rummage Bin and the Yard Sale pay Alley crates
	binWins = {
		M = { crates = { alley_crate = 1 } },
		L = { crates = { alley_golden_crate = 1 } },
	},
	yardPicks = {
		M = { crates = { alley_crate = 1 } },
		L = { crates = { alley_golden_crate = 1 } },
	},
	-- the design's 1 and 3 Trait Tokens, paid as the golden fish they cost (Traits.COST_FISH 20 a roll since #4006)
	-- until a prize can carry tokens
	traitRolls = {
		M = { fish = 20 },
		L = { fish = 60 },
	},
	dashRuns = {
		M = { spins = 2 },
	},
	topCatLevel = {
		M = { potions = { tip_potion = 1 } },
		L = { potions = { tip_potion = 2 } },
		XL = { potions = { big_tip_potion = 1 }, crates = { classic_golden_crate = 1 } },
	},
}
Catalog.achievementLines = ACHIEVEMENT_LINES

-- #3694: what one achievement pays: its size's coins and pass XP with its line's item, or the size's whole prize when
-- its line has no row for that size. A new table each call, so callers may keep it.
local PRIZE_BY_SIZE = { "coins", "coinSeconds", "passXp" }
function Catalog.achievementPrize(def: Types.AchievementDef): Types.IndexPrize
	local base = Catalog.achievementPrizes[def.size]
	local line = Catalog.achievementLines[def.measure]
	local item = if line then line[def.size] else nil
	if base == nil or item == nil then
		return table.clone((base or {}) :: Types.IndexPrize)
	end
	local prize: { [string]: any } = table.clone(item :: any)
	for _, key in PRIZE_BY_SIZE do
		prize[key] = (base :: any)[key]
	end
	return prize :: Types.IndexPrize
end

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
for _, line in Catalog.achievementLines do
	for _, prize in line do
		for _, part in prize :: { [string]: any } do
			if type(part) == "table" and not table.isfrozen(part) then
				table.freeze(part)
			end
		end
		if not table.isfrozen(prize) then
			table.freeze(prize)
		end
	end
end
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
-- #2614 (Derek2 2026-11-09: "make mystery gifts better"; Design-Agent's tiers): the wrap is rolled first, Common 70,
-- Rare 25, Super 5, then a row of it. A Common potion is Money, Lucky or Steady (the Swift Potion left the pool), its
-- coins are 3 minutes of income, a Rare quest potion is one of the three 30-minute ones, and a Super crate is the one
-- of the highest open area plus 15 golden fish. About 3.8 golden fish a gift on average (it was 3).
Catalog.mysteryGiftTiers = {
	{
		tier = "Common",
		chance = 70,
		rows = {
			{ kind = "potion", count = 1, chance = 45 },
			{ kind = "coins", count = 180, chance = 35 },
			{ kind = "fish", count = 8, chance = 20 },
		},
	},
	{
		tier = "Rare",
		chance = 25,
		rows = {
			{ kind = "questPotion", count = 1, chance = 40 },
			{ kind = "fish", count = 20, chance = 25 },
			{ kind = "spin", count = 1, chance = 20 },
			{ kind = "food", id = "big_cat_snack", count = 2, chance = 15 },
		},
	},
	{
		tier = "Super",
		chance = 5,
		rows = {
			{ kind = "crate", id = "highest", count = 1, fish = 15, chance = 60 },
			{ kind = "fish", count = 50, chance = 40 },
		},
	},
} :: { Types.MysteryGiftTier }
for _, tier in Catalog.mysteryGiftTiers do
	for _, row in tier.rows do
		table.freeze(row)
	end
	table.freeze(tier.rows)
	table.freeze(tier)
end
table.freeze(Catalog.mysteryGiftTiers)
-- The Common wrap's rows, for the prompt's odds line until it reads the wrap's own (#2614).
Catalog.mysteryGift = Catalog.mysteryGiftTiers[1].rows

-- Section 12b (F63): the Cat Collector's offers by the value he puts on the cat, lowest first. He offers the best row
-- his value reaches, and the first below that, so a Common always gets 3 golden fish (#2237, was 5). The crate rows start at 6 and 11
-- (Design #500), so every Epic gets a crate and its best rolls 12 fish with it. A zone crate is the crate of
-- the cat's own area and a golden crate its golden version (golden-fish.md section 4). F94 (rewards-and-shops.md
-- section 2f): value 2 pays 10 golden fish (was 3 Tuna and a spin).
Catalog.collectorOffers = {
	{ value = 1, fish = 3 }, -- #2237 fish: was 5, 10, 15, 20, 50, 100
	{ value = 2, fish = 6 },
	{ value = 4, fish = 10 },
	{ value = 6, crates = { zone = 1 } },
	{ value = 8, catFood = { big_cat_snack = 2 } }, -- #1181 (corner-shop-v2.md section 3): "2 Big Snacks"
	{ value = 11, crates = { zone = 1 }, fish = 12 },
	{ value = 20, crates = { zone = 2 } },
	{ value = 35, crates = { golden = 1 } },
	{ value = 60, crates = { golden = 1 }, fish = 30 },
	{ value = 120, crates = { golden = 2 }, fish = 60 },
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
-- #3011 (Derek2 2026-11-10: "buff how often night market stocks good items and amount"): averages 2.45, 1.60, 1.20
-- and 0.55, in stock 95%, 85%, 75% and 45% of nights. Before it (#1442, Derek 2026-11-05, "a little bit" more):
-- sardines { 15, 25, 30, 20, 10 }, caviar { 35, 40, 20, 5, 0 }, moon_milk { 45, 45, 10, 0, 0 } and star_treat
-- { 80, 20, 0, 0, 0 }, averages 1.85, 0.95, 0.65 and 0.20. Prices and bait odds are unchanged. With
-- Config.DealerDryNights a long run without Moon Milk or a Star Treat ends on its own (shared/Dealer). F94
-- (rewards-and-shops.md section 4): each server rolls one stock at dusk that holds all night (was every 5 minutes).
Catalog.dealerAmountWeights = {
	sardines = { 5, 15, 30, 30, 20 },
	caviar = { 15, 35, 30, 15, 5 },
	moon_milk = { 25, 40, 25, 10, 0 },
	star_treat = { 55, 35, 10, 0, 0 },
} :: { [string]: { number } }

-- Section 9. Every area has the same odds since v0.13.7; farther areas pay more through incomeMultiplier instead.
-- #1452 (Derek 2026-11-05: the food bowl should not be the only realistic way to get rare cats): 54 / 29 / 11 / 4.8 /
-- 1.2 (was 72 / 22 / 5 / 0.9 / 0.1), so Salmon in a Royal Bowl is 2.5x the wild for Legendary and Mythical. A full
-- wave of waveSize strays spawns in every area at each sunrise, whether or not anyone has it open; since #1159 an
-- area under its floor of live strays gets daytime top-ups (shared/StrayTopUp). #2557: 11, 12, 12, 11 and 11, 57 a
-- day in all (#1621: 8, 9, 9, 8 and 8, 42) (#1452 had 8, 7, 7, 6 and 6; v0.13.5 6, 5, 5, 4 and 4 after Derek's 10-28 "way too many"; 10 each
-- before that). Every side area's spawn points are its kit set's cat spots (Model-Agent
-- #401, the Park's, the Woods', the Sewer's and the Neighbourhood's v3.2 sets #460, #470, #491 and #505).
Catalog.areas = {
	{
		id = "alley",
		name = "Alleyway",
		tier = 1,
		-- two on the lanes for each cafe's old place, four nooks at the far end (eight before #3170), six in the middle
		-- (#3170) and eight `near` points by the camp for the tutorial stray only (layout v3.1; v4, F84, data-model
		-- section 9 v0.13.18)
		spawnPoints = 34,
		-- #2794 (Derek2 2026-11-09: "make sure alleyway and park have lots of starting cats and lots of spawns since
		-- that's where a lot of players start also have rescues near start for them"): kept at 16 live by day (the
		-- top-up floor), 6 near the camp, 2 stuck cats each sunrise, one in the trap nearest the camp. The sunrise wave
		-- stays 11, since a bigger wave slows the rare-cat pace (tests/specs/Pace). #2557: was 8, then 11
		waveSize = 11,
		floorBase = 16,
		entryFloor = 6,
		rescueMinStuck = 2,
		starterRescue = true,
		rescueSpots = 3,
		odds = { Common = 54, Rare = 29, Epic = 11, Legendary = 4.8, Mythical = 1.2 }, -- #1452
		incomeMultiplier = AREA_INCOME.alley,
		-- #2322 (Derek2: "lower the difficulty of catching cats from first zone a little bit so people get used to it
		-- first"): bands 1.2 times as wide here, every rarity and net
		catchWindowScale = 1.2,
	},
	{
		id = "park",
		name = "Park",
		tier = 2,
		spawnPoints = 48, -- F85's long set's cat spots, 20 near the camp and 28 deep
		waveSize = 12, -- #2557: was 9; #2794 keeps 16 live through floorBase, as the Alleyway
		floorBase = 16,
		entryFloor = 6,
		rescueMinStuck = 2,
		starterRescue = true,
		rescueSpots = 5,
		odds = { Common = 54, Rare = 29, Epic = 11, Legendary = 4.8, Mythical = 1.2 }, -- #1452
		incomeMultiplier = AREA_INCOME.park,
	},
	{
		id = "neighbourhood",
		name = "Neighbourhood",
		tier = 3,
		spawnPoints = 77, -- F85's long set's cat spots, 32 near the camp and 45 deep (side paths for porches, #905)
		waveSize = 12, -- #2557 (Derek2, "increase cat spawns by about 33%"): was 9
		rescueSpots = 4, -- two sheds and two gutters
		odds = { Common = 54, Rare = 29, Epic = 11, Legendary = 4.8, Mythical = 1.2 }, -- #1452
		incomeMultiplier = AREA_INCOME.neighbourhood,
	},
	{
		id = "woods",
		name = "Woods",
		tier = 4,
		spawnPoints = 72, -- F85's long set's cat spots, 28 near the camp, 43 deep and the Great Oak's top
		waveSize = 11, -- #2557 (Derek2, "increase cat spawns by about 33%"): was 8
		rescueSpots = 5, -- two hollow logs, two bramble bushes and the tree house branch
		odds = { Common = 54, Rare = 29, Epic = 11, Legendary = 4.8, Mythical = 1.2 }, -- #1452
		incomeMultiplier = AREA_INCOME.woods,
	},
	{
		id = "sewer",
		name = "Sewer",
		tier = 5,
		spawnPoints = 60, -- F85's long set's cat spots, 25 near the camp and 35 deep
		waveSize = 11, -- #2557 (Derek2, "increase cat spawns by about 33%"): was 8
		rescueSpots = 4, -- two grates and two drain pipes
		odds = { Common = 54, Rare = 29, Epic = 11, Legendary = 4.8, Mythical = 1.2 }, -- #1452
		incomeMultiplier = AREA_INCOME.sewer,
	},
	-- #2651 (tier6-7-areas.md sections 4 and 5): Model-Agent's sets' cat spots (#2666, #2669)
	{
		id = "desert",
		name = "Desert",
		tier = 6,
		spawnPoints = 106, -- 50 near the camp and 56 deep
		waveSize = 11,
		rescueSpots = 5, -- two dunes, two clay urns and a collapsed canopy
		odds = { Common = 54, Rare = 29, Epic = 11, Legendary = 4.8, Mythical = 1.2 },
		incomeMultiplier = AREA_INCOME.desert,
	},
	{
		id = "ruins",
		name = "Ruins",
		tier = 7,
		spawnPoints = 100, -- 55 near the camp and 45 deep
		waveSize = 11,
		rescueSpots = 5, -- two rubble piles, two stone urns and the broken bridge ledge
		odds = { Common = 54, Rare = 29, Epic = 11, Legendary = 4.8, Mythical = 1.2 },
		incomeMultiplier = AREA_INCOME.ruins,
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
	-- #3992 (Derek: "add more index rewards for rainbow /gold up to 70"; Design-Agent's table on the issue): every All
	-- Cats track runs to the whole book. The last step is `whole`, so it needs every cat the book counts (70 today)
	-- and moves up when an area adds cats. `late`: nothing shows or pays until the `indexTo70` switch is on, which waits
	-- for the restart, as an older server's save check drops a claim id it does not know (shared/IndexRewards).
	{ id = "total55", track = "normal", needs = 55, late = true },
	{ id = "total60", track = "normal", needs = 60, late = true },
	{ id = "total65", track = "normal", needs = 65, late = true },
	{ id = "totalAll", track = "normal", needs = 70, whole = true, late = true },
	{ id = "decor5", track = "decor", needs = 5 },
	-- every piece of the page: 12 since F80 (golden-fish.md 4b), and 16 on the Classic page since F97 (`whole`)
	{ id = "decor10", track = "decor", needs = 12, whole = true },
	-- F99 (rainbow-coat.md section 4): one track for the whole Index, since one rainbow Mythical can take weeks
	{ id = "rainbow1", track = "rainbow", needs = 1 },
	{ id = "rainbow3", track = "rainbow", needs = 3 },
	{ id = "rainbow5", track = "rainbow", needs = 5 },
	{ id = "rainbow10", track = "rainbow", needs = 10 },
	{ id = "rainbow25", track = "rainbow", needs = 25 },
	-- #3992: on to every rainbow cat
	{ id = "rainbow30", track = "rainbow", needs = 30, late = true },
	{ id = "rainbow35", track = "rainbow", needs = 35, late = true },
	{ id = "rainbow40", track = "rainbow", needs = 40, late = true },
	{ id = "rainbow45", track = "rainbow", needs = 45, late = true },
	{ id = "rainbow50", track = "rainbow", needs = 50, late = true },
	{ id = "rainbow55", track = "rainbow", needs = 55, late = true },
	{ id = "rainbow60", track = "rainbow", needs = 60, late = true },
	{ id = "rainbow65", track = "rainbow", needs = 65, late = true },
	{ id = "rainbowAll", track = "rainbow", needs = 70, whole = true, late = true },
	-- #1772 (Derek2: "Gold cats X / 50" like the Rainbow cats): the gold track on the All Cats page, different gold
	-- cats across every area (profile.goldCollection), next to total5 to total50
	{ id = "goldtotal5", track = "gold", needs = 5 },
	{ id = "goldtotal10", track = "gold", needs = 10 },
	{ id = "goldtotal15", track = "gold", needs = 15 },
	{ id = "goldtotal20", track = "gold", needs = 20 },
	{ id = "goldtotal25", track = "gold", needs = 25 },
	{ id = "goldtotal30", track = "gold", needs = 30 },
	{ id = "goldtotal35", track = "gold", needs = 35 },
	{ id = "goldtotal40", track = "gold", needs = 40 },
	{ id = "goldtotal45", track = "gold", needs = 45 },
	{ id = "goldtotal50", track = "gold", needs = 50 },
	-- #3992: on to every gold cat
	{ id = "goldtotal55", track = "gold", needs = 55, late = true },
	{ id = "goldtotal60", track = "gold", needs = 60, late = true },
	{ id = "goldtotal65", track = "gold", needs = 65, late = true },
	{ id = "goldtotalAll", track = "gold", needs = 70, whole = true, late = true },
} :: { Types.IndexMilestone }

-- What each milestone pays per page (golden-fish.md sections 4, 5 and 5b). Everything is free and only the server
-- pays it. The normal track adds tips forever (`bonus`), the gold track gold luck (`goldLuck`) and All Cats faster
-- bait (`baitSpeed`). Named apart from profile.indexRewards (the claims) and frozen, so a write meant for a profile
-- errors instead of changing the prize for everyone on the server (reviewer S61). F94 (rewards-and-shops.md section
-- 2e): no shop food or spins beside a crate, so a prize shows two pictures and a track's last milestone three.
-- #2237 (Derek2 2026-11-07): every page's golden fish halved, rounded to 5 and at least 5
Catalog.indexPrizes = {
	alley = {
		cats3 = { coins = 300, coinSeconds = 300, fish = 5 },
		cats6 = { crates = { alley_crate = 1 }, fish = 5, bonus = 0.02 },
		cats10 = {
			crates = { alley_crate = 2, alley_golden_crate = 1 },
			fish = 15,
			bonus = 0.05,
		},
		gold1 = { fish = 5, crates = { alley_crate = 1 }, goldLuck = 0.02 },
		gold2 = { coins = 1000, coinSeconds = 450, fish = 10, goldLuck = 0.03 },
		gold4 = { crates = { alley_golden_crate = 1 }, fish = 15, goldLuck = 0.05 },
		gold6 = {
			coins = 2000,
			coinSeconds = 900,
			fish = 25,
			goldLuck = 0.05,
		},
		gold8 = { crates = { alley_golden_crate = 1 }, fish = 30, goldLuck = 0.05 },
		gold10 = {
			coins = 5000,
			coinSeconds = 1800,
			crates = { alley_golden_crate = 2 },
			fish = 50,
			tag = "Alleyway Gold Master",
			goldLuck = 0.10,
		},
	},
	park = {
		cats3 = { coins = 1000, coinSeconds = 300, fish = 5 },
		cats6 = { crates = { park_crate = 1 }, fish = 5, bonus = 0.02 },
		cats10 = {
			crates = { park_crate = 2, park_golden_crate = 1 },
			fish = 20,
			bonus = 0.05,
		},
		gold1 = { fish = 10, crates = { park_crate = 1 }, goldLuck = 0.02 },
		gold2 = { coins = 3000, coinSeconds = 450, fish = 10, goldLuck = 0.03 },
		gold4 = { crates = { park_golden_crate = 1 }, fish = 20, goldLuck = 0.05 },
		gold6 = {
			coins = 6000,
			coinSeconds = 900,
			fish = 30,
			goldLuck = 0.05,
		},
		gold8 = { crates = { park_golden_crate = 1 }, fish = 40, goldLuck = 0.05 },
		gold10 = {
			coins = 15000,
			coinSeconds = 1800,
			crates = { park_golden_crate = 2 },
			fish = 65,
			tag = "Park Gold Master",
			goldLuck = 0.10,
		},
	},
	neighbourhood = {
		cats3 = { coins = 3000, coinSeconds = 300, fish = 10 },
		cats6 = { crates = { neighbourhood_crate = 1 }, lures = { caviar = 2 }, bonus = 0.02 },
		cats10 = {
			crates = { neighbourhood_crate = 2, neighbourhood_golden_crate = 1 },
			fish = 25,
			bonus = 0.05,
		},
		gold1 = { fish = 10, crates = { neighbourhood_crate = 1 }, goldLuck = 0.02 },
		gold2 = { coins = 10000, coinSeconds = 450, fish = 15, goldLuck = 0.03 },
		gold4 = { crates = { neighbourhood_golden_crate = 1 }, fish = 25, goldLuck = 0.05 },
		gold6 = {
			coins = 20000,
			coinSeconds = 900,
			fish = 35,
			goldLuck = 0.05,
		},
		gold8 = { crates = { neighbourhood_golden_crate = 1 }, fish = 45, goldLuck = 0.05 },
		gold10 = {
			coins = 50000,
			coinSeconds = 1800,
			crates = { neighbourhood_golden_crate = 2 },
			fish = 75,
			tag = "Neighbourhood Gold Master",
			goldLuck = 0.10,
		},
	},
	woods = {
		cats3 = { coins = 10000, coinSeconds = 300, fish = 10 },
		cats6 = { crates = { woods_crate = 1 }, lures = { moon_milk = 2 }, bonus = 0.02 },
		cats10 = {
			crates = { woods_crate = 2, woods_golden_crate = 1 },
			fish = 40,
			bonus = 0.05,
		},
		gold1 = { fish = 15, crates = { woods_crate = 1 }, goldLuck = 0.02 },
		gold2 = { coins = 30000, coinSeconds = 450, fish = 20, goldLuck = 0.03 },
		gold4 = { crates = { woods_golden_crate = 1 }, fish = 30, goldLuck = 0.05 },
		gold6 = {
			coins = 60000,
			coinSeconds = 900,
			fish = 45,
			goldLuck = 0.05,
		},
		gold8 = { crates = { woods_golden_crate = 1 }, fish = 60, goldLuck = 0.05 },
		gold10 = {
			coins = 150000,
			coinSeconds = 1800,
			crates = { woods_golden_crate = 2 },
			fish = 100,
			tag = "Woods Gold Master",
			goldLuck = 0.10,
		},
	},
	sewer = {
		cats3 = { coins = 30000, coinSeconds = 300, fish = 15 },
		cats6 = { crates = { sewer_crate = 1 }, lures = { star_treat = 2 }, bonus = 0.02 },
		cats10 = {
			crates = { sewer_crate = 2, sewer_golden_crate = 1 },
			fish = 50,
			bonus = 0.05,
		},
		gold1 = { fish = 15, crates = { sewer_crate = 1 }, goldLuck = 0.02 },
		gold2 = { coins = 100000, coinSeconds = 450, fish = 25, goldLuck = 0.03 },
		gold4 = { crates = { sewer_golden_crate = 1 }, fish = 40, goldLuck = 0.05 },
		gold6 = {
			coins = 200000,
			coinSeconds = 900,
			fish = 55,
			goldLuck = 0.05,
		},
		gold8 = { crates = { sewer_golden_crate = 1 }, fish = 75, goldLuck = 0.05 },
		gold10 = {
			coins = 500000,
			coinSeconds = 1800,
			crates = { sewer_golden_crate = 2 },
			fish = 125,
			tag = "Sewer Gold Master",
			goldLuck = 0.10,
		},
	},
	desert = { -- #2651 (tier6-7-areas.md 7b): about 3 times the Sewer's coins; no goldLuck (the area tracks reach GoldLuckMax)
		cats3 = { coins = 90000, coinSeconds = 300, fish = 15 },
		cats6 = { crates = { desert_crate = 1 }, lures = { star_treat = 2 }, bonus = 0.02 },
		cats10 = {
			crates = { desert_crate = 2, desert_golden_crate = 1 },
			fish = 55,
			bonus = 0.05,
		},
		gold1 = { fish = 20, crates = { desert_crate = 1 } },
		gold2 = { coins = 300000, coinSeconds = 450, fish = 25 },
		gold4 = { crates = { desert_golden_crate = 1 }, fish = 45 },
		gold6 = { coins = 600000, coinSeconds = 900, fish = 60 },
		gold8 = { crates = { desert_golden_crate = 1 }, fish = 80 },
		gold10 = {
			coins = 1500000,
			coinSeconds = 1800,
			crates = { desert_golden_crate = 2 },
			fish = 135,
			tag = "Desert Gold Master",
		},
	},
	ruins = { -- #2651 (tier6-7-areas.md 7b): about 9 times the Sewer's coins; no goldLuck (the area tracks reach GoldLuckMax)
		cats3 = { coins = 270000, coinSeconds = 300, fish = 20 },
		cats6 = { crates = { ruins_crate = 1 }, lures = { star_treat = 2 }, bonus = 0.02 },
		cats10 = {
			crates = { ruins_crate = 2, ruins_golden_crate = 1 },
			fish = 60,
			bonus = 0.05,
		},
		gold1 = { fish = 20, crates = { ruins_crate = 1 } },
		gold2 = { coins = 900000, coinSeconds = 450, fish = 30 },
		gold4 = { crates = { ruins_golden_crate = 1 }, fish = 50 },
		gold6 = { coins = 1800000, coinSeconds = 900, fish = 65 },
		gold8 = { crates = { ruins_golden_crate = 1 }, fish = 85 },
		gold10 = {
			coins = 4500000,
			coinSeconds = 1800,
			crates = { ruins_golden_crate = 2 },
			fish = 150,
			tag = "Ruins Gold Master",
		},
	},
	all = {
		total5 = { fish = 5, spins = 1, baitSpeed = 0.02 },
		total10 = { fish = 10, crates = { classic_crate = 1 }, baitSpeed = 0.02 },
		total15 = { fish = 10, spins = 2, baitSpeed = 0.02 },
		total20 = { fish = 15, crates = { classic_crate = 1 }, baitSpeed = 0.03 },
		total25 = { fish = 15, crates = { classic_golden_crate = 1 }, baitSpeed = 0.03 },
		total30 = { fish = 20, crates = { highest = 1 }, baitSpeed = 0.03 },
		total35 = { fish = 25, spins = 3, baitSpeed = 0.04 },
		total40 = { fish = 30, crates = { classic_golden_crate = 1 }, baitSpeed = 0.04 },
		total45 = { fish = 40, spins = 3, baitSpeed = 0.05 },
		total50 = {
			fish = 75,
			crates = { classic_golden_crate = 2 },
			spins = 10,
			tag = "Cat Master",
			baitSpeed = 0.10,
		},
		-- #3992: the last bait speed steps take the total from 0.38 to exactly BaitSpeedMax (0.5)
		total55 = { fish = 45, crates = { classic_golden_crate = 1 }, baitSpeed = 0.02 },
		total60 = { fish = 50, spins = 4, baitSpeed = 0.02 },
		total65 = { fish = 60, crates = { highest = 1 }, baitSpeed = 0.02 },
		totalAll = {
			fish = 150,
			crates = { classic_golden_crate = 4 },
			spins = 12,
			tag = "Cat Legend",
			baitSpeed = 0.06,
		},
		-- #1772 (Design-Agent's table on the issue): the gold cats track, a little richer than the totals as gold is
		-- rarer. No gold luck: the five area gold tracks already reach GoldLuckMax, which would eat it
		goldtotal5 = { fish = 10, spins = 1 },
		goldtotal10 = { fish = 15, crates = { classic_golden_crate = 1 } },
		goldtotal15 = { fish = 15, spins = 2 },
		goldtotal20 = { fish = 20, crates = { highest = 1 } },
		goldtotal25 = { fish = 25, crates = { classic_golden_crate = 2 } },
		goldtotal30 = { fish = 30, spins = 3 },
		goldtotal35 = { fish = 40, crates = { highest = 1 } },
		goldtotal40 = { fish = 45, crates = { classic_golden_crate = 2 } },
		goldtotal45 = { fish = 55, spins = 5 },
		goldtotal50 = {
			fish = 125,
			crates = { classic_golden_crate = 4 },
			spins = 10,
			tag = "Golden Paw",
		},
		-- #3992
		goldtotal55 = { fish = 65, crates = { classic_golden_crate = 2 } },
		goldtotal60 = { fish = 75, spins = 6 },
		goldtotal65 = { fish = 90, crates = { highest = 2 } },
		goldtotalAll = {
			fish = 200,
			crates = { classic_golden_crate = 6 },
			spins = 15,
			tag = "Golden Legend",
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
	decor_desert = {
		decor5 = { fish = Config.DecorIndexHalfFish },
		decor10 = { bonus = Config.DecorIndexBonus },
	},
	decor_ruins = {
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
	-- F99 (rainbow-coat.md section 4): the three luck steps add up to RainbowLuckMax (+40%; #2269: was 0.2, 0.3, 0.5)
	rainbow = {
		rainbow1 = { fish = 15, tag = "Rainbow Finder" },
		rainbow3 = { fish = 25, crates = { classic_golden_crate = 1 } },
		rainbow5 = { fish = 40, rainbowLuck = 0.08 },
		rainbow10 = { fish = 50, crates = { classic_golden_crate = 2 }, rainbowLuck = 0.12 },
		rainbow25 = {
			fish = 75,
			crates = { classic_golden_crate = 3 },
			tag = "Rainbow Master",
			rainbowLuck = 0.2,
		},
		-- #3992: rainbow luck is already at RainbowLuckMax after rainbow25, so these add none
		rainbow30 = { fish = 80, crates = { classic_golden_crate = 2 } },
		rainbow35 = { fish = 90, spins = 3 },
		rainbow40 = { fish = 100, crates = { highest = 1 } },
		rainbow45 = { fish = 110, spins = 5 },
		rainbow50 = { fish = 125, crates = { classic_golden_crate = 3 }, tag = "Rainbow Star" },
		rainbow55 = { fish = 140, crates = { highest = 2 } },
		rainbow60 = { fish = 160, spins = 8 },
		rainbow65 = { fish = 180, crates = { classic_golden_crate = 4 } },
		rainbowAll = {
			fish = 300,
			crates = { classic_golden_crate = 6 },
			spins = 15,
			tag = "Rainbow Legend",
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
			fish = 100, -- #2497: was 300
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
		prize = { coins = 1000, coinSeconds = 300, fish = 10 }, -- F94 (was also 2 spins and 3 Tuna); #2497: fish was 25
	},
	-- #1937 (release.md section 4): the first four weeks' codes, coins only (about 10 minutes of income at most, no
	-- fish, spins, potions or crates). Each ships off; that week's small PR turns it on, on its day. Each ends 60 days
	-- after that day (launch-ops.md section 1), at 00:00 UTC. The old `launch` row above stays off and unused.
	opening = {
		id = "opening",
		active = false, -- go wide, Thursday 2026-11-12
		endsAt = 1799625600, -- 2027-01-11
		prize = { coins = 1000, coinSeconds = 300 },
	},
	rally = {
		id = "rally",
		active = false, -- week 1, Saturday 2026-11-14
		endsAt = 1799798400, -- 2027-01-13
		prize = { coins = 1000, coinSeconds = 300 },
	},
	cozy = {
		id = "cozy",
		active = false, -- week 3, Saturday 2026-11-28
		endsAt = 1801008000, -- 2027-01-27
		prize = { coins = 1500, coinSeconds = 450 },
	},
	snowy = {
		id = "snowy",
		active = false, -- week 4, Saturday 2026-12-05, the Winter Cafe's start
		endsAt = 1801612800, -- 2027-02-03
		prize = { coins = 2000, coinSeconds = 600 },
	},
	-- #3148 (Derek2 2026-11-10: "make UPDATE1 a code and 500VISITS no case sensitivity and make them decent"): the
	-- update's code and the 500 visits thank-you, on for everyone with no end. Beside `release` in size and well short
	-- of a tier: coins as minutes of the player's own income, golden fish and one more thing, three pictures each
	-- (rewards rule 3), nothing from the shop's food (rule 1). Typed in any case (Codes.normalize lowercases).
	update1 = {
		id = "update1",
		active = true,
		prize = { coins = 2500, coinSeconds = 900, fish = 50, potions = { lucky_potion = 2 } },
	},
	["500visits"] = {
		id = "500visits",
		active = true,
		prize = { coins = 2000, coinSeconds = 600, fish = 40, crates = { classic_crate = 1 } },
	},
	-- #3576 (Derek 2026-11-12: "add codes for 2000visits,10likes and update2 when it's out"): two thank-you codes, on
	-- as soon as a server has them, and the second update's code, on by the clock at the update (Thursday 2026-11-12
	-- 22:00 UTC; unknown before it). Prizes are Design-Agent's, beside `update1` and `500visits` in size; no end.
	["2000visits"] = {
		id = "2000visits",
		active = true,
		prize = { coins = 2500, coinSeconds = 900, fish = 50, crates = { classic_crate = 2 } },
	},
	["10likes"] = {
		id = "10likes",
		active = true,
		prize = { coins = 2000, coinSeconds = 600, fish = 40, potions = { lucky_potion = 1 } },
	},
	update2 = {
		id = "update2",
		active = true,
		startsAt = 1794520800, -- 2026-11-12 22:00 UTC
		prize = { coins = 2500, coinSeconds = 900, fish = 60, potions = { big_tip_potion = 2 } },
	},
	group = {
		id = "group",
		active = true, -- #1118: on since the game's group (Config.GroupId) is set
		requiresGroup = true,
		-- F94 (was also 5 spins, 2 Caviar and a Tip Potion); #2497: fish was 100
		prize = { coins = 2500, coinSeconds = 900, fish = 40, crates = { classic_crate = 1 } },
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
-- #3665 (Derek 2026-11-12: "buff gold crates chance of legendary / mythic so its not only always epics"): 70, 24, 6
-- (was 80, 17.5, 2.5). A plain crate's lucky twentieth keeps the old numbers in its own table (Crates.LUCKY_ODDS).
local GOLDEN_CRATE_ODDS =
	{ Common = 0, Rare = 0, Epic = 70, Legendary = 24, Mythical = 6 } :: { [string]: number }
-- F101: the Rally Crate is never sold and has no golden twin (`sold` and `golden` false).
local CRATE_POOLS: { { area: string, name: string, sold: boolean?, golden: boolean? } } = {
	{ area = "alley", name = "Alley" },
	{ area = "park", name = "Park" },
	{ area = "neighbourhood", name = "Neighbourhood" },
	{ area = "woods", name = "Woods" },
	{ area = "sewer", name = "Sewer" },
	{ area = "desert", name = "Desert" }, -- #2651 (tier6-7-areas.md 7b)
	{ area = "ruins", name = "Ruins" },
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
	texture: string?, -- #2256: a floor's tiled Top-face image (Types.DecorDef.texture)
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
			-- #2256: CatCafe_Tex_LeafLitter (Model-Agent's #2382), tiled on the floor's Top face over the Ground colour
			texture = "rbxassetid://100787729125099",
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
	-- #2651 (tier6-7-areas.md 7b): the Epics are plain decorations on decor spots, not F48 index_ pieces
	desert = {
		{
			id = "desert_sandstone_blocks",
			name = "Sandstone Blocks",
			kind = "wallpaper",
			rarity = "Common",
			color = Color3.fromRGB(204, 170, 120),
			material = Enum.Material.Sandstone,
			description = "Warm blocks of desert stone.",
		},
		{
			id = "desert_market_stripes",
			name = "Market Stripes",
			kind = "wallpaper",
			rarity = "Rare",
			color = Color3.fromRGB(220, 120, 80),
			material = Enum.Material.Fabric,
			description = "Bright stripes like a desert tent.",
		},
		{
			id = "desert_sand_ripple",
			name = "Sand Ripple",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(232, 205, 150),
			material = Enum.Material.Sand,
			description = "Soft sand swept into little waves.",
		},
		{
			id = "desert_mirage_glass",
			name = "Mirage Glass",
			kind = "floor",
			rarity = "Mythical",
			color = Color3.fromRGB(160, 200, 240),
			material = Enum.Material.Glass,
			description = "A floor that shimmers like heat on the dunes.",
		},
		{
			id = "desert_dune_gold",
			name = "Dune Gold",
			kind = "paint",
			rarity = "Common",
			color = Color3.fromRGB(226, 190, 120),
			material = Enum.Material.SmoothPlastic,
			description = "The colour of sand at noon.",
		},
		{
			id = "desert_oasis_teal",
			name = "Oasis Teal",
			kind = "paint",
			rarity = "Rare",
			color = Color3.fromRGB(64, 168, 160),
			material = Enum.Material.SmoothPlastic,
			description = "Cool water green with sandy trim.",
		},
		{
			id = "desert_cushion_pile",
			name = "Cushion Pile",
			kind = "furniture",
			rarity = "Common",
			description = "A heap of tasselled floor cushions.",
		},
		{
			id = "desert_caravan_bench",
			name = "Caravan Bench",
			kind = "furniture",
			rarity = "Legendary",
			description = "A carved bench under a fringed canopy.",
		},
		{
			id = "desert_lantern_palm",
			name = "Lantern Palm",
			kind = "decoration",
			rarity = "Rare",
			description = "A potted palm hung with tiny lanterns.",
		},
		{
			id = "desert_oasis_fountain",
			name = "Oasis Fountain",
			kind = "decoration",
			rarity = "Epic",
			description = "A little tiled fountain that never runs dry.",
		},
		{
			id = "desert_arch_gate_door",
			name = "Arch Gate Door",
			kind = "door",
			rarity = "Common",
			description = "A pointed arch door with brass studs.",
		},
		{
			id = "desert_sun_disc_flap",
			name = "Sun Disc Flap",
			kind = "catflap",
			rarity = "Rare",
			description = "The flap in a golden sun disc.",
		},
	},
	ruins = {
		{
			id = "ruins_carved_stone",
			name = "Carved Stone",
			kind = "wallpaper",
			rarity = "Common",
			color = Color3.fromRGB(150, 145, 135),
			material = Enum.Material.Slate,
			description = "Old stone carved with tiny cats.",
		},
		{
			id = "ruins_glyph_frieze",
			name = "Glyph Frieze",
			kind = "wallpaper",
			rarity = "Rare",
			color = Color3.fromRGB(196, 170, 128),
			material = Enum.Material.Sandstone,
			description = "A band of gold glyphs around the room.",
		},
		{
			id = "ruins_cracked_flagstone",
			name = "Cracked Flagstone",
			kind = "floor",
			rarity = "Common",
			color = Color3.fromRGB(140, 135, 125),
			material = Enum.Material.Cobblestone,
			description = "Worn flagstones from the temple road.",
		},
		{
			id = "ruins_jade_inlay",
			name = "Jade Inlay",
			kind = "floor",
			rarity = "Mythical",
			color = Color3.fromRGB(80, 160, 120),
			material = Enum.Material.Marble,
			description = "Polished jade tiles with gold lines between them.",
		},
		{
			id = "ruins_moss_stone",
			name = "Moss Stone",
			kind = "paint",
			rarity = "Common",
			color = Color3.fromRGB(120, 130, 110),
			material = Enum.Material.SmoothPlastic,
			description = "Grey-green like a quiet courtyard.",
		},
		{
			id = "ruins_glyph_gold",
			name = "Glyph Gold",
			kind = "paint",
			rarity = "Rare",
			color = Color3.fromRGB(232, 190, 80),
			material = Enum.Material.SmoothPlastic,
			description = "Trim the colour of glowing glyphs.",
		},
		{
			id = "ruins_pillar_table",
			name = "Pillar Table",
			kind = "furniture",
			rarity = "Common",
			description = "A table top on a broken pillar.",
		},
		{
			id = "ruins_stone_throne",
			name = "Stone Throne",
			kind = "furniture",
			rarity = "Legendary",
			description = "A great carved throne, sized for a cat.",
		},
		{
			id = "ruins_brazier_pair",
			name = "Brazier Pair",
			kind = "decoration",
			rarity = "Rare",
			description = "Two little braziers with a soft glow.",
		},
		{
			id = "ruins_gargoyle_statue",
			name = "Gargoyle Statue",
			kind = "decoration",
			rarity = "Epic",
			description = "A friendly gargoyle keeping watch.",
		},
		{
			id = "ruins_temple_gate_door",
			name = "Temple Gate Door",
			kind = "door",
			rarity = "Rare",
			description = "A heavy stone door with a cat-head carving.",
		},
		{
			id = "ruins_keyhole_flap",
			name = "Keyhole Flap",
			kind = "catflap",
			rarity = "Common",
			description = "The flap in a keyhole-shaped arch.",
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
			texture = row.texture,
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

-- #1645 (cafe-pass.md section 3): the Cafe Pass's season decor, earned on its track and owned forever. #2006 (Derek2,
-- 2026-11-07: "make it do something" and "a rarity attached"): each piece has a rarity, Common to Epic (paid pieces
-- stop below the crates' Legendary and Mythical), and the crate pieces' money bonus for it (Config.CratePieceBonus).
-- It has no crate, so it is in no crate pool or Decor Index page and never moves the Index, and it can't be traded
-- (Trade.piece takes crate pieces only) or bought (Economy.decorBlocker). Each piece takes a decor spot like the crate
-- furniture and decorations; they are kept apart in Catalog.passDecor (Catalog.crateDecor is the 84 crate pieces), and
-- the server places them after the crate pieces.
-- #1822: a row with `pack` comes with that game pass instead (the King Cat Pack's booth, granted once by
-- ShopCatService through shared/KingPack), with the same rules; `asset` names a model other than the one
-- its name gives.
local PASS_DECOR: {
	{
		id: string,
		rarity: Types.Rarity,
		name: string,
		kind: Types.DecorKind,
		description: string,
		asset: string?,
		pack: string?,
		passKey: string?,
		bonus: number?, -- #4026: a money bonus other than its rarity's CratePieceBonus
	}
} =
	{
		{
			id = "decor_pumpkin_lantern",
			rarity = "Common",
			name = "Pumpkin Lantern",
			kind = "decoration",
			description = "A friendly cat face, glowing warm.",
		},
		{
			id = "decor_fallen_leaf_rug",
			rarity = "Common",
			name = "Fallen Leaf Rug",
			kind = "decoration",
			description = "A big maple leaf to curl up on.",
		},
		{
			id = "decor_cosy_knit_cushion",
			rarity = "Common",
			name = "Cosy Knit Cushion",
			kind = "furniture",
			description = "A soft knitted pouf in pumpkin bands.",
		},
		{
			id = "decor_hay_bale_seat",
			rarity = "Rare",
			name = "Hay Bale Seat",
			kind = "furniture",
			description = "Harvest time, sit a while.",
		},
		{
			id = "decor_apple_crate_shelf",
			rarity = "Rare",
			name = "Apple Crate Shelf",
			kind = "furniture",
			description = "Crates of red apples, stacked as shelves.",
		},
		{
			id = "decor_maple_tree_planter",
			rarity = "Rare",
			name = "Maple Tree Planter",
			kind = "decoration",
			description = "A little maple in red and orange.",
		},
		-- #1883 part C (levels 32 and 33, Model-Agent's #1921)
		{
			id = "decor_maple_leaf_lamp",
			rarity = "Epic",
			name = "Maple Leaf Lamp",
			kind = "decoration",
			description = "A paper maple leaf, glowing amber day and night.",
		},
		{
			id = "decor_harvest_cider_cart",
			rarity = "Epic",
			name = "Harvest Cider Cart",
			kind = "furniture",
			description = "A barrel of cider, three mugs and a basket of apples.",
		},
		{
			id = "decor_royal_velvet_booth",
			rarity = "Epic",
			name = "Royal Velvet Booth",
			kind = "furniture",
			description = "A deep red booth fit for a king.",
			asset = "CatCafe_Decor_VelvetBooth",
			pack = "Cat King Pack",
		},
		-- #1168 row 3 (Monetization-Agent, 2026-11-06): the Garden Decor Pack pass's six pieces, owned while the pass
		-- is (PassDecor.toGrant, given into decorOwned by ShopCatService). Model-Agent makes the models; the pass id
		-- stays 0 until they are in.
		{
			id = "decor_garden_hanging_fern",
			rarity = "Rare",
			name = "Hanging Fern Basket",
			kind = "decoration",
			description = "A leafy fern spilling from a woven basket.",
			pack = "Garden Decor Pack",
			passKey = "GardenDecorPackPassId",
		},
		{
			id = "decor_garden_sunflower_pot",
			rarity = "Rare",
			name = "Sunflower Pot",
			kind = "decoration",
			description = "Three tall sunflowers in a sunny pot.",
			pack = "Garden Decor Pack",
			passKey = "GardenDecorPackPassId",
		},
		{
			id = "decor_garden_watering_can",
			rarity = "Rare",
			name = "Watering Can Planter",
			kind = "decoration",
			description = "An old tin can, now full of daisies.",
			pack = "Garden Decor Pack",
			passKey = "GardenDecorPackPassId",
		},
		{
			id = "decor_garden_lemon_tree",
			rarity = "Epic",
			name = "Potted Lemon Tree",
			kind = "decoration",
			description = "A little tree with bright lemons.",
			pack = "Garden Decor Pack",
			passKey = "GardenDecorPackPassId",
		},
		{
			id = "decor_garden_ivy_trellis",
			rarity = "Epic",
			name = "Ivy Trellis",
			kind = "furniture",
			description = "A wooden trellis climbing with ivy.",
			pack = "Garden Decor Pack",
			passKey = "GardenDecorPackPassId",
		},
		{
			id = "decor_garden_bench",
			rarity = "Epic",
			name = "Garden Swing Seat",
			kind = "furniture",
			description = "A cosy swing seat wrapped in flowers.",
			pack = "Garden Decor Pack",
			passKey = "GardenDecorPackPassId",
		},
		-- #4026: the four outfit packs' decor pieces (storepacks.py), +25% money each while in use (shared/StorePacks)
		{
			id = "decor_pack_disco_ball",
			rarity = "Legendary",
			name = "Disco Ball",
			kind = "furniture",
			description = "A mirror ball on a stand, with coloured spots.",
			pack = "Stylish Pack",
			passKey = "StylishPackPassId",
			bonus = 0.25,
		},
		{
			id = "decor_pack_cocoa_stand",
			rarity = "Legendary",
			name = "Cocoa Stand",
			kind = "furniture",
			description = "A little cart of hot cocoa and marshmallows.",
			pack = "Winter Pack",
			passKey = "WinterPackPassId",
			bonus = 0.25,
		},
		{
			id = "decor_pack_pastry_case",
			rarity = "Legendary",
			name = "Pastry Case",
			kind = "furniture",
			description = "A glass case full of fresh pastries.",
			pack = "Chef Pack",
			passKey = "ChefPackPassId",
			bonus = 0.25,
		},
		{
			id = "decor_pack_rocket_lamp",
			rarity = "Legendary",
			name = "Rocket Lamp",
			kind = "furniture",
			description = "A rocket lamp that glows like the stars.",
			pack = "Space Pack",
			passKey = "SpacePackPassId",
			bonus = 0.25,
		},
	}
Catalog.passDecor = {} :: { Types.DecorDef }
for _, row in PASS_DECOR do
	local bonus = row.bonus or Config.CratePieceBonus[row.rarity]
	local def: Types.DecorDef = {
		id = row.id,
		name = row.name,
		cost = 0,
		category = KIND_CATEGORY[row.kind],
		effect = string.format("+%d%% money while in use", math.floor(bonus * 100 + 0.5)),
		description = row.description,
		bonus = bonus,
		rarity = row.rarity,
		asset = row.asset or "CatCafe_Decor_" .. (row.name:gsub("[^%w]", "")),
		source = "pass",
		kind = row.kind,
		pack = row.pack,
		passKey = row.passKey,
	}
	Catalog.decorById[row.id] = def
	table.insert(Catalog.passDecor, def)
end

-- #2486 (live-events.md section 2e): each Cafe Event's free reward piece, by the cosmeticId its record names. It is
-- given by catching a cat during the event (CafeEvents.reward), comes back at later events, is never sold and only
-- trades as other decor does. It joins Catalog.passDecor, the pieces that stand on the next free decor spots, with
-- source "event". Model-Agent makes the models (#2488).
local EVENT_DECOR: { { id: string, rarity: Types.Rarity, name: string, kind: Types.DecorKind, description: string } } =
	{
		{
			id = "Decor_PartyBunting",
			rarity = "Rare",
			name = "Party Bunting",
			kind = "decoration",
			description = "Bright flags from the Cafe Party.",
		},
	}
Catalog.eventDecor = {} :: { Types.DecorDef }
for _, row in EVENT_DECOR do
	local bonus = Config.CratePieceBonus[row.rarity]
	local def: Types.DecorDef = {
		id = row.id,
		name = row.name,
		cost = 0,
		category = KIND_CATEGORY[row.kind],
		effect = string.format("+%d%% money while in use", math.floor(bonus * 100 + 0.5)),
		description = row.description,
		bonus = bonus,
		rarity = row.rarity,
		asset = "CatCafe_" .. row.id,
		source = "event",
		kind = row.kind,
	}
	Catalog.decorById[row.id] = def
	table.insert(Catalog.passDecor, def)
	table.insert(Catalog.eventDecor, def)
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

-- The Rescue Rally's steps (F101, rescue-rally.md section 3), in order. #2018 (Derek2 2026-11-07: "increase amount
-- and how good of rewards from rally and how often you hit milestones"): five steps, not three, about 100 golden fish
-- and two Rally Crates a lap (was 30 and one). The bar then empties for the next lap.
Catalog.rallySteps = {
	{ share = 0.15, prize = { fish = 5 } }, -- #2237 fish: was 8, 12, 18, 25, 40
	{ share = 0.3, prize = { fish = 7, potions = { tip_potion = 1 } } },
	{ share = 0.5, prize = { fish = 10, potions = { swift_potion = 1, steady_potion = 1 } } },
	{ share = 0.75, prize = { fish = 15, crates = { rally_crate = 1 } } },
	{
		share = 1,
		prize = { fish = 25, crates = { rally_crate = 1 }, potions = { big_tip_potion = 1 } },
	},
} :: { Types.RallyStep }

-- The Golden Fish Market (F53, golden-fish.md section 3): what golden fish buy. Crates open at once; a perk is
-- forever: Golden Espresso +5% tips a level, Big Bowl a shorter bait wait, Extra Decor Spot one more decor spot a
-- level, Swift Paws a little walk speed a level (#3063), Lucky Charm +0.1 Luck a level (#3298).
Catalog.fishShop = {} :: { Types.FishShopRow }
local function shopRow(row: Types.FishShopRow)
	table.insert(Catalog.fishShop, row)
end
for _, def in Catalog.crates do
	if def.price ~= nil then
		shopRow({ id = def.id, kind = "crate", cost = def.price })
	end
end
-- #3317 (Derek2 2026-11-11: "move to the top of perks"): Swift Paws first, five levels (shared/SwiftPaws; Monetization-
-- Agent's prices, 1,810 fish in all). The Star Treat's row (150 fish) is gone from the Market only (Derek2: "remove
-- star treat from fish market"); it still comes from the Daily Treat, the Dealer and prizes, and saved ones stay.
shopRow({ id = "swift_paws", kind = "perk", costs = { 60, 150, 300, 500, 800 }, maxLevel = 5 })
shopRow({ id = "golden_espresso", kind = "perk", costs = { 40, 80, 150, 250, 400 }, maxLevel = 5 })
shopRow({ id = "big_bowl", kind = "perk", costs = { 150 }, maxLevel = 1 })
shopRow({ id = "extra_decor_spot", kind = "perk", costs = { 100, 250 }, maxLevel = 2 })
-- #3298 (new-activities.md section 5): Lucky Charm, +0.1 overall Luck a level (shared/LuckyCharm), 850 fish in all.
-- Hidden and not sold until the `luckyCharm` switch is on.
shopRow({ id = "lucky_charm", kind = "perk", costs = { 100, 250, 500 }, maxLevel = 3 })

Catalog.fishShopById = {} :: { [string]: Types.FishShopRow }
for _, row in Catalog.fishShop do
	Catalog.fishShopById[row.id] = row
end

function Catalog.getFishShopRow(id: string): Types.FishShopRow?
	return Catalog.fishShopById[id]
end

-- #2565 (mystery-market.md section 4d): Juniper's Mystery Market shelf, in rotation order (shared/MysteryMarket). The
-- launch shelf is the Backpack and the Long Net (Derek2, 2026-11-09), and the Backpack is the launch week's sale.
-- Golden fish only, bought once, never random and never sold for Robux. New items go at the end, so the weeks
-- already announced keep their item.
Catalog.mysteryItems = {
	{
		id = "backpack",
		name = "Backpack",
		text = "Carry 2 cats! The first rides on your back.",
		cost = 400,
		minTier = 1,
		kind = "tool",
	},
	{
		id = "long_net",
		name = "Long Net",
		text = "Your net reaches a stud further.",
		cost = 320,
		minTier = 2,
		kind = "tool",
	},
	-- #3535: carry speed only (shared/SpeedShoes); hidden and not sold while its live switch is off
	{
		id = "speed_shoes",
		name = "Speed Shoes",
		text = "Carry cats faster!",
		cost = 500,
		minTier = 1,
		kind = "tool",
		flag = "speedShoes",
	},
} :: { Types.MysteryItem }

Catalog.mysteryItemsById = {} :: { [string]: Types.MysteryItem }
for _, item in Catalog.mysteryItems do
	Catalog.mysteryItemsById[item.id] = item
end

function Catalog.getMysteryItem(id: string): Types.MysteryItem?
	return Catalog.mysteryItemsById[id]
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

-- The Corner Shop v2 (corner-shop-v2.md section 1, #1180; the stall from corner-shop.md, #1052): sold for coins only,
-- in this order, at a fixed `price` that never follows income, tier or a pass. Each row's amount in a window is
-- rolled by its place in the list by price (#1577, the Day Cart, shared/CornerShop); `needsTier` hides and refuses it below
-- that tier. Nothing random, nothing that raises income, nothing for golden fish or Robux. Prices v3 (#1385): x10
-- for Small, x20 for regular and x40 for Big and Mega on the v2 prices.
Catalog.cornerShop = {
	{
		id = "swift_potion_small",
		name = "Small Swift Potion",
		family = "swift",
		size = "small",
		kind = "potion",
		potionId = "swift_potion_small",
		price = 3000,
	},
	{
		id = "swift_potion",
		name = "Swift Potion",
		family = "swift",
		size = "regular",
		kind = "potion",
		potionId = "swift_potion",
		price = 100000,
	},
	{
		id = "swift_potion_big",
		name = "Big Swift Potion",
		family = "swift",
		size = "big",
		kind = "potion",
		potionId = "swift_potion_big",
		price = 20000000,
		needsTier = 3,
	},
	{
		id = "steady_potion_small",
		name = "Small Steady Paw Potion",
		family = "steady",
		size = "small",
		kind = "potion",
		potionId = "steady_potion_small",
		price = 10000,
	},
	{
		id = "steady_potion",
		name = "Steady Paw Potion",
		family = "steady",
		size = "regular",
		kind = "potion",
		potionId = "steady_potion",
		price = 400000,
	},
	{
		id = "steady_potion_big",
		name = "Big Steady Paw Potion",
		family = "steady",
		size = "big",
		kind = "potion",
		potionId = "steady_potion_big",
		price = 80000000,
		needsTier = 3,
	},
	{
		id = "quick_bait_potion_small",
		name = "Small Quick Bait Potion",
		family = "quick_bait",
		size = "small",
		kind = "potion",
		potionId = "quick_bait_potion_small",
		price = 25000,
	},
	{
		id = "quick_bait_potion",
		name = "Quick Bait Potion",
		family = "quick_bait",
		size = "regular",
		kind = "potion",
		potionId = "quick_bait_potion",
		price = 1200000,
	},
	{
		id = "quick_bait_potion_big",
		name = "Big Quick Bait Potion",
		family = "quick_bait",
		size = "big",
		kind = "potion",
		potionId = "quick_bait_potion_big",
		price = 240000000,
		needsTier = 3,
	},
	-- #3118 (Derek2 2026-11-10: the Fresh Catch is gone, "add any item that could be found in there to the day cart for
	-- an appropriate price based on how good the item is"): its four potions the cart didn't sell, priced from their
	-- old golden fish prices against Steady (12 fish, 400K) and Quick Bait (15 fish, 1.2M). The cart's "nothing that
	-- raises income" rule is lifted for these by that ask; every one is capped a day (Config.CornerDailyLimits).
	-- Monetization-Agent's pass: Big Money is Tier 4 and about 30 minutes of a Tier 4 income (~300M an hour, Tier 4 to
	-- 5 in economy-ladder.md v4), so its +50% for 30 minutes is a coin sink, not a skip; Money is Tier 3 and 3 a day.
	-- At most +75% for half an hour a day with both running: never a quiet 2x.
	{
		id = "tip_potion",
		name = "Money Potion",
		family = "money",
		size = "regular",
		kind = "potion",
		potionId = "tip_potion",
		price = 5000000,
		needsTier = 3,
	},
	{
		id = "lucky_potion",
		name = "Lucky Potion",
		family = "lucky",
		size = "regular",
		kind = "potion",
		potionId = "lucky_potion",
		price = 1500000,
	},
	{
		id = "big_tip_potion",
		name = "Big Money Potion",
		family = "big_money",
		size = "regular",
		kind = "potion",
		potionId = "big_tip_potion",
		price = 150000000,
		needsTier = 4,
	},
	{
		id = "gold_rush_potion",
		name = "Gold Rush Potion",
		family = "gold_rush",
		size = "regular",
		kind = "potion",
		potionId = "gold_rush_potion",
		price = 3000000,
	},
	{
		id = "small_cat_snack",
		name = "Small Snack",
		family = "food",
		size = "small",
		kind = "food",
		foodId = "small_cat_snack",
		xp = 600,
		price = 4000,
	},
	{
		id = "cat_snack",
		name = "Cat Snack",
		family = "food",
		size = "regular",
		kind = "food",
		foodId = "cat_snack",
		xp = 2000,
		price = 300000,
	},
	{
		id = "big_cat_snack",
		name = "Big Snack",
		family = "food",
		size = "big",
		kind = "food",
		foodId = "big_cat_snack",
		xp = 6000,
		price = 40000000,
		needsTier = 3,
	},
	{
		id = "cat_feast",
		name = "Cat Feast",
		family = "food",
		size = "mega",
		kind = "food",
		foodId = "cat_feast",
		xp = 20000,
		price = 3200000000,
		needsTier = 4,
	},
	-- #1281 (corner-shop-v2.md section 1b): the three shop bait foods, sold here instead of at the bowl. `price` is
	-- filled in below from the food's cost (its Tier 1 price, which places it in the Day Cart's list); the buy charges
	-- Economy.foodPrice for the buyer's tier. No daily limit.
	{
		id = "kibble",
		name = "Kibble",
		family = "bait",
		size = "small",
		kind = "bait",
		lureId = "kibble",
		price = 0,
	},
	{
		id = "tuna",
		name = "Tuna",
		family = "bait",
		size = "regular",
		kind = "bait",
		lureId = "tuna",
		price = 0,
	},
	{
		id = "salmon",
		name = "Salmon",
		family = "bait",
		size = "big",
		kind = "bait",
		lureId = "salmon",
		price = 0,
	},
	-- #3462: the three Tier 6 potions, in the billions, one of each a game day (Config.CornerDailyLimits). Top shelf
	-- rows like the two baits below, so they sit with them at the end of this list
	{
		id = "big_lucky_potion",
		name = "Big Lucky Potion",
		family = "big_lucky",
		size = "regular",
		kind = "potion",
		potionId = "big_lucky_potion",
		price = 5000000000,
		needsTier = 6,
		topShelf = true,
	},
	{
		id = "big_gold_rush_potion",
		name = "Big Gold Rush Potion",
		family = "big_gold_rush",
		size = "regular",
		kind = "potion",
		potionId = "big_gold_rush_potion",
		price = 8000000000,
		needsTier = 6,
		topShelf = true,
	},
	{
		id = "mega_tip_potion",
		name = "Mega Money Potion",
		family = "mega_money",
		size = "regular",
		kind = "potion",
		potionId = "mega_tip_potion",
		price = 20000000000,
		needsTier = 6,
		topShelf = true,
	},
	-- #3462: the cart's own baits, Tier 6 and up, at the flat price of their Catalog.lures rows. They are top shelf
	-- rows (shared/CornerShop): nothing shows or sells until the `cartTier6` switch is on, which waits for every
	-- server to run a build that knows their ids. Top shelf rows stay the last rows of this list.
	{
		id = "honey_cream",
		name = "Honey Cream",
		family = "bait",
		size = "big",
		kind = "bait",
		lureId = "honey_cream",
		price = 1000000000,
		needsTier = 6,
		topShelf = true,
	},
	{
		id = "comet_treat",
		name = "Comet Treat",
		family = "bait",
		size = "mega",
		kind = "bait",
		lureId = "comet_treat",
		price = 3000000000,
		needsTier = 6,
		topShelf = true,
	},
} :: { Types.CornerShopRow }
Catalog.cornerShopById = {} :: { [string]: Types.CornerShopRow }
for _, row in Catalog.cornerShop do
	local lure = if row.lureId ~= nil then Catalog.luresById[row.lureId] else nil
	if lure ~= nil then
		row.price = lure.cost -- its Tier 1 price (FoodTierPriceFactor[1] is 1)
	end
	Catalog.cornerShopById[row.id] = row
	table.freeze(row)
end
table.freeze(Catalog.cornerShop)

function Catalog.getCornerShopRow(id: string): Types.CornerShopRow?
	return Catalog.cornerShopById[id]
end

-- Cat food (corner-shop-v2.md section 3, #1181): kept in the Bag and fed to one cat at any time (FeedCat), each
-- giving `xp` to that cat. Bought at the Corner Shop or earned (the Daily Treat, rescues, catches, the Collector).
Catalog.catFood = {
	{ id = "small_cat_snack", name = "Small Snack", xp = 600 },
	{ id = "cat_snack", name = "Cat Snack", xp = 2000 },
	{ id = "big_cat_snack", name = "Big Snack", xp = 6000 },
	{ id = "cat_feast", name = "Cat Feast", xp = 20000 },
} :: { Types.CatFoodDef }
Catalog.catFoodById = {} :: { [string]: Types.CatFoodDef }
for _, food in Catalog.catFood do
	Catalog.catFoodById[food.id] = food
	table.freeze(food)
end
table.freeze(Catalog.catFood)

function Catalog.getCatFood(id: string): Types.CatFoodDef?
	return Catalog.catFoodById[id]
end

-- #1182 step 1: the developer products whose contents are set (shop-and-pass-plan 2026-11-01, #1186, #1191; the
-- Starter Bundle waits on Sprinkles' model and the Cafe Pass paid tier is on hold). Each sells under
-- Config.ProductIds[id] once it is made in Creator Hub; until then its id is 0 and it is never granted.
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
	-- the mixes for M (10) and L (20 + 2 bonus) set in #1186 and #1191
	{
		id = "potion_pack_m",
		name = "Potion Pack M",
		prize = { potions = { big_tip_potion = 5, swift_potion = 3, steady_potion = 2 } },
	},
	{
		id = "potion_pack_l",
		name = "Potion Pack L",
		prize = { potions = { big_tip_potion = 10, swift_potion = 6, steady_potion = 6 } },
	},
	-- #1168 row 8 (Monetization-Agent, 2026-11-06): R$25, repeatable, 10 Steady Paw potions (easier catch circles only)
	{
		id = "steady_paw_pack",
		name = "Steady Paw Pack",
		prize = { potions = { steady_potion = 10 } },
	},
	-- #1625 (store-skus.md): R$99, once per account. Sprinkles, 10 Big Money, 5 Swift and the Bakery Stripes sign.
	-- #2850 (Derek2): plus 5 Steady Paw and 2x money for good, like the 2x Money pass (the higher one counts).
	{
		id = "starter_bundle",
		name = "Starter Bundle",
		oncePerAccount = true,
		prize = {
			potions = { big_tip_potion = 10, swift_potion = 5, steady_potion = 5 },
			moneyMultiplier = 2,
			-- #4020: a buyer who already has 2x Money or more (a Money pass) gets these instead of the 2x (no Lucky: a Robux
			-- item never holds odds potions, Products.ALLOWED_POTIONS)
			moneySwap = { big_tip_potion = 10, swift_potion = 5 },
			cats = { "sprinkles" },
			signStyles = { "bakery_stripes" },
		},
	},
	-- #1168 row 4 (Monetization-Agent, 2026-11-06): R$25, once per account, no gameplay effect. It marks the buyer a
	-- supporter (Products.isSupporter): a gold heart by their name on the Thank You board and a "[Thank You]" chat tag.
	{
		id = "thank_you_badge",
		name = "Thank You Badge",
		oncePerAccount = true,
		supporter = true,
		prize = { potions = {} },
	},
	-- #1626 (cafe-pass.md section 1): the paid track of the season running when it is bought. It holds no potions:
	-- everything comes from the track's levels as they are reached (CafePassService).
	{
		id = "cafe_pass",
		name = "Cafe Pass",
		seasonPass = true,
		prize = { potions = {} },
	},
	-- #3864 (Derek 2026-11-13: "a big trait reroll bundle ... advertised after using the mystic pool free spins", "lets
	-- do 199 robux", "smaller one of 20 for 99 robux"): Trait Tokens, one roll each. Repeatable. Offered on the Mystic
	-- Pool card with the roll's odds (shared/Traits.BUNDLES, traitBundles switch).
	{
		id = "trait_tokens_20",
		name = "20 Trait Tokens",
		prize = { potions = {}, traitTokens = 20 },
	},
	{
		id = "trait_tokens_50",
		name = "50 Trait Tokens",
		prize = { potions = {}, traitTokens = 50 },
	},
	-- #3996 (todays-deal-3996.md section 2): Today's Deal, R$25 each, one a UTC day (shared/DailyDeal). Fixed contents;
	-- deal 2's tokens are offered only where the token bundles may be.
	{
		id = "deal_1",
		name = "Today's Deal: Big Money",
		prize = { potions = { big_tip_potion = 5, swift_potion = 2 } },
	},
	{
		id = "deal_2",
		name = "Today's Deal: Trait Tokens",
		prize = { potions = {}, traitTokens = 7 },
	},
	{
		id = "deal_3",
		name = "Today's Deal: Steady Paw",
		prize = { potions = { steady_potion = 10, big_tip_potion = 2 } },
	},
	{
		id = "deal_4",
		name = "Today's Deal: Potion Mix",
		prize = { potions = { big_tip_potion = 4, swift_potion = 1, steady_potion = 2 } },
	},
} :: { Types.ProductDef }
Catalog.productsById = {} :: { [string]: Types.ProductDef }
for _, product in Catalog.products do
	Catalog.productsById[product.id] = product
	table.freeze(product.prize.potions)
	if product.prize.cats ~= nil then
		table.freeze(product.prize.cats)
	end
	if product.prize.signStyles ~= nil then
		table.freeze(product.prize.signStyles)
	end
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
-- models (#750; the stations #1348, #1349 and #1351 since #1319) stand at Layout.campExtras; shared/CampExtras
-- holds their rules.
Catalog.campExtras = {
	{
		id = "picnic",
		area = "park",
		name = "Picnic Basket",
		model = "CatCafe_Camp_Park_PicnicStation", -- #1133 (#1348)
		kind = "collect",
	},
	{
		id = "yardSale",
		area = "neighbourhood",
		name = "Yard Sale",
		model = "CatCafe_Camp_Neighbourhood_YardSaleStall", -- #1154 (#1349)
		kind = "shop",
	},
	{
		id = "pond",
		area = "woods",
		name = "Fish Pond",
		model = "CatCafe_Camp_Woods_FishingHut", -- #1232 (#1351)
		kind = "collect",
	},
	{
		id = "lostFound",
		area = "sewer",
		name = "Lost and Found",
		model = "CatCafe_Camp_Sewer_LostFoundBooth", -- #1732: the lost-property kiosk, was the small crate
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
-- fence styles, bought with coins at the Garden Nursery in the Park (lawn-nursery.md, #1200) at the tier that sells
-- them. Each has a `rarity` and costs that rarity's Catalog.lawnRarityPrices rung (lawn-nursery.md section 1), fixed
-- coins, the same with or without a money pass.
-- Models are Model-Agent's (#673, style guide section 13).
-- lawn-nursery.md section 1 (#1200): the fixed coin price of each lawn rarity, about 5 times a step and 10 at the top
Catalog.lawnRarityPrices = table.freeze({
	Common = 10000,
	Uncommon = 50000,
	Rare = 250000,
	Epic = 1000000,
	Legendary = 5000000,
	Mythical = 50000000,
	Golden = 500000000,
}) :: { [string]: number }

Catalog.lawn = {
	{
		id = "tulip_bed",
		name = "Tulip Bed",
		spot = "small",
		tier = 2, -- #1382 / lawn-nursery.md section 2: Commons open at Tier 2 (was 1)
		rarity = "Common",
		price = 10000,
		model = "CatCafe_Lawn_TulipBed",
	},
	{
		id = "sandwich_board",
		name = "Sandwich Board",
		spot = "small",
		tier = 2, -- #1382 / lawn-nursery.md section 2: Commons open at Tier 2 (was 1)
		rarity = "Common",
		price = 10000,
		model = "CatCafe_Lawn_SandwichBoard",
	},
	{
		id = "potted_cat_topiary",
		name = "Potted Cat Topiary",
		spot = "small",
		tier = 1,
		rarity = "Uncommon",
		price = 50000,
		model = "CatCafe_Lawn_PottedCatTopiary",
	},
	{
		id = "mailbox",
		name = "Mailbox",
		spot = "small",
		tier = 1,
		rarity = "Uncommon",
		price = 50000,
		model = "CatCafe_Lawn_Mailbox",
	},
	{
		id = "lamp_post",
		name = "Lamp Post",
		spot = "small",
		tier = 2,
		rarity = "Rare",
		price = 250000,
		model = "CatCafe_Lawn_LampPost",
	},
	{
		id = "bird_bath",
		name = "Bird Bath",
		spot = "small",
		tier = 2,
		rarity = "Rare",
		price = 250000,
		model = "CatCafe_Lawn_BirdBath",
	},
	{
		id = "garden_gnome_cat",
		name = "Garden Gnome Cat",
		spot = "small",
		tier = 2,
		rarity = "Rare",
		price = 250000,
		model = "CatCafe_Lawn_GardenGnomeCat",
	},
	{
		id = "bicycle_with_basket",
		name = "Bicycle with Basket",
		spot = "big",
		tier = 2,
		rarity = "Epic",
		price = 1000000,
		model = "CatCafe_Lawn_BicycleWithBasket",
	},
	{
		id = "garden_bench",
		name = "Garden Bench",
		spot = "big",
		tier = 2,
		rarity = "Epic",
		price = 1000000,
		model = "CatCafe_Lawn_GardenBench",
	},
	{
		id = "umbrella_table",
		name = "Umbrella Table",
		spot = "big",
		tier = 3,
		rarity = "Legendary",
		price = 5000000,
		model = "CatCafe_Lawn_UmbrellaTable",
	},
	{
		id = "little_fountain",
		name = "Little Fountain",
		spot = "big",
		tier = 3,
		rarity = "Legendary",
		price = 5000000,
		model = "CatCafe_Lawn_LittleFountain",
	},
	{
		id = "fairy_light_arch",
		name = "Fairy Light Arch",
		spot = "big",
		tier = 4,
		rarity = "Mythical",
		price = 50000000,
		model = "CatCafe_Lawn_FairyLightArch",
	},
	{
		id = "flower_cart",
		name = "Flower Cart",
		spot = "big",
		tier = 4,
		rarity = "Mythical",
		price = 50000000,
		model = "CatCafe_Lawn_FlowerCart",
	},
	{
		id = "balloon_bunch",
		name = "Balloon Bunch",
		spot = "small",
		tier = 4,
		rarity = "Legendary",
		price = 5000000,
		model = "CatCafe_Lawn_BalloonBunch",
	},
	{
		id = "cat_tree_sign",
		name = "Cat Tree Sign",
		spot = "big",
		tier = 5,
		rarity = "Golden",
		price = 500000000,
		model = "CatCafe_Lawn_CatTreeSign",
	},
	{
		id = "golden_paw_statue",
		name = "Golden Paw Statue",
		spot = "big",
		tier = 5,
		rarity = "Golden",
		price = 500000000,
		model = "CatCafe_Lawn_GoldenPawStatue",
	},
	-- #3222 (Derek2 2026-11-11: "add golden decor's that are a super low drop chance like the 12%'s you can get from
	-- p2w"): Golden pieces nobody can buy, found only as a rare drop from a freed cat (Lawn.dropPick). Model-Agent's
	-- models (PR #3228). `price` is the Golden rung of the ladder for the specs and the trade value, never charged.
	{
		id = "golden_cat_fountain",
		name = "Golden Cat Fountain",
		spot = "big",
		tier = 5,
		rarity = "Golden",
		price = 500000000,
		model = "CatCafe_Lawn_GoldenCatFountain",
		drop = true,
	},
	{
		id = "golden_cat_throne",
		name = "Golden Cat Throne",
		spot = "big",
		tier = 5,
		rarity = "Golden",
		price = 500000000,
		model = "CatCafe_Lawn_GoldenCatThrone",
		drop = true,
	},
	{
		id = "golden_yarn_kitten",
		name = "Golden Yarn Kitten",
		spot = "big",
		tier = 5,
		rarity = "Golden",
		price = 500000000,
		model = "CatCafe_Lawn_GoldenYarnKitten",
		drop = true,
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
		tier = 2, -- #1382 / lawn-nursery.md section 2: Commons open at Tier 2 (was 1)
		rarity = "Common",
		price = 10000,
		model = "CatCafe_Lawn_Path_RedBrick",
	},
	{
		id = "stepping_stones",
		name = "Stepping Stones",
		kind = "path",
		tier = 2,
		rarity = "Uncommon",
		price = 50000,
		model = "CatCafe_Lawn_Path_SteppingStones",
	},
	{
		id = "paw_print_path",
		name = "Paw Print Path",
		kind = "path",
		tier = 3,
		rarity = "Epic",
		price = 1000000,
		model = "CatCafe_Lawn_Path_PawPrintPath",
	},
	{
		id = "white_picket",
		name = "White Picket",
		kind = "fence",
		tier = 2, -- #1382 / lawn-nursery.md section 2: Commons open at Tier 2 (was 1)
		rarity = "Common",
		price = 10000,
		model = "CatCafe_Lawn_Fence_WhitePicket",
	},
	{
		id = "low_hedge",
		name = "Low Hedge",
		kind = "fence",
		tier = 2,
		rarity = "Uncommon",
		price = 50000,
		model = "CatCafe_Lawn_Fence_LowHedge",
	},
	{
		id = "iron_railing",
		name = "Iron Railing",
		kind = "fence",
		tier = 3,
		rarity = "Epic",
		price = 1000000,
		model = "CatCafe_Lawn_Fence_IronRailing",
	},
	{
		id = "flower_box_fence",
		name = "Flower Box Fence",
		kind = "fence",
		tier = 4,
		rarity = "Mythical",
		price = 50000000,
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
