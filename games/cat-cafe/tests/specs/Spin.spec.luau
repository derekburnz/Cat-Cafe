--!strict
-- shared/Spin.luau and Catalog.spinWheel against data-model section 11c (F49): one free spin a UTC day, banked
-- spins up to SpinBankCap, the free one used first, eight weighted slices whose chances add up to 100% (v2, #1500).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Catalog = require(ReplicatedStorage.Shared.Catalog)
	local Config = require(ReplicatedStorage.Shared.Config)
	local Prizes = require(ReplicatedStorage.Shared.Prizes)
	local Spin = require(ReplicatedStorage.Shared.Spin)

	local DAY = 86400

	describe("Catalog.spinWheel (section 11c)", function()
		it("has eight slices in wheel order whose weights add up to 200 half-percents (v2, #1500)", function()
			expect(#Catalog.spinWheel).to.equal(8)
			local total = 0
			for index, row in Catalog.spinWheel do
				expect(row.slice).to.equal(index)
				expect(row.weight > 0).to.equal(true)
				total += row.weight
			end
			expect(total).to.equal(200)
		end)

		it("matches the design's prizes and chances (rewards-and-shops.md section 2b v2)", function()
			local rows = Catalog.spinWheel :: any
			expect(rows[1]).to.deepEqual({ slice = 1, kind = "coins", seconds = 120, minCoins = 200, weight = 70 })
			expect(rows[2]).to.deepEqual({ slice = 2, kind = "coins", seconds = 600, minCoins = 1000, weight = 44 })
			expect(rows[3]).to.deepEqual({ slice = 3, kind = "fish", count = 5, weight = 30 })
			expect(rows[4]).to.deepEqual({ slice = 4, kind = "coins", seconds = 1800, minCoins = 3000, weight = 24 })
			expect(rows[5]).to.deepEqual({ slice = 5, kind = "lure", lureId = "caviar", count = 1, weight = 18 })
			expect(rows[6]).to.deepEqual({ slice = 6, kind = "crate", crate = "highest", count = 1, weight = 12 })
			-- the two 0.5% jackpots
			expect(rows[7]).to.deepEqual({
				slice = 7,
				kind = "crate",
				crate = "highest_golden",
				count = 1,
				weight = 1,
				jackpot = true,
			})
			expect(rows[8]).to.deepEqual({ slice = 8, kind = "fish", count = 100, weight = 1, jackpot = true })
			-- coins land on 69% of spins
			local coins = 0
			for _, row in rows do
				if row.kind == "coins" then
					coins += row.weight
				end
			end
			expect(coins / 200).to.be.near(0.69, 1e-9)
			expect(Spin.amount(rows[3], 100)).to.equal(5)
			expect(Spin.amount(rows[8], 100)).to.equal(100)
			expect(Spin.amount(rows[7], 100)).to.equal(1)
		end)

		it("pays the jackpot crate as the golden crate of the highest open zone", function()
			expect(Prizes.crateFor(Prizes.HIGHEST_GOLDEN, 1)).to.equal("alley_golden_crate")
			expect(Prizes.crateFor(Prizes.HIGHEST_GOLDEN, 3)).to.equal("neighbourhood_golden_crate")
			expect(Prizes.crateFor(Prizes.HIGHEST_GOLDEN, 5)).to.equal("sewer_golden_crate")
			expect(Prizes.crateFor(Prizes.HIGHEST, 5)).to.equal("sewer_crate")
			for tier = 1, 5 do
				local id = Prizes.crateFor(Prizes.HIGHEST_GOLDEN, tier) :: string
				local crate = Catalog.getCrate(id) :: any
				expect(crate.golden).to.equal(true)
				local plain = Catalog.getCrate(Prizes.crateFor(Prizes.HIGHEST, tier) :: string) :: any
				expect(crate.area).to.equal(plain.area)
			end
		end)

		it("toasts only a jackpot, with its prize", function()
			local rows = Catalog.spinWheel
			expect(Spin.jackpotText(rows[8], 100, nil)).to.equal("Jackpot! 100 golden fish")
			expect(Spin.jackpotText(rows[7], 1, "park_golden_crate")).to.equal("Jackpot! A Golden Park Crate")
			for slice = 1, 6 do
				expect(Spin.jackpotText(rows[slice], 1, "park_crate")).to.equal(nil)
			end
		end)

		it("lands each slice within 0.1 point of its chance over 200,000 evenly spread spins (QA)", function()
			-- evenly spread rolls test the weight walk itself; the server's Random supplies the rolls in play
			local hits: { number } = {}
			local count = 200000
			for i = 0, count - 1 do
				local slice = Spin.pick((i + 0.5) / count).slice
				hits[slice] = (hits[slice] or 0) + 1
			end
			for _, row in Catalog.spinWheel do
				expect((hits[row.slice] or 0) / count).to.be.near(row.weight / 200, 0.001)
			end
		end)

		it("names real foods and is frozen", function()
			for _, row in Catalog.spinWheel do
				if row.kind == "lure" then
					expect(Catalog.getLure(row.lureId :: string)).to.be.ok()
				end
				expect(table.isfrozen(row)).to.equal(true)
			end
			expect(table.isfrozen(Catalog.spinWheel)).to.equal(true)
		end)

		it("banks 5 spins from Tip Jar steps 6 and 11 and none from the rest (#1414)", function()
			local spins = { [6] = 5, [11] = 5 }
			for _, row in Catalog.tipJar do
				expect(row.prize.spins).to.equal(spins[row.step])
			end
		end)
	end)

	describe("free and banked spins", function()
		it(
			"a free spin is due on any UTC day after the last free one, and missed days do not stack",
			function()
				local spin = { lastFreeDay = 10, banked = 0 }
				expect(Spin.day(10 * DAY + 5)).to.equal(10)
				expect(Spin.freeDue(spin, 10 * DAY + 86399)).to.equal(false)
				expect(Spin.freeDue(spin, 11 * DAY)).to.equal(true)
				expect(Spin.available(spin, 15 * DAY)).to.equal(1)
			end
		)

		it("counts the free spin and the banked ones", function()
			local spin = { lastFreeDay = 10, banked = 3 }
			expect(Spin.available(spin, 10 * DAY + 1)).to.equal(3)
			expect(Spin.available(spin, 11 * DAY + 1)).to.equal(4)
		end)

		it("uses the free spin first, then banked ones, then refuses", function()
			local spin = { lastFreeDay = 10, banked = 1 }
			local now = 12 * DAY + 100
			expect(Spin.take(spin, now)).to.equal("free")
			expect(spin.lastFreeDay).to.equal(12)
			expect(Spin.take(spin, now)).to.equal("banked")
			expect(spin.banked).to.equal(0)
			expect(Spin.take(spin, now)).never.to.be.ok()
			expect(spin.lastFreeDay).to.equal(12)
		end)

		it("says when the next free spin is due: now, or the next 00:00 UTC", function()
			local spin = { lastFreeDay = 12, banked = 0 }
			expect(Spin.nextFreeAt(spin, 12 * DAY + 100)).to.equal(13 * DAY)
			expect(Spin.nextFreeAt(spin, 13 * DAY + 7)).to.equal(13 * DAY + 7)
		end)

		it("banks up to SpinBankCap and says how many went in", function()
			local spin = { lastFreeDay = 0, banked = Config.SpinBankCap - 1 }
			expect(Spin.bank(spin, 1)).to.equal(1)
			expect(spin.banked).to.equal(Config.SpinBankCap)
			expect(Spin.bank(spin, 1)).to.equal(0)
			expect(spin.banked).to.equal(Config.SpinBankCap)
			spin.banked = 0
			expect(Spin.bank(spin, -3)).to.equal(0)
			expect(spin.banked).to.equal(0)
		end)
	end)

	describe("pick and amount", function()
		it("walks the weights in wheel order", function()
			expect(Spin.pick(0).slice).to.equal(1)
			expect(Spin.pick(0.3499).slice).to.equal(1)
			expect(Spin.pick(0.3501).slice).to.equal(2)
			expect(Spin.pick(0.5699).slice).to.equal(2)
			expect(Spin.pick(0.5701).slice).to.equal(3)
			expect(Spin.pick(0.7201).slice).to.equal(4)
			expect(Spin.pick(0.8401).slice).to.equal(5)
			expect(Spin.pick(0.9301).slice).to.equal(6)
			expect(Spin.pick(0.9899).slice).to.equal(6)
			expect(Spin.pick(0.9901).slice).to.equal(7)
			expect(Spin.pick(0.9949).slice).to.equal(7)
			expect(Spin.pick(0.9951).slice).to.equal(8)
			expect(Spin.pick(0.99999).slice).to.equal(8)
			expect(Spin.pick(1).slice).to.equal(8)
			expect(Spin.pick(-1).slice).to.equal(1)
		end)

		it("pays coins from the day rate with a floor, and foods by count", function()
			local rows = Catalog.spinWheel
			expect(Spin.amount(rows[1], 0)).to.equal(200)
			expect(Spin.amount(rows[1], 5)).to.equal(600)
			expect(Spin.amount(rows[2], 1)).to.equal(1000)
			expect(Spin.amount(rows[2], 10.5)).to.equal(6300)
			expect(Spin.amount(rows[4], 1)).to.equal(3000)
			expect(Spin.amount(rows[4], 10)).to.equal(18000)
			expect(Spin.amount(rows[5], 1000)).to.equal(1)
			expect(Spin.amount(rows[6], 1000)).to.equal(1)
		end)
	end)

	describe("use all (#1078)", function()
		it("adds several spins' prizes up for one card, in the order each prize first came", function()
			local totals = Spin.summarize({
				{ slice = 3, amount = 5 },
				{ slice = 1, amount = 250 },
				{ slice = 8, amount = 100 },
				{ slice = 2, amount = 1200 },
				{ slice = 5, amount = 1 },
				{ slice = 6, amount = 1 },
				{ slice = 7, amount = 1 },
				{ slice = 5, amount = 1 },
				{ slice = 4, amount = 3000 },
				{ slice = 99, amount = 5 }, -- unknown: left out
			})
			expect(totals :: any).to.deepEqual({
				{ kind = "fish", amount = 105 },
				{ kind = "coins", amount = 4450 },
				{ kind = "lure", id = "caviar", amount = 2 },
				{ kind = "crate", id = "highest", amount = 1 },
				{ kind = "crate", id = "highest_golden", amount = 1 },
			})
			expect(#Spin.summarize({})).to.equal(0)
		end)

		it("spends a full bank and today's free spin in one press", function()
			expect(Config.SpinAllMax >= Config.SpinBankCap + 1).to.equal(true)
		end)
	end)
end
