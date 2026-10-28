--!strict
-- The odds text every food card shows before you buy or use the food (data-model section 8 and the growth
-- thread's rules for paid random items: labelled text, never an icon, shown on the card itself):
--   rich   the card's one short row, each rarity's name and share in its colour (Derek 2026-10-28):
--          "Common 70%   Rare 26%   Epic 3.5%   Legendary 0.4%   Mythical 0.1%"
--   line   the same as plain text, "Odds: 70% Common · 26% Rare · 3.5% Epic · 0.4% Legendary · 0.1% Mythical"
--   split  the same chance for every cat of a rarity across the areas you have unlocked, cat by cat, and which
--          area the next rank up adds to the pool
--   extras the gold chance (with the Index's gold luck in it, v0.10) and the charm star odds, because both change
--          what the cat earns; under the card's Details since 2026-10-28, with the split
--   waitSeconds how long the bowl's cat takes: LureWaitSeconds, or the Big Bowl perk's wait, half for food set at
--          night (F60), less the Index's faster bait (F54), whole seconds as the server's Economy.baitWaitSeconds
-- Shared by the bait bowl screen and the night dealer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local FoodOdds = {}

-- Theme.rarityOrder, kept here so this module loads without Theme's fonts (the cloud test runner has no Font)
local RARITIES: { string } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
local NBSP = utf8.char(0xA0) -- a no-break space

-- data-model section 8: GoldChanceBait 0.05 (v0.5 F42), and the charm star odds from the two-roll charm
local GOLD_CHANCE: number = Config.GoldChanceBait
local STAR_ODDS: { number } = Config.CharmStarOdds
local GOLD_LUCK_MAX: number = (Config :: any).GoldLuckMax or 1.5
local BAIT_SPEED_MAX: number = (Config :: any).BaitSpeedMax or 0.5
local WAIT_SECONDS: number = Config.LureWaitSeconds
local BIG_BOWL_SECONDS: number = (Config :: any).BigBowlLureWaitSeconds or WAIT_SECONDS
local NIGHT_SECONDS: number = Config.LureWaitSecondsNight -- F60: 300, so night food waits half

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

-- The card's odds row for a RichText label: "Common 70%   Rare 25%   ..." with each part in its rarity's colour.
-- `hexOf` gives that colour as hex (the screens pass Theme.rarityInk), since this module loads without Theme.
-- A no-break space joins each name to its share, so a wrapped row never leaves "Rare" and "25%" apart (N229).
function FoodOdds.rich(odds: Types.LureOdds?, hexOf: (rarity: string) -> string): string
	if not odds then
		return "Odds: not set"
	end
	assert(odds, "odds not set")
	local parts: { string } = {}
	for _, rarity in RARITIES do
		local share = (odds :: any)[rarity]
		if type(share) == "number" then
			local part = rarity .. NBSP .. percent(share)
			table.insert(parts, ('<font color="#%s">%s</font>'):format(hexOf(rarity), part))
		end
	end
	return table.concat(parts, "   ")
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
			-- with no areas in the catalog every cat but the spare ones (F78), which never come from bait
			local area: string? = def.area
			local inPool = if #areaNames == 0 then area ~= "spare" else unlocked[def.area] == true
			if def.rarity == rarity and inPool then
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

-- "Gold 5% · Charm 1★ 7.8%, 2★ 23.5%, 3★ 35.7%, 4★ 24.3%, 5★ 8.7%"; with gold luck the chance has it in
-- (chance x (1 + luck), golden-fish.md section 5): "Gold 7% (+40% luck) · Charm ...".
function FoodOdds.extras(goldLuck: number?): string
	local stars: { string } = {}
	for count, share in STAR_ODDS do
		table.insert(stars, ("%d★ %s"):format(count, percent(share)))
	end
	local luck = math.clamp(goldLuck or 0, 0, GOLD_LUCK_MAX)
	local gold = percent(GOLD_CHANCE * (1 + luck) * 100)
	if luck > 0 then
		gold ..= (" (+%s luck)"):format(percent(luck * 100))
	end
	return ("Gold %s · Charm %s"):format(gold, table.concat(stars, ", "))
end

-- The bait wait for food going in now, as the server's Economy.baitWaitSeconds: the Big Bowl perk's wait or
-- LureWaitSeconds, cut to LureWaitSecondsNight's share when it goes in at night (F60: 300 s, or 240 with the Big
-- Bowl), less the faster bait. The server adds a hair before flooring for the summed percents' float error, so this
-- does too (372 s, not 371).
function FoodOdds.waitSeconds(bigBowl: boolean, baitSpeed: number?, night: boolean?): number
	local base = if bigBowl then BIG_BOWL_SECONDS else WAIT_SECONDS
	if night then
		base = math.floor(base * NIGHT_SECONDS / WAIT_SECONDS)
	end
	return math.floor(base * (1 - math.clamp(baitSpeed or 0, 0, BAIT_SPEED_MAX)) + 1e-6)
end

return FoodOdds
