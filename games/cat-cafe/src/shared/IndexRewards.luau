--!strict
-- Index rewards (F48, data-model section 11b): each area page of the Index has four milestones counted from the
-- collection (distinct catIds of that area) or, for gold10, the gold collection. Shared so the Index's reward bar
-- and the server's ClaimIndexReward check agree. Pure.

local Catalog = require(script.Parent.Catalog)
local Types = require(script.Parent.Types)

local IndexRewards = {}

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

-- Different cats of the area in `collection` (a collection or a gold collection: catId -> first caught at).
function IndexRewards.progress(collection: { [string]: number }, areaId: string): number
	local n = 0
	for catId in collection do
		local def = Catalog.getCat(catId)
		if def ~= nil and def.area == areaId then
			n += 1
		end
	end
	return n
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
	local collection = if milestone.gold then profile.goldCollection else profile.collection
	local left = milestone.need - IndexRewards.progress(collection, areaId)
	if left > 0 then
		return string.format(
			"Find %d more%s cat%s first",
			left,
			if milestone.gold then " gold" else "",
			if left == 1 then "" else "s"
		)
	end
	return nil
end

return IndexRewards
