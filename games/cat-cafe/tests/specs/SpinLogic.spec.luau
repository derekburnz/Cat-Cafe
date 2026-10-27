--!strict
-- UI/Components/SpinLogic.luau: the Spin Wheel window's spins, countdown, chances and landing (F49, data-model 11c).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local SpinLogic = require(Components:WaitForChild("SpinLogic")) :: any

	local DAY = 86400
	local ROWS = {
		{ slice = 1, kind = "coins", seconds = 120, minCoins = 200, weight = 30 },
		{ slice = 2, kind = "lure", lureId = "tuna", count = 3, weight = 22 },
		{ slice = 3, kind = "coins", seconds = 600, minCoins = 1000, weight = 18 },
		{ slice = 4, kind = "lure", lureId = "salmon", count = 2, weight = 15 },
		{ slice = 5, kind = "lure", lureId = "sardines", count = 2, weight = 10 },
		{ slice = 6, kind = "lure", lureId = "caviar", count = 1, weight = 5 },
	}

	describe("SpinLogic spins", function()
		it("has today's free spin due once the UTC day passes lastFreeDay", function()
			local now = 20000 * DAY + 3600
			expect(SpinLogic.freeDue({ lastFreeDay = 19999, banked = 0 }, now)).to.equal(true)
			expect(SpinLogic.freeDue({ lastFreeDay = 20000, banked = 0 }, now)).to.equal(false)
			expect(SpinLogic.freeDue(nil, now)).to.equal(true)
		end)

		it("counts the banked spins plus the free one, and missed days do not stack", function()
			local now = 20000 * DAY
			expect(SpinLogic.spins({ lastFreeDay = 19990, banked = 2 }, now)).to.equal(3)
			expect(SpinLogic.spins({ lastFreeDay = 20000, banked = 2 }, now)).to.equal(2)
			expect(SpinLogic.spins({ lastFreeDay = 20000, banked = 0 }, now)).to.equal(0)
			expect(SpinLogic.spins(nil, now)).to.equal(1)
		end)

		it("counts down to 00:00 UTC once today's free spin is used", function()
			local now = 20000 * DAY + 5 * 3600
			expect(SpinLogic.nextFreeIn({ lastFreeDay = 20000, banked = 0 }, now)).to.equal(
				19 * 3600
			)
			expect(SpinLogic.nextFreeIn({ lastFreeDay = 19999, banked = 0 }, now)).to.equal(0)
		end)

		it("says why a spin was refused", function()
			local now = 20000 * DAY + 23 * 3600 + 30 * 60
			local used = { lastFreeDay = 20000, banked = 0 }
			expect(SpinLogic.refusal(used, now)).to.equal("Next free spin in 30m 0s")
			expect(SpinLogic.refusal({ lastFreeDay = 20000, banked = 1 }, now)).to.equal(
				"Walk up to the wheel and try again"
			)
		end)

		it("writes waits as hours and minutes, minutes and seconds, or seconds", function()
			expect(SpinLogic.wait(5 * 3600 + 12 * 60 + 40)).to.equal("5h 12m")
			expect(SpinLogic.wait(12 * 60 + 30)).to.equal("12m 30s")
			expect(SpinLogic.wait(44.2)).to.equal("45s")
			expect(SpinLogic.wait(-3)).to.equal("0s")
		end)
	end)

	describe("SpinLogic prizes", function()
		it("shows each slice's chance, and the chances add up to 100%", function()
			local total = 0
			for _, row in ROWS do
				local text = SpinLogic.chance(ROWS, row)
				expect(text).to.equal(("%d%%"):format(row.weight))
				total += tonumber(text:sub(1, -2)) :: number
			end
			expect(total).to.equal(100)
			local halves = {
				{ slice = 1, kind = "coins", weight = 1 },
				{ slice = 2, kind = "coins", weight = 39 },
			}
			expect(SpinLogic.chance(halves, halves[1])).to.equal("2.5%")
			expect(SpinLogic.chance({}, ROWS[1])).to.equal("0%")
		end)

		it("lists the slices likeliest first for the Odds list, adding up to 100% (F69)", function()
			local shuffled = { ROWS[4], ROWS[6], ROWS[1], ROWS[3], ROWS[5], ROWS[2] }
			local list = SpinLogic.byChance(shuffled)
			expect(#list).to.equal(6)
			local total = 0
			for index, row in list do
				expect(row).to.equal(ROWS[index]) -- the catalog's weights already fall slice by slice
				total += SpinLogic.share(list, row)
			end
			expect(math.abs(total - 100) < 1e-9).to.equal(true)
			expect(shuffled[1]).to.equal(ROWS[4]) -- the input is left as it was
			local tied = {
				{ slice = 2, kind = "coins", weight = 50 },
				{ slice = 1, kind = "coins", weight = 50 },
			}
			expect(SpinLogic.byChance(tied)[1].slice).to.equal(1)
			expect(SpinLogic.share({}, ROWS[1])).to.equal(0)
		end)

		it("estimates coins as the server pays them, never under minCoins", function()
			expect(SpinLogic.coins(ROWS[1], 10)).to.equal(1200)
			expect(SpinLogic.coins(ROWS[1], 1)).to.equal(200)
			expect(SpinLogic.coins(ROWS[3], 2.5)).to.equal(1500)
			expect(SpinLogic.coins(ROWS[3], -4)).to.equal(1000)
		end)

		it("finds a slice's place on the wheel", function()
			expect(SpinLogic.indexOf(ROWS, 6)).to.equal(6)
			expect(SpinLogic.indexOf(ROWS, 0)).to.equal(nil)
		end)
	end)

	describe("SpinLogic landing", function()
		it("stops in the middle of the paid slice after the full turns, clockwise", function()
			for index = 1, 6 do
				for _, from in { 0, 37, -125, 721.5 } do
					local to = SpinLogic.landing(from, index, 6, 5)
					expect(to >= from + 5 * 360).to.equal(true)
					expect(to < from + 6 * 360).to.equal(true)
					-- the slice's middle, (index - 1) * 60 degrees round, sits under the pointer at the top
					local offset = (to + (index - 1) * 60) % 360
					expect(math.min(offset, 360 - offset) < 1e-6).to.equal(true)
					expect(SpinLogic.slotAt(to, 6)).to.equal(index)
				end
			end
		end)

		it("reads the slot under the pointer as the wheel turns", function()
			expect(SpinLogic.slotAt(0, 6)).to.equal(1)
			expect(SpinLogic.slotAt(-60, 6)).to.equal(2)
			expect(SpinLogic.slotAt(29, 6)).to.equal(1)
			expect(SpinLogic.slotAt(31, 6)).to.equal(6)
			expect(SpinLogic.slotAt(360 * 4 - 120, 6)).to.equal(3)
		end)
	end)

	describe("SpinLogic edges (QA)", function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local Catalog = require(ReplicatedStorage.Shared.Catalog)
		local Config = require(ReplicatedStorage.Shared.Config)
		local Spin = require(ReplicatedStorage.Shared.Spin)

		-- The window's spin count, Spin button and countdown come from SpinLogic and the answer
		-- from Spin, so the two agree at any second, the last one before 00:00 UTC included.
		it("agrees with the server on spins and the next free one at any time of day", function()
			for _, offset in { 0, 0.5, 1, 3600, 43200, 86399, 86399.75, DAY } do
				local now = 20000 * DAY + offset
				for _, lastFreeDay in { 0, 19998, 19999, 20000 } do
					for _, banked in { 0, 1, Config.SpinBankCap } do
						local spin = { lastFreeDay = lastFreeDay, banked = banked }
						local at = ("+%s s, last %d, banked %d: "):format(
							tostring(offset),
							lastFreeDay,
							banked
						)
						local spins = SpinLogic.spins(spin, now)
						expect(at .. spins).to.equal(at .. Spin.available(spin, now))
						expect(SpinLogic.freeDue(spin, now)).to.equal(Spin.freeDue(spin, now))
						local wait = Spin.nextFreeAt(spin, now) - now
						local gap = math.abs(SpinLogic.nextFreeIn(spin, now) - wait)
						expect(gap < 1e-6).to.equal(true)
						if spins == 0 then
							expect(SpinLogic.refusal(spin, now)).to.equal(
								"Next free spin in " .. SpinLogic.wait(wait)
							)
						end
					end
				end
			end
		end)

		-- The chance printed beside a slice is what the player is told they get, so it must be the
		-- share of rolls the server's pick lands on, and the printed chances must add up to 100%.
		it("prints each slice's true chance: the share of rolls the server lands on", function()
			local rows = Catalog.spinWheel
			local hits: { [number]: number } = {}
			local rolls = 100000
			for k = 0, rolls - 1 do
				local slice = Spin.pick(k / rolls).slice
				hits[slice] = (hits[slice] or 0) + 1
			end
			local printed = 0
			for index, row in rows do
				expect(SpinLogic.indexOf(rows, row.slice)).to.equal(index)
				local text = SpinLogic.chance(rows, row)
				local percent = tonumber(string.match(text, "^([%d%.]+)%%$")) :: number
				local share = (hits[row.slice] or 0) / rolls * 100
				expect(math.abs(share - percent) <= 0.05 + 1e-9).to.equal(true)
				printed += percent
			end
			expect(math.abs(printed - 100) < 1e-9).to.equal(true)
		end)

		it("estimates a coin slice as the server pays it, at any day rate", function()
			for _, row in Catalog.spinWheel do
				if row.kind ~= "coins" then
					continue
				end
				local floor = row.minCoins or 0
				for _, rate in { 0 / 0, -math.huge, -1, 0 } do
					expect(Spin.amount(row, rate)).to.equal(floor)
					expect(SpinLogic.coins(row, rate)).to.equal(floor)
				end
				local last = -1
				for step = 0, 400 do
					local paid = Spin.amount(row, step * 0.37)
					expect(SpinLogic.coins(row, step * 0.37)).to.equal(paid)
					expect(paid % 1 == 0 and paid >= last).to.equal(true)
					last = paid
				end
			end
		end)
	end)
end
