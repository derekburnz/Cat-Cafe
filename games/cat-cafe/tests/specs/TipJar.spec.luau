--!strict
-- shared/TipJar.luau and Catalog.tipJar: the Tip Jar's playtime gifts (F47, data-model section 11b).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Catalog = require(ReplicatedStorage.Shared.Catalog)
	local TipJar = require(ReplicatedStorage.Shared.TipJar)

	describe("Catalog.tipJar (section 11b table, v0.10 F68)", function()
		-- step -> { minutes, prize }
		local expected: { { any } } = {
			{ 2, { coins = 50, coinSeconds = 30 } },
			{ 5, { lures = { kibble = 2 } } },
			{ 10, { coins = 100, coinSeconds = 60 } },
			{ 15, { lures = { tuna = 1 } } },
			{ 20, { coins = 150, coinSeconds = 90 } },
			{ 30, { lures = { tuna = 2 } } },
			{ 40, { coins = 250, coinSeconds = 120 } },
			{ 50, { lures = { salmon = 1 } } },
			-- the pretty good gift at an hour (round 4 Q10)
			{ 60, { coins = 1000, coinSeconds = 600, fish = 10, spins = 1 } },
			{ 75, { lures = { sardines = 1 } } },
			{ 90, { coins = 600, coinSeconds = 300, spins = 1 } },
			-- and the really good one at two hours, with its Tip Potion since F64
			{
				120,
				{
					lures = { caviar = 1 },
					crates = { classic_crate = 1 },
					fish = 25,
					spins = 2,
					potions = { tip_potion = 1 },
				},
			},
		}

		it("has the twelve steps in order, each at its own index, paying the design's prizes", function()
			expect(#Catalog.tipJar).to.equal(#expected)
			for index, def in ipairs(Catalog.tipJar) do
				local row = expected[index]
				expect(def.step).to.equal(index)
				expect(def.minutes).to.equal(row[1])
				expect(def.prize :: any).to.deepEqual(row[2])
			end
		end)

		it("unlocks later with every step, and every food and crate is real", function()
			for index, def in ipairs(Catalog.tipJar) do
				if index > 1 then
					expect(def.minutes > Catalog.tipJar[index - 1].minutes).to.equal(true)
				end
				for lureId in def.prize.lures or {} do
					expect(Catalog.getLure(lureId)).to.be.ok()
				end
				for crateId in def.prize.crates or {} do
					expect(Catalog.getCrate(crateId)).to.be.ok()
				end
			end
		end)

		it("names each step's kind for analytics", function()
			local kinds = {}
			for _, def in ipairs(Catalog.tipJar) do
				table.insert(kinds, TipJar.kind(def))
			end
			expect(kinds :: any).to.deepEqual({
				"coins",
				"lure",
				"coins",
				"lure",
				"coins",
				"lure",
				"coins",
				"lure",
				"mixed",
				"lure",
				"mixed",
				"mixed",
			})
		end)
	end)

	describe("TipJar rules", function()
		local first = Catalog.tipJar[1] -- 2 minutes, 30 s of day rate, at least 50
		local last = Catalog.tipJar[12] -- 120 minutes, Caviar, a crate, fish and spins

		it("a step is ready once the session has run its minutes", function()
			expect(TipJar.unlocksAfter(first)).to.equal(120)
			expect(TipJar.isReady(first, 1000, 1119.9)).to.equal(false)
			expect(TipJar.isReady(first, 1000, 1120)).to.equal(true)
			expect(TipJar.isReady(last, 1000, 1000 + 7199)).to.equal(false)
			expect(TipJar.isReady(last, 1000, 1000 + 7200)).to.equal(true)
		end)

		it("a coins step pays its seconds of day rate, never under its floor", function()
			expect(TipJar.coins(first, 0)).to.equal(50)
			expect(TipJar.coins(first, 1.5)).to.equal(50) -- 45 is under the floor
			expect(TipJar.coins(first, 10)).to.equal(300)
			expect(TipJar.coins(first, 10.55)).to.equal(316) -- floored
			expect(TipJar.coins(first, -5)).to.equal(50)
			expect(TipJar.coins(Catalog.tipJar[11], 100)).to.equal(30000)
			-- step 9 (v0.10): 600 s of day rate, at least 1,000
			expect(TipJar.coins(Catalog.tipJar[9], 1)).to.equal(1000)
			expect(TipJar.coins(Catalog.tipJar[9], 2.5)).to.equal(1500)
		end)

		it("a step without coins pays none", function()
			expect(TipJar.coins(last, 1000)).to.equal(0)
		end)

		it("a fresh session has every step unclaimed, as a dense array", function()
			local claimed = TipJar.unclaimed()
			expect(#claimed).to.equal(#Catalog.tipJar)
			for _, flag in ipairs(claimed) do
				expect(flag).to.equal(false)
			end
			expect(TipJar.step(3)).to.equal(Catalog.tipJar[3])
			expect(TipJar.step(13)).never.to.be.ok()
		end)
	end)

	describe("TipJar edges (QA)", function()
		-- TipJarService credits TipJar.coins straight into the save, so a NaN or a fraction here would stay in the
		-- player's coins for good.
		it("pays whole coins at or over the floor at any day rate, rising with the rate", function()
			for _, def in Catalog.tipJar do
				if def.prize.coins ~= nil then
					local floor = def.prize.coins :: number
					for _, rate in { 0 / 0, -math.huge, -1, 0 } do
						expect(TipJar.coins(def, rate)).to.equal(floor)
					end
					local last = floor
					for step = 0, 400 do
						local paid = TipJar.coins(def, step * 0.37)
						expect(paid == math.floor(paid) and paid >= last).to.equal(true)
						last = paid
					end
				end
			end
		end)
	end)
end
