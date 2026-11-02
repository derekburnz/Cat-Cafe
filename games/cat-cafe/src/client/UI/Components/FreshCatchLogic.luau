--!strict
-- The Fresh Catch shelf's sums (F94, rewards-and-shops.md section 3) for the Golden Fish Market's Fresh Catch tab and
-- the chalkboard on its stall. By day the server sends FreshCatchStock whenever this player's stock changes (a new
-- window, sunrise, a join, every buy) and nil at night:
--   { window, restocksAt (os.time), stock = { { itemId, fish, amount, bought } } }, rows in Catalog.freshCatch order.
-- A row's id is its potion's or crate's id. The amount is the window's, the same on every server; each player may buy
-- up to it.
--   normalize(raw) -> Stock?                 the remote's table with bad rows dropped, nil for nil or junk
--   left(item) -> number                     how many this player can still buy
--   inStock(weights?) -> number?             the share of windows that stock at least one, from
--                                            Config.FreshCatchAmountWeights[itemId] (percent for 0, 1, 2, 3)
--   chanceText(share?) -> string?            "In stock 9 times in 10", "In stock 1 time in 4"
--   countdown(seconds) -> string             "Fresh catch in 3:12"
--   board(stock?, nameOf) -> { BoardLine }   the chalkboard's lines: what the window stocks, with how many
-- Pure, so the cloud spec runner checks it.

local FreshCatchLogic = {}

export type Item = { itemId: string, fish: number, amount: number, bought: number }
export type Stock = { window: number, restocksAt: number, stock: { Item } }
export type BoardLine = { itemId: string, name: string, amount: number, fish: number }

local function whole(value: unknown): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.floor(value)
end

function FreshCatchLogic.normalize(raw: unknown): Stock?
	if type(raw) ~= "table" then
		return nil
	end
	local source = raw :: { [string]: unknown }
	local window = whole(source.window)
	local restocksAt = whole(source.restocksAt)
	local rows = source.stock
	if window == nil or restocksAt == nil or type(rows) ~= "table" then
		return nil
	end
	local stock: { Item } = {}
	for _, entry in rows :: { unknown } do
		if type(entry) == "table" then
			local row = entry :: { [string]: unknown }
			local itemId = row.itemId
			local fish = whole(row.fish)
			local amount = whole(row.amount)
			local bought = whole(row.bought)
			if type(itemId) == "string" and fish ~= nil and amount ~= nil then
				table.insert(stock, {
					itemId = itemId,
					fish = math.max(0, fish),
					amount = math.max(0, amount),
					bought = math.max(0, bought or 0),
				})
			end
		end
	end
	return { window = window, restocksAt = restocksAt, stock = stock }
end

function FreshCatchLogic.left(item: Item): number
	return math.max(0, item.amount - item.bought)
end

function FreshCatchLogic.inStock(weights: { number }?): number?
	if weights == nil or #weights == 0 then
		return nil
	end
	local total = 0
	for _, weight in weights do
		if type(weight) == "number" and weight > 0 then
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	local none = weights[1]
	return 1 - math.max(0, if type(none) == "number" then none else 0) / total
end

-- The nearest "n times in d" a child reads at a glance: tenths, then quarters for the rare ones (25% reads "1 time in
-- 4", 10% "1 time in 10").
function FreshCatchLogic.chanceText(share: number?): string?
	if share == nil then
		return nil
	end
	if share >= 0.995 then
		return "Always in stock"
	elseif share <= 0 then
		return "Not in stock today"
	end
	local tenths = math.floor(share * 10 + 0.5)
	if math.abs(share - 0.25) < 0.01 then
		return "In stock 1 time in 4"
	elseif share < 0.095 then
		return ("In stock 1 time in %d"):format(math.floor(1 / share + 0.5))
	end
	return ("In stock %d %s in 10"):format(tenths, if tenths == 1 then "time" else "times")
end

function FreshCatchLogic.countdown(seconds: number): string
	local left = math.max(0, math.ceil(seconds))
	return ("Fresh catch in %d:%02d"):format(left // 60, left % 60)
end

function FreshCatchLogic.board(stock: Stock?, nameOf: (itemId: string) -> string): { BoardLine }
	local lines: { BoardLine } = {}
	if stock == nil then
		return lines
	end
	for _, item in stock.stock do
		if item.amount > 0 then
			table.insert(lines, {
				itemId = item.itemId,
				name = nameOf(item.itemId),
				amount = item.amount,
				fish = item.fish,
			})
		end
	end
	return lines
end

return FreshCatchLogic
