--!strict
-- shared/GoldenFish.luau (F52, golden-fish.md section 2) and the crate and Market rows it shares save version 7
-- with (F53, sections 3 and 4).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local GoldenFish = require(Shared.GoldenFish)
	local ProfileSchema = require(Shared.ProfileSchema)

	describe("GoldenFish.forCatch", function()
		it("pays a cat new to the Index by its rarity, whichever way it was found", function()
			local paid: { [string]: number } =
				{ Common = 1, Rare = 3, Epic = 8, Legendary = 20, Mythical = 40 }
			for rarity, fish in paid do
				expect(GoldenFish.forCatch(rarity, true, false, "net")).to.equal(fish)
				expect(GoldenFish.forCatch(rarity, true, false, "rescue")).to.equal(fish)
				expect(GoldenFish.forCatch(rarity, true, false, "bait")).to.equal(fish)
			end
		end)

		it("pays twice that for a first gold, and both when the first catch is gold", function()
			expect(GoldenFish.forCatch("Rare", false, true, "net")).to.equal(6)
			expect(GoldenFish.forCatch("Mythical", false, true, "bait")).to.equal(80)
			expect(GoldenFish.forCatch("Epic", true, true, "net")).to.equal(24)
		end)

		it("pays a repeat only for Epic and better by net or rescue", function()
			expect(GoldenFish.forCatch("Common", false, false, "net")).to.equal(0)
			expect(GoldenFish.forCatch("Rare", false, false, "rescue")).to.equal(0)
			expect(GoldenFish.forCatch("Epic", false, false, "net")).to.equal(1)
			expect(GoldenFish.forCatch("Legendary", false, false, "rescue")).to.equal(3)
			expect(GoldenFish.forCatch("Mythical", false, false, "net")).to.equal(8)
		end)

		it(
			"never pays a repeat from the bait bowl, so bought food cannot be farmed into fish",
			function()
				for _, rarity in Catalog.rarityOrder do
					expect(GoldenFish.forCatch(rarity, false, false, "bait")).to.equal(0)
					expect(GoldenFish.forCatch(rarity, false, false, "starter")).to.equal(0)
				end
			end
		)

		it("pays nothing for an unknown rarity", function()
			expect(GoldenFish.forCatch("Shiny", true, true, "net")).to.equal(0)
		end)
	end)

	describe("GoldenFish.forRankUp", function()
		it("pays 10, 25, 50 and 100 for Tiers 2 to 5 and nothing else", function()
			expect(GoldenFish.forRankUp(1)).to.equal(0)
			expect(GoldenFish.forRankUp(2)).to.equal(10)
			expect(GoldenFish.forRankUp(3)).to.equal(25)
			expect(GoldenFish.forRankUp(4)).to.equal(50)
			expect(GoldenFish.forRankUp(5)).to.equal(100)
			expect(GoldenFish.forRankUp(6)).to.equal(0)
		end)
	end)

	describe("GoldenFish.credit and trySpend", function()
		it(
			"credit adds whole fish to the wallet, the lifetime count and stats.fishEarned",
			function()
				local profile = ProfileSchema.template(100)
				GoldenFish.credit(profile, 8)
				GoldenFish.credit(profile, 2.9)
				GoldenFish.credit(profile, 0)
				GoldenFish.credit(profile, -5)
				expect(profile.goldenFish).to.equal(10)
				expect(profile.lifetimeGoldenFish).to.equal(10)
				expect(profile.stats.fishEarned).to.equal(10)
			end
		)

		it(
			"trySpend takes fish only when the wallet holds them, and never touches the lifetime count",
			function()
				local profile = ProfileSchema.template(100)
				GoldenFish.credit(profile, 70)
				expect(GoldenFish.trySpend(profile, 60)).to.equal(true)
				expect(profile.goldenFish).to.equal(10)
				expect(GoldenFish.trySpend(profile, 60)).to.equal(false)
				expect(GoldenFish.trySpend(profile, -5)).to.equal(false)
				expect(profile.goldenFish).to.equal(10)
				expect(profile.lifetimeGoldenFish).to.equal(70)
			end
		)
	end)

	describe("Tip Jar step 12", function()
		it(
			"gives TipJarStep12Fish golden fish with its Caviar and spin; no other step gives fish",
			function()
				for _, def in Catalog.tipJar do
					expect(def.fish).to.equal(
						if def.step == 12 then Config.TipJarStep12Fish else nil
					)
				end
			end
		)
	end)

	describe("Catalog crates and the Golden Fish Market (F53 rows in save version 7)", function()
		it("has a crate and a golden crate for each zone and the Classic pool", function()
			expect(#Catalog.crates).to.equal(12)
			for _, pool in { "alley", "park", "neighbourhood", "woods", "sewer", "classic" } do
				expect(Catalog.cratePools[pool]).to.equal(true)
				local crate = Catalog.getCrate(pool .. "_crate")
				local golden = Catalog.getCrate(pool .. "_golden_crate")
				assert(crate and golden)
				expect(crate.area).to.equal(pool)
				expect(crate.golden).to.equal(false)
				expect(crate.price).to.equal(60)
				expect(golden.golden).to.equal(true)
				expect(golden.price).never.to.be.ok()
			end
		end)

		it("shows odds that add up to 100, and golden odds of Epic or better only", function()
			for _, def in Catalog.crates do
				local total = 0
				for _, rarity in Catalog.rarityOrder do
					total += def.odds[rarity] or 0
				end
				expect(total).to.be.near(100, 1e-9)
				if def.golden then
					expect((def.odds.Common or 0) + (def.odds.Rare or 0)).to.equal(0)
					expect(def.odds.Epic).to.equal(80)
				else
					expect(def.odds.Common).to.equal(60)
					expect(def.odds.Mythical).to.equal(0.5)
				end
			end
		end)

		it(
			"sells each priced crate, the Star Treat and three perks, and never a golden crate",
			function()
				for _, def in Catalog.crates do
					local row = Catalog.getFishShopRow(def.id)
					if def.golden then
						expect(row).never.to.be.ok()
					else
						assert(row)
						expect(row.kind).to.equal("crate")
						expect(row.cost).to.equal(def.price)
					end
				end
				local treat = Catalog.getFishShopRow("star_treat")
				assert(treat)
				expect(treat.kind).to.equal("lure")
				expect(treat.cost).to.equal(80)
				expect(Catalog.getLure("star_treat")).to.be.ok()
				local perks: { [string]: number } =
					{ golden_espresso = 5, big_bowl = 1, extra_decor_spot = 2 }
				for id, maxLevel in perks do
					local row = Catalog.getFishShopRow(id)
					assert(row and row.costs)
					expect(row.kind).to.equal("perk")
					expect(row.maxLevel).to.equal(maxLevel)
					expect(#row.costs).to.equal(maxLevel)
				end
			end
		)
	end)
end
