--!strict
-- Turns the dealer's three slots into shop rows (data-model section 8b). Each slot is rolled on its own, so one
-- food can fill two or three slots; like the Grow a Garden seed shop, it shows once with "x2 Stock" and Buy
-- takes the first of its slots not bought yet. Rows keep the order the foods first appear in the stock.
-- Pure, so the cloud test runner checks it.

local Types = require(script.Parent.Parent.Types)

export type Row = {
	lureId: string,
	def: Types.LureDef,
	cost: number, -- the server's price from the slot, not the catalog's
	open: { number }, -- slot numbers (1 to 3) not bought yet, lowest first
	total: number, -- slots holding this food, bought or not
}

local DealerRows = {}

-- Slots whose food is not in the catalog are left out (an old client during a catalog change).
function DealerRows.group(stock: Types.DealerStock, lureById: { [string]: Types.LureDef }): { Row }
	local rows: { Row } = {}
	local byId: { [string]: Row } = {}
	for slot, entry in stock.slots do
		local def = lureById[entry.lureId]
		if def == nil then
			continue
		end
		local row = byId[entry.lureId]
		if row == nil then
			local created: Row = {
				lureId = entry.lureId,
				def = def,
				cost = entry.cost,
				open = {},
				total = 0,
			}
			byId[entry.lureId] = created
			table.insert(rows, created)
			row = created
		end
		local current = row :: Row
		current.total += 1
		if not entry.bought then
			table.insert(current.open, slot)
		end
	end
	return rows
end

-- "4:12" for a restock countdown; "0:00" once it has passed.
function DealerRows.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(whole // 60, whole % 60)
end

return DealerRows
