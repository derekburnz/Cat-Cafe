--!strict
-- The odds text every food card shows before you buy or use the food (data-model section 8 and the growth
-- thread's rules for paid random items: labelled text, never an icon, shown on the card itself):
--   rich   the card's one short row, each rarity's name and share in its colour (Derek 2026-10-28):
--          "Common 70%   Rare 26%   Epic 3.5%   Legendary 0.4%   Mythical 0.1%"
--   line   the same as plain text, "Odds: 70% Common · 26% Rare · 3.5% Epic · 0.4% Legendary · 0.1% Mythical"
--   split  the same chance for every cat of a rarity across the areas you have unlocked, cat by cat, and which
--          area the next rank up adds to the pool
--   extras the gold chance (with the Index's gold luck in it, v0.10, and a running Gold Rush or Lucky Potion's,
--          F73) and the charm star odds, because both change what the cat earns; under the card's Details since
--          2026-10-28, with the split
--   atBowl a food's odds in the player's bowl (F82): shared Bait.oddsFor at the lure_bowl level, as the server rolls
--   waitSeconds how long the bowl's cat takes: the bowl level's wait (F82), a fifth off with the Big Bowl perk, half
--          for food set at night (F60), less the faster bait (the Index's, F54, plus a running Quick Bait Potion's,
--          F73, the two inside BaitSpeedMax), whole seconds as the server's Economy.baitWaitSeconds
--   bowlStep the bait bowl's two shop lines: the next bowl and its wait, and one food's rarer cats (F82)
-- Shared by the bait bowl screen, the night dealer and the upgrades shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Types)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bait = require(Shared:WaitForChild("Bait"))
local Config = require(Shared:WaitForChild("Config"))

local FoodOdds = {}

-- Theme.rarityOrder, kept here so this module loads without Theme's fonts (the cloud test runner has no Font)
local RARITIES: { string } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
local NBSP = utf8.char(0xA0) -- a no-break space

-- data-model section 8: GoldChanceBait 0.05 (v0.5 F42), and the charm star odds from the two-roll charm
local GOLD_CHANCE: number = Config.GoldChanceBait
local STAR_ODDS: { number } = Config.CharmStarOdds
local GOLD_LUCK_MAX: number = (Config :: any).GoldLuckMax or 1.5
local BAIT_SPEED_MAX: number = (Config :: any).BaitSpeedMax or 0.5

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

-- A food's odds in a bowl of `bowlLevel` (F82): the server rolls shared Bait.oddsFor at the player's lure_bowl
-- level, so every card shows the same. No bowl (0) or a level 1 bowl keeps the food's own odds.
function FoodOdds.atBowl(odds: Types.LureOdds?, bowlLevel: number?): Types.LureOdds?
	if not odds then
		return nil
	end
	assert(odds, "odds not set")
	return Bait.oddsFor(odds, bowlLevel or 0)
end

-- Bait picks the cat uniformly among that rarity's cats in every area the player has unlocked (data-model
-- section 8), so the pool grows with the tier. "Rare 22%: Calico 11%, Siamese 11%". The shares are the bowl's
-- (F82), and a bowl with luck says so on the last line.
function FoodOdds.split(
	catalog: Types.Catalog,
	lure: Types.LureDef,
	tier: number,
	bowlLevel: number?
): string
	local odds = FoodOdds.atBowl(lure.odds, bowlLevel)
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
	local luck = Bait.luck(bowlLevel or 0)
	if luck > 0 then
		table.insert(
			lines,
			("Your %s moves %s of each rarity's chance up one rarity."):format(
				Bait.bowlName(bowlLevel or 0),
				percent(luck * 100)
			)
		)
	end
	return table.concat(lines, "\n")
end

-- "Gold 5% · Charm 1★ 7.8%, 2★ 23.5%, 3★ 35.7%, 4★ 24.3%, 5★ 8.7%"; with gold luck the chance has it in
-- (chance x (1 + luck), golden-fish.md section 5): "Gold 7% (+40% luck) · Charm ...". F73, as the server's
-- BaitService: `potionLuck` (a running Gold Rush Potion's) goes on top of the Index's capped luck, and `goldScale`
-- (a running Lucky Potion's 2) multiplies the lot: "Gold 16.5% (+65% luck, Lucky Potion x2) · Charm ...".
function FoodOdds.extras(goldLuck: number?, potionLuck: number?, goldScale: number?): string
	local stars: { string } = {}
	for count, share in STAR_ODDS do
		table.insert(stars, ("%d★ %s"):format(count, percent(share)))
	end
	local luck = math.clamp(goldLuck or 0, 0, GOLD_LUCK_MAX) + math.max(0, potionLuck or 0)
	local scale = math.max(1, goldScale or 1)
	local gold = percent(GOLD_CHANCE * (1 + luck) * scale * 100)
	local notes: { string } = {}
	if luck > 0 then
		table.insert(notes, ("+%s luck"):format(percent(luck * 100)))
	end
	if scale > 1 then
		table.insert(notes, ("Lucky Potion x%g"):format(scale))
	end
	if #notes > 0 then
		gold ..= " (" .. table.concat(notes, ", ") .. ")"
	end
	return ("Gold %s · Charm %s"):format(gold, table.concat(stars, ", "))
end

-- The bait wait for food going in now, as the server's Economy.baitWaitSeconds: shared Bait.waitSeconds for the
-- bowl's level (F82: 600 s down to 480), a fifth off with the Big Bowl perk, LureWaitSecondsNight's share of it at
-- night (F60: half), then less the faster bait. The server adds a hair before flooring for the summed percents' float
-- error, so this does too (372 s, not 371).
function FoodOdds.waitSeconds(
	bowlLevel: number,
	bigBowl: boolean,
	baitSpeed: number?,
	night: boolean?
): number
	local base = Bait.waitSeconds(bowlLevel, bigBowl, night)
	return math.floor(base * (1 - math.clamp(baitSpeed or 0, 0, BAIT_SPEED_MAX)) + 1e-6)
end

-- 570 -> "9m 30s", 480 -> "8m" (Format.duration's style, which this module cannot load in the cloud test runner)
local function minutes(seconds: number): string
	local mins = seconds // 60
	local secs = seconds % 60
	if mins == 0 then
		return ("%ds"):format(secs)
	end
	return if secs == 0 then ("%dm"):format(mins) else ("%dm %ds"):format(mins, secs)
end

-- The example food on the bowl's shop row: the Salmon, else the first shop food (design F82)
local function exampleFood(catalog: Types.Catalog): Types.LureDef?
	local first: Types.LureDef? = nil
	local lures: { Types.LureDef } = catalog.lures or {}
	for _, lure in lures do
		if lure.id == "salmon" and lure.odds then
			return lure
		elseif first == nil and lure.odds and lure.source ~= "dealer" then
			first = lure
		end
	end
	return first
end

-- The bait bowl's row in the upgrades shop (F82), two short lines for a bowl at `level` (0 when not bought):
--   "Next: Comfy Bowl · 9m 30s wait"
--   "Rarer bait cats: Salmon Legendary 8.5% to 9.36%", the rarity one up from what the food attracts
-- With no bowl the second line is nil, so the row keeps the catalog's description; at the top level the first line
-- names the bowl you have. The wait is the day wait, with the Big Bowl perk's fifth off when owned.
function FoodOdds.bowlStep(
	catalog: Types.Catalog,
	level: number,
	bigBowl: boolean
): (string, string?)
	if level >= Bait.MAX_LEVEL then
		return ("%s · %s wait"):format(
			Bait.bowlName(level),
			minutes(Bait.waitSeconds(level, bigBowl))
		),
			"Top bowl: bait cats at their rarest"
	end
	local nextLevel = level + 1
	local first = ("Next: %s · %s wait"):format(
		Bait.bowlName(nextLevel),
		minutes(Bait.waitSeconds(nextLevel, bigBowl))
	)
	local food = exampleFood(catalog)
	if level < 1 or not food then
		return first, nil
	end
	local lure = food :: Types.LureDef
	local index = table.find(RARITIES, lure.attracts) or 1
	local rarity = RARITIES[math.min(index + 1, #RARITIES)]
	local now = (FoodOdds.atBowl(lure.odds, level) :: any)[rarity] or 0
	local after = (FoodOdds.atBowl(lure.odds, nextLevel) :: any)[rarity] or 0
	return first,
		("Rarer bait cats: %s %s %s to %s"):format(lure.name, rarity, percent(now), percent(after))
end

return FoodOdds
