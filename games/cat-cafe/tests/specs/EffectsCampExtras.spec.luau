--!strict
-- The camp extras' rod and lid (F100, camp-extras.md sections 2 and 3: golden fish "landed with a little rod
-- animation", "the box's lid rattling when a prize waits"). Logic.keyed, keyedSeconds, lidRattle, hangs and campHeld
-- are pure; the rod and lid turning in the camps (CampExtras.luau on Model-Agent's #750 models with Gameplay-Engineer's
-- F100 moments) is a Studio row (effects-list "Camp extras rod and lid").
-- Written by the Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local c = Presets.campExtras
	local FRAME = 1 / 60

	-- the turn in degrees every frame from 0 to a little past the end
	local function sample(keys: { { number } }): { number }
		local out: { number } = {}
		for t = 0, Logic.keyedSeconds(keys) + 0.1, FRAME do
			local turn: number = Logic.keyed(keys, t)
			table.insert(out, turn)
		end
		return out
	end

	describe("Effects camp extras", function()
		it("eases between keys and holds the first and last", function()
			local keys = { { 0.5, 10 }, { 1.5, 30 }, { 2, 30 } }
			expect(Logic.keyed(keys, 0)).to.equal(10)
			expect(Logic.keyed(keys, 0.5)).to.equal(10)
			expect(Logic.keyed(keys, 1)).to.be.near(20, 1e-9)
			expect(Logic.keyed(keys, 1.5)).to.equal(30)
			expect(Logic.keyed(keys, 9)).to.equal(30)
			expect(Logic.keyedSeconds(keys)).to.equal(2)
			expect(Logic.keyed({}, 1)).to.equal(0)
			expect(Logic.keyedSeconds({})).to.equal(0)
			-- eased: a quarter of the way in time is less than a quarter of the way in value
			expect(Logic.keyed(keys, 0.75) < 15).to.equal(true)
		end)

		it("lands the fish: lifts the tip, casts back past rest into the water and comes to rest", function()
			local turns = sample(c.rod.keys)
			expect(turns[1]).to.equal(0)
			expect(turns[#turns]).to.equal(0)
			local lowest, at = 0, 1
			for i, turn in turns do
				if turn < lowest then
					lowest, at = turn, i
				end
			end
			expect(lowest <= -30).to.equal(true) -- the tip lifted high
			expect(at * FRAME < 1).to.equal(true) -- early, before the cast
			-- after the lift the swing back down crosses rest into the water: the rodCast beat sounds once
			local plops = 0
			for i = at + 1, #turns do
				if turns[i - 1] < 0 and turns[i] >= 0 then
					plops += 1
				end
			end
			expect(plops >= 1).to.equal(true)
			local firstPlop = 0
			for i = at + 1, #turns do
				if turns[i - 1] < 0 and turns[i] >= 0 then
					firstPlop = i
					break
				end
			end
			local deepest = 0
			for i = firstPlop, #turns do
				deepest = math.max(deepest, turns[i])
			end
			expect(deepest > 0 and deepest <= 10).to.equal(true) -- past rest, a small dip
		end)

		it("moves the rod and the lid with no jumps at 60 frames a second", function()
			for _, keys in { c.rod.keys, c.lid.pop } do
				local turns = sample(keys)
				for i = 2, #turns do
					expect(math.abs(turns[i] - turns[i - 1]) < 4).to.equal(true)
				end
			end
			local last = 0
			for t = 0, c.lid.rattle.seconds + 0.05, FRAME do
				local turn = math.deg(Logic.lidRattle(t))
				expect(math.abs(turn - last) < 3).to.equal(true)
				last = turn
			end
		end)

		it("rattles the lid in quick lifts, each smaller, never into the box", function()
			local r = c.lid.rattle
			expect(Logic.lidRattle(-0.1)).to.equal(0)
			expect(Logic.lidRattle(0)).to.equal(0)
			expect(Logic.lidRattle(r.seconds)).to.equal(0)
			expect(Logic.lidRattle(r.seconds + 1)).to.equal(0)
			local peaks: { number } = {}
			local before, now = 0, 0
			for t = 0, r.seconds, 0.001 do
				local turn = Logic.lidRattle(t)
				expect(turn >= 0).to.equal(true)
				expect(turn <= math.rad(r.degrees) + 1e-9).to.equal(true)
				if now > before and now > turn then
					table.insert(peaks, now)
				end
				before, now = now, turn
			end
			expect(#peaks).to.equal(r.knocks)
			for i = 2, #peaks do
				expect(peaks[i] < peaks[i - 1]).to.equal(true)
			end
			-- the lid lets the prize out: up, never into the box, shut again at the end
			local pop = sample(c.lid.pop)
			local most = 0
			for _, turn in pop do
				expect(turn >= 0).to.equal(true)
				most = math.max(most, turn)
			end
			expect(most >= 20).to.equal(true)
			expect(pop[#pop]).to.equal(0)
		end)

		it("hangs the line and bobber from the tip and turns the rest of the rod", function()
			-- #750's rod parts in its pivot's space (the butt in the holder, no turn)
			local function part(x: number, y: number, z: number, up: any): any
				return { Position = Vector3.new(x, y, z), UpVector = up }
			end
			local tilted = Vector3.new(0, 0.6428, 0.766)
			local beyond = c.rod.hangBeyond
			expect(Logic.hangs(part(0, 0.8356, 0.9959, tilted), beyond)).to.equal(false) -- the rod
			expect(Logic.hangs(part(0, 0.1511, 0.18, tilted), beyond)).to.equal(false) -- the handle
			expect(Logic.hangs(part(0.08, 0.3857, 0.4596, Vector3.new(0, -1, 0)), beyond)).to.equal(false) -- the reel
			expect(Logic.hangs(part(0, 0.4856, 1.9917, Vector3.new(0, 1, 0)), beyond)).to.equal(true) -- the line
			expect(Logic.hangs(part(0, -0.7, 1.9917, Vector3.new(0, 1, 0)), beyond)).to.equal(true) -- the bobber
		end)

		it("reads the Lost and Found's waiting prizes from the camp extras state", function()
			expect(Logic.campHeld({ lostFound = { held = 2, nextAt = 100 } }, "lostFound")).to.equal(2)
			expect(Logic.campHeld({ lostFound = 3 }, "lostFound")).to.equal(3)
			expect(Logic.campHeld({ lostFound = { held = 0 } }, "lostFound")).to.equal(0)
			expect(Logic.campHeld({ pond = { held = 5 } }, "lostFound")).to.equal(0)
			expect(Logic.campHeld({ lostFound = { held = -1 } }, "lostFound")).to.equal(0)
			expect(Logic.campHeld({ lostFound = { held = "2" } }, "lostFound")).to.equal(0)
			expect(Logic.campHeld({ lostFound = { held = 0 / 0 } }, "lostFound")).to.equal(0)
			expect(Logic.campHeld(nil, "lostFound")).to.equal(0)
			expect(Logic.campHeld("full", "lostFound")).to.equal(0)
		end)
	end)

	describe("Logic.bellWobble (#1732)", function()
		it("rings the desk bell side to side, dying away, and rests before and after", function()
			local r = c.bell.ring
			expect(Logic.bellWobble(-0.1)).to.equal(0)
			expect(Logic.bellWobble(0)).to.equal(0)
			expect(Logic.bellWobble(r.seconds)).to.equal(0)
			expect(Logic.bellWobble(r.seconds + 1)).to.equal(0)
			local left, right = false, false
			local last = 0
			for t = 0, r.seconds + 0.05, FRAME do
				local turn = Logic.bellWobble(t)
				expect(math.abs(turn) <= math.rad(r.degrees) + 1e-9).to.equal(true)
				expect(math.abs(math.deg(turn - last)) < 4).to.equal(true) -- no jump between frames
				left = left or turn < -0.01
				right = right or turn > 0.01
				last = turn
			end
			expect(left and right).to.equal(true)
			-- the first tip is bigger than one near the end
			local early = math.abs(Logic.bellWobble(r.seconds / (4 * r.wobbles)))
			local late = math.abs(Logic.bellWobble(r.seconds * (1 - 1 / (4 * r.wobbles))))
			expect(early > late).to.equal(true)
		end)
	end)
end
