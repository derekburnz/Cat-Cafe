--!strict
-- #4221 (Derek 2026-11-14: "a separate secret tab of the index and make one secret per area"): the Index's Secret
-- tab, while the `secretAreas` switch is on. One card per area in tier order:
-- - "found": the area's Secret is in this player's collection; its look and name, and whether they have it gold or
--   rainbow too;
-- - "hidden": the area is open (or its Secret was found some other way) and its Secret is not found yet: a black shape,
--   "???" and the area's hint;
-- - "locked": the player's tier has not opened the area: "Tier N";
-- - "soon": no Secret lives in the area yet (its cat ships later): "Coming soon".
-- The header counts found over every area ("3 / 10 found"). It counts toward no Index total, track or reward, like the
-- Exclusive page. Pure: no Theme, so the cloud spec runner can load it.
--   cards(catalog, state) -> { Card }   the cards in tier order
--   counter(cards) -> string            "3 / 10 found"
--   line(cards) -> string               the header's first line: the rule, every Secret found, or none yet
--   hint(card) -> string                the small line under a card's name

local CatVariant = require(script.Parent.CatVariant)
local IndexBook = require(script.Parent.IndexBook)
local Types = require(script.Parent.Parent.Types)

export type CardState = "found" | "hidden" | "locked" | "soon"

export type Card = {
	area: string,
	areaName: string,
	tier: number,
	state: CardState,
	def: Types.CatDef?, -- the area's Secret, nil while none lives there
	gold: boolean, -- found in its gold coat
	rainbow: boolean, -- found in its rainbow coat
}

local SecretTabLogic = {}

SecretTabLogic.FLAG = "secretAreas" -- Catching.SECRET_AREAS_FLAG
SecretTabLogic.TAB = "Secret"
SecretTabLogic.LINE = "One Secret cat hides in every area."
SecretTabLogic.NOTE = "Not counted in the Index."
SecretTabLogic.ALL_FOUND = "Every Secret found. Amazing!"
SecretTabLogic.NONE_YET = "Secret cats can turn up when a Mythical appears. Keep catching!"
SecretTabLogic.HIDDEN_NAME = "???"
SecretTabLogic.SOON = "Coming soon"
-- Growth-Agent's hints (secret-tab-copy.md): the area and a feeling, never the look. Only for Secrets already in the
-- game; each new one's hint comes with its cat (the dark-shape rule keeps them out of the repo until then).
SecretTabLogic.HINTS = {
	alley = "Something floats past the cafe at night...",
	neighbourhood = "One house on the street keeps flickering.",
	snowy = "Stars fall on the highest peak.",
} :: { [string]: string }
SecretTabLogic.HINT_FALLBACK = "Keep catching here..."

function SecretTabLogic.cards(catalog: Types.Catalog, state: Types.PlayerState): { Card }
	local found = IndexBook.found(state, "normal")
	local gold: { [string]: number } = CatVariant.collection(state)
	local rainbow: { [string]: number } = CatVariant.rainbowCollection(state)
	local secretOf: { [string]: Types.CatDef } = {}
	for _, def in catalog.cats do
		local home = def.secretArea
		if def.area == IndexBook.SECRET and home ~= nil and secretOf[home] == nil then
			secretOf[home] = def -- catalog order: the first one an area names
		end
	end
	local areas = table.clone(catalog.areas or {})
	table.sort(areas, function(a: Types.AreaDef, b: Types.AreaDef): boolean
		return a.tier < b.tier
	end)
	local list: { Card } = {}
	for _, area in areas do
		local def = secretOf[area.id]
		local have = def ~= nil and found[def.id] == true
		local cardState: CardState = if def == nil
			then "soon"
			elseif have then "found"
			elseif state.tier < area.tier then "locked"
			else "hidden"
		table.insert(list, {
			area = area.id,
			areaName = area.name,
			tier = area.tier,
			state = cardState,
			def = def,
			gold = have and def ~= nil and (gold[def.id] or 0) > 0,
			rainbow = have and def ~= nil and (rainbow[def.id] or 0) > 0,
		})
	end
	return list
end

function SecretTabLogic.counter(cards: { Card }): string
	local have = 0
	for _, card in cards do
		if card.state == "found" then
			have += 1
		end
	end
	return ("%d / %d found"):format(have, #cards)
end

function SecretTabLogic.line(cards: { Card }): string
	local have = 0
	for _, card in cards do
		if card.state == "found" then
			have += 1
		end
	end
	if #cards > 0 and have >= #cards then
		return SecretTabLogic.ALL_FOUND
	elseif have == 0 then
		return SecretTabLogic.NONE_YET
	end
	return SecretTabLogic.LINE
end

-- The card's name line: the cat's name once found, "???" while hidden, "Tier N" while locked, "Coming soon".
function SecretTabLogic.name(card: Card): string
	if card.state == "found" and card.def ~= nil then
		return card.def.name
	elseif card.state == "locked" then
		return "Tier " .. tostring(card.tier)
	elseif card.state == "soon" then
		return SecretTabLogic.SOON
	end
	return SecretTabLogic.HIDDEN_NAME
end

-- The small line under the name: the hint while hidden, how to open a locked area, nothing otherwise.
function SecretTabLogic.hint(card: Card): string
	if card.state == "hidden" then
		return SecretTabLogic.HINTS[card.area] or SecretTabLogic.HINT_FALLBACK
	elseif card.state == "locked" then
		return ("Reach Tier %d to search here"):format(card.tier)
	end
	return ""
end

return SecretTabLogic
