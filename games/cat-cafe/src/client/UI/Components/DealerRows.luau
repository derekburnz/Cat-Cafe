--!strict
-- The night dealer's stock as shop rows (data-model section 8b v0.8, F59). Every window the dealer stocks each of
-- the four dealer foods with an amount from 0 to 4, the same on every server, and each player can buy up to that
-- many; one row per food in rarity order (F97 section 3, Components/FoodOrder), rarest first (#2057, Derek2: "sort night
-- dealer items by highest rarity first"), like the Grow a Garden seed shop, "x2 Stock" while some are left,
-- "Sold out" once this player bought them all and "None this time" for an amount of 0.
--   normalize(raw) -> DealerStock?   the DealerStock remote's { window, restocksAt, stock = { { lureId, cost,
--                                    amount, bought } } }, or the pre-F59 { slots = { { lureId, cost, bought } },
--                                    restocksAt } turned into amounts (a food in n slots has amount n), so the
--                                    screen works whichever the controller sends
--   group(stock, lureById) -> rows   foods the catalog does not know are left out
--   amountOdds(weights) -> string?   "Stock odds: 0 (15%) · 1 (25%) · 2 (30%) · 3 (20%) · 4 (10%)"
--   clock(seconds) -> "4:12"
--   buyAll(stock, lureById, money) -> BuyAll?   #2573 (riverpopcorn886 via Derek2): what Buy all would take, from the
--                                    server's own shared Dealer.planAll (best grade first, what fits), with the words
--                                    of its confirm card; nil when nothing fits
-- Pure, so the cloud test runner checks it.

local FoodOrder = require(script.Parent.FoodOrder)
local Types = require(script.Parent.Parent.Types)

local Dealer =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Dealer"))

export type Row = {
	lureId: string,
	def: Types.LureDef,
	cost: number, -- the server's price, not the catalog's
	amount: number, -- this window's stock of it, 0 to 4
	bought: number, -- how many of it this player bought this window
	left: number, -- amount less bought, never below 0
}

-- #2573: Buy all's plan and its confirm card's words.
export type BuyAll = {
	count: number, -- foods it buys
	of: number, -- foods left on the cart for this player (known ones with a price)
	total: number, -- coins
	after: number, -- coins left after
	list: string, -- "1 Star Treat · 2 Caviar"
	partial: string?, -- "You can afford 6 of 10. The best go first." when it can't take everything
}

local DealerRows = {}

local function count(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge then
		return 0
	end
	return math.max(0, math.floor(value))
end

function DealerRows.normalize(raw: any): Types.DealerStock?
	if type(raw) ~= "table" or type(raw.restocksAt) ~= "number" then
		return nil
	end
	local foods: { Types.DealerFood } = {}
	if type(raw.stock) == "table" then
		for _, entry in raw.stock do
			if
				type(entry) == "table"
				and type(entry.lureId) == "string"
				and type(entry.cost) == "number"
			then
				table.insert(foods, {
					lureId = entry.lureId,
					cost = entry.cost,
					amount = count(entry.amount),
					bought = count(entry.bought),
				})
			end
		end
	elseif type(raw.slots) == "table" then
		local byId: { [string]: Types.DealerFood } = {}
		for _, slot in raw.slots do
			if
				type(slot) ~= "table"
				or type(slot.lureId) ~= "string"
				or type(slot.cost) ~= "number"
			then
				continue
			end
			local food = byId[slot.lureId]
			if food == nil then
				local created: Types.DealerFood =
					{ lureId = slot.lureId, cost = slot.cost, amount = 0, bought = 0 }
				byId[slot.lureId] = created
				table.insert(foods, created)
				food = created
			end
			local current = food :: Types.DealerFood
			current.amount += 1
			if slot.bought == true then
				current.bought += 1
			end
		end
	else
		return nil
	end
	local stock: Types.DealerStock = {
		window = if type(raw.window) == "number" then raw.window else nil,
		restocksAt = raw.restocksAt,
		stock = foods,
	}
	return stock
end

function DealerRows.group(stock: Types.DealerStock, lureById: { [string]: Types.LureDef }): { Row }
	local rows: { Row } = {}
	local foods: { Types.DealerFood } = stock.stock or {}
	for _, food in foods do
		local def = lureById[food.lureId]
		if def == nil then
			continue
		end
		table.insert(rows, {
			lureId = food.lureId,
			def = def,
			cost = food.cost,
			amount = food.amount,
			bought = food.bought,
			left = math.max(0, food.amount - food.bought),
		})
	end
	FoodOrder.sort(rows, function(row: Row): (string, Types.LureDef?)
		return row.lureId, row.def
	end, true)
	return rows
end

-- Catalog.dealerAmountWeights' row for one food: the percent chance of stocking 0, 1, 2, 3 or 4. Amounts with no
-- chance are left out, so a Star Treat reads "Stock odds: 0 (90%) · 1 (10%)".
function DealerRows.amountOdds(weights: { number }?): string?
	if weights == nil or #weights == 0 then
		return nil
	end
	local parts: { string } = {}
	for index, weight in weights do
		if type(weight) == "number" and weight > 0 then
			local share = string.format("%.1f", weight):gsub("%.0$", "")
			table.insert(parts, ("%d (%s%%)"):format(index - 1, share))
		end
	end
	if #parts == 0 then
		return nil
	end
	return "Stock odds: " .. table.concat(parts, " · ")
end

-- "4:12" for a restock countdown; "0:00" once it has passed.
function DealerRows.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(whole // 60, whole % 60)
end

function DealerRows.buyAll(
	stock: Types.DealerStock?,
	lureById: { [string]: Types.LureDef },
	money: number
): BuyAll?
	if stock == nil or type(stock.stock) ~= "table" then
		return nil
	end
	local plan, total = Dealer.planAll(stock.stock :: any, money)
	local units = 0
	local parts: { string } = {}
	for _, item in plan do
		units += item.count
		local def = lureById[item.lureId]
		table.insert(parts, ("%d %s"):format(item.count, if def then def.name else item.lureId))
	end
	if units == 0 then
		return nil
	end
	local of = 0
	for _, food in stock.stock :: { Types.DealerFood } do
		if lureById[food.lureId] ~= nil and (food.cost or 0) > 0 then
			of += math.max(0, count(food.amount) - count(food.bought))
		end
	end
	of = math.max(of, units)
	local after = math.max(0, money - total)
	return {
		count = units,
		of = of,
		total = total,
		after = after,
		list = table.concat(parts, " · "),
		partial = if units < of
			then ("You can afford %d of %d. The best go first."):format(units, of)
			else nil,
	}
end

return DealerRows
