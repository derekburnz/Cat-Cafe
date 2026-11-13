--!strict
-- The Corner Shop (corner-shop.md, #1052; v2 corner-shop-v2.md, #1180 and #1181): a coins-only stall in the Town
-- Square, open day and night; since #1577 it stands on the Day Cart (day-cart.md). Every CornerShopWindowSeconds window
-- (one game day) rolls each Catalog.cornerShop row's stock by its place in the list by Tier 1 price (stock), seeded
-- only from the global window with the salt "corner", so every server shows the same stock and it differs from the
-- Fresh Catch's roll in the same window. The amount is per player: each
-- player may buy up to it of each row in the window. Prices are fixed (the row's `price`). A UTC day allows at most
-- Config.CornerDailyLimits of a family's row, each row on its own (#1712; per game day since #1629) (cat food has no daily XP cap since #1255; foodXpToday still counts
-- it); a row's `needsTier` refuses it below that tier. #1281 (section 1b): the "bait" rows sell the bowl foods at
-- Economy.foodPrice for the buyer's tier (priceOf), up to LURE_MAX of each food held.
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

-- The most of a row a window can stock (day-cart.md section 2: 1, 2 or 3).
CornerShop.MOST = #Config.DayCartQtyOdds

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

-- #3462: the top shelf, the rows marked `topShelf` (the Tier 6 baits and potions). It is shut until the server opens
-- it from the `cartTier6` switch (CornerShopService): a save drops a food or potion id an older server build does not
-- know, so nothing new is sold while one may still run. Shut, its rows are left out of `view` and refused by
-- `buyBlocker`. Its rows roll after every other row's, so the rest of the cart's stock is the same with or without
-- them, and Buy all never takes them (a press there should not spend billions).
CornerShop.TOP_SHELF_FLAG = "cartTier6"
local topShelfOpen = false
function CornerShop.setTopShelf(open: boolean)
	topShelfOpen = open == true
end
function CornerShop.topShelfOpen(): boolean
	return topShelfOpen
end
local function shut(row: Types.CornerShopRow): boolean
	return row.topShelf == true and not topShelfOpen
end

-- #1577 (day-cart.md section 2): the rows' Catalog.cornerShop indexes, cheapest Tier 1 price first (ties keep the
-- Catalog order), the top shelf's rows after the rest (#3462). Built once; the Catalog is frozen.
local byPrice: { number }? = nil
function CornerShop.listOrder(): { number }
	if byPrice == nil then
		local order: { number } = {}
		for index in Catalog.cornerShop do
			table.insert(order, index)
		end
		table.sort(order, function(a: number, b: number): boolean
			local topA, topB =
				Catalog.cornerShop[a].topShelf == true, Catalog.cornerShop[b].topShelf == true
			if topA ~= topB then
				return topB
			end
			local priceA, priceB = Catalog.cornerShop[a].price, Catalog.cornerShop[b].price
			if priceA ~= priceB then
				return priceA < priceB
			end
			return a < b
		end)
		byPrice = order
	end
	return byPrice :: { number }
end

-- The chance that the row at `place` (from 1) in the list by price is in stock: max(floor, top - step x (place - 1)).
function CornerShop.stockChance(place: number): number
	return math.max(Config.DayCartFloor, Config.DayCartTopChance - Config.DayCartStep * (place - 1))
end

-- What everyone may buy of each row in `window`, in Catalog.cornerShop order. Down the list by price each row rolls
-- whether it's in stock (stockChance), then its amount (1, 2 or 3 by Config.DayCartQtyOdds); both rolls are always
-- drawn, so one row's result never moves another's.
function CornerShop.stock(window: number): { ItemAmount }
	local state = CornerShop.seed(window)
	local amounts: { number } = table.create(#Catalog.cornerShop, 0)
	local odds = { 0 }
	for _, weight in Config.DayCartQtyOdds do
		table.insert(odds, weight)
	end
	for place, index in CornerShop.listOrder() do
		state = (state * MULTIPLIER) % MODULUS
		local inStock = state / MODULUS < CornerShop.stockChance(place)
		state = (state * MULTIPLIER) % MODULUS
		amounts[index] = if inStock then FreshCatch.pickAmount(odds, state / MODULUS) else 0
	end
	local items: { ItemAmount } = {}
	for index, row in Catalog.cornerShop do
		table.insert(items, { itemId = row.id, amount = amounts[index] })
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

-- Clears the bought counts and each row's count toward its family's daily limit once the window (a game day since
-- #1437) has moved on (never on a step back: two servers' clocks can differ by a second at a window edge, reviewer
-- N32), and the food XP once the UTC day has. #1629 (Derek2): the family limits reset at every in-game sunrise, not at 00:00 UTC.
-- #3118 (Monetization-Agent): only the window clears them now, so the daily caps and the stock roll share one
-- in-game day; 00:00 UTC no longer gives a second reset in between.
function CornerShop.refresh(state: Types.CornerShopState, window: number, day: number)
	if window > state.window then
		state.window = window
		state.bought = {}
		state.today = {}
	end
	if day > state.day then
		state.day = day
		state.foodXpToday = 0
	end
end

-- True while this server's window is behind the one the saved counts belong to: every row counts as bought out.
function CornerShop.behind(state: Types.CornerShopState, window: number): boolean
	return window < state.window
end

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
		if shut(row) then
			continue -- #3462: the top shelf's rows come last in the Catalog, so the rows before them keep their places
		end
		-- #1435: the row is at its family's daily limit, so the window greys Buy ("Back at sunrise", #1629) instead of
		-- letting every press come back with the toast. The limit itself is still never shown (#1190). #1712: each row
		-- counts on its own, so buying one size never uses up another.
		local limit = CornerShop.perDay(row.family)
		local outToday = limit ~= nil and (state.today[row.id] or 0) >= limit
		local leftToday = if limit ~= nil
			then math.max(0, limit - (state.today[row.id] or 0))
			else nil
		table.insert(stock, {
			itemId = item.itemId,
			price = CornerShop.priceOf(row, tier or 1),
			amount = item.amount,
			bought = state.bought[item.itemId] or 0,
			size = row.size,
			needsTier = row.needsTier,
			outToday = if outToday then true else nil,
			leftToday = leftToday, -- #2593
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
	if row == nil or shut(row) then
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
	local today = state.today[row.id] or 0
	if limit ~= nil and today >= limit then
		-- #1190: the limits are never shown on a row, only as this toast when a buy hits one; #1712: per row
		return string.format("That's all the %s for today, back at sunrise!", row.name)
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
		return CornerShop.NO_COINS
	end
	return nil
end

-- Marks a passed buy of `itemId` on the state: the window's count, the row's count today (#1712: each row against its
-- family's limit on its own) and, for food, its XP.
function CornerShop.record(state: Types.CornerShopState, itemId: string)
	local row = Catalog.getCornerShopRow(itemId) :: Types.CornerShopRow
	state.bought[itemId] = (state.bought[itemId] or 0) + 1
	state.today[itemId] = (state.today[itemId] or 0) + 1
	if row.kind == "food" then
		state.foodXpToday += row.xp or 0
	end
end

export type PlanItem = { itemId: string, count: number }
export type Held = { catFood: { [string]: number }, lures: { [string]: number } }

-- #2593 (Derek2: a Buy all for each of the Day Cart's sections): what Buy all takes from the `kind` section ("potion",
-- "food" or "bait") of `window`'s stock for a player at `tier` with `coins` and `held` (their Bag's catFood and their
-- lures), and the total. Best first: the dearest row at the player's price first (ties in list order); each takes
-- one at a time for as long as CornerShop.buyBlocker passes it on a copy of `state` (the tier, the window's amount,
-- the family's daily limit, the Bag and LURE_MAX, the coins), so a row that no longer fits is passed for the next,
-- cheaper one. The server recomputes it from its own state (CornerShopService's BuyCornerShopAll) and buys each one
-- through the same check; the confirm card shows the same plan. `state` is not changed.
function CornerShop.planAll(
	state: Types.CornerShopState,
	window: number,
	kind: string,
	tier: number,
	coins: number,
	held: Held
): ({ PlanItem }, number)
	local copy: Types.CornerShopState = {
		window = state.window,
		bought = table.clone(state.bought),
		day = state.day,
		today = table.clone(state.today),
		foodXpToday = state.foodXpToday,
	}
	type Entry = { row: Types.CornerShopRow, price: number, place: number }
	local rows: { Entry } = {}
	for place, item in CornerShop.stock(window) do
		local row = Catalog.getCornerShopRow(item.itemId)
		-- #3462: never a top shelf row, open or shut
		if row ~= nil and row.kind == kind and row.topShelf ~= true then
			table.insert(rows, { row = row, price = CornerShop.priceOf(row, tier), place = place })
		end
	end
	table.sort(rows, function(a: Entry, b: Entry): boolean
		if a.price ~= b.price then
			return a.price > b.price
		end
		return a.place < b.place
	end)
	local foods = table.clone(held.catFood)
	local lures = table.clone(held.lures)
	local left = coins
	local plan: { PlanItem } = {}
	local total = 0
	for _, entry in rows do
		local row = entry.row
		local count = 0
		while entry.price > 0 do
			local blocker = CornerShop.buyBlocker(copy, {
				itemId = row.id,
				seenWindow = window,
				tier = tier,
				coins = left,
				foodHeld = if row.foodId ~= nil then foods[row.foodId] or 0 else 0,
				lureHeld = if row.lureId ~= nil then lures[row.lureId] or 0 else nil,
			}, window)
			if blocker ~= nil then
				break
			end
			CornerShop.record(copy, row.id)
			left -= entry.price
			total += entry.price
			count += 1
			if row.foodId ~= nil then
				foods[row.foodId] = (foods[row.foodId] or 0) + 1
			end
			if row.lureId ~= nil then
				lures[row.lureId] = (lures[row.lureId] or 0) + 1
			end
		end
		if count > 0 then
			table.insert(plan, { itemId = row.id, count = count })
		end
	end
	return plan, total
end

CornerShop.NO_COINS = "Not enough coins"
CornerShop.NOTHING_LEFT = "Nothing left to buy here right now"

-- #3693: why a Buy all of the `kind` section buys nothing, for the toast (planAll came back empty). "Not enough
-- coins" when that is what stops a row; else the first row's own reason that is not "sold out this time" (the Bag
-- full, the day's limit, a tier); else NOTHING_LEFT. Same arguments as planAll; `state` is not changed.
function CornerShop.whyNone(
	state: Types.CornerShopState,
	window: number,
	kind: string,
	tier: number,
	coins: number,
	held: Held
): string
	local other: string? = nil
	for _, item in CornerShop.stock(window) do
		local row = Catalog.getCornerShopRow(item.itemId)
		if row == nil or row.kind ~= kind or row.topShelf == true then
			continue
		end
		if (state.bought[row.id] or 0) >= CornerShop.amountOf(window, row.id) then
			continue -- sold out this time: nothing to say about it
		end
		local blocker = CornerShop.buyBlocker(state, {
			itemId = row.id,
			seenWindow = window,
			tier = tier,
			coins = coins,
			foodHeld = if row.foodId ~= nil then held.catFood[row.foodId] or 0 else 0,
			lureHeld = if row.lureId ~= nil then held.lures[row.lureId] or 0 else nil,
		}, window)
		if blocker == CornerShop.NO_COINS then
			return CornerShop.NO_COINS
		elseif blocker ~= nil and other == nil then
			other = blocker
		end
	end
	return other or CornerShop.NOTHING_LEFT
end

-- A saved state made whole at os.time() `now`: whole numbers, the window no later than the next one, the day no
-- later than today, each row's count within its family's limit (a family with no limit within the most a day's windows
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
	if type(value.bought) == "table" and not oldCount then
		for _, row in Catalog.cornerShop do
			local count = math.clamp(whole(value.bought[row.id]), 0, CornerShop.MOST)
			if count > 0 then
				state.bought[row.id] = count
			end
		end
	end
	-- #1712: the day's counts are by row; an older save's counts by family start the day afresh
	if type(value.today) == "table" then
		local dayMost = math.ceil(86400 / Config.CornerShopWindowSeconds) * 3
		for _, row in Catalog.cornerShop do
			local count =
				math.clamp(whole(value.today[row.id]), 0, CornerShop.perDay(row.family) or dayMost)
			if count > 0 then
				state.today[row.id] = count
			end
		end
	end
	return state
end

return CornerShop
