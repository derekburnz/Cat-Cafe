--!strict
-- Every food list in rarity order (F97 section 3, Derek 2026-10-28: "sort all food in food bowl by rarity"): the bowl,
-- the bag, the shop, the dealer and a prize's foods all run Kibble, Tuna, Moonlit Sardines, Salmon, Caviar, Moon
-- Milk, Star Treat. The catalog's `sortOrder` decides when a food has one (Gameplay-Engineer's F97 catalog field);
-- until then the food's grade (Components/FoodGrade), then its price, then the section's order for the id (a prize
-- names foods by id alone, with no price), then the id.
--   less(a, aId, b, bId) -> boolean   whether food a comes before food b; a def may be nil (a prize names an id the
--                                     catalog does not have), and the design's grade for the id stands in
--   sort(list, read)                  sorts any list in place; read(item) gives the item's id and def
--   defs(lures, rarestFirst?)         a sorted copy of a catalog's foods; rarestFirst turns it round, Star Treat
--                                     first (#1609: the bowl's list and the Bag's Bait tab)
-- Pure, so the cloud spec runner checks it.

local FoodGrade = require(script.Parent.FoodGrade)
local Types = require(script.Parent.Parent.Types)

local FoodOrder = {}

local GRADE_RANK: { [string]: number } =
	{ Common = 1, Rare = 2, Epic = 3, Legendary = 4, Mythical = 5 }
local LAST = math.huge
-- F97 section 3's list, for ids with the same grade and no price
local DESIGN: { [string]: number } = {
	kibble = 1,
	tuna = 2,
	sardines = 3,
	salmon = 4,
	caviar = 5,
	moon_milk = 6,
	star_treat = 7,
}

local function sortOrder(lure: Types.LureDef?): number
	local value = if lure then (lure :: any).sortOrder else nil
	return if type(value) == "number" and value == value then value else LAST
end

local function grade(lure: Types.LureDef?, id: string): number
	local name = if lure then FoodGrade.of(lure) else FoodGrade.DEFAULTS[id]
	return GRADE_RANK[name or ""] or LAST
end

local function cost(lure: Types.LureDef?): number
	local value = if lure then lure.cost else nil
	return if type(value) == "number" and value == value then value else LAST
end

function FoodOrder.less(a: Types.LureDef?, aId: string, b: Types.LureDef?, bId: string): boolean
	local aOrder, bOrder = sortOrder(a), sortOrder(b)
	if aOrder ~= bOrder then
		return aOrder < bOrder
	end
	local aGrade, bGrade = grade(a, aId), grade(b, bId)
	if aGrade ~= bGrade then
		return aGrade < bGrade
	end
	local aCost, bCost = cost(a), cost(b)
	if aCost ~= bCost then
		return aCost < bCost
	end
	local aDesign, bDesign = DESIGN[aId] or LAST, DESIGN[bId] or LAST
	if aDesign ~= bDesign then
		return aDesign < bDesign
	end
	return aId < bId
end

function FoodOrder.sort<T>(list: { T }, read: (item: T) -> (string, Types.LureDef?))
	table.sort(list, function(x: T, y: T): boolean
		local xId, xDef = read(x)
		local yId, yDef = read(y)
		return FoodOrder.less(xDef, xId, yDef, yId)
	end)
end

function FoodOrder.defs(lures: { Types.LureDef }, rarestFirst: boolean?): { Types.LureDef }
	local list = table.clone(lures)
	FoodOrder.sort(list, function(lure: Types.LureDef): (string, Types.LureDef?)
		return lure.id, lure
	end)
	if rarestFirst then
		local count = #list
		for index = 1, count // 2 do
			list[index], list[count - index + 1] = list[count - index + 1], list[index]
		end
	end
	return list
end

return FoodOrder
