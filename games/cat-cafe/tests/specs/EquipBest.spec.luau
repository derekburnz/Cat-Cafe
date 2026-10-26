--!strict
-- EquipBest.luau: the one-tap placement must be the best possible placement, never worse than greedy,
-- and must leave cats where they are when nothing improves.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatStats = require(Shared.CatStats)
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local EquipBest = require(Shared.EquipBest)
	local ProfileSchema = require(Shared.ProfileSchema)

	local function profileAt(cafeLevel: number, withStarter: boolean?)
		local profile = ProfileSchema.template(0)
		profile.upgradeLevels.cafe_level = cafeLevel
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
		local cats = {}
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
		it("is the rating, times 1.5 on the favorite spot type, 0 for an unknown cat", function()
			local tabby = CatStats.newInstance("t", "tabby", 0)
			expect(EquipBest.value(tabby, Catalog.getSpot("counter_1") :: any)).to.be.near(
				Config.FavoriteMultiplier
			)
			expect(EquipBest.value(tabby, Catalog.getSpot("window_1") :: any)).to.equal(1)
			local nope = CatStats.newInstance("n", "nope", 0)
			expect(EquipBest.value(nope, Catalog.getSpot("window_1") :: any)).to.equal(0)
		end)
	end)

	describe("plan", function()
		it(
			"a fresh cafe is already optimal: Tabby stays on the counter, nothing changes",
			function()
				local profile = profileAt(1, true)
				local plan = EquipBest.plan(profile)
				expect(plan.placements.starter_tabby).to.equal("counter_1")
				expect(plan.spotsOpen).to.equal(2)
				expect(plan.catsPlaced).to.equal(1)
				expect(plan.baseRate).to.be.near(1.5)
				expect(EquipBest.isOptimal(profile, plan)).to.equal(true)
				expect(EquipBest.apply(profile, plan)).to.equal(0)
			end
		)

		it("fills open spots with favorites first and rests the overflow", function()
			local profile = profileAt(1)
			addCat(profile, "a", "tabby") -- loves counter
			addCat(profile, "b", "snow") -- loves window
			addCat(profile, "c", "ginger") -- loves cushion (locked at cafe 1)
			local plan = EquipBest.plan(profile)
			expect(plan.placements.a).to.equal("counter_1")
			expect(plan.placements.b).to.equal("window_1")
			expect(plan.placements.c).never.to.be.ok()
			expect(plan.baseRate).to.be.near(3)
			expect(EquipBest.apply(profile, plan)).to.equal(2)
			expect(profile.cats.a.spotId).to.equal("counter_1")
			expect(profile.cats.b.spotId).to.equal("window_1")
			expect(profile.cats.c.spotId).never.to.be.ok()
			expect(EquipBest.isOptimal(profile, plan)).to.equal(true)
		end)

		it("beats greedy-by-rating: a weaker cat on its favorite spot can be worth more", function()
			-- Two perfect Tabbies (1.74 each, both love the counter) and a perfect Snow (1.2, loves the window).
			-- Greedy puts a Tabby on the window for 1.74; the best plan puts Snow there for 1.8.
			local profile = profileAt(1)
			addCat(profile, "t1", "tabby", 100, Config.CatMaxLevel)
			addCat(profile, "t2", "tabby", 100, Config.CatMaxLevel)
			addCat(profile, "s", "snow", 100)
			local plan = EquipBest.plan(profile)
			expect(plan.placements.s).to.equal("window_1")
			expect(plan.placements.t1 == "counter_1" or plan.placements.t2 == "counter_1").to.equal(
				true
			)
			expect(plan.baseRate).to.be.near(1.74 * 1.5 + 1.2 * 1.5, 1e-6)
			expect(plan.baseRate).to.be.near(bruteForce(profile), 1e-6)
		end)

		it("prefers the spot a cat already sits on when two choices are equal", function()
			local profile = profileAt(5)
			addCat(profile, "p1", "ragdoll", 50, 1, "patio_2")
			addCat(profile, "p2", "ragdoll", 50, 1, "patio_1")
			addCat(profile, "x", "tabby", 50, 1, "counter_1")
			local plan = EquipBest.plan(profile)
			expect(plan.placements.x).to.equal("counter_1")
			-- Both Ragdolls love the cat tree; one gets it, the other keeps its patio spot rather than swapping.
			local onTree = if plan.placements.p1 == "cattree_1" then "p1" else "p2"
			local other = if onTree == "p1" then "p2" else "p1"
			expect(plan.placements[onTree]).to.equal("cattree_1")
			expect(plan.placements[other]).to.equal(profile.cats[other].spotId)
		end)

		it("moves a resting better cat onto a spot and rests the worse one", function()
			local profile = profileAt(1)
			addCat(profile, "weak", "tabby", 0, 1, "counter_1")
			addCat(profile, "strong", "tabby", 100, 5)
			addCat(profile, "window", "tuxedo", 50, 1, "window_1")
			local plan = EquipBest.plan(profile)
			expect(plan.placements.strong).to.equal("counter_1")
			expect(plan.placements.weak).never.to.be.ok()
			expect(plan.placements.window).to.equal("window_1")
			expect(EquipBest.isOptimal(profile, plan)).to.equal(false)
			expect(EquipBest.apply(profile, plan)).to.equal(2)
			expect(profile.cats.weak.spotId).never.to.be.ok()
			expect(profile.cats.strong.spotId).to.equal("counter_1")
		end)

		it("ignores spots the cafe level has not opened and cats on them get moved", function()
			local profile = profileAt(1)
			addCat(profile, "a", "void", 50, 1, "shelf_1") -- shelf opens at cafe 3; a damaged or downgraded save
			local plan = EquipBest.plan(profile)
			expect(plan.spotsOpen).to.equal(2)
			expect(plan.placements.a == "counter_1" or plan.placements.a == "window_1").to.equal(
				true
			)
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
				local cafeLevel = math.floor(next() * 4) + 1 -- 1 to 4: at most 5 spots keeps brute force quick
				local profile = profileAt(cafeLevel)
				local count = math.floor(next() * 6) + 1
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
						plan.baseRate * Economy.cafeMultiplier(profile),
						1e-6
					)
				end
			end
		end)
	end)
end
