--!strict
-- Economy.luau against data-model sections 5, 6, 11 and 14, plus the ten minute loop numbers in features.md section 8.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)

	-- A fresh profile per data-model section 14. Built here because the engineer's DataService
	-- (which owns the real template) needs DataStoreService and is Studio-only.
	local function freshProfile(now: number?)
		local t = now or 1000
		return {
			version = 1,
			coins = Config.StartCoins,
			lifetimeCoins = 0,
			lastTick = t,
			lastSeen = t,
			rateAtLogout = 0,
			upgradeLevels = {},
			decorOwned = {},
			decorPlaced = {},
			lures = {},
			equippedLure = nil,
			cats = { starter = { uid = "starter", catId = "tabby", variant = "base", caughtAt = t, spotId = "counter_1" } },
			collection = { tabby = t },
			stats = { catsCaught = 0, catsSold = 0, grabsAttempted = 0, grabsSucceeded = 0, luresUsed = 0, playtimeSeconds = 0, sessions = 0 },
			tutorialStep = 0,
			settings = { music = true, sfx = true },
		}
	end

	local function cat(uid: string, catId: string, spotId: string?, variant: string?)
		return { uid = uid, catId = catId, variant = variant or "base", caughtAt = 0, spotId = spotId }
	end

	describe("upgrade levels and start levels (sections 6 and 14)", function()
		it("cafe_level and espresso start at 1, everything else at 0", function()
			local p = freshProfile()
			expect(Economy.level(p, "cafe_level")).to.equal(1)
			expect(Economy.level(p, "espresso")).to.equal(1)
			expect(Economy.level(p, "tables")).to.equal(0)
			expect(Economy.level(p, "gloves")).to.equal(0)
			expect(Economy.level(p, "lure_bowl")).to.equal(0)
			expect(Economy.level(p, "park_access")).to.equal(0)
			expect(Economy.cafeLevel(p)).to.equal(1)
		end)

		it("a saved level wins over the start level, unknown ids are 0", function()
			local p = freshProfile()
			p.upgradeLevels.cafe_level = 3
			expect(Economy.cafeLevel(p)).to.equal(3)
			expect(Economy.level(p, "not_a_thing")).to.equal(0)
		end)
	end)

	describe("cafeMultiplier = 1 + 0.10 x tables + 0.15 x (espresso - 1) + placed decor (section 11)", function()
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

		it("everything maxed is 1 + 0.6 + 0.3 + 0.3 = 2.2", function()
			local p = freshProfile()
			p.upgradeLevels.tables = 6
			p.upgradeLevels.espresso = 3
			for _, def in ipairs(Catalog.decor) do
				p.decorOwned[def.id] = true
				p.decorPlaced[def.id] = true
			end
			expect(Economy.cafeMultiplier(p)).to.be.near(2.2)
		end)
	end)

	describe("catRate = rarity rate x variant x favorite (section 11)", function()
		it("a Tabby on the counter (its favorite) earns 1.5, on the window 1", function()
			expect(Economy.catRate(cat("a", "tabby", "counter_1"))).to.be.near(1.5)
			expect(Economy.catRate(cat("a", "tabby", "window_1"))).to.be.near(1.0)
		end)

		it("a Void on the shelf earns 37.5", function()
			expect(Economy.catRate(cat("a", "void", "shelf_1"))).to.be.near(37.5)
			expect(Economy.catRate(cat("a", "void", "counter_1"))).to.be.near(25)
		end)

		it("resting cats, unknown spots and unknown cats earn nothing", function()
			expect(Economy.catRate(cat("a", "tabby", nil))).to.equal(0)
			expect(Economy.catRate(cat("a", "tabby", "throne_1"))).to.equal(0)
			expect(Economy.catRate(cat("a", "golden", "counter_1"))).to.equal(0)
		end)

		it("variants multiply: golden 2x, galaxy 5x, anything else 1x", function()
			expect(Economy.variantMultiplier("base")).to.equal(1)
			expect(Economy.variantMultiplier("golden")).to.equal(2)
			expect(Economy.variantMultiplier("galaxy")).to.equal(5)
			expect(Economy.variantMultiplier("sparkly")).to.equal(1)
			expect(Economy.catRate(cat("a", "tabby", "counter_1", "galaxy"))).to.be.near(7.5)
		end)
	end)

	describe("incomePerSecond and settle (section 11)", function()
		it("fresh profile earns 1.5 per second (the HUD must show a positive rate within 5 s)", function()
			expect(Economy.incomePerSecond(freshProfile())).to.be.near(1.5)
		end)

		it("sums placed cats and applies the cafe multiplier once", function()
			local p = freshProfile()
			p.cats.b = cat("b", "snow", "window_1") -- favorite: 1.5
			p.cats.c = cat("c", "calico", nil) -- resting
			p.upgradeLevels.tables = 2 -- x1.2
			expect(Economy.incomePerSecond(p)).to.be.near((1.5 + 1.5) * 1.2)
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
	end)

	describe("offlineGain = rate x 0.25 x min(elapsed, 3600) (section 11)", function()
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

		it("features.md step 7: 5 minutes away at the starter rate shows 112 coins", function()
			local gain = Economy.offlineGain(1.5, 0, 300)
			expect(gain).to.equal(112)
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

	describe("upgrade costs and blockers (section 6)", function()
		it("next cost is costs[level + 1], nil when maxed or unknown", function()
			local p = freshProfile()
			expect(Economy.nextUpgradeCost(p, "cafe_level")).to.equal(250)
			expect(Economy.nextUpgradeCost(p, "tables")).to.equal(100)
			expect(Economy.nextUpgradeCost(p, "espresso")).to.equal(300)
			p.upgradeLevels.tables = 6
			expect(Economy.nextUpgradeCost(p, "tables")).never.to.be.ok()
			expect(Economy.nextUpgradeCost(p, "jetpack")).never.to.be.ok()
		end)

		it("fresh profile: only Tables is affordable at 50 coins... and it is not (100)", function()
			local p = freshProfile()
			expect(Economy.upgradeBlocker(p, "tables")).to.equal("Not enough coins")
			p.coins = 100
			expect(Economy.upgradeBlocker(p, "tables")).never.to.be.ok()
		end)

		it("cafe level gates come before the coin check", function()
			local p = freshProfile()
			p.coins = 1000000
			expect(Economy.upgradeBlocker(p, "lure_bowl")).to.equal("Needs cafe level 2")
			expect(Economy.upgradeBlocker(p, "park_access")).to.equal("Needs cafe level 3")
			p.upgradeLevels.cafe_level = 2
			expect(Economy.upgradeBlocker(p, "lure_bowl")).never.to.be.ok()
			expect(Economy.upgradeBlocker(p, "park_access")).to.equal("Needs cafe level 3")
			p.coins = 0
			expect(Economy.upgradeBlocker(p, "park_access")).to.equal("Needs cafe level 3")
		end)

		it("espresso level 3 needs cafe level 3, level 2 does not", function()
			local p = freshProfile()
			p.coins = 1000000
			expect(Economy.upgradeBlocker(p, "espresso")).never.to.be.ok()
			p.upgradeLevels.espresso = 2
			expect(Economy.upgradeBlocker(p, "espresso")).to.equal("Needs cafe level 3")
			p.upgradeLevels.cafe_level = 3
			expect(Economy.upgradeBlocker(p, "espresso")).never.to.be.ok()
			p.upgradeLevels.espresso = 3
			expect(Economy.upgradeBlocker(p, "espresso")).to.equal("Already maxed")
		end)

		it("unknown upgrades are refused", function()
			expect(Economy.upgradeBlocker(freshProfile(), "jetpack")).to.equal("Unknown upgrade")
		end)
	end)

	describe("decor blockers (section 7)", function()
		it("refuses unknown, owned, gated and unaffordable decor in that order", function()
			local p = freshProfile()
			expect(Economy.decorBlocker(p, "lava_lamp")).to.equal("Unknown decor")
			expect(Economy.decorBlocker(p, "plants")).to.equal("Not enough coins")
			p.coins = 150
			expect(Economy.decorBlocker(p, "plants")).never.to.be.ok()
			p.decorOwned.plants = true
			expect(Economy.decorBlocker(p, "plants")).to.equal("Already owned")
			p.coins = 1000000
			expect(Economy.decorBlocker(p, "neon_sign")).to.equal("Needs cafe level 4")
			p.upgradeLevels.cafe_level = 4
			expect(Economy.decorBlocker(p, "neon_sign")).never.to.be.ok()
		end)
	end)

	describe("spots (section 5)", function()
		it("spots open by cafe level", function()
			local p = freshProfile()
			expect(Economy.spotIsOpen(p, "counter_1")).to.equal(true)
			expect(Economy.spotIsOpen(p, "window_1")).to.equal(true)
			expect(Economy.spotIsOpen(p, "cushion_1")).to.equal(false)
			expect(Economy.spotIsOpen(p, "patio_2")).to.equal(false)
			expect(Economy.spotIsOpen(p, "nowhere_1")).to.equal(false)
			p.upgradeLevels.cafe_level = 5
			for _, spot in ipairs(Catalog.spots) do
				expect(Economy.spotIsOpen(p, spot.id)).to.equal(true)
			end
		end)

		it("catOnSpot finds the occupant", function()
			local p = freshProfile()
			local occupant = Economy.catOnSpot(p, "counter_1")
			expect(occupant).to.be.ok()
			assert(occupant)
			expect(occupant.uid).to.equal("starter")
			expect(Economy.catOnSpot(p, "window_1")).never.to.be.ok()
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
			p.cats.c = cat("c", "void", "shelf_1")
			expect(Economy.countsByCat(p)).to.deepEqual({ tabby = { count = 2 }, void = { count = 1 } })
		end)
	end)

	describe("features.md section 8: the ten minute loop in numbers", function()
		it("step 1: $50 and a positive rate on join", function()
			local p = freshProfile()
			expect(p.coins).to.equal(50)
			expect(Economy.incomePerSecond(p) > 0).to.equal(true)
		end)

		it("step 4: placing a caught Common on window_1 raises the rate", function()
			local p = freshProfile()
			local before = Economy.incomePerSecond(p)
			p.cats.new = cat("new", "ginger", "window_1")
			expect(Economy.incomePerSecond(p) > before).to.equal(true)
			expect(Economy.incomePerSecond(p)).to.be.near(2.5)
		end)

		it("step 5: Table 1 costs $100 and raises the rate by exactly 10%", function()
			local p = freshProfile()
			p.cats.new = cat("new", "ginger", "window_1")
			local before = Economy.incomePerSecond(p)
			p.coins = 100
			expect(Economy.nextUpgradeCost(p, "tables")).to.equal(100)
			expect(Economy.upgradeBlocker(p, "tables")).never.to.be.ok()
			expect(Economy.trySpend(p, 100)).to.equal(true)
			p.upgradeLevels.tables = 1
			expect(Economy.incomePerSecond(p)).to.be.near(before * 1.1)
		end)

		it("reaching $100 for Table 1 from the start takes about 34 s at the starter rate", function()
			-- Balance guard: if this jumps past ~2 minutes the tutorial beat 'buy a table' is too slow.
			local p = freshProfile(0)
			local seconds = (100 - p.coins) / Economy.incomePerSecond(p)
			expect(seconds <= 120).to.equal(true)
		end)

		it("cafe level 2 at $250 is reachable inside 10 minutes with two placed Commons and a table", function()
			local p = freshProfile(0)
			p.cats.new = cat("new", "ginger", "window_1")
			p.upgradeLevels.tables = 1
			p.coins = 0
			Economy.settle(p, 600 - 90) -- rough: 90 s spent walking and catching
			expect(p.coins >= 250).to.equal(true)
		end)
	end)
end
