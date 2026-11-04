--!strict
-- The Corner Shop (corner-shop.md, #1052): a coins-only stall in the Town Square, open day and night. Every
-- CornerShopWindowSeconds window rolls an amount of each Catalog.cornerShop row from Config.CornerShopAmountWeights,
-- seeded only from the global window with the salt "corner", so every server shows the same stock and it differs
-- from the Fresh Catch's roll in the same window. The amount is per player: each player may buy up to it of each row
-- in the window. Cat Snacks give at most CornerSnackXpPerDay XP a UTC day across all cats. Pure: the server's
-- CornerShopService checks the range, takes the coins and gives the item; the window shows the same numbers.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Economy = require(script.Parent.Economy)
local FreshCatch = require(script.Parent.FreshCatch)
local Types = require(script.Parent.Types)

local CornerShop = {}

CornerShop.TAG = "CornerShop" -- the stall, CatCafe_Street_CornerShop

local MODULUS = 2147483647 -- 2^31 - 1, the Park-Miller generator, as FreshCatch
local MULTIPLIER = 48271
local SALT = 1000003 * 11 + 0x636F726E -- "corn": keeps this roll apart from the Fresh Catch's (salt 7)
local DAY = 86400

-- The global stock window at server time `now` (os.time()).
function CornerShop.window(now: number): number
	return math.floor(now / Config.CornerShopWindowSeconds)
end

-- When the stock after `window` arrives, in os.time().
function CornerShop.restocksAt(window: number): number
	return (window + 1) * Config.CornerShopWindowSeconds
end

-- The UTC day number of os.time() `now`, which the snack cap counts by.
function CornerShop.day(now: number): number
	return math.floor(now / DAY)
end

-- The window's seed, the same on every server: FreshCatch.seed's fold with this shop's own salt.
function CornerShop.seed(window: number): number
	local hash = (SALT + math.floor(window) % MODULUS) % MODULUS
	for _ = 1, 3 do
		hash = (hash * MULTIPLIER) % MODULUS
		hash = bit32.bxor(hash, bit32.rshift(hash, 13))
	end
	hash %= MODULUS
	return if hash == 0 then 1 else hash
end

export type ItemAmount = { itemId: string, amount: number }

-- What everyone may buy of each row in `window`, in Catalog.cornerShop order.
function CornerShop.stock(window: number): { ItemAmount }
	local state = CornerShop.seed(window)
	local items: { ItemAmount } = {}
	for _, row in Catalog.cornerShop do
		state = (state * MULTIPLIER) % MODULUS
		local weights = Config.CornerShopAmountWeights[row.id]
		table.insert(items, {
			itemId = row.id,
			amount = if weights ~= nil then FreshCatch.pickAmount(weights, state / MODULUS) else 0,
		})
	end
	return items
end

-- The amount of `itemId` in `window`; 0 for an item the shop does not sell.
function CornerShop.amountOf(window: number, itemId: string): number
	for _, item in CornerShop.stock(window) do
		if item.itemId == itemId then
			return item.amount
		end
	end
	return 0
end

-- A new player's state.
function CornerShop.fresh(): Types.CornerShopState
	return { window = 0, bought = {}, snackDay = 0, snackXp = 0 }
end

-- Clears the bought counts once the window has moved on (never on a step back: two servers' clocks can differ by a
-- second at a window edge, reviewer N32), and the snack XP once the UTC day has.
function CornerShop.refresh(state: Types.CornerShopState, window: number, day: number)
	if window > state.window then
		state.window = window
		state.bought = {}
	end
	if day > state.snackDay then
		state.snackDay = day
		state.snackXp = 0
	end
end

-- True while this server's window is behind the one the saved counts belong to: every row counts as bought out.
function CornerShop.behind(state: Types.CornerShopState, window: number): boolean
	return window < state.window
end

-- The snack XP left today for a refreshed state.
function CornerShop.snackRoom(state: Types.CornerShopState): number
	return math.max(0, Config.CornerSnackXpPerDay - state.snackXp)
end

-- What CornerShopStock sends for a refreshed state at `dayRate`.
function CornerShop.view(
	state: Types.CornerShopState,
	window: number,
	dayRate: number
): Types.CornerShopStock
	local stock: { Types.CornerShopItem } = {}
	for _, item in CornerShop.stock(window) do
		local row = Catalog.getCornerShopRow(item.itemId) :: Types.CornerShopRow
		table.insert(stock, {
			itemId = item.itemId,
			price = Economy.cornerPrice(row, dayRate),
			amount = item.amount,
			bought = state.bought[item.itemId] or 0,
		})
	end
	return {
		window = window,
		restocksAt = CornerShop.restocksAt(window),
		stock = stock,
		snackXp = state.snackXp,
	}
end

export type Buy = {
	itemId: string,
	seenWindow: number,
	shownPrice: number,
	ownsCat: boolean, -- a snack's cat is the player's (the server looks it up); true for every other row
}

-- Why a buy would be refused for a refreshed state, or nil, and the price it charges. `window` is the server's,
-- `price` the server's price, `coins` what the player has. The server checks the range itself.
function CornerShop.buyBlocker(
	state: Types.CornerShopState,
	buy: Buy,
	window: number,
	price: number,
	coins: number
): string?
	local row = Catalog.getCornerShopRow(buy.itemId)
	if row == nil then
		return "That isn't in the Corner Shop."
	end
	if CornerShop.behind(state, window) then
		return "The shop is restocking. Try again in a moment."
	end
	if buy.seenWindow ~= window then
		return "The Corner Shop just restocked. Take another look."
	end
	local amount = CornerShop.amountOf(window, buy.itemId)
	if amount <= 0 then
		return "None this time."
	end
	if (state.bought[buy.itemId] or 0) >= amount then
		return if amount == 1
			then "You bought the only one this time."
			else "You bought them all this time."
	end
	if price > buy.shownPrice then
		-- the day rate rose while the window was open: never charge more than the player saw
		return "The price just changed. Take another look."
	end
	if row.kind == "snack" then
		if not buy.ownsCat then
			return "Pick one of your cats for the snack."
		end
		if (row.xp or 0) > CornerShop.snackRoom(state) then
			return "Snacks are full for today"
		end
	end
	if coins < price then
		return "Not enough coins"
	end
	return nil
end

-- A saved state made whole at os.time() `now`: whole numbers, the window no later than the next one, the snack day
-- no later than today, the snack XP within the cap, and a count per row of at most the largest amount a window rolls.
function CornerShop.sanitize(raw: unknown, now: number): Types.CornerShopState
	local state = CornerShop.fresh()
	if type(raw) ~= "table" then
		return state
	end
	local value = raw :: any
	local function whole(x: unknown): number
		return if type(x) == "number" and x == x and math.abs(x) < 2 ^ 40 then math.floor(x) else 0
	end
	state.window = math.clamp(whole(value.window), 0, CornerShop.window(now) + 1)
	state.snackDay = math.clamp(whole(value.snackDay), 0, CornerShop.day(now))
	state.snackXp = math.clamp(whole(value.snackXp), 0, Config.CornerSnackXpPerDay)
	if type(value.bought) == "table" then
		for _, row in Catalog.cornerShop do
			local weights: { number } = Config.CornerShopAmountWeights[row.id] or {}
			local most = 0
			for index, weight in weights do
				if weight > 0 then
					most = index - 1
				end
			end
			local count = math.clamp(whole(value.bought[row.id]), 0, most)
			if count > 0 then
				state.bought[row.id] = count
			end
		end
	end
	return state
end

return CornerShop
