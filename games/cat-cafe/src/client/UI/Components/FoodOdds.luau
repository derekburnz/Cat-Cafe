--!strict
-- The odds text every food card shows before you buy or use the food (data-model section 8 and the growth
-- thread's rules for paid random items: labelled text, never an icon, shown on the card itself):
--   line   "Odds: 70% Common · 26% Rare · 3.5% Epic · 0.4% Legendary · 0.1% Mythical"
--   split  the same chance for every cat of a rarity across the areas you have unlocked, cat by cat, and which
--          area the next rank up adds to the pool
--   extras the shiny chance and the charm star odds, because both change what the cat earns
-- Shared by the HUD's lure picker and the bait bowl screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local FoodOdds = {}

-- Theme.rarityOrder, kept here so this module loads without Theme's fonts (the cloud test runner has no Font)
local RARITIES: { string } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

-- data-model section 8: ShinyChanceBait 0.05 (v0.5 F42), and the charm star odds from the two-roll charm
local SHINY_CHANCE: number = Config.ShinyChanceBait
local STAR_ODDS: { number } = Config.CharmStarOdds

-- 70 -> "70%", 3.5 -> "3.5%", 17.5 -> "17.5%", 0.125 -> "0.13%" (catalog odds are percentages). Up to two
-- decimals, so a food's per-cat split adds back up to its rarity's share (reviewer N69).
local function percent(value: number): string
	local text = string.format("%.2f", value)
	text = text:gsub("0+$", ""):gsub("%.$", "")
	return text .. "%"
end

FoodOdds.percent = percent

function FoodOdds.line(odds: Types.LureOdds?): string
	if not odds then
		return "Odds: not set"
	end
	assert(odds, "odds not set")
	local parts: { string } = {}
	for _, rarity in RARITIES do
		local share = (odds :: any)[rarity]
		if type(share) == "number" then
			table.insert(parts, ("%s %s"):format(percent(share), rarity))
		end
	end
	return "Odds: " .. table.concat(parts, " · ")
end

-- Bait picks the cat uniformly among that rarity's cats in every area the player has unlocked (data-model
-- section 8), so the pool grows with the tier. "Rare 22%: Calico 11%, Siamese 11%"
function FoodOdds.split(catalog: Types.Catalog, lure: Types.LureDef, tier: number): string
	local odds = lure.odds
	if not odds then
		return "Odds not set for this food yet."
	end
	assert(odds, "odds not set")
	local unlocked: { [string]: boolean } = {}
	local areaNames: { string } = {}
	local nextArea: Types.AreaDef? = nil
	local areaList: { Types.AreaDef } = catalog.areas or {}
	for _, area in areaList do
		if area.tier <= tier then
			unlocked[area.id] = true
			table.insert(areaNames, area.name)
		elseif area.tier == tier + 1 and nextArea == nil then
			nextArea = area
		end
	end
	local lines: { string } = {
		if #areaNames > 0
			then "Same chance for every cat of a rarity in " .. table.concat(areaNames, ", ") .. ":"
			else "Same chance for every cat of a rarity:",
	}
	for _, rarity in RARITIES do
		local share = (odds :: any)[rarity]
		if type(share) ~= "number" or share <= 0 then
			continue
		end
		local names: { string } = {}
		for _, def in catalog.cats do
			if def.rarity == rarity and (#areaNames == 0 or unlocked[def.area]) then
				table.insert(names, def.name)
			end
		end
		if #names == 0 then
			continue
		end
		local each = share / #names
		local parts: { string } = {}
		for _, name in names do
			table.insert(parts, ("%s %s"):format(name, percent(each)))
		end
		table.insert(lines, ("%s %s: %s"):format(rarity, percent(share), table.concat(parts, ", ")))
	end
	if nextArea then
		local area = nextArea :: Types.AreaDef
		table.insert(
			lines,
			("Rank up to Tier %d to add the %s cats; each cat's share then gets smaller."):format(
				area.tier,
				area.name
			)
		)
	end
	return table.concat(lines, "\n")
end

-- "Shiny 5% · Charm 1★ 7.8%, 2★ 23.5%, 3★ 35.7%, 4★ 24.3%, 5★ 8.7%"
function FoodOdds.extras(): string
	local stars: { string } = {}
	for count, share in STAR_ODDS do
		table.insert(stars, ("%d★ %s"):format(count, percent(share)))
	end
	return ("Shiny %s · Charm %s"):format(percent(SHINY_CHANCE * 100), table.concat(stars, ", "))
end

return FoodOdds
