--!strict
-- shared/Spin.luau and Catalog.spinWheel against data-model section 11c (F49): one free spin a UTC day, banked
-- spins up to SpinBankCap, the free one used first, six weighted slices whose chances add up to 100.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Catalog = require(ReplicatedStorage.Shared.Catalog)
	local Config = require(ReplicatedStorage.Shared.Config)
	local Spin = require(ReplicatedStorage.Shared.Spin)

	local DAY = 86400

	describe("Catalog.spinWheel (section 11c)", function()
		it("has six slices in wheel order whose weights add up to 100", function()
			expect(#Catalog.spinWheel).to.equal(6)
			local total = 0
			for index, row in Catalog.spinWheel do
				expect(row.slice).to.equal(index)
				expect(row.weight > 0).to.equal(true)
				total += row.weight
			end
			expect(total).to.equal(100)
		end)

		it("matches the design's prizes and chances", function()
			local rows = Catalog.spinWheel :: any
			expect(rows[1]).to.deepEqual({
				slice = 1,
				kind = "coins",
				seconds = 120,
				minCoins = 200,
				weight = 30,
			})
			expect(rows[2]).to.deepEqual({
				slice = 2,
				kind = "lure",
				lureId = "tuna",
				count = 3,
				weight = 22,
			})
			expect(rows[3]).to.deepEqual({
				slice = 3,
				kind = "coins",
				seconds = 600,
				minCoins = 1000,
				weight = 18,
			})
			expect(rows[4]).to.deepEqual({
				slice = 4,
				kind = "lure",
				lureId = "salmon",
				count = 2,
				weight = 15,
			})
			expect(rows[5]).to.deepEqual({
				slice = 5,
				kind = "lure",
				lureId = "sardines",
				count = 2,
				weight = 10,
			})
			expect(rows[6]).to.deepEqual({
				slice = 6,
				kind = "lure",
				lureId = "caviar",
				count = 1,
				weight = 5,
			})
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

		it("banks one spin from each of Tip Jar steps 11 and 12 and from no other step", function()
			for _, row in Catalog.tipJar do
				expect(row.spins).to.equal(if row.step == 11 or row.step == 12 then 1 else nil)
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
			expect(Spin.pick(0.2999).slice).to.equal(1)
			expect(Spin.pick(0.30).slice).to.equal(2)
			expect(Spin.pick(0.5199).slice).to.equal(2)
			expect(Spin.pick(0.52).slice).to.equal(3)
			expect(Spin.pick(0.70).slice).to.equal(4)
			expect(Spin.pick(0.85).slice).to.equal(5)
			expect(Spin.pick(0.95).slice).to.equal(6)
			expect(Spin.pick(0.99999).slice).to.equal(6)
			expect(Spin.pick(1).slice).to.equal(6)
			expect(Spin.pick(-1).slice).to.equal(1)
		end)

		it("pays coins from the day rate with a floor, and foods by count", function()
			local rows = Catalog.spinWheel
			expect(Spin.amount(rows[1], 0)).to.equal(200)
			expect(Spin.amount(rows[1], 5)).to.equal(600)
			expect(Spin.amount(rows[3], 1)).to.equal(1000)
			expect(Spin.amount(rows[3], 10.5)).to.equal(6300)
			expect(Spin.amount(rows[2], 1000)).to.equal(3)
			expect(Spin.amount(rows[6], 1000)).to.equal(1)
		end)
	end)
end
