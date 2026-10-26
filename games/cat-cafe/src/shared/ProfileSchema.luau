--!strict
-- Save data version 1 (data-model section 14): template, migration and sanitising. Pure.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local ProfileSchema = {}

ProfileSchema.VERSION = 1

local function asNumber(value: any, default: number): number
	if type(value) == "number" and value == value and value >= 0 and value < math.huge then
		return value
	end
	return default
end

local function asInt(value: any, default: number): number
	return math.floor(asNumber(value, default))
end

-- Starting profile: 50 coins, one Tabby placed on counter_1. `now` is server os.time().
function ProfileSchema.template(now: number): Types.PlayerProfile
	local levels: { [string]: number } = {}
	for _, def in Catalog.upgrades do
		levels[def.id] = def.startLevel
	end
	return {
		version = ProfileSchema.VERSION,
		coins = Config.StartCoins,
		lifetimeCoins = 0,
		lastTick = now,
		lastSeen = now,
		rateAtLogout = 0,
		upgradeLevels = levels,
		decorOwned = {},
		decorPlaced = {},
		lures = {},
		equippedLure = nil,
		cats = {
			starter_tabby = {
				uid = "starter_tabby",
				catId = "tabby",
				variant = "base",
				caughtAt = now,
				spotId = "counter_1",
			},
		},
		collection = { tabby = now },
		stats = {
			catsCaught = 0,
			catsSold = 0,
			grabsAttempted = 0,
			grabsSucceeded = 0,
			luresUsed = 0,
			playtimeSeconds = 0,
			sessions = 0,
		},
		tutorialStep = 0,
		settings = { music = true, sfx = true },
	}
end

-- Takes whatever was loaded (any version, possibly damaged) and returns a valid current profile.
-- Unknown catalog ids are dropped so a removed cat or upgrade never breaks loading. Migrates forward only.
function ProfileSchema.migrate(raw: any, now: number): Types.PlayerProfile
	local profile = ProfileSchema.template(now)
	if type(raw) ~= "table" then
		return profile
	end

	profile.coins = asNumber(raw.coins, profile.coins)
	profile.lifetimeCoins = asNumber(raw.lifetimeCoins, 0)
	profile.lastTick = asInt(raw.lastTick, now)
	profile.lastSeen = asInt(raw.lastSeen, now)
	profile.rateAtLogout = asNumber(raw.rateAtLogout, 0)
	profile.tutorialStep = math.clamp(asInt(raw.tutorialStep, 0), 0, 4)

	if type(raw.upgradeLevels) == "table" then
		for id, lvl in raw.upgradeLevels do
			local def = if type(id) == "string" then Catalog.getUpgrade(id) else nil
			if def ~= nil then
				profile.upgradeLevels[id] =
					math.clamp(asInt(lvl, def.startLevel), def.startLevel, def.maxLevel)
			end
		end
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
	if type(raw.equippedLure) == "string" and (profile.lures[raw.equippedLure] or 0) > 0 then
		profile.equippedLure = raw.equippedLure
	end

	if type(raw.cats) == "table" then
		profile.cats = {}
		local usedSpots: { [string]: boolean } = {}
		for uid, entry in raw.cats do
			if
				type(uid) == "string"
				and type(entry) == "table"
				and type(entry.catId) == "string"
				and Catalog.getCat(entry.catId) ~= nil
			then
				local spotId: string? = nil
				if
					type(entry.spotId) == "string"
					and Catalog.getSpot(entry.spotId) ~= nil
					and not usedSpots[entry.spotId]
				then
					spotId = entry.spotId
					usedSpots[entry.spotId] = true
				end
				profile.cats[uid] = {
					uid = uid,
					catId = entry.catId,
					variant = if type(entry.variant) == "string" then entry.variant else "base",
					caughtAt = asInt(entry.caughtAt, now),
					spotId = spotId,
				}
			end
		end
	end

	profile.collection = {}
	if type(raw.collection) == "table" then
		for catId, at in raw.collection do
			if type(catId) == "string" and Catalog.getCat(catId) ~= nil then
				profile.collection[catId] = asInt(at, now)
			end
		end
	end
	for _, instance in profile.cats do
		if profile.collection[instance.catId] == nil then
			profile.collection[instance.catId] = instance.caughtAt
		end
	end

	if type(raw.stats) == "table" then
		local stats = profile.stats
		stats.catsCaught = asInt(raw.stats.catsCaught, 0)
		stats.catsSold = asInt(raw.stats.catsSold, 0)
		stats.grabsAttempted = asInt(raw.stats.grabsAttempted, 0)
		stats.grabsSucceeded = asInt(raw.stats.grabsSucceeded, 0)
		stats.luresUsed = asInt(raw.stats.luresUsed, 0)
		stats.playtimeSeconds = asInt(raw.stats.playtimeSeconds, 0)
		stats.sessions = asInt(raw.stats.sessions, 0)
	end
	if type(raw.settings) == "table" then
		profile.settings.music = raw.settings.music ~= false
		profile.settings.sfx = raw.settings.sfx ~= false
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
