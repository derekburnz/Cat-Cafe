--!strict
-- Index rewards (F48, F54; data-model section 11b, golden-fish.md sections 4, 5 and 5b). Every page of the Index
-- has milestones counted from the profile: an area page's normal track from its cats in the collection and its gold
-- track from its gold cats, the All Cats page (area id "all") from different cats across every area, and a Decor
-- Index page (area id "decor_<pool>") from that crate's pieces owned. A claimed milestone's permanent bonus counts
-- from the claim on: tips (`bonus`), gold luck (`goldLuck`, capped at GoldLuckMax) or faster bait (`baitSpeed`,
-- capped at BaitSpeedMax). Shared so the Index's reward bar and the server's ClaimIndexReward check agree. Pure.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Crates = require(script.Parent.Crates)
local Potions = require(script.Parent.Potions)
local Types = require(script.Parent.Types)

local IndexRewards = {}

IndexRewards.ALL = "all" -- the All Cats page
IndexRewards.DECOR_PREFIX = "decor_" -- a Decor Index page: "decor_" .. the crate pool

export type Totals = { bonus: number, goldLuck: number, baitSpeed: number }

local milestonesById: { [string]: Types.IndexMilestone } = {}
for _, milestone in Catalog.indexMilestones do
	milestonesById[milestone.id] = milestone
end

function IndexRewards.milestone(id: string): Types.IndexMilestone?
	return milestonesById[id]
end

function IndexRewards.prize(areaId: string, milestoneId: string): Types.IndexPrize?
	local area = Catalog.indexPrizes[areaId]
	return if area ~= nil then area[milestoneId] else nil
end

-- Different cats of the area in `collection` (a collection or a gold collection: catId -> first caught at), or of
-- every area when `areaId` is "all".
function IndexRewards.progress(collection: { [string]: number }, areaId: string): number
	local n = 0
	for catId in collection do
		local def = Catalog.getCat(catId)
		if def ~= nil and (areaId == IndexRewards.ALL or def.area == areaId) then
			n += 1
		end
	end
	return n
end

-- What the milestone on this page counts toward `needs` for the player.
function IndexRewards.count(
	profile: Types.PlayerProfile,
	areaId: string,
	milestone: Types.IndexMilestone
): number
	if milestone.track == "decor" then
		local pool = string.sub(areaId, #IndexRewards.DECOR_PREFIX + 1)
		return Crates.pageCount(profile, pool)
	end
	local collection = if milestone.track == "gold"
		then profile.goldCollection
		else profile.collection
	return IndexRewards.progress(collection, areaId)
end

function IndexRewards.claimed(
	profile: Types.PlayerProfile,
	areaId: string,
	milestoneId: string
): boolean
	local area = profile.indexRewards[areaId]
	return area ~= nil and area[milestoneId] == true
end

-- Why the milestone cannot be claimed now, or nil when it can.
function IndexRewards.blocker(
	profile: Types.PlayerProfile,
	areaId: string,
	milestoneId: string
): string?
	local milestone = milestonesById[milestoneId]
	if milestone == nil or IndexRewards.prize(areaId, milestoneId) == nil then
		return "Unknown reward"
	end
	if IndexRewards.claimed(profile, areaId, milestoneId) then
		return "Already claimed"
	end
	local left = milestone.needs - IndexRewards.count(profile, areaId, milestone)
	if left <= 0 then
		return nil
	end
	if milestone.track == "decor" then
		return string.format("Find %d more piece%s first", left, if left == 1 then "" else "s")
	end
	return string.format(
		"Find %d more%s cat%s first",
		left,
		if milestone.track == "gold" then " gold" else "",
		if left == 1 then "" else "s"
	)
end

-- Six decimals, so sums like 0.02 + 0.06 + 0.1 + 0.2 are 0.38 and not 0.38000000000000006 (review N184).
local function round6(x: number): number
	return math.floor(x * 1e6 + 0.5) / 1e6
end

-- The permanent bonuses of every claimed milestone: tips, and gold luck and bait speed up to their caps, rounded
-- to six decimals so the server and the UI floor the same bait wait. A claim from before F54 counts too, since
-- the bonus belongs to the milestone.
function IndexRewards.totals(profile: Types.PlayerProfile): Totals
	local totals: Totals = { bonus = 0, goldLuck = 0, baitSpeed = 0 }
	for areaId, claims in profile.indexRewards do
		for milestoneId, claimed in claims do
			local prize = if claimed then IndexRewards.prize(areaId, milestoneId) else nil
			if prize ~= nil then
				totals.bonus += prize.bonus or 0
				totals.goldLuck += prize.goldLuck or 0
				totals.baitSpeed += prize.baitSpeed or 0
			end
		end
	end
	totals.bonus = round6(totals.bonus)
	totals.goldLuck = math.min(round6(totals.goldLuck), Config.GoldLuckMax)
	totals.baitSpeed = math.min(round6(totals.baitSpeed), Config.BaitSpeedMax)
	return totals
end

-- A gold roll's chance with the Index's gold luck: chance x (1 + goldLuck), the luck at most GoldLuckMax. The Index
-- shows this (the UI's copy matches it).
function IndexRewards.goldChance(chance: number, goldLuck: number): number
	return chance * (1 + math.clamp(goldLuck, 0, Config.GoldLuckMax))
end

-- The chance a gold roll uses now (F73): as goldChance, with `goldLuck` the Index's plus a running Gold Rush Potion's
-- (luckiest with `now`, or Potions.goldLuck), which goes on top of GoldLuckMax.
function IndexRewards.rollChance(chance: number, goldLuck: number): number
	return chance * (1 + math.clamp(goldLuck, 0, Config.GoldLuckMax + Potions.MAX_GOLD_LUCK))
end

-- The gold luck a shared roll in an area uses (a net stray or a rescue trap): the highest among the players whose
-- tier has the area open, 0 when nobody has (golden-fish.md section 5), and the index in `profiles` of the first
-- player with it (nil at 0), for the Index Board's "Gold luck +40% from Sam". With `now`, a running Gold Rush
-- Potion's luck counts too (F73: one player's potion lifts the shared rolls for everyone).
function IndexRewards.luckiest(
	profiles: { Types.PlayerProfile },
	areaTier: number,
	tierOf: (Types.PlayerProfile) -> number,
	now: number?
): (number, number?)
	local best, from = 0, nil
	for index, profile in profiles do
		if tierOf(profile) >= areaTier then
			local luck = IndexRewards.totals(profile).goldLuck
				+ (if now ~= nil then Potions.goldLuck(profile, now) else 0)
			if luck > best then
				best, from = luck, index
			end
		end
	end
	return best, from
end

function IndexRewards.bestGoldLuck(
	profiles: { Types.PlayerProfile },
	areaTier: number,
	tierOf: (Types.PlayerProfile) -> number
): number
	return (IndexRewards.luckiest(profiles, areaTier, tierOf))
end

return IndexRewards
