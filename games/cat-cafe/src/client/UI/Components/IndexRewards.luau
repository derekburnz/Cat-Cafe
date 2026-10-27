--!strict
-- Index rewards (F48, data-model section 11b): each area page of the Index pays out at 3, 6 and 10 of its cats
-- and at all of them as gold cats. The server counts from `collection` and `goldCollection`, which the client
-- already has, so this works out which milestones are claimed, ready or still to go, for the reward strip, the
-- red badges on the area tabs and the Index. Pure: no Theme, so the cloud spec runner can load it.
--
-- Catalog.indexMilestones lists the milestones (the same on every page) and Catalog.indexPrizes[areaId][id] the
-- prize; an area or milestone without a prize has no card. state.indexRewards[areaId][id] is true once claimed.
--
-- F54 (golden-fish.md sections 5 and 8) gives each area a normal track (cats3, cats6, cats10) and a gold track
-- (gold1 to gold10), milestone rows { id, track, needs }, and an "All Cats" page (area id "all", total5 to
-- total50) that counts different cats across every area. Both row shapes are read here, so the UI works before
-- and after the engineer's catalog change.
--
-- F53 (golden-fish.md section 4) adds the Decor Index: area ids "decor_alley" to "decor_classic" with decor5 and
-- decor10, counted from the owned pieces of that crate (Components/DecorPieces).

local CatVariant = require(script.Parent.CatVariant)
local DecorPieces = require(script.Parent.DecorPieces)
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

-- One thing a prize pays, for the little pictures with amounts (Derek 2026-10-27: "showing little symbols of
-- whatever they are going to get as next reward and how much"). `id` is the lure, crate or decor id, or the prize
-- field's name for a kind the UI does not know yet.
-- `bonus` is a fraction (0.02 for "+2% tips forever") and `tag` carries the tag's name in `id`.
export type PartKind =
	"coins"
	| "fish"
	| "lure"
	| "spins"
	| "crate"
	| "tag"
	| "decor"
	| "bonus"
	| "potion"
	| "other"
export type PrizePart = { kind: PartKind, id: string?, amount: number }
export type Track = "normal" | "gold"

export type Counts = {
	total: number, -- the area's cats in the catalog
	found: number, -- of those, in collection
	gold: number, -- of those, in goldCollection
}

local FALLBACK_AREA = "alley" -- a cat without an area is an Alleyway cat, as in the Index
-- prize fields prizeParts reads by name; any other number field shows as an "other" part
local KNOWN_FIELDS = {
	coins = true,
	coinSeconds = true,
	lures = true,
	fish = true,
	spins = true,
	crates = true,
	bonus = true,
	tag = true,
	decorId = true,
	potions = true,
}

local IndexRewards = {}

IndexRewards.ALL_AREA = "all" -- the All Cats page: every area's cats together (F54)

-- How many cats a milestone needs: `needs` (F54) or `need` (F48).
function IndexRewards.need(milestone: Milestone): number
	return milestone.needs or milestone.need or 0
end

-- Whether a milestone counts gold cats: `track = "gold"` (F54) or `gold = true` (F48).
function IndexRewards.isGold(milestone: Milestone): boolean
	return milestone.track == "gold" or milestone.gold == true
end

function IndexRewards.track(milestone: Milestone): Track
	return if IndexRewards.isGold(milestone) then "gold" else "normal"
end

-- The area's cats in the catalog and how many are found and gold. The "all" page counts every area's cats, and a
-- Decor Index page its crate's pieces and how many the player owns.
function IndexRewards.counts(catalog: Catalog, state: State, areaId: string): Counts
	local pool = DecorPieces.poolOf(areaId)
	if pool then
		local owned, total = DecorPieces.pageCounts(catalog, state, pool)
		return { total = total, found = owned, gold = 0 }
	end
	local collection: { [string]: number } = state.collection or {}
	local gold = CatVariant.collection(state)
	local counts: Counts = { total = 0, found = 0, gold = 0 }
	local all = areaId == IndexRewards.ALL_AREA
	for _, def in catalog.cats do
		if not all and (def.area or FALLBACK_AREA) ~= areaId then
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
		local need = IndexRewards.need(milestone)
		local count = if IndexRewards.isGold(milestone) then counts.gold else counts.found
		local claimed = IndexRewards.isClaimed(state, areaId, milestone.id)
		local milestoneState: MilestoneState = if claimed
			then "claimed"
			elseif count >= need then "ready"
			else "locked"
		table.insert(views, {
			milestone = milestone,
			prize = prize,
			state = milestoneState,
			have = math.min(count, need),
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
-- "1 cat" for a milestone of one (the gold track starts at "1 gold"). On a Decor Index page "5 pieces".
function IndexRewards.needLabel(milestone: Milestone, total: number, areaId: string?): string
	local need = IndexRewards.need(milestone)
	local all = total > 0 and need >= total
	if areaId and DecorPieces.poolOf(areaId) then
		return if all then ("All %d"):format(need) else ("%d pieces"):format(need)
	end
	if IndexRewards.isGold(milestone) then
		return if all then ("All %d gold"):format(need) else ("%d gold"):format(need)
	end
	return if all
		then ("All %d"):format(need)
		elseif need == 1 then "1 cat"
		else ("%d cats"):format(need)
end

-- The milestone to show as the next reward: the first one ready to claim, else the first still to reach, in
-- catalog order (the normal track before the gold one). With `track`, only that track's milestones. Nil once
-- every milestone is claimed (or there are none).
function IndexRewards.nextView(views: { View }, track: Track?): View?
	for _, view in views do
		if
			view.state == "ready" and (track == nil or IndexRewards.track(view.milestone) == track)
		then
			return view
		end
	end
	for _, view in views do
		if
			view.state == "locked" and (track == nil or IndexRewards.track(view.milestone) == track)
		then
			return view
		end
	end
	return nil
end

-- How many more cats (or gold cats) the milestone needs.
function IndexRewards.toGo(view: View): number
	return math.max(0, IndexRewards.need(view.milestone) - view.have)
end

-- The coins a prize pays at this day rate: max(coins, floor(dayRate * coinSeconds)), the Tip Jar's rule, so the
-- card shows what a claim would pay now. Without coinSeconds it is just `coins`.
function IndexRewards.coins(prize: Prize, dayRate: number?): number
	local least = prize.coins or 0
	local seconds = prize.coinSeconds
	if seconds == nil or dayRate == nil then
		return least
	end
	return math.max(least, math.floor(math.max(0, dayRate) * seconds))
end

-- What a prize pays, one part per thing, in a steady order: coins (at `dayRate` when the prize grows with the
-- cafe), golden fish, foods (by id), spins, crates (by id), potions (by id), the name tag, the decor piece, the
-- tips-forever bonus, then any number field the UI does not know yet (Derek 2026-10-27: Index rewards give crates
-- and wheel spins rather than decor outright; golden-fish.md section 5 adds fish, bonuses and a tag).
function IndexRewards.prizeParts(prize: Prize, dayRate: number?): { PrizePart }
	local parts: { PrizePart } = {}
	local coins = IndexRewards.coins(prize, dayRate)
	if coins > 0 then
		table.insert(parts, { kind = "coins" :: PartKind, amount = coins })
	end
	local fish = prize.fish
	if fish and fish > 0 then
		table.insert(parts, { kind = "fish" :: PartKind, amount = fish })
	end
	for _, entry in IndexRewards.lureList(prize) do
		if entry.count > 0 then
			table.insert(parts, { kind = "lure" :: PartKind, id = entry.id, amount = entry.count })
		end
	end
	local spins = prize.spins
	if spins and spins > 0 then
		table.insert(parts, { kind = "spins" :: PartKind, amount = spins })
	end
	local crates: { [string]: number } = prize.crates or {}
	local crateParts: { PrizePart } = {}
	for id, count in crates do
		if count > 0 then
			table.insert(crateParts, { kind = "crate" :: PartKind, id = id, amount = count })
		end
	end
	table.sort(crateParts, function(a: PrizePart, b: PrizePart): boolean
		return (a.id or "") < (b.id or "")
	end)
	for _, part in crateParts do
		table.insert(parts, part)
	end
	-- v0.10 potions (the Tip Jar's step 12, codes and the Daily Treat), by id
	local potions: { [string]: number } = prize.potions or {}
	local potionParts: { PrizePart } = {}
	for id, count in potions do
		if count > 0 then
			table.insert(potionParts, { kind = "potion" :: PartKind, id = id, amount = count })
		end
	end
	table.sort(potionParts, function(a: PrizePart, b: PrizePart): boolean
		return (a.id or "") < (b.id or "")
	end)
	for _, part in potionParts do
		table.insert(parts, part)
	end
	local tag = prize.tag
	if tag and tag ~= "" then
		table.insert(parts, { kind = "tag" :: PartKind, id = tag, amount = 1 })
	end
	local decorId: string? = prize.decorId
	if decorId then
		table.insert(parts, { kind = "decor" :: PartKind, id = decorId, amount = 1 })
	end
	local bonus = prize.bonus
	if bonus and bonus > 0 then
		table.insert(parts, { kind = "bonus" :: PartKind, amount = bonus })
	end
	local loose = prize :: any
	local others: { PrizePart } = {}
	for key, value in loose :: { [any]: any } do
		if
			type(key) == "string"
			and KNOWN_FIELDS[key] == nil
			and type(value) == "number"
			and value > 0
		then
			table.insert(others, { kind = "other" :: PartKind, id = key, amount = value })
		end
	end
	table.sort(others, function(a: PrizePart, b: PrizePart): boolean
		return (a.id or "") < (b.id or "")
	end)
	for _, part in others do
		table.insert(parts, part)
	end
	return parts
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
	local need = IndexRewards.need(milestone)
	local count = if total > 0 and need >= total then ("All %d"):format(need) else tostring(need)
	return ("%s %s cats%s"):format(
		count,
		areaName,
		if IndexRewards.isGold(milestone) then " as gold" else ""
	)
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
