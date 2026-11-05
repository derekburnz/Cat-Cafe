--!strict
-- Yard decor at the Yard Sale (#1537, lawn-nursery.md section 7): the only place lawn pieces and path and fence styles
-- are sold. Each global game day (#1437: counted from Config.ClockEpoch, so every server has the same sunrise) rolls
-- Config.YardDecorRows rows, each a different piece or style, seeded only from the day with this module's own salt:
-- the same stock on every server. A row first rolls a rarity by Config.YardDecorRarityWeights, then picks a piece of
-- that rarity; a rarity with nothing left moves the roll one rarity down (and up from Common when Common is used
-- up). Both draws are made for every row, so one row's result never moves another's. Prices are the pieces' own
-- fixed coin prices; tier gates stay. Each player buys each row once a day (the save's `yardDecor`, version 35).
-- Pure: LawnService checks the reach, takes the coins and gives the piece; CampExtrasState shows the same rows.

local Catalog = require(script.Parent.Catalog)
local Clock = require(script.Parent.Clock)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type Profile = Types.PlayerProfile

local YardSale = {}

local MODULUS = 2147483647 -- 2^31 - 1, the Park-Miller generator, as CornerShop and FreshCatch
local MULTIPLIER = 48271
local SALT = 1000003 * 13 + 0x79617264 -- "yard": keeps this roll apart from the other shops'

-- Lowest first: the order a roll moves down (and, past Common, up) when a rarity has no piece left.
YardSale.RARITIES = table.freeze({
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythical",
	"Golden",
}) :: { Types.LawnRarity }

YardSale.Messages = table.freeze({
	notToday = "That isn't at the Yard Sale today",
	boughtToday = "You bought that today. New stock at sunrise.",
	newStock = "New stock is on its way",
})

-- Every piece and style the Yard Sale can roll, by rarity, in Catalog order (pieces, then styles). The free Grey
-- Slabs (no rarity) is never sold.
local pool: { [string]: { string } } = {}
for _, rarity in YardSale.RARITIES do
	pool[rarity] = {}
end
for _, def in Catalog.lawn do
	table.insert(pool[def.rarity], def.id)
end
for _, def in Catalog.lawnStyles do
	if def.rarity ~= nil and def.price > 0 then
		table.insert(pool[def.rarity], def.id)
	end
end

-- The ids of `rarity` the Yard Sale can roll (a copy).
function YardSale.poolOf(rarity: Types.LawnRarity): { string }
	return table.clone(pool[rarity] or {})
end

-- The global game day at server time `now` (os.time()): the same number on every server, the day that just ended
-- at night, so the stock turns at sunrise.
function YardSale.dayAt(now: number): number
	return Clock.dayAt(now - Config.ClockEpoch)
end

-- When the stock after `day` arrives: the next sunrise, in os.time().
function YardSale.restocksAt(day: number): number
	return Config.ClockEpoch + Clock.sunriseOf(math.floor(day) + 1)
end

-- The day's seed, the same on every server.
function YardSale.seed(day: number): number
	local hash = (SALT + math.floor(day) % MODULUS) % MODULUS
	for _ = 1, 3 do
		hash = (hash * MULTIPLIER) % MODULUS
		hash = bit32.bxor(hash, bit32.rshift(hash, 13))
	end
	hash %= MODULUS
	return if hash == 0 then 1 else hash
end

local function nextState(state: number): number
	return (state * MULTIPLIER) % MODULUS
end

-- The rarity a draw in [0, 1) lands on by Config.YardDecorRarityWeights.
function YardSale.pickRarity(draw: number): Types.LawnRarity
	local weights: { [string]: number } = Config.YardDecorRarityWeights :: any
	local total = 0
	for _, rarity in YardSale.RARITIES do
		total += math.max(0, weights[rarity] or 0)
	end
	local point = draw * total
	for _, rarity in YardSale.RARITIES do
		local weight = math.max(0, weights[rarity] or 0)
		if point < weight then
			return rarity
		end
		point -= weight
	end
	return YardSale.RARITIES[1]
end

-- Where `rarity` sits in RARITIES.
local function rankOf(rarity: Types.LawnRarity): number
	return table.find(YardSale.RARITIES, rarity) or 1
end

-- The rarity at or below `rarity` with a piece left in `left`, else the nearest above it, else nil.
local function withPieces(
	left: { [string]: { string } },
	rarity: Types.LawnRarity
): Types.LawnRarity?
	local rank = rankOf(rarity)
	for at = rank, 1, -1 do
		local candidate = YardSale.RARITIES[at]
		if #left[candidate] > 0 then
			return candidate
		end
	end
	for at = rank + 1, #YardSale.RARITIES do
		local candidate = YardSale.RARITIES[at]
		if #left[candidate] > 0 then
			return candidate
		end
	end
	return nil
end

-- The ids on sale on `day`, in roll order: Config.YardDecorRows of them (fewer only if the pool runs out), no id
-- twice. Cached for the last day asked, since every view and buy asks for the same day.
local cachedDay: number? = nil
local cachedStock: { string } = {}
function YardSale.stock(day: number): { string }
	day = math.floor(day)
	if cachedDay == day then
		return table.clone(cachedStock)
	end
	local left: { [string]: { string } } = {}
	for _, rarity in YardSale.RARITIES do
		left[rarity] = table.clone(pool[rarity])
	end
	local state = YardSale.seed(day)
	local rows: { string } = {}
	for _ = 1, Config.YardDecorRows do
		state = nextState(state)
		local rolled = YardSale.pickRarity(state / MODULUS)
		state = nextState(state)
		local pickDraw = state / MODULUS
		local rarity = withPieces(left, rolled)
		if rarity == nil then
			break
		end
		local ids = left[rarity]
		local at = math.floor(pickDraw * #ids) + 1
		table.insert(rows, table.remove(ids, math.min(at, #ids)) :: string)
	end
	cachedDay, cachedStock = day, rows
	return table.clone(rows)
end

-- True when `id` is on sale on `day`.
function YardSale.inStock(day: number, id: string): boolean
	return table.find(YardSale.stock(day), id) ~= nil
end

-- A new player's state.
function YardSale.fresh(): Types.YardDecorState
	return { day = 0, bought = {} }
end

-- Clears the bought rows once the day has moved on (never on a step back: two servers' clocks can differ by a second
-- at sunrise, reviewer N32).
function YardSale.refresh(state: Types.YardDecorState, day: number)
	if day > state.day then
		state.day = day
		state.bought = {}
	end
end

-- True while this server's day is behind the one the saved rows belong to: every row counts as bought.
function YardSale.behind(state: Types.YardDecorState, day: number): boolean
	return day < state.day
end

-- The def's name, price, tier and rarity for a piece or style id, or nil.
local function defOf(id: string): (string?, number, number, Types.LawnRarity?)
	local piece = Catalog.getLawn(id)
	if piece ~= nil then
		return piece.name, piece.price, piece.tier, piece.rarity
	end
	local style = Catalog.getLawnStyle(id)
	if style ~= nil then
		return style.name, style.price, style.tier, style.rarity
	end
	return nil, 0, 0, nil
end

-- What a row costs (its fixed coin price), 0 for an unknown id.
function YardSale.priceOf(id: string): number
	local _, price = defOf(id)
	return price
end

-- Why `profile` can't buy `id` on `day`, or nil. The day's state is refreshed first by the caller. `lawnBlocker` is
-- Lawn.buyBlocker's answer (owned, tier), checked after the Yard Sale's own rules.
function YardSale.buyBlocker(
	state: Types.YardDecorState,
	day: number,
	id: string,
	lawnBlocker: string?
): string?
	if YardSale.behind(state, day) then
		return YardSale.Messages.newStock
	end
	if not YardSale.inStock(day, id) then
		return YardSale.Messages.notToday
	end
	if state.bought[id] == true then
		return YardSale.Messages.boughtToday
	end
	return lawnBlocker
end

-- The day's rows as CampExtrasState shows them: each id, name, rarity, price, the tier that opens it, and whether this
-- player bought it today or owns it already.
function YardSale.view(
	profile: Profile,
	state: Types.YardDecorState,
	day: number
): { Types.YardDecorRow }
	local rows: { Types.YardDecorRow } = {}
	local behind = YardSale.behind(state, day)
	for _, id in YardSale.stock(day) do
		local name, price, tier, rarity = defOf(id)
		local row: Types.YardDecorRow = {
			id = id,
			name = name or id,
			rarity = rarity or "Common" :: Types.LawnRarity,
			price = price,
			tier = tier,
			bought = behind or state.bought[id] == true,
			owned = profile.lawnOwned[id] == true,
		}
		table.insert(rows, row)
	end
	return rows
end

-- A saved `yardDecor` made safe: a whole day, and only ids that are lawn pieces or styles, marked true.
function YardSale.sanitize(raw: unknown): Types.YardDecorState
	local state = YardSale.fresh()
	if type(raw) ~= "table" then
		return state
	end
	local value = raw :: { [any]: any }
	local day = value.day
	if type(day) == "number" and day == day and day >= 0 and day < 2 ^ 40 then
		state.day = math.floor(day)
	end
	if type(value.bought) == "table" then
		local count = 0
		for id, bought in value.bought do
			if type(id) == "string" and bought == true and defOf(id) ~= nil and count < 64 then
				state.bought[id] = true
				count += 1
			end
		end
	end
	return state
end

return YardSale
