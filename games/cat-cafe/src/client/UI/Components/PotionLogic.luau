--!strict
-- The potion bag, the HUD's potion timers and the Mystery gift card's words (F64, data-model section 12b; the quest
-- potions of F73, quests.md section 4). Pure, so the cloud spec runner checks it.
--   list(catalog)              the potions in bag order: Catalog.potions when the server ships it, else the four
--                              F64 potions of the data model
--   rows(catalog, state, now)  one row per potion with its count, time left and whether Use can take it; ids the
--                              player holds that the catalog does not name yet come last, named from the id
--   running(catalog, state, now)  the potions with time left, in bag order, for the HUD chips
--   clock(seconds)             "9:05", "60:00"; whole seconds, rounded up so a potion never reads 0:00 early
--   giftRows(catalog)          what a Mystery gift can hold: Catalog.mysteryGift, else the data model's table
--   giftLine(rows, foodName)   "Potion 60%  ·  2 Salmon 20%  ·  10 golden fish 10%  ·  1 spin 10%"
--   giftPrize(kind, id, count) a MysteryGiftResult as the prize shape PrizeChips draws
--   giftTitle(...)             "Tip Potion", "2 Salmon", "10 golden fish", "1 spin"
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
	effect: string, -- one short line for the bag ("+25% tips")
}

export type Row = {
	potion: Potion,
	count: number,
	secondsLeft: number, -- 0 when it is not running
	canUse: boolean, -- one in the bag and room under PotionMaxMinutes for its time
}

export type GiftRow = {
	kind: string, -- "potion", "lure", "fish" or "spin"
	id: string?,
	count: number,
	chance: number, -- percent
}

PotionLogic.MAX_MINUTES = if type(Config.PotionMaxMinutes) == "number"
	then Config.PotionMaxMinutes
	else 60

-- data-model section 12b and quests.md section 4: names, minutes and the bag's short line, by id. The bag keeps
-- these words even once Catalog.potions arrives, since the catalog's `effect` is the server's, not the card's.
local KNOWN: { Potion } = {
	{ id = "tip_potion", name = "Tip Potion", minutes = 10, effect = "+25% tips" },
	{
		id = "lucky_potion",
		name = "Lucky Potion",
		minutes = 10,
		effect = "Double gold chance on bait",
	},
	{ id = "swift_potion", name = "Swift Potion", minutes = 5, effect = "+4 walk speed" },
	{
		id = "steady_potion",
		name = "Steady Paw Potion",
		minutes = 10,
		effect = "Easier catch circles",
	},
	{ id = "big_tip_potion", name = "Big Tip Potion", minutes = 30, effect = "+50% tips" },
	{ id = "gold_rush_potion", name = "Gold Rush Potion", minutes = 30, effect = "+25% gold luck" },
	{
		id = "quick_bait_potion",
		name = "Quick Bait Potion",
		minutes = 30,
		effect = "Bait ready 25% sooner",
	},
}
local F64_COUNT = 4 -- the first four of KNOWN are F64's; the rest come with Catalog.potions (F73)

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
		local left = secondsLeft(buffs, potion.id, now)
		table.insert(rows, {
			potion = potion,
			count = count,
			secondsLeft = left,
			canUse = count > 0 and left + potion.minutes * 60 <= maxSeconds + 0.5,
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
		if row.secondsLeft > 0 then
			table.insert(running, row)
		end
	end
	return running
end

function PotionLogic.clock(seconds: number): string
	if seconds ~= seconds or seconds <= 0 then
		return "0:00"
	end
	local whole = math.ceil(seconds)
	return ("%d:%02d"):format(whole // 60, whole % 60)
end

function PotionLogic.giftRows(catalog: Types.Catalog?): { GiftRow }
	local rows: { any } = if catalog and type((catalog :: any).mysteryGift) == "table"
		then (catalog :: any).mysteryGift
		else {}
	local list: { GiftRow } = {}
	for _, row in rows do
		if type(row) == "table" and type(row.kind) == "string" and type(row.chance) == "number" then
			table.insert(list, {
				kind = row.kind,
				id = if type(row.id) == "string" then row.id else nil,
				count = if type(row.count) == "number" then row.count else 1,
				chance = row.chance,
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
-- potion is named ("Tip Potion"). `foodName` names a food by id (the catalog's lures).
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
	end
	return "A surprise"
end

function PotionLogic.giftLine(rows: { GiftRow }, foodName: (id: string) -> string?): string
	local parts: { string } = {}
	for _, row in rows do
		local what = PotionLogic.giftTitle(row.kind, row.id, row.count, foodName)
		table.insert(parts, ("%s %s"):format(what, percent(row.chance)))
	end
	return table.concat(parts, "  ·  ")
end

function PotionLogic.giftPrize(kind: string, id: string?, count: number): Types.IndexPrize
	local amount = math.max(1, math.floor(count))
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
