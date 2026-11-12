--!strict
-- #3614: the Yard Sale's lucky pick table (shared/YardPick).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CampExtras = require(ReplicatedStorage.Shared.CampExtras)
local Catalog = require(ReplicatedStorage.Shared.Catalog)
local Config = require(ReplicatedStorage.Shared.Config)
local YardPick = require(ReplicatedStorage.Shared.YardPick)

return function()
	describe("YardPick (#3614)", function()
		local function total(rows: { YardPick.Row }): number
			local sum = 0
			for _, row in rows do
				sum += row.chance
			end
			return sum
		end

		it("the table's four groups add to 1", function()
			local t = Config.YardSaleTable
			expect(t.classic + t.area + t.goldenClassic + t.goldenArea).to.be.near(1, 1e-9)
		end)

		it("rows add to 1 at every tier, and every crate is real", function()
			for tier = 0, 12 do
				local rows = YardPick.rows(tier)
				expect(total(rows)).to.be.near(1, 1e-9)
				for _, row in rows do
					expect(Catalog.getCrate(row.crateId) ~= nil).to.equal(true)
					expect(row.chance > 0).to.equal(true)
					expect(row.tier).to.equal(if row.golden then 3 else 1)
				end
			end
		end)

		it("at Tier 3 gives the design's rows", function()
			local rows = YardPick.rows(3)
			local byId: { [string]: number } = {}
			for _, row in rows do
				byId[row.crateId] = row.chance
			end
			expect(rows[1].crateId).to.equal("classic_crate")
			expect(byId.classic_crate).to.be.near(0.38, 1e-9)
			expect(byId.classic_golden_crate).to.be.near(0.08, 1e-9)
			local plain, golden = 0, 0
			for _, row in rows do
				if row.crateId ~= "classic_crate" and row.crateId ~= "classic_golden_crate" then
					if row.golden then
						golden += 1
						expect(row.chance).to.be.near(0.04 / 3, 1e-9)
					else
						plain += 1
						expect(row.chance).to.be.near(0.5 / 3, 1e-9)
					end
				end
			end
			expect(plain).to.equal(3)
			expect(golden).to.equal(3)
		end)

		it("never offers a crate of an area the tier has not opened", function()
			for tier = 0, 12 do
				for _, row in YardPick.rows(tier) do
					for _, area in Catalog.areas do
						if
							row.crateId == area.id .. "_crate"
							or row.crateId == area.id .. "_golden_crate"
						then
							expect(area.tier <= tier).to.equal(true)
						end
					end
				end
			end
		end)

		it("10,000 picks match the table and stay inside the rows", function()
			local rows = YardPick.rows(3)
			local counts = table.create(#rows, 0)
			local rng = Random.new(3614)
			local N = 10000
			for _ = 1, N do
				local index = YardPick.pick(rows, rng:NextNumber())
				counts[index] += 1
			end
			for index, row in rows do
				-- within 4 standard deviations of the row's share
				local sd = math.sqrt(N * row.chance * (1 - row.chance))
				expect(math.abs(counts[index] - N * row.chance) <= 4 * sd + 1).to.equal(true)
			end
		end)

		it("pick walks the rows in order and survives the ends", function()
			local rows = YardPick.rows(3)
			expect(YardPick.pick(rows, 0)).to.equal(1)
			expect(YardPick.pick(rows, 0.3799)).to.equal(1)
			expect(YardPick.pick(rows, 0.3801)).to.equal(2)
			expect(YardPick.pick(rows, 0.99999)).to.equal(#rows)
			expect(YardPick.pick(rows, 1)).to.equal(1) -- past the end: the Classic Crate, never nothing
			expect(YardPick.pick(rows, -1)).to.equal(1)
		end)

		it("waits 2 hours between picks and 4 for the free crate", function()
			expect(YardPick.hours(true)).to.equal(2)
			expect(YardPick.hours(false)).to.equal(Config.YardSaleClaimHours)
		end)

		it("pickBlocker: one pick per wait, nothing to pay", function()
			local T = 1800000000
			local save = CampExtras.fresh(T)
			expect(CampExtras.pickBlocker(save, 3, T, 2)).to.equal(nil)
			expect(CampExtras.pickBlocker(save, 0, T, 2) ~= nil).to.equal(true) -- the Yard Sale is shut
			save.yardSale.lastClaimAt = T
			expect(CampExtras.pickBlocker(save, 3, T + 2 * 3600 - 1, 2) ~= nil).to.equal(true)
			expect(CampExtras.pickBlocker(save, 3, T + 2 * 3600, 2)).to.equal(nil)
			-- the view's next time follows the pick's wait when it is given, the free crate's otherwise
			expect(CampExtras.view(save, 3, T + 60, nil, 2).yardSale.nextAt).to.equal(T + 2 * 3600)
			expect(CampExtras.view(save, 3, T + 60).yardSale.nextAt).to.equal(
				T + Config.YardSaleClaimHours * 3600
			)
		end)
	end)
end
