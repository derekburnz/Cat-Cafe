--!strict
-- The night dealer's stock as shop rows (data-model section 8b v0.8, F59). Every window the dealer stocks each of
-- the four dealer foods with an amount from 0 to 4, the same on every server, and each player can buy up to that
-- many; one row per food in the server's order, like the Grow a Garden seed shop, "x2 Stock" while some are left,
-- "Sold out" once this player bought them all and "None this time" for an amount of 0.
--   normalize(raw) -> DealerStock?   the DealerStock remote's { window, restocksAt, stock = { { lureId, cost,
--                                    amount, bought } } }, or the pre-F59 { slots = { { lureId, cost, bought } },
--                                    restocksAt } turned into amounts (a food in n slots has amount n), so the
--                                    screen works whichever the controller sends
--   group(stock, lureById) -> rows   foods the catalog does not know are left out
--   amountOdds(weights) -> string?   "Stock odds: 0 (15%) · 1 (25%) · 2 (30%) · 3 (20%) · 4 (10%)"
--   clock(seconds) -> "4:12"
-- Pure, so the cloud test runner checks it.

local Types = require(script.Parent.Parent.Types)

export type Row = {
	lureId: string,
	def: Types.LureDef,
	cost: number, -- the server's price, not the catalog's
	amount: number, -- this window's stock of it, 0 to 4
	bought: number, -- how many of it this player bought this window
	left: number, -- amount less bought, never below 0
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

return DealerRows
