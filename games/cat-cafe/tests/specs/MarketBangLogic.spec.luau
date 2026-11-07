--!strict
-- UI/Components/MarketBangLogic.luau (#2214, crispi_255's idea): the "!" over the Fish Market shows only while there are
-- crates to open, and its bubble counts them.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local MarketBangLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("MarketBangLogic")
	) :: any

	describe("MarketBangLogic", function()
		it("counts every unopened crate", function()
			expect(MarketBangLogic.count(nil)).to.equal(0)
			expect(MarketBangLogic.count({})).to.equal(0)
			expect(MarketBangLogic.count({ park = 2, alley = 0, golden = 1 })).to.equal(3)
		end)

		it("says nothing with no crates, so the stall shows no !", function()
			expect(MarketBangLogic.line(nil)).to.equal(nil)
			expect(MarketBangLogic.line({ park = 0 })).to.equal(nil)
		end)

		it("counts one crate and many", function()
			expect(MarketBangLogic.line({ park = 1 })).to.equal("📦 1 crate to open")
			expect(MarketBangLogic.line({ park = 2, woods = 3 })).to.equal("📦 5 crates to open")
		end)
	end)
end
