--!strict
-- shared/CheapTiers and Catalog.setTierNeeds (#5249): what Tiers 3 to 8 ask with `cheapTiers` on and off.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog) :: any
	local CheapTiers = require(Shared.CheapTiers) :: any

	describe("Catalog.setTierNeeds", function()
		it("sets Tiers 3 to 8 and puts the plain needs back", function()
			local plain = Catalog.PLAIN_TIER_NEEDS
			expect(plain[3].cost).to.equal(50000)
			expect(plain[7].cost).to.equal(3125000000)
			expect(plain[7].needsRarityCount).to.equal(3)
			expect(Catalog.setTierNeeds(CheapTiers.NEEDS)).to.equal(true)
			expect(Catalog.getTier(3).cost).to.equal(25000)
			expect(Catalog.getTier(5).cost).to.equal(5000000)
			expect(Catalog.getTier(6).distinctCats).to.equal(17)
			expect(Catalog.getTier(7).needsRarityCount).to.equal(2)
			expect(Catalog.getTier(8).needsRarityCount).to.equal(5) -- Derek's #4513 count is kept
			expect(Catalog.getTier(3).distinctCats).to.equal(plain[3].distinctCats) -- left out: stays plain
			expect(Catalog.setTierNeeds(CheapTiers.NEEDS)).to.equal(false)
			expect(Catalog.setTierNeeds(nil)).to.equal(true)
			for tier = 3, 8 do
				expect(Catalog.getTier(tier).cost).to.equal(plain[tier].cost)
				expect(Catalog.getTier(tier).distinctCats).to.equal(plain[tier].distinctCats)
			end
			expect(Catalog.getTier(7).needsRarityCount).to.equal(3)
		end)

		it(
			"cuts every cost by at least half, keeps the ladder rising and leaves Tiers 2 and 9 alone",
			function()
				local last = 0
				for tier = 3, 8 do
					local cost = CheapTiers.NEEDS[tier].cost
					expect(cost <= Catalog.PLAIN_TIER_NEEDS[tier].cost / 2).to.equal(true)
					expect(cost > last).to.equal(true)
					last = cost
				end
				local two, nine = Catalog.getTier(2).cost, Catalog.getTier(9).cost
				Catalog.setTierNeeds(CheapTiers.NEEDS)
				expect(Catalog.getTier(2).cost).to.equal(two)
				expect(Catalog.getTier(9).cost).to.equal(nine)
				expect(Catalog.getTier(9).distinctCats > Catalog.getTier(8).distinctCats).to.equal(
					true
				)
				Catalog.setTierNeeds(nil)
			end
		)

		it("is off by default", function()
			expect(CheapTiers.on()).to.equal(false)
		end)
	end)
end
