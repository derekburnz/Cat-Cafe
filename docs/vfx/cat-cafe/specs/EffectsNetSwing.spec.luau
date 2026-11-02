--!strict
-- The net swing's effects (F93, catch-rework.md): the result word a catch earns and its burst, the rescue trap's
-- shake that grows each hit, and the whoosh trail's timing against the smack. Written by the vfx-animator for QA to
-- move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function near(a: number, b: number, within: number): boolean
		return math.abs(a - b) < within
	end

	-- the biggest tip and hop over a shake, sampled finely
	local function peak(hits: number, needed: number): (number, number)
		local o = Presets.trapShake
		local tip, hop = 0, 0
		local t = 0
		while t < o.seconds do
			local a: number, b: number = Logic.trapShake(t, hits, needed, o)
			tip = math.max(tip, math.abs(a))
			hop = math.max(hop, b)
			t += 0.001
		end
		return tip, hop
	end

	describe("Effects net swing", function()
		it("names the result word the way section 3 does", function()
			expect(Logic.catchWord({ "perfect", "perfect", "perfect" })).to.equal("purrfect")
			expect(Logic.catchWord({ "perfect", "perfect", "perfect", "good" })).to.equal(
				"excellent"
			)
			expect(Logic.catchWord({ "perfect", "good", "perfect", "good" })).to.equal("excellent") -- half
			expect(Logic.catchWord({ "perfect", "good", "good" })).to.equal("great")
			expect(Logic.catchWord({ "good", "good", "good", "good", "good" })).to.equal("great")
			expect(Logic.catchWord({ "perfect", "perfect", "miss" }) == nil).to.equal(true)
			expect(Logic.catchWord({ "miss" }) == nil).to.equal(true)
			expect(Logic.catchWord({}) == nil).to.equal(true)
			-- the old numeric grades: 1 Perfect, 0 Miss
			expect(Logic.catchWord({ 1, 1 })).to.equal("purrfect")
			expect(Logic.catchWord({ 1, 0.5 })).to.equal("excellent")
			expect(Logic.catchWord({ 1, 0 }) == nil).to.equal(true)
		end)

		it("spreads the word's sparkles evenly across it", function()
			local centre = Vector2.new(400, 60)
			local spots = Logic.wordSpots(centre, 200, 4)
			expect(#spots).to.equal(4)
			expect(near(spots[1].X, 325, 1e-6)).to.equal(true)
			expect(near(spots[4].X, 475, 1e-6)).to.equal(true)
			local sum = 0
			for _, spot in spots do
				expect(spot.Y).to.equal(60)
				expect(spot.X > 300 and spot.X < 500).to.equal(true)
				sum += spot.X
			end
			expect(near(sum / 4, 400, 1e-6)).to.equal(true)
			local one = Logic.wordSpots(centre, 200, 1)
			expect(near(one[1].X, 400, 1e-6)).to.equal(true)
			expect(#Logic.wordSpots(centre, 200, 0)).to.equal(0)
		end)

		it("gives the biggest word the biggest burst, in the word's colour", function()
			local w = Presets.catchWord.words
			expect(w.purrfect.sparkles > w.excellent.sparkles).to.equal(true)
			expect(w.excellent.sparkles > w.great.sparkles).to.equal(true)
			expect(w.purrfect.rings > w.great.rings).to.equal(true)
			expect(w.purrfect.colour).to.equal(Presets.palette.golden)
			expect(w.excellent.colour).to.equal(Presets.palette.golden)
			expect(w.great.colour).to.equal(Presets.palette.mint)
			-- over the catch screen (25), under the toasts (30)
			local order = Presets.catchWord.displayOrder
			expect(order > 25 and order < 30).to.equal(true)
		end)

		it("shakes the trap a little more each hit and settles after", function()
			local o = Presets.trapShake
			local before = 0
			for hits = 1, 5 do
				local tip, hop = peak(hits, 5)
				expect(tip > before).to.equal(true)
				expect(tip <= o.most + 1e-9).to.equal(true)
				expect(hop >= 0 and hop <= o.hop + 1e-9).to.equal(true)
				before = tip
			end
			local first = peak(1, 5)
			expect(first <= o.least + 1e-9).to.equal(true)
			expect(first > o.least * 0.8).to.equal(true)
			-- a one hit rescue shakes the most
			local only = peak(1, 1)
			expect(only > o.most * 0.8).to.equal(true)
			local a: number, b: number = Logic.trapShake(o.seconds, 3, 5, o)
			expect(a).to.equal(0)
			expect(b).to.equal(0)
			local c: number, d: number = Logic.trapShake(-0.1, 3, 5, o)
			expect(c).to.equal(0)
			expect(d).to.equal(0)
			local e: number = Logic.trapShake(0, 3, 5, o)
			expect(e).to.equal(0) -- it starts from standing still
			expect(o.most <= 8).to.equal(true) -- a shake, not a tumble
		end)

		it("draws the whoosh over the downswing, ending by the time the smack does", function()
			local trail = Presets.netTrail
			local smack = Presets.netSmack
			expect(trail.from < smack.land).to.equal(true)
			expect(trail.to > smack.land).to.equal(true)
			expect(trail.to + trail.lifetime <= smack.ends).to.equal(true)
			expect(trail.inner > 0 and trail.inner < 1).to.equal(true)
			local b = Presets.budget
			expect(b.lowPerformance.netTrails <= b.low.netTrails).to.equal(true)
			expect(b.low.netTrails <= b.high.netTrails).to.equal(true)
		end)
	end)
end
