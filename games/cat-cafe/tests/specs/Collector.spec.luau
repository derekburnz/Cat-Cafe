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
end
