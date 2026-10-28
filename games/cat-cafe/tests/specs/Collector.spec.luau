--!strict
-- shared/Collector.luau and Catalog.collectorOffers against data-model section 12b (F63, the Cat Collector): which cat
-- he asks for, the value he puts on it, the offer that value reaches and what a trade pays.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local CatStats = require(Shared.CatStats)
	local Collector = require(Shared.Collector)
	local Config = require(Shared.Config)

	local function firstOf(rarity: string, area: string?): string
		for _, def in Catalog.cats do
			if def.rarity == rarity and (area == nil or def.area == area) and Catalog.getArea(def.area) ~= nil then
				return def.id
			end
		end
		error("no cat of rarity " .. rarity)
	end

	local function cat(uid: string, catId: string, fields: { [string]: any }?): any
		local instance: any = CatStats.newInstance(uid, catId, 100)
		for key, value in fields or {} do
			instance[key] = value
		end
		return instance
	end

	local function fixed(value: number): () -> number
		return function()
			return value
		end
	end

	describe("Catalog.collectorOffers (section 12b)", function()
		it("is the design's nine rows, lowest value first", function()
			expect(Catalog.collectorOffers :: any).to.deepEqual({
				{ value = 1, fish = 5 },
				{ value = 2, lures = { tuna = 3 }, spins = 1 },
				{ value = 4, fish = 15 },
				{ value = 6, crates = { zone = 1 } },
				{ value = 11, crates = { zone = 1 }, fish = 20 },
				{ value = 20, crates = { zone = 2 } },
				{ value = 35, crates = { golden = 1 } },
				{ value = 60, crates = { golden = 1 }, fish = 50 },
				{ value = 120, crates = { golden = 2 }, fish = 100 },
			})
			expect(Catalog.getLure("tuna")).to.be.ok()
		end)

		it("values cats by rarity and gold with a roll from 0.8 to 1.5", function()
			expect(Config.CollectorValue :: any).to.deepEqual({ Common = 1, Rare = 3, Epic = 8, Legendary = 20, Mythical = 50 })
			expect(Config.CollectorGoldMultiplier).to.equal(3)
			expect(Config.CollectorRollMin).to.equal(0.8)
			expect(Config.CollectorRollMax).to.equal(1.5)
		end)
	end)

	describe("value and offerFor", function()
		it("lays the roll over 0.8 to 1.5 of the rarity's value, three times for gold", function()
			local epic = cat("e", firstOf("Epic"))
			expect(Collector.value(epic, 0)).to.be.near(8 * 0.8, 1e-9)
			expect(Collector.value(epic, 1)).to.be.near(8 * 1.5, 1e-9)
			expect(Collector.value(epic, 2)).to.be.near(8 * 1.5, 1e-9) -- clamped
			local gold = cat("g", firstOf("Epic"), { variant = "gold" })
			expect(Collector.value(gold, 0.5)).to.be.near(8 * 3 * 1.15, 1e-9)
			expect(Collector.value(cat("x", "no_such_cat"), 1)).to.equal(0)
		end)

		it("offers the best row the value reaches, and the first below that", function()
			expect(Collector.offerFor(0).value).to.equal(1)
			expect(Collector.offerFor(0.8).value).to.equal(1)
			expect(Collector.offerFor(1.99).value).to.equal(1)
			expect(Collector.offerFor(2).value).to.equal(2)
			expect(Collector.offerFor(34.9).value).to.equal(20)
			expect(Collector.offerFor(35).value).to.equal(35)
			expect(Collector.offerFor(1000).value).to.equal(120)
		end)

		-- the design's table of what each kind of cat gets (Design #500: the crate rows at 6 and 11, so every Epic
		-- gets a crate and its rolls from 11 to 12 20 fish with it)
		it("gives a Common 5 fish, a Rare tuna and a spin or 15 fish, an Epic a crate or more", function()
			local function offers(catId: string, variant: string): { [number]: boolean }
				local seen: { [number]: boolean } = {}
				for step = 0, 100 do
					local instance = cat("c", catId, { variant = variant })
					seen[Collector.offerFor(Collector.value(instance, step / 100)).value] = true
				end
				return seen
			end
			expect(offers(firstOf("Common"), "base") :: any).to.deepEqual({ [1] = true })
			expect(offers(firstOf("Rare"), "base") :: any).to.deepEqual({ [2] = true, [4] = true })
			expect(offers(firstOf("Epic"), "base") :: any).to.deepEqual({ [6] = true, [11] = true })
			expect(offers(firstOf("Legendary"), "base") :: any).to.deepEqual({ [11] = true, [20] = true })
			expect(offers(firstOf("Mythical"), "base") :: any).to.deepEqual({ [35] = true, [60] = true })
			-- features.md F63 done when: a gold Epic offers a crate and 20 fish, two crates or a golden crate
			expect(offers(firstOf("Epic"), "gold") :: any).to.deepEqual({ [11] = true, [20] = true, [35] = true })
			expect(offers(firstOf("Rare"), "gold") :: any).to.deepEqual({ [6] = true, [11] = true })
			expect(offers(firstOf("Legendary"), "gold") :: any).to.deepEqual({ [35] = true, [60] = true })
			expect(offers(firstOf("Mythical"), "gold") :: any).to.deepEqual({ [120] = true })
		end)
	end)

	describe("pickCat", function()
		it("asks only for resting, unlocked area cats", function()
			local common = firstOf("Common")
			local cats = {
				working = cat("working", common, { spotId = "barista_1" }),
				locked = cat("locked", common, { locked = true }),
				unknown = cat("unknown", "no_such_cat"),
			}
			expect(Collector.pickCat(cats, fixed(0))).to.equal(nil)
			cats.resting = cat("resting", common)
			expect((Collector.pickCat(cats, fixed(0)) :: any).uid).to.equal("resting")
			expect(Collector.askable(cats.resting)).to.equal(true)
			expect(Collector.askable(cats.working)).to.equal(false)
			expect(Collector.askable(cats.locked)).to.equal(false)
		end)

		it("picks a catId evenly, so a pile of one kind does not crowd out the rest", function()
			local a, b = firstOf("Common", "alley"), firstOf("Rare", "alley")
			local cats: { [string]: any } = { b1 = cat("b1", b) }
			for n = 1, 9 do
				cats["a" .. n] = cat("a" .. n, a)
			end
			local ids = { a, b }
			table.sort(ids)
			expect((Collector.pickCat(cats, fixed(0)) :: any).catId).to.equal(ids[1])
			expect((Collector.pickCat(cats, fixed(0.99)) :: any).catId).to.equal(ids[2])
		end)

		it("takes that catId's lowest rated cat, the lowest uid on a tie", function()
			local common = firstOf("Common")
			local cats = {
				high = cat("high", common, { charm = 90 }),
				low = cat("low", common, { charm = 10 }),
				gold = cat("gold", common, { variant = "gold", charm = 10 }),
			}
			expect((Collector.pickCat(cats, fixed(0)) :: any).uid).to.equal("low")
			local tied = { zed = cat("zed", common), abe = cat("abe", common) }
			expect((Collector.pickCat(tied, fixed(0)) :: any).uid).to.equal("abe")
		end)
	end)

	describe("prize", function()
		it("pays the cat's own area's crate and golden crate, fish, food and spins", function()
			local zone = Collector.prize({ value = 11, crates = { zone = 1 }, fish = 20 }, "park")
			expect(zone :: any).to.deepEqual({ fish = 20, crates = { park_crate = 1 } })
			expect(Catalog.getCrate("park_crate")).to.be.ok()
			local golden = Collector.prize({ value = 120, crates = { golden = 2 }, fish = 100 }, "sewer")
			expect(golden :: any).to.deepEqual({ fish = 100, crates = { sewer_golden_crate = 2 } })
			expect(Catalog.getCrate("sewer_golden_crate")).to.be.ok()
			local food = Collector.prize(Catalog.collectorOffers[2], "alley")
			expect(food :: any).to.deepEqual({ lures = { tuna = 3 }, spins = 1 })
		end)

		it("names a real crate for every area and every crate row", function()
			for _, area in Catalog.areas do
				for _, row in Catalog.collectorOffers do
					local crates: { [string]: number } = Collector.prize(row, area.id).crates or {}
					for crateId in crates do
						if Catalog.getCrate(crateId) == nil then
							error(string.format("no crate %s for %s", crateId, area.id))
						end
					end
				end
			end
		end)
	end)

	describe("Cat Collector edges (QA, F63)", function()
		-- the share of rolls, swept evenly over 0 to 1, whose offer is the row of `value`
		local function share(catId: string, variant: string, value: number): number
			local hits, steps = 0, 10000
			for step = 0, steps - 1 do
				local instance = cat("c", catId, { variant = variant })
				if Collector.offerFor(Collector.value(instance, (step + 0.5) / steps)).value == value then
					hits += 1
				end
			end
			return hits / steps
		end

		it("matches the design's words on how often the better rows come up (section 12b)", function()
			-- "an Epic a crate and about one time in six 20 fish with it": 8 x 0.8 to 1.5 reaches 11 above roll 0.82
			expect(share(firstOf("Epic"), "base", 11)).to.be.near(1 / 6, 0.02)
			-- "a gold Rare (7.2 to 13.5) gets the 20 fish 40% of the time"
			expect(share(firstOf("Rare"), "gold", 11)).to.be.near(0.40, 0.01)
			-- "a Mythical a golden crate and often 50 fish with it": 40 to 75 reaches 60 for 15 of its 35
			expect(share(firstOf("Mythical"), "base", 60)).to.be.near(15 / 35, 0.01)
			-- "a Legendary a crate and fish or two crates": 16 to 30, two crates from 20
			expect(share(firstOf("Legendary"), "base", 20)).to.be.near(10 / 14, 0.01)
		end)

		it("never offers less for a better roll, or for the gold cat of the same kind", function()
			for _, def in Catalog.cats do
				if Catalog.getArea(def.area) == nil then
					continue
				end
				local before, beforeGold = 0, 0
				for step = 0, 200 do
					local roll = step / 200
					local plain = Collector.offerFor(Collector.value(cat("p", def.id), roll)).value
					local gold = Collector.offerFor(Collector.value(cat("g", def.id, { variant = "gold" }), roll)).value
					if plain < before or gold < beforeGold or gold < plain then
						error(string.format("%s at roll %.3f: plain %d, gold %d", def.id, roll, plain, gold))
					end
					before, beforeGold = plain, gold
				end
			end
		end)

		it("500 seeded cafes: asks only for a resting, unlocked area cat, the lowest rated of its kind", function()
			local rng = Random.new(6301)
			local ids: { string } = {}
			for _, def in Catalog.cats do
				table.insert(ids, def.id)
			end
			table.insert(ids, "no_such_cat")
			local asked = 0
			for run = 1, 500 do
				local cats: { [string]: any } = {}
				for n = 1, rng:NextInteger(0, 9) do
					local uid = string.format("u%d_%d", run, n)
					cats[uid] = cat(uid, ids[rng:NextInteger(1, #ids)], {
						spotId = if rng:NextNumber() < 0.4 then "waiter_1" else nil,
						locked = if rng:NextNumber() < 0.3 then true else nil,
						variant = if rng:NextNumber() < 0.2 then "gold" else "base",
						level = rng:NextInteger(1, 50),
						charm = rng:NextInteger(0, 100),
					})
				end
				local askable = 0
				for _, instance in cats do
					if Collector.askable(instance) then
						askable += 1
					end
				end
				local roll = rng:NextNumber()
				local picked = Collector.pickCat(cats, function()
					return roll
				end)
				if askable == 0 then
					expect(picked).never.to.be.ok()
					continue
				end
				expect(picked).to.be.ok()
				local chosen = picked :: any
				local def = Catalog.getCat(chosen.catId)
				if
					def == nil
					or Catalog.getArea(def.area) == nil
					or chosen.spotId ~= nil
					or chosen.locked == true
				then
					error(string.format("run %d asked for %s (%s)", run, chosen.uid, chosen.catId))
				end
				for _, instance in cats do
					if
						instance.catId == chosen.catId
						and Collector.askable(instance)
						and CatStats.rating(instance) < CatStats.rating(chosen)
					then
						error(string.format("run %d asked for %s over the lower rated %s", run, tostring(chosen.uid), tostring(instance.uid)))
					end
				end
				asked += 1
			end
			expect(asked > 200).to.equal(true)
		end)

		it("about one visit every 25 minutes of play by the clock (one check every 120 s at 12%, by day only)", function()
			-- data-model 12b says about 35, from before the short night (F66); by the build's numbers a check lands in
			-- the open part of the day (a 300 s day of a 390 s loop, less the last DuskWarningSeconds) 285 / 390 of
			-- the time, and a visit then holds the plot for CollectorStaySeconds
			local open = (Config.DayLengthSeconds - Config.DuskWarningSeconds)
				/ (Config.DayLengthSeconds + Config.NightLengthSeconds)
			local waiting = Config.CollectorCheckSeconds / (Config.CollectorChance * open)
			local minutes = (waiting + Config.CollectorStaySeconds) / 60
			expect(minutes > 20 and minutes < 30).to.equal(true)
		end)
	end)
end
