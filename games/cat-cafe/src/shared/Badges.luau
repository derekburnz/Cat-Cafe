--!strict
-- Roblox badges (#1934, release.md section 1), pure: the badges in their order (#3618; 5 a day are made free; #5160 retired six and added five), what
-- earns each, read from the profile alone, and which are due. The server's BadgeAwardService awards them; nothing
-- here is sent to the client. A badge is earned by playing only: never for liking, favouriting, buying or inviting
-- (a shop-only cat counts toward none), and nothing has a streak that can be lost once earned.
--   id(key) -> number                         the Roblox badge id in Config.Badges, 0 while not made
--   earned(profile) -> { key }                every badge the profile has earned, in LIST order
--   due(profile, owned, waitUntil, now) -> { key }  earned, made, not owned, not waiting on a retry, and allowed
--   allowed(profile, key) -> boolean          #4775: before Tier 3 only the EARLY badges award, none before Tier 2
--   noteFinish(stats, purrfect)               a net catch's end: counts a PURRFECT and its run, or ends the run

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local IndexRewards = require(script.Parent.IndexRewards)
local Types = require(script.Parent.Types)

type Profile = Types.PlayerProfile

local Badges = {}

Badges.WELCOME_STEP = 5 -- tutorialStep once the first loop ends
Badges.COLLECTOR_CATS = 25
Badges.EXPERT_CATS = 50
Badges.MASTER_CATS = 100 -- #5160
Badges.PURRFECT_RUN = 5
-- #4775 (Derek 2026-11-16: "way too many pop up badges in the first bit of game ... no more then 2 until tier 3"):
-- below QUIET_BELOW_TIER only these two award; every other badge earned meanwhile waits for Tier 3, then comes out
-- one at a time (BadgeAwardService's AWARD_GAP_SECONDS).
Badges.QUIET_BELOW_TIER = 3
Badges.EARLY = table.freeze({ cozyCafe = true }) :: { [string]: boolean } -- #5160: First Catch retired
-- Derek 2026-11-16 15:22 UTC ("no unnecessary pop ups until tutorial steps done"): below TUTORIAL_TIER (the
-- walk-through ends at the Tier 2 rank up) none award, the EARLY two included; they come out at Tier 2.
Badges.TUTORIAL_TIER = 2

-- key: the Config.Badges field; name and description: what Creator Hub shows (one plain line, nothing pressuring)
export type Badge = {
	key: string,
	name: string,
	description: string,
	earned: (profile: Profile) -> boolean,
}

local function atTier(n: number): (Profile) -> boolean
	return function(profile: Profile): boolean
		return Economy.tier(profile) >= n
	end
end

local function owns(rarity: Types.Rarity): (Profile) -> boolean
	return function(profile: Profile): boolean
		return Economy.distinctCatsAtLeast(profile, rarity) >= 1
	end
end

-- A coat collection (catId -> first caught at) holding a cat that is not shop-only.
local function anyCoat(collection: { [string]: number }): boolean
	for catId in collection do
		local def = Catalog.getCat(catId)
		-- #4251: a harvest coat gives no coat badge (Design spec 3b: harvest cats count toward no reward)
		if def == nil or (def.exclusive ~= true and def.area ~= "harvest") then
			return true
		end
	end
	return false
end

-- Each area's Index page size: its cats that count on the page (IndexRewards.progress's rule).
local pageSize: { [string]: number } = {}
for _, def in Catalog.cats do
	if
		def.area ~= "spare"
		and def.area ~= "secret"
		and def.area ~= "harvest"
		and def.exclusive ~= true
	then
		pageSize[def.area] = (pageSize[def.area] or 0) + 1
	end
end

-- #3618: any upgrade bought past where a new cafe starts (the first table is open from the start, #3660).
local function boughtUpgrade(profile: Profile): boolean
	for upgradeId, level in profile.upgradeLevels do
		local def = Catalog.getUpgrade(upgradeId)
		local start = if def ~= nil then def.startLevel else 0
		if upgradeId == "tables" then
			start = math.max(start, Config.StartTables)
		elseif upgradeId == "lure_bowl" then
			start = math.max(start, Config.StartBowls) -- #4097: the Bait bowl is open from the start too
		end
		if level > start then
			return true
		end
	end
	return false
end

local function pageComplete(profile: Profile): boolean
	for areaId, size in pageSize do
		if size > 0 and IndexRewards.progress(profile.collection, areaId) >= size then
			return true
		end
	end
	return false
end

-- #3618 (Derek 2026-11-12: "tier 1,2,3,4,5,6,7 badges ... first badges should be like finished tutorial steps"):
-- badges-order.md's 28, in the order they are awarded and listed. The 22 made before keep their ids and rules.
local LIST: { Badge } = {
	-- #5160 (Derek 2026-11-17: "remove old ones not really needed ... take away some of the badge bloat"): the six
	-- first-step badges (First Catch, Home Sweet Home, Fixing Up, Liftoff, Welcome to the Cafe, Grand Opening) are
	-- retired: no longer awarded, disabled on Roblox. Their ids stay in Config.Badges' notes.
	-- Cafe tiers, named after the tiers in the game
	-- given once the tutorial is finished, so it never pops over the tutorial
	{
		key = "cornerCafe",
		name = "Corner Cafe",
		description = "Open your Tier 1 cafe.",
		earned = function(profile)
			return profile.tutorialStep >= Badges.WELCOME_STEP
		end,
	},
	{
		key = "cozyCafe",
		name = "Cozy Cafe",
		description = "Rank your cafe up to Tier 2.",
		earned = atTier(2),
	},
	{
		key = "busyCafe",
		name = "Busy Cafe",
		description = "Rank your cafe up to Tier 3.",
		earned = atTier(3),
	},
	{
		key = "famousCafe",
		name = "Famous Cafe",
		description = "Rank your cafe up to Tier 4.",
		earned = atTier(4),
	},
	{
		key = "grandCafe",
		name = "Grand Cafe",
		description = "Rank your cafe up to Tier 5.",
		earned = atTier(5),
	},
	{
		key = "sunstoneCafe",
		name = "Sunstone Cafe",
		description = "Rank your cafe up to Tier 6.",
		earned = atTier(6),
	},
	{
		key = "wonderCafe",
		name = "Wonder Cafe",
		description = "Rank your cafe up to Tier 7.",
		earned = atTier(7),
	},
	-- #5160: the last three tiers, made free (5 a day) once Model-Agent's icons are in
	{
		key = "summitCafe",
		name = "Summit Cafe",
		description = "Rank your cafe up to Tier 8.",
		earned = atTier(8),
	},
	{
		key = "funfairCafe",
		name = "Funfair Cafe",
		description = "Rank your cafe up to Tier 9.",
		earned = atTier(9),
	},
	{
		key = "royalCafe",
		name = "Royal Cafe",
		description = "Rank your cafe up to Tier 10.",
		earned = atTier(10),
	},
	-- Catching
	{
		key = "purrfect",
		name = "Purrfect!",
		description = "Make a PURRFECT catch.",
		earned = function(profile)
			return profile.stats.purrfectCatches >= 1
		end,
	},
	{
		key = "purrfectStreak",
		name = "Purrfect Streak",
		description = "Make 5 PURRFECT catches in a row.",
		earned = function(profile)
			return profile.stats.bestPurrfectStreak >= Badges.PURRFECT_RUN
		end,
	},
	{
		key = "baitCat",
		name = "Bait Cat",
		description = "Tame your first cat from the Bait bowl.",
		earned = function(profile)
			return profile.stats.baitsTamed >= 1
		end,
	},
	{
		key = "rareFind",
		name = "Rare Find",
		description = "Find an Epic cat.",
		earned = owns("Epic"),
	},
	{
		key = "legendaryFind",
		name = "Legendary Find",
		description = "Find a Legendary cat.",
		earned = owns("Legendary"),
	},
	{
		key = "mythicalFind",
		name = "Mythical Find",
		description = "Find a Mythical cat.",
		earned = owns("Mythical"),
	},
	{
		key = "secretFind", -- #5160
		name = "Secret Find",
		description = "Find a Secret cat.",
		earned = owns("Secret"),
	},
	-- Collecting
	{
		key = "catCollector",
		name = "Cat Collector",
		description = "Find 25 different cats.",
		earned = function(profile)
			return Economy.distinctCats(profile) >= Badges.COLLECTOR_CATS
		end,
	},
	{
		key = "catExpert",
		name = "Cat Expert",
		description = "Find 50 different cats.",
		earned = function(profile)
			return Economy.distinctCats(profile) >= Badges.EXPERT_CATS
		end,
	},
	{
		key = "catMaster", -- #5160
		name = "Cat Master",
		description = "Find 100 different cats.",
		earned = function(profile)
			return Economy.distinctCats(profile) >= Badges.MASTER_CATS
		end,
	},
	{
		key = "goldenCoat",
		name = "Golden Coat",
		description = "Find a gold cat.",
		earned = function(profile)
			return anyCoat(profile.goldCollection)
		end,
	},
	{
		key = "rainbowCoat",
		name = "Rainbow Coat",
		description = "Find a rainbow cat.",
		earned = function(profile)
			return anyCoat(profile.rainbowCollection)
		end,
	},
	{
		key = "pageComplete",
		name = "Page Complete",
		description = "Fill a whole area page in the Cat Index.",
		earned = pageComplete,
	},
	-- With other players
	{
		key = "helpingPaw",
		name = "Helping Paw",
		description = "Help another player rescue a stuck cat.",
		earned = function(profile)
			return profile.stats.teamRescuesHelped >= 1
		end,
	},
	{
		key = "firstTrade",
		name = "First Trade",
		description = "Finish your first trade with another player.",
		earned = function(profile)
			return profile.stats.trades >= 1
		end,
	},
	-- #2486's "Cafe Party Guest" (catch a cat during a Cafe Event) was here; #4282 (Derek 2026-11-14: "remove this
	-- badge ... its not really needed") took it out, and it is disabled on Roblox
	-- #3324 (Derek2 11-11): being in a server while the owner is there. Nothing in the profile earns it: the server
	-- passes it in `due`'s `extra` while the owner is in the server (BadgeAwardService), so it can't be earned alone.
	{
		key = "metOwner",
		name = "Met the Owner",
		description = "Be in a server while the game's owner is playing.",
		earned = function(_profile)
			return false
		end,
	},
}
for _, badge in LIST do
	table.freeze(badge)
end
table.freeze(LIST)
Badges.LIST = LIST

local byKey: { [string]: Badge } = {}
for _, badge in LIST do
	byKey[badge.key] = badge
end

function Badges.get(key: string): Badge?
	return byKey[key]
end

-- The Roblox badge id Config.Badges holds for `key`, or 0 (not made yet, or not a whole positive number).
function Badges.id(key: string): number
	local id = Config.Badges[key]
	return if type(id) == "number" and id > 0 and id % 1 == 0 then id else 0
end

-- Every badge the profile has earned, in LIST order.
function Badges.earned(profile: Profile): { string }
	local keys: { string } = {}
	for _, badge in LIST do
		if badge.earned(profile) then
			table.insert(keys, badge.key)
		end
	end
	return keys
end

-- #4775: whether `key` may award now: from Tier 3 every badge, before it only the EARLY two.
function Badges.allowed(profile: Profile, key: string): boolean
	local tier = Economy.tier(profile)
	if tier < Badges.TUTORIAL_TIER then
		return false
	end
	return Badges.EARLY[key] == true or tier >= Badges.QUIET_BELOW_TIER
end

-- The badges to award now: earned, made (id not 0), not in `owned` (badge id -> true, this join's cache), not
-- waiting on a retry (`waitUntil[key]` later than `now`) and allowed at the profile's tier (#4775). `extra` (#3324): keys earned by something outside the
-- profile right now (Met the Owner while the owner is here), added after the profile's, in LIST order.
function Badges.due(
	profile: Profile,
	owned: { [number]: boolean },
	waitUntil: { [string]: number },
	now: number,
	extra: { [string]: boolean }?
): { string }
	local earned = Badges.earned(profile)
	if extra ~= nil then
		for _, badge in LIST do
			if extra[badge.key] == true and not table.find(earned, badge.key) then
				table.insert(earned, badge.key)
			end
		end
	end
	local keys: { string } = {}
	for _, key in earned do
		local id = Badges.id(key)
		local wait = waitUntil[key]
		if
			id ~= 0
			and owned[id] ~= true
			and (wait == nil or wait <= now)
			and Badges.allowed(profile, key)
		then
			table.insert(keys, key)
		end
	end
	return keys
end

-- A net catch's end (CatService): a PURRFECT one counts and extends the run of PURRFECTs in a row (keeping the best);
-- any other end (a plain catch or a cat that got away) starts the run again. Only the run resets: the best stays.
function Badges.noteFinish(stats: Types.Stats, purrfect: boolean)
	if purrfect then
		stats.purrfectCatches += 1
		stats.purrfectStreak += 1
		stats.bestPurrfectStreak = math.max(stats.bestPurrfectStreak, stats.purrfectStreak)
	else
		stats.purrfectStreak = 0
	end
end

return Badges
