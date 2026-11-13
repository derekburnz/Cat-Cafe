--!strict
-- The Mystic Pool's first walk-up cutscene (#3430, Effects/MysticIntroCut; its timing in Effects/Logic): it is quick, its parts come in order, the
-- five colours only ever step forward, Sorrel's wave is slow and the controls always come back. Written by the
-- vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Traits = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Traits")
	) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Logic = require(Effects:WaitForChild("Logic")) :: any

	describe("Effects mystic intro cut", function()
		it("runs 6 to 8 seconds and gives the controls back soon after whatever happens", function()
			local p = Presets.mysticIntro
			local whole = Logic.mysticIntroSeconds()
			expect(whole >= 6).to.equal(true)
			expect(whole <= 8).to.equal(true)
			expect(p.cap > whole).to.equal(true)
			expect(p.cap <= whole + 3).to.equal(true)
			-- a skip is back at the player in a blink, and the first press of the walk-up does not count as one
			expect(p.skipOut <= 0.3).to.equal(true)
			expect(p.skipAfter > 0 and p.skipAfter <= 0.3).to.equal(true)
			-- Reduce Motion: the line alone, long enough to read
			expect(p.still >= 2).to.equal(true)
		end)

		it("plays its parts in order: in, swirl, rise, out", function()
			local p = Presets.mysticIntro
			local order = { "in", "swirl", "rise", "out", "done" }
			local at = 1
			local t = 0
			while t <= Logic.mysticIntroSeconds() + 0.5 do
				local phase, k = Logic.mysticIntroPhase(t)
				while order[at] ~= phase do
					at += 1
					expect(at <= #order).to.equal(true)
				end
				expect(k >= 0 and k <= 1).to.equal(true)
				t += 0.05
			end
			expect(order[at]).to.equal("done")
			expect((Logic.mysticIntroPhase(0))).to.equal("in")
			expect((Logic.mysticIntroPhase(p.swingIn + 0.01))).to.equal("swirl")
			expect((Logic.mysticIntroPhase(-1))).to.equal("in")
		end)

		it("steps the liquid through all six colours forward only", function()
			local p = Presets.mysticIntro
			local last = 1
			local seen = {}
			local s = 0
			while s <= p.step * p.steps + 1 do
				local i, k = Logic.mysticIntroSwirl(s)
				expect(i >= last).to.equal(true)
				expect(i - last <= 1).to.equal(true)
				expect(k >= 0 and k <= 1).to.equal(true)
				seen[i] = true
				last = i
				s += 0.02
			end
			for i = 1, p.steps do
				expect(seen[i]).to.equal(true)
			end
			expect(last).to.equal(6)
			expect(p.steps).to.equal(#Traits.RARITIES)
			-- each colour is fully in before the next starts
			expect(p.blend < p.step).to.equal(true)
			local _, settled = Logic.mysticIntroSwirl(p.step * p.steps + 1)
			expect(settled).to.equal(1)
		end)

		it("raises Sorrel's staff, then waves it slowly without dropping it", function()
			local p = Presets.mysticIntro
			expect(Logic.mysticIntroWave(0)).to.equal(0)
			expect(Logic.mysticIntroWave(-1)).to.equal(0)
			expect(math.abs(Logic.mysticIntroWave(p.raise) - 1) < 1e-6).to.equal(true)
			local low = 1
			local s = p.raise
			while s <= 3 do
				local k = Logic.mysticIntroWave(s)
				expect(k <= 1 + 1e-6).to.equal(true)
				low = math.min(low, k)
				s += 0.02
			end
			expect(low >= p.waveLow - 1e-6).to.equal(true)
			expect(low < 0.9).to.equal(true)
			-- calm: well under the 3 a second a young audience's screens stay below
			expect(p.waveHz <= 1).to.equal(true)
		end)
	end)
end
