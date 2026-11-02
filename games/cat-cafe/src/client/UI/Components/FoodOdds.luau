--!strict
-- The odds text every food card shows before you buy or use the food (data-model section 8 and the growth
-- thread's rules for paid random items: labelled text, never an icon, shown on the card itself):
--   rich   the card's one short row, each rarity's name and share in its colour (Derek 2026-10-28):
--          "Common 70%   Rare 26%   Epic 3.5%   Legendary 0.4%   Mythical 0.1%"
--   line   the same as plain text, "Odds: 70% Common · 26% Rare · 3.5% Epic · 0.4% Legendary · 0.1% Mythical"
--   split  the same chance for every cat of a rarity across the areas you have unlocked, cat by cat, and which
--          area the next rank up adds to the pool
--   extras the gold chance (with the Index's gold luck in it, v0.10, and a running Gold Rush or Lucky Potion's,
--          F73), because it changes what the cat earns; under the card's Details since 2026-10-28, with the split.
--          The charm star odds left with F97 section 5 (stars show nowhere now)
--   rainbow the rainbow chance under it (F99, rainbow-coat.md section 1): "Rainbow 0.5%", with the Index's rainbow
--          luck in it, once the server's Config has RainbowChanceBait
--   atBowl a food's odds in the player's bowl (F82): shared Bait.oddsFor at the lure_bowl level, then the player's
--          Luck (F88, shared/Luck.apply), as the server rolls food set now
--   waitSeconds how long the bowl's cat takes: the bowl level's wait (F82), 2 minutes off with the Big Bowl perk, half
--          for food set at night (F60), less the faster bait (the Index's, F54, plus a running Quick Bait Potion's,
--          F73, the two inside BaitSpeedMax), whole seconds as the server's Economy.baitWaitSeconds
--   bowlStep the bait bowl's two shop lines: the next bowl and its wait, and one food's rarer cats (F82)
-- Shared by the bait bowl screen, the night dealer and the upgrades shop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Types)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bait = require(Shared:WaitForChild("Bait"))
local Config = require(Shared:WaitForChild("Config"))
local Luck = require(Shared:WaitForChild("Luck"))

local FoodOdds = {}

-- Theme.rarityOrder, kept here so this module loads without Theme's fonts (the cloud test runner has no Font)
local RARITIES: { string } = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
local NBSP = utf8.char(0xA0) -- a no-break space

-- data-model section 8: GoldChanceBait 0.05 (v0.5 F42)
local GOLD_CHANCE: number = Config.GoldChanceBait
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

-- A food's odds in a bowl of `bowlLevel` (F82) at the player's Luck (F88): the server rolls shared Bait.oddsFor at
-- the player's lure_bowl level and then Luck.apply, so every card shows the same. No bowl (0) or a level 1 bowl
-- keeps the food's own odds, and Luck x1 (or nil) leaves them as the bowl makes them.
function FoodOdds.atBowl(odds: Types.LureOdds?, bowlLevel: number?, luck: number?): Types.LureOdds?
	if not odds then
		return nil
	end
	assert(odds, "odds not set")
	local bowl = Bait.oddsFor(odds, bowlLevel or 0)
	return if luck ~= nil and luck > 1 then Luck.apply(bowl, luck) else bowl
end

-- Bait picks the cat uniformly among that rarity's cats in every area the player has unlocked (data-model
-- section 8), so the pool grows with the tier. "Rare 22%: Calico 11%, Siamese 11%". The shares are the bowl's
-- (F82) at the player's Luck (F88). A bowl past level 1 says so on a last line, named "rarer visitors" so the one
-- thing called Luck is the HUD chip's (spec 1b), and Luck over x1 says so under it.
function FoodOdds.split(
	catalog: Types.Catalog,
	lure: Types.LureDef,
	tier: number,
	bowlLevel: number?,
	luck: number?
): string
	local odds = FoodOdds.atBowl(lure.odds, bowlLevel, luck)
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
	local shift = Bait.luck(bowlLevel or 0)
	if shift > 0 then
		table.insert(
			lines,
			("%s: rarer visitors. %s of each rarity's chance moves up one rarity."):format(
				Bait.bowlName(bowlLevel or 0),
				percent(shift * 100)
			)
		)
	end
	if luck ~= nil and luck > 1 then
		table.insert(
			lines,
			("Your %s is in these odds: Epic and rarer cats are more likely."):format(
				Luck.text(luck)
			)
		)
	end
	return table.concat(lines, "\n")
end

-- "Gold 5%"; with gold luck the chance has it in (chance x (1 + luck), golden-fish.md section 5): "Gold 7% (+40%
-- luck)". F73, as the server's BaitService: `potionLuck` (a running Gold Rush Potion's) goes on top of the Index's
-- capped luck, and `goldScale` (a running Lucky Potion's 2) multiplies the lot: "Gold 16.5% (+65% luck, Lucky Potion
-- x2)". No charm star odds since F97 section 5.
function FoodOdds.extras(goldLuck: number?, potionLuck: number?, goldScale: number?): string
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
	return "Gold " .. gold
end

-- "Rainbow 0.5%" under the gold line (F99, rainbow-coat.md section 1): RainbowChanceBait x (1 + rainbow luck), the
-- luck capped at RainbowLuckMax, so a Rainbow Master reads "Rainbow 1% (+100% luck)". Gold luck, Gold Rush and Lucky
-- Potions never touch it. Nil while the server has no rainbow roll (no RainbowChanceBait in Config); `chance` stands
-- in for the Config's in the spec.
function FoodOdds.rainbow(rainbowLuck: number?, chance: number?): string?
	local base = chance or tonumber((Config :: any).RainbowChanceBait)
	if base == nil or base <= 0 then
		return nil
	end
	local most = tonumber((Config :: any).RainbowLuckMax) or 1
	local luck = math.clamp(rainbowLuck or 0, 0, most)
	local line = "Rainbow " .. percent(base * (1 + luck) * 100)
	if luck > 0 then
		line ..= (" (+%s luck)"):format(percent(luck * 100))
	end
	return line
end

-- The bait wait for food going in now, as the server's Economy.baitWaitSeconds: shared Bait.waitSeconds for the
-- bowl's level (F82: 600 s down to 480), BigBowlWaitCutSeconds (120) off with the Big Bowl perk (F95),
-- LureWaitSecondsNight's share of it at night (F60: half), then less the faster bait. The server adds a hair before
-- flooring for the summed percents' float error, so this does too (372 s, not 371).
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
-- names the bowl you have. The wait is the day wait, with the Big Bowl perk's 2 minutes off when owned (F95).
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
