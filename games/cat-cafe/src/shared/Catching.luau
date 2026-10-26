--!strict
-- Pure catch math (data-model sections 8 to 10): odds, picking a cat, fleeing. The circles themselves are in
-- Circles. Callers pass random rolls in so tests are deterministic.

local Catalog = require(script.Parent.Catalog)
local Types = require(script.Parent.Types)

local Catching = {}

-- roll is in [0, 1).
function Catching.succeeds(chance: number, roll: number): boolean
	return roll < chance
end

-- A failed catch makes anything rarer than Common run off (data-model section 2).
function Catching.fleesOnFail(rarity: Types.Rarity): boolean
	return Catalog.rarities[rarity].fleesOnFail
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

function Catching.rarityAtLeast(rarity: Types.Rarity, minimum: string): boolean
	return (Catalog.rarityRank[rarity] or 0) >= (Catalog.rarityRank[minimum] or 99)
end

function Catching.percentText(chance: number): string
	return string.format("%d%%", math.floor(chance * 100 + 0.5))
end

return Catching
