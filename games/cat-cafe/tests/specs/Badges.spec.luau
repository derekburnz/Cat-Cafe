--!strict
-- Badges.luau against release.md section 1 (#1934): the 21 badges in creation order with their Config keys, what
-- earns each (read from the profile alone, never a shop-only cat), which are due (made, not owned, not waiting on a
-- retry) and the PURRFECT counts.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Badges = require(Shared.Badges)
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local ProfileSchema = require(Shared.ProfileSchema)

	local NOW = 1_800_000_000

	local function fresh(): any
		return ProfileSchema.template(NOW)
	end

	local function has(profile: any, key: string): boolean
		return table.find(Badges.earned(profile), key) ~= nil
	end

	-- the first cat (not spare, not shop-only) of `rarity`, or of any rarity when nil
	local function catOf(rarity: string?): any
		for _, def in Catalog.cats do
			if
				def.area ~= "spare"
				and def.exclusive ~= true
				and (rarity == nil or def.rarity == rarity)
			then
				return def
			end
		end
		error("no cat of " .. tostring(rarity))
	end

	-- `count` distinct cats that are not spare or shop-only, into the collection
	local function collect(profile: any, count: number)
		local added = 0
		for _, def in Catalog.cats do
			if added >= count then
				break
			end
			if
				def.area ~= "spare"
				and def.exclusive ~= true
				and profile.collection[def.id] == nil
			then
				profile.collection[def.id] = NOW
				added += 1
			end
		end
	end

	-- runs `fn` with Config.Badges set to `ids`, then puts the real table back
	local function withIds(ids: { [string]: number }, fn: () -> ())
		local config = Config :: any
		local real = config.Badges
		config.Badges = ids
		local ok, err = pcall(fn)
		config.Badges = real
		if not ok then
			error(err, 0)
		end
	end

	describe("the list (section 1)", function()
		it("is the 28 badges in badges-order.md's order, each with a Config key (#3618)", function()
			local keys = {
				"firstCatch",
				"firstHome",
				"firstUpgrade",
				"firstFlight",
				"welcome",
				"grandOpening",
				"cornerCafe",
				"cozyCafe",
				"busyCafe",
				"famousCafe",
				"grandCafe",
				"sunstoneCafe",
				"wonderCafe",
				"purrfect",
				"purrfectStreak",
				"baitCat",
				"rareFind",
				"legendaryFind",
				"mythicalFind",
				"catCollector",
				"catExpert",
				"goldenCoat",
				"rainbowCoat",
				"pageComplete",
				"helpingPaw",
				"firstTrade",
				"metOwner",
			}
			expect(#Badges.LIST).to.equal(#keys)
			for i, key in keys do
				local badge = Badges.LIST[i]
				expect(badge.key).to.equal(key)
				expect(Config.Badges[key]).to.be.a("number")
				expect(#badge.name > 0).to.equal(true)
				expect(#badge.description > 0).to.equal(true)
				expect(Badges.get(key)).to.equal(badge)
			end
			local configKeys = 0
			for _ in Config.Badges do
				configKeys += 1
			end
			expect(configKeys).to.equal(#keys)
		end)

		it("has one plain line per badge, never about buying, liking or inviting", function()
			for _, badge in Badges.LIST do
				local text = string.lower(badge.name .. " " .. badge.description)
				for _, word in
					{ "robux", "buy", "like", "favorite", "favourite", "invite", "streak of days" }
				do
					expect(string.find(text, word, 1, true)).to.equal(nil)
				end
				expect(string.find(badge.description, "\n", 1, true)).to.equal(nil)
			end
		end)

		it("reads a 0, a fraction or a negative id as not made", function()
			withIds({ welcome = 0, firstCatch = 1.5, cozyCafe = -4, grandOpening = 123 }, function()
				expect(Badges.id("welcome")).to.equal(0)
				expect(Badges.id("firstCatch")).to.equal(0)
				expect(Badges.id("cozyCafe")).to.equal(0)
				expect(Badges.id("grandOpening")).to.equal(123)
				expect(Badges.id("unknown")).to.equal(0)
			end)
		end)
	end)

	describe("what earns each", function()
		it("gives a fresh save nothing", function()
			expect(#Badges.earned(fresh())).to.equal(0)
		end)

		it(
			"gives the first-hour badges: tutorial, first catch, Tier 2, roadmap, PURRFECT",
			function()
				local profile = fresh()
				profile.tutorialStep = 4
				expect(has(profile, "welcome")).to.equal(false)
				profile.tutorialStep = Badges.WELCOME_STEP
				expect(has(profile, "welcome")).to.equal(true)
				profile.stats.grabsSucceeded = 1
				expect(has(profile, "firstCatch")).to.equal(true)
				profile.tier = 2
				expect(has(profile, "cozyCafe")).to.equal(true)
				expect(has(profile, "busyCafe")).to.equal(false)
				profile.grandOpening.finished = true
				expect(has(profile, "grandOpening")).to.equal(true)
				Badges.noteFinish(profile.stats, true)
				expect(has(profile, "purrfect")).to.equal(true)
				profile.stats.baitsTamed = 1
				expect(has(profile, "baitCat")).to.equal(true)
			end
		)

		it("gives each tier's badge from Tier 3 to 5, and the lower ones with it", function()
			local profile = fresh()
			profile.tier = 5
			for _, key in { "cozyCafe", "busyCafe", "famousCafe", "grandCafe" } do
				expect(has(profile, key)).to.equal(true)
			end
		end)

		it("counts a Legendary toward Rare Find, and a shop-only cat toward nothing", function()
			local profile = fresh()
			profile.collection[catOf("Legendary").id] = NOW
			expect(has(profile, "rareFind")).to.equal(true)
			expect(has(profile, "legendaryFind")).to.equal(true)
			expect(has(profile, "mythicalFind")).to.equal(false)
			local shop = fresh()
			for _, def in Catalog.cats do
				if def.exclusive == true then
					shop.collection[def.id] = NOW
					shop.goldCollection[def.id] = NOW
					shop.rainbowCollection[def.id] = NOW
				end
			end
			for _, key in
				{
					"rareFind",
					"legendaryFind",
					"mythicalFind",
					"goldenCoat",
					"rainbowCoat",
					"pageComplete",
				}
			do
				expect(has(shop, key)).to.equal(false)
			end
		end)

		it("gives Cat Collector at 25 different cats and Cat Expert at 50", function()
			local profile = fresh()
			collect(profile, Badges.COLLECTOR_CATS - 1 - Economy.distinctCats(profile))
			expect(has(profile, "catCollector")).to.equal(false)
			collect(profile, 1)
			expect(has(profile, "catCollector")).to.equal(true)
			expect(has(profile, "catExpert")).to.equal(false)
			collect(profile, Badges.EXPERT_CATS - Economy.distinctCats(profile))
			expect(has(profile, "catExpert")).to.equal(true)
		end)

		it("gives the coat badges from a gold or rainbow cat", function()
			local profile = fresh()
			profile.goldCollection[catOf().id] = NOW
			expect(has(profile, "goldenCoat")).to.equal(true)
			expect(has(profile, "rainbowCoat")).to.equal(false)
			profile.rainbowCollection[catOf().id] = NOW
			expect(has(profile, "rainbowCoat")).to.equal(true)
		end)

		it("gives Page Complete only once every cat of one area's page is in", function()
			local profile = fresh()
			local alley = {}
			for _, def in Catalog.cats do
				if def.area == "alley" and def.exclusive ~= true then
					table.insert(alley, def.id)
				end
			end
			expect(#alley > 1).to.equal(true)
			for i = 1, #alley - 1 do
				profile.collection[alley[i]] = NOW
			end
			expect(has(profile, "pageComplete")).to.equal(false)
			profile.collection[alley[#alley]] = NOW
			expect(has(profile, "pageComplete")).to.equal(true)
		end)

		it("gives Helping Paw for a helped rescue and First Trade for a trade", function()
			local profile = fresh()
			profile.stats.rescues = 3 -- a rescue of your own is not helping
			expect(has(profile, "helpingPaw")).to.equal(false)
			profile.stats.teamRescuesHelped = 1
			expect(has(profile, "helpingPaw")).to.equal(true)
			profile.stats.trades = 1
			expect(has(profile, "firstTrade")).to.equal(true)
		end)
	end)

	describe("the PURRFECT counts", function()
		it("counts a run of PURRFECTs, ends it on any other finish, keeps the best", function()
			local stats = fresh().stats
			for _ = 1, 4 do
				Badges.noteFinish(stats, true)
			end
			Badges.noteFinish(stats, false)
			expect(stats.purrfectCatches).to.equal(4)
			expect(stats.purrfectStreak).to.equal(0)
			expect(stats.bestPurrfectStreak).to.equal(4)
			Badges.noteFinish(stats, true)
			expect(stats.purrfectStreak).to.equal(1)
			expect(stats.bestPurrfectStreak).to.equal(4)
		end)

		it("gives Purrfect Streak at 5 in a row and keeps it after the run ends", function()
			local profile = fresh()
			for _ = 1, Badges.PURRFECT_RUN do
				Badges.noteFinish(profile.stats, true)
			end
			expect(has(profile, "purrfectStreak")).to.equal(true)
			Badges.noteFinish(profile.stats, false)
			expect(has(profile, "purrfectStreak")).to.equal(true)
		end)

		it("keeps the counts through a save and load", function()
			local profile = fresh()
			for _ = 1, 3 do
				Badges.noteFinish(profile.stats, true)
			end
			profile.stats.teamRescuesHelped = 2
			local loaded: any = ProfileSchema.migrate(profile, NOW)
			expect(loaded.stats.purrfectCatches).to.equal(3)
			expect(loaded.stats.purrfectStreak).to.equal(3)
			expect(loaded.stats.bestPurrfectStreak).to.equal(3)
			expect(loaded.stats.teamRescuesHelped).to.equal(2)
		end)
	end)

	describe("the six new badges (#3618)", function()
		it("each reads only from the save", function()
			local profile = fresh()
			profile.stats.catsCaught = 1
			expect(has(profile, "firstHome")).to.equal(true)
			expect(has(profile, "firstUpgrade")).to.equal(false)
			profile.upgradeLevels.tables = math.max(
				profile.upgradeLevels.tables or 0,
				Config.StartTables
			) + 1
			expect(has(profile, "firstUpgrade")).to.equal(true)
			expect(has(profile, "firstFlight")).to.equal(false)
			profile.stats.cannonFlights = 1
			expect(has(profile, "firstFlight")).to.equal(true)
			expect(has(profile, "cornerCafe")).to.equal(false)
			profile.tutorialStep = Badges.WELCOME_STEP
			expect(has(profile, "cornerCafe")).to.equal(true)
			profile.tier = 6
			expect(has(profile, "sunstoneCafe")).to.equal(true)
			expect(has(profile, "wonderCafe")).to.equal(false)
			profile.tier = 7
			expect(has(profile, "wonderCafe")).to.equal(true)
		end)
	end)

	describe("which are due (section 1's catch-up and retries)", function()
		it("skips a badge with id 0, one owned and one waiting on a retry", function()
			local profile = fresh()
			profile.tutorialStep = 5
			profile.stats.grabsSucceeded = 1
			profile.tier = 3
			withIds({ welcome = 11, firstCatch = 12, cozyCafe = 0, busyCafe = 14 }, function()
				local due = Badges.due(profile, {}, {}, 100)
				expect(table.concat(due, ",")).to.equal("firstCatch,welcome,busyCafe")
				due = Badges.due(profile, { [12] = true }, { busyCafe = 160 }, 100)
				expect(table.concat(due, ",")).to.equal("welcome")
				due = Badges.due(profile, { [12] = true }, { busyCafe = 160 }, 160)
				expect(table.concat(due, ",")).to.equal("welcome,busyCafe")
			end)
		end)

		it(
			"adds Met the Owner only while the server passes it, and only once made (#3324)",
			function()
				local profile = fresh()
				expect(table.find(Badges.earned(profile), "metOwner")).to.equal(nil)
				withIds({ metOwner = 0 }, function()
					expect(#Badges.due(profile, {}, {}, 0, { metOwner = true })).to.equal(0)
				end)
				withIds({ metOwner = 21 }, function()
					expect(#Badges.due(profile, {}, {}, 0)).to.equal(0)
					expect(table.concat(Badges.due(profile, {}, {}, 0, { metOwner = true }), ",")).to.equal(
						"metOwner"
					)
					expect(#Badges.due(profile, { [21] = true }, {}, 0, { metOwner = true })).to.equal(
						0
					)
					expect(#Badges.due(profile, {}, {}, 0, { notABadge = true })).to.equal(0)
				end)
			end
		)

		it("is empty while no badge is made", function()
			local profile = fresh()
			profile.tier = 5
			profile.tutorialStep = 5
			withIds({}, function()
				expect(#Badges.due(profile, {}, {}, 0)).to.equal(0)
			end)
		end)
	end)
end
