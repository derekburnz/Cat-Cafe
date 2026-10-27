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

	-- QA edges (qa-playtester): the numbers come from golden-fish.md, not from Config, so a Config change that
	-- drifts from the design fails here and the designer decides which one is right.
	describe("GoldenFish edges (QA)", function()
		local FIRST: { [string]: number } =
			{ Common = 1, Rare = 3, Epic = 8, Legendary = 20, Mythical = 40 }
		local REPEAT: { [string]: number } = { Epic = 1, Legendary = 3, Mythical = 8 }
		local seed = 20261027
		local function roll(n: number): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed % n + 1
		end

		it("has a first-catch row for every rarity the catalog can roll", function()
			for _, rarity in Catalog.rarityOrder do
				expect(FIRST[rarity] ~= nil).to.equal(true)
				expect(Config.FishFirstCatch[rarity]).to.equal(FIRST[rarity])
				expect(Config.FishRepeatCatch[rarity]).to.equal(REPEAT[rarity])
			end
		end)

		it(
			"pays every rarity, Index state and way of finding a cat as section 2's table says",
			function()
				local rarities: { string } = {}
				for _, rarity in Catalog.rarityOrder do
					table.insert(rarities, rarity)
				end
				for _, odd in { "Secret", "", "common", "Gold" } do
					table.insert(rarities, odd)
				end
				local methods: { any } =
					{ "net", "rescue", "bait", "starter", "NET", "spin", "", 7 }
				for _, rarity in rarities do
					local first = FIRST[rarity] or 0
					for _, isNew in { true, false } do
						for _, firstGold in { true, false } do
							for _, method in methods do
								local want = (if isNew then first else 0)
									+ (if firstGold then 2 * first else 0)
								if want == 0 and (method == "net" or method == "rescue") then
									want = REPEAT[rarity] or 0
								end
								local got = GoldenFish.forCatch(rarity, isNew, firstGold, method)
								if got ~= want then
									error(
										string.format(
											"forCatch(%q, %s, %s, %s) gave %s, want %d",
											rarity,
											tostring(isNew),
											tostring(firstGold),
											tostring(method),
											tostring(got),
											want
										)
									)
								end
							end
						end
					end
				end
			end
		)

		it(
			"pays one cat by bait at most its first catch plus its first gold, however often it comes",
			function()
				for _, rarity in Catalog.rarityOrder do
					for _ = 1, 40 do
						local seen, goldSeen, total, sawGold = false, false, 0, false
						for _ = 1, 30 do
							local gold = roll(4) == 1
							sawGold = sawGold or gold
							total += GoldenFish.forCatch(
								rarity,
								not seen,
								gold and not goldSeen,
								"bait"
							)
							seen = true
							goldSeen = goldSeen or gold
						end
						expect(total).to.equal(
							FIRST[rarity] + (if sawGold then 2 * FIRST[rarity] else 0)
						)
					end
				end
			end
		)

		it("pays rank ups only on whole Tiers 2 to 5, 185 fish in all", function()
			local total = 0
			for tier = 2, 5 do
				total += GoldenFish.forRankUp(tier)
			end
			expect(total).to.equal(185)
			expect(GoldenFish.forRankUp(2.0)).to.equal(10)
			for _, odd in { 0, -1, 1.5, 2.5, 5.0001, 0 / 0, math.huge, -math.huge, 1e9 } do
				expect(GoldenFish.forRankUp(odd)).to.equal(0)
			end
		end)

		it(
			"keeps the wallet at earned minus spent over 3,000 seeded credits and Market buys",
			function()
				local costs: { number } = { 0 }
				for _, row in Catalog.fishShop do
					if row.cost then
						table.insert(costs, row.cost)
					end
					for _, cost in row.costs or {} do
						table.insert(costs, cost)
					end
				end
				local earnings: { number } = { 0, -3, 0.999, 1, 2.9, 5, 8, 40, 100, 250 }
				local profile = ProfileSchema.template(100)
				local earned, spent = 0, 0
				for _ = 1, 3000 do
					if roll(2) == 1 then
						local amount = earnings[roll(#earnings)]
						GoldenFish.credit(profile, amount)
						earned += math.max(0, math.floor(amount))
					else
						local cost = costs[roll(#costs)]
						local had = profile.goldenFish
						local ok = GoldenFish.trySpend(profile, cost)
						expect(ok).to.equal(had >= cost)
						if ok then
							spent += cost
						end
					end
					expect(profile.lifetimeGoldenFish).to.equal(earned)
					expect(profile.stats.fishEarned).to.equal(earned)
					expect(profile.goldenFish).to.equal(earned - spent)
					expect(profile.goldenFish >= 0 and profile.goldenFish % 1 == 0).to.equal(true)
				end
			end
		)

		it("spends an exact balance to 0 and refuses one fish short", function()
			local profile = ProfileSchema.template(100)
			GoldenFish.credit(profile, 59)
			expect(GoldenFish.trySpend(profile, 60)).to.equal(false)
			expect(profile.goldenFish).to.equal(59)
			GoldenFish.credit(profile, 1)
			expect(GoldenFish.trySpend(profile, 60)).to.equal(true)
			expect(profile.goldenFish).to.equal(0)
			expect(GoldenFish.trySpend(profile, 0)).to.equal(true)
			expect(profile.goldenFish).to.equal(0)
		end)

		it("prices the Market as section 3 lists, each perk level dearer than the last", function()
			local want: { [string]: { number } } = {
				star_treat = { 80 },
				golden_espresso = { 40, 80, 150, 250, 400 },
				big_bowl = { 150 },
				extra_decor_spot = { 100, 250 },
			}
			for _, def in Catalog.crates do
				if not def.golden then
					want[def.id] = { 60 }
				end
			end
			local kinds = { crate = true, lure = true, perk = true }
			for _, row in Catalog.fishShop do
				expect(kinds[row.kind]).to.equal(true)
				local prices: { number } = if row.costs then row.costs else { row.cost :: number }
				expect(prices :: any).to.deepEqual(want[row.id])
				for level = 2, #prices do
					expect(prices[level] > prices[level - 1]).to.equal(true)
				end
			end
			for id in want do
				expect(Catalog.getFishShopRow(id)).to.be.ok()
			end
		end)

		it("gives every crate section 4's rarity odds, plain and golden", function()
			local plain = { Common = 60, Rare = 27, Epic = 10, Legendary = 2.5, Mythical = 0.5 }
			local golden = { Common = 0, Rare = 0, Epic = 80, Legendary = 17.5, Mythical = 2.5 }
			for _, def in Catalog.crates do
				local want: { [string]: number } = if def.golden then golden else plain
				for _, rarity in Catalog.rarityOrder do
					expect(def.odds[rarity] or 0).to.equal(want[rarity])
				end
			end
		end)

		it(
			"keeps section 4's promise: about 40 crates to a Legendary and 190 to a Mythical with the lucky twentieth",
			function()
				-- Opens since the last Epic or better: 0 to CrateLuckyEvery - 1, and the last one opens on golden odds.
				-- E[k] = 1 + P(Common or Rare) E[k + 1] + P(other Epic or better) E[0], solved as E[k] = a + b E[0].
				local plain = assert(Catalog.getCrate("alley_crate")).odds
				local golden = assert(Catalog.getCrate("alley_golden_crate")).odds
				local last = Config.CrateLuckyEvery - 1
				local function opensTo(target: string): number
					local a, b = 0, 0
					for k = last, 0, -1 do
						local odds = if k == last then golden else plain
						local low = ((odds.Common or 0) + (odds.Rare or 0)) / 100
						local reset = 0
						for _, rarity in { "Epic", "Legendary", "Mythical" } do
							if rarity ~= target then
								reset += (odds[rarity] or 0) / 100
							end
						end
						if k == last then
							a, b = 1, reset -- golden odds hold no Common or Rare
						else
							a, b = 1 + low * a, low * b + reset
						end
					end
					return a / (1 - b)
				end
				local legendary, mythical = opensTo("Legendary"), opensTo("Mythical")
				expect(legendary >= 35 and legendary <= 42).to.equal(true)
				expect(mythical >= 180 and mythical <= 200).to.equal(true)
			end
		)
	end)
end
