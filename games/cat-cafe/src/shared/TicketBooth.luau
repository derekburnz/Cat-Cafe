--!strict
-- #4061 Ticket Booth (Water Park late station; Design-Agent/notes/ticket-booth-and-dragon-keep.md section 1, Derek's
-- OK 2026-11-13 23:53 UTC). From TicketBoothTier on, every cat caught by net, rescue or bait drops tickets by its
-- rarity, x2 for a gold coat and x5 for a rainbow one, and x2 again during the day's Ticket Rush hour (it starts at
-- the first catch of each UTC day). Tickets buy fixed prizes with day, week or once limits. Nothing random, nothing for
-- Robux, and no money pass is ever a prize. The weekly Water Park shelf, the Booth Plush Cat and the "Park Regular"
-- title come with the booth's models (a follow-up); `spent` already counts toward the title. Pure.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local TicketBooth = {}

TicketBooth.FLAG = "ticketBooth" -- the live switch: no tickets drop and BuyTicketPrize is refused while off
TicketBooth.DAY = 86400
TicketBooth.WEEK = 7 * 86400
TicketBooth.WEEK_START = 4 * 86400 -- the Unix clock began on a Thursday: weeks turn Monday 00:00 UTC
TicketBooth.RUSH_SECONDS = 3600
TicketBooth.RUSH_MULT = 2
TicketBooth.CONFIRM_AT = 1000 -- the UI asks for a second tap at this price and over
TicketBooth.REGULAR_SPENT = 10000 -- the "Park Regular" title (follow-up)

TicketBooth.PER_RARITY = {
	Common = 1,
	Rare = 2,
	Epic = 4,
	Legendary = 10,
	Mythical = 25,
	Secret = 60,
} :: { [string]: number }
TicketBooth.COAT_MULT = { gold = 2, rainbow = 5 } :: { [string]: number }

export type Limit = { per: "day" | "week" | "once", n: number }
export type Prize = {
	id: string,
	name: string,
	line: string, -- what it gives, one line for the card
	price: number,
	limit: Limit?,
	prize: Types.IndexPrize?, -- paid by Payout
	tokens: number?, -- Trait Tokens, into profile.traits.tokens
}

-- In shelf order (section 1.3)
TicketBooth.PRIZES = {
	{
		id = "fish25",
		name = "25 golden fish",
		line = "25 golden fish",
		price = 300,
		limit = { per = "day", n = 4 },
		prize = { fish = 25 },
	},
	{
		id = "traitToken",
		name = "Trait Token",
		line = "One Mystic Pool roll",
		price = 700,
		limit = { per = "week", n = 3 },
		tokens = 1,
	},
	{
		id = "goldenCrate",
		name = "Golden Crate",
		line = "A golden Cafe Crate",
		price = 900,
		limit = { per = "day", n = 2 },
		prize = { crates = { classic_golden_crate = 1 } },
	},
	{
		id = "bigGoldRush",
		name = "Big Gold Rush Potion",
		line = "30 minutes",
		price = 1200,
		prize = { potions = { big_gold_rush_potion = 1 } },
	},
	{
		id = "bigLucky",
		name = "Big Lucky Potion",
		line = "30 minutes",
		price = 1200,
		prize = { potions = { big_lucky_potion = 1 } },
	},
	{
		id = "swiftPaws",
		name = "Swift Paws",
		line = "1 hour of Big Swift Potion",
		price = 800,
		prize = { potions = { swift_potion_big = 2 } },
	},
} :: { Prize }

local byId: { [string]: Prize } = {}
for _, prize in TicketBooth.PRIZES do
	byId[prize.id] = prize
end

function TicketBooth.prize(id: string): Prize?
	return byId[id]
end

function TicketBooth.fresh(): Types.TicketSave
	return { have = 0, spent = 0, limits = {}, rushAt = 0 }
end

local function whole(value: unknown): number
	if type(value) == "number" and value == value and value >= 0 and value < 1e12 then
		return math.floor(value)
	end
	return 0
end

-- A save's tickets made whole: counts as whole numbers, limits only for known prizes.
function TicketBooth.sanitize(raw: unknown): Types.TicketSave
	local out = TicketBooth.fresh()
	if type(raw) ~= "table" then
		return out
	end
	local t = raw :: any
	out.have = whole(t.have)
	out.spent = whole(t.spent)
	out.rushAt = whole(t.rushAt)
	if type(t.limits) == "table" then
		for id, entry in t.limits do
			if type(id) == "string" and byId[id] ~= nil and type(entry) == "table" then
				out.limits[id] = { key = whole(entry.key), n = whole(entry.n) }
			end
		end
	end
	return out
end

-- Whether `tier` has the booth (Config.TicketBoothTier).
function TicketBooth.open(tier: number): boolean
	return tier >= Config.TicketBoothTier
end

function TicketBooth.dayOf(now: number): number
	return math.floor(now / TicketBooth.DAY)
end

function TicketBooth.weekOf(now: number): number
	return math.floor((now - TicketBooth.WEEK_START) / TicketBooth.WEEK)
end

-- When this week's shelf and week limits turn over (server time).
function TicketBooth.weekEndsAt(now: number): number
	return (TicketBooth.weekOf(now) + 1) * TicketBooth.WEEK + TicketBooth.WEEK_START
end

function TicketBooth.rushOn(save: Types.TicketSave, now: number): boolean
	return save.rushAt > 0 and now >= save.rushAt and now < save.rushAt + TicketBooth.RUSH_SECONDS
end

-- Tickets for one cat: by rarity and coat, times the rush. 0 for a starter or traded cat.
function TicketBooth.forCatch(
	rarity: string,
	variant: string?,
	method: Types.CatchMethod,
	rush: boolean
): number
	if method ~= "net" and method ~= "rescue" and method ~= "bait" then
		return 0
	end
	local base = TicketBooth.PER_RARITY[rarity] or 0
	local coat = if variant ~= nil then TicketBooth.COAT_MULT[variant] or 1 else 1
	return base * coat * (if rush then TicketBooth.RUSH_MULT else 1)
end

-- A catch on `save` at `now`: starts the day's rush at the day's first catch, then adds the tickets. Returns them.
function TicketBooth.credit(
	save: Types.TicketSave,
	rarity: string,
	variant: string?,
	method: Types.CatchMethod,
	now: number
): number
	if TicketBooth.dayOf(save.rushAt) ~= TicketBooth.dayOf(now) then
		save.rushAt = now
	end
	local n = TicketBooth.forCatch(rarity, variant, method, TicketBooth.rushOn(save, now))
	save.have += n
	return n
end

local function limitKey(limit: Limit, now: number): number
	if limit.per == "day" then
		return TicketBooth.dayOf(now)
	elseif limit.per == "week" then
		return TicketBooth.weekOf(now)
	end
	return 0
end

-- How many more of `prize` may be bought now, nil for no limit.
function TicketBooth.left(save: Types.TicketSave, prize: Prize, now: number): number?
	local limit = prize.limit
	if limit == nil then
		return nil
	end
	local entry = save.limits[prize.id]
	local used = if entry ~= nil and entry.key == limitKey(limit, now) then entry.n else 0
	return math.max(0, limit.n - used)
end

-- Why `prize` cannot be bought now, or nil.
function TicketBooth.blocker(save: Types.TicketSave, prize: Prize, now: number): string?
	local left = TicketBooth.left(save, prize, now)
	if left ~= nil and left <= 0 then
		local limit = prize.limit :: Limit
		return if limit.per == "day"
			then "That's all for today"
			elseif limit.per == "week" then "That's all for this week"
			else "You have this already"
	end
	if save.have < prize.price then
		return "Not enough tickets yet"
	end
	return nil
end

-- Spends the tickets and counts the limit. The caller checked `blocker` and pays the prize.
function TicketBooth.spend(save: Types.TicketSave, prize: Prize, now: number)
	save.have -= prize.price
	save.spent += prize.price
	local limit = prize.limit
	if limit ~= nil then
		local key = limitKey(limit, now)
		local entry = save.limits[prize.id]
		if entry == nil or entry.key ~= key then
			save.limits[prize.id] = { key = key, n = 1 }
		else
			entry.n += 1
		end
	end
end

-- Prizes that can be bought now (the booth's "!").
function TicketBooth.readyCount(save: Types.TicketSave, now: number): number
	local n = 0
	for _, prize in TicketBooth.PRIZES do
		if TicketBooth.blocker(save, prize, now) == nil then
			n += 1
		end
	end
	return n
end

-- For the booth window (PlayerState.ticketBooth).
function TicketBooth.view(save: Types.TicketSave, now: number): Types.TicketBoothView
	local rows: { Types.TicketPrizeRow } = {}
	for _, prize in TicketBooth.PRIZES do
		table.insert(rows, {
			id = prize.id,
			name = prize.name,
			line = prize.line,
			price = prize.price,
			left = TicketBooth.left(save, prize, now),
			per = if prize.limit ~= nil then prize.limit.per :: string else nil,
			blocker = TicketBooth.blocker(save, prize, now),
		})
	end
	return {
		tickets = save.have,
		spent = save.spent,
		rushEndsAt = if TicketBooth.rushOn(save, now)
			then save.rushAt + TicketBooth.RUSH_SECONDS
			else nil,
		rushUsedToday = TicketBooth.dayOf(save.rushAt) == TicketBooth.dayOf(now),
		weekEndsAt = TicketBooth.weekEndsAt(now),
		prizes = rows,
		ready = TicketBooth.readyCount(save, now),
	}
end

return TicketBooth
