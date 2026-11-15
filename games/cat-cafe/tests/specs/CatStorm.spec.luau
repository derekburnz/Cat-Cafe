--!strict
-- shared/CatStorm.luau (#4195 part 3): the storm's odds on every area's own, how many strays an area gets and how
-- far apart, and when an area is full.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local CatStorm = require(Shared.CatStorm)

	describe("CatStorm.odds", function()
		it("multiplies the Mythical weight and leaves the area's odds table alone", function()
			for _, area in Catalog.areas do
				local before = table.clone(area.odds)
				local storm = CatStorm.odds(area.odds, 10)
				expect(area.odds).to.deepEqual(before)
				expect(storm.Mythical).to.be.near(area.odds.Mythical * 10, 1e-9)
				for _, rarity in { "Common", "Rare", "Epic", "Legendary" } do
					expect((storm :: any)[rarity]).to.equal((area.odds :: any)[rarity])
				end
			end
		end)

		it(
			"makes a Mythical likelier in every area, never certain and never less likely",
			function()
				for _, area in Catalog.areas do
					local plain = CatStorm.share(area.odds, "Mythical")
					local storm = CatStorm.share(CatStorm.odds(area.odds, 10), "Mythical")
					expect(storm > plain).to.equal(true)
					expect(storm < 1).to.equal(true)
					-- ten times the weight is ten times the chance while it is small, and less than that as it grows
					expect(storm <= plain * 10 + 1e-9).to.equal(true)
					expect(storm >= plain * 10 / (1 + 9 * plain) - 1e-9).to.equal(true)
					-- every other rarity can still come
					for _, rarity in { "Common", "Rare", "Epic", "Legendary" } do
						if (area.odds :: any)[rarity] > 0 then
							expect(CatStorm.share(CatStorm.odds(area.odds, 10), rarity) > 0).to.equal(
								true
							)
						end
					end
				end
			end
		)

		it("is the Park's 1.2% at about 10.8%, as the roll itself comes out", function()
			local park = Catalog.areas[2]
			expect(park.id).to.equal("park")
			local storm = CatStorm.odds(park.odds, 10)
			expect(CatStorm.share(storm, "Mythical")).to.be.near(12 / 110.8, 1e-6)
			local rng = Random.new(4195)
			local mythical, rolls = 0, 4000
			for _ = 1, rolls do
				if Catching.pickRarity(storm, rng:NextNumber()) == "Mythical" then
					mythical += 1
				end
			end
			expect(mythical / rolls).to.be.near(12 / 110.8, 0.02)
		end)

		it("changes nothing for no boost, and stops at its cap", function()
			local odds = Catalog.areas[1].odds
			for _, boost in { 1, 0, -3, 0.5, 0 / 0 } do
				expect(CatStorm.odds(odds, boost)).to.deepEqual(odds)
			end
			expect(CatStorm.odds(odds, 999).Mythical).to.be.near(
				odds.Mythical * CatStorm.BOOST_MAX,
				1e-9
			)
		end)
	end)

	describe("how the storm's strays come", function()
		it("gives each area two waves' worth, spread over the whole storm", function()
			for _, area in Catalog.areas do
				local total = CatStorm.total(area.waveSize)
				expect(total).to.equal(area.waveSize * CatStorm.WAVES)
				local gap = CatStorm.gap(600, area.waveSize)
				expect(gap >= CatStorm.GAP_MIN).to.equal(true)
				-- the last one still lands inside a ten minute storm
				expect((total - 1) * gap < 600).to.equal(true)
			end
			expect(CatStorm.gap(600, 11)).to.be.near(600 / 22, 1e-9)
			-- a short test storm never drops them closer than the floor
			expect(CatStorm.gap(60, 11)).to.equal(CatStorm.GAP_MIN)
			expect(CatStorm.total(0)).to.equal(CatStorm.WAVES)
		end)

		it("starts the areas at different seconds, all within the first few", function()
			local count = #Catalog.areas
			local seen: { [number]: boolean } = {}
			for index = 1, count do
				local first = CatStorm.offset(index, count, 27)
				expect(first >= 0 and first < CatStorm.GAP_MIN * 2).to.equal(true)
				expect(seen[first]).to.equal(nil)
				seen[first] = true
			end
			expect(CatStorm.offset(1, count, 27)).to.equal(0)
			expect(CatStorm.offset(1, 1, 27)).to.equal(0)
		end)

		it("holds off while an area already stands full", function()
			expect(CatStorm.room(0, 11)).to.equal(true)
			expect(CatStorm.room(21, 11)).to.equal(true)
			expect(CatStorm.room(22, 11)).to.equal(false)
			expect(CatStorm.room(40, 11)).to.equal(false)
		end)
	end)
end
