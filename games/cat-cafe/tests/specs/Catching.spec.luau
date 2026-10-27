--!strict
-- Catching.luau against data-model v0.3.1 sections 2, 3, 8, 9 and 10b: odds, picking a cat, fleeing. The circles
-- that decide a catch have their own spec (Circles.spec).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local Config = require(Shared.Config)

	describe("succeeds", function()
		it("roll strictly below chance wins", function()
			expect(Catching.succeeds(0.5, 0.49)).to.equal(true)
			expect(Catching.succeeds(0.5, 0.5)).to.equal(false)
			expect(Catching.succeeds(0.95, 0.9499)).to.equal(true)
			expect(Catching.succeeds(0.95, 0.95)).to.equal(false)
			expect(Catching.succeeds(0.05, 0)).to.equal(true)
		end)

		it("a chance of 0 can never win, a chance of 1 always does for rolls in [0, 1)", function()
			expect(Catching.succeeds(0, 0)).to.equal(false)
			expect(Catching.succeeds(1, 0.999999)).to.equal(true)
		end)
	end)

	describe("patience (sections 2 and 10, v0.4)", function()
		it("paws per player per stray: Common 3, Rare 2, Epic 2, Legendary 1, Mythical 1; nothing flees", function()
			expect(Catching.patience("Common")).to.equal(3)
			expect(Catching.patience("Rare")).to.equal(2)
			expect(Catching.patience("Epic")).to.equal(2)
			expect(Catching.patience("Legendary")).to.equal(1)
			expect(Catching.patience("Mythical")).to.equal(1)
			expect((Catching :: any).fleesOnFail).never.to.be.ok()
			expect((Catching :: any).fleesOnMiss).never.to.be.ok()
		end)

		it("every stray gives at least one try, and a rarer cat never trusts you longer", function()
			local previous = math.huge
			for _, rarity in ipairs(Catalog.rarityOrder) do
				local paws = Catching.patience(rarity)
				expect(paws >= 1).to.equal(true)
				expect(paws <= previous).to.equal(true)
				previous = paws
			end
		end)

		it("v0.3: the hold ring and flat chance are gone (F26)", function()
			local catching = Catching :: any
			expect(catching.ringBonus).never.to.be.ok()
			expect(catching.ringResultFromHold).never.to.be.ok()
			expect(catching.chance).never.to.be.ok()
		end)
	end)

	describe("pickRarity against odds tables (sections 8 and 9)", function()
		local alley = { Common = 72, Rare = 22, Epic = 5, Legendary = 0.9, Mythical = 0.1 }

		it("maps roll boundaries onto the cumulative odds", function()
			expect(Catching.pickRarity(alley, 0)).to.equal("Common")
			expect(Catching.pickRarity(alley, 0.7199)).to.equal("Common")
			expect(Catching.pickRarity(alley, 0.7201)).to.equal("Rare")
			expect(Catching.pickRarity(alley, 0.9399)).to.equal("Rare")
			expect(Catching.pickRarity(alley, 0.9401)).to.equal("Epic")
			expect(Catching.pickRarity(alley, 0.9899)).to.equal("Epic")
			expect(Catching.pickRarity(alley, 0.9901)).to.equal("Legendary")
			expect(Catching.pickRarity(alley, 0.9989)).to.equal("Legendary")
			expect(Catching.pickRarity(alley, 0.9991)).to.equal("Mythical")
			expect(Catching.pickRarity(alley, 0.999999)).to.equal("Mythical")
		end)

		it("clamps out of range rolls instead of erroring", function()
			expect(Catching.pickRarity(alley, -1)).to.equal("Common")
			expect(Catching.pickRarity(alley, 1)).to.equal("Mythical")
			expect(Catching.pickRarity(alley, 7)).to.equal("Mythical")
		end)

		it("a zero weight is never picked (Moon Milk and Star Treat have no Commons)", function()
			local starTreat = Catalog.getLure("star_treat")
			assert(starTreat)
			for i = 0, 999 do
				local rarity = Catching.pickRarity(starTreat.odds, i / 1000)
				expect(rarity ~= "Common" and rarity ~= "Rare").to.equal(true)
			end
		end)

		local function distribution(odds: any)
			local counts: { [string]: number } =
				{ Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythical = 0 }
			local n = 20000
			for i = 0, n - 1 do
				local rarity = Catching.pickRarity(odds, i / n)
				counts[rarity] += 1
			end
			return counts, n
		end

		local function oddsOf(def: any)
			assert(def ~= nil, "catalog entry missing")
			return def.odds
		end
		local sources: { { any } } = {
			{ "alley", oddsOf(Catalog.getArea("alley")) },
			{ "park", oddsOf(Catalog.getArea("park")) },
			{ "kibble", oddsOf(Catalog.getLure("kibble")) },
			{ "tuna", oddsOf(Catalog.getLure("tuna")) },
			{ "salmon", oddsOf(Catalog.getLure("salmon")) },
			{ "sardines", oddsOf(Catalog.getLure("sardines")) },
			{ "caviar", oddsOf(Catalog.getLure("caviar")) },
			{ "moon_milk", oddsOf(Catalog.getLure("moon_milk")) },
			{ "star_treat", oddsOf(Catalog.getLure("star_treat")) },
		}
		for _, source in ipairs(sources) do
			it(
				source[1] .. " produces the advertised percentages over an even sweep of rolls",
				function()
					local counts, n = distribution(source[2])
					for _, rarity in ipairs(Catalog.rarityOrder) do
						expect(counts[rarity] / n * 100).to.be.near(source[2][rarity], 0.05)
					end
				end
			)
		end
	end)

	describe(
		"pickRarity scales by the odds total (v0.2, so a rescue table need not sum to 100)",
		function()
			-- The alley with the Rare weight doubled but not renormalised: 75 / 40 / 4.5 / 0.5, total 120.
			local heavy: { [string]: number } =
				{ Common = 75, Rare = 40, Epic = 4.5, Legendary = 0.5 }

			it("cuts the roll at the cumulative share of the total", function()
				expect(Catching.pickRarity(heavy :: any, 0)).to.equal("Common")
				expect(Catching.pickRarity(heavy :: any, 0.6249)).to.equal("Common") -- 75 / 120 = 0.625
				expect(Catching.pickRarity(heavy :: any, 0.6251)).to.equal("Rare")
				expect(Catching.pickRarity(heavy :: any, 0.9583)).to.equal("Rare") -- 115 / 120 = 0.95833
				expect(Catching.pickRarity(heavy :: any, 0.9584)).to.equal("Epic")
				expect(Catching.pickRarity(heavy :: any, 0.9958)).to.equal("Epic") -- 119.5 / 120 = 0.99583
				expect(Catching.pickRarity(heavy :: any, 0.9959)).to.equal("Legendary")
				expect(Catching.pickRarity(heavy :: any, 1)).to.equal("Legendary")
			end)

			it("a sweep matches each weight over the total", function()
				local counts: { [string]: number } =
					{ Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythical = 0 }
				local n = 24000
				for i = 0, n - 1 do
					local rarity = Catching.pickRarity(heavy :: any, i / n)
					counts[rarity] += 1
				end
				for rarity, weight in pairs(heavy) do
					local count: number = counts[rarity]
					expect(count / n).to.be.near(weight / 120, 0.0005)
				end
			end)
		end
	)

	describe("rescueOdds (section 10b): every non-Common weight doubled, renormalised to 100", function()
		local function total(odds: any): number
			local sum = 0
			for _, rarity in ipairs(Catalog.rarityOrder) do
				sum += odds[rarity]
			end
			return sum
		end

		it("Alleyway 72 / 22 / 5 / 0.9 / 0.1 becomes 56.25 / 34.375 / 7.8125 / 1.40625 / 0.15625", function()
			local alley = Catalog.getArea("alley")
			assert(alley)
			local rescue: any = Catching.rescueOdds(alley.odds)
			expect(rescue.Common).to.be.near(56.25, 1e-9)
			expect(rescue.Rare).to.be.near(34.375, 1e-9)
			expect(rescue.Epic).to.be.near(7.8125, 1e-9)
			expect(rescue.Legendary).to.be.near(1.40625, 1e-9)
			expect(rescue.Mythical).to.be.near(0.15625, 1e-9)
		end)

		it("Park 60 / 28 / 9 / 2.5 / 0.5 becomes 60 / 56 / 18 / 5 / 1 over 140 (42.9 / 40.0 / 12.9 / 3.6 / 0.7)", function()
			local park = Catalog.getArea("park")
			assert(park)
			local rescue: any = Catching.rescueOdds(park.odds)
			expect(rescue.Common).to.be.near(60 / 140 * 100, 1e-9)
			expect(rescue.Rare).to.be.near(40, 1e-9)
			expect(rescue.Epic).to.be.near(18 / 140 * 100, 1e-9)
			expect(rescue.Legendary).to.be.near(5 / 140 * 100, 1e-9)
			expect(rescue.Mythical).to.be.near(1 / 140 * 100, 1e-9)
		end)

		it("always sums to 100, doubles every rarer weight against Common and leaves the input alone", function()
			for _, area in ipairs(Catalog.areas) do
				local before = table.clone(area.odds :: any)
				local rescue: any = Catching.rescueOdds(area.odds)
				expect(total(rescue)).to.be.near(100, 1e-9)
				for _, rarity in ipairs(Catalog.rarityOrder) do
					if rarity ~= "Common" then
						expect(rescue[rarity] / rescue.Common).to.be.near(
							2 * (area.odds :: any)[rarity] / area.odds.Common,
							1e-9
						)
					end
				end
				expect(area.odds :: any).to.deepEqual(before)
			end
		end)

		it("all Common or all zero odds stay all Common", function()
			local allCommon: any = Catching.rescueOdds({ Common = 100, Rare = 0, Epic = 0, Legendary = 0, Mythical = 0 })
			expect(allCommon.Common).to.be.near(100, 1e-9)
			expect(allCommon.Mythical).to.equal(0)
			local empty: any = Catching.rescueOdds({ Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythical = 0 })
			expect(empty).to.deepEqual({ Common = 100, Rare = 0, Epic = 0, Legendary = 0, Mythical = 0 })
		end)

		it("a rescue roll over the Alleyway gives a Rare 34.375% of the time", function()
			local alley = Catalog.getArea("alley")
			assert(alley)
			local rescue = Catching.rescueOdds(alley.odds)
			local rares, n = 0, 12800
			for i = 0, n - 1 do
				if Catching.pickRarity(rescue, i / n) == "Rare" then
					rares += 1
				end
			end
			expect(rares / n).to.be.near(0.34375, 0.001)
		end)
	end)

	describe("candidates and pickCat (section 3 areas)", function()
		local function idList(list: { any })
			local out = {}
			for _, def in ipairs(list) do
				table.insert(out, def.id)
			end
			return out
		end

		it("each area offers only its own cats", function()
			expect(idList(Catching.candidates("Common", "alley"))).to.deepEqual({ "tabby", "tuxedo", "ginger", "smoke" })
			expect(idList(Catching.candidates("Rare", "alley"))).to.deepEqual({ "calico", "tortie" })
			expect(idList(Catching.candidates("Epic", "alley"))).to.deepEqual({ "sphynx", "maine_coon" })
			expect(idList(Catching.candidates("Legendary", "alley"))).to.deepEqual({ "void" })
			expect(idList(Catching.candidates("Mythical", "alley"))).to.deepEqual({ "midnight" })
			expect(idList(Catching.candidates("Common", "park"))).to.deepEqual({ "snow", "cream", "brownie", "blue" })
			expect(idList(Catching.candidates("Rare", "park"))).to.deepEqual({ "siamese", "bengal" })
			expect(idList(Catching.candidates("Epic", "park"))).to.deepEqual({ "ragdoll", "persian" })
			expect(idList(Catching.candidates("Legendary", "park"))).to.deepEqual({ "blossom" })
			expect(idList(Catching.candidates("Mythical", "park"))).to.deepEqual({ "aurora" })
		end)

		it("v0.3: no cat lives in two areas, so the old \"both\" area is empty", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				expect(#Catching.candidates(rarity, "both")).to.equal(0)
			end
		end)

		it("pickCat is uniform over the candidates", function()
			local commons = Catching.candidates("Common", "alley")
			expect(Catching.pickCat("Common", "alley", 0).id).to.equal(commons[1].id)
			expect(Catching.pickCat("Common", "alley", 0.2499).id).to.equal(commons[1].id)
			expect(Catching.pickCat("Common", "alley", 0.25).id).to.equal(commons[2].id)
			expect(Catching.pickCat("Common", "alley", 0.5).id).to.equal(commons[3].id)
			expect(Catching.pickCat("Common", "alley", 0.999).id).to.equal(commons[4].id)
			expect(Catching.pickCat("Rare", "park", 0.4999).id).to.equal("siamese")
			expect(Catching.pickCat("Rare", "park", 0.5).id).to.equal("bengal")
			expect(Catching.pickCat("Mythical", "park", 0.7).id).to.equal("aurora")
		end)

		it("pickCat falls back to the first catalog cat in an area with no cats", function()
			expect(Catching.pickCat("Mythical", "nowhere", 0.5).id).to.equal(Catalog.cats[1].id)
			expect(Catching.pickCat("Common", "both", 0.5).id).to.equal(Catalog.cats[1].id)
		end)

		it("pickCat never returns nil for any rarity, area and roll", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				for _, area in ipairs({ "alley", "park", "neighbourhood", "woods", "sewer", "nowhere" }) do
					for _, roll in ipairs({ 0, 0.5, 0.999999, 1 }) do
						local def = Catching.pickCat(rarity, area, roll)
						expect(def).to.be.ok()
						if area ~= "nowhere" then
							expect(def.area).to.equal(area)
							expect(def.rarity).to.equal(rarity)
						end
					end
				end
			end
		end)

		-- F28: bait picks among that rarity's cats in every area the player has unlocked (section 8).
		it("the bait pick spreads a rarity over every unlocked area (F28)")
	end)

	describe("rarityAtLeast and percentText", function()
		it("Epic and rarer trigger announcements, Rare does not", function()
			expect(Catching.rarityAtLeast("Epic", Config.AnnounceMinRarity)).to.equal(true)
			expect(Catching.rarityAtLeast("Legendary", Config.AnnounceMinRarity)).to.equal(true)
			expect(Catching.rarityAtLeast("Mythical", Config.AnnounceMinRarity)).to.equal(true)
			expect(Catching.rarityAtLeast("Rare", Config.AnnounceMinRarity)).to.equal(false)
			expect(Catching.rarityAtLeast("Common", "Bogus")).to.equal(false)
		end)

		it("percentText rounds to a whole percent", function()
			expect(Catching.percentText(0.45)).to.equal("45%")
			expect(Catching.percentText(0.949)).to.equal("95%")
			expect(Catching.percentText(0.004)).to.equal("0%")
			expect(Catching.percentText(0.005)).to.equal("1%")
			expect(Catching.percentText(1)).to.equal("100%")
		end)
	end)
end
