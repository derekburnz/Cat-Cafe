--!strict
-- Catching.luau against data-model v0.3.1 sections 2, 3, 8, 9 and 10b: odds, picking a cat, fleeing. The circles
-- that decide a catch have their own spec (Circles.spec).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local Config = require(Shared.Config)

	describe("succeeds", function()
		it("roll strictly below chance wins", function()
			expect(Catching.succeeds(0.5, 0.49)).to.equal(true)
			expect(Catching.succeeds(0.5, 0.5)).to.equal(false)
			expect(Catching.succeeds(0.95, 0.9499)).to.equal(true)
			expect(Catching.succeeds(0.95, 0.95)).to.equal(false)
			expect(Catching.succeeds(0.05, 0)).to.equal(true)
		end)

		it("a chance of 0 can never win, a chance of 1 always does for rolls in [0, 1)", function()
			expect(Catching.succeeds(0, 0)).to.equal(false)
			expect(Catching.succeeds(1, 0.999999)).to.equal(true)
		end)
	end)

	describe("the chase after a miss (sections 2 and 10, v0.5)", function()
		it("sprint studs: Common 12, Rare 16, Epic 20, Legendary 26, Mythical 32; the v0.4 paws are gone", function()
			expect(Catching.fleeStuds("Common")).to.equal(12)
			expect(Catching.fleeStuds("Rare")).to.equal(16)
			expect(Catching.fleeStuds("Epic")).to.equal(20)
			expect(Catching.fleeStuds("Legendary")).to.equal(26)
			expect(Catching.fleeStuds("Mythical")).to.equal(32)
			expect((Catching :: any).patience).never.to.be.ok()
			expect((Catching :: any).fleesOnFail).never.to.be.ok()
		end)

		it("a rarer cat always runs at least as far", function()
			local previous = 0
			for _, rarity in ipairs(Catalog.rarityOrder) do
				local studs = Catching.fleeStuds(rarity)
				expect(studs > 0).to.equal(true)
				expect(studs >= previous).to.equal(true)
				previous = studs
			end
		end)

		it("nobody may try again until the sprint at StrayFleeSpeed and the breather are over", function()
			local sprint = 26
			local expected = 100 + sprint / Config.StrayFleeSpeed + Config.StrayRestSeconds
			expect(Catching.fleeUntil(100, sprint)).to.be.near(expected, 1e-9)
		end)

		it("a sprint cut short by a wall still waits at least GrabRetrySeconds", function()
			expect(Catching.fleeUntil(100, 0)).to.be.near(100 + Config.GrabRetrySeconds, 1e-9)
			expect(Catching.fleeUntil(100, -5)).to.be.near(100 + Config.GrabRetrySeconds, 1e-9)
		end)

		it("a Mythical's chase is longer than a Common's", function()
			local common = Catching.fleeUntil(0, Catching.fleeStuds("Common"))
			local mythical = Catching.fleeUntil(0, Catching.fleeStuds("Mythical"))
			expect(mythical > common).to.equal(true)
		end)

		it("v0.3: the hold ring and flat chance are gone (F26)", function()
			local catching = Catching :: any
			expect(catching.ringBonus).never.to.be.ok()
			expect(catching.ringResultFromHold).never.to.be.ok()
			expect(catching.chance).never.to.be.ok()
		end)
	end)

	describe("pickRarity against odds tables (sections 8 and 9)", function()
		local alley = { Common = 72, Rare = 22, Epic = 5, Legendary = 0.9, Mythical = 0.1 }

		it("maps roll boundaries onto the cumulative odds", function()
			expect(Catching.pickRarity(alley, 0)).to.equal("Common")
			expect(Catching.pickRarity(alley, 0.7199)).to.equal("Common")
			expect(Catching.pickRarity(alley, 0.7201)).to.equal("Rare")
			expect(Catching.pickRarity(alley, 0.9399)).to.equal("Rare")
			expect(Catching.pickRarity(alley, 0.9401)).to.equal("Epic")
			expect(Catching.pickRarity(alley, 0.9899)).to.equal("Epic")
			expect(Catching.pickRarity(alley, 0.9901)).to.equal("Legendary")
			expect(Catching.pickRarity(alley, 0.9989)).to.equal("Legendary")
			expect(Catching.pickRarity(alley, 0.9991)).to.equal("Mythical")
			expect(Catching.pickRarity(alley, 0.999999)).to.equal("Mythical")
		end)

		it("clamps out of range rolls instead of erroring", function()
			expect(Catching.pickRarity(alley, -1)).to.equal("Common")
			expect(Catching.pickRarity(alley, 1)).to.equal("Mythical")
			expect(Catching.pickRarity(alley, 7)).to.equal("Mythical")
		end)

		it("a zero weight is never picked (Moon Milk and Star Treat have no Commons)", function()
			local starTreat = Catalog.getLure("star_treat")
			assert(starTreat)
			for i = 0, 999 do
				local rarity = Catching.pickRarity(starTreat.odds, i / 1000)
				expect(rarity ~= "Common" and rarity ~= "Rare").to.equal(true)
			end
		end)

		local function distribution(odds: any)
			local counts: { [string]: number } =
				{ Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythical = 0 }
			local n = 20000
			for i = 0, n - 1 do
				local rarity = Catching.pickRarity(odds, i / n)
				counts[rarity] += 1
			end
			return counts, n
		end

		local function oddsOf(def: any)
			assert(def ~= nil, "catalog entry missing")
			return def.odds
		end
		local sources: { { any } } = {
			{ "alley", oddsOf(Catalog.getArea("alley")) },
			{ "park", oddsOf(Catalog.getArea("park")) },
			{ "kibble", oddsOf(Catalog.getLure("kibble")) },
			{ "tuna", oddsOf(Catalog.getLure("tuna")) },
			{ "salmon", oddsOf(Catalog.getLure("salmon")) },
			{ "sardines", oddsOf(Catalog.getLure("sardines")) },
			{ "caviar", oddsOf(Catalog.getLure("caviar")) },
			{ "moon_milk", oddsOf(Catalog.getLure("moon_milk")) },
			{ "star_treat", oddsOf(Catalog.getLure("star_treat")) },
		}
		for _, source in ipairs(sources) do
			it(
				source[1] .. " produces the advertised percentages over an even sweep of rolls",
				function()
					local counts, n = distribution(source[2])
					for _, rarity in ipairs(Catalog.rarityOrder) do
						expect(counts[rarity] / n * 100).to.be.near(source[2][rarity], 0.05)
					end
				end
			)
		end
	end)

	describe(
		"pickRarity scales by the odds total (v0.2, so a rescue table need not sum to 100)",
		function()
			-- The alley with the Rare weight doubled but not renormalised: 75 / 40 / 4.5 / 0.5, total 120.
			local heavy: { [string]: number } =
				{ Common = 75, Rare = 40, Epic = 4.5, Legendary = 0.5 }

			it("cuts the roll at the cumulative share of the total", function()
				expect(Catching.pickRarity(heavy :: any, 0)).to.equal("Common")
				expect(Catching.pickRarity(heavy :: any, 0.6249)).to.equal("Common") -- 75 / 120 = 0.625
				expect(Catching.pickRarity(heavy :: any, 0.6251)).to.equal("Rare")
				expect(Catching.pickRarity(heavy :: any, 0.9583)).to.equal("Rare") -- 115 / 120 = 0.95833
				expect(Catching.pickRarity(heavy :: any, 0.9584)).to.equal("Epic")
				expect(Catching.pickRarity(heavy :: any, 0.9958)).to.equal("Epic") -- 119.5 / 120 = 0.99583
				expect(Catching.pickRarity(heavy :: any, 0.9959)).to.equal("Legendary")
				expect(Catching.pickRarity(heavy :: any, 1)).to.equal("Legendary")
			end)

			it("a sweep matches each weight over the total", function()
				local counts: { [string]: number } =
					{ Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythical = 0 }
				local n = 24000
				for i = 0, n - 1 do
					local rarity = Catching.pickRarity(heavy :: any, i / n)
					counts[rarity] += 1
				end
				for rarity, weight in pairs(heavy) do
					local count: number = counts[rarity]
					expect(count / n).to.be.near(weight / 120, 0.0005)
				end
			end)
		end
	)

	describe("rescueOdds (section 10b): every non-Common weight doubled, renormalised to 100", function()
		local function total(odds: any): number
			local sum = 0
			for _, rarity in ipairs(Catalog.rarityOrder) do
				sum += odds[rarity]
			end
			return sum
		end

		it("Alleyway 72 / 22 / 5 / 0.9 / 0.1 becomes 56.25 / 34.375 / 7.8125 / 1.40625 / 0.15625", function()
			local alley = Catalog.getArea("alley")
			assert(alley)
			local rescue: any = Catching.rescueOdds(alley.odds)
			expect(rescue.Common).to.be.near(56.25, 1e-9)
			expect(rescue.Rare).to.be.near(34.375, 1e-9)
			expect(rescue.Epic).to.be.near(7.8125, 1e-9)
			expect(rescue.Legendary).to.be.near(1.40625, 1e-9)
			expect(rescue.Mythical).to.be.near(0.15625, 1e-9)
		end)

		it("Park 60 / 28 / 9 / 2.5 / 0.5 becomes 60 / 56 / 18 / 5 / 1 over 140 (42.9 / 40.0 / 12.9 / 3.6 / 0.7)", function()
			local park = Catalog.getArea("park")
			assert(park)
			local rescue: any = Catching.rescueOdds(park.odds)
			expect(rescue.Common).to.be.near(60 / 140 * 100, 1e-9)
			expect(rescue.Rare).to.be.near(40, 1e-9)
			expect(rescue.Epic).to.be.near(18 / 140 * 100, 1e-9)
			expect(rescue.Legendary).to.be.near(5 / 140 * 100, 1e-9)
			expect(rescue.Mythical).to.be.near(1 / 140 * 100, 1e-9)
		end)

		it("always sums to 100, doubles every rarer weight against Common and leaves the input alone", function()
			for _, area in ipairs(Catalog.areas) do
				local before = table.clone(area.odds :: any)
				local rescue: any = Catching.rescueOdds(area.odds)
				expect(total(rescue)).to.be.near(100, 1e-9)
				for _, rarity in ipairs(Catalog.rarityOrder) do
					if rarity ~= "Common" then
						expect(rescue[rarity] / rescue.Common).to.be.near(
							2 * (area.odds :: any)[rarity] / area.odds.Common,
							1e-9
						)
					end
				end
				expect(area.odds :: any).to.deepEqual(before)
			end
		end)

		it("all Common or all zero odds stay all Common", function()
			local allCommon: any = Catching.rescueOdds({ Common = 100, Rare = 0, Epic = 0, Legendary = 0, Mythical = 0 })
			expect(allCommon.Common).to.be.near(100, 1e-9)
			expect(allCommon.Mythical).to.equal(0)
			local empty: any = Catching.rescueOdds({ Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythical = 0 })
			expect(empty).to.deepEqual({ Common = 100, Rare = 0, Epic = 0, Legendary = 0, Mythical = 0 })
		end)

		it("a rescue roll over the Alleyway gives a Rare 34.375% of the time", function()
			local alley = Catalog.getArea("alley")
			assert(alley)
			local rescue = Catching.rescueOdds(alley.odds)
			local rares, n = 0, 12800
			for i = 0, n - 1 do
				if Catching.pickRarity(rescue, i / n) == "Rare" then
					rares += 1
				end
			end
			expect(rares / n).to.be.near(0.34375, 0.001)
		end)
	end)

	describe("candidates and pickCat (section 3 areas)", function()
		local function idList(list: { any })
			local out = {}
			for _, def in ipairs(list) do
				table.insert(out, def.id)
			end
			return out
		end

		it("each area offers only its own cats", function()
			expect(idList(Catching.candidates("Common", "alley"))).to.deepEqual({ "tabby", "tuxedo", "ginger", "smoke" })
			expect(idList(Catching.candidates("Rare", "alley"))).to.deepEqual({ "calico", "tortie" })
			expect(idList(Catching.candidates("Epic", "alley"))).to.deepEqual({ "sphynx", "maine_coon" })
			expect(idList(Catching.candidates("Legendary", "alley"))).to.deepEqual({ "void" })
			expect(idList(Catching.candidates("Mythical", "alley"))).to.deepEqual({ "midnight" })
			expect(idList(Catching.candidates("Common", "park"))).to.deepEqual({ "snow", "cream", "brownie", "blue" })
			expect(idList(Catching.candidates("Rare", "park"))).to.deepEqual({ "siamese", "bengal" })
			expect(idList(Catching.candidates("Epic", "park"))).to.deepEqual({ "ragdoll", "persian" })
			expect(idList(Catching.candidates("Legendary", "park"))).to.deepEqual({ "blossom" })
			expect(idList(Catching.candidates("Mythical", "park"))).to.deepEqual({ "aurora" })
		end)

		it("v0.3: no cat lives in two areas, so the old \"both\" area is empty", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				expect(#Catching.candidates(rarity, "both")).to.equal(0)
			end
		end)

		it("pickCat is uniform over the candidates", function()
			local commons = Catching.candidates("Common", "alley")
			expect(Catching.pickCat("Common", "alley", 0).id).to.equal(commons[1].id)
			expect(Catching.pickCat("Common", "alley", 0.2499).id).to.equal(commons[1].id)
			expect(Catching.pickCat("Common", "alley", 0.25).id).to.equal(commons[2].id)
			expect(Catching.pickCat("Common", "alley", 0.5).id).to.equal(commons[3].id)
			expect(Catching.pickCat("Common", "alley", 0.999).id).to.equal(commons[4].id)
			expect(Catching.pickCat("Rare", "park", 0.4999).id).to.equal("siamese")
			expect(Catching.pickCat("Rare", "park", 0.5).id).to.equal("bengal")
			expect(Catching.pickCat("Mythical", "park", 0.7).id).to.equal("aurora")
		end)

		it("pickCat falls back to the first catalog cat in an area with no cats", function()
			expect(Catching.pickCat("Mythical", "nowhere", 0.5).id).to.equal(Catalog.cats[1].id)
			expect(Catching.pickCat("Common", "both", 0.5).id).to.equal(Catalog.cats[1].id)
		end)

		it("pickCat never returns nil for any rarity, area and roll", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				for _, area in ipairs({ "alley", "park", "neighbourhood", "woods", "sewer", "nowhere" }) do
					for _, roll in ipairs({ 0, 0.5, 0.999999, 1 }) do
						local def = Catching.pickCat(rarity, area, roll)
						expect(def).to.be.ok()
						if area ~= "nowhere" then
							expect(def.area).to.equal(area)
							expect(def.rarity).to.equal(rarity)
						end
					end
				end
			end
		end)

		-- F28: bait picks among that rarity's cats in every area the player has unlocked (section 8).
		it("the bait pick spreads a rarity over every unlocked area (F28)", function()
			-- 240 evenly spaced rolls: every pool size here (1 to 5, 2 to 10, 4 to 20 cats) divides 240, so a
			-- uniform pick lands on each cat of the pool exactly 240 / pool times.
			local ROLLS = 240
			for tier = 1, 5 do
				for _, rarity in Catalog.rarityOrder do
					local pool: { [string]: boolean } = {}
					local size = 0
					for _, def in Catalog.cats do
						local area = Catalog.getArea(def.area)
						if def.rarity == rarity and area ~= nil and area.tier <= tier then
							pool[def.id] = true
							size += 1
						end
					end
					expect(size > 0).to.equal(true)
					local hits: { [string]: number } = {}
					for i = 0, ROLLS - 1 do
						local def = Catching.pickBaitCat(rarity, tier, (i + 0.5) / ROLLS)
						if not pool[def.id] then
							error(string.format("tier %d %s picked %s from outside the pool", tier, rarity, def.id))
						end
						hits[def.id] = (hits[def.id] or 0) + 1
					end
					for id in pool do
						if hits[id] ~= ROLLS / size then
							error(string.format("tier %d %s: %s picked %s of %d times", tier, rarity, id, tostring(hits[id]), ROLLS / size))
						end
					end
				end
			end
		end)

		it("the bait pick stays in the pool at the roll edges and never returns nil (QA)", function()
			for tier = 0, 6 do
				for _, rarity in Catalog.rarityOrder do
					for _, roll in { 0, 0.999999, 1 } do
						local def = Catching.pickBaitCat(rarity, tier, roll)
						expect(def).to.be.ok()
						local area = Catalog.getArea(def.area)
						if tier >= 1 then
							expect(def.rarity).to.equal(rarity)
							expect(area ~= nil and area.tier <= tier).to.equal(true)
						end
					end
				end
			end
		end)
	end)

	describe("rarityAtLeast and percentText", function()
		it("Epic and rarer trigger announcements, Rare does not", function()
			expect(Catching.rarityAtLeast("Epic", Config.AnnounceMinRarity)).to.equal(true)
			expect(Catching.rarityAtLeast("Legendary", Config.AnnounceMinRarity)).to.equal(true)
			expect(Catching.rarityAtLeast("Mythical", Config.AnnounceMinRarity)).to.equal(true)
			expect(Catching.rarityAtLeast("Rare", Config.AnnounceMinRarity)).to.equal(false)
			expect(Catching.rarityAtLeast("Common", "Bogus")).to.equal(false)
		end)

		it("percentText rounds to a whole percent", function()
			expect(Catching.percentText(0.45)).to.equal("45%")
			expect(Catching.percentText(0.949)).to.equal("95%")
			expect(Catching.percentText(0.004)).to.equal("0%")
			expect(Catching.percentText(0.005)).to.equal("1%")
			expect(Catching.percentText(1)).to.equal("100%")
		end)
	end)

	describe("shoutOut (F30): who hears about a catch", function()
		local function cat(rarity: string, name: string): any
			return { id = "test", name = name, rarity = rarity }
		end

		it("announces Epic and rarer, with the right article", function()
			expect(Catching.shoutOut("Dee", "caught", cat("Epic", "Moonpaw"), "base")).to.equal(
				"Dee caught an Epic Moonpaw!"
			)
			expect(Catching.shoutOut("Dee", "rescued", cat("Legendary", "Sunny"), nil)).to.equal(
				"Dee rescued a Legendary Sunny!"
			)
		end)

		it("stays quiet for a plain Common or Rare", function()
			expect(Catching.shoutOut("Dee", "caught", cat("Rare", "Pip"), "base")).to.equal(nil)
			expect(Catching.shoutOut("Dee", "caught", cat("Common", "Tabby"), nil)).to.equal(nil)
		end)

		it("always announces a gold cat, whatever its rarity", function()
			expect(Catching.shoutOut("Dee", "caught", cat("Common", "Tabby"), "gold")).to.equal(
				"Dee caught a gold Common Tabby!"
			)
		end)

		it("adds where it happened", function()
			local text = Catching.shoutOut("Dee", "tamed", cat("Epic", "Moonpaw"), "base", " at their bait bowl")
			expect(text).to.equal("Dee tamed an Epic Moonpaw at their bait bowl!")
		end)
	end)
	describe("spreadPick: a wave is scattered, not clumped (Derek 2026-10-27 22:38)", function()
		local function v(x: number, z: number): Vector3
			return Vector3.new(x, 0.1, z)
		end
		local spacing = Config.StraySpawnSpacingStuds

		it("spawns at least StraySpawnSpacingStuds (12) from every stray in the area when it can", function()
			expect(spacing).to.equal(12)
			local points = { v(0, 0), v(5, 0), v(30, 0) }
			local taken = { v(2, 0) }
			for roll = 0, 0.99, 0.05 do
				expect(Catching.spreadPick(points, taken, roll)).to.equal(3)
			end
		end)

		it("prefers far points: weight grows with the gap to the nearest stray", function()
			local points = { v(12, 0), v(48, 0) }
			local taken = { v(0, 0) }
			-- weights 12 and 48: the near point takes the first fifth of the rolls
			expect(Catching.spreadPick(points, taken, 0)).to.equal(1)
			expect(Catching.spreadPick(points, taken, 0.19)).to.equal(1)
			expect(Catching.spreadPick(points, taken, 0.21)).to.equal(2)
			expect(Catching.spreadPick(points, taken, 0.999)).to.equal(2)
		end)

		it("picks evenly in an empty area", function()
			local points = { v(0, 0), v(1, 0), v(2, 0), v(3, 0) }
			expect(Catching.spreadPick(points, {}, 0)).to.equal(1)
			expect(Catching.spreadPick(points, {}, 0.3)).to.equal(2)
			expect(Catching.spreadPick(points, {}, 0.6)).to.equal(3)
			expect(Catching.spreadPick(points, {}, 0.9)).to.equal(4)
			expect(Catching.spreadPick(points, {}, 1)).to.equal(4)
		end)

		it("when every free point is closer than the spacing, takes the one farthest from all strays", function()
			local points = { v(3, 0), v(8, 0), v(5, 0) }
			local taken = { v(0, 0), v(16, 0) }
			expect(Catching.spreadPick(points, taken, 0.5)).to.equal(2)
		end)

		it("measures flat distance, so a stray on a step still counts", function()
			local points = { Vector3.new(0, 20, 0), v(40, 0) }
			expect(Catching.spreadPick(points, { v(0, 0) }, 0)).to.equal(2)
		end)

		it("has nothing to pick with no free points", function()
			expect(Catching.spreadPick({}, { v(0, 0) }, 0.5)).never.to.be.ok()
		end)

		it("a ten-cat wave over the Park's points never puts two cats under 12 studs while a far point is free", function()
			local Layout = require(game:GetService("ServerScriptService").Server.World.Layout)
			local free: { Vector3 } = {}
			for _, point in Layout.park.spawnPoints do
				table.insert(free, v(point.x, point.z))
			end
			local rng = Random.new(7)
			local taken: { Vector3 } = {}
			for _ = 1, 10 do
				local index = Catching.spreadPick(free, taken, rng:NextNumber()) :: number
				local at = table.remove(free, index) :: Vector3
				local nearest = math.huge
				for _, other in taken do
					nearest = math.min(nearest, (at - other).Magnitude)
				end
				local couldSpread = false
				for _, point in free do
					local gap = math.huge
					for _, other in taken do
						gap = math.min(gap, (point - other).Magnitude)
					end
					couldSpread = couldSpread or gap >= spacing
				end
				expect(nearest >= spacing or not couldSpread).to.equal(true)
				table.insert(taken, at)
			end
		end)
	end)

	describe("spreadPick edges (QA)", function()
		local function v(x: number, z: number): Vector3
			return Vector3.new(x, 0, z)
		end
		local function gapOf(point: Vector3, taken: { Vector3 }): number
			local gap = math.huge
			for _, other in taken do
				gap = math.min(gap, Vector3.new(point.X - other.X, 0, point.Z - other.Z).Magnitude)
			end
			return gap
		end

		it("500 seeded areas: a far enough point whenever one is free, else the farthest", function()
			local rng = Random.new(368)
			local spacing = Config.StraySpawnSpacingStuds
			for _ = 1, 500 do
				local points: { Vector3 } = {}
				for _ = 1, rng:NextInteger(1, 12) do
					table.insert(points, Vector3.new(rng:NextNumber(-40, 40), rng:NextNumber(0, 8), rng:NextNumber(-40, 40)))
				end
				local taken: { Vector3 } = {}
				for _ = 1, rng:NextInteger(0, 8) do
					table.insert(taken, Vector3.new(rng:NextNumber(-40, 40), rng:NextNumber(0, 8), rng:NextNumber(-40, 40)))
				end
				local best, anyFar = -1, false
				for _, point in points do
					local gap = gapOf(point, taken)
					best = math.max(best, gap)
					anyFar = anyFar or gap >= spacing
				end
				for _, roll in { 0, rng:NextNumber(), 0.999999, 1 } do
					local index = Catching.spreadPick(points, taken, roll)
					expect(index ~= nil and points[index :: number] ~= nil).to.equal(true)
					local gap = gapOf(points[index :: number], taken)
					if anyFar then
						expect(gap >= spacing).to.equal(true)
					else
						expect(gap).to.equal(best)
					end
				end
			end
		end)

		it("a sweep of 12,000 rolls lands on each point in proportion to its gap, capped at 60 studs", function()
			-- gaps 12 (exactly the spacing counts), 11.99 (too near), 30, 60 and 90 (capped to 60)
			local points = { v(12, 0), v(-11.99, 0), v(0, 30), v(0, -60), v(90, 90) }
			local taken = { v(0, 0) }
			local weights = { 12, 0, 30, 60, 60 }
			local total = 162
			local counts = { 0, 0, 0, 0, 0 }
			local sweeps = 12000
			for i = 0, sweeps - 1 do
				local index = Catching.spreadPick(points, taken, (i + 0.5) / sweeps) :: number
				counts[index] += 1
			end
			for index, weight in weights do
				expect(math.abs(counts[index] - sweeps * weight / total) <= 2).to.equal(true)
			end
		end)
	end)
end
