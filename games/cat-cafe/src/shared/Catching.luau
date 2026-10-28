--!strict
-- Pure catch math (data-model sections 8 to 10): odds, picking a cat, the chase after a miss. The circles are in
-- Circles. Callers pass random rolls in so tests are deterministic.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Catching = {}

-- Where a carried cat rides, relative to the carrier's HumanoidRootPart: the asset manifest's
-- poses.carried.body_cframe_roblox, cradled across the chest and facing the carrier's left so the camera behind the
-- player sees it side on. 12 numbers for CFrame.new(table.unpack(...)), so this module stays free of Roblox types;
-- the server's carry (CatService) and the intro's demo carry (IntroController, F72) both use it.
Catching.CARRIED_POSE = { 0, -0.4, -1.05, 0, 0, 1, 0, 1, 0, -1, 0, 0 }

-- roll is in [0, 1).
function Catching.succeeds(chance: number, roll: number): boolean
	return roll < chance
end

-- Studs a stray of this rarity sprints away from the player who missed (v0.5, data-model section 10 step 5).
function Catching.fleeStuds(rarity: Types.Rarity): number
	return Catalog.rarities[rarity].fleeStuds
end

-- Server time from which anyone may try a stray again after a miss: the sprint at StrayFleeSpeed, then the
-- StrayRestSeconds breather, and never sooner than GrabRetrySeconds after the miss.
function Catching.fleeUntil(missedAt: number, sprintStuds: number): number
	local sprint = math.max(0, sprintStuds) / Config.StrayFleeSpeed
	return missedAt + math.max(Config.GrabRetrySeconds, sprint + Config.StrayRestSeconds)
end

-- F57 (data-model section 10 step 5, v0.8): a player's misses in a row on one stray, the last at server time `at`.
export type MissStreak = { count: number, at: number }

-- The streak after a miss at `now`: one more, or 1 again when StrayMissStreakResetSeconds have passed since the
-- last. A catch or a despawn ends the stray and its streaks with it.
function Catching.nextMiss(streak: MissStreak?, now: number): MissStreak
	if streak == nil or now - streak.at >= Config.StrayMissStreakResetSeconds then
		return { count = 1, at = now }
	end
	return { count = streak.count + 1, at = now }
end

-- How much longer than everyone else the player who missed waits once the stray stops: StraySelfRetrySteps by
-- misses in a row (3, 6, then 10 s for every miss after).
function Catching.selfRetrySeconds(misses: number): number
	local steps = Config.StraySelfRetrySteps
	return steps[math.clamp(misses, 1, #steps)]
end

local function oddsTotal(odds: Types.LureOdds): number
	local total = 0
	for _, rarity: Types.Rarity in Catalog.rarityOrder do
		local weight = (odds :: any)[rarity]
		if type(weight) == "number" and weight > 0 then
			total += weight
		end
	end
	return total
end

-- Picks a rarity from an odds table. Weights are scaled by their total, so percentages that sum to 100 read
-- exactly as written and a reweighted table (rescueOdds) works too. roll is in [0, 1).
function Catching.pickRarity(odds: Types.LureOdds, roll: number): Types.Rarity
	local total = oddsTotal(odds)
	if total <= 0 then
		return "Common"
	end
	local target = math.clamp(roll, 0, 0.999999) * total
	local acc = 0
	for _, rarity: Types.Rarity in Catalog.rarityOrder do
		local weight = (odds :: any)[rarity]
		if type(weight) == "number" and weight > 0 then
			acc += weight
			if target < acc then
				return rarity
			end
		end
	end
	return "Common"
end

-- Rescue odds (data-model section 10b): the area's odds with every non-Common weight doubled, scaled back to
-- 100. The Alleyway's 72 / 22 / 5 / 0.9 / 0.1 becomes 56.25 / 34.375 / 7.8125 / 1.40625 / 0.15625.
function Catching.rescueOdds(odds: Types.LureOdds): Types.LureOdds
	local common = odds.Common
	local rare, epic = odds.Rare * 2, odds.Epic * 2
	local legendary, mythical = odds.Legendary * 2, odds.Mythical * 2
	local total = common + rare + epic + legendary + mythical
	if total <= 0 then
		return { Common = 100, Rare = 0, Epic = 0, Legendary = 0, Mythical = 0 }
	end
	local scale = 100 / total
	return {
		Common = common * scale,
		Rare = rare * scale,
		Epic = epic * scale,
		Legendary = legendary * scale,
		Mythical = mythical * scale,
	}
end

-- Cats of a rarity that can spawn in an area, in catalog order.
function Catching.candidates(rarity: Types.Rarity, area: string): { Types.CatDef }
	local out: { Types.CatDef } = {}
	for _, def in Catalog.cats do
		if def.rarity == rarity and def.area == area then
			table.insert(out, def)
		end
	end
	return out
end

-- Uniform pick among candidates; falls back down the rarity ladder if nothing fits the area.
function Catching.pickCat(rarity: Types.Rarity, area: string, roll: number): Types.CatDef
	local rank = Catalog.rarityRank[rarity]
	while rank >= 1 do
		local list = Catching.candidates(Catalog.rarityOrder[rank], area)
		if #list > 0 then
			local index = math.clamp(math.floor(roll * #list) + 1, 1, #list)
			return list[index]
		end
		rank -= 1
	end
	return Catalog.cats[1]
end

-- The bait bowl's pick (data-model section 8): uniform among the rarity's cats in every area `tier` opens, so the
-- pool grows with the tier, the same split the food cards show. Falls back down the rarity ladder like pickCat.
function Catching.pickBaitCat(rarity: Types.Rarity, tier: number, roll: number): Types.CatDef
	local rank = Catalog.rarityRank[rarity]
	while rank >= 1 do
		local list: { Types.CatDef } = {}
		for _, def in Catalog.cats do
			local area = Catalog.getArea(def.area)
			if def.rarity == Catalog.rarityOrder[rank] and area ~= nil and area.tier <= tier then
				table.insert(list, def)
			end
		end
		if #list > 0 then
			return list[math.clamp(math.floor(roll * #list) + 1, 1, #list)]
		end
		rank -= 1
	end
	return Catalog.cats[1]
end

function Catching.rarityAtLeast(rarity: Types.Rarity, minimum: string): boolean
	return (Catalog.rarityRank[rarity] or 0) >= (Catalog.rarityRank[minimum] or 99)
end

-- The server-wide shout-out for a new cat, or nil when it is not worth one: AnnounceMinRarity (Epic) and up, and
-- every gold (data-model section 15). "Sam caught a gold Rare Tabby!", "Sam rescued an Epic Maine Coon!";
-- `where` adds a place before the "!" (" at their bait bowl").
function Catching.shoutOut(
	playerName: string,
	verb: string,
	def: Types.CatDef,
	variant: string?,
	where: string?
): string?
	local gold = variant == "gold"
	if not gold and not Catching.rarityAtLeast(def.rarity, Config.AnnounceMinRarity) then
		return nil
	end
	local phrase = (if gold then "gold " else "") .. def.rarity .. " " .. def.name
	local article = if phrase:match("^[AEIOUaeiou]") then "an " else "a "
	return string.format("%s %s %s%s%s!", playerName, verb, article, phrase, where or "")
end

function Catching.percentText(chance: number): string
	return string.format("%d%%", math.floor(chance * 100 + 0.5))
end

local SPREAD_WEIGHT_CAP = 60 -- studs: past this every gap weighs the same, so an empty area picks evenly

-- Which of the free spawn `points` a new stray takes, as an index, given where the area's strays already stand
-- (`taken`): a point at least StraySpawnSpacingStuds from all of them, picked with weight growing with its flat gap
-- to the nearest (capped), or, when none is that far, the point with the biggest gap. Nil with no points. roll is in
-- [0, 1).
function Catching.spreadPick(points: { Vector3 }, taken: { Vector3 }, roll: number): number?
	if #points == 0 then
		return nil
	end
	local spacing = Config.StraySpawnSpacingStuds
	local gaps: { number } = {}
	local farthest, farthestGap = 1, -1
	local total = 0
	for i, point in points do
		local gap = math.huge
		for _, other in taken do
			gap = math.min(gap, Vector3.new(point.X - other.X, 0, point.Z - other.Z).Magnitude)
		end
		gaps[i] = gap
		if gap > farthestGap then
			farthest, farthestGap = i, gap
		end
		if gap >= spacing then
			total += math.min(gap, SPREAD_WEIGHT_CAP)
		end
	end
	if total <= 0 then
		return farthest
	end
	local left = math.clamp(roll, 0, 1) * total
	local last = farthest
	for i, gap in gaps do
		if gap >= spacing then
			last = i
			left -= math.min(gap, SPREAD_WEIGHT_CAP)
			if left < 0 then
				return i
			end
		end
	end
	return last -- roll 1: the last far-enough point
end

-- The zones Epic and rarer strays keep to: the Alleyway's "nook" points (town-layout-v3.md 7e: the exciting cats
-- wait at the back alleys' ends, so no cafe's lane is the lucky one) and a v3.2 side area's "deep" ones (section 8d:
-- the rarer the cat, the longer the walk to it).
local KEEP_ZONES: { [string]: boolean } = { nook = true, deep = true }

-- A "rare" spawn point is a rare-biased nook (the Great Oak's top in the Woods, Derek 2026-10-28 01:35): only a Rare
-- or rarer stray takes it, and one takes it first while it is free, so whoever climbs up finds a Rare or better.
Catching.RARE_ZONE = "rare"

export type SpawnSlot = { zone: string?, free: boolean }

-- The spawn points, as indexes into `slots`, that a new stray of `rarity` may take: a free "rare" point for a Rare
-- or rarer stray when there is one; else, for Epic and rarer in an area with "nook" or "deep" points, only the free
-- ones of those (none free: none, and the stray waits for the next wave; spawnWave places the rarest first, so this
-- is rare); else every free point but a "rare" one. A nil rarity (a carried cat sent home) is any but a "rare" one.
function Catching.spawnPool(slots: { SpawnSlot }, rarity: Types.Rarity?): { number }
	local rare: { number } = {}
	local kept: { number } = {}
	local open: { number } = {}
	local hasKept = false
	for i, slot in slots do
		local zone = slot.zone
		local keep = zone ~= nil and KEEP_ZONES[zone] == true
		hasKept = hasKept or keep
		if not slot.free then
			continue
		end
		if zone == Catching.RARE_ZONE then
			table.insert(rare, i)
		else
			table.insert(open, i)
			if keep then
				table.insert(kept, i)
			end
		end
	end
	if rarity ~= nil and Catching.rarityAtLeast(rarity, "Rare") and #rare > 0 then
		return rare
	end
	if rarity ~= nil and Catching.rarityAtLeast(rarity, "Epic") and hasKept then
		return kept
	end
	return open
end

return Catching
