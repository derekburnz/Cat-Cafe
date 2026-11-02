--!strict
-- The night dealer's stock (data-model section 8b). F94 (rewards-and-shops.md section 4, Derek's Set 4 Q9 answer):
-- each server rolls one stock at dusk with its own Random, an amount of 0 to 4 of each dealer food from
-- Catalog.dealerAmountWeights, and it holds the whole night; the next dusk rolls again, so each server's night is
-- its own. Each player may buy up to the amount of each food that night; DealerService keeps the counts in memory and
-- clears them at sunrise. Before F94 the stock rolled every 5 minutes, the same on every server; that roll moved to
-- the Fresh Catch shelf (shared/FreshCatch). Pure.

local Catalog = require(script.Parent.Catalog)
local FreshCatch = require(script.Parent.FreshCatch)

local Dealer = {}

-- The dealer foods in the order they are rolled and shown (section 8b).
Dealer.FOODS = { "sardines", "caviar", "moon_milk", "star_treat" }

-- The amount at `roll` (0 to 1) through `weights` (shared with the Fresh Catch shelf).
Dealer.pickAmount = FreshCatch.pickAmount

export type FoodAmount = { lureId: string, amount: number }

-- One night's stock, one roll of `nextNumber` (0 to 1, the server's Random) per food, in Dealer.FOODS order.
function Dealer.roll(nextNumber: () -> number): { FoodAmount }
	local foods: { FoodAmount } = {}
	for _, lureId in Dealer.FOODS do
		local weights = Catalog.dealerAmountWeights[lureId]
		table.insert(foods, {
			lureId = lureId,
			amount = if weights ~= nil then Dealer.pickAmount(weights, nextNumber()) else 0,
		})
	end
	return foods
end

-- The amount of `lureId` in `stock`; 0 for a food the dealer does not sell.
function Dealer.amountIn(stock: { FoodAmount }, lureId: string): number
	for _, food in stock do
		if food.lureId == lureId then
			return food.amount
		end
	end
	return 0
end

return Dealer
