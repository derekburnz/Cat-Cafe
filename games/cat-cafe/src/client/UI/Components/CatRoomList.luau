--!strict
-- Which cats the cat room's inventory grid shows, and in what order (UI plan 2026-10-27, the Pet Simulator
-- inventory Derek sent).
--   counts(cats)                          -> { all, working, resting }
--   matches(instance, def, query)         -> true when the query is empty or found, as plain text and ignoring
--                                            case, in the player's name for the cat, its breed or its rarity
--   list(cats, defs, rank, filter, query) -> the cats to show: filter "All", "Working" or "Resting", then the
--                                            query. Working cats first (Pet Simulator lists equipped pets
--                                            first), then rarer, then the higher rating, then breed and uid so
--                                            the grid never reshuffles between syncs.
-- Pure, no Theme, so the cloud spec runner can load it; the caller passes the rarity rank.

local Types = require(script.Parent.Parent.Types)

local CatRoomList = {}

export type Filter = "All" | "Working" | "Resting"

export type Counts = {
	all: number,
	working: number,
	resting: number,
}

function CatRoomList.counts(cats: { [string]: Types.CatInstance }): Counts
	local counts: Counts = { all = 0, working = 0, resting = 0 }
	for _, instance in cats do
		counts.all += 1
		if instance.spotId ~= nil then
			counts.working += 1
		else
			counts.resting += 1
		end
	end
	return counts
end

function CatRoomList.matches(
	instance: Types.CatInstance,
	def: Types.CatDef?,
	query: string
): boolean
	local needle = string.lower(query:match("^%s*(.-)%s*$") or "")
	if needle == "" then
		return true
	end
	local haystacks: { string } = { instance.catId }
	if instance.name then
		table.insert(haystacks, instance.name)
	end
	if def then
		table.insert(haystacks, def.name)
		table.insert(haystacks, def.rarity)
	end
	for _, haystack in haystacks do
		if string.find(string.lower(haystack), needle, 1, true) then
			return true
		end
	end
	return false
end

function CatRoomList.list(
	cats: { [string]: Types.CatInstance },
	defs: { [string]: Types.CatDef },
	rank: (rarity: string) -> number,
	filter: Filter,
	query: string
): { Types.CatInstance }
	local shown: { Types.CatInstance } = {}
	for _, instance in cats do
		local working = instance.spotId ~= nil
		if filter == "Working" and not working then
			continue
		end
		if filter == "Resting" and working then
			continue
		end
		if CatRoomList.matches(instance, defs[instance.catId], query) then
			table.insert(shown, instance)
		end
	end

	local function ratingOf(instance: Types.CatInstance): number
		local rating = instance.rating
		if rating ~= nil then
			return rating
		end
		local def = defs[instance.catId]
		return if def then def.incomePerSecond else 0
	end
	local function rarityOf(instance: Types.CatInstance): number
		local def = defs[instance.catId]
		return if def then rank(def.rarity) else 0
	end
	table.sort(shown, function(a: Types.CatInstance, b: Types.CatInstance): boolean
		local workingA, workingB = a.spotId ~= nil, b.spotId ~= nil
		if workingA ~= workingB then
			return workingA
		end
		local rarityA, rarityB = rarityOf(a), rarityOf(b)
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		local ratingA, ratingB = ratingOf(a), ratingOf(b)
		if ratingA ~= ratingB then
			return ratingA > ratingB
		end
		if a.catId ~= b.catId then
			return a.catId < b.catId
		end
		return a.uid < b.uid
	end)
	return shown
end

return CatRoomList
