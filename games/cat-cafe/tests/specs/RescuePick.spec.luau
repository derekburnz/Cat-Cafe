--!strict
-- RescuePick.luau (#2240): each sunrise an area's traps are picked from its pool of spots, keeping today's mix of trap
-- types, away from yesterday's spots where the pool allows and at least the spacing apart where it can.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local RescuePick = require(Shared.RescuePick)

	local function spot(id: string, trap: string, x: number, z: number): RescuePick.Candidate
		return { id = id, trap = trap, position = Vector3.new(x, 0, z) }
	end

	-- A Park-like pool: 9 trees and 6 trashcans, 30 studs apart on a line.
	local function parkPool(): { RescuePick.Candidate }
		local pool = {}
		for i = 1, 15 do
			table.insert(
				pool,
				spot(string.format("p%02d", i), if i <= 9 then "tree" else "trashcan", i * 30, 0)
			)
		end
		return pool
	end

	local function seeded(seed: number): (number) -> number
		local rng = Random.new(seed)
		return function(n: number): number
			return rng:NextInteger(1, n)
		end
	end

	local function trapsOf(pool: { RescuePick.Candidate }, ids: { string }): { [string]: number }
		local byId: { [string]: string } = {}
		for _, s in pool do
			byId[s.id] = s.trap
		end
		local out: { [string]: number } = {}
		for _, id in ids do
			out[byId[id]] = (out[byId[id]] or 0) + 1
		end
		return out
	end

	describe("RescuePick (#2240)", function()
		it("the spacing is 25 studs", function()
			expect(Config.RescueSpotSpacingStuds).to.equal(25)
		end)

		it("mix counts each trap type", function()
			expect(RescuePick.mix({ "tree", "tree", "tree", "trashcan", "trashcan" })).to.deepEqual({
				tree = 3,
				trashcan = 2,
			})
		end)

		it("keeps the area's mix and returns sorted, distinct ids", function()
			local pool = parkPool()
			for seed = 1, 50 do
				local ids = RescuePick.pick(pool, { tree = 3, trashcan = 2 }, {}, 25, seeded(seed))
				expect(#ids).to.equal(5)
				expect(trapsOf(pool, ids)).to.deepEqual({ tree = 3, trashcan = 2 })
				local seen: { [string]: boolean } = {}
				for i, id in ids do
					expect(seen[id]).to.equal(nil)
					seen[id] = true
					if i > 1 then
						expect(ids[i - 1] < id).to.equal(true)
					end
				end
			end
		end)

		it("never repeats yesterday's spots while the pool has others of that type", function()
			local pool = parkPool()
			local rand = seeded(7)
			local yesterday: { [string]: boolean } = {}
			for _ = 1, 30 do
				local ids = RescuePick.pick(pool, { tree = 3, trashcan = 2 }, yesterday, 25, rand)
				local today: { [string]: boolean } = {}
				for _, id in ids do
					expect(yesterday[id]).to.equal(nil)
					today[id] = true
				end
				yesterday = today
			end
		end)

		it(
			"takes yesterday's spots when a type has no others (the Woods' one tree house branch)",
			function()
				local pool = {
					spot("branch", "tree", 0, 0),
					spot("log1", "log", 40, 0),
					spot("log2", "log", 80, 0),
				}
				local ids = RescuePick.pick(
					pool,
					{ tree = 1, log = 1 },
					{ branch = true },
					25,
					seeded(3)
				)
				expect(trapsOf(pool, ids)).to.deepEqual({ tree = 1, log = 1 })
				expect(table.find(ids, "branch") ~= nil).to.equal(true)
			end
		)

		it("without a pool (pool = the mix) every spot is picked, as before #2240", function()
			local pool = {
				spot("a", "tree", 0, 0),
				spot("b", "tree", 40, 0),
				spot("c", "trashcan", 80, 0),
			}
			local all = { "a", "b", "c" }
			expect(RescuePick.pick(pool, { tree = 2, trashcan = 1 }, {}, 25, seeded(1))).to.deepEqual(
				all
			)
			expect(
				RescuePick.pick(
					pool,
					{ tree = 2, trashcan = 1 },
					{ a = true, b = true, c = true },
					25,
					seeded(2)
				)
			).to.deepEqual(all)
		end)

		it("keeps picks the spacing apart where the pool allows", function()
			-- pairs 10 studs apart, the pairs 100 apart: two picks must come from different pairs
			local pool = {
				spot("a1", "tree", 0, 0),
				spot("a2", "tree", 10, 0),
				spot("b1", "tree", 100, 0),
				spot("b2", "tree", 110, 0),
			}
			for seed = 1, 40 do
				local ids = RescuePick.pick(pool, { tree = 2 }, {}, 25, seeded(seed))
				expect(#ids).to.equal(2)
				expect(string.sub(ids[1], 1, 1) ~= string.sub(ids[2], 1, 1)).to.equal(true)
			end
		end)

		it("fills the mix anyway when the spacing cannot be kept", function()
			local pool =
				{ spot("a", "tree", 0, 0), spot("b", "tree", 5, 0), spot("c", "tree", 10, 0) }
			expect(#RescuePick.pick(pool, { tree = 3 }, {}, 25, seeded(1))).to.equal(3)
		end)

		it(
			"ignores pool spots of a type the mix does not use and asks for no more than the pool has",
			function()
				local pool = { spot("a", "tree", 0, 0), spot("g", "grate", 50, 0) }
				expect(RescuePick.pick(pool, { tree = 2 }, {}, 25, seeded(1))).to.deepEqual({ "a" })
			end
		)

		it("spreads over the whole pool across days", function()
			local pool = parkPool()
			local rand = seeded(11)
			local used: { [string]: boolean } = {}
			local yesterday: { [string]: boolean } = {}
			for _ = 1, 20 do
				local today: { [string]: boolean } = {}
				for _, id in RescuePick.pick(pool, { tree = 3, trashcan = 2 }, yesterday, 25, rand) do
					used[id] = true
					today[id] = true
				end
				yesterday = today
			end
			local n = 0
			for _ in used do
				n += 1
			end
			expect(n).to.equal(15)
		end)
	end)
end
