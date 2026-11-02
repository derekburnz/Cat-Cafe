--!strict
-- What lifts the cafe's money, as a short list for the card a tap on the money counter opens (Derek 2026-10-28:
-- "clicking on it should show all active multipliers like +5% ... +10% for index in a quick clean list instead of just
-- showing the number"). The same sums as the server's Economy.cafeMultiplier, tierMultiplier and the tip potions in
-- settle, from what ProfileSync already sends:
--   Tables (6)            +60%    Config.TableBonus a table
--   Espresso machine      +30%    Config.EspressoBonus a level past the first
--   Decor (3 placed)      +12%    each placed piece's bonus (Catalog.decor and Catalog.crateDecor)
--   Golden Espresso       +10%    Config.GoldenEspressoBonus a Market perk level
--   Index rewards         +6%     the claimed milestones' money forever (IndexRewards.totals)
--   Cafe tier 3           x1.5    the tier's multiplier
--   Money Potion          +25%    each running potion with `tips`, all together at most Config.TimedTipsMax
--   Pals (2)              +15%    F92: shared Pals.bonus while pals are on the server (only then, so a solo player
--                                 never sees a missing bonus), added to the potions as Economy.tipMultiplier does
--   All together          x4.3    (1 + the cafe's percents) x tier x (1 + potions + pals)
-- A source at 0 stays on the list in grey ("+0%"), so a player sees what else could lift it. The Money pass is not
-- on sale yet, so it has no row.
--   rows(catalog, state, now, pals?) -> { Row }   `pals`: how many pals PalsChanged last named
--   percent(0.25) -> "+25%", times(1.5) -> "x1.5"
-- Pure, so the cloud spec runner checks it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IndexRewards = require(script.Parent.IndexRewards)
local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any
local Pals = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pals")) :: any

local BoostList = {}

export type Kind = "add" | "times" | "total"
export type Row = {
	key: string,
	name: string,
	value: string, -- "+25%", "x1.5"
	amount: number, -- the fraction for "add", the multiplier for "times" and "total"
	kind: Kind,
	active: boolean, -- false greys the row (a +0% source)
}

local TABLE_BONUS: number = Config.TableBonus or 0.10
local ESPRESSO_BONUS: number = Config.EspressoBonus or 0.15
local GOLDEN_ESPRESSO_BONUS: number = Config.GoldenEspressoBonus or 0.05
local TIPS_MAX: number = Config.TimedTipsMax or 1
-- data-model section 12b: what the two tip potions add while they run, until Catalog.potions says
local KNOWN_TIPS: { [string]: number } =
	{ tip_potion = Config.TipPotionBonus or 0.25, big_tip_potion = 0.5 }
local POTION_NAMES: { [string]: string } =
	{ tip_potion = "Money Potion", big_tip_potion = "Big Money Potion" }

local function trim(text: string): string
	local out = text:gsub("0+$", ""):gsub("%.$", "")
	return out
end

function BoostList.percent(fraction: number): string
	local value = fraction * 100
	local text = if math.abs(value - math.floor(value + 0.5)) < 0.05
		then tostring(math.floor(value + 0.5))
		else trim(string.format("%.1f", value))
	return "+" .. text .. "%"
end

function BoostList.times(multiplier: number): string
	return "x" .. trim(string.format("%.2f", multiplier))
end

local function level(catalog: Types.Catalog?, state: Types.PlayerState, upgradeId: string): number
	local own = state.upgradeLevels[upgradeId]
	if type(own) == "number" then
		return own
	end
	local upgrades: { Types.UpgradeDef } = if catalog then catalog.upgrades else {}
	for _, def in upgrades do
		if def.id == upgradeId and type(def.startLevel) == "number" then
			return def.startLevel
		end
	end
	return if upgradeId == "espresso" then 1 else 0
end

local function decorBonus(catalog: Types.Catalog?, state: Types.PlayerState): (number, number)
	local byId: { [string]: Types.DecorDef } = {}
	if catalog then
		for _, def in catalog.decor do
			byId[def.id] = def
		end
		local crateDecor: { Types.DecorDef } = catalog.crateDecor or {}
		for _, def in crateDecor do
			byId[def.id] = def
		end
	end
	local bonus, placed = 0, 0
	for decorId, isPlaced in state.decorPlaced do
		local def = byId[decorId]
		if isPlaced and def and state.decorOwned[decorId] and type(def.bonus) == "number" then
			bonus += def.bonus
			placed += 1
		end
	end
	return bonus, placed
end

local function tierMultiplier(catalog: Types.Catalog?, tier: number): number
	local tiers: { Types.TierDef } = if catalog and catalog.tiers then catalog.tiers else {}
	for _, def in tiers do
		if def.tier == tier and type(def.multiplier) == "number" then
			return def.multiplier
		end
	end
	return 1
end

local function add(rows: { Row }, key: string, name: string, fraction: number)
	table.insert(rows, {
		key = key,
		name = name,
		value = BoostList.percent(fraction),
		amount = fraction,
		kind = "add" :: Kind,
		active = fraction > 0,
	})
end

function BoostList.rows(
	catalog: Types.Catalog?,
	state: Types.PlayerState,
	now: number,
	pals: number?
): { Row }
	local rows: { Row } = {}
	local tables = level(catalog, state, "tables")
	add(rows, "tables", ("Tables (%d)"):format(tables), TABLE_BONUS * tables)
	add(
		rows,
		"espresso",
		"Espresso machine",
		ESPRESSO_BONUS * math.max(0, level(catalog, state, "espresso") - 1)
	)
	local decor, placed = decorBonus(catalog, state)
	add(rows, "decor", if placed > 0 then ("Decor (%d placed)"):format(placed) else "Decor", decor)
	local perks: { [string]: number } = state.fishPerks or {}
	add(
		rows,
		"golden_espresso",
		"Golden Espresso",
		GOLDEN_ESPRESSO_BONUS * (perks.golden_espresso or 0)
	)
	local index = if catalog then IndexRewards.totals(catalog :: any, state :: any).bonus else 0
	add(rows, "index", "Index rewards", index)
	local cafe = 1
	for _, row in rows do
		cafe += row.amount
	end

	local tier = if type(state.tier) == "number" then state.tier else 1
	local tierTimes = tierMultiplier(catalog, tier)
	table.insert(rows, {
		key = "tier",
		name = ("Cafe tier %d"):format(tier),
		value = BoostList.times(tierTimes),
		amount = tierTimes,
		kind = "times" :: Kind,
		active = tierTimes > 1,
	})

	-- the running tip potions, each its own row, the sum capped as the server caps it
	local potionTips: { [string]: number } = {}
	local potionNames: { [string]: string } = {}
	local defs: { any } = if catalog and type(catalog.potions) == "table"
		then catalog.potions :: any
		else {}
	for _, def in defs do
		if type(def) == "table" and type(def.id) == "string" and type(def.tips) == "number" then
			potionTips[def.id] = def.tips
			if type(def.name) == "string" then
				potionNames[def.id] = def.name
			end
		end
	end
	local tips = 0
	local buffs: { [string]: number } = state.buffs or {}
	local running: { string } = {}
	for potionId, endsAt in buffs do
		local share = potionTips[potionId] or KNOWN_TIPS[potionId]
		if share and share > 0 and type(endsAt) == "number" and endsAt > now then
			table.insert(running, potionId)
		end
	end
	table.sort(running)
	for _, potionId in running do
		local share =
			math.min(potionTips[potionId] or KNOWN_TIPS[potionId], math.max(0, TIPS_MAX - tips))
		tips += share
		add(rows, potionId, potionNames[potionId] or POTION_NAMES[potionId] or potionId, share)
	end
	-- F92: the pals' share, on top of the potions' cap as the server's tipMultiplier adds it
	local palCount = if type(pals) == "number" then math.max(0, math.floor(pals)) else 0
	if palCount >= 1 then
		local share: number = Pals.bonus(palCount)
		tips += share
		add(rows, "pals", ("Pals (%d)"):format(palCount), share)
	end

	local total = cafe * tierTimes * (1 + tips)
	table.insert(rows, {
		key = "total",
		name = "All together",
		value = BoostList.times(total),
		amount = total,
		kind = "total" :: Kind,
		active = true,
	})
	return rows
end

return BoostList
