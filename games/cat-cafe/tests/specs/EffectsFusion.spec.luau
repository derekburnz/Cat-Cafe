--!strict
-- #4104 the Cat Fusion Observatory's effects (Effects/FusionFx): the swirl of five tiles into one, the Collect burst
-- and the dome's paw lights. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local FusionFx = require(Effects:WaitForChild("FusionFx")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Fusion Observatory", function()
		it("starts each tile at its own place and ends them all at the centre, small", function()
			local p = Presets.fusion.swirl
			for i = 1, p.most do
				local out, turn, scale = FusionFx.swirlAt(i, 0)
				expect(out).to.equal(1)
				expect(turn).to.equal(0)
				expect(scale).to.equal(1)
				out, turn, scale = FusionFx.swirlAt(i, FusionFx.swirlSeconds(p.most))
				expect(math.abs(out) < 1e-6).to.equal(true)
				expect(math.abs(scale - p.land) < 1e-6).to.equal(true)
				expect(math.abs(turn - p.turns * 2 * math.pi) < 1e-6).to.equal(true)
			end
		end)

		it("sends the tiles in one after another, never back out, in under two seconds", function()
			local p = Presets.fusion.swirl
			local whole = FusionFx.swirlSeconds(p.most)
			expect(whole <= 2).to.equal(true)
			local mid = whole / 2
			local last = -1
			for i = 1, p.most do
				local out = FusionFx.swirlAt(i, mid)
				expect(out >= last).to.equal(true) -- a later tile is further out
				last = out
			end
			for i = 1, p.most do
				local before = 2
				for step = 0, 40 do
					local out = FusionFx.swirlAt(i, whole * step / 40)
					expect(out <= before + 1e-9).to.equal(true)
					before = out
				end
			end
			-- a gentle turn, never a spin
			expect(p.turns <= 1).to.equal(true)
		end)

		it("shows gold steady and the rainbow drifting slowly round its hues", function()
			local p = Presets.fusion
			expect(FusionFx.coatColour("gold", 0)).to.equal(p.gold)
			expect(FusionFx.coatColour("gold", 4.2)).to.equal(p.gold)
			expect(FusionFx.coatColour(nil, 1)).to.equal(p.gold)
			local hues = Presets.rainbow.hues
			expect(FusionFx.coatColour("rainbow", 0)).to.equal(hues[1])
			expect(FusionFx.coatColour("rainbow", p.huePeriod)).to.equal(hues[1])
			local second = FusionFx.coatColour("rainbow", p.huePeriod / #hues)
			expect(math.abs(second.R - hues[2].R) < 1e-4).to.equal(true)
			-- each hue stays a second: far under 3 changes a second
			expect(p.huePeriod / #hues >= 1).to.equal(true)
		end)

		it("makes the rainbow burst the bigger one and keeps rings a second apart", function()
			local b = Presets.fusion.burst
			local gold, rainbow = b.kinds.gold, b.kinds.rainbow
			expect(rainbow.sparkles > gold.sparkles).to.equal(true)
			expect(rainbow.rings > gold.rings).to.equal(true)
			expect(rainbow.ringSeconds >= gold.ringSeconds).to.equal(true)
			expect(b.ringGap >= 1).to.equal(true)
			expect(rainbow.rings <= 3).to.equal(true)
			expect(rainbow.sparkles <= 24).to.equal(true)
		end)

		it("circles five paw lights evenly and slowly, breathing only when ready", function()
			local d = Presets.fusion.dome
			expect(d.paws).to.equal(5)
			local sum = Vector3.new(0, 0, 0)
			for i = 1, d.paws do
				local at = FusionFx.pawAt(i, d.paws, 1.7, 6, d.lap)
				expect(math.abs(at.Magnitude - 6) < 1e-6).to.equal(true)
				expect(at.Y).to.equal(0)
				sum += at
			end
			expect(sum.Magnitude < 1e-6).to.equal(true)
			local a = FusionFx.pawAt(1, d.paws, 0, 6, d.lap)
			local b = FusionFx.pawAt(1, d.paws, d.lap, 6, d.lap)
			expect((a - b).Magnitude < 1e-6).to.equal(true)
			expect(d.lapReady >= 4 and d.lapReady < d.lap).to.equal(true)
			expect(FusionFx.slitGlow(false, 0.7)).to.equal(1)
			expect(FusionFx.slitGlow(true, 0)).to.equal(1)
			expect(
				math.abs(FusionFx.slitGlow(true, d.breathSeconds / 2) - (1 - d.breathDip)) < 1e-6
			).to.equal(true)
			expect(d.breathSeconds >= 1).to.equal(true)
		end)
	end)
end
