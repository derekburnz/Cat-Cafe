--!strict
-- Per-cat stats (data-model section 4b): charm rolled once when the cat is caught, level and XP earned while
-- placed, and the rating they combine into. Pure: random rolls are passed in, so tests are deterministic.
--
--   rating = rarity rate x charmMultiplier(charm) x levelMultiplier(level) x variantMultiplier(variant)
--
-- The rating is the one number "how good is this cat" that income, equip best and the cat room sort all use.
-- Everything numeric comes from Config so QA can tune without touching logic. Missing fields (a profile saved
-- before version 2, or a test fixture) fall back to the defaults, so every reader here is nil-safe.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local CatStats = {}

CatStats.MIN_CHARM = 0
CatStats.MAX_CHARM = 100
CatStats.DEFAULT_CHARM = 50 -- exactly a 1.0x multiplier
CatStats.MIN_LEVEL = 1

-- Readers -------------------------------------------------------------------------------------------------

function CatStats.level(instance: Types.CatInstance): number
	local level = (instance :: any).level
	if type(level) ~= "number" or level ~= level then
		return CatStats.MIN_LEVEL
	end
	return math.clamp(math.floor(level), CatStats.MIN_LEVEL, Config.CatMaxLevel)
end

function CatStats.xp(instance: Types.CatInstance): number
	local xp = (instance :: any).xp
	if type(xp) ~= "number" or xp ~= xp or xp < 0 then
		return 0
	end
	return math.floor(xp)
end

function CatStats.charm(instance: Types.CatInstance): number
	local charm = (instance :: any).charm
	if type(charm) ~= "number" or charm ~= charm then
		return CatStats.DEFAULT_CHARM
	end
	return math.clamp(math.floor(charm), CatStats.MIN_CHARM, CatStats.MAX_CHARM)
end

-- Rolls --------------------------------------------------------------------------------------------------

-- Charm 0 to 100 from two uniform rolls in [0, 1). The average of two rolls is triangular, so most cats sit
-- near 50 and only about 8% are 5-star (80+) or 1-star (below 20). Callers pass rng:NextNumber() twice.
function CatStats.rollCharm(roll1: number, roll2: number): number
	local a = math.clamp(roll1, 0, 1)
	local b = math.clamp(roll2, 0, 1)
	return math.clamp(
		math.floor((a + b) / 2 * (CatStats.MAX_CHARM + 1)),
		CatStats.MIN_CHARM,
		CatStats.MAX_CHARM
	)
end

-- Multipliers --------------------------------------------------------------------------------------------

-- 0 -> 1 - CharmSpread, 50 -> 1.0, 100 -> 1 + CharmSpread (0.8x to 1.2x with the default spread).
function CatStats.charmMultiplier(charm: number): number
	local centered = (
		math.clamp(charm, CatStats.MIN_CHARM, CatStats.MAX_CHARM) - CatStats.DEFAULT_CHARM
	) / (CatStats.MAX_CHARM - CatStats.DEFAULT_CHARM)
	return 1 + centered * Config.CharmSpread
end

-- Level 1 -> 1.0, each level above adds CatLevelBonus.
function CatStats.levelMultiplier(level: number): number
	local clamped = math.clamp(math.floor(level), CatStats.MIN_LEVEL, Config.CatMaxLevel)
	return 1 + Config.CatLevelBonus * (clamped - CatStats.MIN_LEVEL)
end

-- Post-slice variants (data-model section 4). "base" and anything unknown is 1x.
function CatStats.variantMultiplier(variant: string?): number
	if variant == "golden" then
		return 2
	elseif variant == "galaxy" then
		return 5
	end
	return 1
end

-- Stars 1 to 5 for the UI: charm 0-19 one star, 20-39 two, 40-59 three, 60-79 four, 80-100 five.
function CatStats.stars(charm: number): number
	local band = (CatStats.MAX_CHARM - CatStats.MIN_CHARM) / 5
	return math.clamp(
		math.floor(
			(math.clamp(charm, CatStats.MIN_CHARM, CatStats.MAX_CHARM) - CatStats.MIN_CHARM) / band
		) + 1,
		1,
		5
	)
end

function CatStats.starsText(stars: number): string
	local filled = math.clamp(math.floor(stars), 0, 5)
	return string.rep("★", filled) .. string.rep("☆", 5 - filled)
end

-- XP and levels -------------------------------------------------------------------------------------------

-- XP needed to go from `level` to the next one; 0 at the cap. One XP is one second placed on a spot.
function CatStats.xpToNext(level: number): number
	if level >= Config.CatMaxLevel then
		return 0
	end
	return Config.CatXpBase * math.max(CatStats.MIN_LEVEL, math.floor(level))
end

-- Total placed seconds needed to reach `level` from level 1 (for balance checks and the collection UI).
function CatStats.xpForLevel(level: number): number
	local total = 0
	for step = CatStats.MIN_LEVEL, math.min(level, Config.CatMaxLevel) - 1 do
		total += CatStats.xpToNext(step)
	end
	return total
end

-- Adds XP, levelling up as many times as it covers. Returns the number of levels gained.
-- Initialises missing fields so a version 1 cat becomes a valid version 2 cat on first touch.
function CatStats.addXp(instance: Types.CatInstance, amount: number): number
	local level = CatStats.level(instance)
	local xp = CatStats.xp(instance)
	if type(amount) == "number" and amount == amount and amount > 0 then
		xp += math.floor(amount)
	end
	local gained = 0
	while level < Config.CatMaxLevel do
		local needed = CatStats.xpToNext(level)
		if xp < needed then
			break
		end
		xp -= needed
		level += 1
		gained += 1
	end
	if level >= Config.CatMaxLevel then
		level = Config.CatMaxLevel
		xp = 0
	end
	instance.level = level
	instance.xp = xp
	instance.charm = CatStats.charm(instance)
	return gained
end

-- Rating ---------------------------------------------------------------------------------------------------

-- Coins per second this cat earns on a neutral spot before the cafe multiplier. 0 for an unknown cat id.
function CatStats.rating(instance: Types.CatInstance): number
	local def = Catalog.getCat(instance.catId)
	if def == nil then
		return 0
	end
	return def.incomePerSecond
		* CatStats.charmMultiplier(CatStats.charm(instance))
		* CatStats.levelMultiplier(CatStats.level(instance))
		* CatStats.variantMultiplier(instance.variant)
end

-- The best rating a cat of this id can reach at max level with 100 charm (collection book "potential").
function CatStats.maxRating(catId: string): number
	local def = Catalog.getCat(catId)
	if def == nil then
		return 0
	end
	return def.incomePerSecond
		* CatStats.charmMultiplier(CatStats.MAX_CHARM)
		* CatStats.levelMultiplier(Config.CatMaxLevel)
end

-- Sort order for the cat room and equip best: rating, then rarity, then name, then uid (stable).
function CatStats.isBetter(a: Types.CatInstance, b: Types.CatInstance): boolean
	local ra, rb = CatStats.rating(a), CatStats.rating(b)
	if ra ~= rb then
		return ra > rb
	end
	local defA, defB = Catalog.getCat(a.catId), Catalog.getCat(b.catId)
	local rankA = if defA ~= nil then Catalog.rarityRank[defA.rarity] else 0
	local rankB = if defB ~= nil then Catalog.rarityRank[defB.rarity] else 0
	if rankA ~= rankB then
		return rankA > rankB
	end
	if a.catId ~= b.catId then
		return a.catId < b.catId
	end
	return a.uid < b.uid
end

-- Construction ----------------------------------------------------------------------------------------------

-- A fresh level 1 instance. `charm` nil means the neutral default (the starter Tabby); callers that catch a
-- stray pass CatStats.rollCharm(...).
function CatStats.newInstance(
	uid: string,
	catId: string,
	now: number,
	charm: number?
): Types.CatInstance
	return {
		uid = uid,
		catId = catId,
		variant = "base",
		caughtAt = now,
		spotId = nil,
		level = CatStats.MIN_LEVEL,
		xp = 0,
		charm = if charm ~= nil
			then math.clamp(math.floor(charm), CatStats.MIN_CHARM, CatStats.MAX_CHARM)
			else CatStats.DEFAULT_CHARM,
	}
end

-- What ProfileSync sends per cat: the saved fields plus the derived numbers the UI shows.
function CatStats.view(instance: Types.CatInstance): Types.CatView
	local level = CatStats.level(instance)
	local charm = CatStats.charm(instance)
	return {
		uid = instance.uid,
		catId = instance.catId,
		variant = instance.variant,
		caughtAt = instance.caughtAt,
		spotId = instance.spotId,
		level = level,
		xp = CatStats.xp(instance),
		xpToNext = CatStats.xpToNext(level),
		charm = charm,
		stars = CatStats.stars(charm),
		rating = CatStats.rating(instance),
	}
end

-- "Lv 3 · ★★★★☆" for toasts.
function CatStats.shortText(instance: Types.CatInstance): string
	return string.format(
		"Lv %d · %s",
		CatStats.level(instance),
		CatStats.starsText(CatStats.stars(CatStats.charm(instance)))
	)
end

return CatStats
