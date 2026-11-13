--!strict
-- The potion bag, the HUD's potion timers and the Mystery gift card's words (F64, data-model section 12b; the quest
-- potions of F73, quests.md section 4). Pure, so the cloud spec runner checks it.
--   list(catalog)              the potions in bag order: Catalog.potions when the server ships it, else the four
--                              F64 potions of the data model
--   rows(catalog, state, now)  one row per potion with its count, time left, whether Use can take it and how many
--                              fit at once (#1600, the Bag's "Use xN"); ids the player holds that the catalog does
--                              not name yet come last, named from the id
--   running(catalog, state, now)  the potions with time left, in bag order, for the HUD chips
--   boosts(catalog, state, now)   what the running potions add to food set in the bowl now, as the server's
--                              Potions.goldLuck, Potions.baitSpeed and Potions.baitGoldChance (F73): gold luck, bait
--                              speed and the Lucky Potion's gold scale
--   clock(seconds)             "9:05", "60:00"; whole seconds, rounded up so a potion never reads 0:00 early
--   giftRows(catalog, tier?)   what a Mystery gift can hold: #2614 the `tier` wrap's rows of Catalog.mysteryGiftTiers,
--                              else Catalog.mysteryGift, else the data model's table
--   giftLine(rows, foodName)   "Potion 60%  ·  2 Salmon 20%  ·  10 golden fish 10%  ·  1 spin 10%"
--   giftPrize(kind, id, count, fish?)  a MysteryGiftResult as the prize shape PrizeChips draws (#2614: coins as
--                              seconds of income, a crate with its fish, cat food)
--   giftTitle(...)             "Money Potion", "2 Salmon", "10 golden fish", "1 spin", "3 minutes of earnings",
--                              "Zone crate", "2 Big Cat Snacks"
-- `buffs` holds each running potion's endsAt in server time (Workspace:GetServerTimeNow()); the server pauses the
-- timers while the player is away, so the client only counts down to endsAt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Parent.Types)

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")) :: any

local PotionLogic = {}

export type Potion = {
	id: string,
	name: string,
	minutes: number,
	effect: string, -- one short line for the bag ("+25% money")
	-- #3344: the timer it runs: a Small or Big size's regular potion (Catalog's `buff`), as the server's Potions.buffOf
	buff: string?,
}

export type Row = {
	potion: Potion,
	count: number,
	secondsLeft: number, -- 0 when it is not running
	canUse: boolean, -- one in the bag and room under PotionMaxMinutes for its time
	fit: number, -- #1600: how many Use all drinks now, the bag's count cut to the room under PotionMaxMinutes
	-- #3344: a Small or Big size, whose secondsLeft is its regular potion's timer; the regular row carries the chip
	shared: boolean,
}

export type Boosts = {
	goldLuck: number, -- added to the Index's (a Gold Rush Potion's 0.25)
	baitSpeed: number, -- added to the Index's, the two inside BaitSpeedMax (a Quick Bait Potion's 0.25)
	goldScale: number, -- the gold chance times this (2 while a Lucky Potion runs, else 1)
}

export type GiftRow = {
	kind: string, -- "potion", "lure", "fish" or "spin"; #2614 "coins", "crate", "food", "questPotion"
	id: string?,
	count: number,
	chance: number, -- percent
	fish: number?, -- #2614: a crate's golden fish with it
}

PotionLogic.MAX_MINUTES = if type(Config.PotionMaxMinutes) == "number"
	then Config.PotionMaxMinutes
	else 60

-- data-model section 12b and quests.md section 4: names, minutes and the bag's short line, by id. The bag keeps
-- these words even once Catalog.potions arrives, since the catalog's `effect` is the server's, not the card's.
local KNOWN: { Potion } = {
	{ id = "tip_potion", name = "Money Potion", minutes = 10, effect = "+25% money" },
	{
		id = "lucky_potion",
		name = "Lucky Potion",
		minutes = 10,
		effect = "Luck +50% and double gold on bait", -- F88: Config.LuckyPotionLuck
	},
	{ id = "swift_potion", name = "Swift Potion", minutes = 5, effect = "+4 walk speed" },
	{
		id = "steady_potion",
		name = "Steady Paw Potion",
		minutes = 10,
		effect = "Easier catch circles",
	},
	{ id = "big_tip_potion", name = "Big Money Potion", minutes = 30, effect = "+50% money" },
	{ id = "gold_rush_potion", name = "Gold Rush Potion", minutes = 30, effect = "+25% gold luck" },
	{
		id = "quick_bait_potion",
		name = "Quick Bait Potion",
		minutes = 30,
		effect = "Bait ready 25% sooner",
	},
}
local F64_COUNT = 4 -- the first four of KNOWN are F64's; the rest come with Catalog.potions (F73)

-- quests.md section 4: the bait boosts by id, for a catalog row that does not carry them
local BOOSTS: { [string]: { goldLuck: number?, baitSpeed: number? } } = {
	gold_rush_potion = { goldLuck = 0.25 },
	quick_bait_potion = { baitSpeed = 0.25 },
}
local LUCKY = "lucky_potion"
local LUCKY_SCALE: number = if type(Config.LuckyPotionGoldScale) == "number"
	then Config.LuckyPotionGoldScale
	else 2

local KNOWN_BY_ID: { [string]: Potion } = {}
for _, potion in KNOWN do
	KNOWN_BY_ID[potion.id] = potion
end

-- data-model section 12b: a potion 60%, 2 Salmon 20%, 10 golden fish 10%, 1 spin 10%
local GIFT: { GiftRow } = {
	{ kind = "potion", count = 1, chance = 60 },
	{ kind = "lure", id = "salmon", count = 2, chance = 20 },
	{ kind = "fish", count = 10, chance = 10 },
	{ kind = "spin", count = 1, chance = 10 },
}

-- "gold_rush_potion" -> "Gold Rush Potion", for an id the catalog does not name
local function titleCase(id: string): string
	local words: { string } = {}
	for word in id:gmatch("[^_]+") do
		table.insert(words, word:sub(1, 1):upper() .. word:sub(2))
	end
	return table.concat(words, " ")
end

local function percent(value: number): string
	local text = string.format("%.1f", value)
	text = text:gsub("%.0$", "")
	return text .. "%"
end

function PotionLogic.list(catalog: Types.Catalog?): { Potion }
	local rows: { any } = if catalog and type((catalog :: any).potions) == "table"
		then (catalog :: any).potions
		else {}
	local list: { Potion } = {}
	for _, row in rows do
		local id = if type(row) == "table" then row.id else nil
		if type(id) ~= "string" then
			continue
		end
		local known = KNOWN_BY_ID[id]
		table.insert(list, {
			id = id,
			name = if type(row.name) == "string"
				then row.name
				elseif known then known.name
				else titleCase(id),
			minutes = if type(row.minutes) == "number"
				then row.minutes
				elseif known then known.minutes
				else 0,
			buff = if type(row.buff) == "string" and row.buff ~= id then row.buff else nil,
			effect = if known
				then known.effect
				elseif type(row.effect) == "string" then row.effect
				else "",
		})
	end
	if #list == 0 then
		for index = 1, F64_COUNT do
			table.insert(list, table.clone(KNOWN[index]))
		end
	end
	return list
end

local function secondsLeft(buffs: { [string]: number }?, id: string, now: number): number
	local endsAt = if buffs then buffs[id] else nil
	if type(endsAt) ~= "number" or endsAt ~= endsAt then
		return 0
	end
	return math.max(0, endsAt - now)
end

function PotionLogic.rows(catalog: Types.Catalog?, state: Types.PlayerState, now: number): { Row }
	local counts: { [string]: number } = state.potions or {}
	local buffs: { [string]: number }? = state.buffs
	local maxSeconds = PotionLogic.MAX_MINUTES * 60
	local rows: { Row } = {}
	local seen: { [string]: boolean } = {}
	local function add(potion: Potion)
		seen[potion.id] = true
		local count = counts[potion.id]
		count = if type(count) == "number" then math.max(0, math.floor(count)) else 0
		-- #3344: a size drinks into its regular potion's timer (the server's Potions.buffOf), so its time left, its
		-- room under PotionMaxMinutes and Use come from that timer
		local left = secondsLeft(buffs, potion.buff or potion.id, now)
		-- as the server's Potions.fitCount: whole potions in the room left under PotionMaxMinutes
		local fit = if potion.minutes > 0
			then math.clamp(math.floor((maxSeconds + 0.5 - left) / (potion.minutes * 60)), 0, count)
			else 0
		table.insert(rows, {
			potion = potion,
			count = count,
			secondsLeft = left,
			canUse = count > 0 and left + potion.minutes * 60 <= maxSeconds + 0.5,
			fit = fit,
			shared = potion.buff ~= nil,
		})
	end
	for _, potion in PotionLogic.list(catalog) do
		add(potion)
	end
	-- a potion the player holds or runs before the catalog names it still shows, in id order
	local extra: { string } = {}
	for id in counts do
		if type(id) == "string" and not seen[id] then
			table.insert(extra, id)
		end
	end
	local timers: { [string]: number } = buffs or {}
	for id in timers do
		if type(id) == "string" and not seen[id] and not table.find(extra, id) then
			table.insert(extra, id)
		end
	end
	table.sort(extra)
	for _, id in extra do
		local known = KNOWN_BY_ID[id]
		add(
			if known
				then table.clone(known)
				else { id = id, name = titleCase(id), minutes = 0, effect = "" }
		)
	end
	return rows
end

function PotionLogic.running(
	catalog: Types.Catalog?,
	state: Types.PlayerState,
	now: number
): { Row }
	local running: { Row } = {}
	for _, row in PotionLogic.rows(catalog, state, now) do
		if row.secondsLeft > 0 and not row.shared then -- #3344: one chip per timer
			table.insert(running, row)
		end
	end
	return running
end

-- The potion bag's rows (Derek 2026-11-03: "it only shows use on potions you have and disappear when used"): the
-- potions in the bag and the ones still running, in bag order; a potion you have none of and that is not running
-- has no row.
-- #3190 (Derek2: "... delays on using potions too fast"): the state as it will be once the Use presses still on their
-- way go through: `extra` is potion id -> how many are pressed but not answered yet. Each comes out of the bag and adds
-- its minutes to the timer (from now if it is not running), as the server's Potions.use does. A copy; `state` is kept.
function PotionLogic.ahead(
	catalog: Types.Catalog?,
	state: Types.PlayerState,
	extra: { [string]: number },
	now: number
): Types.PlayerState
	if next(extra) == nil then
		return state
	end
	local minutes: { [string]: number } = {}
	local timerOf: { [string]: string } = {} -- #3344: a size's minutes go on its regular potion's timer
	for _, potion in PotionLogic.list(catalog) do
		minutes[potion.id] = potion.minutes
		timerOf[potion.id] = potion.buff or potion.id
	end
	local shown: any = table.clone(state :: any)
	local counts: { [string]: number } = table.clone(state.potions or {})
	local buffs: { [string]: number } = table.clone(state.buffs or {})
	for id, n in extra do
		if n > 0 then
			counts[id] = math.max(0, (counts[id] or 0) - n)
			local timer = timerOf[id] or id
			local endsAt = buffs[timer]
			local from = if type(endsAt) == "number" and endsAt > now then endsAt else now
			buffs[timer] = from + n * (minutes[id] or 0) * 60
		end
	end
	shown.potions = counts
	shown.buffs = buffs
	return shown :: Types.PlayerState
end

-- #3326 (the Bag's "Use all potions"): what one press drinks, in bag order, as the server's Potions.useAll does:
-- each kind as many as fit under PotionMaxMinutes, counted after the kinds before it went in. Kinds that fit none are
-- left out; an empty list hides the button.
export type Drink = { potion: Potion, n: number }
function PotionLogic.allPlan(
	catalog: Types.Catalog?,
	state: Types.PlayerState,
	now: number
): { Drink }
	-- a Small or Big size runs its regular potion's timer (the catalog's `buff`), as the server's Potions.buffOf
	local timerOf: { [string]: string } = {}
	local defs: { any } = if catalog ~= nil and type((catalog :: any).potions) == "table"
		then (catalog :: any).potions
		else {}
	for _, def in defs do
		if type(def) == "table" and type(def.id) == "string" then
			timerOf[def.id] = if type(def.buff) == "string" then def.buff else def.id
		end
	end
	local maxSeconds = PotionLogic.MAX_MINUTES * 60
	local added: { [string]: number } = {} -- timer id -> seconds the kinds before put on it
	local plan: { Drink } = {}
	for _, row in PotionLogic.rows(catalog, state, now) do
		local potion = row.potion
		if row.count > 0 and potion.minutes > 0 then
			local timer = timerOf[potion.id] or potion.id
			local left = secondsLeft(state.buffs, timer, now) + (added[timer] or 0)
			local n = math.clamp(
				math.floor((maxSeconds + 0.5 - left) / (potion.minutes * 60)),
				0,
				row.count
			)
			if n > 0 then
				table.insert(plan, { potion = potion, n = n })
				added[timer] = (added[timer] or 0) + n * potion.minutes * 60
			end
		end
	end
	return plan
end

-- #3326: the confirm card's line, "Tip x4, Swift x2, Lucky x1" (" Potion" dropped from each name), and the total.
function PotionLogic.allLine(plan: { Drink }): (string, number)
	local parts: { string } = {}
	local total = 0
	for _, drink in plan do
		local name = string.gsub(drink.potion.name, " Potion$", "")
		table.insert(parts, ("%s x%d"):format(name, drink.n))
		total += drink.n
	end
	return table.concat(parts, ", "), total
end

function PotionLogic.owned(catalog: Types.Catalog?, state: Types.PlayerState, now: number): { Row }
	local owned: { Row } = {}
	for _, row in PotionLogic.rows(catalog, state, now) do
		-- #3344: a size with none in the bag has no row; its time shows on the regular potion's
		if row.count > 0 or (row.secondsLeft > 0 and not row.shared) then
			table.insert(owned, row)
		end
	end
	return owned
end

-- #3937 (Derek 2026-11-13: not "potion numbers for ones that cant be drank because already full"): the Potions
-- button's count, the potions in the bag whose Use is on now (a row reading "Full" adds none), and how many the bag
-- holds in all, so the HUD knows a Full one may come back as its timer runs down.
function PotionLogic.drinkable(
	catalog: Types.Catalog?,
	state: Types.PlayerState,
	now: number
): (number, number)
	local usable, held = 0, 0
	for _, row in PotionLogic.rows(catalog, state, now) do
		held += row.count
		if row.canUse then
			usable += row.count
		end
	end
	return usable, held
end

function PotionLogic.boosts(catalog: Types.Catalog?, state: Types.PlayerState, now: number): Boosts
	local defs: { [string]: Types.PotionDef } = {}
	local list: { Types.PotionDef } = if catalog and type(catalog.potions) == "table"
		then catalog.potions
		else {}
	for _, def in list do
		if type(def) == "table" and type(def.id) == "string" then
			defs[def.id] = def
		end
	end
	local boosts: Boosts = { goldLuck = 0, baitSpeed = 0, goldScale = 1 }
	local timers: { [string]: number } = state.buffs or {}
	for id in timers do
		if type(id) ~= "string" or secondsLeft(state.buffs, id, now) <= 0 then
			continue
		end
		local def = defs[id]
		local known = BOOSTS[id]
		local luck = if def and type(def.goldLuck) == "number"
			then def.goldLuck
			elseif known then known.goldLuck
			else nil
		local speed = if def and type(def.baitSpeed) == "number"
			then def.baitSpeed
			elseif known then known.baitSpeed
			else nil
		boosts.goldLuck += math.max(0, luck or 0)
		boosts.baitSpeed += math.max(0, speed or 0)
		-- #3462: any lucky potion doubles it (the Big Lucky Potion carries `luck`), as the server's baitGoldChance
		if id == LUCKY or (def and type(def.luck) == "number" and def.luck > 0) then
			boosts.goldScale = LUCKY_SCALE
		end
	end
	return boosts
end

function PotionLogic.clock(seconds: number): string
	if seconds ~= seconds or seconds <= 0 then
		return "0:00"
	end
	local whole = math.ceil(seconds)
	return ("%d:%02d"):format(whole // 60, whole % 60)
end

function PotionLogic.giftRows(catalog: Types.Catalog?, tier: string?): { GiftRow }
	local rows: { any } = if catalog and type((catalog :: any).mysteryGift) == "table"
		then (catalog :: any).mysteryGift
		else {}
	local tiers: any = if catalog then (catalog :: any).mysteryGiftTiers else nil
	if type(tier) == "string" and type(tiers) == "table" then
		for _, wrap in tiers do
			if
				type(wrap) == "table"
				and type(wrap.tier) == "string"
				and string.lower(wrap.tier) == string.lower(tier)
				and type(wrap.rows) == "table"
			then
				rows = wrap.rows
			end
		end
	end
	local list: { GiftRow } = {}
	for _, row in rows do
		if type(row) == "table" and type(row.kind) == "string" and type(row.chance) == "number" then
			table.insert(list, {
				kind = row.kind,
				id = if type(row.id) == "string" then row.id else nil,
				count = if type(row.count) == "number" then row.count else 1,
				chance = row.chance,
				fish = if type(row.fish) == "number" then row.fish else nil,
			})
		end
	end
	if #list == 0 then
		for _, row in GIFT do
			table.insert(list, table.clone(row))
		end
	end
	return list
end

-- What a gift row or result is, in a few words: "Potion", "2 Salmon", "10 golden fish", "1 spin"; with an id a
-- potion is named ("Money Potion"). `foodName` names a food by id (the catalog's lures).
function PotionLogic.giftTitle(
	kind: string,
	id: string?,
	count: number,
	foodName: (id: string) -> string?,
	potionName: ((id: string) -> string?)?
): string
	if kind == "potion" then
		local name = if id and potionName then potionName(id) else nil
		if name == nil and id then
			local known = KNOWN_BY_ID[id]
			name = if known then known.name else titleCase(id)
		end
		local word = name or "Potion"
		return if count > 1 then ("%d %ss"):format(count, word) else word
	elseif kind == "lure" then
		local name = (if id then foodName(id) else nil) or (if id then titleCase(id) else "Food")
		return ("%d %s"):format(count, name)
	elseif kind == "fish" then
		return ("%d golden fish"):format(count)
	elseif kind == "spin" then
		return if count == 1 then "1 spin" else ("%d spins"):format(count)
	elseif kind == "coins" then
		-- #2614: `count` is seconds of income
		local minutes = math.max(1, math.floor(count / 60 + 0.5))
		return if minutes == 1
			then "1 minute of earnings"
			else ("%d minutes of earnings"):format(minutes)
	elseif kind == "crate" then
		return "Zone crate"
	elseif kind == "food" then
		local name = (if id then foodName(id) else nil)
			or (if id then titleCase(id) else "Cat Snack")
		return if count > 1 then ("%d %ss"):format(count, name) else name
	elseif kind == "questPotion" then
		return "30-min Potion"
	end
	return "A surprise"
end

function PotionLogic.giftLine(rows: { GiftRow }, foodName: (id: string) -> string?): string
	local parts: { string } = {}
	for _, row in rows do
		local what = PotionLogic.giftTitle(row.kind, row.id, row.count, foodName)
		if row.fish ~= nil and row.fish > 0 then
			what ..= (" + %d golden fish"):format(row.fish) -- #2614: the Super crate's fish
		end
		table.insert(parts, ("%s %s"):format(what, percent(row.chance)))
	end
	return table.concat(parts, "  ·  ")
end

function PotionLogic.giftPrize(
	kind: string,
	id: string?,
	count: number,
	fish: number?
): Types.IndexPrize
	local amount = math.max(1, math.floor(count))
	if kind == "coins" then
		return { coinSeconds = amount }
	elseif kind == "crate" then
		local extra = if type(fish) == "number" and fish > 0 then math.floor(fish) else nil
		return { crates = { [id or "highest"] = 1 }, fish = extra }
	elseif kind == "food" and id then
		return { catFood = { [id] = amount } }
	end
	if kind == "potion" and id then
		return { potions = { [id] = amount } }
	elseif kind == "lure" and id then
		return { lures = { [id] = amount } }
	elseif kind == "fish" then
		return { fish = amount }
	elseif kind == "spin" then
		return { spins = amount }
	end
	return {}
end

return PotionLogic
