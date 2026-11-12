--!strict
-- The Secret cats' own glow (#3544, Effects/SecretGlow): soft, slow, pale, cheap on a phone and never nothing on
-- Low performance. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Logic = require(Effects:WaitForChild("Logic")) :: any

	describe("Effects secret glow", function()
		it("is whole up close and fades out with distance", function()
			local g = Presets.secretGlow
			expect(Logic.secretGlowFade(0)).to.equal(1)
			expect(Logic.secretGlowFade(g.full)).to.equal(1)
			expect(Logic.secretGlowFade(g.within)).to.equal(0)
			expect(Logic.secretGlowFade(g.within + 50)).to.equal(0)
			local mid = Logic.secretGlowFade((g.full + g.within) / 2)
			expect(mid > 0.45 and mid < 0.55).to.equal(true)
			expect(Logic.secretGlowFade(0 / 0)).to.equal(0)
			-- seen from across a cafe (a plot is about 60 studs)
			expect(g.within >= 60).to.equal(true)
		end)

		it("breathes slowly and never goes dark or flashes", function()
			local g = Presets.secretGlow
			local lowest, highest = math.huge, 0
			for i = 0, 400 do
				local level = Logic.secretGlowLevel(0, g.breathe * i / 400, false)
				lowest = math.min(lowest, level)
				highest = math.max(highest, level)
			end
			expect(math.abs(lowest - g.low) < 0.01).to.equal(true)
			expect(math.abs(highest - 1) < 0.01).to.equal(true)
			expect(g.low >= 0.4).to.equal(true) -- a breath, not a blink
			expect(g.breathe >= 3).to.equal(true) -- far under 3 flashes a second
			-- Reduce Motion: it holds still
			expect(Logic.secretGlowLevel(0, 0, true)).to.equal(g.rest)
			expect(Logic.secretGlowLevel(0, g.breathe / 2, true)).to.equal(g.rest)
			-- it fades with distance too
			expect(Logic.secretGlowLevel(g.within, 1, false)).to.equal(0)
		end)

		it("is the Secret colour, pale, and unlike gold", function()
			local g = Presets.secretGlow
			local halo = Presets.emitters.secretHalo
			expect(g.colour).to.equal(Color3.fromRGB(226, 214, 255))
			expect(halo.colors[1]).to.equal(g.colour)
			-- pale violet: blue leads, where gold has almost none
			expect(g.colour.B > g.colour.R and g.colour.B > g.colour.G).to.equal(true)
			expect(Presets.palette.golden.B < 0.5).to.equal(true)
			-- see-through enough to sit on top of a gold or rainbow coat without hiding it
			expect(halo.transparency[1] >= 0.6).to.equal(true)
			expect(g.behind < 0).to.equal(true)
		end)

		it("stays cheap on a phone and is never nothing on Low performance", function()
			local g = Presets.secretGlow
			local halo = Presets.emitters.secretHalo
			local stars = Presets.emitters.secretStars
			-- particles on screen at once: every glowing cat's halo and stars
			local each = halo.rate * halo.lifetime[2] + stars.rate * stars.lifetime[2]
			expect(each <= 8).to.equal(true)
			expect(g.most * each <= 32).to.equal(true)
			expect(g.most <= 4).to.equal(true) -- lights lit at once
			expect(g.mostLow >= 1 and g.mostLow <= g.most).to.equal(true)
			expect(g.range <= 12).to.equal(true)
			expect(g.checkEvery >= 0.25).to.equal(true)
		end)
	end)
end
