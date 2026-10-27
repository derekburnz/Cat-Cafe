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

-- The permanent bonuses of every claimed milestone: tips, and gold luck and bait speed up to their caps. A claim
-- from before F54 counts too, since the bonus belongs to the milestone.
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
	totals.goldLuck = math.min(totals.goldLuck, Config.GoldLuckMax)
	totals.baitSpeed = math.min(totals.baitSpeed, Config.BaitSpeedMax)
	return totals
end

-- A gold roll's chance with gold luck: chance x (1 + goldLuck).
function IndexRewards.goldChance(chance: number, goldLuck: number): number
	return chance * (1 + math.clamp(goldLuck, 0, Config.GoldLuckMax))
end

-- The gold luck a shared roll in an area uses (a net stray or a rescue trap): the highest among the players whose
-- tier has the area open, 0 when nobody has (golden-fish.md section 5).
function IndexRewards.bestGoldLuck(
	profiles: { Types.PlayerProfile },
	areaTier: number,
	tierOf: (Types.PlayerProfile) -> number
): number
	local best = 0
	for _, profile in profiles do
		if tierOf(profile) >= areaTier then
			best = math.max(best, IndexRewards.totals(profile).goldLuck)
		end
	end
	return best
end

return IndexRewards
