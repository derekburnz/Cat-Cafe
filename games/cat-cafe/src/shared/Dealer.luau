--!strict
-- The night dealer's stock (data-model section 8b). v0.8 F59 (round 3 Q5): every window rolls an amount of 0 to 4
-- of each dealer food from Catalog.dealerAmountWeights, in the order of Dealer.FOODS. The roll is seeded only from
-- the global dealer window, so every player on every server sees the same amounts and a rejoin or a server hop
-- cannot reroll; it uses its own generator so every server and the specs agree. The amount is per player: each
-- player may buy up to it of each food in the window, and one player's buys never lower another's.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local Dealer = {}

-- The dealer foods in the order they are rolled and shown (section 8b).
Dealer.FOODS = { "sardines", "caviar", "moon_milk", "star_treat" }

local MODULUS = 2147483647 -- 2^31 - 1, the Park-Miller generator
local MULTIPLIER = 48271

-- The global stock window at server time `now` (os.time()).
function Dealer.window(now: number): number
	return math.floor(now / Config.DealerWindowSeconds)
end

-- When the stock after `window` arrives, in os.time().
function Dealer.restocksAt(window: number): number
	return (window + 1) * Config.DealerWindowSeconds
end

-- The window's seed, the same on every server. Every product stays under 2^53, so it is exact. Each round folds the
-- high bits into the low ones after the multiply: a multiply alone is linear in the window, so each food's roll would
-- only step on by a fixed amount from one window to the next and its amounts would cycle (QA, F59: Moon Milk out of
-- stock 19 windows running). With the fold neighbouring windows roll afresh.
function Dealer.seed(window: number): number
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
function Dealer.pickAmount(weights: { number }, roll: number): number
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

export type FoodAmount = { lureId: string, amount: number }

-- What everyone may buy of each dealer food in `window`, in Dealer.FOODS order.
function Dealer.stock(window: number): { FoodAmount }
	local state = Dealer.seed(window)
	local foods: { FoodAmount } = {}
	for _, lureId in Dealer.FOODS do
		state = (state * MULTIPLIER) % MODULUS
		local weights = Catalog.dealerAmountWeights[lureId]
		table.insert(foods, {
			lureId = lureId,
			amount = if weights ~= nil then Dealer.pickAmount(weights, state / MODULUS) else 0,
		})
	end
	return foods
end

-- The amount of `lureId` in `window`; 0 for a food the dealer does not sell.
function Dealer.amountOf(window: number, lureId: string): number
	for _, food in Dealer.stock(window) do
		if food.lureId == lureId then
			return food.amount
		end
	end
	return 0
end

-- True while this server's window is behind the one the saved marks belong to (a hop to a server whose clock
-- is a second behind at a window edge). Every food then counts as bought out until the window catches up, so a
-- food bought in the newer window cannot be bought again from the older one (reviewer N32).
function Dealer.behind(state: Types.DealerState, window: number): boolean
	return window < state.window
end

-- Clears the bought marks once the window has moved on. Never on a step back, because two servers' clocks can
-- differ by a second at a window edge (reviewer N32).
function Dealer.refresh(state: Types.DealerState, window: number)
	if window > state.window then
		state.window = window
		state.bought = {}
	end
end

return Dealer
