--!strict
-- Economy.luau against data-model v0.3.1 sections 5, 5b, 6, 7, 11 and 14, plus the ten minute loop in features.md
-- section 8. Rank up (F24) has its own block at the end; night income (F31) is in the income block.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)

	-- A fresh version 3 profile per data-model section 14, built by hand so these tests do not depend on
	-- ProfileSchema.template (which has its own spec).
	local function freshProfile(now: number?): any
		local t = now or 1000
		return {
			version = 3,
			coins = Config.StartCoins,
			lifetimeCoins = 0,
			lastTick = t,
			lastSeen = t,
			rateAtLogout = 0,
			tier = 1,
			upgradeLevels = {},
			decorOwned = {},
			decorPlaced = {},
			lures = {},
			bait = nil,
			dealer = { window = 0, bought = {} },
			fishPerks = {}, -- F52 (version 7), read by cafeMultiplier and lureWaitSeconds since F53
			indexRewards = {}, -- F48 (version 5), whose claimed bonuses cafeMultiplier adds since F54
			cats = {
				starter = {
					uid = "starter",
					catId = "tabby",
					variant = "base",
					caughtAt = t,
					spotId = "barista_1",
					method = "starter",
				},
			},
			collection = { tabby = t },
			goldCollection = {},
			stats = {},
			tutorialStep = 0,
			settings = { music = true, sfx = true },
		}
	end

	local function cat(uid: string, catId: string, spotId: string?, variant: string?): any
		return {
			uid = uid,
			catId = catId,
			variant = variant or "base",
			caughtAt = 0,
			spotId = spotId,
		}
	end

	describe("upgrade levels and start levels (sections 6 and 14)", function()
		it("espresso starts at 1, everything else at 0", function()
			local p = freshProfile()
			expect(Economy.level(p, "espresso")).to.equal(1)
			expect(Economy.level(p, "tables")).to.equal(0)
			expect(Economy.level(p, "net")).to.equal(0)
			expect(Economy.level(p, "lure_bowl")).to.equal(0)
		end)

		it("a saved level wins over the start level; removed and unknown ids are 0", function()
			local p = freshProfile()
			p.upgradeLevels.tables = 2
			expect(Economy.level(p, "tables")).to.equal(2)
			expect(Economy.level(p, "cafe_level")).to.equal(0)
			expect(Economy.level(p, "park_access")).to.equal(0)
			expect(Economy.level(p, "not_a_thing")).to.equal(0)
			expect((Economy :: any).cafeLevel).never.to.be.ok()
		end)
	end)

	describe("tier and tierMultiplier (section 5b)", function()
		it("reads the saved tier, 1 for a missing or damaged one, clamped to 1 to 5", function()
			local p = freshProfile()
			expect(Economy.tier(p)).to.equal(1)
			for _, case in ipairs({
				{ nil, 1 },
				{ 0 / 0, 1 },
				{ 0, 1 },
				{ -3, 1 },
				{ 2.7, 2 },
				{ 5, 5 },
				{ 9, 5 },
			}) do
				p.tier = case[1]
				expect(Economy.tier(p)).to.equal(case[2])
			end
			p.tier = "3"
			expect(Economy.tier(p)).to.equal(1)
		end)

		it("tierMultiplier is 1.00, 1.25, 1.50, 1.75 and 2.00", function()
			local p = freshProfile()
			for tier, multiplier in ipairs({ 1.00, 1.25, 1.50, 1.75, 2.00 }) do
				p.tier = tier
				expect(Economy.tierMultiplier(p)).to.be.near(multiplier, 1e-9)
			end
		end)

		it("multiplies the whole rate once: Tier 2 earns 25% more (F24 done-when)", function()
			local p = freshProfile()
			p.upgradeLevels.tables = 1
			local tier1 = Economy.incomePerSecond(p)
			expect(tier1).to.be.near(1.5 * 1.1, 1e-9)
			p.tier = 2
			expect(Economy.incomePerSecond(p)).to.be.near(tier1 * 1.25, 1e-9)
		end)
	end)

	describe(
		"cafeMultiplier = 1 + 0.10 x tables + 0.15 x (espresso - 1) + placed decor (section 11)",
		function()
			it("is 1.0 for a fresh profile", function()
				expect(Economy.cafeMultiplier(freshProfile())).to.be.near(1.0)
			end)

			it("adds 10% per table level", function()
				local p = freshProfile()
				p.upgradeLevels.tables = 1
				expect(Economy.cafeMultiplier(p)).to.be.near(1.10)
				p.upgradeLevels.tables = 6
				expect(Economy.cafeMultiplier(p)).to.be.near(1.60)
			end)

			it("adds 15% per espresso level above 1", function()
				local p = freshProfile()
				p.upgradeLevels.espresso = 3
				expect(Economy.cafeMultiplier(p)).to.be.near(1.30)
				p.upgradeLevels.espresso = 0 -- damaged save; must not go below 1.0
				expect(Economy.cafeMultiplier(p)).to.be.near(1.0)
			end)

			it("adds decor bonuses only while owned and placed", function()
				local p = freshProfile()
				p.decorPlaced.rug = true -- placed but never bought
				expect(Economy.cafeMultiplier(p)).to.be.near(1.0)
				p.decorOwned.rug = true
				expect(Economy.cafeMultiplier(p)).to.be.near(1.05)
				p.decorOwned.plants = true -- owned but stored
				expect(Economy.cafeMultiplier(p)).to.be.near(1.05)
				p.decorPlaced.plants = true
				p.decorOwned.neon_sign, p.decorPlaced.neon_sign = true, true
				p.decorOwned.fish_tank, p.decorPlaced.fish_tank = true, true
				expect(Economy.cafeMultiplier(p)).to.be.near(1.30)
				p.decorOwned.bogus, p.decorPlaced.bogus = true, true
				expect(Economy.cafeMultiplier(p)).to.be.near(1.30)
			end)

			it("everything maxed is 1 + 0.6 + 0.6 + 0.3 = 2.5", function()
				local p = freshProfile()
				p.upgradeLevels.tables = 6
				p.upgradeLevels.espresso = 5
				for _, def in ipairs(Catalog.decor) do
					if def.source ~= "index" then
						p.decorOwned[def.id] = true
						p.decorPlaced[def.id] = true
					end
				end
				expect(Economy.cafeMultiplier(p)).to.be.near(2.5)
			end)

			it("an Index piece is its zone's Epic crate piece: +8% while placed (F53, F54)", function()
				local p = freshProfile()
				p.decorOwned.index_alley = true
				expect(Economy.cafeMultiplier(p)).to.be.near(1.0)
				p.decorPlaced.index_alley = true
				expect(Economy.cafeMultiplier(p)).to.be.near(1.08)
				expect(next(Economy.replacedDecor(p))).never.to.be.ok()
			end)

			it("adds the tips forever of claimed Index milestones (F54)", function()
				local p = freshProfile()
				p.indexRewards.alley = { cats3 = true, cats6 = true, gold1 = true }
				expect(Economy.cafeMultiplier(p)).to.be.near(1.02) -- gold1 is gold luck, not tips
				p.indexRewards.decor_classic = { decor10 = true }
				expect(Economy.cafeMultiplier(p)).to.be.near(1.07)
			end)

			it("bait speed shortens the next bowl in whole seconds, 372 s on the full All Cats track (F54)", function()
				local p = freshProfile()
				expect(Economy.baitWaitSeconds(p)).to.equal(600)
				p.indexRewards.all = { total5 = true }
				expect(Economy.baitWaitSeconds(p)).to.equal(588)
				local all: { [string]: boolean } = {}
				for id in Catalog.indexPrizes.all do
					all[id] = true
				end
				p.indexRewards.all = all
				expect(Economy.baitWaitSeconds(p)).to.equal(372)
			end)

			it("crate and Index pieces are never for sale", function()
				local p = freshProfile()
				p.coins = 1e9
				p.tier = 5
				expect(Economy.decorBlocker(p, "index_park")).to.equal(
					"Found in Cafe Crates, not for sale"
				)
				expect(Economy.decorBlocker(p, "index_park_gold")).to.equal("Unknown decor")
				expect(Economy.decorBlocker(p, "rug")).never.to.be.ok()
			end)
		end
	)

	describe("catRate = rating x favorite role (section 11)", function()
		it("a Tabby as Barista (its favorite) earns 1.5, as Waiter 1", function()
			expect(Economy.catRate(cat("a", "tabby", "barista_1"))).to.be.near(1.5)
			expect(Economy.catRate(cat("a", "tabby", "barista_3"))).to.be.near(1.5)
			expect(Economy.catRate(cat("a", "tabby", "waiter_1"))).to.be.near(1.0)
		end)

		it("a Ninja Cat as Waiter earns 37.5, a Wizard Cat as Barista 112.5", function()
			expect(Economy.catRate(cat("a", "void", "waiter_1"))).to.be.near(37.5)
			expect(Economy.catRate(cat("a", "void", "entertainer_1"))).to.be.near(25)
			expect(Economy.catRate(cat("a", "midnight", "barista_1"))).to.be.near(112.5)
		end)

		it("resting cats, v0.2 spot ids, unknown spots and unknown cats earn nothing", function()
			expect(Economy.catRate(cat("a", "tabby", nil))).to.equal(0)
			expect(Economy.catRate(cat("a", "tabby", "counter_1"))).to.equal(0)
			expect(Economy.catRate(cat("a", "tabby", "throne_1"))).to.equal(0)
			expect(Economy.catRate(cat("a", "golden", "barista_1"))).to.equal(0)
		end)

		it("a gold cat earns 1.5x: a gold Tabby as Barista earns 2.25 (F30 done-when)", function()
			expect(Economy.variantMultiplier("base")).to.equal(1)
			expect(Economy.variantMultiplier("gold")).to.equal(1.5)
			expect(Economy.variantMultiplier("galaxy")).to.equal(1)
			expect(Economy.catRate(cat("a", "tabby", "barista_1", "gold"))).to.be.near(2.25)
			expect(Economy.catRate(cat("a", "tabby", "barista_1", "galaxy"))).to.be.near(1.5)
		end)

		it("v0.3: a rescued cat earns the normal rate", function()
			local rescued = cat("a", "tabby", "barista_1")
			rescued.rescued = true
			expect(Economy.catRate(rescued)).to.be.near(1.5)
		end)
	end)

	describe("incomePerSecond and settle (section 11)", function()
		it(
			"fresh profile earns 1.5 per second (the HUD must show a positive rate within 5 s)",
			function()
				expect(Economy.incomePerSecond(freshProfile())).to.be.near(1.5)
			end
		)

		it("sums working cats and applies the cafe and tier multipliers once", function()
			local p = freshProfile()
			p.cats.b = cat("b", "tuxedo", "waiter_1") -- favorite: 1.5
			p.cats.c = cat("c", "calico", nil) -- resting
			p.upgradeLevels.tables = 2 -- x1.2
			expect(Economy.incomePerSecond(p)).to.be.near((1.5 + 1.5) * 1.2)
			p.tier = 3
			expect(Economy.incomePerSecond(p)).to.be.near((1.5 + 1.5) * 1.2 * 1.5)
		end)

		it("settle credits rate x elapsed and moves lastTick", function()
			local p = freshProfile(1000)
			local earned = Economy.settle(p, 1010)
			expect(earned).to.be.near(15)
			expect(p.coins).to.be.near(65)
			expect(p.lifetimeCoins).to.be.near(15)
			expect(p.lastTick).to.equal(1010)
			expect(Economy.settle(p, 1010)).to.equal(0)
		end)

		it("settle never pays for negative elapsed time", function()
			local p = freshProfile(1000)
			expect(Economy.settle(p, 900)).to.equal(0)
			expect(p.coins).to.equal(Config.StartCoins)
		end)

		it("settle splits the window at phase boundaries, 0.6x by night (F31)", function()
			-- the clock started at os.time() 1000, so its first night begins at 1000 + ServerStartDaySeconds
			local epoch = 1000
			local dusk = epoch + Config.ServerStartDaySeconds
			local p = freshProfile(dusk - 20) -- 20 s of day, then 30 s of night
			local earned = Economy.settle(p, dusk + 30, epoch)
			expect(earned).to.be.near(1.5 * (20 + 30 * Config.NightIncomeMultiplier))
			expect(p.lastTick).to.equal(dusk + 30)
			-- all night: 0.6x; and back to day at dawn (each settle grants XP, so read the rate before each)
			local dawn = dusk + Config.NightLengthSeconds
			p.lastTick = dawn - 10
			local rate = Economy.incomePerSecond(p)
			expect(Economy.settle(p, dawn, epoch)).to.be.near(
				rate * 10 * Config.NightIncomeMultiplier
			)
			rate = Economy.incomePerSecond(p)
			expect(Economy.settle(p, dawn + 10, epoch)).to.be.near(rate * 10)
			-- without the clock the whole window pays the day rate
			p.lastTick = dusk
			rate = Economy.incomePerSecond(p)
			expect(Economy.settle(p, dusk + 10)).to.be.near(rate * 10)
		end)

		it("phaseMultiplier is 1 by day and NightIncomeMultiplier by night", function()
			expect(Economy.phaseMultiplier("day")).to.equal(1)
			expect(Economy.phaseMultiplier("night")).to.equal(Config.NightIncomeMultiplier)
		end)

		it("a rich tip is RichTipSeconds of the day rate, at least $50 (section 12)", function()
			expect(Economy.richTipAmount(1)).to.equal(50)
			expect(Economy.richTipAmount(1.5)).to.equal(67)
			expect(Economy.richTipAmount(10)).to.equal(450)
			expect(Economy.richTipAmount(33.3)).to.equal(math.floor(33.3 * Config.RichTipSeconds))
		end)
	end)

	describe("offlineGain = day rate x 0.25 x min(elapsed, 3600) (section 11)", function()
		it("pays a quarter rate for the time away", function()
			local gain, seconds = Economy.offlineGain(10, 1000, 1300)
			expect(gain).to.equal(750)
			expect(seconds).to.equal(300)
		end)

		it("caps at one hour", function()
			local gain, seconds = Economy.offlineGain(10, 0, 50000)
			expect(seconds).to.equal(3600)
			expect(gain).to.equal(9000)
		end)

		it("floors to whole coins and never goes negative", function()
			local gain = Economy.offlineGain(1.5, 1000, 1007) -- 1.5 x 0.25 x 7 = 2.625
			expect(gain).to.equal(2)
			local back, seconds = Economy.offlineGain(10, 2000, 1000)
			expect(back).to.equal(0)
			expect(seconds).to.equal(0)
		end)

		it("loop step 8: 10 minutes away at 2.75 per second shows 412 coins", function()
			expect(Economy.offlineGain(2.75, 0, 600)).to.equal(412)
		end)
	end)

	describe("spending", function()
		it("canAfford: exact amount yes, one short no, negative cost never", function()
			local p = freshProfile()
			expect(Economy.canAfford(p, 50)).to.equal(true)
			expect(Economy.canAfford(p, 51)).to.equal(false)
			expect(Economy.canAfford(p, 0)).to.equal(true)
			expect(Economy.canAfford(p, -1)).to.equal(false)
		end)

		it("trySpend only takes coins when affordable", function()
			local p = freshProfile()
			expect(Economy.trySpend(p, 60)).to.equal(false)
			expect(p.coins).to.equal(50)
			expect(Economy.trySpend(p, 50)).to.equal(true)
			expect(p.coins).to.equal(0)
			expect(Economy.trySpend(p, -5)).to.equal(false)
			expect(p.coins).to.equal(0)
		end)

		it("credit adds to coins and lifetimeCoins", function()
			local p = freshProfile()
			Economy.credit(p, 25)
			expect(p.coins).to.equal(75)
			expect(p.lifetimeCoins).to.equal(25)
		end)
	end)

	describe("upgrade costs and tier caps (sections 5b and 6)", function()
		it("next cost is costs[level + 1], nil when maxed, removed or unknown", function()
			local p = freshProfile()
			expect(Economy.nextUpgradeCost(p, "tables")).to.equal(150)
			expect(Economy.nextUpgradeCost(p, "espresso")).to.equal(2000)
			expect(Economy.nextUpgradeCost(p, "net")).to.equal(2500)
			expect(Economy.nextUpgradeCost(p, "lure_bowl")).to.equal(600)
			p.upgradeLevels.net = 1
			expect(Economy.nextUpgradeCost(p, "net")).to.equal(25000)
			p.upgradeLevels.tables = 6
			expect(Economy.nextUpgradeCost(p, "tables")).never.to.be.ok()
			expect(Economy.nextUpgradeCost(p, "cafe_level")).never.to.be.ok()
			expect(Economy.nextUpgradeCost(p, "jetpack")).never.to.be.ok()
		end)

		it("fresh profile: Tables is not affordable at 50 coins (150, v0.13.6)", function()
			local p = freshProfile()
			expect(Economy.upgradeBlocker(p, "tables")).to.equal("Not enough coins")
			p.coins = 150
			expect(Economy.upgradeBlocker(p, "tables")).never.to.be.ok()
		end)

		it("the Bait bowl needs no tier: Tier 1 can buy it at 600 (loop step 5, v0.13.6)", function()
			local p = freshProfile()
			expect(Economy.upgradeBlocker(p, "lure_bowl")).to.equal("Not enough coins")
			p.coins = 600
			expect(Economy.upgradeBlocker(p, "lure_bowl")).never.to.be.ok()
			p.upgradeLevels.lure_bowl = 1
			expect(Economy.upgradeBlocker(p, "lure_bowl")).to.equal("Already maxed")
		end)

		it(
			"every capped level asks for its tier, and the tier check comes before the coin check",
			function()
				-- upgrade -> { level, tier needed for the next level }
				local cases: { { any } } = {
					{ "tables", 0, nil },
					{ "tables", 1, nil },
					{ "tables", 2, 2 },
					{ "tables", 3, 2 },
					{ "tables", 4, 3 },
					{ "tables", 5, 3 },
					{ "espresso", 1, nil },
					{ "espresso", 2, 2 },
					{ "espresso", 3, 3 },
					{ "espresso", 4, 4 },
					{ "net", 0, nil },
					{ "net", 1, 2 },
					{ "net", 2, 3 },
				}
				for _, case in ipairs(cases) do
					local id, level, needs = case[1], case[2], case[3]
					local p = freshProfile()
					p.upgradeLevels[id] = level
					p.coins = 0
					if needs == nil then
						expect(Economy.upgradeBlocker(p, id)).to.equal("Not enough coins")
					else
						expect(Economy.upgradeBlocker(p, id)).to.equal(
							string.format("Needs Tier %d", needs)
						)
						p.tier = needs - 1
						if needs - 1 >= 1 then
							expect(Economy.upgradeBlocker(p, id)).to.equal(
								string.format("Needs Tier %d", needs)
							)
						end
						p.tier = needs
						expect(Economy.upgradeBlocker(p, id)).to.equal("Not enough coins")
					end
					p.coins = 1000000
					p.tier = needs or 1
					expect(Economy.upgradeBlocker(p, id)).never.to.be.ok()
				end
			end
		)

		it("at Tier 5 everything can go to its max level and then says Already maxed", function()
			local p = freshProfile()
			p.tier = 5
			p.coins = 1000000
			for _, def in ipairs(Catalog.upgrades) do
				p.upgradeLevels[def.id] = def.maxLevel - 1
				expect(Economy.upgradeBlocker(p, def.id)).never.to.be.ok()
				p.upgradeLevels[def.id] = def.maxLevel
				expect(Economy.upgradeBlocker(p, def.id)).to.equal("Already maxed")
			end
		end)

		it("removed and unknown upgrades are refused", function()
			expect(Economy.upgradeBlocker(freshProfile(), "jetpack")).to.equal("Unknown upgrade")
			expect(Economy.upgradeBlocker(freshProfile(), "cafe_level")).to.equal("Unknown upgrade")
			expect(Economy.upgradeBlocker(freshProfile(), "park_access")).to.equal(
				"Unknown upgrade"
			)
		end)
	end)

	describe("decor blockers (section 7)", function()
		it("refuses unknown, owned, gated and unaffordable decor in that order", function()
			local p = freshProfile()
			expect(Economy.decorBlocker(p, "lava_lamp")).to.equal("Unknown decor")
			expect(Economy.decorBlocker(p, "plants")).to.equal("Needs Tier 2")
			p.tier = 2
			expect(Economy.decorBlocker(p, "plants")).to.equal("Not enough coins")
			p.coins = 4000
			expect(Economy.decorBlocker(p, "plants")).never.to.be.ok()
			p.decorOwned.plants = true
			expect(Economy.decorBlocker(p, "plants")).to.equal("Already owned")
			p.coins = 1000000
			expect(Economy.decorBlocker(p, "neon_sign")).to.equal("Needs Tier 3")
			expect(Economy.decorBlocker(p, "fish_tank")).to.equal("Needs Tier 4")
			p.tier = 3
			expect(Economy.decorBlocker(p, "neon_sign")).never.to.be.ok()
			expect(Economy.decorBlocker(p, "fish_tank")).to.equal("Needs Tier 4")
			p.tier = 4
			expect(Economy.decorBlocker(p, "fish_tank")).never.to.be.ok()
		end)
	end)

	describe("role slots (section 5)", function()
		it("slots open by tier: two at Tier 1, all ten at Tier 5", function()
			local p = freshProfile()
			expect(Economy.spotIsOpen(p, "barista_1")).to.equal(true)
			expect(Economy.spotIsOpen(p, "waiter_1")).to.equal(true)
			expect(Economy.spotIsOpen(p, "waiter_2")).to.equal(false)
			expect(Economy.spotIsOpen(p, "greeter_1")).to.equal(false)
			expect(Economy.spotIsOpen(p, "counter_1")).to.equal(false)
			expect(Economy.spotIsOpen(p, "nowhere_1")).to.equal(false)
			for tier = 1, 5 do
				p.tier = tier
				local open = 0
				for _, spot in ipairs(Catalog.spots) do
					if Economy.spotIsOpen(p, spot.id) then
						open += 1
					end
				end
				expect(open).to.equal(tier * 2)
			end
		end)

		it("catOnSpot finds the occupant", function()
			local p = freshProfile()
			local occupant = Economy.catOnSpot(p, "barista_1")
			expect(occupant).to.be.ok()
			assert(occupant)
			expect(occupant.uid).to.equal("starter")
			expect(Economy.catOnSpot(p, "waiter_1")).never.to.be.ok()
		end)
	end)

	describe("seats and counts", function()
		it("seats = 2 x tables", function()
			local p = freshProfile()
			expect(Economy.seats(p)).to.equal(0)
			p.upgradeLevels.tables = 3
			expect(Economy.seats(p)).to.equal(6)
		end)

		it("countsByCat groups owned cats", function()
			local p = freshProfile()
			p.cats.b = cat("b", "tabby", nil)
			p.cats.c = cat("c", "void", "waiter_1")
			expect(Economy.countsByCat(p)).to.deepEqual({
				tabby = { count = 2 },
				void = { count = 1 },
			})
		end)
	end)

	describe("features.md section 8: the ten minute loop in numbers (v0.3)", function()
		it("step 1: $50 and 1.5 per second with the Tabby as Barista", function()
			local p = freshProfile()
			expect(p.coins).to.equal(50)
			expect(Economy.incomePerSecond(p)).to.be.near(1.5)
		end)

		it(
			"step 4: a caught Common as Waiter raises the rate to 2.5, or 3.0 if it loves waiting",
			function()
				local p = freshProfile()
				local before = Economy.incomePerSecond(p)
				p.cats.new = cat("new", "ginger", "waiter_1")
				expect(Economy.incomePerSecond(p) > before).to.equal(true)
				expect(Economy.incomePerSecond(p)).to.be.near(2.5)
				p.cats.new = cat("new", "tuxedo", "waiter_1")
				expect(Economy.incomePerSecond(p)).to.be.near(3.0)
			end
		)

		it("step 5: Table 1 costs $150 (v0.13.6) and raises the rate by exactly 10%", function()
			local p = freshProfile()
			p.cats.new = cat("new", "ginger", "waiter_1")
			local before = Economy.incomePerSecond(p)
			p.coins = 150
			expect(Economy.nextUpgradeCost(p, "tables")).to.equal(150)
			expect(Economy.upgradeBlocker(p, "tables")).never.to.be.ok()
			expect(Economy.trySpend(p, 150)).to.equal(true)
			p.upgradeLevels.tables = 1
			expect(Economy.incomePerSecond(p)).to.be.near(before * 1.1)
		end)

		it(
			"reaching Table 1 from the start takes about a minute at the starter rate (67 s at $150, v0.13.6)",
			function()
				-- Balance guard: if this jumps past ~2 minutes the tutorial beat 'buy a table' is too slow. QA: the cost
				-- comes from the Catalog, so a price change is checked here too.
				local p = freshProfile(0)
				local seconds = (Catalog.upgradesById.tables.costs[1] - p.coins) / Economy.incomePerSecond(p)
				expect(seconds <= 120).to.equal(true)
			end
		)

		it(
			"step 7: two tables, the bait bowl and Kibble are affordable inside 10 minutes",
			function()
				local p = freshProfile(0)
				p.cats.new = cat("new", "ginger", "waiter_1")
				p.upgradeLevels.tables = 1
				p.coins = 0
				Economy.settle(p, 600 - 90) -- rough: 90 s spent walking and catching
				local tables = Catalog.upgradesById.tables.costs
				local spend = tables[1] + tables[2] + Catalog.upgradesById.lure_bowl.costs[1] + Catalog.luresById.kibble.cost
				expect(p.coins >= spend).to.equal(true)
			end
		)

		it(
			"Tier 2's coins after the loop's purchases take more than 10 minutes on cafe income alone (v0.13.6)",
			function()
				-- Balance guard at the loop's end rates: two Commons and two tables earn 3.0 or 3.6 per second. Since
				-- v0.13.6 (Derek 01:38: "you can max out almost instantly every unlock") Tier 2 waits on coins after the
				-- cats are ready at about 9 minutes, so cafe income alone must not reach it inside 10. The 20 minute top
				-- of features section 8's window is the data-model 11 pace model's (16 min with first catch rewards,
				-- Index coins and the Tip Jar), which this income-only sum leaves out; the S14 playtest times it. QA:
				-- every cost comes from the Catalog (this guard read 1,500 and the old prices until v0.13.6).
				local tables = Catalog.upgradesById.tables.costs
				local spend = tables[1]
					+ tables[2]
					+ Catalog.upgradesById.lure_bowl.costs[1]
					+ Catalog.luresById.kibble.cost
					+ Catalog.tiers[2].cost
					- Config.StartCoins
				for _, rate in ipairs({ 2.5 * 1.2, 3.0 * 1.2 }) do
					local minutes = spend / rate / 60
					expect(minutes >= 10).to.equal(true)
				end
			end
		)

		it("every rank up costs at least five times the one before (QA, v0.13.6 pace)", function()
			-- data-model 11, pace v0.13.6: income grows about five times a tier, and the old costs, growing about four
			-- times, let every tier's shop be bought the moment it opened. A rank up cheaper than that is Derek's
			-- 01:38 "max out almost instantly" again.
			for tier = 3, Catalog.maxTier do
				local ratio = Catalog.tiers[tier].cost / Catalog.tiers[tier - 1].cost
				if ratio < 5 then
					error(string.format("Tier %d costs only %.2f times Tier %d", tier, ratio, tier - 1))
				end
			end
			expect(Catalog.tiers[2].cost >= 5000).to.equal(true)
		end)
	end)
	describe("rank up (F24, section 5b)", function()
		-- Cat ids of one rarity, in catalog order.
		local function idsOf(rarity: string): { string }
			local ids = {}
			for _, def in Catalog.cats do
				if def.rarity == rarity then
					table.insert(ids, def.id)
				end
			end
			return ids
		end

		-- A profile at `tier` whose collection holds `count` different cats: `needed` of `rarity` first (if any),
		-- then Commons, Rares and Epics that are not `rarity`, so the rarity count stays exact.
		local function profileWith(
			tier: number,
			count: number,
			rarity: string?,
			needed: number?,
			coins: number?
		): any
			local p = freshProfile()
			p.tier = tier
			p.coins = coins or 1e9
			p.collection = {}
			local added = 0
			if rarity ~= nil then
				for index, id in idsOf(rarity) do
					if index > (needed or 0) or added >= count then
						break
					end
					p.collection[id] = 1000
					added += 1
				end
			end
			for _, fillRarity in { "Common", "Rare", "Epic" } do
				if fillRarity ~= rarity then
					for _, id in idsOf(fillRarity) do
						if added >= count then
							break
						end
						p.collection[id] = 1000
						added += 1
					end
				end
			end
			assert(added == count, "not enough catalog cats for the test profile")
			return p
		end

		it(
			"distinctCats counts collection entries: owned cats, sold cats and shinies change nothing",
			function()
				local p = freshProfile()
				expect(Economy.distinctCats(p)).to.equal(1) -- the starter Tabby
				p.collection.ginger = 1000
				p.collection.tuxedo = 1000
				expect(Economy.distinctCats(p)).to.equal(3)
				-- A gold copy of a cat already in the collection is not a second entry.
				p.goldCollection.tabby = 1000
				p.cats.gold = cat("gold", "tabby", nil, "gold")
				expect(Economy.distinctCats(p)).to.equal(3)
				-- Selling every cat keeps the collection.
				p.cats = {}
				expect(Economy.distinctCats(p)).to.equal(3)
			end
		)

		it("distinctCatsAtLeast counts that rarity or rarer and skips unknown ids", function()
			local p = profileWith(3, 12, "Epic", 1)
			p.collection.not_a_cat = 1000
			expect(Economy.distinctCatsAtLeast(p, "Epic")).to.equal(1)
			expect(Economy.distinctCatsAtLeast(p, "Legendary")).to.equal(0)
			expect(Economy.distinctCatsAtLeast(p, "Common")).to.equal(12)
			p.collection[idsOf("Mythical")[1]] = 1000
			expect(Economy.distinctCatsAtLeast(p, "Epic")).to.equal(2)
			expect(Economy.distinctCatsAtLeast(p, "Legendary")).to.equal(1)
		end)

		it("Tier 1 to 2: 5 different cats and 8,000 coins (v0.13.6), the starter Tabby counts", function()
			local p = freshProfile()
			p.coins = 8000
			for _, id in { "ginger", "tuxedo", "smoke" } do
				p.collection[id] = 1000
			end
			expect(Economy.rankUpBlocker(p)).to.equal("Needs 5 different cats (you have 4)")
			p.collection.calico = 1000
			expect(Economy.rankUpBlocker(p)).never.to.be.ok()
			p.coins = 7999
			expect(Economy.rankUpBlocker(p)).to.equal("Not enough coins")
		end)

		it(
			"Tier 2 to 3 needs one Epic or better; 3 to 4 one Legendary or better; 4 to 5 two of them",
			function()
				expect(Economy.rankUpBlocker(profileWith(2, 12))).to.equal(
					"Needs one cat, Epic or better"
				)
				expect(Economy.rankUpBlocker(profileWith(2, 12, "Epic", 1))).never.to.be.ok()
				expect(Economy.rankUpBlocker(profileWith(3, 20, "Epic", 3))).to.equal(
					"Needs one cat, Legendary or better"
				)
				expect(Economy.rankUpBlocker(profileWith(3, 20, "Legendary", 1))).never.to.be.ok()
				expect(Economy.rankUpBlocker(profileWith(4, 30, "Legendary", 1))).to.equal(
					"Needs 2 different cats, Legendary or better"
				)
				expect(Economy.rankUpBlocker(profileWith(4, 30, "Legendary", 2))).never.to.be.ok()
			end
		)

		it("a gold copy of the one Legendary does not count as a second Legendary", function()
			local p = profileWith(4, 30, "Legendary", 1)
			local legendary = idsOf("Legendary")[1]
			p.goldCollection[legendary] = 1000
			p.cats.goldLegend = cat("goldLegend", legendary, nil, "gold")
			expect(Economy.rankUpBlocker(p)).to.equal("Needs 2 different cats, Legendary or better")
		end)

		it(
			"a rarer cat counts for the rarity asked (section 5b: or better, reviewer N44)",
			function()
				expect(Economy.rankUpBlocker(profileWith(2, 12, "Mythical", 1))).never.to.be.ok()
				expect(Economy.rankUpBlocker(profileWith(3, 20, "Mythical", 1))).never.to.be.ok()
				-- Tier 5: a Legendary plus a Mythical are two different cats, Legendary or better.
				local p = profileWith(4, 30, "Legendary", 1)
				p.collection[idsOf("Mythical")[1]] = 1000
				expect(Economy.rankUpBlocker(p)).never.to.be.ok()
			end
		)

		it(
			"reasons come in the order a player works through them: cats, then the rarity, then coins",
			function()
				expect(Economy.rankUpBlocker(profileWith(2, 11, nil, nil, 0))).to.equal(
					"Needs 12 different cats (you have 11)"
				)
				expect(Economy.rankUpBlocker(profileWith(2, 12, nil, nil, 0))).to.equal(
					"Needs one cat, Epic or better"
				)
				expect(Economy.rankUpBlocker(profileWith(2, 12, "Epic", 1, 0))).to.equal(
					"Not enough coins"
				)
			end
		)

		it(
			"every tier step passes at exactly its minimum and fails one cat or one coin short",
			function()
				for from = 1, Catalog.maxTier - 1 do
					local nextTier = Catalog.getTier(from + 1)
					assert(nextTier)
					local rarity = nextTier.needsRarity
					local needed = if rarity ~= nil then nextTier.needsRarityCount or 1 else nil
					local count = math.max(nextTier.distinctCats, needed or 0)
					expect(
						Economy.rankUpBlocker(
							profileWith(from, count, rarity, needed, nextTier.cost)
						)
					).never.to.be.ok()
					expect(
						Economy.rankUpBlocker(
							profileWith(from, count, rarity, needed, nextTier.cost - 1)
						)
					).to.equal("Not enough coins")
					if count > 0 then
						local short = Economy.rankUpBlocker(
							profileWith(from, count - 1, rarity, needed, nextTier.cost)
						)
						expect(short).to.be.ok()
						expect(short).never.to.equal("Not enough coins")
					end
				end
			end
		)

		it("at Tier 5 there is nothing left, whatever the coins", function()
			local p = profileWith(5, 40, "Legendary", 5)
			expect(Economy.rankUpBlocker(p)).to.equal("Your cafe is already a Grand Cafe")
			p.tier = 99 -- clamped like Economy.tier
			expect(Economy.rankUpBlocker(p)).to.equal("Your cafe is already a Grand Cafe")
		end)

		it("a damaged tier reads the way Economy.tier does (0 and 1.5 are Tier 1)", function()
			for _, damaged in { 0, -3, 1.5 } do
				local p = freshProfile()
				p.tier = damaged
				p.coins = 1e9
				expect(Economy.rankUpBlocker(p)).to.equal("Needs 5 different cats (you have 1)")
			end
		end)

		it("only reads the profile: coins, tier and collection are unchanged", function()
			local p = profileWith(2, 12, "Epic", 1, 8000)
			local before = Economy.distinctCats(p)
			Economy.rankUpBlocker(p)
			expect(p.coins).to.equal(8000)
			expect(p.tier).to.equal(2)
			expect(Economy.distinctCats(p)).to.equal(before)
		end)
	end)
end
