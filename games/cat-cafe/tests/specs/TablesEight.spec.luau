--!strict
-- shared/TablesEight.luau (#5441): Tables 7 and 8 open at Tiers 9 and 10 only with the switch on, and back.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local LiveFlags = require(Shared.LiveFlags)
	local TablesEight = require(Shared.TablesEight)

	describe("TablesEight", function()
		it(
			"opens Tables 7 at Tier 9 and Tables 8 at Tier 10 only with the switch on, and back",
			function()
				local tables = Catalog.getUpgrade("tables") :: any
				expect(Catalog.setTablesEight(true)).to.equal(true)
				expect(tables.maxLevel).to.equal(8)
				expect(Catalog.tierForLevel("tables", 7)).to.equal(9)
				expect(Catalog.tierForLevel("tables", 8)).to.equal(10)
				expect(tables.requiresTierAtLevel[7]).to.equal(9)
				expect(tables.requiresTierAtLevel[8]).to.equal(10)
				expect(tables.costs[7]).to.equal(25000000000)
				expect(tables.costs[8]).to.equal(150000000000)
				expect(tables.costs[8] > tables.costs[7] and tables.costs[7] > tables.costs[6]).to.equal(
					true
				)
				expect(Catalog.setTablesEight(true)).to.equal(false)
				expect(Catalog.setTablesEight(false)).to.equal(true)
				expect(tables.maxLevel).to.equal(6)
				expect(tables.costs[7]).to.equal(nil)
				expect(tables.costs[8]).to.equal(nil)
				expect(Catalog.tierForLevel("tables", 7)).to.equal(nil)
				expect(tables.requiresTierAtLevel[7]).to.equal(nil)
				expect((Catalog.tiers[10].caps :: any).tables).to.equal(6)
			end
		)

		it("is off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[TablesEight.FLAG]).to.equal(true)
		end)
	end)
end
