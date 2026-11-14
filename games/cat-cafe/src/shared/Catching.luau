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
-- since #1964 it is only where HeldCat puts a cat on a character that has no torso yet.
Catching.CARRIED_POSE = { 0, -0.4, -1.05, 0, 0, 1, 0, 1, 0, -1, 0, 0 }

-- #1964 (Derek2 2026-11-07: "re-work the entire thing and positions hes being carried"): a carried cat lies on the
-- carrier's folded arms, welded to the torso (R15 UpperTorso, R6 Torso) so it rides the walk and the arm fold the
-- same on every screen, with no copy on any client. Its bottom middle sits `up` of the torso's height above the
-- torso's middle, and its back `gap` studs in front of the chest; it lies `turn` degrees about the torso's up, across
-- the arms with its head to the carrier's left. CARRIED_POSE above is only the fallback for a character with no
-- torso yet. Tuned in Studio; numbers only, so this module stays free of Roblox types. Derek2 2026-11-07 04:30
-- ("bring cat closer to chest and lower"): the cat's back rests against the chest (`gap` 0) and its floor sits on
-- Animation-Engineer's lowered hands (#1985: on R15 meeting about 1 stud out, their tops 0.4 below the UpperTorso's
-- middle; R6 arms per #1991), so its middle is on the hands.
Catching.HELD = {
	-- Desktop-Tester after #2002: the R15 cat's head grazed the carrier's Head 0.03 deep, so it sits 0.05 out
	-- Derek2 2026-11-07 12:35 on the R15 sheet: "move it a little to the right so the body is centred across both
	-- arms hands" (right in the front view, the carrier's left, toward the cat's head): `side` studs along the
	-- torso's x, since the box's middle counts the head and the body sat toward the carrier's right
	r15 = { up = -0.3, gap = 0.05, side = -0.25 },
	-- Derek2 2026-11-07 11:49 (#2001): "they are floating ... okay if the bottom is a little bit inside", so the cat
	-- sits down into the arms against the chest instead of clear of them (up 0.25, gap 0.2 before)
	-- Laptop-Tester after #2002: the R6 cat still sat a stud above the folded arms with its head over the chin, so
	-- it comes down a stud (0.5 of a 2-stud Torso) onto the hands
	-- Derek2 13:12 on the sheet after #2021: R6 "bad" (cat low inside crossed arms). With Animation-Engineer's new R6
	-- cradle (arms forward and in at chest height) its floor sits on the arm tops, 0.3 over the Torso's middle,
	-- with its back 0.15 out so the head clears the chin
	r6 = { up = 0.15, gap = 0.15, side = 0 },
	turn = 90,
}

-- The held cat asleep, like a napping cafe cat (Derek2 2026-11-07: "make the carrying look like what a sleeping cat
-- from the cafe would but fit sideways and in a way that doesn't look weird in the arms"; the loaf before): Model-Agent's
-- manifest `cat_poses.sleep` turns for the walking body's hinged pieces, legs tucked, head down and tail curled round,
-- each as piece:PivotTo(piece:GetPivot() * CFrame.Angles(x, y, z)) in degrees, the same numbers as
-- Effects/Presets.catPoses.sleep except the head: lying across the arms, the sleep's head turn faced up into the
-- carrier's chin (pose sheet, #1984), so the held head only tucks its nose down, `x` negative, with no turn or tilt.
-- Its eyes are shut: each Eye piece squashed to HELD_EYES of its height, as Effects
-- blinks them (Presets.motion.blink.squash). Set once on the server, so no client poses the held cat.
Catching.HELD_EYES = 0.12
Catching.HELD_TURNS = {
	LegF1 = { -90, 0, -30 },
	LegF2 = { -90, 0, 30 },
	LegB1 = { 90, 0, -26 },
	LegB2 = { 90, 0, 26 },
	Head = { -40, 0, 0 },
	Tail = { 71.7, 49.6, -66.5 },
} :: { [string]: { number } }

--- Where the bottom middle of a held cat lies in its carrier's torso, in studs on Roblox's axes (x right, y up, z
--- back): `torso` is the torso's size {x, y, z} and `catWidth` the cat's width across its body. Lying across the
--- arms its width is how far it reaches out from the chest, so a big cat sits further out instead of in the chest.
function Catching.holdPoint(
	rig: string,
	torso: { number },
	catWidth: number
): (number, number, number)
	local hold = if rig == "R6" then Catching.HELD.r6 else Catching.HELD.r15
	return hold.side, torso[2] * hold.up, -(torso[3] / 2 + hold.gap + catWidth / 2)
end

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

-- Rescue odds (data-model section 10b): the area's odds with Rare and Epic doubled and Legendary and Mythical
-- times RESCUE_TOP_BOOST (#2240, Derek2 2026-11-07: "leg/mythic chance slightly" higher; was 2), scaled back to
-- 100. The Park's 54 / 29 / 11 / 4.8 / 1.2 becomes about 36.4 / 39.1 / 14.8 / 7.8 / 1.94.
Catching.RESCUE_BOOST = 2
Catching.RESCUE_TOP_BOOST = 2.4
function Catching.rescueOdds(odds: Types.LureOdds): Types.LureOdds
	local common = odds.Common
	local rare, epic = odds.Rare * Catching.RESCUE_BOOST, odds.Epic * Catching.RESCUE_BOOST
	local legendary, mythical =
		odds.Legendary * Catching.RESCUE_TOP_BOOST, odds.Mythical * Catching.RESCUE_TOP_BOOST
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

-- #3470: the Secret cat that takes the place of a rolled `rarity`, or nil. Only a Mythical turns, Catalog.
-- secretPerMythical of the time (`roll` in [0, 1)), and only while the `secretCats` switch is `on`; `pick` in [0, 1)
-- chooses evenly among Catalog.secretCats. So a source's Secret chance is its Mythical chance over 100, whatever Luck
-- did to the odds, and every other rarity keeps its chance.
Catching.SECRET_FLAG = "secretCats"
Catching.SECRET_NAME = "???" -- a wild Secret stray's name on its tag and catch header until it is caught
-- the ReplicatedStorage folder of live Secret strays' spots (the server's SecretBeacons; Effects reads it)
Catching.SECRET_BEACONS = "SecretBeacons"
function Catching.secret(
	rarity: Types.Rarity,
	roll: number,
	pick: number,
	on: boolean
): Types.CatDef?
	local list = Catalog.secretCats
	if not on or rarity ~= "Mythical" or #list == 0 or roll >= Catalog.secretPerMythical then
		return nil
	end
	return list[math.clamp(math.floor(pick * #list) + 1, 1, #list)]
end

function Catching.rarityAtLeast(rarity: Types.Rarity, minimum: string): boolean
	return (Catalog.rarityRank[rarity] or 0) >= (Catalog.rarityRank[minimum] or 99)
end

-- The server-wide shout-out for a new cat, or nil when it is not worth one: AnnounceMinRarity and up with a plain
-- coat, COAT_SHOUT_FROM and up with a gold or rainbow coat (data-model section 15, F99). "Sam caught a Mythical
-- Moonpaw!", "Sam rescued a gold Legendary Maine Coon!"; `where` adds a place before the "!" (" at their bait bowl").
-- Derek 2026-11-12 ("make rainbow/gold finds also changed to only legendary + and make normals only mythic+ it has a
-- bit of clutter right now"): a plain coat from Mythical (Legendary since #2205, Epic before), a gold or rainbow
-- coat from Legendary (#2902 had gold from Rare and every rainbow). The toast, this server's chat line, the line in
-- the other servers and the Rare Cats tab (shared/RareCatsTab) all follow this one rule.
Catching.COAT_SHOUT_FROM = "Legendary"
function Catching.shoutOut(
	playerName: string,
	verb: string,
	def: Types.CatDef,
	variant: string?,
	where: string?
): string?
	local coat = if variant == "gold" or variant == "rainbow" then variant .. " " else ""
	local worth = Catching.rarityAtLeast(def.rarity, Config.AnnounceMinRarity)
		or (
			(variant == "gold" or variant == "rainbow")
			and Catching.rarityAtLeast(def.rarity, Catching.COAT_SHOUT_FROM)
		)
	if not worth then
		return nil
	end
	if def.rarity == "Secret" then
		-- #3470: "Sam caught a SECRET cat: Nebula!", "Sam caught a gold SECRET cat: Nebula at their bait bowl!"
		return string.format(
			"%s %s a %sSECRET cat: %s%s!",
			playerName,
			verb,
			coat,
			def.name,
			where or ""
		)
	end
	local phrase = coat .. def.rarity .. " " .. def.name
	local article = if phrase:match("^[AEIOUaeiou]") then "an " else "a "
	return string.format("%s %s %s%s%s!", playerName, verb, article, phrase, where or "")
end

-- #3897 (Derek 2026-11-13: "instead of flooding players with banners ... only show the cat spawns banners for
-- area's they have unlocked"): whether a player at `tier` hears a rare cat's spawn banner in an area that opens at
-- `areaTier` (nil: an unknown area, which nobody hears). The wave's Mythical, the Secret cat, the pity cat and the
-- event shower all use it.
function Catching.hearsSpawn(tier: number?, areaTier: number?): boolean
	return tier ~= nil and areaTier ~= nil and tier >= areaTier
end

-- F58 (data-model section 9, v0.8): the server-wide line when a wave spawns a Mythical stray, naming the area and
-- not the cat, so finding it is still a surprise: "A Mythical cat appeared in the Woods!", "A gold Mythical cat..."
-- when it is gold (or "rainbow", F99), "... in the Woods on a Lucky Day!" on a Lucky Day's wave (F88). Nil for any
-- other rarity.
function Catching.waveShoutOut(
	rarity: Types.Rarity,
	variant: string?,
	areaName: string,
	luckyDay: boolean?
): string?
	if rarity == "Secret" then
		-- #3470: the area and never the spot or the cat: "A Secret cat is somewhere in the Park!"
		return string.format("A Secret cat is somewhere in the %s!", areaName)
	end
	if rarity ~= "Mythical" then
		return nil
	end
	return string.format(
		"A %sMythical cat appeared in the %s%s!",
		if variant == "gold" or variant == "rainbow" then variant .. " " else "",
		areaName,
		if luckyDay == true then " on a Lucky Day" else ""
	)
end

-- F99 (rainbow-coat.md section 1): a found cat's coat from one roll in [0, 1): "rainbow" below `rainbowChance`, else
-- "gold" below rainbowChance + goldChance, else "base". Rainbow is rolled first on the same roll, so the gold chance
-- stays exactly as it was. An exclusive cat (the Bellhop Cat, the shop cats) is always "base".
function Catching.rollCoat(
	def: Types.CatDef,
	roll: number,
	rainbowChance: number,
	goldChance: number
): string
	if def.exclusive == true then
		return "base"
	end
	if roll < rainbowChance then
		return "rainbow"
	end
	return if roll < rainbowChance + goldChance then "gold" else "base"
end

-- F99 (rainbow-coat.md section 2): the server's toast when a rainbow stray spawns, "A Rainbow Tabby is out in the
-- Woods!", naming the cat (its coat is visible from the spawn, unlike the Mythical wave line).
function Catching.rainbowSpawnText(def: Types.CatDef, areaName: string): string
	return string.format("A Rainbow %s is out in the %s!", def.name, areaName)
end

function Catching.percentText(chance: number): string
	return string.format("%d%%", math.floor(chance * 100 + 0.5))
end

-- F97 (notes-10-28-to-10-30.md section 7; Derek 2026-10-29: "getting epic+ cats feels a little non existent from
-- outside world"): a sunrise wave rolled as `rarities` with no Epic or rarer stray rerolls its last one from
-- WaveMinRareRerollOdds (Epic 83, Legendary 15, Mythical 2). Changes `rarities` in place and returns the rarity the
-- reroll gave, or nil when the wave already had one (or is empty). roll is in [0, 1).
function Catching.waveRare(rarities: { Types.Rarity }, roll: number): Types.Rarity?
	if #rarities == 0 then
		return nil
	end
	for _, rarity in rarities do
		if Catalog.rarityRank[rarity] >= Catalog.rarityRank.Epic then
			return nil
		end
	end
	local rerolled: Types.Rarity =
		Catching.pickRarity(Config.WaveMinRareRerollOdds :: Types.LureOdds, roll)
	rarities[#rarities] = rerolled
	return rerolled
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

-- The zones the rarest strays keep to, each with the rarest that it holds them to: the Alleyway's "nook" points, Epic
-- and up (town-layout-v3.md 7e: the exciting cats wait at the back alleys' ends, so no cafe's lane is the lucky one),
-- and a side area's "deep" ones, Mythical only (section 8d: the rarer the cat, the longer the walk to it). #2210
-- (crispi_255 via Derek2, 2026-11-07: the good cats "only spawn at the back"): "deep" held Epic and up as well, so
-- every Epic and Legendary in the Park, Sewer, Neighbourhood and Woods stood in the far half. They spawn anywhere in
-- the area now, spread from the others like any stray.
-- #3170 (Derek2: "all the cats in alleyway are piled into the back now spread them out through the entire area even
-- the decent ones"): the Alleyway's nooks no longer keep its Epic and up; they spawn anywhere there.
Catching.KEEP_ZONES = table.freeze({ deep = "Mythical" }) :: { [string]: string }

-- A "rare" spawn point is a rare-biased nook (the Great Oak's top in the Woods, Derek 2026-10-28 01:35): only a Rare
-- or rarer stray takes it, and one takes it first while it is free, so whoever climbs up finds a Rare or better.
Catching.RARE_ZONE = "rare"

export type SpawnSlot = { zone: string?, free: boolean }

-- The spawn points, as indexes into `slots`, that a new stray of `rarity` may take: a free "rare" point for a Rare
-- or rarer stray when there is one; else, in an area with points of a KEEP_ZONES zone that holds this rarity (a
-- "nook" Epic and up, a "deep" Mythical), only the free ones of those (none free: none, and the stray waits for the
-- next wave; spawnWave places the rarest first, so this is rare); else every free point but a "rare" one. A nil
-- rarity (a carried cat sent home) is any but a "rare" one.
function Catching.spawnPool(slots: { SpawnSlot }, rarity: Types.Rarity?): { number }
	local rare: { number } = {}
	local kept: { number } = {}
	local open: { number } = {}
	local hasKept = false
	for i, slot in slots do
		local zone = slot.zone
		local floor = if zone ~= nil then Catching.KEEP_ZONES[zone] else nil
		local keep = rarity ~= nil and floor ~= nil and Catching.rarityAtLeast(rarity, floor)
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
	if hasKept then
		return kept
	end
	return open
end

return Catching
