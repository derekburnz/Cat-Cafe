--!strict
-- Rainbow coats (F99, rainbow-coat.md section 2): the six hues and how they blend, bands flowing from nose to tail
-- every 3 seconds, stripes still showing, the face details kept, a rainbow cat of any rarity getting the big pull,
-- and the numbers the spec names. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function close(a: number, b: number): boolean
		return math.abs(a - b) < 1e-6
	end

	local function same(a: Color3, b: Color3): boolean
		return close(a.R, b.R) and close(a.G, b.G) and close(a.B, b.B)
	end

	describe("Effects rainbow coat", function()
		it("runs round six hues, blending each into the next and wrapping", function()
			local hues = Presets.rainbow.hues
			expect(#hues).to.equal(6)
			for i = 1, 6 do
				expect(same(Logic.rainbowAt(hues, (i - 1) / 6), hues[i])).to.equal(true)
			end
			expect(same(Logic.rainbowAt(hues, 1), hues[1])).to.equal(true)
			expect(same(Logic.rainbowAt(hues, -1 / 6), hues[6])).to.equal(true)
			local half = Logic.rainbowAt(hues, 1 / 12)
			expect(same(half, hues[1]:Lerp(hues[2], 0.5))).to.equal(true)
		end)

		it("measures each part from the nose to the tail tip", function()
			expect(Logic.rainbowPhase(-0.95, -0.95, 0.85)).to.equal(0)
			expect(Logic.rainbowPhase(0.85, -0.95, 0.85)).to.equal(1)
			expect(close(Logic.rainbowPhase(-0.05, -0.95, 0.85), 0.5)).to.equal(true)
			expect(Logic.rainbowPhase(2, -0.95, 0.85)).to.equal(1)
			expect(Logic.rainbowPhase(0, 0, 0)).to.equal(0)
		end)

		it("flows the bands from nose to tail, one lap every 3 seconds", function()
			local r = Presets.rainbow
			expect(r.period).to.equal(3)
			-- the colour at the nose now is a little further back a moment later
			local now = Logic.rainbowHue(10, 0, r.period, r.spread)
			local later = Logic.rainbowHue(10.3, 0.1 * r.spread, r.period, r.spread)
			expect(close(now % 1, later % 1)).to.equal(true)
			local lap = Logic.rainbowHue(13, 0.4, r.period, r.spread)
				- Logic.rainbowHue(10, 0.4, r.period, r.spread)
			expect(close(lap, -1)).to.equal(true)
			expect(Logic.rainbowHue(5, 0.4, 0, 1)).to.equal(0.4) -- still bands
		end)

		it("keeps stripes and patches darker, but never dull", function()
			local least = Presets.rainbow.least
			expect(Logic.rainbowShade(0.8, 0.8, least)).to.equal(1)
			expect(close(Logic.rainbowShade(0, 0.8, least), least)).to.equal(true)
			local stripe = Logic.rainbowShade(0.45, 0.8, least)
			expect(stripe > least and stripe < 1).to.equal(true)
			expect(least >= 0.6).to.equal(true)
			expect(close(Logic.lightness(Color3.new(1, 1, 1)), 1)).to.equal(true)
		end)

		it("leaves the nose, mouth and blush alone and colours the muzzle and stripes", function()
			local share = Presets.rainbow.keepShare
			-- the Tabby's head: the head box is 1.0 long, the nose 0.115, a mouth stroke 0.079, the blush 0.138
			expect(Logic.rainbowKeeps(0.115, 1.0, share)).to.equal(true)
			expect(Logic.rainbowKeeps(0.079, 1.0, share)).to.equal(true)
			expect(Logic.rainbowKeeps(0.138, 1.0, share)).to.equal(true)
			expect(Logic.rainbowKeeps(0.414, 1.0, share)).to.equal(false) -- the muzzle
			expect(Logic.rainbowKeeps(0.544, 1.0, share)).to.equal(false) -- a crown stripe
			expect(Logic.rainbowKeeps(1.0, 1.0, share)).to.equal(false)
		end)

		it("gives a rainbow cat of any rarity the big pull", function()
			expect(Logic.bigPull("Common", false, true)).to.equal(true)
			expect(Logic.bigPull("Rare", false, true)).to.equal(true)
			expect(Logic.bigPull("Common", false, false)).to.equal(false)
			expect(Logic.bigPull("Common", false)).to.equal(false)
			expect(Logic.bigPull(nil, false, true)).to.equal(false)
		end)

		it("matches the spec's glow and caps the flowing cats", function()
			local r = Presets.rainbow
			expect(r.glow.range).to.equal(6)
			expect(r.glow.brightness).to.equal(0.6)
			expect(r.within).to.equal(120)
			expect(r.beam.seconds).to.equal(3)
			local b = Presets.budget
			expect(b.high.rainbowCats <= 10).to.equal(true)
			expect(b.low.rainbowCats <= b.high.rainbowCats).to.equal(true)
			expect(b.lowPerformance.rainbowCats <= b.low.rainbowCats).to.equal(true)
			expect(b.high.rainbowOutlines <= b.high.rainbowCats).to.equal(true)
			expect(b.lowPerformance.rainbowOutlines).to.equal(0)
			expect(Presets.emitters.rainbowTrail ~= nil).to.equal(true)
		end)
	end)
end
