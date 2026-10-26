--!strict
-- CatStats.luau against data-model v0.3.1 sections 4 and 4b: charm, level and XP, shiny, rating, and how Economy
-- uses them. The v2 to v3 save migration has its own spec (ProfileSchema.spec).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatStats = require(Shared.CatStats)
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local ProfileSchema = require(Shared.ProfileSchema)

	local function cat(catId: string, charm: number?, level: number?, spotId: string?)
		local instance = CatStats.newInstance("uid_" .. catId, catId, 0, charm)
		if level ~= nil then
			instance.level = level
		end
		instance.spotId = spotId
		return instance
	end

	-- Park-Miller generator so the distribution test is deterministic and needs no Roblox Random.
	local function lcg(seed: number): () -> number
		local state = seed
		return function()
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
	end

	describe("charm roll", function()
		it("maps two rolls to 0..100 with the extremes at the ends and 50 in the middle", function()
			expect(CatStats.rollCharm(0, 0)).to.equal(0)
			expect(CatStats.rollCharm(1, 1)).to.equal(100)
			expect(CatStats.rollCharm(0.5, 0.5)).to.equal(50)
			-- out-of-range rolls are clamped to 0 and 1 first, so (-5, 7) is the same as (0, 1)
			expect(CatStats.rollCharm(-5, 7)).to.equal(50)
		end)

		it("is triangular: most cats near 50, about 8% five star and 8% one star", function()
			local next = lcg(20261026)
			local fiveStar, oneStar, total = 0, 0, 0
			local samples = 20000
			for _ = 1, samples do
				local charm = CatStats.rollCharm(next(), next())
				expect(charm >= 0 and charm <= 100).to.equal(true)
				total += charm
				if CatStats.stars(charm) == 5 then
					fiveStar += 1
				elseif CatStats.stars(charm) == 1 then
					oneStar += 1
				end
			end
			expect(total / samples).to.be.near(50, 1.5)
			expect(fiveStar / samples).to.be.near(0.08, 0.015)
			expect(oneStar / samples).to.be.near(0.08, 0.015)
		end)
	end)

	describe("multipliers", function()
		it("charm 0 is 1 - spread, 50 is exactly 1.0, 100 is 1 + spread", function()
			expect(CatStats.charmMultiplier(0)).to.be.near(1 - Config.CharmSpread)
			expect(CatStats.charmMultiplier(50)).to.equal(1)
			expect(CatStats.charmMultiplier(100)).to.be.near(1 + Config.CharmSpread)
			expect(CatStats.charmMultiplier(500)).to.be.near(1 + Config.CharmSpread)
		end)

		it("level 1 is 1.0 and each level adds CatLevelBonus up to the cap", function()
			expect(CatStats.levelMultiplier(1)).to.equal(1)
			expect(CatStats.levelMultiplier(2)).to.be.near(1 + Config.CatLevelBonus)
			expect(CatStats.levelMultiplier(Config.CatMaxLevel)).to.be.near(
				1 + Config.CatLevelBonus * (Config.CatMaxLevel - 1)
			)
			expect(CatStats.levelMultiplier(Config.CatMaxLevel + 5)).to.be.near(
				CatStats.levelMultiplier(Config.CatMaxLevel)
			)
			expect(CatStats.levelMultiplier(0)).to.equal(1)
		end)

		it("variants: base 1x, shiny ShinyMultiplier (1.5x); Golden and Galaxy are gone (v0.3)", function()
			expect(Config.ShinyMultiplier).to.equal(1.5)
			expect(CatStats.variantMultiplier("base")).to.equal(1)
			expect(CatStats.variantMultiplier("shiny")).to.equal(Config.ShinyMultiplier)
			expect(CatStats.variantMultiplier("golden")).to.equal(1)
			expect(CatStats.variantMultiplier("galaxy")).to.equal(1)
			expect(CatStats.variantMultiplier(nil)).to.equal(1)
			expect(Economy.variantMultiplier("shiny")).to.equal(Config.ShinyMultiplier)
		end)

		it("stars: five equal bands of 20 charm", function()
			expect(CatStats.stars(0)).to.equal(1)
			expect(CatStats.stars(19)).to.equal(1)
			expect(CatStats.stars(20)).to.equal(2)
			expect(CatStats.stars(50)).to.equal(3)
			expect(CatStats.stars(79)).to.equal(4)
			expect(CatStats.stars(80)).to.equal(5)
			expect(CatStats.stars(100)).to.equal(5)
			expect(CatStats.starsText(3)).to.equal("★★★☆☆")
		end)
	end)

	describe("XP and levels", function()
		it(
			"xpToNext is CatXpBase x level and 0 at the cap; level 10 takes 45 minutes placed",
			function()
				expect(CatStats.xpToNext(1)).to.equal(Config.CatXpBase)
				expect(CatStats.xpToNext(9)).to.equal(Config.CatXpBase * 9)
				expect(CatStats.xpToNext(Config.CatMaxLevel)).to.equal(0)
				expect(CatStats.xpForLevel(Config.CatMaxLevel)).to.equal(45 * 60)
				expect(CatStats.xpForLevel(1)).to.equal(0)
			end
		)

		it("addXp levels up when the bar fills and carries the remainder", function()
			local instance = cat("tabby")
			expect(CatStats.addXp(instance, Config.CatXpBase - 1)).to.equal(0)
			expect(instance.level).to.equal(1)
			expect(instance.xp).to.equal(Config.CatXpBase - 1)
			expect(CatStats.addXp(instance, 3)).to.equal(1)
			expect(instance.level).to.equal(2)
			expect(instance.xp).to.equal(2)
		end)

		it("addXp can jump several levels and stops at the cap with xp 0", function()
			local instance = cat("tabby")
			expect(CatStats.addXp(instance, CatStats.xpForLevel(4))).to.equal(3)
			expect(instance.level).to.equal(4)
			expect(instance.xp).to.equal(0)
			expect(CatStats.addXp(instance, 10 ^ 9)).to.equal(Config.CatMaxLevel - 4)
			expect(instance.level).to.equal(Config.CatMaxLevel)
			expect(instance.xp).to.equal(0)
			expect(CatStats.addXp(instance, 500)).to.equal(0)
			expect(instance.xp).to.equal(0)
		end)

		it("ignores negative, nil and NaN amounts and initialises a version 1 cat", function()
			local legacy: any = { uid = "old", catId = "tabby", variant = "base", caughtAt = 0 }
			expect(CatStats.level(legacy)).to.equal(1)
			expect(CatStats.charm(legacy)).to.equal(CatStats.DEFAULT_CHARM)
			expect(CatStats.addXp(legacy, -50)).to.equal(0)
			expect(legacy.level).to.equal(1)
			expect(legacy.xp).to.equal(0)
			expect(legacy.charm).to.equal(CatStats.DEFAULT_CHARM)
			expect(CatStats.addXp(legacy, 0 / 0)).to.equal(0)
			expect(legacy.xp).to.equal(0)
		end)
	end)

	describe("rating = rarity rate x charm x level x variant", function()
		it("a neutral level 1 cat rates exactly its rarity rate", function()
			for _, def in ipairs(Catalog.cats) do
				expect(CatStats.rating(cat(def.id))).to.equal(def.incomePerSecond)
			end
		end)

		it("a perfect max level Tabby rates 1.74, a Void 43.5", function()
			expect(CatStats.rating(cat("tabby", 100, Config.CatMaxLevel))).to.be.near(1.2 * 1.45)
			expect(CatStats.maxRating("tabby")).to.be.near(1.2 * 1.45)
			expect(CatStats.maxRating("void")).to.be.near(25 * 1.2 * 1.45)
			expect(CatStats.maxRating("nope")).to.equal(0)
		end)

		it(
			"a one star Common is still worth more than nothing and less than a neutral one",
			function()
				local worst = CatStats.rating(cat("tabby", 0))
				expect(worst).to.be.near(0.8)
				expect(worst < CatStats.rating(cat("tabby"))).to.equal(true)
			end
		)

		it("a shiny multiplies the rating and unknown cats rate 0", function()
			local shiny = cat("tabby")
			shiny.variant = "shiny"
			expect(CatStats.rating(shiny)).to.be.near(1.5, 1e-9)
			expect(CatStats.isBetter(shiny, cat("tabby"))).to.equal(true)
			expect(CatStats.rating(cat("dragon"))).to.equal(0)
		end)

		it("the section 4b example: a perfect max level shiny Midnight rates 195.75", function()
			local best = cat("midnight", 100, Config.CatMaxLevel)
			best.variant = "shiny"
			expect(CatStats.rating(best)).to.be.near(75 * 1.2 * 1.45 * 1.5, 1e-9)
			expect(CatStats.rating(best)).to.be.near(195.75, 1e-9)
		end)

		it("maxRating is the base variant figure; the book's shiny line is that times 1.5", function()
			expect(CatStats.maxRating("midnight")).to.be.near(75 * 1.2 * 1.45, 1e-9)
			expect(CatStats.maxRating("midnight") * Config.ShinyMultiplier).to.be.near(195.75, 1e-9)
		end)

		it("isBetter orders by rating, then rarity, then id, then uid", function()
			local a = cat("tabby", 100)
			local b = cat("tabby", 50)
			expect(CatStats.isBetter(a, b)).to.equal(true)
			expect(CatStats.isBetter(b, a)).to.equal(false)
			expect(CatStats.isBetter(cat("void"), cat("tabby", 100, 10))).to.equal(true)
			local c, d = cat("ginger"), cat("smoke")
			expect(CatStats.isBetter(c, d)).to.equal(true)
			local e, f = cat("tabby"), cat("tabby")
			f.uid = "zzz"
			expect(CatStats.isBetter(e, f)).to.equal(true)
		end)
	end)

	describe("instances and views", function()
		it("newInstance starts at level 1, 0 xp, neutral charm unless rolled", function()
			local plain = CatStats.newInstance("u1", "snow", 123)
			expect(plain.level).to.equal(1)
			expect(plain.xp).to.equal(0)
			expect(plain.charm).to.equal(CatStats.DEFAULT_CHARM)
			expect(plain.caughtAt).to.equal(123)
			expect(plain.spotId).never.to.be.ok()
			expect(CatStats.newInstance("u2", "snow", 0, 999).charm).to.equal(100)
			expect(CatStats.newInstance("u3", "snow", 0, 73.9).charm).to.equal(73)
		end)

		it("view adds xpToNext, stars and rating for the UI", function()
			local instance = cat("siamese", 85, 3, "barista_1")
			instance.xp = 40
			instance.name = "Mochi"
			instance.method = "bait"
			local view = CatStats.view(instance)
			expect(view.uid).to.equal(instance.uid)
			expect(view.catId).to.equal("siamese")
			expect(view.spotId).to.equal("barista_1")
			expect(view.name).to.equal("Mochi")
			expect(view.method).to.equal("bait")
			expect(view.level).to.equal(3)
			expect(view.xp).to.equal(40)
			expect(view.xpToNext).to.equal(Config.CatXpBase * 3)
			expect(view.charm).to.equal(85)
			expect(view.stars).to.equal(5)
			expect(view.rating).to.be.near(
				3 * CatStats.charmMultiplier(85) * CatStats.levelMultiplier(3)
			)
			expect(CatStats.shortText(instance)).to.equal("Lv 3 · ★★★★★")
		end)
	end)

	describe("Economy integration", function()
		it("a fresh profile still earns 1.5 per second (starter Tabby is neutral)", function()
			local profile = ProfileSchema.template(1000)
			expect(profile.version).to.equal(3)
			expect(profile.tier).to.equal(1)
			expect((profile :: any).renovations).never.to.be.ok()
			expect(profile.cats.starter_tabby.charm).to.equal(CatStats.DEFAULT_CHARM)
			expect(profile.cats.starter_tabby.spotId).to.equal("barista_1")
			expect(Economy.incomePerSecond(profile)).to.be.near(1.5)
		end)

		it("catRate uses the rating: a perfect Tabby as Barista earns 1.8, as Waiter 1.2", function()
			expect(Economy.catRate(cat("tabby", 100, 1, "barista_1"))).to.be.near(1.8)
			expect(Economy.catRate(cat("tabby", 100, 1, "waiter_1"))).to.be.near(1.2)
		end)

		it("settle grants one XP per second to placed cats only", function()
			local profile = ProfileSchema.template(1000)
			profile.cats.resting = cat("snow")
			Economy.settle(profile, 1000 + Config.CatXpBase + 5)
			expect(profile.cats.starter_tabby.level).to.equal(2)
			expect(profile.cats.starter_tabby.xp).to.equal(5)
			expect(profile.cats.resting.level).to.equal(1)
			expect(profile.cats.resting.xp).to.equal(0)
		end)

		it("coins in a settle window use the rate from before the level up", function()
			local profile = ProfileSchema.template(0)
			profile.coins = 0
			Economy.settle(profile, Config.CatXpBase)
			expect(profile.coins).to.be.near(1.5 * Config.CatXpBase)
			expect(profile.cats.starter_tabby.level).to.equal(2)
			expect(Economy.incomePerSecond(profile)).to.be.near(1.5 * (1 + Config.CatLevelBonus))
		end)

		it("v0.3: the tier multiplier replaces prestige and renovations (section 11)", function()
			local economy = Economy :: any
			expect(economy.prestigeMultiplier).never.to.be.ok()
			local profile: any = ProfileSchema.template(0)
			profile.renovations = 2
			expect(Economy.incomePerSecond(profile)).to.be.near(1.5)
		end)

		it("migrate keeps saved stats, defaults missing ones and clamps nonsense", function()
			local raw: any = ProfileSchema.template(0)
			raw.version = 1
			raw.renovations = nil
			raw.cats = {
				old = {
					uid = "old",
					catId = "tabby",
					variant = "base",
					caughtAt = 5,
					spotId = "counter_1",
				},
				kept = {
					uid = "kept",
					catId = "void",
					caughtAt = 5,
					level = 7,
					xp = 30,
					charm = 91,
				},
				wild = {
					uid = "wild",
					catId = "snow",
					caughtAt = 5,
					level = 99,
					xp = -4,
					charm = 1000,
				},
			}
			local profile = ProfileSchema.migrate(raw, 100)
			expect(profile.version).to.equal(3)
			expect((profile :: any).renovations).never.to.be.ok()
			expect(profile.cats.old.level).to.equal(1)
			expect(profile.cats.old.xp).to.equal(0)
			expect(profile.cats.old.charm).to.equal(CatStats.DEFAULT_CHARM)
			expect(profile.cats.kept.level).to.equal(7)
			expect(profile.cats.kept.xp).to.equal(30)
			expect(profile.cats.kept.charm).to.equal(91)
			expect(profile.cats.wild.level).to.equal(Config.CatMaxLevel)
			expect(profile.cats.wild.xp).to.equal(0)
			expect(profile.cats.wild.charm).to.equal(100)
		end)
	end)

	-- Design v0.3: a rescued cat keeps its flag for the book and analytics but pays no more (RescuedTipsMultiplier 1.0).
	-- The gloves to net carry-over is a v1 and v2 save rule, so it lives in ProfileSchema.spec now.
	describe("rescued cats (v0.3)", function()
		it("rescuedMultiplier is 1 for everyone", function()
			expect(Config.RescuedTipsMultiplier).to.equal(1)
			expect(CatStats.rescuedMultiplier(true)).to.equal(1)
			expect(CatStats.rescuedMultiplier(false)).to.equal(1)
			expect(CatStats.rescuedMultiplier(nil)).to.equal(1)
		end)

		it("a rescued cat rates the same as a net cat and the view still shows the flag", function()
			local plain = cat("tabby", 50, 1)
			local rescued = cat("tabby", 50, 1)
			rescued.rescued = true
			expect(CatStats.rating(rescued)).to.equal(CatStats.rating(plain))
			local view = CatStats.view(rescued)
			expect(view.rescued).to.equal(true)
			expect(view.rating).to.equal(CatStats.rating(plain))
			expect(CatStats.view(plain).rescued).to.equal(nil)
		end)

		it("migrate keeps rescued only when it was saved as true", function()
			local raw: any = ProfileSchema.template(0)
			raw.cats = {
				saved = { uid = "saved", catId = "tabby", caughtAt = 5, rescued = true },
				junk = { uid = "junk", catId = "tabby", caughtAt = 5, rescued = "yes" },
				plain = { uid = "plain", catId = "tabby", caughtAt = 5 },
			}
			local profile = ProfileSchema.migrate(raw, 100)
			expect(profile.cats.saved.rescued).to.equal(true)
			expect(profile.cats.junk.rescued).to.equal(nil)
			expect(profile.cats.plain.rescued).to.equal(nil)
		end)
	end)
end
