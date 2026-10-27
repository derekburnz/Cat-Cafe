--!strict
-- Pure catch math (data-model sections 8 to 10): odds, picking a cat, the chase after a miss. The circles are in
-- Circles. Callers pass random rolls in so tests are deterministic.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Catching = {}

-- roll is in [0, 1).
function Catching.succeeds(chance: number, roll: number): boolean
	return roll < chance
end

-- Studs a stray of this rarity sprints away from the player who missed (v0.5, data-model section 10 step 5).
function Catching.fleeStuds(rarity: Types.Rarity): number
	return Catalog.rarities[rarity].fleeStuds
end

-- Server time from which anyone may try a stray again after a miss: the sprint at StrayFleeSpeed, then the
-- StrayRestSeconds breather, and never sooner than GrabRetrySeconds after the miss.
function Catching.fleeUntil(missedAt: number, sprintStuds: number): number
	local sprint = math.max(0, sprintStuds) / Config.StrayFleeSpeed
	return missedAt + math.max(Config.GrabRetrySeconds, sprint + Config.StrayRestSeconds)
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

-- The bait bowl's pick (data-model section 8): uniform among the rarity's cats in every area `tier` opens, so the
-- pool grows with the tier, the same split the food cards show. Falls back down the rarity ladder like pickCat.
function Catching.pickBaitCat(rarity: Types.Rarity, tier: number, roll: number): Types.CatDef
	local rank = Catalog.rarityRank[rarity]
	while rank >= 1 do
		local list: { Types.CatDef } = {}
		for _, def in Catalog.cats do
			local area = Catalog.getArea(def.area)
			if def.rarity == Catalog.rarityOrder[rank] and area ~= nil and area.tier <= tier then
				table.insert(list, def)
			end
		end
		if #list > 0 then
			return list[math.clamp(math.floor(roll * #list) + 1, 1, #list)]
		end
		rank -= 1
	end
	return Catalog.cats[1]
end

function Catching.rarityAtLeast(rarity: Types.Rarity, minimum: string): boolean
	return (Catalog.rarityRank[rarity] or 0) >= (Catalog.rarityRank[minimum] or 99)
end

-- The server-wide shout-out for a new cat, or nil when it is not worth one: AnnounceMinRarity (Epic) and up, and
-- every shiny (data-model section 15). "Sam caught a shiny Rare Tabby!", "Sam rescued an Epic Maine Coon!";
-- `where` adds a place before the "!" (" at their bait bowl").
function Catching.shoutOut(
	playerName: string,
	verb: string,
	def: Types.CatDef,
	variant: string?,
	where: string?
): string?
	local shiny = variant == "shiny"
	if not shiny and not Catching.rarityAtLeast(def.rarity, Config.AnnounceMinRarity) then
		return nil
	end
	local phrase = (if shiny then "shiny " else "") .. def.rarity .. " " .. def.name
	local article = if phrase:match("^[AEIOUaeiou]") then "an " else "a "
	return string.format("%s %s %s%s%s!", playerName, verb, article, phrase, where or "")
end

function Catching.percentText(chance: number): string
	return string.format("%d%%", math.floor(chance * 100 + 0.5))
end

return Catching
