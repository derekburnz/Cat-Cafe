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
		it(
			"sprint studs (v0.8 F57, doubled): Common 24, Rare 32, Epic 40, Legendary 52, Mythical 64; no v0.4 paws",
			function()
				expect(Catching.fleeStuds("Common")).to.equal(24)
				expect(Catching.fleeStuds("Rare")).to.equal(32)
				expect(Catching.fleeStuds("Epic")).to.equal(40)
				expect(Catching.fleeStuds("Legendary")).to.equal(52)
				expect(Catching.fleeStuds("Mythical")).to.equal(64)
				expect((Catching :: any).patience).never.to.be.ok()
				expect((Catching :: any).fleesOnFail).never.to.be.ok()
			end
		)

		it(
			"F57: the player who missed waits 3, 6, then 10 s by misses in a row on the stray",
			function()
				expect(Catching.selfRetrySeconds(1)).to.equal(3)
				expect(Catching.selfRetrySeconds(2)).to.equal(6)
				expect(Catching.selfRetrySeconds(3)).to.equal(10)
				expect(Catching.selfRetrySeconds(7)).to.equal(10)
				expect(Catching.selfRetrySeconds(0)).to.equal(3)
			end
		)

		it("F57: misses in a row count up, and start again 60 s after the last", function()
			local first = Catching.nextMiss(nil, 100)
			expect(first.count).to.equal(1)
			local second = Catching.nextMiss(first, 110)
			expect(second.count).to.equal(2)
			expect(second.at).to.equal(110)
			local third = Catching.nextMiss(second, 169.9)
			expect(third.count).to.equal(3)
			local fresh = Catching.nextMiss(third, 169.9 + Config.StrayMissStreakResetSeconds)
			expect(fresh.count).to.equal(1)
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

		it(
			"nobody may try again until the sprint at StrayFleeSpeed and the breather are over",
			function()
				local sprint = 26
				local expected = 100 + sprint / Config.StrayFleeSpeed + Config.StrayRestSeconds
				expect(Catching.fleeUntil(100, sprint)).to.be.near(expected, 1e-9)
			end
		)

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

	describe(
		"rescueOdds (section 10b): Rare and Epic doubled, Legendary and Mythical x2.4 (#2240), renormalised to 100",
		function()
			local function total(odds: any): number
				local sum = 0
				for _, rarity in ipairs(Catalog.rarityOrder) do
					sum += odds[rarity]
				end
				return sum
			end

			it(
				"Alleyway 54 / 29 / 11 / 4.8 / 1.2 (#1452) becomes 54 / 58 / 22 / 11.52 / 2.88 over 148.4",
				function()
					local alley = Catalog.getArea("alley")
					assert(alley)
					local rescue: any = Catching.rescueOdds(alley.odds)
					expect(rescue.Common).to.be.near(54 / 148.4 * 100, 1e-9)
					expect(rescue.Rare).to.be.near(58 / 148.4 * 100, 1e-9)
					expect(rescue.Epic).to.be.near(22 / 148.4 * 100, 1e-9)
					expect(rescue.Legendary).to.be.near(11.52 / 148.4 * 100, 1e-9)
					expect(rescue.Mythical).to.be.near(2.88 / 148.4 * 100, 1e-9)
					-- #2240's table: Legendary 6.6% to 7.8% and Mythical 1.64% to 1.94%
					expect(rescue.Legendary).to.be.near(7.76, 0.01)
					expect(rescue.Mythical).to.be.near(1.94, 0.01)
				end
			)

			it(
				"the old Alleyway 72 / 22 / 5 / 0.9 / 0.1 becomes 72 / 44 / 10 / 2.16 / 0.24 over 128.4",
				function()
					local rescue: any = Catching.rescueOdds({
						Common = 72,
						Rare = 22,
						Epic = 5,
						Legendary = 0.9,
						Mythical = 0.1,
					})
					expect(rescue.Common).to.be.near(72 / 128.4 * 100, 1e-9)
					expect(rescue.Rare).to.be.near(44 / 128.4 * 100, 1e-9)
					expect(rescue.Epic).to.be.near(10 / 128.4 * 100, 1e-9)
					expect(rescue.Legendary).to.be.near(2.16 / 128.4 * 100, 1e-9)
					expect(rescue.Mythical).to.be.near(0.24 / 128.4 * 100, 1e-9)
				end
			)

			it(
				"the old Park 60 / 28 / 9 / 2.5 / 0.5 becomes 60 / 56 / 18 / 6 / 1.2 over 141.2",
				function()
					local rescue: any = Catching.rescueOdds({
						Common = 60,
						Rare = 28,
						Epic = 9,
						Legendary = 2.5,
						Mythical = 0.5,
					})
					expect(rescue.Common).to.be.near(60 / 141.2 * 100, 1e-9)
					expect(rescue.Rare).to.be.near(56 / 141.2 * 100, 1e-9)
					expect(rescue.Epic).to.be.near(18 / 141.2 * 100, 1e-9)
					expect(rescue.Legendary).to.be.near(6 / 141.2 * 100, 1e-9)
					expect(rescue.Mythical).to.be.near(1.2 / 141.2 * 100, 1e-9)
				end
			)

			it(
				"always sums to 100, boosts every rarer weight against Common and leaves the input alone",
				function()
					for _, area in ipairs(Catalog.areas) do
						local before = table.clone(area.odds :: any)
						local rescue: any = Catching.rescueOdds(area.odds)
						expect(total(rescue)).to.be.near(100, 1e-9)
						for _, rarity in ipairs(Catalog.rarityOrder) do
							if rarity ~= "Common" then
								local boost = if rarity == "Legendary"
										or rarity == "Mythical"
									then Catching.RESCUE_TOP_BOOST
									else Catching.RESCUE_BOOST
								expect(rescue[rarity] / rescue.Common).to.be.near(
									boost * (area.odds :: any)[rarity] / area.odds.Common,
									1e-9
								)
							end
						end
						expect(area.odds :: any).to.deepEqual(before)
					end
				end
			)

			it("all Common or all zero odds stay all Common", function()
				local allCommon: any = Catching.rescueOdds({
					Common = 100,
					Rare = 0,
					Epic = 0,
					Legendary = 0,
					Mythical = 0,
				})
				expect(allCommon.Common).to.be.near(100, 1e-9)
				expect(allCommon.Mythical).to.equal(0)
				local empty: any = Catching.rescueOdds({
					Common = 0,
					Rare = 0,
					Epic = 0,
					Legendary = 0,
					Mythical = 0,
				})
				expect(empty).to.deepEqual({
					Common = 100,
					Rare = 0,
					Epic = 0,
					Legendary = 0,
					Mythical = 0,
				})
			end)

			it("a rescue roll over the Alleyway gives a Rare 58 / 148.4 of the time", function()
				local alley = Catalog.getArea("alley")
				assert(alley)
				local rescue = Catching.rescueOdds(alley.odds)
				local rares, n = 0, 12800
				for i = 0, n - 1 do
					if Catching.pickRarity(rescue, i / n) == "Rare" then
						rares += 1
					end
				end
				expect(rares / n).to.be.near(58 / 148.4, 0.001)
			end)
		end
	)

	describe("candidates and pickCat (section 3 areas)", function()
		local function idList(list: { any })
			local out = {}
			for _, def in ipairs(list) do
				table.insert(out, def.id)
			end
			return out
		end

		it("each area offers only its own cats", function()
			expect(idList(Catching.candidates("Common", "alley"))).to.deepEqual({
				"tabby",
				"tuxedo",
				"ginger",
				"smoke",
			})
			expect(idList(Catching.candidates("Rare", "alley"))).to.deepEqual({ "binbag", "tortie" })
			expect(idList(Catching.candidates("Epic", "alley"))).to.deepEqual({
				"taxi",
				"maine_coon",
			})
			expect(idList(Catching.candidates("Legendary", "alley"))).to.deepEqual({ "void" })
			expect(idList(Catching.candidates("Mythical", "alley"))).to.deepEqual({ "neon" })
			expect(idList(Catching.candidates("Common", "park"))).to.deepEqual({
				"snow",
				"cream",
				"brownie",
				"blue",
			})
			expect(idList(Catching.candidates("Rare", "park"))).to.deepEqual({
				"birdwatch",
				"bengal",
			})
			expect(idList(Catching.candidates("Epic", "park"))).to.deepEqual({
				"ragdoll",
				"duckling",
			})
			expect(idList(Catching.candidates("Legendary", "park"))).to.deepEqual({ "blossom" })
			expect(idList(Catching.candidates("Mythical", "park"))).to.deepEqual({ "balloon" })
		end)

		it(
			"F78: a spare cat never spawns, from an area wave or a rescue (data-model 3d)",
			function()
				for _, rarity in ipairs(Catalog.rarityOrder) do
					for _, area in ipairs({ "alley", "park", "neighbourhood", "woods", "sewer" }) do
						for _, def in Catching.candidates(rarity, area) do
							expect(def.area).to.equal(area)
						end
					end
				end
			end
		)

		it("F78: bait never picks a spare cat, at any tier and roll", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				for tier = 1, 5 do
					for roll = 0, 0.99, 0.05 do
						expect(Catching.pickBaitCat(rarity, tier, roll).area ~= "spare").to.equal(
							true
						)
					end
				end
			end
		end)

		it('v0.3: no cat lives in two areas, so the old "both" area is empty', function()
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
			expect(Catching.pickCat("Rare", "park", 0.4999).id).to.equal("birdwatch")
			expect(Catching.pickCat("Rare", "park", 0.5).id).to.equal("bengal")
			expect(Catching.pickCat("Mythical", "park", 0.7).id).to.equal("balloon")
		end)

		it("pickCat falls back to the first catalog cat in an area with no cats", function()
			expect(Catching.pickCat("Mythical", "nowhere", 0.5).id).to.equal(Catalog.cats[1].id)
			expect(Catching.pickCat("Common", "both", 0.5).id).to.equal(Catalog.cats[1].id)
		end)

		it("pickCat never returns nil for any rarity, area and roll", function()
			for _, rarity in ipairs(Catalog.rarityOrder) do
				for _, area in ipairs({
					"alley",
					"park",
					"neighbourhood",
					"woods",
					"sewer",
					"nowhere",
				}) do
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
							error(
								string.format(
									"tier %d %s picked %s from outside the pool",
									tier,
									rarity,
									def.id
								)
							)
						end
						hits[def.id] = (hits[def.id] or 0) + 1
					end
					for id in pool do
						if hits[id] ~= ROLLS / size then
							error(
								string.format(
									"tier %d %s: %s picked %s of %d times",
									tier,
									rarity,
									id,
									tostring(hits[id]),
									ROLLS / size
								)
							)
						end
					end
				end
			end
		end)

		it(
			"the bait pick stays in the pool at the roll edges and never returns nil (QA)",
			function()
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
			end
		)
	end)

	describe("rarityAtLeast and percentText", function()
		it(
			"Mythical and rarer trigger announcements, Legendary and below do not (Derek 2026-11-12)",
			function()
				expect(Catching.rarityAtLeast("Epic", Config.AnnounceMinRarity)).to.equal(false)
				expect(Catching.rarityAtLeast("Legendary", Config.AnnounceMinRarity)).to.equal(
					false
				)
				expect(Catching.rarityAtLeast("Secret", Config.AnnounceMinRarity)).to.equal(true)
				expect(Catching.rarityAtLeast("Mythical", Config.AnnounceMinRarity)).to.equal(true)
				expect(Catching.rarityAtLeast("Rare", Config.AnnounceMinRarity)).to.equal(false)
				expect(Catching.rarityAtLeast("Common", "Bogus")).to.equal(false)
			end
		)

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

		it("announces a plain Mythical and rarer, with the right article", function()
			expect(Catching.shoutOut("Dee", "caught", cat("Mythical", "Moonpaw"), "base")).to.equal(
				"Dee caught a Mythical Moonpaw!"
			)
			expect(Catching.shoutOut("Dee", "rescued", cat("Mythical", "Sunny"), nil)).to.equal(
				"Dee rescued a Mythical Sunny!"
			)
		end)

		it("stays quiet for a plain Common, Rare, Epic or Legendary (Derek 2026-11-12)", function()
			expect(Catching.shoutOut("Dee", "rescued", cat("Legendary", "Sunny"), nil)).to.equal(
				nil
			)
			expect(Catching.shoutOut("Dee", "caught", cat("Legendary", "Sunny"), "base")).to.equal(
				nil
			)
			expect(Catching.shoutOut("Dee", "caught", cat("Epic", "Moonpaw"), "base")).to.equal(nil)
			expect(
				Catching.shoutOut(
					"Dee",
					"tamed",
					cat("Epic", "Moonpaw"),
					nil,
					" at their bait bowl"
				)
			).to.equal(nil)
			expect(Catching.shoutOut("Dee", "caught", cat("Rare", "Pip"), "base")).to.equal(nil)
			expect(Catching.shoutOut("Dee", "caught", cat("Common", "Tabby"), nil)).to.equal(nil)
		end)

		it("announces a gold or rainbow cat from Legendary up only (Derek 2026-11-12)", function()
			expect(Catching.COAT_SHOUT_FROM).to.equal("Legendary")
			expect(Catching.shoutOut("Dee", "caught", cat("Common", "Tabby"), "gold")).to.equal(nil)
			expect(Catching.shoutOut("Dee", "caught", cat("Rare", "Pip"), "gold")).to.equal(nil)
			expect(Catching.shoutOut("Dee", "caught", cat("Common", "Tabby"), "rainbow")).to.equal(
				nil
			)
			expect(Catching.shoutOut("Dee", "caught", cat("Epic", "Moonpaw"), "gold")).to.equal(nil)
			expect(Catching.shoutOut("Dee", "caught", cat("Epic", "Moonpaw"), "rainbow")).to.equal(
				nil
			)
			expect(Catching.shoutOut("Dee", "caught", cat("Legendary", "Sunny"), "gold")).to.equal(
				"Dee caught a gold Legendary Sunny!"
			)
			expect(Catching.shoutOut("Dee", "caught", cat("Legendary", "Sunny"), "rainbow")).to.equal(
				"Dee caught a rainbow Legendary Sunny!"
			)
			expect(Catching.shoutOut("Dee", "caught", cat("Mythical", "Moonpaw"), "gold")).to.equal(
				"Dee caught a gold Mythical Moonpaw!"
			)
		end)

		it("adds where it happened", function()
			local text = Catching.shoutOut(
				"Dee",
				"tamed",
				cat("Mythical", "Moonpaw"),
				"base",
				" at their bait bowl"
			)
			expect(text).to.equal("Dee tamed a Mythical Moonpaw at their bait bowl!")
		end)
	end)
	describe("spreadPick: a wave is scattered, not clumped (Derek 2026-10-27 22:38)", function()
		local function v(x: number, z: number): Vector3
			return Vector3.new(x, 0.1, z)
		end
		local spacing = Config.StraySpawnSpacingStuds

		it(
			"spawns at least StraySpawnSpacingStuds (12) from every stray in the area when it can",
			function()
				expect(spacing).to.equal(12)
				local points = { v(0, 0), v(5, 0), v(30, 0) }
				local taken = { v(2, 0) }
				for roll = 0, 0.99, 0.05 do
					expect(Catching.spreadPick(points, taken, roll)).to.equal(3)
				end
			end
		)

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

		it(
			"when every free point is closer than the spacing, takes the one farthest from all strays",
			function()
				local points = { v(3, 0), v(8, 0), v(5, 0) }
				local taken = { v(0, 0), v(16, 0) }
				expect(Catching.spreadPick(points, taken, 0.5)).to.equal(2)
			end
		)

		it("measures flat distance, so a stray on a step still counts", function()
			local points = { Vector3.new(0, 20, 0), v(40, 0) }
			expect(Catching.spreadPick(points, { v(0, 0) }, 0)).to.equal(2)
		end)

		it("has nothing to pick with no free points", function()
			expect(Catching.spreadPick({}, { v(0, 0) }, 0.5)).never.to.be.ok()
		end)

		it(
			"a ten-cat wave over the Park's points never puts two cats under 12 studs while a far point is free",
			function()
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
			end
		)
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

		it(
			"500 seeded areas: a far enough point whenever one is free, else the farthest",
			function()
				local rng = Random.new(368)
				local spacing = Config.StraySpawnSpacingStuds
				for _ = 1, 500 do
					local points: { Vector3 } = {}
					for _ = 1, rng:NextInteger(1, 12) do
						table.insert(
							points,
							Vector3.new(
								rng:NextNumber(-40, 40),
								rng:NextNumber(0, 8),
								rng:NextNumber(-40, 40)
							)
						)
					end
					local taken: { Vector3 } = {}
					for _ = 1, rng:NextInteger(0, 8) do
						table.insert(
							taken,
							Vector3.new(
								rng:NextNumber(-40, 40),
								rng:NextNumber(0, 8),
								rng:NextNumber(-40, 40)
							)
						)
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
			end
		)

		it(
			"a sweep of 12,000 rolls lands on each point in proportion to its gap, capped at 60 studs",
			function()
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
			end
		)
	end)
	describe(
		"spawnPool: which points a new stray may take (v3.1 nooks, F81 deep, the Great Oak's top)",
		function()
			local function slots(list: { { any } }): { Catching.SpawnSlot }
				local out: { Catching.SpawnSlot } = {}
				for _, row in list do
					table.insert(out, { zone = row[1], free = row[2] })
				end
				return out
			end
			-- a Woods-like area: near, deep and the oak's top, one near and one deep taken
			local woods = slots({
				{ "near", true },
				{ "near", false },
				{ "deep", true },
				{ "deep", false },
				{ "rare", true },
			})

			it("names the rare-biased zone", function()
				expect(Catching.RARE_ZONE).to.equal("rare")
			end)

			it("sends a Rare or rarer stray to a free rare point first", function()
				for _, rarity in { "Rare", "Epic", "Legendary", "Mythical" } do
					expect(Catching.spawnPool(woods, rarity :: any) :: any).to.deepEqual({ 5 })
				end
			end)

			it("never puts a Common, or a carried cat sent home, on a rare point", function()
				expect(Catching.spawnPool(woods, "Common") :: any).to.deepEqual({ 1, 3 })
				expect(Catching.spawnPool(woods, nil) :: any).to.deepEqual({ 1, 3 })
			end)

			it(
				"with the rare point taken, a Rare, Epic or Legendary takes any free point and a Mythical only deep ones",
				function()
					-- #2210 (crispi_255: the good cats "only spawn at the back"): Epic and Legendary kept to deep before
					local full = slots({ { "near", true }, { "deep", true }, { "rare", false } })
					expect(Catching.spawnPool(full, "Rare") :: any).to.deepEqual({ 1, 2 })
					expect(Catching.spawnPool(full, "Epic") :: any).to.deepEqual({ 1, 2 })
					expect(Catching.spawnPool(full, "Legendary") :: any).to.deepEqual({ 1, 2 })
					expect(Catching.spawnPool(full, "Mythical") :: any).to.deepEqual({ 2 })
				end
			)

			it(
				"leaves a Mythical with nowhere to go when every deep point is taken, and an Epic still a place",
				function()
					local park = slots({ { "near", true }, { "deep", false } })
					expect(#Catching.spawnPool(park, "Mythical")).to.equal(0)
					expect(Catching.spawnPool(park, "Epic") :: any).to.deepEqual({ 1 })
				end
			)

			it(
				"lets the Alleyway's Epic and up spawn anywhere (#3170), and keeps the deep half for Mythicals (#2210)",
				function()
					expect(Catching.KEEP_ZONES.nook).to.equal(nil)
					expect(Catching.KEEP_ZONES.deep).to.equal("Mythical")
					local alley = slots({ { "lane", true }, { "nook", true }, { "mid", true } })
					for _, rarity in { "Common", "Epic", "Legendary", "Mythical" } do
						expect(Catching.spawnPool(alley, rarity :: any) :: any).to.deepEqual({
							1,
							2,
							3,
						})
					end
				end
			)

			it("leaves a Mythical with nowhere to go when every deep point is taken", function()
				local park = slots({ { "near", true }, { "near", true }, { "deep", false } })
				expect(#Catching.spawnPool(park, "Mythical")).to.equal(0)
				expect(Catching.spawnPool(park, "Rare") :: any).to.deepEqual({ 1, 2 })
			end)

			it("takes any free point in an area with no zones", function()
				local plain = slots({ { nil, true }, { nil, false }, { nil, true } })
				expect(Catching.spawnPool(plain, "Legendary") :: any).to.deepEqual({ 1, 3 })
				expect(Catching.spawnPool(plain, "Common") :: any).to.deepEqual({ 1, 3 })
			end)
		end
	)
	describe(
		"hearsSpawn: only players with the area open hear a rare cat's spawn (#3897)",
		function()
			it("tells a player whose tier has the area, and not one below it", function()
				expect(Catching.hearsSpawn(2, 2)).to.equal(true)
				expect(Catching.hearsSpawn(5, 2)).to.equal(true)
				expect(Catching.hearsSpawn(1, 2)).to.equal(false)
			end)
			it("tells nobody about an unknown area or a player with no tier", function()
				expect(Catching.hearsSpawn(5, nil)).to.equal(false)
				expect(Catching.hearsSpawn(nil, 1)).to.equal(false)
			end)
		end
	)
	describe("waveShoutOut: a wave's Mythical told to the area's players (F58, #3897)", function()
		it("names the area and not the cat, and says gold when it is", function()
			expect(Catching.waveShoutOut("Mythical", "base", "Woods")).to.equal(
				"A Mythical cat appeared in the Woods!"
			)
			expect(Catching.waveShoutOut("Mythical", "gold", "Alleyway")).to.equal(
				"A gold Mythical cat appeared in the Alleyway!"
			)
			expect(Catching.waveShoutOut("Mythical", nil, "Park")).to.equal(
				"A Mythical cat appeared in the Park!"
			)
		end)

		it("says nothing for any other rarity, gold or not", function()
			for _, rarity in { "Common", "Rare", "Epic", "Legendary" } do
				expect(Catching.waveShoutOut(rarity :: any, "gold", "Sewer")).never.to.be.ok()
			end
		end)
	end)

	describe("chase and announce edges (QA, F57 and F58)", function()
		it(
			"the UI's first wait is the first step, and every step is longer than the one before",
			function()
				local steps = Config.StraySelfRetrySteps
				expect(Config.StraySelfRetrySeconds).to.equal(steps[1])
				expect(steps[1] > 0).to.equal(true)
				for index = 2, #steps do
					expect(steps[index] > steps[index - 1]).to.equal(true)
				end
			end
		)

		it(
			"a streak can build: the longest wait for any rarity is well under the 60 s reset",
			function()
				-- a player who tries again the moment they may, and misses, must still be inside the streak window, or
				-- the 6 and 10 s steps could never come up
				local last = Config.StraySelfRetrySteps[#Config.StraySelfRetrySteps]
				for _, rarity in Catalog.rarityOrder do
					local wait = Catching.fleeUntil(0, Catching.fleeStuds(rarity)) + last
					expect(wait < Config.StrayMissStreakResetSeconds).to.equal(true)
					-- and each miss in a row keeps the streak going
					local streak = Catching.nextMiss(nil, 0)
					for misses = 2, 5 do
						local at = Catching.fleeUntil(streak.at, Catching.fleeStuds(rarity))
							+ Catching.selfRetrySeconds(streak.count)
						streak = Catching.nextMiss(streak, at)
						expect(streak.count).to.equal(misses)
					end
				end
			end
		)

		it(
			"the one who missed always waits longer than everyone else, more with each miss in a row",
			function()
				for _, rarity in Catalog.rarityOrder do
					local everyone = Catching.fleeUntil(100, Catching.fleeStuds(rarity))
					local before = everyone
					for misses = 1, 5 do
						local own = everyone + Catching.selfRetrySeconds(misses)
						expect(own > everyone).to.equal(true)
						expect(own >= before).to.equal(true)
						before = own
					end
				end
			end
		)

		it("Startled is slower than carrying a cat, which is slower than walking", function()
			expect(Config.StartledWalkSpeed > 0).to.equal(true)
			expect(Config.StartledWalkSpeed < Config.CarryWalkSpeed).to.equal(true)
			expect(Config.CarryWalkSpeed < Config.NormalWalkSpeed).to.equal(true)
			expect(Config.StartledSeconds > 0).to.equal(true)
		end)

		it(
			"a dropped cat walking home is slower than anyone on foot, so it can always be caught up with (F67)",
			function()
				expect(Config.DropReturnWalkSpeed > 0).to.equal(true)
				expect(Config.DropReturnWalkSpeed < Config.StartledWalkSpeed).to.equal(true)
				-- home means within DropHomeRadiusStuds, well inside the reach of a grab
				expect(Config.DropHomeRadiusStuds < Config.GrabRangeStuds).to.equal(true)
				-- the fallback leaves time for a long walk: from the back alley's far end to the street at least
				local alley = Config.World.AlleyNorthZ - Config.World.AlleySouthZ
				expect(Config.DropReturnMaxSeconds > alley / Config.DropReturnWalkSpeed).to.equal(
					true
				)
			end
		)

		it("every area's Mythical line names the area and no cat", function()
			for _, area in Catalog.areas do
				for _, variant in { "base", "gold" } do
					local line = Catching.waveShoutOut("Mythical", variant, area.name) :: string
					expect(line).to.be.ok()
					expect(line:find(area.name, 1, true) ~= nil).to.equal(true)
					expect(line:sub(1, 2)).to.equal("A ")
					expect(line:sub(-1)).to.equal("!")
					expect(line:find("gold ", 1, true) ~= nil).to.equal(variant == "gold")
					-- #3997: the area's own name is not a cat's ("Snowy Mountain" holds the Alley's Snow)
					local rest = line:gsub(area.name, "", 1)
					for _, def in Catalog.cats do
						if rest:find(def.name, 1, true) ~= nil then
							error(string.format("%q names the cat %s", line, def.name))
						end
					end
				end
			end
		end)
	end)
	describe(
		"holdPoint (#1964): a held cat lies on the folded arms, in front of the chest",
		function()
			local UPPER = { 2, 1.6, 1 } -- a classic R15 UpperTorso
			local TORSO = { 2, 2, 1 } -- R6

			it(
				"rests a cat's back against the chest, centred, low on the chest (Derek2: closer and lower)",
				function()
					local x, y, z = Catching.holdPoint("R15", UPPER, 1)
					expect(x).to.equal(Catching.HELD.r15.side) -- nudged toward the cat's head so its body is centred
					expect(x <= 0 and x > -UPPER[1] / 4).to.equal(true)
					expect(y <= -UPPER[2] / 5 and y > -UPPER[2] / 2).to.equal(true) -- low on the torso, not at the hips
					expect(z).to.be.near(-(0.5 + Catching.HELD.r15.gap + 0.5), 1e-9)
					-- its back rests on the chest (at most a tenth of a stud out, so its head clears the chin) without
					-- sinking into it, so its middle is on the hands about a stud out
					local back = -z - 1 / 2 - UPPER[3] / 2
					expect(back >= 0 and back <= 0.1).to.equal(true)
				end
			)

			it("sits a wider cat further out, and scales with the avatar's torso", function()
				local _, _, small = Catching.holdPoint("R15", UPPER, 0.8)
				local _, _, big = Catching.holdPoint("R15", UPPER, 1.4)
				expect(big < small).to.equal(true)
				local _, low = Catching.holdPoint("R15", UPPER, 1)
				local _, tall = Catching.holdPoint("R15", { 2.4, 2.4, 1.2 }, 1)
				expect(tall < low).to.equal(true)
			end)

			it("uses R6's own height on its one-piece torso, inside it", function()
				local _, y = Catching.holdPoint("R6", TORSO, 1)
				expect(y).to.be.near(TORSO[2] * Catching.HELD.r6.up, 1e-9)
				expect(math.abs(y) < TORSO[2] / 2).to.equal(true)
			end)

			it(
				"lies across the arms asleep, like a napping cafe cat: legs tucked, head down, tail round",
				function()
					expect(Catching.HELD.turn).to.equal(90)
					for _, name in { "LegF1", "LegF2", "LegB1", "LegB2", "Head", "Tail" } do
						expect(#Catching.HELD_TURNS[name]).to.equal(3)
					end
					-- Model-Agent's manifest cat_poses.sleep, as Effects/Presets.catPoses.sleep (Derek2 2026-11-07)
					local Presets = require(
						game:GetService("StarterPlayer")
							:WaitForChild("StarterPlayerScripts")
							:WaitForChild("Client")
							:WaitForChild("Effects")
							:WaitForChild("Presets")
					) :: any
					local sleep = Presets.catPoses.sleep.turns
					local count = 0
					for name, angles in Catching.HELD_TURNS do
						count += 1
						if name ~= "Head" then
							for k = 1, 3 do
								expect(angles[k]).to.be.near(sleep[name][k], 1e-9)
							end
						end
					end
					-- the head only tucks down, further than the sleep's, and never turns toward the carrier's chin (#1984)
					local head = Catching.HELD_TURNS.Head
					expect(head[1] <= sleep.Head[1]).to.equal(true)
					expect(head[2]).to.equal(0)
					expect(head[3]).to.equal(0)
					for _ in sleep do
						count -= 1
					end
					expect(count).to.equal(0) -- the same pieces, no more and no fewer
					expect(Catching.HELD_EYES).to.equal(Presets.motion.blink.squash)
				end
			)
		end
	)

	describe("Catching.pickNewBaitCat (#4188)", function()
		it(
			"picks a kind not owned among the rarity's open cats, and falls back when all are owned",
			function()
				local pool: { string } = {}
				for _, def in Catalog.cats do
					local area = Catalog.getArea(def.area)
					if def.rarity == "Common" and area ~= nil and area.tier <= 1 then
						table.insert(pool, def.id)
					end
				end
				expect(#pool >= 2).to.equal(true)
				local owned: { [string]: any } = {}
				for index = 1, #pool - 1 do
					owned[pool[index]] = 1
				end
				for i = 0, 19 do
					expect(Catching.pickNewBaitCat("Common", 1, (i + 0.5) / 20, owned).id).to.equal(
						pool[#pool]
					)
				end
				owned[pool[#pool]] = 1
				local fallback = Catching.pickNewBaitCat("Common", 1, 0.5, owned)
				expect(fallback.id).to.equal(Catching.pickBaitCat("Common", 1, 0.5).id)
			end
		)
	end)
end
