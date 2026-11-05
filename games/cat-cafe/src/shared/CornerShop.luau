--!strict
-- The Corner Shop (corner-shop.md, #1052; v2 corner-shop-v2.md, #1180 and #1181): a coins-only stall in the Town
-- Square, open day and night. Every CornerShopWindowSeconds window rolls an amount of each Catalog.cornerShop row from
-- its size's Config.CornerShopSizeWeights, seeded only from the global window with the salt "corner", so every server
-- shows the same stock and it differs from the Fresh Catch's roll in the same window. The amount is per player: each
-- player may buy up to it of each row in the window. Prices are fixed (the row's `price`). A UTC day allows at most
-- Config.CornerDailyLimits of a family, any size (cat food has no daily XP cap since #1255; foodXpToday still counts
-- it); a row's `needsTier` refuses it below that tier. #1281 (section 1b): the "bait" rows sell the bowl foods at
-- Economy.foodPrice for the buyer's tier (priceOf), from their own stock weights, up to LURE_MAX of each food held.
-- Pure: the server's CornerShopService checks the range, takes the coins and gives the item; the window shows the
-- same numbers.

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

-- #1281: a bait food can't be bought past this many held (section 1b's LureMax). A stack already above it (from
-- prizes) stays; it just can't grow by buying.
CornerShop.LURE_MAX = 99

-- A row's stock chances (0, 1, 2 or 3): its own `weights` (the bait rows), else its size's.
local function weightsOf(row: Types.CornerShopRow): { number }?
	return row.weights or Config.CornerShopSizeWeights[row.size]
end

-- What a row costs a player at `tier`: the bait rows' food price grows with the tier (Economy.foodPrice, F97), every
-- other row's price is fixed.
function CornerShop.priceOf(row: Types.CornerShopRow, tier: number): number
	if row.kind == "bait" and row.lureId ~= nil then
		return Economy.foodPrice(row.lureId, tier)
	end
	return row.price
end

-- The global stock window at server time `now` (os.time()). #1437: counted from Config.ClockEpoch, so with a window of
-- one game day it turns at every sunrise of the global clock.
function CornerShop.window(now: number): number
	return math.floor((now - Config.ClockEpoch) / Config.CornerShopWindowSeconds)
end

-- When the stock after `window` arrives, in os.time().
function CornerShop.restocksAt(window: number): number
	return Config.ClockEpoch + (window + 1) * Config.CornerShopWindowSeconds
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
		local weights = weightsOf(row)
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
	return { window = 0, bought = {}, day = 0, today = {}, foodXpToday = 0 }
end

-- Clears the bought counts once the window has moved on (never on a step back: two servers' clocks can differ by a
-- second at a window edge, reviewer N32), and the day's counts once the UTC day has.
function CornerShop.refresh(state: Types.CornerShopState, window: number, day: number)
	if window > state.window then
		state.window = window
		state.bought = {}
	end
	if day > state.day then
		state.day = day
		state.today = {}
		state.foodXpToday = 0
	end
end

-- True while this server's window is behind the one the saved counts belong to: every row counts as bought out.
function CornerShop.behind(state: Types.CornerShopState, window: number): boolean
	return window < state.window
end

-- What the limit toast calls each limited family (corner-shop-v2.md section 1, #1190).
CornerShop.FAMILY_NAMES = table.freeze({
	steady = "Steady Paw",
	quick_bait = "Quick Bait",
	whistle = "Cat Whistles",
}) :: { [string]: string }

-- A family's daily limit, or nil for none (the Swift Potion, and food, which counts XP instead).
function CornerShop.perDay(family: string): number?
	return Config.CornerDailyLimits[family]
end

-- What CornerShopStock sends for a refreshed state, with each row's price for a player at `tier` (nil is Tier 1).
function CornerShop.view(
	state: Types.CornerShopState,
	window: number,
	tier: number?
): Types.CornerShopStock
	local stock: { Types.CornerShopItem } = {}
	for _, item in CornerShop.stock(window) do
		local row = Catalog.getCornerShopRow(item.itemId) :: Types.CornerShopRow
		-- #1435: the row's family is at its daily limit, so the window greys Buy ("Back tomorrow") instead of
		-- letting every press come back with the toast. The limit itself is still never shown (#1190).
		local limit = CornerShop.perDay(row.family)
		local outToday = limit ~= nil and (state.today[row.family] or 0) >= limit
		table.insert(stock, {
			itemId = item.itemId,
			price = CornerShop.priceOf(row, tier or 1),
			amount = item.amount,
			bought = state.bought[item.itemId] or 0,
			size = row.size,
			needsTier = row.needsTier,
			outToday = if outToday then true else nil,
		})
	end
	return {
		window = window,
		restocksAt = CornerShop.restocksAt(window),
		stock = stock,
		snackXp = state.foodXpToday,
	}
end

-- What a buy is checked against besides the state: the server's window and the player's tier, coins and Bag count of
-- the row's food. #1281: for a bait row, how many of its food the player holds (`lureHeld`) and the price the window
-- showed (`shownPrice`, nil from a window that sends none).
export type Buy = {
	itemId: string,
	seenWindow: number,
	tier: number,
	coins: number,
	foodHeld: number,
	lureHeld: number?,
	shownPrice: number?,
}

-- Why a buy would be refused for a refreshed state at the server's `window`, or nil (QA checks 3 and 4). The server
-- checks the range itself.
function CornerShop.buyBlocker(state: Types.CornerShopState, buy: Buy, window: number): string?
	local row = Catalog.getCornerShopRow(buy.itemId)
	if row == nil then
		return "That isn't in the Corner Shop."
	end
	if row.needsTier ~= nil and buy.tier < row.needsTier then
		return string.format("Opens at Tier %d", row.needsTier)
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
	local limit = CornerShop.perDay(row.family)
	local today = state.today[row.family] or 0
	if limit ~= nil and today >= limit then
		-- #1190: the limits are never shown on a row, only as this toast when a buy hits one
		return string.format(
			"That's all the %s for today, back tomorrow!",
			CornerShop.FAMILY_NAMES[row.family] or row.name
		)
	end
	if row.kind == "food" then
		if buy.foodHeld >= Config.CatFoodMax then
			return "Your Bag is full of that food"
		end
	end
	local price = CornerShop.priceOf(row, buy.tier)
	if row.kind == "bait" then
		if (buy.lureHeld or 0) >= CornerShop.LURE_MAX then
			return string.format("You have all the %s you can carry", row.name)
		end
		-- the price grew since the window showed it (a rank up while it was open): the refusal sends the new one
		if buy.shownPrice ~= nil and price > buy.shownPrice then
			return "The price changed. Take another look."
		end
	end
	if buy.coins < price then
		return "Not enough coins"
	end
	return nil
end

-- Marks a passed buy of `itemId` on the state: the window's count, the family's count today and, for food, its XP.
function CornerShop.record(state: Types.CornerShopState, itemId: string)
	local row = Catalog.getCornerShopRow(itemId) :: Types.CornerShopRow
	state.bought[itemId] = (state.bought[itemId] or 0) + 1
	state.today[row.family] = (state.today[row.family] or 0) + 1
	if row.kind == "food" then
		state.foodXpToday += row.xp or 0
	end
end

-- A saved state made whole at os.time() `now`: whole numbers, the window no later than the next one, the day no
-- later than today, each family's count within its limit (a family with no limit within the most a day's windows
-- could sell), the food XP within the cap, and a count per row of at most the largest amount a window rolls. A v1
-- save (snackDay, snackXp) starts the day afresh.
function CornerShop.sanitize(raw: unknown, now: number): Types.CornerShopState
	local state = CornerShop.fresh()
	if type(raw) ~= "table" then
		return state
	end
	local value = raw :: any
	local function whole(x: unknown): number
		return if type(x) == "number" and x == x and math.abs(x) < 2 ^ 40 then math.floor(x) else 0
	end
	-- #1437: a window past the next one is from the old 5 minute count; its window and buys start afresh (the day's
	-- family counts below are by UTC day and stay)
	local latest = math.max(0, CornerShop.window(now) + 1)
	local oldCount = whole(value.window) > latest
	state.window = if oldCount then 0 else math.clamp(whole(value.window), 0, latest)
	state.day = math.clamp(whole(value.day), 0, CornerShop.day(now))
	state.foodXpToday = math.clamp(whole(value.foodXpToday), 0, 2 ^ 31)
	local families: { [string]: boolean } = {}
	if type(value.bought) == "table" and not oldCount then
		for _, row in Catalog.cornerShop do
			families[row.family] = true
			local weights: { number } = weightsOf(row) or {}
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
	else
		for _, row in Catalog.cornerShop do
			families[row.family] = true
		end
	end
	if type(value.today) == "table" then
		local dayMost = math.ceil(86400 / Config.CornerShopWindowSeconds) * 3 * #Catalog.cornerShop
		for family in families do
			local count =
				math.clamp(whole(value.today[family]), 0, CornerShop.perDay(family) or dayMost)
			if count > 0 then
				state.today[family] = count
			end
		end
	end
	return state
end

return CornerShop
