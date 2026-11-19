--!strict
-- shared/Advent.luau: the advent calendar's locks, order and catch-ups (#5502). The four lock tests the spec asks for
-- (advent-calendar-spec section 1) are the first four.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Advent = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Advent")) :: any

	local DAY = 86400
	local function fresh()
		return Advent.fresh(nil)
	end

	describe("Advent locks", function()
		it("opens nothing before Dec 1 20:00 UTC, with both switches on", function()
			local times = {
				0,
				1763510400,
				Advent.FIRST_OPEN - 30 * DAY,
				Advent.FIRST_OPEN - 3600,
				Advent.FIRST_OPEN - 1,
			}
			for _, now in times do
				expect(Advent.due(now)).to.equal(0)
				expect(Advent.live(true, true, now)).to.equal(false)
				local door, _, reason = Advent.check(fresh(), now, true, true)
				expect(door).to.equal(nil)
				expect(reason).to.equal("not_yet")
				expect(Advent.view(fresh(), now, true, true).ready).to.equal(false)
			end
			expect(Advent.check(fresh(), Advent.FIRST_OPEN, true, true)).to.equal(1)
		end)

		it("opens nothing at any time with either switch off", function()
			local now = Advent.FIRST_OPEN - 2 * DAY
			while now < Advent.CLOSES + 2 * DAY do
				for _, pair in { { false, true }, { true, false }, { false, false } } do
					local door, _, reason = Advent.check(fresh(), now, pair[1], pair[2])
					expect(door).to.equal(nil)
					expect(reason).to.equal("off")
					expect(Advent.live(pair[1], pair[2], now)).to.equal(false)
					local view = Advent.view(fresh(), now, pair[1], pair[2])
					expect(view.ready).to.equal(false)
					expect(view.due).to.equal(0)
				end
				now += 6 * 3600
			end
		end)

		it("never opens door N before its date", function()
			for n = 1, Advent.DOORS do
				local at = Advent.doorAt(n)
				expect(Advent.due(at - 1) < n).to.equal(true)
				expect(Advent.due(at) >= n).to.equal(true)
				-- a save with every earlier door opened still waits for door n's date
				local state = { year = Advent.YEAR, opened = n - 1, day = 0, caught = 0 }
				expect(Advent.check(state, at - 1, true, true)).to.equal(nil)
				expect(Advent.check(state, at, true, true)).to.equal(n)
			end
			expect(Advent.doorAt(2)).to.equal(Advent.DEC_2)
			expect(Advent.doorAt(24)).to.equal(Advent.DEC_2 + 22 * DAY)
		end)

		it("opens nothing from Jan 4 2027 00:00 UTC", function()
			expect(Advent.due(Advent.CLOSES - 1)).to.equal(24)
			for _, now in { Advent.CLOSES, Advent.CLOSES + 1, Advent.CLOSES + 400 * DAY } do
				expect(Advent.due(now)).to.equal(0)
				local door, _, reason = Advent.check(fresh(), now, true, true)
				expect(door).to.equal(nil)
				expect(reason).to.equal("closed")
				expect(Advent.live(true, true, now)).to.equal(false)
			end
		end)
	end)

	describe("Advent order and catch-ups", function()
		it("opens today's door on time, once, then waits for tomorrow", function()
			local state = fresh()
			local now = Advent.FIRST_OPEN + 60
			local door, kind = Advent.check(state, now, true, true)
			expect(door).to.equal(1)
			expect(kind).to.equal("on_time")
			Advent.mark(state, door, kind, now)
			local next, _, reason = Advent.check(state, now + 60, true, true)
			expect(next).to.equal(nil)
			expect(reason).to.equal("tomorrow")
			expect(Advent.check(state, Advent.DEC_2, true, true)).to.equal(2)
		end)

		it("lets a Dec 20 start open all 24 by Jan 3, in order", function()
			local state = fresh()
			local day = Advent.doorAt(20) + 3600
			local last = 0
			while day < Advent.CLOSES do
				while true do
					local door, kind = Advent.check(state, day, true, true)
					if door == nil then
						break
					end
					expect(door).to.equal(last + 1)
					last = door
					Advent.mark(state, door, kind, day)
				end
				day += DAY
			end
			expect(state.opened).to.equal(24)
			local _, _, reason = Advent.check(state, Advent.CLOSES - 60, true, true)
			expect(reason).to.equal("done")
		end)

		it("limits catch-ups to two a UTC day", function()
			local state = fresh()
			local now = Advent.doorAt(10) + 60
			for n = 1, 2 do
				local door, kind = Advent.check(state, now, true, true)
				expect(door).to.equal(n)
				expect(kind).to.equal("catch_up")
				Advent.mark(state, door, kind, now)
			end
			expect(Advent.check(state, now + 60, true, true)).to.equal(nil)
			expect(Advent.check(state, now + DAY, true, true)).to.equal(3)
		end)
	end)

	describe("Advent saves and doors", function()
		it("starts fresh on junk or another year and keeps a good save", function()
			expect(Advent.fresh(nil).opened).to.equal(0)
			expect(Advent.fresh({ year = 2025, opened = 20 }).opened).to.equal(0)
			expect(Advent.fresh({ year = 2026, opened = 99, day = 1, caught = 1 }).opened).to.equal(
				24
			)
			expect(Advent.fresh({ year = 2026, opened = 5.7, day = 3, caught = 1 }).opened).to.equal(
				5
			)
			expect(Advent.sanitize("x")).to.equal(nil)
		end)

		it(
			"puts the four cats behind doors 6, 12, 18 and 24 and a prize behind the rest",
			function()
				local cats = {
					[6] = "peppermint_swirl",
					[12] = "nutcracker",
					[18] = "northern_lights",
					[24] = "silent_night",
				}
				for n = 1, Advent.DOORS do
					local door = Advent.door(n)
					expect(door.n).to.equal(n)
					expect(door.cat).to.equal(cats[n])
					expect(door.cat ~= nil or door.prize ~= nil).to.equal(true)
				end
				for _, id in cats do
					expect(Advent.isCat(id)).to.equal(true)
				end
			end
		)

		it(
			"gives calendar cats that are exclusive, Secret, never rolled and kept out of the Dragon Keep",
			function()
				local Catalog = require(ReplicatedStorage.Shared.Catalog) :: any
				local DragonKeep = require(ReplicatedStorage.Shared.DragonKeep) :: any
				for id in Advent.CATS do
					local def = Catalog.getCat(id)
					expect(def).to.be.ok()
					expect(def.exclusive).to.equal(true)
					expect(def.source).to.equal("advent")
					expect(def.rarity).to.equal("Secret")
					expect(DragonKeep.eventCat(id)).to.equal(true)
					for _, secret in Catalog.secretCats do
						expect(secret.id ~= id).to.equal(true)
					end
				end
			end
		)
	end)
end
