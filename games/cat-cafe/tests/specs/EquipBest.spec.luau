--!strict
-- EquipBest.luau: the one-tap placement must be the best possible placement over the open role slots (data-model
-- v0.3.1 section 4b), never worse than greedy, and must leave cats where they are when nothing improves.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatStats = require(Shared.CatStats)
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local EquipBest = require(Shared.EquipBest)
	local ProfileSchema = require(Shared.ProfileSchema)

	local function profileAt(tier: number, withStarter: boolean?)
		local profile = ProfileSchema.template(0)
		profile.tier = tier
		if withStarter ~= true then
			profile.cats = {}
		end
		return profile
	end

	local function addCat(
		profile: any,
		uid: string,
		catId: string,
		charm: number?,
		level: number?,
		spotId: string?
	)
		local instance = CatStats.newInstance(uid, catId, 0, charm)
		if level ~= nil then
			instance.level = level
		end
		instance.spotId = spotId
		profile.cats[uid] = instance
		return instance
	end

	-- Exhaustive search over "each open spot gets one distinct cat or nobody" for small cases.
	local function bruteForce(profile: any): number
		local spots = EquipBest.openSpots(profile)
		local cats: { any } = {}
		for _, instance in pairs(profile.cats) do
			table.insert(cats, instance)
		end
		local used = {}
		local function search(index: number): number
			if index > #spots then
				return 0
			end
			local best = search(index + 1) -- leave this spot empty
			for i, instance in ipairs(cats) do
				if not used[i] then
					used[i] = true
					local value = EquipBest.value(instance, spots[index]) + search(index + 1)
					used[i] = nil
					if value > best then
						best = value
					end
				end
			end
			return best
		end
		return search(1)
	end

	local function lcg(seed: number): () -> number
		local state = seed
		return function()
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
	end

	describe("value", function()
		it(
			"is the rating, times 1.5 in a slot of the favorite role, 0 for an unknown cat",
			function()
				local tabby = CatStats.newInstance("t", "tabby", 0)
				expect(EquipBest.value(tabby, Catalog.getSpot("barista_1") :: any)).to.be.near(
					Config.FavoriteMultiplier
				)
				expect(EquipBest.value(tabby, Catalog.getSpot("barista_3") :: any)).to.be.near(
					Config.FavoriteMultiplier
				)
				expect(EquipBest.value(tabby, Catalog.getSpot("waiter_1") :: any)).to.equal(1)
				local nope = CatStats.newInstance("n", "nope", 0)
				expect(EquipBest.value(nope, Catalog.getSpot("waiter_1") :: any)).to.equal(0)
			end
		)
	end)

	describe("restAll", function()
		it("rests every working cat, counts them and leaves resting cats alone", function()
			local profile = profileAt(3)
			addCat(profile, "a", "tabby", nil, nil, "barista_1")
			addCat(profile, "b", "tabby", nil, nil, "waiter_1")
			addCat(profile, "c", "tabby")
			expect(EquipBest.restAll(profile)).to.equal(2)
			for _, instance in pairs(profile.cats) do
				expect(instance.spotId).to.equal(nil)
			end
			expect(Economy.incomePerSecond(profile)).to.equal(0)
			expect(EquipBest.restAll(profile)).to.equal(0)
		end)

		it("leaves equip best a clean slate to place from", function()
			local profile = profileAt(3)
			addCat(profile, "a", "tabby", nil, nil, "waiter_1")
			addCat(profile, "b", "tabby")
			EquipBest.restAll(profile)
			local plan = EquipBest.plan(profile)
			expect(EquipBest.apply(profile, plan)).to.equal(plan.catsPlaced)
			expect(EquipBest.isOptimal(profile, plan)).to.equal(true)
		end)
	end)

	describe("plan", function()
		it("a fresh cafe is already optimal: Tabby stays Barista, nothing changes", function()
			local profile = profileAt(1, true)
			local plan = EquipBest.plan(profile)
			expect(plan.placements.starter_tabby).to.equal("barista_1")
			expect(plan.spotsOpen).to.equal(2)
			expect(plan.catsPlaced).to.equal(1)
			expect(plan.baseRate).to.be.near(1.5)
			expect(EquipBest.isOptimal(profile, plan)).to.equal(true)
			expect(EquipBest.apply(profile, plan)).to.equal(0)
		end)

		it("fills open spots with favorites first and rests the overflow", function()
			local profile = profileAt(1)
			addCat(profile, "a", "tabby") -- loves barista
			addCat(profile, "b", "tuxedo") -- loves waiter
			addCat(profile, "c", "ginger") -- loves greeter (no greeter slot at Tier 1)
			local plan = EquipBest.plan(profile)
			expect(plan.placements.a).to.equal("barista_1")
			expect(plan.placements.b).to.equal("waiter_1")
			expect(plan.placements.c).never.to.be.ok()
			expect(plan.baseRate).to.be.near(3)
			expect(EquipBest.apply(profile, plan)).to.equal(2)
			expect(profile.cats.a.spotId).to.equal("barista_1")
			expect(profile.cats.b.spotId).to.equal("waiter_1")
			expect(profile.cats.c.spotId).never.to.be.ok()
			expect(EquipBest.isOptimal(profile, plan)).to.equal(true)
		end)

		it("beats greedy-by-rating: a weaker cat on its favorite spot can be worth more", function()
			-- Two perfect level 24 Tabbies (1.752 each, both love barista) and a perfect Tuxedo (1.2, loves waiter).
			-- Greedy makes a Tabby the Waiter for 1.752; the best plan makes the Tuxedo the Waiter for 1.8.
			local profile = profileAt(1)
			addCat(profile, "t1", "tabby", 100, 24)
			addCat(profile, "t2", "tabby", 100, 24)
			addCat(profile, "s", "tuxedo", 100)
			local plan = EquipBest.plan(profile)
			expect(plan.placements.s).to.equal("waiter_1")
			expect(plan.placements.t1 == "barista_1" or plan.placements.t2 == "barista_1").to.equal(
				true
			)
			expect(plan.baseRate).to.be.near(1.752 * 1.5 + 1.2 * 1.5, 1e-6)
			expect(plan.baseRate).to.be.near(bruteForce(profile), 1e-6)
		end)

		it("prefers the slot a cat already works when two choices are equal", function()
			-- Tier 3 has one entertainer slot. Both Bengals love it; one gets it, and the other keeps its own
			-- waiter slot rather than moving to an equal one.
			local profile = profileAt(3)
			addCat(profile, "p1", "bengal", 50, 1, "waiter_2")
			addCat(profile, "p2", "bengal", 50, 1, "waiter_1")
			addCat(profile, "x", "tabby", 50, 1, "barista_1")
			local plan = EquipBest.plan(profile)
			expect(plan.placements.x).to.equal("barista_1")
			local onStage = if plan.placements.p1 == "entertainer_1" then "p1" else "p2"
			local other = if onStage == "p1" then "p2" else "p1"
			expect(plan.placements[onStage]).to.equal("entertainer_1")
			expect(plan.placements[other]).to.equal(profile.cats[other].spotId)
		end)

		it("moves a resting better cat onto a spot and rests the worse one", function()
			local profile = profileAt(1)
			addCat(profile, "weak", "tabby", 0, 1, "barista_1")
			addCat(profile, "strong", "tabby", 100, 5)
			addCat(profile, "waiter", "tuxedo", 50, 1, "waiter_1")
			local plan = EquipBest.plan(profile)
			expect(plan.placements.strong).to.equal("barista_1")
			expect(plan.placements.weak).never.to.be.ok()
			expect(plan.placements.waiter).to.equal("waiter_1")
			expect(EquipBest.isOptimal(profile, plan)).to.equal(false)
			expect(EquipBest.apply(profile, plan)).to.equal(2)
			expect(profile.cats.weak.spotId).never.to.be.ok()
			expect(profile.cats.strong.spotId).to.equal("barista_1")
		end)

		it("ignores slots the tier has not opened and cats on them get moved", function()
			local profile = profileAt(1)
			addCat(profile, "a", "void", 50, 1, "barista_3") -- barista_3 opens at Tier 5; a damaged save
			addCat(profile, "b", "tabby", 50, 1, "counter_1") -- a v0.2 spot id
			local plan = EquipBest.plan(profile)
			expect(plan.spotsOpen).to.equal(2)
			expect(plan.placements.a).to.equal("waiter_1")
			expect(plan.placements.b).to.equal("barista_1")
			expect(EquipBest.isOptimal(profile, plan)).to.equal(false)
		end)

		it("ten slots at Tier 5: the hand-computed best of eleven cats (F25 done-when)", function()
			-- Slots: three barista, three waiter, two greeter, two entertainer. Every slot can take a cat that
			-- loves its role, so the best plan pays 1.5x everywhere and rests the weakest spare, Ginger:
			-- barista Wizard 112.5 + Bandit 12 + Tabby 1.5, waiter Ninja 37.5 + Pirate 4.5 + Tuxedo 1.5, greeter
			-- DJ 12 + Sleepy 18 (a Park Epic: 8 x 1.5 for its area since v0.13.7, x 1.5), entertainer Rocker 4.5 +
			-- Smoke 1.5 = 205.5.
			local profile = profileAt(5)
			for _, id in ipairs({
				"tabby",
				"tuxedo",
				"ginger",
				"smoke",
				"calico",
				"tortie",
				"sphynx",
				"maine_coon",
				"void",
				"midnight",
				"ragdoll",
			}) do
				addCat(profile, id, id)
			end
			local plan = EquipBest.plan(profile)
			expect(plan.spotsOpen).to.equal(10)
			expect(plan.catsPlaced).to.equal(10)
			expect(plan.baseRate).to.be.near(205.5, 1e-9)
			expect(plan.placements.ginger).never.to.be.ok()
			for uid, spotId in pairs(plan.placements) do
				local spot = Catalog.getSpot(spotId)
				local def = Catalog.getCat(profile.cats[uid].catId)
				assert(spot and def)
				expect(spot.spotType).to.equal(def.favoriteRole)
			end
		end)

		it("handles no cats and no open spots", function()
			local profile = profileAt(1)
			local empty = EquipBest.plan(profile)
			expect(empty.catsPlaced).to.equal(0)
			expect(empty.baseRate).to.equal(0)
			expect(EquipBest.apply(profile, empty)).to.equal(0)
		end)

		it("matches an exhaustive search on random cafes", function()
			local next = lcg(7)
			local catIds = {}
			for _, def in ipairs(Catalog.cats) do
				table.insert(catIds, def.id)
			end
			for trial = 1, 40 do
				local tier = math.floor(next() * 5) + 1
				local profile = profileAt(tier)
				-- at most 4 cats on ten slots and 5 on eight keeps the brute force quick
				local count = math.floor(next() * (if tier == 5 then 4 else 5)) + 1
				local spotsOpen = EquipBest.openSpots(profile)
				for i = 1, count do
					local catId = catIds[math.floor(next() * #catIds) + 1]
					local charm = math.floor(next() * 101)
					local level = math.floor(next() * Config.CatMaxLevel) + 1
					local spotId: string? = nil
					if next() < 0.5 then
						local spot = spotsOpen[math.floor(next() * #spotsOpen) + 1]
						if Economy.catOnSpot(profile, spot.id) == nil then
							spotId = spot.id
						end
					end
					addCat(profile, "c" .. i, catId, charm, level, spotId)
				end
				local plan = EquipBest.plan(profile)
				local expected = bruteForce(profile)
				expect(plan.baseRate).to.be.near(expected, 1e-6)
				-- the plan never double books a spot or uses a locked one
				local seen = {}
				for uid, spotId in pairs(plan.placements) do
					expect(profile.cats[uid]).to.be.ok()
					expect(Economy.spotIsOpen(profile, spotId)).to.equal(true)
					expect(seen[spotId]).never.to.be.ok()
					seen[spotId] = uid
				end
				EquipBest.apply(profile, plan)
				expect(EquipBest.isOptimal(profile, plan)).to.equal(true)
				if trial == 40 then
					expect(Economy.incomePerSecond(profile)).to.be.near(
						plan.baseRate
							* Economy.cafeMultiplier(profile)
							* Economy.tierMultiplier(profile),
						1e-6
					)
				end
			end
		end)
	end)
end
