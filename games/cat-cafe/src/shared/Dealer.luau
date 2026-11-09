--!strict
-- The night dealer's stock (data-model section 8b). F94 (rewards-and-shops.md section 4, Derek's Set 4 Q9 answer):
-- each server rolls one stock at dusk with its own Random, an amount of 0 to 4 of each dealer food from
-- Catalog.dealerAmountWeights, and it holds the whole night; the next dusk rolls again, so each server's night is
-- its own. Each player may buy up to the amount of each food that night; DealerService keeps the counts in memory and
-- clears them at sunrise. Before F94 the stock rolled every 5 minutes, the same on every server; that roll moved to
-- the Fresh Catch shelf (shared/FreshCatch). Pure.

local Catalog = require(script.Parent.Catalog)
local FreshCatch = require(script.Parent.FreshCatch)
local Types = require(script.Parent.Types)

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

export type PlanItem = { lureId: string, count: number }

-- #2573 (riverpopcorn886 via Derek2: "Buy all"): what Buy all takes from `stock` (the DealerStock rows, priced for
-- the player, with their bought counts) with `coins`, and the total cost. Rows go best grade first (the food's
-- `rarity` badge), then in row order; each takes one at a time while it has stock left and the next one fits, and a
-- row that no longer fits is passed for the next (cheaper) one, so what fits is bought, never nothing. Rows of
-- foods not in the Catalog, at no cost or with nothing left are skipped. The server recomputes it from its own stock
-- and coins (DealerService's BuyDealerAll); the confirm card shows the same plan.
function Dealer.planAll(stock: { Types.DealerFood }, coins: number): ({ PlanItem }, number)
	type Entry = { food: Types.DealerFood, rank: number, row: number }
	local order: { Entry } = {}
	for row, food in stock do
		local def = Catalog.getLure(food.lureId)
		if def ~= nil and food.cost > 0 and food.amount - food.bought > 0 then
			table.insert(
				order,
				{ food = food, rank = Catalog.rarityRank[def.rarity] or 0, row = row }
			)
		end
	end
	table.sort(order, function(a: Entry, b: Entry): boolean
		if a.rank ~= b.rank then
			return a.rank > b.rank
		end
		return a.row < b.row
	end)
	local plan: { PlanItem } = {}
	local total = 0
	local left = math.max(0, coins)
	for _, entry in order do
		local food = entry.food
		local count = math.min(food.amount - food.bought, math.floor(left / food.cost))
		if count > 0 then
			table.insert(plan, { lureId = food.lureId, count = count })
			total += count * food.cost
			left -= count * food.cost
		end
	end
	return plan, total
end

return Dealer
