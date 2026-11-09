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

		it(
			"asks to check the treats and perks until that tab is opened, crates first (#2571)",
			function()
				expect(MarketBangLogic.line(nil, true)).to.equal(
					"🍪 Treats and perks to check out!"
				)
				expect(MarketBangLogic.line({ park = 0 }, true)).to.equal(
					"🍪 Treats and perks to check out!"
				)
				expect(MarketBangLogic.line({ park = 2 }, true)).to.equal("📦 2 crates to open")
				expect(MarketBangLogic.line(nil, false)).to.equal(nil)
			end
		)

		it("reads the Treats tab as new from the saved storeSeen (#2571)", function()
			local StoreTabs = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared")
					:WaitForChild("StoreTabs")
			)
			expect(MarketBangLogic.treatsNew(nil)).to.equal(false) -- before the first sync: no "!" flash
			expect(MarketBangLogic.treatsNew({})).to.equal(true)
			expect(MarketBangLogic.treatsNew({ cats = 1 })).to.equal(true)
			expect(MarketBangLogic.treatsNew({ treats = StoreTabs.VERSIONS.treats })).to.equal(
				false
			)
			expect(StoreTabs.isTab("treats")).to.equal(true) -- MarkStoreSeen("treats") is saved
		end)
	end)
end
