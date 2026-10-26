--!strict
-- ProfileSchema.luau against data-model v0.3.1 section 14: the version 3 template, the version guard (S31) and the
-- 2 to 3 migration. F22 done-when: a v2 save loads as v3 with tier 1, refunds applied, two cats working and no
-- coins lost. Refunds use the version 2 prices frozen in ProfileSchema, never the live Catalog.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatStats = require(Shared.CatStats)
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local EquipBest = require(Shared.EquipBest)
	local ProfileSchema = require(Shared.ProfileSchema)

	-- What version 2 charged per level (data-model v0.2 section 6), written out here so a change to the frozen
	-- table in ProfileSchema fails a test.
	local V2 = {
		cafe_level = { 0, 250, 800, 2500, 8000 },
		park_access = { 1000 },
		tables = { 100, 250, 600, 1500, 3500, 8000 },
		espresso = { 0, 300, 1200, 4000, 12000 },
		net = { 500, 2500, 10000 },
	}
	local function v2Cost(id: string, from: number, to: number): number
		local total = 0
		for level = from + 1, to do
			total += (V2 :: any)[id][level]
		end
		return total
	end

	local function v2Cat(uid: string, catId: string, spotId: string?, extra: { [string]: any }?): any
		local entry: { [string]: any } =
			{ uid = uid, catId = catId, variant = "base", caughtAt = 500, spotId = spotId, level = 1, xp = 0, charm = 50 }
		for key, value in pairs(extra or {}) do
			entry[key] = value
		end
		return entry
	end

	-- A version 2 save shaped like the v0.2 template (main before F22).
	local function v2Save(levels: { [string]: any }?): any
		return {
			version = 2,
			coins = 1234,
			lifetimeCoins = 5000,
			lastTick = 900,
			lastSeen = 900,
			rateAtLogout = 3.3,
			renovations = 0,
			upgradeLevels = levels
				or { cafe_level = 1, tables = 0, espresso = 1, net = 0, lure_bowl = 0, park_access = 0 },
			decorOwned = {},
			decorPlaced = {},
			lures = {},
			equippedLure = nil,
			cats = { starter_tabby = v2Cat("starter_tabby", "tabby", "counter_1") },
			collection = { tabby = 500 },
			stats = {
				catsCaught = 4,
				catsSold = 1,
				grabsAttempted = 9,
				grabsSucceeded = 4,
				luresUsed = 2,
				playtimeSeconds = 1800,
				sessions = 3,
			},
			tutorialStep = 5,
			settings = { music = false, sfx = true },
		}
	end

	local function working(profile: any): { [string]: string }
		local out: { [string]: string } = {}
		for uid, instance in pairs(profile.cats) do
			if instance.spotId ~= nil then
				out[uid] = instance.spotId
			end
		end
		return out
	end

	local function count(map: { [any]: any }): number
		local n = 0
		for _ in pairs(map) do
			n += 1
		end
		return n
	end

	describe("template (section 14)", function()
		it("is version 3 at Tier 1 with 50 coins and the v0.3 start levels", function()
			local profile = ProfileSchema.template(1000)
			expect(ProfileSchema.VERSION).to.equal(3)
			expect(profile.version).to.equal(3)
			expect(profile.tier).to.equal(1)
			expect(profile.coins).to.equal(Config.StartCoins)
			expect(profile.lifetimeCoins).to.equal(0)
			expect(profile.lastTick).to.equal(1000)
			expect(profile.lastSeen).to.equal(1000)
			expect(profile.rateAtLogout).to.equal(0)
			expect(profile.upgradeLevels :: any).to.deepEqual({ tables = 0, espresso = 1, net = 0, lure_bowl = 0 })
			expect(count(profile.decorOwned) + count(profile.decorPlaced) + count(profile.lures)).to.equal(0)
			expect(profile.tutorialStep).to.equal(0)
			expect(profile.settings :: any).to.deepEqual({ music = true, sfx = true })
		end)

		it("starts with one neutral Tabby working as the Barista, found as the starter", function()
			local profile = ProfileSchema.template(1000)
			expect(count(profile.cats)).to.equal(1)
			local starter = profile.cats.starter_tabby
			assert(starter)
			expect(starter.catId).to.equal("tabby")
			expect(starter.variant).to.equal("base")
			expect(starter.spotId).to.equal("barista_1")
			expect(starter.method).to.equal("starter")
			expect(starter.charm).to.equal(CatStats.DEFAULT_CHARM)
			expect(starter.level).to.equal(1)
			expect(starter.xp).to.equal(0)
			expect(starter.name).never.to.be.ok()
			expect(profile.collection :: any).to.deepEqual({ tabby = 1000 })
			expect(Economy.incomePerSecond(profile)).to.be.near(1.5, 1e-9)
		end)

		it("has the new v0.3 fields and none of the removed ones", function()
			local profile: any = ProfileSchema.template(1000)
			expect(profile.bait).never.to.be.ok()
			expect(profile.dealer).to.deepEqual({ window = 0, bought = {} })
			expect(profile.shinyCollection).to.deepEqual({})
			expect(profile.renovations).never.to.be.ok()
			expect(profile.upgradeLevels.cafe_level).never.to.be.ok()
			expect(profile.upgradeLevels.park_access).never.to.be.ok()
			for _, key in
				ipairs({
					"perfectCircles",
					"circlesTotal",
					"rescues",
					"rescueAttempts",
					"baitsTamed",
					"baitsLetGo",
					"bumpsGiven",
					"bumpsLanded",
					"bumpsTaken",
				})
			do
				expect(profile.stats[key]).to.equal(0)
			end
		end)

		it("has flags = { autoPress = false } (section 10, reviewer S23)", function()
			expect(ProfileSchema.template(0).flags :: any).to.deepEqual({ autoPress = false })
		end)
		it("has telemetry = { onboardingStep = 0, achieved = {} } (growth analytics-plan)")
		-- equippedLure goes when the bait bowl replaces the v0.2 lure spots.
		it("drops equippedLure, in the template and in the migration (F28)")
	end)

	describe("versionOf and isNewerThanCode (S31 newer-save guard)", function()
		it("reads the saved version, version 1 for saves from before the field", function()
			local cases: { { any } } = {
				{ {}, 1 },
				{ { version = 1 }, 1 },
				{ { version = 2 }, 2 },
				{ { version = 3 }, 3 },
				{ { version = 4 }, 4 },
				{ { version = 99 }, 99 },
				{ { version = 2.9 }, 2 },
				{ { version = 0 }, 1 },
				{ { version = -4 }, 1 },
				{ { version = 0 / 0 }, 1 },
				{ { version = "3" }, 1 },
			}
			for _, case in ipairs(cases) do
				expect(ProfileSchema.versionOf(case[1])).to.equal(case[2])
			end
		end)

		it("a missing save (a new player) counts as the current version", function()
			expect(ProfileSchema.versionOf(nil)).to.equal(ProfileSchema.VERSION)
			expect(ProfileSchema.isNewerThanCode(nil)).to.equal(false)
		end)

		it("only a save above the code's version is newer", function()
			expect(ProfileSchema.isNewerThanCode({ version = 4 })).to.equal(true)
			expect(ProfileSchema.isNewerThanCode({ version = 99 })).to.equal(true)
			expect(ProfileSchema.isNewerThanCode({ version = 3 })).to.equal(false)
			expect(ProfileSchema.isNewerThanCode({ version = 2 })).to.equal(false)
			expect(ProfileSchema.isNewerThanCode({})).to.equal(false)
			expect(ProfileSchema.isNewerThanCode(ProfileSchema.template(0))).to.equal(false)
		end)
	end)

	describe("migrate 2 to 3: tier and refunds at the version 2 prices", function()
		it("a typical v2 save: Tier 1, levels capped, every coin refunded (F22 done-when)", function()
			local raw = v2Save({
				cafe_level = 3,
				tables = 4,
				espresso = 3,
				net = 2,
				lure_bowl = 1,
				park_access = 1,
			})
			local profile = ProfileSchema.migrate(raw, 1000)
			expect(profile.version).to.equal(3)
			expect(profile.tier).to.equal(1)
			expect(profile.upgradeLevels :: any).to.deepEqual({ tables = 2, espresso = 2, net = 1, lure_bowl = 1 })
			-- cafe_level 2 and 3 (250 + 800), park_access (1000), tables 3 and 4 (600 + 1500), espresso 3 (1200),
			-- net 2 at the v2 price (2500, not today's 3000)
			local refund = 250 + 800 + 1000 + 600 + 1500 + 1200 + 2500
			expect(refund).to.equal(7850)
			expect(profile.coins).to.equal(1234 + refund)
			expect(profile.lifetimeCoins).to.equal(5000)
		end)

		it("no coins lost: coins after = coins before + the v2 price of every level taken away", function()
			local cases: { { [string]: number } } = {
				{ cafe_level = 1, tables = 0, espresso = 1, net = 0, lure_bowl = 0, park_access = 0 },
				{ cafe_level = 2, tables = 2, espresso = 2, net = 1, lure_bowl = 1, park_access = 0 },
				{ cafe_level = 5, tables = 6, espresso = 3, net = 3, lure_bowl = 1, park_access = 1 },
				{ cafe_level = 4, tables = 5, espresso = 1, net = 0, lure_bowl = 0, park_access = 1 },
			}
			local caps = Catalog.tiers[1].caps
			for _, levels in ipairs(cases) do
				local expected = v2Cost("cafe_level", 1, levels.cafe_level)
					+ v2Cost("park_access", 0, levels.park_access)
					+ v2Cost("tables", math.min(levels.tables, caps.tables), levels.tables)
					+ v2Cost("espresso", math.min(levels.espresso, caps.espresso), levels.espresso)
					+ v2Cost("net", math.min(levels.net, caps.net), levels.net)
				local profile = ProfileSchema.migrate(v2Save(table.clone(levels) :: any), 1000)
				expect(profile.coins).to.equal(1234 + expected)
				expect(profile.upgradeLevels.tables).to.equal(math.min(levels.tables, caps.tables))
				expect(profile.upgradeLevels.espresso).to.equal(math.min(levels.espresso, caps.espresso))
				expect(profile.upgradeLevels.net).to.equal(math.min(levels.net, caps.net))
				expect(profile.upgradeLevels.lure_bowl).to.equal(levels.lure_bowl)
			end
		end)

		it("everything maxed in v2 refunds 13,600 + 1,200 + 12,500 + 11,550 + 1,000", function()
			local profile = ProfileSchema.migrate(
				v2Save({ cafe_level = 5, tables = 6, espresso = 3, net = 3, lure_bowl = 1, park_access = 1 }),
				1000
			)
			expect(profile.coins).to.equal(1234 + 13600 + 1200 + 12500 + 11550 + 1000)
		end)

		it("espresso levels above the v2 cap of 3 still refund at the v2 prices", function()
			-- v2 only sold espresso to 3, but the frozen table has all five prices; a level 5 save refunds 3 to 5.
			local profile = ProfileSchema.migrate(v2Save({ espresso = 5 }), 1000)
			expect(profile.upgradeLevels.espresso).to.equal(2)
			expect(profile.coins).to.equal(1234 + 1200 + 4000 + 12000)
		end)

		it("levels at or under the Tier 1 caps refund nothing", function()
			local profile = ProfileSchema.migrate(
				v2Save({ cafe_level = 1, tables = 2, espresso = 2, net = 1, lure_bowl = 1, park_access = 0 }),
				1000
			)
			expect(profile.coins).to.equal(1234)
			expect(profile.upgradeLevels :: any).to.deepEqual({ tables = 2, espresso = 2, net = 1, lure_bowl = 1 })
		end)

		it("damaged levels count as the start level and refund nothing", function()
			for _, bad in ipairs({ "lots", 0 / 0, -5, math.huge, true }) do
				local profile = ProfileSchema.migrate(
					v2Save({ cafe_level = bad, tables = bad, espresso = bad, net = bad, park_access = bad }),
					1000
				)
				expect(profile.coins).to.equal(1234)
				expect(profile.upgradeLevels.tables).to.equal(0)
				expect(profile.upgradeLevels.espresso).to.equal(1)
				expect(profile.upgradeLevels.net).to.equal(0)
			end
		end)

		it("a level past the last v2 price refunds only the prices that exist", function()
			local profile = ProfileSchema.migrate(
				v2Save({ cafe_level = 1e9, park_access = 7, tables = 40, net = 12, lure_bowl = 3 }),
				1000
			)
			expect(profile.coins).to.equal(1234 + 11550 + 1000 + v2Cost("tables", 2, 6) + v2Cost("net", 1, 3))
			expect(profile.upgradeLevels.tables).to.equal(2)
			expect(profile.upgradeLevels.net).to.equal(1)
			expect(profile.upgradeLevels.lure_bowl).to.equal(1) -- no cap, but never above its max level
		end)

		it("unknown upgrade ids are dropped without a refund", function()
			local levels: any = { jetpack = 5, tables = 1 }
			local profile: any = ProfileSchema.migrate(v2Save(levels), 1000)
			expect(profile.upgradeLevels.jetpack).never.to.be.ok()
			expect(profile.coins).to.equal(1234)
		end)

		it("a v1 gloves level becomes the net, capped at 1 with the rest refunded at v2 net prices", function()
			local raw = v2Save({ gloves = 2 })
			raw.version = 1
			local profile: any = ProfileSchema.migrate(raw, 1000)
			expect(profile.upgradeLevels.net).to.equal(1)
			expect(profile.upgradeLevels.gloves).never.to.be.ok()
			expect(profile.coins).to.equal(1234 + 2500)
			raw = v2Save({ gloves = 99 })
			raw.version = 1
			profile = ProfileSchema.migrate(raw, 1000)
			expect(profile.upgradeLevels.net).to.equal(1)
			expect(profile.coins).to.equal(1234 + 2500 + 10000)
		end)

		it("when gloves and net were both saved, the net level wins and gloves is dropped", function()
			local raw = v2Save({ gloves = 3, net = 1 })
			raw.version = 1
			local profile: any = ProfileSchema.migrate(raw, 1000)
			expect(profile.upgradeLevels.net).to.equal(1)
			expect(profile.upgradeLevels.gloves).never.to.be.ok()
			expect(profile.coins).to.equal(1234)
		end)

		it("a v2 save is Tier 1 even if it somehow holds a tier", function()
			local raw = v2Save()
			raw.tier = 4
			expect(ProfileSchema.migrate(raw, 1000).tier).to.equal(1)
		end)

		it("keeps coins, lifetime coins, times, the day rate, tutorial, settings, decor and food", function()
			local raw = v2Save()
			raw.decorOwned = { plants = true, rug = true, lava_lamp = true }
			raw.decorPlaced = { plants = true, lava_lamp = true, neon_sign = true }
			raw.lures = { kibble = 2, tuna = 0, caviar_v9 = 4 }
			local profile = ProfileSchema.migrate(raw, 1000)
			expect(profile.coins).to.equal(1234)
			expect(profile.lifetimeCoins).to.equal(5000)
			expect(profile.lastTick).to.equal(900)
			expect(profile.lastSeen).to.equal(900)
			expect(profile.rateAtLogout).to.be.near(3.3, 1e-9)
			expect(profile.tutorialStep).to.equal(5)
			expect(profile.settings :: any).to.deepEqual({ music = false, sfx = true })
			-- Decor bought in v2 is kept even where v0.3 gates it behind Tier 2; only known and owned decor counts.
			expect(profile.decorOwned :: any).to.deepEqual({ plants = true, rug = true })
			expect(profile.decorPlaced :: any).to.deepEqual({ plants = true })
			expect(profile.lures :: any).to.deepEqual({ kibble = 2 })
		end)

		it("keeps the v2 stats and starts the new counters at 0; renovations goes", function()
			local profile: any = ProfileSchema.migrate(v2Save(), 1000)
			expect(profile.stats.catsCaught).to.equal(4)
			expect(profile.stats.grabsAttempted).to.equal(9)
			expect(profile.stats.playtimeSeconds).to.equal(1800)
			expect(profile.stats.sessions).to.equal(3)
			expect(profile.stats.perfectCircles).to.equal(0)
			expect(profile.stats.bumpsTaken).to.equal(0)
			expect(profile.renovations).never.to.be.ok()
			expect(profile.bait).never.to.be.ok()
			expect(profile.dealer).to.deepEqual({ window = 0, bought = {} })
		end)
	end)

	describe("migrate 2 to 3: cats", function()
		local function v2WithCats(): any
			local raw = v2Save()
			raw.cats = {
				starter_tabby = v2Cat("starter_tabby", "tabby", "counter_1", { level = 4, xp = 10 }),
				c1 = v2Cat("c1", "tuxedo", "window_1", { charm = 70 }),
				c2 = v2Cat("c2", "snow", "cushion_1"),
				c3 = v2Cat("c3", "calico", nil, { rescued = true }),
				c4 = v2Cat("c4", "void", "shelf_1", { variant = "golden", charm = 64, level = 3, xp = 25 }),
			}
			raw.collection = { tabby = 500, tuxedo = 600, snow = 600, calico = 700, void = 800 }
			return raw
		end

		it("clears every v2 spot and Equip Best fills barista_1 and waiter_1 (two cats working)", function()
			local profile = ProfileSchema.migrate(v2WithCats(), 1000)
			local placed = working(profile)
			expect(count(placed)).to.equal(2)
			-- Void loves barista (37.5 there); Calico as Waiter (3) beats every Common in either slot.
			expect(placed.c4).to.equal("barista_1")
			expect(placed.c3).to.equal("waiter_1")
			local plan = EquipBest.plan(profile)
			expect(EquipBest.isOptimal(profile, plan)).to.equal(true)
		end)

		it("no cat keeps a v2 spot id, and every working cat sits in an open Tier 1 slot", function()
			local profile = ProfileSchema.migrate(v2WithCats(), 1000)
			for _, instance in pairs(profile.cats) do
				if instance.spotId ~= nil then
					expect(Catalog.getSpot(instance.spotId)).to.be.ok()
					expect(Economy.spotIsOpen(profile, instance.spotId)).to.equal(true)
				end
			end
		end)

		it("a v2 save with only the starter puts it to work as the Barista at 1.5 per second", function()
			local profile = ProfileSchema.migrate(v2Save(), 1000)
			expect(working(profile) :: any).to.deepEqual({ starter_tabby = "barista_1" })
			expect(Economy.incomePerSecond(profile)).to.be.near(1.5, 1e-9)
		end)

		it("method: starter for the first Tabby, rescue for rescued cats, net for the rest", function()
			local profile = ProfileSchema.migrate(v2WithCats(), 1000)
			expect(profile.cats.starter_tabby.method).to.equal("starter")
			expect(profile.cats.c3.method).to.equal("rescue")
			for _, uid in ipairs({ "c1", "c2", "c4" }) do
				expect(profile.cats[uid].method).to.equal("net")
			end
		end)

		it("keeps level, xp, charm and the rescued flag; Golden becomes base; no v2 cat has a name", function()
			local raw = v2WithCats()
			raw.cats.c2.name = "Smuggled"
			local profile = ProfileSchema.migrate(raw, 1000)
			local tabby, void = profile.cats.starter_tabby, profile.cats.c4
			expect(tabby.level).to.equal(4)
			expect(tabby.xp).to.equal(10)
			expect(void.variant).to.equal("base")
			expect(void.charm).to.equal(64)
			expect(void.level).to.equal(3)
			expect(void.xp).to.equal(25)
			expect(profile.cats.c1.charm).to.equal(70)
			expect(profile.cats.c3.rescued).to.equal(true)
			expect(profile.cats.c1.rescued).never.to.be.ok()
			for _, instance in pairs(profile.cats) do
				expect(instance.name).never.to.be.ok()
				expect(instance.caughtAt).to.equal(500)
			end
		end)

		it("keeps the collection and adds any owned cat missing from it", function()
			local raw = v2WithCats()
			raw.collection = { tabby = 500, dragon = 1 }
			local profile = ProfileSchema.migrate(raw, 1000)
			expect(profile.collection.tabby).to.equal(500)
			expect(profile.collection.dragon).never.to.be.ok()
			for _, id in ipairs({ "tuxedo", "snow", "calico", "void" }) do
				expect(profile.collection[id]).to.equal(500)
			end
			expect(ProfileSchema.collectionCount(profile)).to.equal(5)
			expect(ProfileSchema.catCount(profile)).to.equal(5)
			expect(count(profile.shinyCollection)).to.equal(0)
		end)

		it("drops cats with unknown ids or a broken entry", function()
			local raw = v2WithCats()
			raw.cats.bad1 = v2Cat("bad1", "golden_tabby", "counter_1")
			raw.cats.bad2 = "not a cat"
			raw.cats[7] = v2Cat("7", "tabby", nil)
			raw.cats.bad3 = { uid = "bad3" }
			local profile = ProfileSchema.migrate(raw, 1000)
			expect(ProfileSchema.catCount(profile)).to.equal(5)
		end)

		it("a v2 save with no cats loads with none, and nothing breaks", function()
			local raw = v2Save()
			raw.cats = {}
			local profile = ProfileSchema.migrate(raw, 1000)
			expect(ProfileSchema.catCount(profile)).to.equal(0)
			expect(Economy.incomePerSecond(profile)).to.equal(0)
		end)
	end)

	describe("migrate on a version 3 save", function()
		local function v3Save(): any
			local raw: any = ProfileSchema.template(100)
			raw.tier = 3
			raw.coins = 4321
			raw.upgradeLevels = { tables = 6, espresso = 4, net = 3, lure_bowl = 1 }
			raw.lures = { kibble = 1, caviar = 2 }
			raw.bait = { lureId = "tuna", placedAt = 90, catId = "siamese", variant = "shiny", charm = 88 }
			raw.dealer = { window = 2938211, bought = { ["2"] = true } }
			raw.cats.c1 = {
				uid = "c1",
				catId = "bengal",
				variant = "shiny",
				caughtAt = 95,
				spotId = "entertainer_1",
				level = 2,
				xp = 3,
				charm = 61,
				name = "Zoom",
				method = "bait",
			}
			raw.cats.c2 = {
				uid = "c2",
				catId = "calico",
				variant = "base",
				caughtAt = 96,
				spotId = "greeter_1",
				level = 1,
				xp = 0,
				charm = 50,
				rescued = true,
				method = "rescue",
			}
			raw.collection = { tabby = 100, bengal = 95, calico = 96 }
			raw.shinyCollection = { bengal = 95 }
			return raw
		end

		it("a fresh template loads unchanged", function()
			local template = ProfileSchema.template(100)
			expect(ProfileSchema.migrate(ProfileSchema.template(100), 500) :: any).to.deepEqual(template)
		end)

		it("a full v3 save loads unchanged: tier, slots, names, method, shiny, bait and dealer", function()
			local raw = v3Save()
			local before = ProfileSchema.migrate(v3Save(), 500)
			expect(before.coins).to.equal(4321)
			expect(before.tier).to.equal(3)
			expect(before.upgradeLevels :: any).to.deepEqual(raw.upgradeLevels)
			expect(working(before) :: any).to.deepEqual({
				starter_tabby = "barista_1",
				c1 = "entertainer_1",
				c2 = "greeter_1",
			})
			expect(before.cats.c1.name).to.equal("Zoom")
			expect(before.cats.c1.method).to.equal("bait")
			expect(before.cats.c1.variant).to.equal("shiny")
			expect(before.cats.c2.method).to.equal("rescue")
			expect(before.bait :: any).to.deepEqual(raw.bait)
			expect(before.dealer :: any).to.deepEqual(raw.dealer)
			expect(before.shinyCollection :: any).to.deepEqual({ bengal = 95 })
			-- and loading the result again changes nothing
			expect(ProfileSchema.migrate(before, 900) :: any).to.deepEqual(before)
		end)

		it("does not run Equip Best: a deliberate v3 placement stays as saved", function()
			local raw = v3Save()
			raw.cats.c1.spotId = "waiter_2" -- the Bengal loves entertainer, but the player put it here
			local profile = ProfileSchema.migrate(raw, 500)
			expect(profile.cats.c1.spotId).to.equal("waiter_2")
		end)

		it("clears slots above the tier, unknown or v2 slot ids, and a second cat on one slot", function()
			local raw = v3Save()
			raw.tier = 1
			raw.cats.c2.spotId = "barista_1" -- the starter already works it
			raw.cats.c3 = { uid = "c3", catId = "snow", caughtAt = 1, spotId = "window_1" }
			local profile = ProfileSchema.migrate(raw, 500)
			expect(profile.cats.c1.spotId).never.to.be.ok() -- entertainer_1 opens at Tier 3
			expect(profile.cats.c3.spotId).never.to.be.ok()
			local onBarista = 0
			for _, instance in pairs(profile.cats) do
				if instance.spotId == "barista_1" then
					onBarista += 1
				end
			end
			expect(onBarista).to.equal(1)
		end)

		it("clamps the tier to 1 to 5 and levels to each upgrade's range", function()
			for _, case in ipairs({ { 0, 1 }, { 9, 5 }, { "2", 1 }, { 2.5, 2 } }) do
				local raw = v3Save()
				raw.tier = case[1]
				expect(ProfileSchema.migrate(raw, 500).tier).to.equal(case[2])
			end
			local raw = v3Save()
			raw.upgradeLevels = { tables = 40, espresso = -2, net = "x", lure_bowl = 3, cafe_level = 4 }
			local profile: any = ProfileSchema.migrate(raw, 500)
			expect(profile.upgradeLevels).to.deepEqual({ tables = 6, espresso = 1, net = 0, lure_bowl = 1 })
			expect(profile.coins).to.equal(4321) -- refunds are for the 2 to 3 step only
		end)

		it("keeps only known methods, and a missing method stays missing", function()
			local raw = v3Save()
			raw.cats.c1.method = "stolen"
			raw.cats.c2.method = nil
			local profile = ProfileSchema.migrate(raw, 500)
			expect(profile.cats.c1.method).never.to.be.ok()
			expect(profile.cats.c2.method).never.to.be.ok()
			expect(profile.cats.starter_tabby.method).to.equal("starter")
		end)

		it("adds a shiny cat to the shiny page if the save missed it", function()
			local raw = v3Save()
			raw.shinyCollection = {}
			local profile = ProfileSchema.migrate(raw, 500)
			expect(profile.shinyCollection :: any).to.deepEqual({ bengal = 95 })
		end)

		it("drops a bait with an unknown food or cat or a bad time, and fixes its variant and charm", function()
			local cases: { any } = {
				{ lureId = "pizza", placedAt = 90, catId = "siamese", variant = "base", charm = 50 },
				{ lureId = "tuna", placedAt = 90, catId = "dragon", variant = "base", charm = 50 },
				{ lureId = "tuna", placedAt = 0 / 0, catId = "siamese", variant = "base", charm = 50 },
				{ lureId = "tuna", catId = "siamese", variant = "base", charm = 50 },
				"tuna",
			}
			for _, bait in ipairs(cases) do
				local raw = v3Save()
				raw.bait = bait
				expect(ProfileSchema.migrate(raw, 500).bait).never.to.be.ok()
			end
			local raw = v3Save()
			raw.bait = { lureId = "star_treat", placedAt = 90.7, catId = "aurora", variant = "galaxy", charm = 400 }
			expect(ProfileSchema.migrate(raw, 500).bait :: any).to.deepEqual({
				lureId = "star_treat",
				placedAt = 90,
				catId = "aurora",
				variant = "base",
				charm = 100,
			})
		end)

		it("keeps the autoPress flag only when a v3 save holds it as true", function()
			local raw = v3Save()
			raw.flags = { autoPress = true }
			expect(ProfileSchema.migrate(raw, 500).flags.autoPress).to.equal(true)
			for _, flags in ipairs({ { autoPress = "yes" }, {}, "junk" } :: { any }) do
				raw.flags = flags
				expect(ProfileSchema.migrate(raw, 500).flags.autoPress).to.equal(false)
			end
			local v2 = v2Save()
			v2.flags = { autoPress = true }
			expect(ProfileSchema.migrate(v2, 1000).flags.autoPress).to.equal(false)
		end)

		it("keeps dealer marks only for slots 1 to 3 saved as true", function()
			local raw = v3Save()
			raw.dealer = { window = 77.9, bought = { ["1"] = true, ["2"] = "yes", ["4"] = true, [3] = true } }
			expect(ProfileSchema.migrate(raw, 500).dealer :: any).to.deepEqual({ window = 77, bought = { ["1"] = true } })
			raw.dealer = "junk"
			expect(ProfileSchema.migrate(raw, 500).dealer :: any).to.deepEqual({ window = 0, bought = {} })
		end)
	end)

	describe("saved names (section 4, reviewer N36)", function()
		local function loadName(name: any): string?
			local raw: any = ProfileSchema.template(100)
			raw.cats.starter_tabby.name = name
			return ProfileSchema.migrate(raw, 500).cats.starter_tabby.name
		end

		it("keeps a normal name, emoji and accents included", function()
			expect(loadName("Mochi")).to.equal("Mochi")
			expect(loadName("Señor Whiskers")).to.equal("Señor Whiskers")
			expect(loadName("Bean 🐾")).to.equal("Bean 🐾")
		end)

		it("drops an empty name, a non-string and invalid UTF-8", function()
			expect(loadName("")).never.to.be.ok()
			expect(loadName(42)).never.to.be.ok()
			expect(loadName({})).never.to.be.ok()
			expect(loadName("bad\255name")).never.to.be.ok()
			expect(loadName("\192\128")).never.to.be.ok()
		end)

		it("cuts a long name to 200 bytes on a character boundary", function()
			expect(loadName(string.rep("a", 250))).to.equal(string.rep("a", 200))
			expect(loadName(string.rep("a", 200))).to.equal(string.rep("a", 200))
			-- 199 bytes then a three byte character: cutting at 200 would split it, so it goes whole
			local cut = loadName(string.rep("a", 199) .. "€" .. "b")
			expect(cut).to.equal(string.rep("a", 199))
			-- two byte characters line up with 200, so exactly 100 of them stay
			local accents = loadName(string.rep("é", 150))
			expect(accents).to.equal(string.rep("é", 100))
			for _, name in ipairs({ cut, accents }) do
				expect(utf8.len(name :: string)).to.be.ok()
				expect(#(name :: string) <= 200).to.equal(true)
			end
		end)
	end)

	describe("damaged and empty saves", function()
		it("nil, a string or a number gives a fresh template", function()
			for _, raw in ipairs({ "junk", 42, true }) do
				expect(ProfileSchema.migrate(raw, 100) :: any).to.deepEqual(ProfileSchema.template(100))
			end
			expect(ProfileSchema.migrate(nil, 100) :: any).to.deepEqual(ProfileSchema.template(100))
		end)

		it("an empty table is a version 1 save: the starter works as Barista with 50 coins", function()
			local profile = ProfileSchema.migrate({}, 100)
			expect(profile.version).to.equal(3)
			expect(profile.tier).to.equal(1)
			expect(profile.coins).to.equal(Config.StartCoins)
			expect(working(profile) :: any).to.deepEqual({ starter_tabby = "barista_1" })
			expect(profile.collection.tabby).to.equal(100)
		end)

		it("negative or NaN coins fall back to the start coins before any refund", function()
			for _, bad in ipairs({ -10, 0 / 0, "999" }) do
				local raw = v2Save({ park_access = 1 })
				raw.coins = bad
				expect(ProfileSchema.migrate(raw, 1000).coins).to.equal(Config.StartCoins + 1000)
			end
		end)
	end)
end
