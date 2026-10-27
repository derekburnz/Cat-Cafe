--!strict
-- Book rewards (F48, data-model section 11b): each area page of the Book has four milestones counted from the
-- collection (distinct catIds of that area) or, for gold10, the gold collection. Shared so the Book's reward bar
-- and the server's ClaimBookReward check agree. Pure.

local Catalog = require(script.Parent.Catalog)
local Types = require(script.Parent.Types)

local BookRewards = {}

local milestonesById: { [string]: Types.BookMilestone } = {}
for _, milestone in Catalog.bookMilestones do
	milestonesById[milestone.id] = milestone
end

function BookRewards.milestone(id: string): Types.BookMilestone?
	return milestonesById[id]
end

function BookRewards.prize(areaId: string, milestoneId: string): Types.BookPrize?
	local area = Catalog.bookRewards[areaId]
	return if area ~= nil then area[milestoneId] else nil
end

-- Different cats of the area in `collection` (a collection or a gold collection: catId -> first caught at).
function BookRewards.progress(collection: { [string]: number }, areaId: string): number
	local n = 0
	for catId in collection do
		local def = Catalog.getCat(catId)
		if def ~= nil and def.area == areaId then
			n += 1
		end
	end
	return n
end

function BookRewards.claimed(
	profile: Types.PlayerProfile,
	areaId: string,
	milestoneId: string
): boolean
	local area = profile.bookRewards[areaId]
	return area ~= nil and area[milestoneId] == true
end

-- Why the milestone cannot be claimed now, or nil when it can.
function BookRewards.blocker(
	profile: Types.PlayerProfile,
	areaId: string,
	milestoneId: string
): string?
	local milestone = milestonesById[milestoneId]
	if milestone == nil or BookRewards.prize(areaId, milestoneId) == nil then
		return "Unknown reward"
	end
	if BookRewards.claimed(profile, areaId, milestoneId) then
		return "Already claimed"
	end
	local collection = if milestone.gold then profile.goldCollection else profile.collection
	local left = milestone.need - BookRewards.progress(collection, areaId)
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

return BookRewards
