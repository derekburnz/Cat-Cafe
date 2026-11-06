--!strict
-- Save data (data-model section 14): template, migration and sanitising. Pure.

local CafePass = require(script.Parent.CafePass)
local CampExtras = require(script.Parent.CampExtras)
local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local CornerShop = require(script.Parent.CornerShop)
local DailyTreat = require(script.Parent.DailyTreat)
local EquipBest = require(script.Parent.EquipBest)
local FreshCatch = require(script.Parent.FreshCatch)
local Lawn = require(script.Parent.Lawn)
local Looks = require(script.Parent.Looks)
local Onboarding = require(script.Parent.Onboarding)
local Products = require(script.Parent.Products)
local Rally = require(script.Parent.Rally)
local Settings = require(script.Parent.Settings)
local SignStyles = require(script.Parent.SignStyles)
local Spin = require(script.Parent.Spin)
local StarterCat = require(script.Parent.StarterCat)
local Tips = require(script.Parent.Tips)
local Trade = require(script.Parent.Trade)
local Types = require(script.Parent.Types)
local YardSale = require(script.Parent.YardSale)

local ProfileSchema = {}

-- Version 2 (2026-10-26) added level, xp and charm per cat. Version 3 (2026-10-26, design v0.3) adds the tier,
-- role slots, bait, the dealer, shinies, cat names and how each cat was found; cafe_level and park_access go.
-- Version 4 (2026-10-27) renames shiny to gold. Version 5 (F48) adds indexRewards and stats.tipJarClaims: an older
-- server would drop them, and a player hopping servers could claim every Index reward again (reviewer S60).
-- Version 6 (F49) adds spin and stats.spins, for the same reason: an older server would drop spin during a
-- rollout, giving a second free spin and losing banked ones.
-- Version 7 (F52 and F53, golden-fish.md) adds goldenFish, lifetimeGoldenFish, crates, crateLuck, fishPerks,
-- stats.cratesOpened and stats.fishEarned: an older server would drop them, losing fish, crates and perks.
-- Version 8 (F54) adds the All Cats and Decor Index pages to indexRewards and bait.readyAt: an older server would
-- drop those claims, so a player hopping servers during a rollout could claim them twice.
-- Version 9 (F65) adds codesRedeemed: an older server would drop it, letting a code pay twice.
-- Version 10 (F72) adds introSeen: an older server would drop it, playing the intro cutscene again.
-- Version 11 (v0.8 F56) adds stats.pickups, the counter of Dropped cats picked up: an older server would drop it.
-- Version 12 (v0.12 F75) moves cats onto the 50-level curve (an old level L becomes 1 + ceil(2.5 x (L - 1)) with xp
-- 0), lets xp hold fractions and adds stats.catLevelUps: an older server would clamp level 24 back to 10 and save it.
-- Version 13 (F64) adds potions, buffs (seconds of play time left), stats.potionsUsed and stats.mysteryGifts: an
-- older server would drop them, losing the bag and any running potion.
-- Version 14 (F62) adds each cat's `locked` and locks every gold, Legendary and Mythical cat already owned, once: an
-- older server would drop the flag, and a second run would lock again a cat its player unlocked.
-- Version 15 (F63) adds stats.collectorTrades, the cats traded to the Cat Collector: an older server would drop it.
-- Version 16 (F73) adds quests, achievements and seven stats (rareCatches, goldCatches, tipPilesCollected and the
-- quest and set counts): an older server would drop the claims, so a player hopping servers during a rollout could
-- claim a quest or an achievement twice.
-- Version 17 (F70) adds dailyTreat, the Daily Treat card: an older server would drop it, letting a stamp pay twice
-- in a day and the card start again at day 1.
-- Version 18 (F94, rewards-and-shops.md section 6) adds freshCatch, the Fresh Catch shelf's counts and alert, and
-- drops dealer, whose stock is now per server per night and kept in memory: an older server would drop freshCatch,
-- letting a player buy a window's stock twice by hopping servers during a rollout.
-- Version 19 (F87, easy-start.md section 5) moves telemetry to the 24 step onboarding funnel v2 (`funnel` 2, with
-- the old step carried over; since #1273 Onboarding.fromOld) and adds telemetry.firstDay: an older server would read a v2 step
-- as a v1 one and log the wrong steps.
-- Version 20 (F87, easy-start.md section 6) adds tipsSeen, feedbackAsked and stuckHelpShown: an older server would
-- drop them and show every context tip and the one feedback ask again. A save from before version 20 that is past
-- the first loop (tutorialStep 5) has seen every tip already (Tips.sanitizeSeen).
-- Version 21 (F96, starter-cat.md section 4) adds starterCatClaimed: an older server would drop it and let the free
-- Bellhop Cat be claimed again. A save that already holds a Bellhop Cat counts as claimed.
-- Version 22 (F96, starter-cat.md section 3) adds notifyAskAt, when the notification ask first showed: an older server
-- would drop it and ask again sooner than the 30 days. The favorite and notification asks ride tipsSeen like the like
-- ask (Tips.sanitizeSeen keeps them).
-- Version 23 (F98, leaderboards.md section 5) adds stats.bestRate, stats.weekPlay and stats.weekBestRate: an older
-- server would drop them, and the Money board would forget the player's best rate.
-- Version 24 (F99, rainbow-coat.md section 5) adds the rainbow coat: variant "rainbow", rainbowCollection and
-- stats.rainbowCatches. An older server would read a rainbow cat as a base one and save it so, and drop the
-- collection and the count.
-- Version 25 (F100, camp-extras.md section 4) adds campExtras, what the four camp extras hold and the Yard Sale's
-- buys today: an older server would drop it, letting a player collect the same fill or buy the same crate twice by
-- hopping servers during a rollout. A save from before version 25 starts with one fill waiting at each open extra.
-- Version 26 (F101, rescue-rally.md section 5) adds rally, the weekend and the laps paid in it: an older server would
-- drop it, and a player could take more than RallyMaxLaps laps of prizes by hopping servers during a rollout.
-- Version 27 (F102, trading.md section 6) adds tradeLog, tradeIds, stats.trades, stats.tradesToday and the "trade"
-- method: an older server would drop the applied trade ids, so a trade still
-- pending after a shutdown (section 4) could be applied twice, and it would read a traded cat's method as none.
-- Version 28 (F91, front-lawn.md section 5) adds lawnOwned, lawn and lawnStyles, the front lawn bought with coins: an
-- older server would drop them, and the player would lose every piece and style paid for. Older saves start with an
-- empty lawn, Grey Slabs and no fence; CafeService gives the Tier 2 and 3 gifts on load (Lawn.grantTierGifts).
-- Version 29 (#1052, corner-shop.md section 5) adds cornerShop, the Corner Shop's bought counts this window and the
-- Cat Snack XP given today: an older server would drop it, letting a player buy a window's stock twice or pass the
-- day's snack cap by hopping servers during a rollout. Older saves start with nothing bought.
-- Version 30 (#1083, idea-credits.md section 4) adds hideCredit, true while the player keeps their name off the Thank
-- You board: an older server would drop it, and the player's name would come back on the board after a rollout.
-- Version 31 (#1182) adds receipts, the developer product PurchaseIds already granted: an older server would drop
-- them, and a receipt Roblox delivers again after a rollout would grant its potions twice.
-- #1273 (no new version): telemetry moves to the onboarding funnel v3 (`funnel` 3, sanitizeTelemetry) and gains
-- telemetry.introStep. It is analytics only: an older server during a rollout reads funnel 3 as v1 and saves funnel 2,
-- which this one then takes back to v3's start or out of it, and a step Roblox sees twice counts once.
-- Version 32 (#1180, #1181; corner-shop-v2.md section 4) adds catFood, the Bag's cat food, and the Corner Shop's day
-- counters (day, today, foodXpToday; snackDay and snackXp go): an older server would drop them, losing the food
-- bought and letting a player pass a daily limit by hopping servers during a rollout.
-- Version 33 (#1154, camp-stations.md section 3) turns campExtras.yardSale from { day, bought } into
-- { lastClaimAt, claims }, one free crate every YardSaleClaimHours: an older server would read it as no crate taken
-- today and give a second one by server hopping during a rollout. A save that took today's crate waits until
-- YardSaleClaimHours after that UTC day began (CampExtras.sanitize).
-- Version 34 (#1161) adds bait2, the Second Bait Bowl's food and rolled cat: an older server would drop it, losing
-- the food and letting the player roll that bowl again by hopping servers during a rollout.
-- #1574 (no new version): decorUnlocked, the Legendary and up pieces unlocked to trade, and the trade log's gaveDecor
-- and gotDecor. An older server drops them, which only locks those pieces again and shortens old log entries.
-- Version 35 (#1625) adds onceBought, signStyles and signStyle, the Starter Bundle's once-per-account mark and the
-- sign styles: an older server would drop them, losing the Bakery Stripes sign and letting the bundle be bought as new.
-- Version 36 (#1645, cafe-pass.md section 6) adds pass, the Cafe Pass's XP, claims, paid season and items: an older
-- server would drop it, losing the XP and letting a reward be claimed twice by hopping servers during a rollout.
-- Version 37 (#1537, lawn-nursery.md section 7) adds yardDecor, the Yard Sale's lawn rows bought this global game
-- day: an older server would drop it, letting the player buy the same row again by hopping servers during a rollout.
-- Version 38 (#1624, store-pass-looks.md) adds looks, the cafe theme and uniform picks: an older server would drop them,
-- showing Classic until the player picks again.
ProfileSchema.VERSION = 38

local DAY_SECONDS = 86400 -- telemetry.firstDay is a UTC day number (F87)

-- What version 2 charged for each level, frozen here because the live Catalog no longer has cafe_level or
-- park_access and has repriced the net. The 2 to 3 migration refunds levels it takes away at these prices.
local V2_COSTS: { [string]: { number } } = {
	cafe_level = { 0, 250, 800, 2500, 8000 },
	park_access = { 1000 },
	tables = { 100, 250, 600, 1500, 3500, 8000 },
	espresso = { 0, 300, 1200, 4000, 12000 },
	net = { 500, 2500, 10000 },
}
local V2_START_LEVELS: { [string]: number } = { cafe_level = 1, espresso = 1 }

local STARTER_UID = "starter_tabby"
local MAX_NAME_LENGTH = 200 -- bytes kept from a saved name

local function asNumber(value: any, default: number): number
	if type(value) == "number" and value == value and value >= 0 and value < math.huge then
		return value
	end
	return default
end

local function asInt(value: any, default: number): number
	return math.floor(asNumber(value, default))
end

local function newStats(): Types.Stats
	return {
		catsCaught = 0,
		catsSold = 0,
		grabsAttempted = 0,
		grabsSucceeded = 0,
		perfectCircles = 0,
		circlesTotal = 0,
		rescues = 0,
		rescueAttempts = 0,
		baitsTamed = 0,
		baitsLetGo = 0,
		bumpsGiven = 0,
		bumpsLanded = 0,
		bumpsTaken = 0,
		luresUsed = 0,
		playtimeSeconds = 0,
		sessions = 0,
		tipJarClaims = 0,
		spins = 0,
		cratesOpened = 0,
		fishEarned = 0,
		pickups = 0,
		catLevelUps = 0,
		potionsUsed = 0,
		mysteryGifts = 0,
		collectorTrades = 0,
		rareCatches = 0,
		goldCatches = 0,
		rainbowCatches = 0, -- F99
		tipPilesCollected = 0,
		dailyQuestsDone = 0,
		dailySetsDone = 0,
		weeklyQuestsDone = 0,
		weeklySetsDone = 0,
		bestRate = 0, -- F98
		weekPlay = { week = 0, seconds = 0 },
		weekBestRate = { week = 0, rate = 0 },
		trades = 0, -- F102
		tradesToday = { day = 0, count = 0 },
	}
end

-- F98: a saved { week, <field> } pair of whole week number and non-negative amount, else week 0 and 0.
local function sanitizeWeekly(raw: any, field: string): any
	local week = if type(raw) == "table" then asInt(raw.week, 0) else 0
	local amount = if type(raw) == "table" then asNumber(raw[field], 0) else 0
	return { week = week, [field] = amount }
end

-- No quests yet (F73): day and week 0, so QuestService rolls both when the profile loads.
local function newQuests(): Types.QuestState
	return {
		day = 0,
		daily = {},
		dailyReroll = false,
		dailySet = false,
		week = 0,
		weekly = {},
		weeklyReroll = false,
		weeklySet = false,
	}
end

-- Starting profile: 50 coins, Tier 1, one Tabby working as the Barista. `now` is server os.time().
function ProfileSchema.template(now: number): Types.PlayerProfile
	local levels: { [string]: number } = {}
	for _, def in Catalog.upgrades do
		levels[def.id] = def.startLevel
	end
	-- The starter has neutral charm (50) so every new cafe earns the same 1.5 per second.
	local starter = CatStats.newInstance(STARTER_UID, "tabby", now)
	starter.spotId = "barista_1"
	starter.method = "starter"
	return {
		version = ProfileSchema.VERSION,
		coins = Config.StartCoins,
		lifetimeCoins = 0,
		lastTick = now,
		lastSeen = now,
		rateAtLogout = 0,
		tier = 1,
		upgradeLevels = levels,
		decorOwned = {},
		decorPlaced = {},
		decorUnlocked = {},
		lures = {},
		bait = nil,
		bait2 = nil,
		freshCatch = FreshCatch.fresh(),
		cats = {
			[STARTER_UID] = starter,
		},
		collection = { tabby = now },
		goldCollection = {},
		rainbowCollection = {},
		indexRewards = {},
		spin = { lastFreeDay = 0, banked = 0 },
		goldenFish = 0,
		lifetimeGoldenFish = 0,
		crates = {},
		crateLuck = {},
		fishPerks = {},
		codesRedeemed = {},
		introSeen = false,
		potions = {},
		buffs = {},
		quests = newQuests(),
		achievements = {},
		dailyTreat = { stamp = 0, lastDay = 0 },
		stats = newStats(),
		tutorialStep = 0,
		settings = Settings.defaults(),
		flags = { autoPress = false },
		telemetry = {
			onboardingStep = 0,
			achieved = {},
			funnel = Onboarding.VERSION,
			firstDay = now // DAY_SECONDS,
			introStep = 0,
		},
		tipsSeen = {},
		feedbackAsked = false,
		stuckHelpShown = {},
		starterCatClaimed = false,
		notifyAskAt = 0,
		campExtras = CampExtras.fresh(now),
		rally = Rally.fresh(now),
		tradeLog = {},
		tradeIds = {},
		lawnOwned = {},
		lawn = {},
		lawnStyles = Lawn.freshStyles(),
		cornerShop = CornerShop.fresh(),
		yardDecor = YardSale.fresh(),
		hideCredit = nil,
		receipts = {},
		catFood = {},
		onceBought = {},
		signStyles = {},
		signStyle = nil,
		pass = CafePass.fresh(0),
		looks = {},
	}
end

-- The version a raw save was written by. Saves from before the field existed count as version 1.
function ProfileSchema.versionOf(raw: any): number
	if type(raw) ~= "table" then
		return ProfileSchema.VERSION
	end
	return math.max(1, asInt(raw.version, 1))
end

-- True when the save was written by newer code than this server runs. Loading it would drop the fields this
-- version does not know and then save that, so DataService refuses it and asks the player to rejoin (S31).
function ProfileSchema.isNewerThanCode(raw: any): boolean
	return ProfileSchema.versionOf(raw) > ProfileSchema.VERSION
end

-- Coins a version 2 save spent on levels from `fromLevel + 1` up to `toLevel` of an upgrade.
local function v2Spent(upgradeId: string, fromLevel: number, toLevel: number): number
	local costs = V2_COSTS[upgradeId]
	if costs == nil then
		return 0
	end
	local total = 0
	for level = fromLevel + 1, math.min(toLevel, #costs) do
		total += costs[level]
	end
	return total
end

-- Version 1 and 2 upgrade levels: carries the ones that still exist (renamed ids too), caps tables, espresso and
-- net at Tier 1, and returns the refund for everything taken away (cafe_level, park_access, levels over a cap).
local function migrateV2Upgrades(rawLevels: any, profile: Types.PlayerProfile): number
	if type(rawLevels) ~= "table" then
		return 0
	end
	local refund = 0
	for rawId, lvl in rawLevels do
		if type(rawId) ~= "string" then
			continue
		end
		-- A renamed upgrade (gloves -> net) carries its level unless the new id was saved too.
		local renamed = Catalog.renamedUpgrades[rawId]
		local id = if renamed ~= nil and rawLevels[renamed] == nil then renamed else rawId
		local def = Catalog.getUpgrade(id)
		local start = V2_START_LEVELS[id] or (if def ~= nil then def.startLevel else 0)
		local level = math.max(start, asInt(lvl, start))
		if def == nil then
			-- Removed in version 3 (cafe_level, park_access): give back what was spent.
			refund += v2Spent(id, start, level)
		else
			level = math.min(level, def.maxLevel)
			local cap = (Catalog.tiers[1].caps :: any)[id]
			if type(cap) == "number" and level > cap then
				refund += v2Spent(id, cap, level)
				level = cap
			end
			profile.upgradeLevels[def.id] = level
		end
	end
	return refund
end

local function migrateV3Upgrades(rawLevels: any, profile: Types.PlayerProfile)
	if type(rawLevels) ~= "table" then
		return
	end
	for id, lvl in rawLevels do
		local def = if type(id) == "string" then Catalog.getUpgrade(id) else nil
		if def ~= nil then
			profile.upgradeLevels[def.id] =
				math.clamp(asInt(lvl, def.startLevel), def.startLevel, def.maxLevel)
		end
	end
end

-- A saved cat or bait variant: "gold", "rainbow" (F99), or "shiny" from a version 3 save (Derek 2026-10-27 renamed
-- shiny to gold); anything else is the base coat.
local function variantOf(value: any): string
	return if value == "rainbow"
		then "rainbow"
		elseif value == "gold" or value == "shiny" then "gold"
		else "base"
end

-- A saved name, cut to MAX_NAME_LENGTH bytes on a character boundary; nil when empty or not valid UTF-8
-- (reviewer N36). RenameCat enforces the real rules on the way in.
local function sanitizeName(value: any): string?
	if type(value) ~= "string" then
		return nil
	end
	local name: string = value
	if #name == 0 or utf8.len(name) == nil then
		return nil
	end
	if #name > MAX_NAME_LENGTH then
		local cut = MAX_NAME_LENGTH
		-- Step back past continuation bytes (10xxxxxx) so the cut never splits a character.
		while cut > 0 and bit32.band(string.byte(name, cut + 1), 0xC0) == 0x80 do
			cut -= 1
		end
		name = string.sub(name, 1, cut)
	end
	return name
end

local function sanitizeMethod(value: any): Types.CatchMethod?
	if
		value == "net"
		or value == "rescue"
		or value == "bait"
		or value == "starter"
		or value == "trade"
	then
		return value
	end
	return nil
end

-- How a cat saved before version 3 was found: the template's starter, a rescue, otherwise the net.
local function legacyMethod(uid: string, entry: any): Types.CatchMethod
	if uid == STARTER_UID then
		return "starter"
	elseif entry.rescued == true then
		return "rescue"
	end
	return "net"
end

-- One saved cat as this version keeps it (`entry` already has a known catId); `spotId` checked by the caller.
local function catFrom(
	uid: string,
	entry: any,
	fromVersion: number,
	now: number,
	spotId: string?
): Types.CatInstance
	local instance: Types.CatInstance = {
		uid = uid,
		catId = entry.catId,
		-- Golden and Galaxy were never handed out; only "shiny" survives, and it is "gold" now.
		variant = variantOf(entry.variant),
		caughtAt = asInt(entry.caughtAt, now),
		spotId = spotId,
		-- Version 1 cats had no stats: they become level 1 with neutral charm (a 1.0x rate). Before version 12 the
		-- cap was 10 at 5% a level: the level moves onto the 50-level curve and the xp toward it starts again.
		level = if fromVersion >= 12
			then math.clamp(
				asInt(entry.level, CatStats.MIN_LEVEL),
				CatStats.MIN_LEVEL,
				Config.CatMaxLevel
			)
			else CatStats.remapLevel(asInt(entry.level, CatStats.MIN_LEVEL)),
		xp = if fromVersion >= 12 then asNumber(entry.xp, 0) else 0,
		charm = math.clamp(
			asInt(entry.charm, CatStats.DEFAULT_CHARM),
			CatStats.MIN_CHARM,
			CatStats.MAX_CHARM
		),
		rescued = if entry.rescued == true then true else nil,
		name = if fromVersion >= 3 then sanitizeName(entry.name) else nil,
		method = if fromVersion >= 3
			then sanitizeMethod(entry.method)
			else legacyMethod(uid, entry),
	}
	-- F62: the saved lock; a save from before version 14 locks its gold, Legendary and Mythical cats
	local locked = if fromVersion >= 14
		then entry.locked == true
		else CatStats.arrivesLocked(instance.catId, instance.variant)
	instance.locked = if locked then true else nil
	return instance
end

local function sanitizeCats(
	raw: any,
	profile: Types.PlayerProfile,
	fromVersion: number,
	now: number
)
	if type(raw.cats) ~= "table" then
		return
	end
	profile.cats = {}
	local usedSpots: { [string]: boolean } = {}
	for uid, entry in raw.cats do
		if
			type(uid) ~= "string"
			or type(entry) ~= "table"
			or type(entry.catId) ~= "string"
			or Catalog.getCat(entry.catId) == nil
		then
			continue
		end
		-- Version 3 slots are role slots; older spot ids are cleared and Equip Best fills the roles afterwards.
		local spotId: string? = nil
		if fromVersion >= 3 and type(entry.spotId) == "string" then
			local spot = Catalog.getSpot(entry.spotId)
			if spot ~= nil and spot.tier <= profile.tier and not usedSpots[spot.id] then
				spotId = spot.id
				usedSpots[spot.id] = true
			end
		end
		profile.cats[uid] = catFrom(uid, entry, fromVersion, now, spotId)
	end
end

local function sanitizeCollection(value: any, now: number): { [string]: number }
	local out: { [string]: number } = {}
	if type(value) == "table" then
		for catId, at in value do
			if type(catId) == "string" and Catalog.getCat(catId) ~= nil then
				out[catId] = asInt(at, now)
			end
		end
	end
	return out
end

local function sanitizeBait(value: any): Types.BaitState?
	if type(value) ~= "table" then
		return nil
	end
	if type(value.lureId) ~= "string" or Catalog.getLure(value.lureId) == nil then
		return nil
	end
	if type(value.catId) ~= "string" or Catalog.getCat(value.catId) == nil then
		return nil
	end
	if type(value.placedAt) ~= "number" or value.placedAt ~= value.placedAt then
		return nil
	end
	local placedAt = math.floor(value.placedAt)
	-- F54: the arrival UseLure fixed, inside the longest wait (an old save has none and waits LureWaitSeconds)
	local readyAt: number? = nil
	if type(value.readyAt) == "number" and value.readyAt == value.readyAt then
		readyAt = math.clamp(math.floor(value.readyAt), placedAt, placedAt + Config.LureWaitSeconds)
	end
	return {
		lureId = value.lureId,
		placedAt = placedAt,
		readyAt = readyAt,
		night = if value.night == true then true else nil, -- F60: night bait, only ever true
		catId = value.catId,
		variant = variantOf(value.variant),
		charm = math.clamp(
			asInt(value.charm, CatStats.DEFAULT_CHARM),
			CatStats.MIN_CHARM,
			CatStats.MAX_CHARM
		),
	}
end

-- Unopened crates (F53): known crate ids with a whole count above 0.
local function sanitizeCrates(value: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(value) == "table" then
		for id, count in value do
			if type(id) == "string" and Catalog.getCrate(id) ~= nil then
				local n = asInt(count, 0)
				if n > 0 then
					out[id] = n
				end
			end
		end
	end
	return out
end

-- Opens since each pool's last Epic or better (F53): known pools, 0 to CrateLuckyEvery - 1.
local function sanitizeCrateLuck(value: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(value) == "table" then
		for pool, count in value do
			if type(pool) == "string" and Catalog.cratePools[pool] then
				local n = math.min(asInt(count, 0), Config.CrateLuckyEvery - 1)
				if n > 0 then
					out[pool] = n
				end
			end
		end
	end
	return out
end

-- Golden Fish Market perks (F53): known perk ids, 1 to the perk's maxLevel.
local function sanitizeFishPerks(value: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(value) == "table" then
		for id, level in value do
			local row = if type(id) == "string" then Catalog.getFishShopRow(id) else nil
			if row ~= nil and row.kind == "perk" then
				local n = math.min(asInt(level, 0), row.maxLevel or 0)
				if n > 0 then
					out[id] = n
				end
			end
		end
	end
	return out
end

-- The potion bag (F64): known potion ids with a whole count above 0.
local function sanitizePotions(value: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(value) == "table" then
		for id, count in value do
			if type(id) == "string" and Catalog.getPotion(id) ~= nil then
				local n = asInt(count, 0)
				if n > 0 then
					out[id] = n
				end
			end
		end
	end
	return out
end

-- Running potions (F64): known potion ids with seconds of play time left, above 0 and at most PotionMaxMinutes.
local function sanitizeBuffs(value: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(value) == "table" then
		for id, left in value do
			if type(id) == "string" and Catalog.getPotion(id) ~= nil then
				local seconds = math.min(asNumber(left, 0), Config.PotionMaxMinutes * 60)
				if seconds > 0 then
					out[id] = seconds
				end
			end
		end
	end
	return out
end

-- A save's quest slots (F73), in order up to `slots` and dense (the N116 lesson): a string id (QuestService gives an
-- unknown or misplaced one a fresh pick), a whole base of 0 or more and needs of at least 1.
local function sanitizeQuestList(value: any, slots: number): { Types.QuestEntry }
	local out: { Types.QuestEntry } = {}
	if type(value) ~= "table" then
		return out
	end
	for slot = 1, slots do
		local entry = value[slot]
		if type(entry) ~= "table" then
			break
		end
		table.insert(out, {
			id = if type(entry.id) == "string" then string.sub(entry.id, 1, 40) else "",
			base = math.max(0, asInt(entry.base, 0)),
			needs = math.max(1, asInt(entry.needs, 1)),
			claimed = entry.claimed == true,
		})
	end
	return out
end

local function sanitizeQuests(value: any): Types.QuestState
	local quests = newQuests()
	if type(value) ~= "table" then
		return quests
	end
	quests.day = asInt(value.day, 0)
	quests.daily = sanitizeQuestList(value.daily, Config.QuestDailyCount)
	quests.dailyReroll = value.dailyReroll == true
	quests.dailySet = value.dailySet == true
	quests.week = asInt(value.week, 0)
	quests.weekly = sanitizeQuestList(value.weekly, Config.QuestWeeklyCount)
	quests.weeklyReroll = value.weeklyReroll == true
	quests.weeklySet = value.weeklySet == true
	return quests
end

-- Claimed achievements (F73): known ids only.
local function sanitizeAchievements(value: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(value) == "table" then
		for id, claimed in value do
			if type(id) == "string" and claimed == true and Catalog.getAchievement(id) ~= nil then
				out[id] = true
			end
		end
	end
	return out
end

-- Redeemed codes (F65): any code id a code could have had (letters and digits, up to CodeMaxLength) with a time, so
-- a code row removed and later added back still counts as used.
local function sanitizeCodes(value: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(value) == "table" then
		for id, at in value do
			if
				type(id) == "string"
				and #id <= Config.CodeMaxLength
				and string.match(id, "^%w+$") ~= nil
				and type(at) == "number"
			then
				out[id] = asInt(at, 0)
			end
		end
	end
	return out
end

-- F87: a state saved before version 19 counts its steps in the 12 step funnel v1, one before #1273 in the 25 step
-- funnel v2; Onboarding.fromOld takes either out of the funnel v3 once it had logged a first catch, else back to its
-- start (#1273: no save version, since `funnel` already tells the funnels apart). A first day in the future is
-- clamped to today.
local function sanitizeTelemetry(value: any, now: number): Types.TelemetryState
	local telemetry: Types.TelemetryState = {
		onboardingStep = 0,
		achieved = {},
		funnel = Onboarding.VERSION,
		firstDay = 0,
		introStep = 0,
	}
	if type(value) ~= "table" then
		return telemetry
	end
	local step = math.max(0, asInt(value.onboardingStep, 0))
	local achieved: { [string]: boolean } = {}
	local introStep = math.max(0, asInt(value.introStep, 0))
	if value.funnel == Onboarding.VERSION then
		if type(value.achieved) == "table" then
			for key, held in value.achieved do
				if type(key) == "string" and held == true then
					achieved[key] = true
				end
			end
		end
	else
		local old = if type(value.funnel) == "number" then value.funnel else nil
		step = Onboarding.fromOld(old, step)
		-- a player out of the funnel is out of the intro one too
		introStep = if step >= Onboarding.COUNT then Onboarding.INTRO_COUNT else 0
	end
	telemetry.onboardingStep = math.clamp(step, 0, Onboarding.COUNT)
	for later = telemetry.onboardingStep + 1, Onboarding.COUNT do
		local key = tostring(later)
		if achieved[key] == true then
			telemetry.achieved[key] = true
		end
	end
	telemetry.introStep = math.clamp(introStep, 0, Onboarding.INTRO_COUNT)
	telemetry.firstDay = math.clamp(asInt(value.firstDay, 0), 0, now // DAY_SECONDS)
	return telemetry
end

-- Takes whatever was loaded (any version up to this one, possibly damaged) and returns a valid current profile.
-- Unknown catalog ids are dropped so a removed cat or upgrade never breaks loading. Migrates forward only:
-- callers check isNewerThanCode first, because this would strip a newer save down to this version.
--
-- Version 2 to 3 (data-model section 14): Tier 1; refunds cafe_level levels above 1, park_access, and tables,
-- espresso and net levels above the Tier 1 caps at the version 2 prices; clears every cat's spot and runs Equip
-- Best once to fill barista_1 and waiter_1; method "starter" for the first Tabby, "rescue" for rescued cats and
-- "net" for the rest; equippedLure (the v0.2 lure spots, replaced by the bait bowl in F28) and renovations are
-- dropped.
function ProfileSchema.migrate(raw: any, now: number): Types.PlayerProfile
	local profile = ProfileSchema.template(now)
	if type(raw) ~= "table" then
		return profile
	end
	local fromVersion = math.min(ProfileSchema.versionOf(raw), ProfileSchema.VERSION)

	profile.coins = asNumber(raw.coins, profile.coins)
	profile.lifetimeCoins = asNumber(raw.lifetimeCoins, 0)
	profile.lastTick = asInt(raw.lastTick, now)
	profile.lastSeen = asInt(raw.lastSeen, now)
	profile.rateAtLogout = asNumber(raw.rateAtLogout, 0)
	profile.tutorialStep = math.clamp(asInt(raw.tutorialStep, 0), 0, 5)
	profile.tier = if fromVersion >= 3
		then math.clamp(asInt(raw.tier, 1), 1, Catalog.maxTier)
		else 1

	if fromVersion >= 3 then
		migrateV3Upgrades(raw.upgradeLevels, profile)
	else
		profile.coins += migrateV2Upgrades(raw.upgradeLevels, profile)
	end

	if type(raw.decorOwned) == "table" then
		for id, owned in raw.decorOwned do
			if type(id) == "string" and owned == true and Catalog.getDecor(id) ~= nil then
				profile.decorOwned[id] = true
			end
		end
	end
	if type(raw.decorPlaced) == "table" then
		for id, placed in raw.decorPlaced do
			if type(id) == "string" and placed == true and profile.decorOwned[id] then
				profile.decorPlaced[id] = true
			end
		end
	end

	if type(raw.lures) == "table" then
		for id, count in raw.lures do
			if type(id) == "string" and Catalog.getLure(id) ~= nil then
				local n = asInt(count, 0)
				if n > 0 then
					profile.lures[id] = n
				end
			end
		end
	end
	if fromVersion >= 3 then
		profile.bait = sanitizeBait(raw.bait)
	end
	if fromVersion >= 34 then
		profile.bait2 = sanitizeBait(raw.bait2) -- #1161: kept even if the pass is not seen this session
	end

	sanitizeCats(raw, profile, fromVersion, now)

	profile.collection = sanitizeCollection(raw.collection, now)
	for _, instance in profile.cats do
		if profile.collection[instance.catId] == nil then
			profile.collection[instance.catId] = instance.caughtAt
		end
	end
	-- Version 3 called it shinyCollection (Derek 2026-10-27: shiny is gold now); a later save only has goldCollection.
	if fromVersion >= 4 then
		profile.goldCollection = sanitizeCollection(raw.goldCollection, now)
	elseif fromVersion == 3 then
		profile.goldCollection = sanitizeCollection(raw.shinyCollection, now)
	end
	for _, instance in profile.cats do
		if instance.variant == "gold" and profile.goldCollection[instance.catId] == nil then
			profile.goldCollection[instance.catId] = instance.caughtAt
		end
	end
	-- F99: the rainbow coats found (version 24); every rainbow cat owned is in it
	profile.rainbowCollection = sanitizeCollection(raw.rainbowCollection, now)
	for _, instance in profile.cats do
		if instance.variant == "rainbow" and profile.rainbowCollection[instance.catId] == nil then
			profile.rainbowCollection[instance.catId] = instance.caughtAt
		end
	end

	-- Index reward claims (F48); saves before version 5 have none and can claim every milestone they passed.
	if type(raw.indexRewards) == "table" then
		for areaId, claims in raw.indexRewards do
			local prizes = if type(areaId) == "string" then Catalog.indexPrizes[areaId] else nil
			if prizes ~= nil and type(claims) == "table" then
				local kept: { [string]: boolean } = {}
				for milestoneId, claimed in claims do
					if
						type(milestoneId) == "string"
						and claimed == true
						and prizes[milestoneId] ~= nil
					then
						kept[milestoneId] = true
					end
				end
				if next(kept) ~= nil then
					profile.indexRewards[areaId] = kept
				end
			end
		end
	end

	-- The Spin Wheel (F49); saves before version 6 have no spins banked and today's free spin due.
	profile.spin = Spin.sanitize(raw.spin, now)

	-- Golden fish, crates and Market perks (F52, F53); saves before version 7 start with none.
	profile.goldenFish = asInt(raw.goldenFish, 0)
	profile.lifetimeGoldenFish = math.max(asInt(raw.lifetimeGoldenFish, 0), profile.goldenFish)
	profile.crates = sanitizeCrates(raw.crates)
	profile.crateLuck = sanitizeCrateLuck(raw.crateLuck)
	profile.fishPerks = sanitizeFishPerks(raw.fishPerks)
	profile.codesRedeemed = sanitizeCodes(raw.codesRedeemed) -- F65; saves before version 9 have used none
	-- F72: every save from before version 10 plays the intro once too (Derek, intro-cutscene.md answer 2)
	profile.introSeen = raw.introSeen == true
	profile.potions = sanitizePotions(raw.potions) -- F64; saves before version 13 hold none
	profile.buffs = sanitizeBuffs(raw.buffs)
	profile.quests = sanitizeQuests(raw.quests) -- F73; saves before version 16 have none and roll on load
	profile.achievements = sanitizeAchievements(raw.achievements)
	profile.dailyTreat = DailyTreat.sanitize(raw.dailyTreat, now) -- F70; saves before version 17 start a fresh card
	-- F94; saves before version 18 have bought nothing on the shelf, and their dealer counts are dropped
	profile.freshCatch = FreshCatch.sanitize(raw.freshCatch, now)

	if type(raw.stats) == "table" then
		local stats = profile.stats :: any
		for key, default in newStats() :: any do
			if type(default) == "number" then
				stats[key] = asInt(raw.stats[key], 0)
			end
		end
		-- F98 (version 23): a rate keeps its fractions; older saves have none of the three
		stats.bestRate = asNumber(raw.stats.bestRate, 0)
		stats.weekPlay = sanitizeWeekly(raw.stats.weekPlay, "seconds")
		stats.weekBestRate = sanitizeWeekly(raw.stats.weekBestRate, "rate")
		-- F102 (version 27)
		stats.tradesToday = Trade.sanitizeToday(raw.stats.tradesToday)
	end
	profile.settings = Settings.sanitize(raw.settings)

	if fromVersion >= 3 and type(raw.flags) == "table" then
		profile.flags.autoPress = raw.flags.autoPress == true
	end
	profile.telemetry = sanitizeTelemetry(raw.telemetry, now)
	-- F87 (version 20): an older save past the first loop has met everything the tips explain
	profile.tipsSeen =
		Tips.sanitizeSeen(raw.tipsSeen, fromVersion < 20 and profile.tutorialStep >= 5)
	profile.feedbackAsked = raw.feedbackAsked == true
	profile.stuckHelpShown = Tips.sanitizeHelp(raw.stuckHelpShown)
	-- F96 (version 21): the one free Bellhop Cat, kept claimed by the flag or by owning one
	profile.starterCatClaimed = raw.starterCatClaimed == true
	for _, instance in profile.cats do
		if instance.catId == StarterCat.CAT_ID then
			profile.starterCatClaimed = true
		end
	end

	-- F96 (version 22): when the notification ask first showed, never in the future
	profile.notifyAskAt = math.clamp(asInt(raw.notifyAskAt, 0), 0, now)
	-- F100 (version 25): the camp extras, settled for the tier by CampExtraService once the profile loads
	profile.campExtras = CampExtras.sanitize(raw.campExtras, now)
	-- F101 (version 26): the Rescue Rally laps this weekend
	profile.rally = Rally.sanitize(raw.rally, now)
	-- F102 (version 27): the Trades page and the trades this save has applied
	profile.tradeLog = Trade.sanitizeLog(raw.tradeLog)
	profile.tradeIds = Trade.sanitizeIds(raw.tradeIds)
	-- F91 (version 28): the front lawn, kept to what the tier opens
	profile.lawnOwned, profile.lawn, profile.lawnStyles =
		Lawn.sanitize(raw.lawnOwned, raw.lawn, raw.lawnStyles, profile.tier)
	-- #1574 (no new version): the Legendary and up pieces unlocked to trade, owned ones only. An older server drops the
	-- list, which only locks those pieces again.
	profile.decorUnlocked = {}
	if type(raw.decorUnlocked) == "table" then
		for id, unlocked in raw.decorUnlocked do
			if
				type(id) == "string"
				and unlocked == true
				and Trade.ownsPiece(profile, id)
				and Trade.pieceLocked(profile, id)
			then
				profile.decorUnlocked[id] = true
			end
		end
	end
	-- #1052 (version 29): the Corner Shop; saves before it have bought nothing and fed no snacks
	profile.cornerShop = CornerShop.sanitize(raw.cornerShop, now)
	-- #1537 (version 35): the Yard Sale's lawn rows bought today; saves before it have bought none
	profile.yardDecor = YardSale.sanitize(raw.yardDecor)
	-- #1083 (version 30): only true hides the name on the Thank You board; anything else is shown
	profile.hideCredit = if raw.hideCredit == true then true else nil
	-- #1182 (version 31): the granted PurchaseIds, kept as strings, newest last; older saves have granted none
	profile.receipts = Products.sanitize(raw.receipts)
	-- #1625 (version 35): the once-per-account products bought, the saved sign styles and the pick; none before
	profile.onceBought = Products.sanitizeOnce(raw.onceBought)
	profile.signStyles = SignStyles.sanitize(raw.signStyles)
	profile.signStyle = SignStyles.sanitizePick(raw.signStyle)
	-- #1645 (version 36): the Cafe Pass; saves before it start at season 0 with nothing (CafePassService rolls it on)
	profile.pass = CafePass.sanitize(raw.pass)
	-- #1624 (version 38): the theme and uniform picks, known ids only; saves before it show Classic
	profile.looks = Looks.sanitize(raw.looks)
	-- #1181 (version 32): the Bag's cat food, known foods only, whole counts of 1 to CatFoodMax
	if type(raw.catFood) == "table" then
		for _, food in Catalog.catFood do
			local count = raw.catFood[food.id]
			if type(count) == "number" and count == count and count >= 1 then
				profile.catFood[food.id] = math.min(math.floor(count), Config.CatFoodMax)
			end
		end
	end

	if fromVersion < 3 then
		EquipBest.apply(profile, EquipBest.plan(profile))
	end

	profile.version = ProfileSchema.VERSION
	return profile
end

-- F102: a cat from outside the save (a stored trade record on the recovery path) made whole as a cat of this version
-- is, with no spot; nil unless it has a string uid and a known catId.
function ProfileSchema.cleanCat(entry: any, now: number): Types.CatInstance?
	if
		type(entry) ~= "table"
		or type(entry.uid) ~= "string"
		or #entry.uid == 0
		or type(entry.catId) ~= "string"
		or Catalog.getCat(entry.catId) == nil
	then
		return nil
	end
	return catFrom(entry.uid, entry, ProfileSchema.VERSION, now, nil)
end

function ProfileSchema.catCount(profile: Types.PlayerProfile): number
	local n = 0
	for _ in profile.cats do
		n += 1
	end
	return n
end

function ProfileSchema.collectionCount(profile: Types.PlayerProfile): number
	local n = 0
	for _ in profile.collection do
		n += 1
	end
	return n
end

return ProfileSchema
