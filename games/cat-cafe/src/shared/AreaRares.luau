--!strict
-- #4227 (Derek 2026-11-14, from a player's suggestion): how many wild Mythical and Secret strays are out in each area
-- now, for the bubbles on the Cannon picker's area cards and the HUD Cannon button. The server keeps it in one
-- ReplicatedStorage attribute (ATTRIBUTE), JSON { [areaId] = { m = mythicals, s = secrets } }, written when a wild
-- stray spawns or goes (CatService). Only live wild strays count: no dropped cat, tutorial stray, bait or rescue cat.
-- An area with none is left out. Pure, so the specs load it.
--   count(strays) -> Counts           from { area, rarity, wild } rows
--   decode(value) -> Counts           the attribute's value read back safely (anything odd reads as nothing)
--   totals(counts, open) -> (m, s)    the sums over the areas in `open` (the HUD button's bubbles)
local AreaRares = {}

AreaRares.ATTRIBUTE = "AreaRares"

export type Count = { m: number, s: number }
export type Counts = { [string]: Count }
export type Row = { area: string, rarity: string, wild: boolean }

function AreaRares.count(rows: { Row }): Counts
	local out: Counts = {}
	for _, row in rows do
		if row.wild and (row.rarity == "Mythical" or row.rarity == "Secret") then
			local entry = out[row.area]
			if entry == nil then
				entry = { m = 0, s = 0 }
				out[row.area] = entry
			end
			if row.rarity == "Mythical" then
				entry.m += 1
			else
				entry.s += 1
			end
		end
	end
	return out
end

local function whole(value: unknown): number
	if type(value) ~= "number" or value ~= value or value < 0 then
		return 0
	end
	return math.min(math.floor(value), 999)
end

-- `decodeJson` is HttpService.JSONDecode (passed in so this stays pure); a bad or missing value reads as nothing
function AreaRares.decode(value: unknown, decodeJson: (string) -> unknown): Counts
	local out: Counts = {}
	if type(value) ~= "string" or value == "" then
		return out
	end
	local ok, parsed = pcall(decodeJson, value)
	if not ok or type(parsed) ~= "table" then
		return out
	end
	for area, entry in parsed :: { [unknown]: unknown } do
		if type(area) == "string" and type(entry) == "table" then
			local m = whole((entry :: any).m)
			local s = whole((entry :: any).s)
			if m > 0 or s > 0 then
				out[area] = { m = m, s = s }
			end
		end
	end
	return out
end

function AreaRares.totals(counts: Counts, open: { [string]: boolean }): (number, number)
	local m, s = 0, 0
	for area, entry in counts do
		if open[area] then
			m += entry.m
			s += entry.s
		end
	end
	return m, s
end

return AreaRares
