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
			expect(CheapTiers.easyFour()).to.equal(false)
			expect(CheapTiers.needs()).to.equal(nil)
		end)
	end)

	describe("tier4Easy (#5285 E)", function()
		it(
			"asks 250,000 and an Epic at Tier 4 on either row, and puts the plain ones back",
			function()
				local plain = Catalog.PLAIN_TIER_NEEDS
				expect(plain[4].needsRarity).to.equal("Legendary")
				expect(plain[5].needsRarity).to.equal("Legendary")
				for _, cheap in { false, true } do
					Catalog.setTierNeeds(CheapTiers.needsFor(cheap, true))
					expect(Catalog.getTier(4).cost).to.equal(250000)
					expect(Catalog.getTier(4).needsRarity).to.equal("Epic")
					expect(Catalog.getTier(4).distinctCats).to.equal(plain[4].distinctCats)
					expect(Catalog.getTier(5).needsRarity).to.equal("Legendary")
					expect(Catalog.getTier(3).cost).to.equal(if cheap then 25000 else plain[3].cost)
					expect(Catalog.getTier(5).cost).to.equal(
						if cheap then 5000000 else plain[5].cost
					)
				end
				Catalog.setTierNeeds(CheapTiers.needsFor(true, false))
				expect(Catalog.getTier(4).cost).to.equal(400000)
				expect(Catalog.getTier(4).needsRarity).to.equal("Legendary")
				Catalog.setTierNeeds(nil)
				expect(Catalog.getTier(4).cost).to.equal(plain[4].cost)
				expect(Catalog.getTier(4).needsRarity).to.equal("Legendary")
				expect(CheapTiers.NEEDS[4].needsRarity).to.equal(nil) -- the cheapTiers row itself is untouched
			end
		)

		it("keeps the ladder rising: Tier 4 still costs more than Tier 3 on both rows", function()
			for _, cheap in { false, true } do
				Catalog.setTierNeeds(CheapTiers.needsFor(cheap, true))
				expect(Catalog.getTier(4).cost > Catalog.getTier(3).cost).to.equal(true)
				expect(Catalog.getTier(5).cost > Catalog.getTier(4).cost).to.equal(true)
			end
			Catalog.setTierNeeds(nil)
		end)
	end)

	describe("tier3Easy (#5467)", function()
		it(
			"asks 10,000 and 4 kinds at Tier 3 on any row, keeps the 2 Rares, and puts the old ones back",
			function()
				local plain = Catalog.PLAIN_TIER_NEEDS
				for _, cheap in { false, true } do
					for _, four in { false, true } do
						Catalog.setTierNeeds(CheapTiers.needsFor(cheap, four, true))
						expect(Catalog.getTier(3).cost).to.equal(10000)
						expect(Catalog.getTier(3).distinctCats).to.equal(4)
						expect(Catalog.getTier(3).needsRarity).to.equal(plain[3].needsRarity)
						expect(Catalog.getTier(3).needsRarityCount).to.equal(
							plain[3].needsRarityCount
						)
						expect(Catalog.getTier(4).cost).to.equal(
							if four then 250000 elseif cheap then 400000 else plain[4].cost
						)
						-- still a step up from Tier 2, in coins and in kinds
						expect(Catalog.getTier(3).cost > Catalog.getTier(2).cost).to.equal(true)
						expect(Catalog.getTier(3).distinctCats >= Catalog.getTier(2).distinctCats).to.equal(
							true
						)
					end
				end
				Catalog.setTierNeeds(CheapTiers.needsFor(true, false, false))
				expect(Catalog.getTier(3).cost).to.equal(25000)
				expect(Catalog.getTier(3).distinctCats).to.equal(plain[3].distinctCats)
				Catalog.setTierNeeds(nil)
				expect(Catalog.getTier(3).cost).to.equal(plain[3].cost)
			end
		)
	end)

	describe("tiersEasy (Derek 2026-11-19)", function()
		it("lays Tiers 4 to 7 on any rows, keeps 3 and 8, and each tier is a step up", function()
			local plain = Catalog.PLAIN_TIER_NEEDS
			for _, cheap in { false, true } do
				for _, four in { false, true } do
					Catalog.setTierNeeds(CheapTiers.needsFor(cheap, four, true, true))
					expect(Catalog.getTier(3).cost).to.equal(10000)
					for tier, row in CheapTiers.EASY do
						local def = Catalog.getTier(tier)
						expect(def.cost).to.equal(row.cost)
						expect(def.distinctCats).to.equal(row.distinctCats)
						expect(def.needsRarity).to.equal(row.needsRarity)
						expect(def.needsRarityCount).to.equal(row.needsRarityCount)
					end
					expect(Catalog.getTier(8).cost).to.equal(
						if cheap then CheapTiers.NEEDS[8].cost else plain[8].cost
					)
					for tier = 3, 8 do
						local below, def = Catalog.getTier(tier - 1), Catalog.getTier(tier)
						expect(def.cost > below.cost).to.equal(true)
						expect(def.distinctCats >= below.distinctCats).to.equal(true)
					end
				end
			end
			Catalog.setTierNeeds(CheapTiers.needsFor(true, true, true, false))
			expect(Catalog.getTier(4).cost).to.equal(250000)
			expect(Catalog.getTier(7).cost).to.equal(CheapTiers.NEEDS[7].cost)
			Catalog.setTierNeeds(nil)
			expect(Catalog.getTier(5).cost).to.equal(plain[5].cost)
		end)
	end)

	describe("coinsOnly (#5533)", function()
		it("starts off", function()
			expect(CheapTiers.coinsOnly()).to.equal(false)
		end)

		it("asks coins only at every tier, whatever the other switches", function()
			local plain = Catalog.PLAIN_TIER_NEEDS
			for _, cheap in { false, true } do
				for _, all in { false, true } do
					Catalog.setTierNeeds(CheapTiers.needsFor(cheap, true, true, all, true))
					for tier = 2, Catalog.maxTier do
						local def = Catalog.getTier(tier)
						expect(def.distinctCats).to.equal(0)
						expect(def.needsRarity).to.equal(nil)
						expect(def.needsRarityCount).to.equal(nil)
						local cost = CheapTiers.COINS[tier]
						if cost ~= nil then
							expect(def.cost).to.equal(cost)
						end
						if tier > 2 then
							expect(def.cost > Catalog.getTier(tier - 1).cost).to.equal(true)
						end
					end
					expect(Catalog.getTier(8).cost).to.equal(
						if cheap then CheapTiers.NEEDS[8].cost else plain[8].cost
					)
				end
			end
			expect(Catalog.getTier(2).cost).to.equal(CheapTiers.COINS[2])
			Catalog.setTierNeeds(nil)
			for tier = 2, Catalog.maxTier do
				local def = Catalog.getTier(tier)
				expect(def.cost).to.equal(plain[tier].cost)
				expect(def.distinctCats).to.equal(plain[tier].distinctCats)
				expect(def.needsRarity).to.equal(plain[tier].needsRarity)
				expect(def.needsRarityCount).to.equal(plain[tier].needsRarityCount)
			end
			expect(Catalog.getTier(2).cost).to.equal(1500)
		end)

		it("lets a player with the coins and one cat rank up at every tier", function()
			local Economy = require(Shared.Economy) :: any
			Catalog.setTierNeeds(CheapTiers.needsFor(false, false, false, false, true))
			for tier = 1, 6 do
				local nextDef = Catalog.getTier(tier + 1)
				local profile: any = {
					tier = tier,
					coins = nextDef.cost,
					collection = {},
					cats = {},
				}
				expect(Economy.rankUpBlocker(profile)).to.equal(nil)
				profile.coins = nextDef.cost - 1
				expect(Economy.rankUpBlocker(profile)).to.equal("Not enough coins")
			end
			Catalog.setTierNeeds(nil)
		end)
	end)

	describe("tier3Up (#5617)", function()
		it(
			"lays Tier 3 at TIER3_UP coins over coinsOnly and the rest, and touches nothing else",
			function()
				local plain = CheapTiers.needsFor(false, false, true, true, true) :: any
				local up = CheapTiers.needsFor(false, false, true, true, true, true) :: any
				expect(up[3].cost).to.equal(CheapTiers.TIER3_UP)
				expect(up[3].distinctCats).to.equal(0)
				expect(up[2].cost).to.equal(plain[2].cost)
				expect(up[4].cost).to.equal(plain[4].cost)
				local alone = CheapTiers.needsFor(false, false, false, false, false, true) :: any
				expect(alone[3].cost).to.equal(CheapTiers.TIER3_UP)
				expect(alone[4]).to.equal(nil)
			end
		)
	end)
end
