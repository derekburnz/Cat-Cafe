--!strict
-- The Rainbow coat (F99, rainbow-coat.md): the coat roll (rainbow first on the same roll, so gold keeps its chance),
-- what a rainbow cat earns and fetches, the Index's Rainbow track and its luck, the shout-outs, and save version 24.
-- QA checks 2, 3, 7 and 8 of section 6 are here; the rest are Studio rows.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local CatStats = require(Shared.CatStats)
	local Collector = require(Shared.Collector)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local IndexRewards = require(Shared.IndexRewards)
	local Leaderboards = require(Shared.Leaderboards)
	local ProfileSchema = require(Shared.ProfileSchema)

	local function catsOf(rarity: string?, exclusive: boolean): { any }
		local found = {}
		for _, def in Catalog.cats do
			if
				(rarity == nil or def.rarity == rarity)
				and (def.exclusive == true) == exclusive
				and def.area ~= "spare"
				and (exclusive or Catalog.getArea(def.area) ~= nil)
			then
				table.insert(found, def)
			end
		end
		return found
	end

	local common = catsOf("Common", false)[1]
	local exclusive = catsOf(nil, true)[1]

	describe("the coat roll (section 1)", function()
		it("is rainbow below the rainbow chance, gold in the next gold chance, else base", function()
			expect(Catching.rollCoat(common, 0.004, 0.005, 0.05)).to.equal("rainbow")
			expect(Catching.rollCoat(common, 0.005, 0.005, 0.05)).to.equal("gold")
			expect(Catching.rollCoat(common, 0.054, 0.005, 0.05)).to.equal("gold")
			expect(Catching.rollCoat(common, 0.055, 0.005, 0.05)).to.equal("base")
			expect(Catching.rollCoat(common, 0.9, 0.005, 0.05)).to.equal("base")
		end)

		it("never gives an exclusive cat a coat", function()
			assert(exclusive, "an exclusive cat")
			expect(Catching.rollCoat(exclusive, 0, 0.005, 0.05)).to.equal("base")
			expect(Catching.rollCoat(exclusive, 0.01, 0.005, 0.05)).to.equal("base")
		end)

		-- Bait's rolls with no luck: `rolls` places from `roll(i)`, the share that came out rainbow and gold.
		local function shares(def: any, n: number, roll: (number) -> number): (number, number)
			local rainbow, gold = 0, 0
			for i = 1, n do
				local coat = Catching.rollCoat(
					def,
					roll(i),
					IndexRewards.rainbowChance(Config.RainbowChanceBait, 0),
					IndexRewards.rollChance(Config.GoldChanceBait, 0)
				)
				if coat == "rainbow" then
					rainbow += 1
				elseif coat == "gold" then
					gold += 1
				end
			end
			return rainbow / n, gold / n
		end

		it("rolls bait at exactly 0.5% rainbow and 5% gold over evenly spread rolls, alike for every rarity", function()
			for _, rarity in { "Common", "Rare", "Epic", "Legendary", "Mythical" } do
				local def = catsOf(rarity, false)[1]
				assert(def, rarity)
				local rainbow, gold = shares(def, 100000, function(i: number): number
					return (i - 0.5) / 100000
				end)
				expect(rainbow).to.be.near(0.005, 1e-9)
				expect(gold).to.be.near(0.05, 1e-9)
			end
		end)

		it("rolls bait near 0.5% rainbow and 5% gold over 100,000 random placements (check 2)", function()
			local rng = Random.new(99)
			local rainbow, gold = shares(common, 100000, function(): number
				return rng:NextNumber()
			end)
			-- three standard deviations of 100,000 rolls: 0.07 points for rainbow, 0.21 for gold
			expect(math.abs(rainbow - 0.005) <= 0.0007).to.equal(true)
			expect(math.abs(gold - 0.05) <= 0.0021).to.equal(true)
		end)
	end)

	describe("earnings and the Cat Collector", function()
		it("a rainbow cat at work earns exactly twice the same cat in gold (check 3)", function()
			local spotId = Catalog.spots[1].id
			local function at(variant: string): number
				local instance = CatStats.newInstance("u1", common.id, 100, 50)
				instance.variant = variant
				instance.spotId = spotId
				return Economy.catRate(instance, 1)
			end
			expect(at("gold") > 0).to.equal(true)
			expect(at("rainbow")).to.be.near(2 * at("gold"), 1e-9)
			expect(CatStats.variantMultiplier("rainbow")).to.equal(Config.RainbowMultiplier)
		end)

		it("the Collector values a rainbow cat at ten times the base cat (check 8)", function()
			local base = CatStats.newInstance("u1", common.id, 100, 50)
			local rainbow = CatStats.newInstance("u2", common.id, 100, 50)
			rainbow.variant = "rainbow"
			expect(Collector.value(rainbow, 0.5)).to.be.near(10 * Collector.value(base, 0.5), 1e-9)
		end)

		it("a rainbow cat arrives locked, like a gold one", function()
			expect(CatStats.arrivesLocked(common.id, "rainbow")).to.equal(true)
			expect(CatStats.arrivesLocked(common.id, "base")).to.equal(false)
		end)
	end)

	describe("the Rainbow track (section 4)", function()
		local function profileWith(rainbow: { [string]: number }, claims: { [string]: boolean }?): any
			local profile: any = ProfileSchema.template(100)
			profile.rainbowCollection = rainbow
			profile.indexRewards = if claims ~= nil then { rainbow = claims } else {}
			return profile
		end

		it("has five milestones on the Rainbow page, their luck adding up to RainbowLuckMax", function()
			local page = Catalog.indexPrizes[IndexRewards.RAINBOW]
			assert(page, "the Rainbow page")
			local luck = 0
			for _, id in { "rainbow1", "rainbow3", "rainbow5", "rainbow10", "rainbow25" } do
				local milestone = IndexRewards.milestone(id)
				assert(milestone, id)
				expect(milestone.track).to.equal("rainbow")
				expect(page[id]).to.be.ok()
				luck += page[id].rainbowLuck or 0
			end
			expect(luck).to.be.near(Config.RainbowLuckMax, 1e-9)
			expect(page.rainbow1.tag).to.equal("Rainbow Finder")
			expect(page.rainbow25.tag).to.equal("Rainbow Master")
		end)

		it("counts different rainbow cats across every area and never an exclusive cat", function()
			local found: { [string]: number } = {}
			local commons = catsOf("Common", false)
			for i = 1, 3 do
				found[commons[i].id] = 1
			end
			found[exclusive.id] = 1
			local profile = profileWith(found)
			local milestone = IndexRewards.milestone("rainbow3") :: any
			expect(IndexRewards.count(profile, IndexRewards.RAINBOW, milestone)).to.equal(3)
			expect(IndexRewards.blocker(profile, IndexRewards.RAINBOW, "rainbow3")).to.equal(nil)
			expect(IndexRewards.blocker(profile, IndexRewards.RAINBOW, "rainbow5")).to.equal(
				"Find 2 more rainbow cats first"
			)
		end)

		it("lifts the food card's rainbow line to 0.6%, 0.75% and 1% as rainbow5, 10 and 25 are claimed (check 7)", function()
			expect(IndexRewards.rainbowLuck(profileWith({}))).to.equal(0)
			local claims: { [string]: boolean } = {}
			local chances: { [string]: number } = { rainbow5 = 0.006, rainbow10 = 0.0075, rainbow25 = 0.01 }
			for _, id in { "rainbow5", "rainbow10", "rainbow25" } do
				claims[id] = true
				local luck = IndexRewards.rainbowLuck(profileWith({}, table.clone(claims)))
				expect(IndexRewards.rainbowChance(Config.RainbowChanceBait, luck)).to.be.near(chances[id], 1e-9)
			end
			-- gold luck is apart: the Rainbow track adds none, and rainbow luck is not in the gold totals
			expect(IndexRewards.totals(profileWith({}, claims)).goldLuck).to.equal(0)
		end)

		it("rolls shared rainbows with the best rainbow luck among players with the area open", function()
			local lucky = profileWith({}, { rainbow5 = true, rainbow10 = true })
			local plain = profileWith({})
			local function tierOf(profile: any): number
				return if profile == lucky then 1 else 5
			end
			expect(IndexRewards.bestRainbowLuck({ plain, lucky }, 1, tierOf)).to.be.near(0.5, 1e-9)
			expect(IndexRewards.bestRainbowLuck({ plain, lucky }, 3, tierOf)).to.equal(0)
		end)

		it("each rainbow coat counts toward the Index leaderboard", function()
			local profile = profileWith({ [common.id] = 1, [exclusive.id] = 1 })
			local before = Leaderboards.indexEntries(profileWith({}))
			expect(Leaderboards.indexEntries(profile)).to.equal(before + 1)
		end)
	end)

	describe("shout-outs (section 2)", function()
		it("shouts out every rainbow cat, a Common too, and names the stray's area on its spawn", function()
			expect(Catching.shoutOut("Sam", "caught", common, "rainbow")).to.equal(
				string.format("Sam caught a rainbow Common %s!", common.name)
			)
			expect(Catching.rainbowSpawnText(common, "Woods")).to.equal(
				string.format("A Rainbow %s is out in the Woods!", common.name)
			)
			expect(Catching.waveShoutOut("Mythical", "rainbow", "Woods")).to.equal(
				"A rainbow Mythical cat appeared in the Woods!"
			)
		end)
	end)

	describe("save version 24 (section 5)", function()
		it("keeps a rainbow cat, the rainbow collection and the count", function()
			local raw: any = ProfileSchema.template(100)
			local instance = CatStats.newInstance("r1", common.id, 90, 50)
			instance.variant = "rainbow"
			raw.cats.r1 = instance
			raw.rainbowCollection = { [exclusive.id] = 80, not_a_cat = 70 }
			raw.stats.rainbowCatches = 2
			local profile = ProfileSchema.migrate(raw, 1000)
			expect(profile.cats.r1.variant).to.equal("rainbow")
			-- every rainbow cat owned is in the collection; unknown ids go
			expect(profile.rainbowCollection[common.id]).to.equal(90)
			expect(profile.rainbowCollection[exclusive.id]).to.equal(80)
			expect((profile.rainbowCollection :: any).not_a_cat).never.to.be.ok()
			expect(profile.stats.rainbowCatches).to.equal(2)
			expect(ProfileSchema.migrate(profile, 1000) :: any).to.deepEqual(profile)
		end)

		it("gives a version 23 save an empty rainbow collection", function()
			local raw: any = ProfileSchema.template(100)
			raw.version = 23
			raw.rainbowCollection = nil
			raw.stats.rainbowCatches = nil
			local profile = ProfileSchema.migrate(raw, 1000)
			expect(next(profile.rainbowCollection)).never.to.be.ok()
			expect(profile.stats.rainbowCatches).to.equal(0)
			expect(profile.version).to.equal(ProfileSchema.VERSION)
		end)
	end)
end
