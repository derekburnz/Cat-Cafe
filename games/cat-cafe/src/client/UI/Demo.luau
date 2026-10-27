--!strict
-- The shared catalog plus a pretend server, so the UI runs in Studio with no backend.
-- Usage from any LocalScript: require the UI module and call UI.demo()
-- Everything here is client-side pretend money. Delete or leave unused in production.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BugReport = require(Shared:WaitForChild("BugReport"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Config = require(Shared:WaitForChild("Config"))
local DecorPieces = require(script.Parent.Components.DecorPieces)
local Format = require(script.Parent.Components.Format)
local IndexRewards = require(script.Parent.Components.IndexRewards)
local MarketLogic = require(script.Parent.Components.MarketLogic)
local RankUp = require(script.Parent.Screens.RankUp)
local RescueMarker = require(Shared:WaitForChild("RescueMarker"))
local Settings = require(Shared:WaitForChild("Settings"))
local Types = require(script.Parent.Types)

local Demo = {}

local function now(): number
	return os.time()
end

-- data-model section 11b's Tip Jar rows, until the engineer's Catalog.tipJar lands
local DEMO_TIP_JAR: { Types.TipJarRow } = {
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
	{ step = 12, minutes = 120, kind = "lure", lureId = "caviar", count = 1, spins = 1, fish = 5 },
}

-- data-model section 11c's Spin Wheel slices, until the engineer's Catalog.spinWheel lands
local DEMO_SPIN_WHEEL: { Types.SpinRow } = {
	{ slice = 1, kind = "coins", seconds = 120, minCoins = 200, weight = 30 },
	{ slice = 2, kind = "lure", lureId = "tuna", count = 3, weight = 22 },
	{ slice = 3, kind = "coins", seconds = 600, minCoins = 1000, weight = 18 },
	{ slice = 4, kind = "lure", lureId = "salmon", count = 2, weight = 15 },
	{ slice = 5, kind = "fish", count = 4, weight = 10 }, -- F54, golden-fish.md section 6
	{ slice = 6, kind = "crate", crate = "highest", count = 1, weight = 5 },
}

-- data-model section 11b's Index milestones and prizes, until the engineer's Catalog.indexMilestones and
-- Catalog.indexPrizes land
local DEMO_INDEX_MILESTONES: { Types.IndexMilestone } = {
	{ id = "cats3", need = 3 },
	{ id = "cats6", need = 6 },
	{ id = "cats10", need = 10 },
	{ id = "gold10", need = 10, gold = true },
}
local function indexPrizes(
	coins: number,
	six: string,
	ten: { [string]: number },
	areaId: string
): { [string]: Types.IndexPrize }
	return {
		cats3 = { coins = coins },
		cats6 = { lures = { [six] = 2 } },
		cats10 = { lures = ten, decorId = "index_" .. areaId },
		gold10 = { decorId = "index_" .. areaId .. "_gold" },
	}
end
local DEMO_INDEX_PRIZES: { [string]: { [string]: Types.IndexPrize } } = {
	alley = indexPrizes(300, "tuna", { salmon = 1 }, "alley"),
	park = indexPrizes(1000, "salmon", { caviar = 1 }, "park"),
	neighbourhood = indexPrizes(3000, "caviar", { moon_milk = 1 }, "neighbourhood"),
	woods = indexPrizes(10000, "moon_milk", { star_treat = 1 }, "woods"),
	sewer = indexPrizes(30000, "star_treat", { star_treat = 2 }, "sewer"),
}

-- golden-fish.md section 4's draft pieces (names can change), until the engineer's F53 pieces land: per crate,
-- "name/rarity/kind" for its ten cosmetics. They stand in for Catalog.crateDecor and fill the crates, so the
-- Market's odds card and reveal, the Decor screen's style slots and spots, and the Decor Index have something to
-- show.
local DEMO_PIECE_ROWS: { [string]: { string } } = {
	alley = {
		"Brick Wall/C/wallpaper",
		"Midnight Sky/M/wallpaper",
		"Subway Tile/C/floor",
		"Puddle Glass/R/floor",
		"Fire Escape Red/C/paint",
		"Graffiti Pastel/R/paint",
		"Milk Crate Stools/C/furniture",
		"Retro Jukebox/L/furniture",
		"Jar Lights/R/decoration",
		"Alley Mural Print/E/decoration",
	},
	park = {
		"Leafy Vines/C/wallpaper",
		"Meadow Mural/R/wallpaper",
		"Garden Path/C/floor",
		"Clover Carpet/R/floor",
		"Meadow Green/C/paint",
		"Duck Pond Blue/C/paint",
		"Picnic Table Set/R/furniture",
		"Park Bench/E/furniture",
		"Duck Fountain/L/decoration",
		"Blossom Tree/M/decoration",
	},
	neighbourhood = {
		"Picket Stripes/C/wallpaper",
		"Kitchen Gingham/R/wallpaper",
		"Checker Kitchen/C/floor",
		"Porch Planks/C/floor",
		"Pastel Pink/C/paint",
		"Rainbow Shimmer/M/paint",
		"Porch Swing/R/furniture",
		"Ice Cream Counter/L/furniture",
		"Bicycle Planter/R/decoration",
		"Mailbox Planter/E/decoration",
	},
	woods = {
		"Birch Bark/C/wallpaper",
		"Aurora Sky/M/wallpaper",
		"Mossy Planks/C/floor",
		"Leaf Litter/R/floor",
		"Forest Green/C/paint",
		"Toadstool Red/R/paint",
		"Log Stools/C/furniture",
		"Hollow Log Booth/L/furniture",
		"Lantern Stump/R/decoration",
		"Mushroom Lamp/E/decoration",
	},
	sewer = {
		"Pipe Works/C/wallpaper",
		"Bottle Cap Mosaic/R/wallpaper",
		"Canal Tile/C/floor",
		"Glimmer Canal/M/floor",
		"Brass Teal/C/paint",
		"Copper Patina/R/paint",
		"Crate Shelf/C/furniture",
		"Bathtub Sofa/L/furniture",
		"Rubber Duck Row/R/decoration",
		"Pipe Fountain/E/decoration",
	},
	classic = {
		"Cream Stripes/C/wallpaper",
		"Paw Print/R/wallpaper",
		"Oak Boards/C/floor",
		"Black and White Tile/C/floor",
		"Latte Brown/C/paint",
		"Gold Leaf/M/paint",
		"Bistro Set/R/furniture",
		"Velvet Booth/E/furniture",
		"Hanging Plants/R/decoration",
		"Cat Tree Tower/L/decoration",
	},
}
local DEMO_RARITY: { [string]: string } =
	{ C = "Common", R = "Rare", E = "Epic", L = "Legendary", M = "Mythical" }
local DEMO_BONUS: { [string]: number } =
	{ Common = 0.02, Rare = 0.04, Epic = 0.08, Legendary = 0.15, Mythical = 0.25 }
local catalogPieces: { Types.DecorDef }? = (Catalog :: any).crateDecor
local DEMO_CRATE_DECOR: { Types.DecorDef } = catalogPieces or {}
local DEMO_POOL_PIECES: { [string]: { string } } = {}
if catalogPieces == nil then
	for pool, rows in DEMO_PIECE_ROWS do
		DEMO_POOL_PIECES[pool] = {}
		for _, row in rows do
			local name, letter, kind = row:match("^(.-)/(%a)/(%a+)$")
			assert(name and letter and kind, row)
			local rarity = DEMO_RARITY[letter]
			local id = pool .. "_" .. name:lower():gsub("%W+", "_")
			local piece: any = {
				id = id,
				name = name,
				cost = 0,
				category = DecorPieces.kindName(kind),
				effect = "",
				description = "",
				bonus = DEMO_BONUS[rarity],
				asset = "",
				source = "crate",
				crate = pool,
				rarity = rarity,
				kind = kind,
			}
			table.insert(DEMO_CRATE_DECOR, piece)
			table.insert(DEMO_POOL_PIECES[pool], id)
		end
	end
end
local DEMO_CRATES: { Types.CrateDef } = {}
for _, def in Catalog.crates do
	local crate = table.clone(def)
	if #crate.pieces == 0 then
		crate.pieces = DEMO_POOL_PIECES[crate.area] or {}
	end
	table.insert(DEMO_CRATES, crate)
end
-- golden-fish.md section 4: a duplicate gives golden fish back by its rarity
local DEMO_REFUND: { [string]: number } =
	{ Common = 10, Rare = 20, Epic = 40, Legendary = 80, Mythical = 150 }

-- golden-fish.md section 5b's All Cats page, until the engineer's F54 milestones and prizes land
local DEMO_ALL_PRIZES: { [string]: Types.IndexPrize } = {
	total5 = { fish = 10, spins = 1, bonus = 0.02 },
	total10 = { fish = 15, crates = { classic_crate = 1 }, bonus = 0.02 },
	total15 = { fish = 20, spins = 2, bonus = 0.02 },
	total20 = { fish = 25, crates = { classic_crate = 1 }, bonus = 0.03 },
	total25 = { fish = 30, spins = 2, bonus = 0.03 },
	total30 = { fish = 40, crates = { highest = 1 }, bonus = 0.03 },
	total35 = { fish = 50, spins = 3, bonus = 0.04 },
	total40 = { fish = 60, crates = { classic_golden_crate = 1 }, bonus = 0.04 },
	total45 = { fish = 75, spins = 3, bonus = 0.05 },
	total50 = {
		fish = 150,
		crates = { classic_golden_crate = 1 },
		tag = "Cat Master",
		bonus = 0.10,
	},
}

-- The catalog's Index with the All Cats page added when it has none yet, so the demo shows that page's rewards.
local function withAllCats(
	milestones: { Types.IndexMilestone },
	prizes: { [string]: { [string]: Types.IndexPrize } }
): ({ Types.IndexMilestone }, { [string]: { [string]: Types.IndexPrize } })
	if prizes.all ~= nil then
		return milestones, prizes
	end
	local outMilestones = table.clone(milestones)
	for count = 5, 50, 5 do
		table.insert(outMilestones, { id = "total" .. count, needs = count, track = "normal" })
	end
	local outPrizes = table.clone(prizes)
	outPrizes.all = DEMO_ALL_PRIZES
	-- golden-fish.md section 4's Decor Index: 25 golden fish at 5 of 10 pieces, +5% tips forever at all 10
	table.insert(outMilestones, { id = "decor5", needs = 5, track = "normal" })
	table.insert(outMilestones, { id = "decor10", needs = 10, track = "normal" })
	for pool in DEMO_PIECE_ROWS do
		outPrizes[DecorPieces.areaOf(pool)] = { decor5 = { fish = 25 }, decor10 = { bonus = 0.05 } }
	end
	return outMilestones, outPrizes
end
local demoMilestones, demoPrizes = withAllCats(
	(Catalog :: any).indexMilestones or DEMO_INDEX_MILESTONES,
	(Catalog :: any).indexPrizes or DEMO_INDEX_PRIZES
)

-- The real catalog (src/shared/Catalog.luau), so the demo shows the slice's actual cats and prices.
local CATALOG: Types.Catalog = {
	cats = Catalog.cats,
	upgrades = Catalog.upgrades,
	decor = Catalog.decor,
	crateDecor = DEMO_CRATE_DECOR,
	lures = Catalog.lures,
	spots = Catalog.spots,
	tiers = Catalog.tiers,
	areas = Catalog.areas,
	tipJar = (Catalog :: any).tipJar or DEMO_TIP_JAR,
	indexMilestones = demoMilestones,
	indexPrizes = demoPrizes,
	spinWheel = (Catalog :: any).spinWheel or DEMO_SPIN_WHEEL,
	crates = DEMO_CRATES,
	fishShop = Catalog.fishShop,
	rarities = Catalog.rarities,
}
-- every decor item, the shop's and the crates', for the demo's ToggleDecor and OpenCrate
local DEMO_DECOR = DecorPieces.all(CATALOG)

-- data-model section 10: circles and shrink time per rarity, Basic Net windows
local DEMO_CIRCLES: { [string]: { count: number, shrink: number } } = {
	Common = { count = 1, shrink = 1.4 },
	Rare = { count = 2, shrink = 1.15 },
	Epic = { count = 3, shrink = 0.95 },
	Legendary = { count = 4, shrink = 0.8 },
	Mythical = { count = 5, shrink = 0.65 },
}
local DEMO_WINDOWS: Types.CatchWindows = { perfect = 0.045, good = 0.11 }

local DECOR_BONUS: { [string]: number } =
	{ plants = 0.05, rug = 0.05, neon_sign = 0.10, fish_tank = 0.10 }
-- the bait bowl's wait, short so the demo shows the cat arriving (the design's LureWaitSeconds is 600)
local DEMO_BAIT_SECONDS = 20
-- the night dealer's stock window, short so one restock shows each night (DealerWindowSeconds is 600)
local DEMO_DEALER_WINDOW = 20

local SELL_VALUE: { [string]: number } =
	{ Common = 25, Rare = 150, Epic = 600, Legendary = 3000, Mythical = 12000 }

function Demo.run(UI: any): () -> ()
	local running = true
	local nextUid = 1
	local function uid(): string
		nextUid += 1
		return "demo_" .. tostring(nextUid)
	end

	local catById: { [string]: Types.CatDef } = {}
	for _, def in CATALOG.cats do
		catById[def.id] = def
	end

	local profile = {
		money = 50,
		upgradeLevels = { espresso = 1 } :: { [string]: number },
		decorOwned = {} :: { [string]: boolean },
		decorPlaced = {} :: { [string]: boolean },
		lures = {} :: { [string]: number },
		cats = {} :: { [string]: Types.CatInstance },
		-- three Alleyway cats already found, so the Index's first reward is ready to claim
		collection = { tabby = now(), tuxedo = now(), ginger = now() } :: { [string]: number },
		goldCollection = {} :: { [string]: number },
		indexRewards = {} :: { [string]: { [string]: boolean } },
		tier = 1,
		settings = Settings.defaults() :: any,
		-- today's free spin waiting plus one banked from the Tip Jar, so the wheel spins twice (Y opens it)
		spin = { lastFreeDay = 0, banked = 1 } :: Types.SpinState,
		-- enough golden fish for a crate and a perk, a banked Classic Crate and an Alley lucky twentieth one open away
		-- (M opens the Market)
		goldenFish = 137,
		crates = { classic_crate = 1, alley_golden_crate = 1 } :: { [string]: number },
		crateLuck = { alley = 19 } :: { [string]: number },
		fishPerks = {} :: { [string]: number },
	}
	-- six Alley crate pieces, so the Decor Index's first reward is ready; a wallpaper in use and both Tier 1 decor
	-- spots taken, so the Retro Jukebox says "Spots full"
	if DEMO_POOL_PIECES.alley then
		local owned =
			{ "brick_wall", "subway_tile", "fire_escape_red", "milk_crate_stools", "jar_lights" }
		for _, name in owned do
			profile.decorOwned["alley_" .. name] = true
		end
		profile.decorOwned.alley_retro_jukebox = true
		for _, name in { "brick_wall", "milk_crate_stools", "jar_lights" } do
			profile.decorPlaced["alley_" .. name] = true
		end
	end
	local starter = uid()
	profile.cats[starter] = {
		uid = starter,
		catId = "tabby",
		variant = "base",
		name = "Mochi", -- a player's name for the cat, as the server sends it after RenameCat
		caughtAt = now(),
		spotId = "barista_1",
		level = 2,
		stars = 3,
		rating = 1.2,
	}

	local spotType: { [string]: string } = {}
	for _, spot in CATALOG.spots :: { Types.SpotDef } do
		spotType[spot.id] = spot.spotType
	end

	local function rate(): number
		local multiplier = 1
			+ 0.10 * (profile.upgradeLevels.tables or 0)
			+ 0.15 * ((profile.upgradeLevels.espresso or 1) - 1)
		for decorId, placed in profile.decorPlaced do
			if placed then
				multiplier += DECOR_BONUS[decorId] or 0
			end
		end
		local total = 0
		for _, instance in profile.cats do
			if instance.spotId then
				local def = catById[instance.catId]
				local favorite = def.favoriteRole == spotType[instance.spotId]
				total += def.incomePerSecond * (if favorite then 1.5 else 1)
			end
		end
		return total * multiplier
	end

	local function push()
		UI.update({
			money = math.floor(profile.money),
			incomePerSecond = rate(),
			upgradeLevels = profile.upgradeLevels,
			decorOwned = profile.decorOwned,
			decorPlaced = profile.decorPlaced,
			lures = profile.lures,
			cats = profile.cats,
			collection = profile.collection,
			goldCollection = profile.goldCollection,
			indexRewards = profile.indexRewards,
			customers = 2 * (profile.upgradeLevels.tables or 0),
			tier = profile.tier,
			settings = profile.settings,
			spin = { lastFreeDay = profile.spin.lastFreeDay, banked = profile.spin.banked },
			goldenFish = profile.goldenFish,
			crates = table.clone(profile.crates),
			crateLuck = table.clone(profile.crateLuck),
			fishPerks = table.clone(profile.fishPerks),
		})
	end

	local function spend(cost: number): boolean
		if profile.money < cost then
			UI.toast("Not enough coins", "warn")
			return false
		end
		profile.money -= cost
		return true
	end

	UI.init({ catalog = CATALOG })

	-- the Tip Jar as if this session started six minutes ago, so two gifts are ready and a third is close
	local jar: Types.TipJarState =
		{ sessionStartedAt = Workspace:GetServerTimeNow() - 6 * 60 + 20, claimed = {} }
	UI.tipJar.set(jar)

	local connections: { any } = {}
	connections[#connections + 1] = UI.events.claimTipJar:Connect(function(step: number)
		local rows: { Types.TipJarRow } = CATALOG.tipJar or {}
		for _, row in rows do
			local claimed: { [any]: boolean } = jar.claimed or {}
			local due = Workspace:GetServerTimeNow() - jar.sessionStartedAt >= row.minutes * 60
			if row.step ~= step or claimed[step] or not due then
				continue
			end
			if row.kind == "coins" then
				local coins = math.max(row.minCoins or 0, math.floor(rate() * (row.seconds or 0)))
				profile.money += coins
				UI.toast(("Tip Jar: +%s"):format(Format.money(coins)), "good")
			elseif row.lureId then
				profile.lures[row.lureId] = (profile.lures[row.lureId] or 0) + (row.count or 1)
				UI.toast("Tip Jar: a food for your bait bowl", "good")
			end
			if (row.spins or 0) > 0 then
				profile.spin.banked = math.min(20, profile.spin.banked + (row.spins or 0))
			end
			claimed[step] = true
			jar = { sessionStartedAt = jar.sessionStartedAt, claimed = claimed }
			task.delay(0.3, function()
				UI.tipJar.set(jar)
				push()
			end)
		end
	end)
	-- ClaimIndexReward as the server checks it: a known prize, the count met, not claimed yet (data-model 11b)
	connections[#connections + 1] = UI.events.claimIndexReward:Connect(
		function(areaId: string, milestoneId: string)
			local rewards: { [string]: { [string]: Types.IndexPrize } } = CATALOG.indexPrizes or {}
			local prize = rewards[areaId] and rewards[areaId][milestoneId]
			local claimed = profile.indexRewards[areaId] or {}
			if prize == nil or claimed[milestoneId] then
				return
			end
			local milestones: { Types.IndexMilestone } = CATALOG.indexMilestones or {}
			local need, gold = math.huge, false
			for _, milestone in milestones do
				if milestone.id == milestoneId then
					need, gold = IndexRewards.need(milestone), IndexRewards.isGold(milestone)
				end
			end
			-- the page's count as the client shows it: cats (or gold cats), or a Decor Index page's pieces
			local counts = IndexRewards.counts(CATALOG, UI.getState(), areaId)
			local have = if gold then counts.gold else counts.found
			if have < need then
				UI.toast("Find more first", "warn")
				return
			end
			profile.money += prize.coins or 0
			profile.goldenFish += prize.fish or 0
			local crates: { [string]: number } = prize.crates or {}
			for crateId, count in crates do
				profile.crates[crateId] = (profile.crates[crateId] or 0) + count
			end
			local lures: { [string]: number } = prize.lures or {}
			for lureId, count in lures do
				profile.lures[lureId] = (profile.lures[lureId] or 0) + count
			end
			if prize.spins then
				profile.spin.banked = math.min(20, profile.spin.banked + prize.spins)
			end
			if prize.decorId then
				profile.decorOwned[prize.decorId] = true
				profile.decorPlaced[prize.decorId] = true
			end
			claimed[milestoneId] = true
			profile.indexRewards[areaId] = claimed
			UI.toast("Index reward claimed!", "good")
			task.delay(0.3, push)
		end
	)
	connections[#connections + 1] = UI.events.buyUpgrade:Connect(function(upgradeId: string)
		for _, def in CATALOG.upgrades do
			if def.id == upgradeId then
				local level = profile.upgradeLevels[upgradeId] or 0
				local cost = def.costs[level + 1]
				if level >= def.maxLevel or not cost then
					return
				end
				if spend(cost) then
					profile.upgradeLevels[upgradeId] = level + 1
					UI.toast(def.name .. " is now Lv " .. tostring(level + 1), "good")
					push()
				end
			end
		end
	end)
	connections[#connections + 1] = UI.events.buyDecor:Connect(function(decorId: string)
		for _, def in CATALOG.decor do
			if def.id == decorId and not profile.decorOwned[decorId] and spend(def.cost) then
				profile.decorOwned[decorId] = true
				profile.decorPlaced[decorId] = true
				UI.toast(def.name .. " placed", "good")
				push()
			end
		end
	end)
	-- ToggleDecor (F53): a wallpaper, floor or paint takes the place of the one in use; furniture and decorations
	-- need a free decor spot
	connections[#connections + 1] = UI.events.toggleDecor:Connect(
		function(decorId: string, placed: boolean)
			if not profile.decorOwned[decorId] then
				return
			end
			local def: Types.DecorDef? = nil
			for _, entry in DEMO_DECOR do
				if entry.id == decorId then
					def = entry
				end
			end
			local kind = DecorPieces.info(def).kind
			if placed and DecorPieces.isStyle(kind) then
				for _, other in DEMO_DECOR do
					if DecorPieces.info(other).kind == kind then
						profile.decorPlaced[other.id] = false
					end
				end
			elseif placed and kind then
				local spots = DecorPieces.spots(profile.tier, profile.fishPerks)
				if DecorPieces.spotsUsed(DEMO_DECOR, profile.decorPlaced) >= spots then
					UI.toast("Every decor spot is taken", "warn")
					return
				end
			end
			profile.decorPlaced[decorId] = placed
			push()
		end
	)
	connections[#connections + 1] = UI.events.buyLure:Connect(function(lureId: string)
		for _, def in CATALOG.lures do
			if def.id == lureId and spend(def.cost) then
				profile.lures[lureId] = (profile.lures[lureId] or 0) + 1
				push()
			end
		end
	end)
	-- Bait bowl (F28): the food goes in, the cat is rolled at once and shows up DEMO_BAIT_SECONDS later
	local bait: Types.BaitView? = nil
	local baitCat: Types.BaitCat? = nil
	connections[#connections + 1] = UI.events.useLure:Connect(function(lureId: string)
		local lure: Types.LureDef? = nil
		for _, def in CATALOG.lures do
			if def.id == lureId then
				lure = def
			end
		end
		if not lure or bait or (profile.upgradeLevels.lure_bowl or 0) < 1 then
			return
		end
		local food = lure :: Types.LureDef
		if (profile.lures[lureId] or 0) < 1 then
			return
		end
		profile.lures[lureId] -= 1
		local roll = math.random() * 100
		local rarity: string = "Common"
		for _, name in { "Common", "Rare", "Epic", "Legendary", "Mythical" } do
			local share = (food.odds :: any)[name] or 0
			if roll < share then
				rarity = name
				break
			end
			roll -= share
		end
		local pool: { Types.CatDef } = {}
		for _, def in CATALOG.cats do
			if def.rarity == rarity then
				table.insert(pool, def)
			end
		end
		local picked = if #pool > 0 then pool[math.random(1, #pool)] else CATALOG.cats[1]
		local charm = math.floor((math.random() + math.random()) / 2 * 101)
		local view: Types.BaitView = { lureId = lureId, readyAt = now() + DEMO_BAIT_SECONDS }
		bait = view
		baitCat = {
			catId = picked.id,
			variant = if math.random() < 0.2 then "gold" else "base",
			charm = charm,
			stars = math.clamp(math.ceil(charm / 20), 1, 5),
		}
		UI.bait.set(view)
		UI.toast(food.name .. " is in the bowl. A cat comes by soon!", "good")
		push()
		task.delay(DEMO_BAIT_SECONDS, function()
			if running and bait == view and baitCat then
				UI.bait.showReady(baitCat)
			end
		end)
	end)
	connections[#connections + 1] = UI.events.resolveBait:Connect(function(choice: Types.BaitChoice)
		local cat = baitCat
		if not cat or not bait then
			return
		end
		bait, baitCat = nil, nil
		UI.bait.set(nil)
		if choice == "tame" then
			local newUid = uid()
			profile.cats[newUid] = {
				uid = newUid,
				catId = cat.catId,
				variant = cat.variant or "base",
				caughtAt = now(),
				spotId = nil,
			}
			local isNew = profile.collection[cat.catId] == nil
			profile.collection[cat.catId] = now()
			UI.showCatFound(cat.catId, isNew, { stars = cat.stars, shiny = cat.variant == "gold" })
			push()
		else
			UI.toast("It wandered off. Maybe next time!", "info")
		end
	end)

	-- Night dealer (F32): three slots rolled from the tier's weights at night start and at each window, gone by
	-- day. Every Buy is answered with fresh stock, as the server does. N opens the cart (the prompt in the game).
	local dealerStock: Types.DealerStock? = nil
	local dealerGift = false
	local function rollDealer()
		local weights = Catalog.dealerSlotWeights -- v0.5 F43: one row for everyone
		local total = 0
		for _, weight in weights do
			total += weight
		end
		local slots: { Types.DealerSlot } = {}
		for _ = 1, 3 do
			local roll = math.random() * total
			local pick = "sardines"
			for lureId, weight in weights do
				roll -= weight
				if weight > 0 and roll <= 0 then
					pick = lureId
					break
				end
			end
			table.insert(
				slots,
				{ lureId = pick, cost = Catalog.luresById[pick].cost, bought = false }
			)
		end
		local stock: Types.DealerStock = { slots = slots, restocksAt = now() + DEMO_DEALER_WINDOW }
		dealerStock = stock
		UI.dealer.setStock(stock)
	end
	-- the server refuses a slot whose food changed with a restock (S42)
	local function buyDealer(slot: number, lureId: string)
		local stock = dealerStock
		if not stock then
			return
		end
		local entry = stock.slots[slot]
		if entry and entry.lureId == lureId and not entry.bought and spend(entry.cost) then
			entry.bought = true
			profile.lures[entry.lureId] = (profile.lures[entry.lureId] or 0) + 1
			local name = Catalog.luresById[entry.lureId].name
			UI.toast("Bought " .. name .. ". Use it in your bait bowl!", "good")
			push()
		end
		UI.dealer.setStock(stock)
	end
	connections[#connections + 1] = UI.events.buyDealerFood:Connect(buyDealer)
	-- SpinWheel as the server runs it (data-model 11c): the free spin first, then a banked one; a weighted slice,
	-- paid at once; SpinResult(0, 0) when there is no spin. The demo has no station, so range is not checked.
	local lastSpin = -math.huge
	connections[#connections + 1] = UI.events.spinWheel:Connect(function()
		local today = math.floor(Workspace:GetServerTimeNow() / 86400)
		local spin = profile.spin
		local rows: { Types.SpinRow } = CATALOG.spinWheel or {}
		local free = today > spin.lastFreeDay
		if (not free and spin.banked < 1) or os.clock() - lastSpin < 4 or #rows == 0 then
			task.delay(0.2, UI.spin.result, 0, 0)
			return
		end
		lastSpin = os.clock()
		if free then
			spin.lastFreeDay = today
		else
			spin.banked -= 1
		end
		local total = 0
		for _, row in rows do
			total += row.weight
		end
		local roll = math.random() * total
		local picked = rows[#rows]
		for _, row in rows do
			roll -= row.weight
			if roll < 0 then
				picked = row
				break
			end
		end
		local amount
		if picked.kind == "coins" then
			amount = math.max(picked.minCoins or 0, math.floor(rate() * (picked.seconds or 0)))
			profile.money += amount
		else
			amount = picked.count or 1
			local lureId = picked.lureId or "tuna"
			profile.lures[lureId] = (profile.lures[lureId] or 0) + amount
		end
		push()
		task.delay(0.2, UI.spin.result, picked.slice, amount)
	end)
	-- OpenCrate as the server runs it (golden-fish.md section 8): a banked crate first, else its price in fish; the
	-- lucky twentieth opens on the golden odds; a duplicate pays its rarity's refund; a refusal is ("", false, 0).
	local cratesById: { [string]: Types.CrateDef } = {}
	local goldenOdds: { [string]: { [string]: number } } = {}
	for _, crate in DEMO_CRATES do
		cratesById[crate.id] = crate
		if crate.golden then
			goldenOdds[crate.area] = crate.odds
		end
	end
	local rarityOf: { [string]: string } = {}
	for _, piece in DEMO_DECOR do
		rarityOf[piece.id] = (piece :: any).rarity
	end
	local lastOpen = -math.huge
	connections[#connections + 1] = UI.events.openCrate:Connect(function(crateId: string)
		local crate = cratesById[crateId]
		local banked = profile.crates[crateId] or 0
		local areas: { MarketLogic.Area } = (CATALOG.areas or {}) :: any
		if
			crate == nil
			or os.clock() - lastOpen < 2
			or not MarketLogic.isOpen(crate, profile.tier, areas)
			or (banked < 1 and (crate.price == nil or profile.goldenFish < crate.price))
		then
			UI.toast("Not enough golden fish", "warn")
			task.delay(0.2, UI.market.result, crateId, "", false, 0)
			return
		end
		lastOpen = os.clock()
		if banked > 0 then
			profile.crates[crateId] = banked - 1
		else
			profile.goldenFish -= crate.price or 0
		end
		local luck = profile.crateLuck[crate.area]
		local odds =
			MarketLogic.nextOdds(crate, luck, Config.CrateLuckyEvery, goldenOdds[crate.area])
		local chances = MarketLogic.pieceChances(crate.pieces, function(id: string): string?
			return rarityOf[id]
		end, odds)
		local roll = math.random() * 100
		local picked = chances[#chances]
		for _, chance in chances do
			roll -= chance.percent
			if roll < 0 then
				picked = chance
				break
			end
		end
		local lucky = picked.rarity ~= "Common" and picked.rarity ~= "Rare" -- Epic or better
		profile.crateLuck[crate.area] = if lucky then 0 else (luck or 0) + 1
		local duplicate = profile.decorOwned[picked.id] == true
		local refund = if duplicate then DEMO_REFUND[picked.rarity] or 0 else 0
		if duplicate then
			profile.goldenFish += refund
		else
			profile.decorOwned[picked.id] = true
		end
		push()
		task.delay(0.2, UI.market.result, crateId, picked.id, duplicate, refund)
	end)
	-- BuyFishItem: a known row, affordable and below its max level; a perk goes up a level, a food goes in the bag
	connections[#connections + 1] = UI.events.buyFishItem:Connect(function(itemId: string)
		local row: Types.FishShopRow? = nil
		local rows: { Types.FishShopRow } = CATALOG.fishShop or {}
		for _, entry in rows do
			if entry.id == itemId then
				row = entry
			end
		end
		local level = profile.fishPerks[itemId]
		local cost = if row then MarketLogic.cost(row, level) else nil
		if row == nil or cost == nil or profile.goldenFish < cost then
			UI.toast("Not enough golden fish", "warn")
			return
		end
		profile.goldenFish -= cost
		if row.kind == "perk" then
			profile.fishPerks[itemId] = (level or 0) + 1
		else
			profile.lures[itemId] = (profile.lures[itemId] or 0) + 1
		end
		push()
	end)
	connections[#connections + 1] = UserInputService.InputBegan:Connect(
		function(input: InputObject, processed: boolean)
			if not processed and input.KeyCode == Enum.KeyCode.N then
				UI.dealer.open()
			elseif not processed and input.KeyCode == Enum.KeyCode.Y then
				UI.spin.open()
			elseif not processed and input.KeyCode == Enum.KeyCode.M then
				UI.market.open()
			end
		end
	)
	connections[#connections + 1] = UI.events.placeCat:Connect(
		function(catUid: string, spotId: string)
			local instance = profile.cats[catUid]
			if not instance then
				return
			end
			for _, other in profile.cats do
				if other.spotId == spotId then
					UI.toast("That spot is taken", "warn")
					return
				end
			end
			instance.spotId = spotId
			UI.toast(catById[instance.catId].name .. " placed on " .. spotId, "good")
			push()
		end
	)
	connections[#connections + 1] = UI.events.unplaceCat:Connect(function(catUid: string)
		local instance = profile.cats[catUid]
		if instance then
			instance.spotId = nil
			push()
		end
	end)
	connections[#connections + 1] = UI.events.sellCat:Connect(function(catUid: string)
		local instance = profile.cats[catUid]
		if instance then
			local def = catById[instance.catId]
			profile.cats[catUid] = nil
			profile.money += SELL_VALUE[def.rarity] or 0
			UI.toast(("Sold %s for $%d"):format(def.name, SELL_VALUE[def.rarity] or 0), "good")
			push()
		end
	end)
	-- the server filters the name before anyone else sees it; the demo keeps it as typed
	connections[#connections + 1] = UI.events.renameCat:Connect(
		function(catUid: string, name: string)
			local instance = profile.cats[catUid]
			if instance then
				instance.name = name
				UI.toast(("Renamed to %s"):format(name), "good")
				push()
			end
		end
	)
	connections[#connections + 1] = UI.events.equipBest:Connect(function()
		UI.toast("Equip best: the server would place your top cats", "info")
	end)
	-- like the server (PR #215): every key of shared/Settings is saved, volumes to two decimals
	connections[#connections + 1] = UI.events.setSetting:Connect(
		function(key: string, value: boolean | number)
			local clean = Settings.clean(key, value)
			if clean ~= nil then
				task.delay(0.3, function()
					profile.settings[key] = clean
					push()
				end)
			end
		end
	)
	-- the server's answers to ReportBug, as toasts; "fail" in the text shows the refusal that keeps the words
	local lastReport = -math.huge
	connections[#connections + 1] = UI.events.reportBug:Connect(
		function(text: string, kind: string, clientErrors: { string })
			print(("[Demo] ReportBug %s %q, %d client errors"):format(kind, text, #clientErrors))
			task.delay(0.5, function()
				if os.clock() - lastReport < 20 then
					UI.toast(BugReport.Messages.limited, "warn")
					return
				end
				lastReport = os.clock() -- like the server's limiter, a failed write still counts
				if string.find(text, "fail", 1, true) then
					UI.toast(BugReport.Messages.failed, "warn")
				else
					UI.toast(BugReport.Messages.sent, "good")
				end
			end)
		end
	)
	connections[#connections + 1] = UI.events.unequipAll:Connect(function()
		local rested = 0
		for _, instance in profile.cats do
			if instance.spotId then
				instance.spotId = nil
				rested += 1
			end
		end
		UI.toast(("%d cats are resting in the cat room."):format(rested), "info")
		push()
	end)
	connections[#connections + 1] = UI.events.travel:Connect(function(destination: string)
		UI.toast(
			if destination == "home"
				then "Travel: the server would take you to your cafe"
				else ("Travel: the server would take you to %s"):format(
					Format.areaName(destination)
				),
			"info"
		)
		UI.travel.result(destination, true)
	end)
	connections[#connections + 1] = UI.events.dropCat:Connect(function()
		UI.setCarrying(nil)
		UI.toast("Dropped: the server would set the cat down with you on the first try", "info")
	end)
	connections[#connections + 1] = UI.events.claimOffline:Connect(function()
		profile.money += 312
		UI.toast("+$312 claimed", "good")
		push()
	end)
	connections[#connections + 1] = UI.events.rankUp:Connect(function()
		local progress = RankUp.progress(CATALOG, UI.getState())
		local nextTier = progress.nextTier
		if progress.ready and nextTier and spend(nextTier.cost) then
			profile.tier = nextTier.tier
			UI.close()
			UI.announce(("Your cafe is now a %s!"):format(nextTier.name))
			push()
		end
	end)

	-- Pretend server for the closing circles: the schedule is made here, presses are stamped on arrival and
	-- graded against each circle's target. Data-model 10 step 5: the first Miss ends the catch and the cat runs
	-- off for a moment (v0.5, tries are unlimited), no Miss catches, and every Perfect adds 4 charm (doubled when
	-- all are Perfect).
	local function demoCatch(catId: string)
		local def = catById[catId]
		local rarity: string = if def then def.rarity else "Common"
		local spec = DEMO_CIRCLES[rarity] or DEMO_CIRCLES.Common
		local strayId = "demo_stray_" .. catId
		UI.catch.show({
			catId = catId,
			strayId = strayId,
			stars = 3,
			press = true,
		})
		task.wait(1.2)
		local start = Workspace:GetServerTimeNow() + 0.6
		local schedule: { Types.CatchCircle } = {}
		for _ = 1, spec.count do
			local shrink = spec.shrink * (1 + (math.random() * 0.6 - 0.3))
			table.insert(schedule, {
				startsAt = start,
				shrinkSeconds = shrink,
				x = math.random(),
				y = math.random(),
			})
			start += shrink + 0.35 + math.random() * 0.35
		end
		local grades: { Types.CircleGrade } = {}
		local missed = false
		local connection = UI.events.catchPressed:Connect(function(id: string, index: number)
			local circle = schedule[index]
			if id ~= strayId or not circle or missed or index ~= #grades + 1 then
				return
			end
			local offset =
				math.abs(Workspace:GetServerTimeNow() - (circle.startsAt + circle.shrinkSeconds))
			local grade: Types.CircleGrade = if offset <= DEMO_WINDOWS.perfect
				then "perfect"
				elseif offset <= DEMO_WINDOWS.good then "good"
				else "miss"
			table.insert(grades, grade)
			missed = grade == "miss"
		end)
		UI.catch.showCircles(strayId, schedule, DEMO_WINDOWS)
		-- judge until a Miss, the last circle, or a circle's deadline passing with no press
		while not missed and #grades < #schedule do
			local circle = schedule[#grades + 1]
			if
				Workspace:GetServerTimeNow()
				> circle.startsAt + circle.shrinkSeconds + DEMO_WINDOWS.good + 0.15
			then
				local miss: Types.CircleGrade = "miss"
				table.insert(grades, miss)
				missed = true
			else
				task.wait(0.05)
			end
		end
		connection:Disconnect()
		local success = not missed
		local perfects = 0
		for _, grade in grades do
			if grade == "perfect" then
				perfects += 1
			end
		end
		local charm = if success then perfects * 4 * (if perfects == #schedule then 2 else 1) else 0
		UI.catch.showGrades(strayId, grades, success, charm)
		task.wait(1.8)
		UI.catch.hide()
		if success then
			UI.setCarrying({ catId = catId })
			task.wait(3)
			UI.setCarrying(nil)
		end
	end

	push()
	UI.toast("Demo mode: pretend server, pretend money", "info")

	-- Rescue minigame (F27): the pretend server judges each press with the same marker maths as the real one
	local demoRescue: Types.RescueChallenge? = nil
	local rescueHits, rescuePaws = 0, 0
	local function startDemoRescue()
		local challenge: Types.RescueChallenge = {
			kind = "bar",
			startsAt = Workspace:GetServerTimeNow() + 0.6,
			phase = 0,
			speed = 1.0,
			zoneWidth = 0.24,
			zones = { 0.72, 0.3, 0.55 },
			hitsNeeded = 3,
			paws = 3,
		}
		demoRescue = challenge
		rescueHits, rescuePaws = 0, 3
		UI.rescue.show("demo_rescue_1", challenge)
	end
	connections[#connections + 1] = UI.events.rescuePressed:Connect(function(spotId: string)
		local challenge = demoRescue
		if not challenge then
			return
		end
		local t = Workspace:GetServerTimeNow()
		local position =
			RescueMarker.position(challenge.startsAt, challenge.phase or 0, challenge.speed or 1, t)
		local zones: { number } = challenge.zones or {}
		local centre = zones[rescueHits + 1] or 0.5
		if RescueMarker.inZone(position, centre, challenge.zoneWidth or 0.3, 0.03) then
			rescueHits += 1
		else
			rescuePaws -= 1
		end
		local success = rescueHits >= (challenge.hitsNeeded or #zones)
		local done = success or rescuePaws <= 0
		if done then
			demoRescue = nil
		end
		UI.rescue.update(spotId, rescueHits, rescuePaws, done, success)
	end)
	connections[#connections + 1] = UI.events.rescueCancelled:Connect(function()
		demoRescue = nil
	end)

	-- clock: a short day and night so the chip can be seen flipping (the real ones are 300 s and 90 s since F66).
	-- The areas close at night, so the Alley button and the Areas panel's Go buttons grey with a moon; the dusk
	-- banner needs a catching area from UI.setZone, so the demo shows the orange countdown and the sunrise banner.
	task.spawn(function()
		local phase: Types.ClockPhase = "day"
		while running do
			local length = if phase == "day" then 45 else 20
			UI.clock.set(phase, now() + length)
			UI.clock.setAreasOpen(phase == "day")
			task.wait(length)
			phase = if phase == "day" then "night" else "day"
			if running then
				if phase == "night" then
					UI.toast("Night fell. The areas are closed until sunrise.", "info")
					rollDealer()
					if not dealerGift then
						-- pretend coins so the demo can buy from him
						dealerGift = true
						profile.money += 5000
						push()
					end
					UI.toast("The night dealer is on the street. Press N to see his cart.", "info")
				else
					dealerStock = nil
					UI.dealer.setStock(nil)
				end
			end
		end
	end)

	-- the dealer restocks when his window ends, while it is still night
	task.spawn(function()
		while running do
			task.wait(0.5)
			local stock = dealerStock
			if stock and now() >= stock.restocksAt + 1 then
				rollDealer()
			end
		end
	end)

	-- money ticks, a cat shows up every 25 s, one ring demo near the start
	task.spawn(function()
		task.wait(2)
		if running then
			UI.showOfflineEarnings(312, 1245)
		end
		task.wait(3)
		if running then
			-- v0.3 net: one Common circle, then three Epic circles
			demoCatch("tabby")
			task.wait(2)
			demoCatch("sphynx")
			UI.tutorial.show("Place your new cat: open Cats, then the Cat room tab")
			task.wait(6)
			UI.tutorial.hide()
			-- rescue minigame (F27): a Rare in a bin, three hits with Rare speed and zone width
			task.wait(3)
			UI.catch.show({
				kind = "rescue",
				catId = "calico",
				rescueSpotId = "demo_rescue_1",
				press = true,
			})
			task.wait(1)
			startDemoRescue()
		end
	end)
	task.spawn(function()
		local sinceCat = 0
		while running do
			local dt = task.wait(0.5)
			profile.money += rate() * dt
			sinceCat += dt
			if sinceCat >= 25 then
				sinceCat = 0
				local pool = CATALOG.cats
				local def = pool[math.random(1, #pool)]
				local newUid = uid()
				-- one in five is gold here (5% in the game) so the cat room's gold cards show up
				local shiny = math.random() < 0.2
				profile.cats[newUid] = {
					uid = newUid,
					catId = def.id,
					variant = if shiny then "gold" else "base",
					caughtAt = now(),
					spotId = nil,
				}
				local isNew = profile.collection[def.id] == nil
				profile.collection[def.id] = now()
				-- the demo rolls stars and a Purrfect bonus so the reveal shows every part
				UI.showCatFound(def.id, isNew, {
					shiny = shiny,
					stars = math.random(1, 5),
					charmGain = if math.random() < 0.3 then math.random(2, 6) else nil,
				})
				if def.rarity == "Epic" or def.rarity == "Legendary" then
					UI.announce(
						("Someone caught %s %s %s!"):format(
							if def.rarity:match("^[AEIOU]") then "an" else "a",
							def.rarity,
							def.name
						)
					)
				end
			end
			UI.update({ money = math.floor(profile.money), incomePerSecond = rate() })
			if sinceCat == 0 then
				push()
			end
		end
	end)

	return function()
		running = false
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

return Demo
