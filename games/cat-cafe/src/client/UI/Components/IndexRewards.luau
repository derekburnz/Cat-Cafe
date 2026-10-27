--!strict
-- Index rewards (F48, data-model section 11b): each area page of the Index pays out at 3, 6 and 10 of its cats
-- and at all of them as gold cats. The server counts from `collection` and `goldCollection`, which the client
-- already has, so this works out which milestones are claimed, ready or still to go, for the reward strip, the
-- red badges on the area tabs and the Index. Pure: no Theme, so the cloud spec runner can load it.
--
-- Catalog.indexMilestones lists the milestones (the same on every page) and Catalog.indexPrizes[areaId][id] the
-- prize; an area or milestone without a prize has no card. state.indexRewards[areaId][id] is true once claimed.

local CatVariant = require(script.Parent.CatVariant)
local Types = require(script.Parent.Parent.Types)

export type Milestone = Types.IndexMilestone
export type Prize = Types.IndexPrize
type Catalog = Types.Catalog
type State = Types.PlayerState

export type MilestoneState = "claimed" | "ready" | "locked"

export type View = {
	milestone: Milestone,
	prize: Prize,
	state: MilestoneState,
	have: number, -- toward `need`, never above it
}

export type LureEntry = { id: string, count: number }

export type Counts = {
	total: number, -- the area's cats in the catalog
	found: number, -- of those, in collection
	gold: number, -- of those, in goldCollection
}

local FALLBACK_AREA = "alley" -- a cat without an area is an Alleyway cat, as in the Index

local IndexRewards = {}

function IndexRewards.counts(catalog: Catalog, state: State, areaId: string): Counts
	local collection: { [string]: number } = state.collection or {}
	local gold = CatVariant.collection(state)
	local counts: Counts = { total = 0, found = 0, gold = 0 }
	for _, def in catalog.cats do
		if (def.area or FALLBACK_AREA) ~= areaId then
			continue
		end
		counts.total += 1
		if collection[def.id] ~= nil then
			counts.found += 1
		end
		if gold[def.id] ~= nil then
			counts.gold += 1
		end
	end
	return counts
end

function IndexRewards.isClaimed(state: State, areaId: string, milestoneId: string): boolean
	local claimed = state.indexRewards and state.indexRewards[areaId]
	return claimed ~= nil and claimed[milestoneId] == true
end

-- The area's milestones in catalog order, each with its prize and state. Empty when the catalog has no
-- milestones or no prizes for this area, so the strip hides until the engineer sends them.
function IndexRewards.views(catalog: Catalog, state: State, areaId: string): { View }
	local views: { View } = {}
	local milestones: { Milestone } = catalog.indexMilestones or {}
	local prizes = catalog.indexPrizes and catalog.indexPrizes[areaId]
	if prizes == nil then
		return views
	end
	local counts = IndexRewards.counts(catalog, state, areaId)
	for _, milestone in milestones do
		local prize: Prize? = prizes[milestone.id]
		if prize == nil then
			continue
		end
		local count = if milestone.gold then counts.gold else counts.found
		local claimed = IndexRewards.isClaimed(state, areaId, milestone.id)
		local milestoneState: MilestoneState = if claimed
			then "claimed"
			elseif count >= milestone.need then "ready"
			else "locked"
		table.insert(views, {
			milestone = milestone,
			prize = prize,
			state = milestoneState,
			have = math.min(count, milestone.need),
		})
	end
	return views
end

-- Milestones ready to claim, per area and in all, for the badges.
function IndexRewards.claimable(catalog: Catalog, state: State): ({ [string]: number }, number)
	local perArea: { [string]: number } = {}
	local total = 0
	local rewards: { [string]: { [string]: Prize } } = catalog.indexPrizes or {}
	for areaId in rewards do
		local ready = 0
		for _, view in IndexRewards.views(catalog, state, areaId) do
			if view.state == "ready" then
				ready += 1
			end
		end
		if ready > 0 then
			perArea[areaId] = ready
			total += ready
		end
	end
	return perArea, total
end

-- "3 cats", "All 10", "All 10 gold"; "5 gold" for a gold milestone short of the whole page.
function IndexRewards.needLabel(milestone: Milestone, total: number): string
	local all = total > 0 and milestone.need >= total
	if milestone.gold then
		return if all
			then ("All %d gold"):format(milestone.need)
			else ("%d gold"):format(milestone.need)
	end
	return if all then ("All %d"):format(milestone.need) else ("%d cats"):format(milestone.need)
end

-- Index decor (data-model section 7) is never sold: only ClaimIndexReward grants it, so the Decor shop shows it as
-- an Index reward and it never lights the shop's dot. `source` is read loosely until SharedTypes.DecorDef has it.
function IndexRewards.isIndexDecor(def: Types.DecorDef): boolean
	return (def :: any).source == "index"
end

-- A gold Index piece names the normal piece it stands in for (`replaces`, N114). While the gold piece is owned and
-- placed the server takes the normal one off the plot and out of the bonus, so its card says so (N117).
-- Returns normal piece id -> gold piece id. `replaces` is read loosely until SharedTypes.DecorDef has it.
function IndexRewards.replacedBy(catalog: Catalog, state: State): { [string]: string }
	local replaced: { [string]: string } = {}
	for _, def in catalog.decor do
		local normalId: string? = (def :: any).replaces
		if normalId and state.decorOwned[def.id] == true and state.decorPlaced[def.id] == true then
			replaced[normalId] = def.id
		end
	end
	return replaced
end

-- The area and milestone whose prize is this Index decor, or nil when no prize names it.
function IndexRewards.decorSource(catalog: Catalog, decorId: string): (string?, Milestone?)
	local rewards: { [string]: { [string]: Prize } } = catalog.indexPrizes or {}
	local milestones: { Milestone } = catalog.indexMilestones or {}
	for areaId, prizes in rewards do
		for _, milestone in milestones do
			local prize: Prize? = prizes[milestone.id]
			if prize and prize.decorId == decorId then
				return areaId, milestone
			end
		end
	end
	return nil, nil
end

-- What unlocks an Index decor piece, for its Decor shop card: "All 10 Alleyway cats", "All 10 Alleyway cats as gold".
function IndexRewards.unlockLabel(milestone: Milestone, areaName: string, total: number): string
	local count = if total > 0 and milestone.need >= total
		then ("All %d"):format(milestone.need)
		else tostring(milestone.need)
	return ("%s %s cats%s"):format(count, areaName, if milestone.gold then " as gold" else "")
end

-- A prize's foods in a steady order (the map has none), for the card's text.
function IndexRewards.lureList(prize: Prize): { LureEntry }
	local list: { LureEntry } = {}
	local lures: { [string]: number } = prize.lures or {}
	for id, count in lures do
		table.insert(list, { id = id, count = count })
	end
	table.sort(list, function(a: LureEntry, b: LureEntry): boolean
		return a.id < b.id
	end)
	return list
end

return IndexRewards
