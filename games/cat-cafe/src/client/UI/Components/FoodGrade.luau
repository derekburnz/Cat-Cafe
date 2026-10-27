--!strict
-- How good a food is (F69, data-model section 8, round 4 Q11: "make the food for bait noticable rarities so people
-- know whats good"): a grade in the cat rarity names, shown as a badge and border wherever a food appears. It is not
-- the rarity the food attracts; the odds line and the "Attracts" chip keep saying that. `LureDef.rarity` is read
-- loosely until the engineer's catalog field lands; until then the design's grades below stand in, and a food
-- neither knows falls back to what it attracts.
-- Pure: no Theme, so the cloud spec runner can load it.

local Types = require(script.Parent.Parent.Types)

local FoodGrade = {}

-- data-model section 8, v0.10
FoodGrade.DEFAULTS = {
	kibble = "Common",
	tuna = "Rare",
	sardines = "Rare",
	salmon = "Epic",
	caviar = "Epic",
	moon_milk = "Legendary",
	star_treat = "Mythical",
} :: { [string]: string }

local KNOWN: { [string]: boolean } =
	{ Common = true, Rare = true, Epic = true, Legendary = true, Mythical = true }

-- The food's grade: its catalog `rarity`, else the design's grade for its id, else the rarity it attracts.
function FoodGrade.of(lure: Types.LureDef?): string
	if lure == nil then
		return "Common"
	end
	local own = (lure :: any).rarity
	if type(own) == "string" and KNOWN[own] then
		return own
	end
	local default = FoodGrade.DEFAULTS[lure.id]
	if default then
		return default
	end
	return if KNOWN[lure.attracts] then lure.attracts else "Common"
end

-- The badge's text: "EPIC" on a big picture, "E" in the corner gem of a small one.
function FoodGrade.badge(grade: string, small: boolean?): string
	local upper = grade:upper()
	return if small then upper:sub(1, 1) else upper
end

-- The chip beside the name, which keeps the old meaning: "Attracts Epic".
function FoodGrade.attracts(lure: Types.LureDef): string
	return "Attracts " .. lure.attracts
end

return FoodGrade
