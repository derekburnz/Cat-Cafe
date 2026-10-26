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

-- Scores the ring from how long after GrabBegin the GrabEnd arrived, on the server's own clock (data-model
-- section 10). The last RingGoodWindow of the hold is good and the last RingPerfectWindow is perfect, both
-- running RingLatencyGraceSeconds past the end of the hold. Earlier or later is a miss, and a miss still rolls
-- the base chance. nil: sooner than GrabMinHoldSeconds, the server drops the GrabEnd and the lock continues.
function Catching.ringResultFromHold(secondsSinceGrabBegin: number): Types.RingResult?
	if secondsSinceGrabBegin < Config.GrabMinHoldSeconds then
		return nil
	end
	local hold = Config.GrabHoldSeconds
	if secondsSinceGrabBegin > hold + Config.RingLatencyGraceSeconds then
		return "miss"
	elseif secondsSinceGrabBegin >= hold - Config.RingPerfectWindow then
		return "perfect"
	elseif secondsSinceGrabBegin >= hold - Config.RingGoodWindow then
		return "good"
	end
	return "miss"
end

-- chance = clamp(base + net x 0.10 + lureBonus + ringBonus, 0.05, 0.95)
function Catching.chance(
	rarity: Types.Rarity,
	netLevel: number,
	lured: boolean,
	ring: Types.RingResult
): number
	local base = Catalog.rarities[rarity].baseCatchChance
	local chance = base
		+ netLevel * Config.NetBonus
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

-- Rescue odds (data-model section 10): the area's odds with the Rare weight doubled, scaled back to 100.
-- The alley's 75 / 20 / 4.5 / 0.5 becomes 62.5 / 33.3 / 3.75 / 0.42.
function Catching.rescueOdds(odds: Types.LureOdds): Types.LureOdds
	local weighted =
		{ Common = odds.Common, Rare = odds.Rare * 2, Epic = odds.Epic, Legendary = odds.Legendary }
	local total = weighted.Common + weighted.Rare + weighted.Epic + weighted.Legendary
	if total <= 0 then
		return { Common = 100, Rare = 0, Epic = 0, Legendary = 0 }
	end
	local scale = 100 / total
	return {
		Common = weighted.Common * scale,
		Rare = weighted.Rare * scale,
		Epic = weighted.Epic * scale,
		Legendary = weighted.Legendary * scale,
	}
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
