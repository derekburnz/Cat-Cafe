--!strict
-- #3609 / #3614 (camp-stations.md section 3a), behind the `yardSaleRoll` switch (YardPick.FLAG): the Yard Sale's free
-- lucky pick. Every Config.YardSaleRollHours a player may take one pick; it always wins a crate and is never paid
-- for in any way. Config.YardSaleTable gives the four groups' chances: the Classic Crate, a crate of one of the
-- player's open areas (the group's chance split evenly), the Golden Classic Crate and a golden crate of one of the
-- player's open areas (split evenly). Only open areas, so every crate won can be opened. A group with no crate for
-- this player gives its chance to the Classic Crate, so the rows always add to 1.
-- Pure. `rows(tier)` is both what the server rolls and what the board shows, so the chances shown are the chances
-- rolled. CampExtraService rolls and banks the crate in one call.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)

local YardPick = {}

YardPick.FLAG = "yardSaleRoll" -- LiveFlags, off by default
YardPick.CLASSIC = "classic_crate"
YardPick.GOLDEN_CLASSIC = "classic_golden_crate"

-- One row of the board: the crate, its chance (0 to 1), whether it is golden, and how big its landing effect is
-- (1 a normal crate, 3 a golden one: the Rummage Bin roll's tiers).
export type Row = { crateId: string, chance: number, golden: boolean, tier: number }

-- The crates of the areas open at `tier`, in Catalog order: plain ones, then golden ones.
local function areaCrates(tier: number): ({ string }, { string })
	local plain: { string } = {}
	local golden: { string } = {}
	for _, area in Catalog.areas do
		if area.tier <= tier then
			local plainId = area.id .. "_crate"
			local goldenId = area.id .. "_golden_crate"
			if Catalog.getCrate(plainId) ~= nil then
				table.insert(plain, plainId)
			end
			if Catalog.getCrate(goldenId) ~= nil then
				table.insert(golden, goldenId)
			end
		end
	end
	return plain, golden
end

-- The rows for a player of `tier`, in the board's order: Classic, the open areas' crates, Golden Classic, the open
-- areas' golden crates. Chances add to 1.
function YardPick.rows(tier: number): { Row }
	local table_ = Config.YardSaleTable
	local plain, golden = areaCrates(tier)
	local classic = table_.classic
	local goldenClassic = table_.goldenClassic
	if #plain == 0 then
		classic += table_.area
	end
	if Catalog.getCrate(YardPick.GOLDEN_CLASSIC) == nil then
		classic += goldenClassic
		goldenClassic = 0
	end
	if #golden == 0 then
		classic += table_.goldenArea
	end
	local rows: { Row } = {}
	table.insert(rows, { crateId = YardPick.CLASSIC, chance = classic, golden = false, tier = 1 })
	for _, crateId in plain do
		table.insert(
			rows,
			{ crateId = crateId, chance = table_.area / #plain, golden = false, tier = 1 }
		)
	end
	if goldenClassic > 0 then
		table.insert(
			rows,
			{ crateId = YardPick.GOLDEN_CLASSIC, chance = goldenClassic, golden = true, tier = 3 }
		)
	end
	for _, crateId in golden do
		table.insert(
			rows,
			{ crateId = crateId, chance = table_.goldenArea / #golden, golden = true, tier = 3 }
		)
	end
	return rows
end

-- The row a draw in [0, 1) lands on (its index in `rows`). A draw past the end (rounding) lands on the first row.
function YardPick.pick(rows: { Row }, draw: number): number
	local point = math.clamp(draw, 0, 1)
	for index, row in rows do
		if point < row.chance then
			return index
		end
		point -= row.chance
	end
	return 1
end

-- The wait between two takes, in hours: the pick's while the switch is on, else the free crate's.
function YardPick.hours(on: boolean): number
	return if on then Config.YardSaleRollHours else Config.YardSaleClaimHours
end

return YardPick
