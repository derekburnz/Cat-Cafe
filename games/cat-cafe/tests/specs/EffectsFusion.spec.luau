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

		it(
			"lands the five on the dome card's picture with a ring sized from its height (#4563)",
			function()
				local p = Presets.fusion
				-- the window's dome card: 600 wide, 88 high, its picture at the left end
				local at, across = FusionFx.landing(Vector2.new(20, 40), Vector2.new(600, 88))
				expect(at).to.equal(Vector2.new(20 + 44, 40 + 44))
				expect(across).to.equal(p.acrossMin)
				-- a square picture: its middle, its own width, never over acrossMax
				at, across = FusionFx.landing(Vector2.new(0, 0), Vector2.new(140, 140))
				expect(at).to.equal(Vector2.new(70, 70))
				expect(across).to.equal(140)
				at, across = FusionFx.landing(Vector2.new(0, 0), Vector2.new(400, 400))
				expect(across).to.equal(p.acrossMax)
				expect(p.acrossMax * p.swirl.ringTo <= 400).to.equal(true)
			end
		)

		it("reads the dome's fusion from ProfileSync and spots a Collect (#4563)", function()
			local coat, ready, gold, rainbow = FusionFx.read({
				running = { coat = "gold", doneAt = 0 },
				ready = true,
				made = { gold = 2, rainbow = 0 },
			})
			expect(coat).to.equal("gold")
			expect(ready).to.equal(true)
			expect(gold).to.equal(2)
			expect(rainbow).to.equal(0)
			coat, ready = FusionFx.read(false)
			expect(coat).to.equal(nil)
			expect(ready).to.equal(false)
			coat = FusionFx.read({ running = { coat = "plain" } })
			expect(coat).to.equal(nil)
			-- gone with its count up: collected; gone with no count change (the switch off): not
			expect(FusionFx.collectedCoat("gold", nil, { gold = 2 }, { gold = 3 })).to.equal("gold")
			expect(FusionFx.collectedCoat("gold", nil, { gold = 2 }, { gold = 2 })).to.equal(nil)
			expect(FusionFx.collectedCoat("gold", "gold", { gold = 2 }, { gold = 3 })).to.equal(nil)
			expect(FusionFx.collectedCoat(nil, nil, {}, { rainbow = 1 })).to.equal(nil)
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

		it(
			"twinkles stars over the dome only at night, near it and never in Low performance (#4069)",
			function()
				local st = Presets.fusion.stars
				expect(FusionFx.starsOn(true, false, 50, st.within)).to.equal(true)
				expect(FusionFx.starsOn(false, false, 50, st.within)).to.equal(false)
				expect(FusionFx.starsOn(true, true, 50, st.within)).to.equal(false)
				expect(FusionFx.starsOn(true, false, st.within + 1, st.within)).to.equal(false)
				local e = Presets.emitters[st.emitter]
				expect(e).to.be.ok()
				expect(e.rate < 3).to.equal(true) -- calm, under 3 a second
				expect(e.speed[2]).to.equal(0) -- stars stay put
			end
		)
	end)
end
