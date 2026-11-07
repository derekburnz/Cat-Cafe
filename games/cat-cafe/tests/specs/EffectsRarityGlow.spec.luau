--!strict
-- The rarity gem's glow (#2231, Derek2 2026-11-07: "make the gems that show raritys glow and be more obvious"): a
-- bigger gem in a halo of its colour that is stronger the rarer the cat, a pulse for Epic and up that is quicker and
-- wider the rarer, and glints for Legendary and Mythical. The look on screen is a Studio row.
-- Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local r = Presets.rarityMark
	local order = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

	describe("rarity gem glow", function()
		it(
			"fades a halo ring to clear at strength 0 and to its own transparency at full strength",
			function()
				expect(Logic.haloTransparency(0.6, 0)).to.equal(1)
				expect(math.abs(Logic.haloTransparency(0.6, 1) - 0.6) < 1e-9).to.equal(true)
				expect(math.abs(Logic.haloTransparency(0.6, 0.5) - 0.8) < 1e-9).to.equal(true)
				expect(Logic.haloTransparency(0.6, 2)).to.equal(Logic.haloTransparency(0.6, 1))
			end
		)
		it("glows stronger the rarer the cat, every rarity a little", function()
			for i = 2, #order do
				expect(r.halo[order[i]] > r.halo[order[i - 1]]).to.equal(true)
			end
			expect(r.halo.Common > 0).to.equal(true)
			expect(r.halo.Mythical).to.equal(1)
		end)
		it("pulses Epic and up, quicker and wider the rarer, and not Common or Rare", function()
			expect(r.pulse.Common).to.equal(nil)
			expect(r.pulse.Rare).to.equal(nil)
			expect(r.pulse.Legendary.seconds < r.pulse.Epic.seconds).to.equal(true)
			expect(r.pulse.Mythical.seconds < r.pulse.Legendary.seconds).to.equal(true)
			expect(r.pulse.Legendary.grow > r.pulse.Epic.grow).to.equal(true)
			expect(r.pulse.Mythical.grow > r.pulse.Legendary.grow).to.equal(true)
			-- the breathing halo stays inside its billboard
			expect(r.haloRest * r.pulse.Mythical.grow <= 1.11).to.equal(true)
		end)
		it("glints Legendary and Mythical, Mythical the most often", function()
			expect(r.glints.Legendary).to.equal(true)
			expect(r.glints.Mythical).to.equal(true)
			expect(r.glints.Epic).to.equal(nil)
			expect(r.glintEvery.Mythical < r.glintEvery.Legendary).to.equal(true)
		end)
		it(
			"is a bigger gem than before (0.8 studs and 16 px at 0.62) and keeps the 12-gem budget",
			function()
				expect(r.size * r.gem > 0.8 * 0.62).to.equal(true)
				expect(r.pixels * r.gem > 16 * 0.62).to.equal(true)
				expect(r.most).to.equal(12)
			end
		)
	end)
end
