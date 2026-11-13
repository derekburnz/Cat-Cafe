--!strict
-- Secret cats (#3470 section 5): the catch pop sits one step above a Mythical's, a Secret glows in starlight because
-- its swatch is too dark to, and the stray's sky beam stays a thin line from any distance and fades up close.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Secret cats", function()
		it("pops a Secret catch a step above a Mythical's", function()
			local ring, confetti, beam = Logic.catchPop("Secret")
			local mythicalRing, mythicalConfetti = Logic.catchPop("Mythical")
			expect(ring > mythicalRing).to.equal(true)
			expect(confetti >= mythicalConfetti).to.equal(true)
			expect(confetti <= 1).to.equal(true) -- a share of the device's confetti budget
			expect(beam).to.equal(true)
			local c = Presets.catchPop
			expect(c.secret.beam.height > c.beam.height).to.equal(true)
			expect(c.secret.beam.width > c.beam.width).to.equal(true)
			expect(c.secret.bursts > c.shower.bursts).to.equal(true)
			expect(c.secret.third.scale > c.echo.scale).to.equal(true)
			expect(c.secret.third.after > c.echo.after).to.equal(true)
			-- no single burst over the skill's 30, and the showers stay inside the phone budget
			expect(Presets.catchSparkle.Secret <= 30).to.equal(true)
			expect(Presets.bursts.shower * c.secret.bursts <= 40).to.equal(true)
		end)

		it("gives a Secret every Mythical extra and the big pull", function()
			expect(Logic.topTier("Secret")).to.equal(true)
			expect(Logic.topTier("Mythical")).to.equal(true)
			expect(Logic.topTier("Legendary")).to.equal(false)
			expect(Logic.topTier(nil)).to.equal(false)
			expect(Logic.bigPull("Secret", false)).to.equal(true)
		end)

		it("glows a Secret in starlight and every other rarity in its own colour", function()
			expect(Logic.glowColour("Secret")).to.equal(Presets.rarityGlow.Secret)
			for _, rarity in { "Common", "Rare", "Epic", "Legendary", "Mythical" } do
				expect(Logic.glowColour(rarity)).to.equal(Presets.rarity[rarity])
			end
			expect(Logic.glowColour("Sparkly")).to.equal(Presets.rarity.Common)
			expect(Logic.glowColour(nil)).to.equal(Presets.rarity.Common)
		end)

		it("shows a Secret stray's gem with the strongest halo, pulse and glint", function()
			local r = Presets.rarityMark
			expect(Logic.rarityMarkShows("Secret", 0, 40, false)).to.equal(true)
			expect(r.glints.Secret).to.equal(true)
			expect(r.halo.Secret >= r.halo.Mythical).to.equal(true)
			expect(r.pulse.Secret.grow > r.pulse.Mythical.grow).to.equal(true)
			expect(r.glintEvery.Secret < r.glintEvery.Mythical).to.equal(true)
			-- nothing flashes above about 3 Hz: a full breath and a glint each take longer than a third of a second
			expect(2 * r.pulse.Secret.seconds > 1 / 3).to.equal(true)
			expect(r.glintEvery.Secret > 1 / 3).to.equal(true)
		end)

		it("keeps the sky beam a thin line from far away and faint up close", function()
			local b = Presets.secretStray.beam
			local nearWidth, nearFade = Logic.secretBeam(0)
			expect(nearWidth).to.equal(b.widthMin)
			expect(nearFade).to.equal(b.near)
			local midWidth, midFade = Logic.secretBeam(200)
			expect(midWidth > nearWidth and midWidth < b.widthMax).to.equal(true)
			expect(math.abs(midFade - b.far) < 1e-6).to.equal(true)
			local farWidth = Logic.secretBeam(5000)
			expect(farWidth).to.equal(b.widthMax)
			-- wider with distance, never narrower, and it only gets clearer as you walk away
			local lastWidth, lastFade = 0, 1
			for distance = 0, 600, 20 do
				local width, fade = Logic.secretBeam(distance)
				expect(width >= lastWidth).to.equal(true)
				expect(fade <= lastFade).to.equal(true)
				lastWidth, lastFade = width, fade
			end
			expect(Logic.secretBeam(-5)).to.equal(b.widthMin)
		end)

		it("glides a far beam to the beacon's new position and snaps to a new spot", function()
			local s = Presets.secretStray
			local from = Vector3.new(0, 0, 0)
			local target = Vector3.new(10, 0, 0)
			local stepped = Logic.secretGlide(from, target, 0.1)
			expect(stepped.X > 0 and stepped.X < 10).to.equal(true)
			expect(Logic.secretGlide(from, target, 0).X).to.equal(0)
			-- a long frame never overshoots
			expect(Logic.secretGlide(from, target, 5).X).to.equal(10)
			-- it closes most of a 2 second walk before the next word comes
			local at = from
			for _ = 1, 120 do
				at = Logic.secretGlide(at, target, 1 / 60)
			end
			expect(at.X > 9.9).to.equal(true)
			local far = Vector3.new(s.snap + 1, 0, 0)
			expect(Logic.secretGlide(from, far, 1 / 60)).to.equal(far)
			expect(s.beacons).to.equal("SecretBeacons")
			expect(s.beams >= s.most).to.equal(true)
		end)

		it("keeps the stray's haze inside the steady emitter budget", function()
			expect(Presets.emitters.secretAura.rate <= 4).to.equal(true)
			expect(Presets.emitters.secretStars.rate <= 4).to.equal(true)
			expect(Presets.secretStray.most <= 2).to.equal(true)
		end)
	end)
end
