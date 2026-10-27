--!strict
-- Save data (data-model section 14): template, migration and sanitising. Pure.

local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local EquipBest = require(script.Parent.EquipBest)
local Onboarding = require(script.Parent.Onboarding)
local Types = require(script.Parent.Types)

local ProfileSchema = {}

-- Version 2 (2026-10-26) added level, xp and charm per cat. Version 3 (2026-10-26, design v0.3) adds the tier,
-- role slots, bait, the dealer, shinies, cat names and how each cat was found; cafe_level and park_access go.
-- Version 4 (2026-10-27) renames shiny to gold. Version 5 (F48) adds indexRewards and stats.tipJarClaims: an older
-- server would drop them, and a player hopping servers could claim every Index reward again (reviewer S60).
ProfileSchema.VERSION = 5

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
local DEALER_SLOTS = 3

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
		lures = {},
		bait = nil,
		dealer = { window = 0, bought = {} },
		cats = {
			[STARTER_UID] = starter,
		},
		collection = { tabby = now },
		goldCollection = {},
		indexRewards = {},
		stats = newStats(),
		tutorialStep = 0,
		settings = { music = true, sfx = true },
		flags = { autoPress = false },
		telemetry = { onboardingStep = 0, achieved = {} },
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

-- A saved cat or bait variant: "gold", or "shiny" from a version 3 save (Derek 2026-10-27 renamed shiny to gold);
-- anything else is the base coat.
local function variantOf(value: any): string
	return if value == "gold" or value == "shiny" then "gold" else "base"
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
	if value == "net" or value == "rescue" or value == "bait" or value == "starter" then
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
		local instance: Types.CatInstance = {
			uid = uid,
			catId = entry.catId,
			-- Golden and Galaxy were never handed out; only "shiny" survives, and it is "gold" now.
			variant = variantOf(entry.variant),
			caughtAt = asInt(entry.caughtAt, now),
			spotId = spotId,
			-- Version 1 cats had no stats: they become level 1 with neutral charm (a 1.0x rate).
			level = math.clamp(
				asInt(entry.level, CatStats.MIN_LEVEL),
				CatStats.MIN_LEVEL,
				Config.CatMaxLevel
			),
			xp = asInt(entry.xp, 0),
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
		profile.cats[uid] = instance
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
	return {
		lureId = value.lureId,
		placedAt = math.floor(value.placedAt),
		catId = value.catId,
		variant = variantOf(value.variant),
		charm = math.clamp(
			asInt(value.charm, CatStats.DEFAULT_CHARM),
			CatStats.MIN_CHARM,
			CatStats.MAX_CHARM
		),
	}
end

local function sanitizeTelemetry(value: any): Types.TelemetryState
	local telemetry: Types.TelemetryState = { onboardingStep = 0, achieved = {} }
	if type(value) ~= "table" then
		return telemetry
	end
	telemetry.onboardingStep = math.clamp(asInt(value.onboardingStep, 0), 0, Onboarding.COUNT)
	if type(value.achieved) == "table" then
		for step = telemetry.onboardingStep + 1, Onboarding.COUNT do
			local key = tostring(step)
			if value.achieved[key] == true then
				telemetry.achieved[key] = true
			end
		end
	end
	return telemetry
end

local function sanitizeDealer(value: any): Types.DealerState
	local dealer: Types.DealerState = { window = 0, bought = {} }
	if type(value) ~= "table" then
		return dealer
	end
	dealer.window = asInt(value.window, 0)
	if type(value.bought) == "table" then
		for slot = 1, DEALER_SLOTS do
			local key = tostring(slot)
			if value.bought[key] == true then
				dealer.bought[key] = true
			end
		end
	end
	return dealer
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
		profile.dealer = sanitizeDealer(raw.dealer)
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

	if type(raw.stats) == "table" then
		local stats = profile.stats :: any
		for key in newStats() :: any do
			stats[key] = asInt(raw.stats[key], 0)
		end
	end
	if type(raw.settings) == "table" then
		profile.settings.music = raw.settings.music ~= false
		profile.settings.sfx = raw.settings.sfx ~= false
	end

	if fromVersion >= 3 and type(raw.flags) == "table" then
		profile.flags.autoPress = raw.flags.autoPress == true
	end
	profile.telemetry = sanitizeTelemetry(raw.telemetry)

	if fromVersion < 3 then
		EquipBest.apply(profile, EquipBest.plan(profile))
	end

	profile.version = ProfileSchema.VERSION
	return profile
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
