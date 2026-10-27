--!strict
-- UI/Components/MarketLogic.luau: the Golden Fish Market's crates, lucky twentieth, odds and perk costs (F53).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local MarketLogic = require(Components:WaitForChild("MarketLogic")) :: any

	local ODDS = { Common = 60, Rare = 27, Epic = 10, Legendary = 2.5, Mythical = 0.5 }
	local GOLDEN = { Common = 0, Rare = 0, Epic = 80, Legendary = 17.5, Mythical = 2.5 }
	local ALLEY = { id = "alley_crate", area = "alley", golden = false, price = 60, odds = ODDS }
	local AREAS = { { id = "alley", tier = 1 }, { id = "park", tier = 2 } }

	describe("MarketLogic.luckLeft and luckText", function()
		it("counts down to the lucky twentieth", function()
			expect(MarketLogic.luckLeft(nil, 20)).to.equal(20)
			expect(MarketLogic.luckLeft(0, 20)).to.equal(20)
			expect(MarketLogic.luckLeft(16, 20)).to.equal(4)
			expect(MarketLogic.luckLeft(19, 20)).to.equal(1)
			expect(MarketLogic.luckLeft(25, 20)).to.equal(1)
		end)

		it("says how many crates are left", function()
			expect(MarketLogic.luckText(4)).to.equal("Epic or better in 4 more crates")
			expect(MarketLogic.luckText(1)).to.equal("Your next crate is Epic or better!")
		end)
	end)

	describe("MarketLogic.nextOdds", function()
		it("uses the golden odds only on the lucky one", function()
			expect(MarketLogic.nextOdds(ALLEY, 3, 20, GOLDEN)).to.equal(ODDS)
			expect(MarketLogic.nextOdds(ALLEY, 19, 20, GOLDEN)).to.equal(GOLDEN)
			expect(MarketLogic.nextOdds(ALLEY, 19, 20, nil)).to.equal(ODDS)
		end)

		it("keeps a golden crate's own odds", function()
			local golden = { id = "alley_golden_crate", golden = true, odds = GOLDEN }
			expect(MarketLogic.nextOdds(golden, 0, 20, GOLDEN)).to.equal(GOLDEN)
		end)
	end)

	describe("MarketLogic.rarityRows", function()
		it("lists the rarities with a chance, Common first", function()
			local rows = MarketLogic.rarityRows(GOLDEN)
			expect(#rows).to.equal(3)
			expect(rows[1].rarity).to.equal("Epic")
			expect(rows[3].percent).to.equal(2.5)
		end)
	end)

	describe("MarketLogic.pieceChances", function()
		it("splits a rarity's odds among its pieces, rarest first", function()
			local rarity = {
				brick = "Common",
				tile = "Common",
				red = "Common",
				stools = "Common",
				puddle = "Rare",
				graffiti = "Rare",
				jars = "Rare",
				mural = "Epic",
				jukebox = "Legendary",
				sky = "Mythical",
			}
			local pieces = {
				"brick",
				"sky",
				"tile",
				"puddle",
				"red",
				"graffiti",
				"stools",
				"jukebox",
				"jars",
				"mural",
				"unknown",
			}
			local chances = MarketLogic.pieceChances(pieces, function(id: string)
				return rarity[id]
			end, ODDS)
			expect(#chances).to.equal(10)
			expect(chances[1].id).to.equal("sky")
			expect(chances[1].percent).to.be.near(0.5)
			expect(chances[4].id).to.equal("puddle")
			expect(chances[4].percent).to.be.near(9)
			expect(chances[7].id).to.equal("brick")
			expect(chances[7].percent).to.be.near(15)
		end)
	end)

	describe("MarketLogic.percent", function()
		it("keeps at most two decimals", function()
			expect(MarketLogic.percent(15)).to.equal("15%")
			expect(MarketLogic.percent(2.5)).to.equal("2.5%")
			expect(MarketLogic.percent(0.5)).to.equal("0.5%")
			expect(MarketLogic.percent(80 / 3)).to.equal("26.67%")
			expect(MarketLogic.percent(100)).to.equal("100%")
		end)
	end)

	describe("MarketLogic.isOpen and openTier", function()
		it("opens a zone crate with its zone and the Classic Crate always", function()
			local park = { id = "park_crate", area = "park" }
			expect(MarketLogic.isOpen(park, 1, AREAS)).to.equal(false)
			expect(MarketLogic.isOpen(park, 2, AREAS)).to.equal(true)
			local classic = { id = "classic_crate", area = "classic" }
			expect(MarketLogic.isOpen(classic, 1, AREAS)).to.equal(true)
			expect(MarketLogic.openTier(park, AREAS)).to.equal(2)
		end)
	end)

	describe("MarketLogic.cost", function()
		it("prices the next perk level and stops at the last", function()
			local espresso =
				{ id = "golden_espresso", kind = "perk", costs = { 40, 80, 150 }, maxLevel = 3 }
			expect(MarketLogic.cost(espresso, 0)).to.equal(40)
			expect(MarketLogic.cost(espresso, 2)).to.equal(150)
			expect(MarketLogic.cost(espresso, 3)).to.equal(nil)
			local treat = { id = "star_treat", kind = "lure", cost = 80 }
			expect(MarketLogic.cost(treat, nil)).to.equal(80)
		end)
	end)
end
