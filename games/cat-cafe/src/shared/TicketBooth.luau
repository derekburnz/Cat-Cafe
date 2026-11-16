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
	cat: string?, -- an exclusive cat's id, given by TicketBoothService (the Booth Plush Cat)
	-- the weekly Water Park shelf (spec 1.3): a decor piece (Catalog.boothDecor, into decorOwned) or a wearable (a Looks
	-- accessory, owned once its once-limit is used); only buyable the weeks it is on the shelf (weekShelf)
	weekly: { kind: "decor" | "look", item: string }?,
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
	-- #4596 (Derek 2026-11-15: "remove the potions ... make it more then 1 trait token like 10 trait tokens but price
	-- increased and add some other options instead of the potions"): Design-Agent's shelf. The old ids traitToken,
	-- bigGoldRush, bigLucky and swiftPaws left it; their saved counts are only ignored.
	{
		id = "tokens10",
		name = "10 Trait Tokens",
		line = "Ten Mystic Pool rolls",
		price = 2000, -- #4960 (Derek 2026-11-16: "lower the price of trait tokens by like 3x"): was 6,000
		limit = { per = "week", n = 1 },
		tokens = 10,
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
		id = "spins5",
		name = "5 Wheel Spins",
		line = "Five spins of the wheel",
		price = 1000,
		limit = { per = "day", n = 3 },
		prize = { spins = 5 },
	},
	-- #4959 (Derek 2026-11-16: "make this at least a legendary bait or mythic not caviar"): Moon Milk, the Legendary
	-- bait, in place of the Epic Caviar (id "caviar" left the shelf; its saved count is only ignored)
	{
		id = "moonMilk",
		name = "Moon Milk Bait",
		line = "Legendary bait",
		price = 1200,
		limit = { per = "day", n = 3 },
		prize = { lures = { moon_milk = 1 } },
	},
	{
		id = "bestGolden",
		name = "Best Golden Crate",
		line = "Your best area's golden crate",
		price = 1800,
		limit = { per = "day", n = 1 },
		prize = { crates = { highest_golden = 1 } },
	},
	{
		id = "boothPlush",
		name = "Booth Plush Cat",
		line = "A Legendary cat, only here",
		price = 8000,
		limit = { per = "once", n = 1 },
		cat = "booth_plush",
	},
} :: { Prize }

-- #4061 (spec 1.3): the weekly Water Park shelf, SHELF_SIZE cards a week taken in turn from WEEKLY (Monday 00:00 UTC).
-- Decor pays like a crate piece of its rarity while in use (Rare +4%, Epic +8%); a wearable pays WEAR_BONUS while it
-- is the cafe's accessory. Bought once, owned for good; "Owned" when it comes round again. No player toys
-- (Derek 2026-11-16: toys do not fit this game; cat cosmetics do).
TicketBooth.SHELF_SIZE = 4
TicketBooth.WEAR_BONUS = 0.05
local function weekly(
	id: string,
	name: string,
	line: string,
	price: number,
	kind: "decor" | "look",
	item: string
): Prize
	return {
		id = id,
		name = name,
		line = line,
		price = price,
		limit = { per = "once", n = 1 },
		weekly = { kind = kind, item = item },
	}
end
TicketBooth.WEEKLY = {
	weekly(
		"wFlamingoFloat",
		"Flamingo Float",
		"Rare decor, +4% money",
		1500,
		"decor",
		"decor_flamingo_float"
	),
	weekly(
		"wSnorkelMask",
		"Snorkel Mask",
		"Glasses, +5% while worn",
		1200,
		"look",
		"acc_snorkel_mask"
	),
	weekly(
		"wSplashFountain",
		"Splash Fountain",
		"Epic decor, +8% money",
		3000,
		"decor",
		"decor_splash_fountain"
	),
	weekly("wSwimCap", "Swim Cap", "Hat, +5% while worn", 1500, "look", "acc_swim_cap"),
	weekly(
		"wTicketArch",
		"Ticket Arch",
		"Epic decor, +8% money",
		2500,
		"decor",
		"decor_ticket_arch"
	),
	weekly("wSunVisor", "Sun Visor", "Hat, +5% while worn", 1800, "look", "acc_sun_visor"),
	weekly(
		"wWavePoolTiles",
		"Wave Pool Tiles",
		"Rare decor, +4% money",
		1800,
		"decor",
		"decor_wave_pool_tiles"
	),
	weekly(
		"wStarfishShades",
		"Starfish Shades",
		"Glasses, +5% while worn",
		2000,
		"look",
		"acc_starfish_shades"
	),
	weekly(
		"wLifeguardChair",
		"Lifeguard Chair",
		"Rare decor, +4% money",
		2000,
		"decor",
		"decor_lifeguard_chair"
	),
	weekly("wSnackHut", "Snack Hut", "Epic decor, +8% money", 3000, "decor", "decor_snack_hut"),
} :: { Prize }

-- #4061 (spec 1.3): the "Park Regular" chat title, held for good once a save has spent this many tickets
-- (CafePassService adds it to the tag choices from profile.tickets.spent)
TicketBooth.REGULAR_SPENT = 10000
TicketBooth.REGULAR_TAG = "title_park_regular"

function TicketBooth.regular(save: Types.TicketSave): boolean
	return save.spent >= TicketBooth.REGULAR_SPENT
end

local byId: { [string]: Prize } = {}
for _, prize in TicketBooth.PRIZES do
	byId[prize.id] = prize
end
for _, prize in TicketBooth.WEEKLY do
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

-- #4061: this week's SHELF_SIZE weekly cards, the next ones of WEEKLY in turn each Monday 00:00 UTC.
function TicketBooth.weekShelf(now: number): { Prize }
	local n = #TicketBooth.WEEKLY
	local start = (TicketBooth.weekOf(now) * TicketBooth.SHELF_SIZE) % n
	local out: { Prize } = {}
	for i = 0, math.min(TicketBooth.SHELF_SIZE, n) - 1 do
		table.insert(out, TicketBooth.WEEKLY[(start + i) % n + 1])
	end
	return out
end

function TicketBooth.onShelf(prize: Prize, now: number): boolean
	return table.find(TicketBooth.weekShelf(now), prize) ~= nil
end

-- Whether the save bought weekly `prize` (its once-limit used).
function TicketBooth.owns(save: Types.TicketSave, prize: Prize): boolean
	local entry = save.limits[prize.id]
	return entry ~= nil and entry.n >= 1
end

-- The weekly wearables the save owns, as Looks items (accessory id -> true), added into a copy of `items`.
function TicketBooth.lookItems(
	save: Types.TicketSave,
	items: { [string]: boolean }
): { [string]: boolean }
	local out = table.clone(items)
	for _, prize in TicketBooth.WEEKLY do
		local w = prize.weekly
		if w ~= nil and w.kind == "look" and TicketBooth.owns(save, prize) then
			out[w.item] = true
		end
	end
	return out
end

-- WEAR_BONUS when `accessory` (the cafe's worn Looks accessory) is a weekly wearable the save owns, else 0.
function TicketBooth.wearBonus(save: Types.TicketSave, accessory: string?): number
	if accessory == nil then
		return 0
	end
	for _, prize in TicketBooth.WEEKLY do
		local w = prize.weekly
		if
			w ~= nil
			and w.kind == "look"
			and w.item == accessory
			and TicketBooth.owns(save, prize)
		then
			return TicketBooth.WEAR_BONUS
		end
	end
	return 0
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
	if prize.weekly ~= nil and not TicketBooth.onShelf(prize, now) then
		return "Not on the shelf this week"
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
	for _, prize in TicketBooth.weekShelf(now) do
		if TicketBooth.blocker(save, prize, now) == nil then
			n += 1
		end
	end
	return n
end

-- For the booth window (PlayerState.ticketBooth).
function TicketBooth.view(save: Types.TicketSave, now: number): Types.TicketBoothView
	local function row(prize: Prize): Types.TicketPrizeRow
		local w = prize.weekly
		return {
			id = prize.id,
			name = prize.name,
			line = prize.line,
			price = prize.price,
			left = TicketBooth.left(save, prize, now),
			per = if prize.limit ~= nil then prize.limit.per :: string else nil,
			blocker = TicketBooth.blocker(save, prize, now),
			kind = if w ~= nil then w.kind :: string else nil,
			item = if w ~= nil then w.item else nil,
			owned = if w ~= nil then TicketBooth.owns(save, prize) else nil,
		}
	end
	local rows: { Types.TicketPrizeRow } = {}
	for _, prize in TicketBooth.PRIZES do
		table.insert(rows, row(prize))
	end
	local week: { Types.TicketPrizeRow } = {}
	for _, prize in TicketBooth.weekShelf(now) do
		table.insert(week, row(prize))
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
		week = week,
		ready = TicketBooth.readyCount(save, now),
	}
end

return TicketBooth
