--!strict
-- Pure catch math (data-model sections 8 to 10). Callers pass random rolls in so tests are deterministic.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Catching = {}

function Catching.ringBonus(result: Types.RingResult): number
	if result == "perfect" then
		return Config.RingBonusPerfect
	elseif result == "good" then
		return Config.RingBonusGood
	end
	return 0
end

-- Turns "seconds since the hold completed" into a ring result. Negative means released early.
function Catching.ringResultFromTiming(secondsAfterHold: number?): Types.RingResult
	if secondsAfterHold == nil or secondsAfterHold < 0 then
		return "miss"
	elseif secondsAfterHold <= Config.RingPerfectWindow then
		return "perfect"
	elseif secondsAfterHold <= Config.RingGoodWindow then
		return "good"
	end
	return "miss"
end

-- chance = clamp(base + gloves x 0.10 + lureBonus + ringBonus, 0.05, 0.95)
function Catching.chance(
	rarity: Types.Rarity,
	glovesLevel: number,
	lured: boolean,
	ring: Types.RingResult
): number
	local base = Catalog.rarities[rarity].baseCatchChance
	local chance = base
		+ glovesLevel * Config.GlovesBonus
		+ (if lured then Config.LureBonus else 0)
		+ Catching.ringBonus(ring)
	return math.clamp(chance, Config.CatchChanceMin, Config.CatchChanceMax)
end

-- roll is in [0, 1).
function Catching.succeeds(chance: number, roll: number): boolean
	return roll < chance
end

function Catching.fleesOnMiss(rarity: Types.Rarity): boolean
	return Catalog.rarities[rarity].fleesOnMiss
end

-- Picks a rarity from an odds table (percentages). roll is in [0, 1).
function Catching.pickRarity(odds: Types.LureOdds, roll: number): Types.Rarity
	local target = math.clamp(roll, 0, 0.999999) * 100
	local acc = 0
	for _, rarity in Catalog.rarityOrder do
		local weight = (odds :: any)[rarity]
		if type(weight) == "number" then
			acc += weight
			if target < acc then
				return rarity
			end
		end
	end
	return "Common"
end

-- Cats of a rarity that can spawn in an area, in catalog order.
function Catching.candidates(rarity: Types.Rarity, area: string): { Types.CatDef }
	local out: { Types.CatDef } = {}
	for _, def in Catalog.cats do
		if def.rarity == rarity and (def.area == "both" or def.area == area) then
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
