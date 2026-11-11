--!strict
-- #3022 (Derek2 2026-11-10: "somehow make it obvious to go catch second cat to earn more money and progress 'your
-- goal' so people don't get lost and go get second cat. A lot of people stop before catching second cat"; baseline
-- onboarding_v6, Nov 8 to 9: 52 served a first customer, 41 caught a second cat). From the first customer served
-- until the second cat is checked in, once on the account:
--   the goal card reads "Catch a 2nd cat" with what it really brings (`view`): the cafe's coins a second now and
--     with one more cat, and the bonus a new kind of cat pays. A new save's starter Tabby and first catch fill both
--     Tier 1 jobs, so for most players the two rates are equal and the bonus is the true money in it,
--   a stray waits near the Alleyway camp's landing: the free stray nearest it within SEARCH_STUDS turns Curious and
--     keeps within LEASH_STUDS of the landing, or a Common arrives at a `near` point when none is that close, and its
--     catch is the first catch's one slow circle (server/Services/CatService; the model's WaitsFor attribute names
--     the player, so the client's pointer and the trail find it),
--   three step_time events say how far the player got (STEPS).
-- It ends by itself at the second check-in and reads only what the save already holds, so it needs no save field.
-- #3160: the two cats are cats caught by hand (`caught`): a cat tamed at the bait bowl does not end it.
-- Pure.

local CatStats = require(script.Parent.CatStats)
local Catalog = require(script.Parent.Catalog)
local Economy = require(script.Parent.Economy)
local EquipBest = require(script.Parent.EquipBest)
local Onboarding = require(script.Parent.Onboarding)
local Types = require(script.Parent.Types)

local SecondCat = {}

SecondCat.CATS = 2 -- cats caught by hand and checked in (SecondCat.caught) that end it
SecondCat.AREA = "alley" -- where the stray waits
SecondCat.ATTRIBUTE = "WaitsFor" -- on the stray's model: the user id of the player it waits for, 0 for none
SecondCat.MAX_RARITY = "Rare" -- the rarest stray that may wait: the easy catch is never a Legendary near the pad
SecondCat.SEARCH_STUDS = 60 -- a free stray this near the camp landing is the one that waits
SecondCat.LEASH_STUDS = 30 -- and it keeps this near the landing
SecondCat.FOLLOWED_STUDS = 25 -- the player came this near the waiting stray: second_cat_trail_followed
SecondCat.TRAIL_DELAY_SECONDS = 2 -- the client's trail starts this long after the customer is served
SecondCat.TRAIL_SECONDS = 120 -- and goes after this long
SecondCat.PREVIEW_SECONDS = 6 -- the earnings line under the goal
SecondCat.NUDGE_SECONDS = 45 -- one more bounce of the goal card when the player has not set off
-- The step_time names (Telemetry.custom "step_time", field 1), each once a session.
SecondCat.SHOWN = "second_cat_trail_shown"
SecondCat.FOLLOWED = "second_cat_trail_followed"
SecondCat.CAUGHT = "second_cat_caught"
SecondCat.STEPS = { SecondCat.SHOWN, SecondCat.FOLLOWED, SecondCat.CAUGHT }

local PREVIEW_UID = "__second_cat" -- the pretend cat's key in the copy `preview` reads; never saved

-- #3160 (Derek2 2026-11-10: "because the food bowl finished instantly it finishes the catch first cat tutorial step so
-- make that still need to happen after cannon"): the cats caught by hand, with the net or a rescue. A cat tamed at
-- the bait bowl counts in stats.catsCaught too, and since the first bowl cat comes in seconds (#2946) it ended this
-- goal before the player had gone out for a second cat. `stats` is a save's or a PlayerState's.
function SecondCat.caught(stats: Types.Stats): number
	-- (read as unknown: a PlayerState from an older server has no baitsTamed)
	local caught: unknown, tamed: unknown = stats.catsCaught, stats.baitsTamed
	if type(caught) ~= "number" then
		return 0
	end
	return math.max(0, caught - (if type(tamed) == "number" then tamed else 0))
end

-- Whether the save is between its first customer served and its second cat checked in.
function SecondCat.waiting(profile: Types.PlayerProfile): boolean
	return SecondCat.caught(profile.stats) < SecondCat.CATS
		and Onboarding.reached(profile.telemetry, "first_customer_served")
end

-- The Common of the waiting area that earns the least, so the preview never promises more than a second cat brings.
local function plainCat(tier: number): Types.CatDef?
	local bestId: string? = nil
	local bestRate = math.huge
	for _, def: Types.CatDef in Catalog.cats :: { Types.CatDef } do
		if def.area == SecondCat.AREA and def.rarity == "Common" and def.exclusive ~= true then
			local rate = CatStats.rating({
				uid = PREVIEW_UID,
				catId = def.id,
				variant = "base",
				caughtAt = 0,
				level = CatStats.MIN_LEVEL,
				xp = 0,
				charm = CatStats.DEFAULT_CHARM,
			}, tier)
			if rate < bestRate then
				bestId, bestRate = def.id, rate
			end
		end
	end
	return if bestId ~= nil then Catalog.catsById[bestId] else nil
end

-- The cafe's coins a second now, and with one more plain Common (level 1, middle charm) working an open role slot
-- that is not its favorite: the same Economy.incomePerSecond both times, so every multiplier the save has counts.
-- The two are equal when no slot is free.
function SecondCat.preview(profile: Types.PlayerProfile): (number, number)
	local now = Economy.incomePerSecond(profile)
	local tier = Economy.tier(profile)
	local def = plainCat(tier)
	if def == nil then
		return now, now
	end
	local used: { [string]: boolean } = {}
	for _, instance in profile.cats do
		if instance.spotId ~= nil then
			used[instance.spotId :: string] = true
		end
	end
	local free: Types.SpotDef? = nil
	for _, spot in EquipBest.openSpots(profile) do
		if not used[spot.id] then
			-- a slot of another role first, so the favorite role's bonus is never promised
			if spot.spotType ~= def.favoriteRole then
				free = spot
				break
			end
			free = free or spot
		end
	end
	if free == nil then
		return now, now
	end
	local copy = table.clone(profile)
	copy.cats = table.clone(profile.cats)
	copy.cats[PREVIEW_UID] = {
		uid = PREVIEW_UID,
		catId = def.id,
		variant = "base",
		caughtAt = 0,
		spotId = free.id,
		level = CatStats.MIN_LEVEL,
		xp = 0,
		charm = CatStats.DEFAULT_CHARM,
	}
	return now, math.max(now, Economy.incomePerSecond(copy))
end

-- What ProfileSync carries while the save waits for its second cat (PlayerState.secondCat), else nil.
function SecondCat.view(profile: Types.PlayerProfile): Types.SecondCatView?
	if not SecondCat.waiting(profile) then
		return nil
	end
	local now, with = SecondCat.preview(profile)
	return {
		now = now,
		with = with,
		cats = SecondCat.caught(profile.stats), -- #3160: by hand; a tamed bowl cat is not one
		bonus = Catalog.rarities.Common.firstCatchReward,
	}
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Whether a stray of `rarity` in coat `variant` may be the one that waits (Review-Agent on #3038): a plain coat, and
-- MAX_RARITY or below, so the waiting stray's easy catch never hands a new save a Legendary, Mythical, gold or
-- rainbow cat that happened to stand near the landing.
function SecondCat.fits(rarity: string, variant: string): boolean
	local rank, top = Catalog.rarityRank[rarity], Catalog.rarityRank[SecondCat.MAX_RARITY]
	return rank ~= nil and top ~= nil and rank <= top and variant == "base"
end

-- Whether a stray at `at` is near enough the landing at `pad` to be the one that waits.
function SecondCat.inSearch(at: Vector3, pad: Vector3): boolean
	return flat(at - pad).Magnitude <= SecondCat.SEARCH_STUDS
end

-- The home of a waiting stray whose home was `home`: pulled toward the landing at `pad` until a wander of
-- `wanderRadius` studs from it stays within LEASH_STUDS (same height). A home already that near is kept.
function SecondCat.leash(home: Vector3, pad: Vector3, wanderRadius: number): Vector3
	local reach = math.max(0, SecondCat.LEASH_STUDS - math.max(0, wanderRadius) * math.sqrt(2))
	local offset = flat(home - pad)
	local distance = offset.Magnitude
	if distance <= reach or distance < 1e-3 then
		return home
	end
	local kept = offset.Unit * reach
	return Vector3.new(pad.X + kept.X, home.Y, pad.Z + kept.Z)
end

-- Whether a player at `player` has come to the waiting stray at `stray` (second_cat_trail_followed).
function SecondCat.followed(player: Vector3, stray: Vector3): boolean
	return flat(player - stray).Magnitude <= SecondCat.FOLLOWED_STUDS
end

return SecondCat
