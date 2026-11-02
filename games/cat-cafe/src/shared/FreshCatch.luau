--!strict
-- The Fresh Catch shelf at the Golden Fish Market (F94, rewards-and-shops.md section 3): by day it sells potions, and
-- now and then a cheaper Classic Crate, for golden fish, with a stock that rolls every FreshCatchWindowSeconds. The
-- roll is the one the night dealer used before F94 (data-model 8b v0.8 F59), moved here: every window rolls an amount
-- of each Catalog.freshCatch row from Config.FreshCatchAmountWeights, seeded only from the global window, so every
-- server shows the same stock and a server hop or a rejoin cannot reroll it. It uses its own generator so every
-- server and the specs agree. The amount is per player: each player may buy up to it of each row in the window, and
-- one player's buys never lower another's. Pure.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local FreshCatch = {}

local MODULUS = 2147483647 -- 2^31 - 1, the Park-Miller generator
local MULTIPLIER = 48271

-- The global stock window at server time `now` (os.time()).
function FreshCatch.window(now: number): number
	return math.floor(now / Config.FreshCatchWindowSeconds)
end

-- When the stock after `window` arrives, in os.time().
function FreshCatch.restocksAt(window: number): number
	return (window + 1) * Config.FreshCatchWindowSeconds
end

-- The window's seed, the same on every server. Every product stays under 2^53, so it is exact. Each round folds the
-- high bits into the low ones after the multiply: a multiply alone is linear in the window, so each row's roll would
-- only step on by a fixed amount from one window to the next and its amounts would cycle (QA, F59: Moon Milk out of
-- stock 19 windows running). With the fold neighbouring windows roll afresh.
function FreshCatch.seed(window: number): number
	local hash = (7 * 1000003 + math.floor(window) % MODULUS) % MODULUS
	for _ = 1, 3 do
		hash = (hash * MULTIPLIER) % MODULUS
		hash = bit32.bxor(hash, bit32.rshift(hash, 13))
	end
	hash %= MODULUS
	return if hash == 0 then 1 else hash
end

-- The amount at `roll` (0 to 1) through `weights`, the chance of 0, 1, 2 and so on in order. Zero weights never
-- come up.
function FreshCatch.pickAmount(weights: { number }, roll: number): number
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local target = math.clamp(roll, 0, 1) * total
	local last = 0
	for index, weight in weights do
		if weight > 0 then
			last = index - 1
			if target < weight then
				return index - 1
			end
			target -= weight
		end
	end
	return last
end

export type ItemAmount = { itemId: string, amount: number }

-- What everyone may buy of each row in `window`, in Catalog.freshCatch order.
function FreshCatch.stock(window: number): { ItemAmount }
	local state = FreshCatch.seed(window)
	local items: { ItemAmount } = {}
	for _, row in Catalog.freshCatch do
		state = (state * MULTIPLIER) % MODULUS
		local weights = Config.FreshCatchAmountWeights[row.id]
		table.insert(items, {
			itemId = row.id,
			amount = if weights ~= nil then FreshCatch.pickAmount(weights, state / MODULUS) else 0,
		})
	end
	return items
end

-- The amount of `itemId` in `window`; 0 for an item the shelf does not sell.
function FreshCatch.amountOf(window: number, itemId: string): number
	for _, item in FreshCatch.stock(window) do
		if item.itemId == itemId then
			return item.amount
		end
	end
	return 0
end

-- The alert rows (the Gold Rush Potion and the cheap crate) that `window` stocks, in shelf order.
function FreshCatch.alerts(window: number): { Types.FreshCatchRow }
	local out: { Types.FreshCatchRow } = {}
	for _, item in FreshCatch.stock(window) do
		local row = Catalog.getFreshCatchRow(item.itemId)
		if row ~= nil and row.alert == true and item.amount > 0 then
			table.insert(out, row)
		end
	end
	return out
end

-- The alert row a player holding `fish` golden fish hears about in `window` (section 3, "A heads up"): the first
-- alert row in stock they can afford, or nil when there is none or `state` already had this window's alert. At most
-- one a window, whatever they buy or rejoin.
function FreshCatch.alertFor(
	state: Types.FreshCatchState,
	window: number,
	fish: number
): Types.FreshCatchRow?
	if state.alerted >= window then
		return nil
	end
	for _, row in FreshCatch.alerts(window) do
		if fish >= row.fish then
			return row
		end
	end
	return nil
end

-- True while this server's window is behind the one the saved counts belong to (a hop to a server whose clock is a
-- second behind at a window edge). Every row then counts as bought out until the window catches up, so a row bought
-- in the newer window cannot be bought again from the older one (reviewer N32).
function FreshCatch.behind(state: Types.FreshCatchState, window: number): boolean
	return window < state.window
end

-- Clears the bought counts once the window has moved on. Never on a step back, because two servers' clocks can
-- differ by a second at a window edge (reviewer N32).
function FreshCatch.refresh(state: Types.FreshCatchState, window: number)
	if window > state.window then
		state.window = window
		state.bought = {}
	end
end

-- A new player's state.
function FreshCatch.fresh(): Types.FreshCatchState
	return { window = 0, bought = {}, alerted = 0 }
end

-- The most of a row any window can stock: the last amount with a weight above 0.
local function most(itemId: string): number
	local weights = Config.FreshCatchAmountWeights[itemId]
	if weights == nil then
		return 0
	end
	local top = 0
	for index, weight in weights do
		if weight > 0 then
			top = index - 1
		end
	end
	return top
end

-- A saved state made whole: whole numbers, and a count per shelf row of at most the largest amount a window rolls.
function FreshCatch.sanitize(raw: unknown): Types.FreshCatchState
	local state = FreshCatch.fresh()
	if type(raw) ~= "table" then
		return state
	end
	local value = raw :: any
	local function whole(x: unknown): number
		return if type(x) == "number" and x == x and math.abs(x) < 2 ^ 40 then math.floor(x) else 0
	end
	state.window = math.max(0, whole(value.window))
	state.alerted = math.max(0, whole(value.alerted))
	if type(value.bought) == "table" then
		for _, row in Catalog.freshCatch do
			local count = math.clamp(whole(value.bought[row.id]), 0, most(row.id))
			if count > 0 then
				state.bought[row.id] = count
			end
		end
	end
	return state
end

return FreshCatch
