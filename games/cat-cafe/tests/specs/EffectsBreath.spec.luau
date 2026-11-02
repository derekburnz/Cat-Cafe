--!strict
-- The sleeping breath and the z's (Derek 2026-10-27: "breathing cat slightly lifting and lowering cat belly while
-- sleeping and Z's looping up and resetting"). Written by the Animation-Engineer for QA to move into tests/specs.
-- How the body swells (Pose) needs Instance and CFrame, so it is a Studio row; this covers the curves.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects breath", function()
		local m = Presets.motion
		local b = m.breath

		it("fills, lets out and rests once a breath, between 0 and 1", function()
			local seconds = 3
			expect(Logic.breath(0, seconds)).to.equal(0)
			expect(Logic.breath(b.inhale * seconds, seconds)).to.be.near(1, 1e-9)
			expect(Logic.breath((b.inhale + b.exhale) * seconds, seconds)).to.be.near(0, 1e-9)
			-- the rest before the next breath is still
			local rest = (b.inhale + b.exhale + 1) / 2 * seconds
			expect(Logic.breath(rest, seconds)).to.equal(0)
			local last = 0
			for t = 0, b.inhale * seconds, 0.01 do
				local v = Logic.breath(t, seconds)
				expect(v >= last - 1e-9 and v <= 1).to.equal(true) -- only ever rises while filling
				last = v
			end
			for t = 0, 3 * seconds, 0.013 do
				local v = Logic.breath(t, seconds)
				expect(v >= 0 and v <= 1).to.equal(true)
			end
			expect(b.inhale + b.exhale < 1).to.equal(true)
		end)

		it("breathes with the belly while asleep, not by floating the whole cat", function()
			for _, case in { { "nap", m.nap }, { "loaf", m.loaf }, { "doze", m.doze } } do
				local style, preset = case[1], case[2]
				for _, body in { "walk", "sit", "parts" } do
					local most = 0
					for t = 0, preset.seconds * 2, 0.02 do
						local o = Logic.idle(style, t, body)
						expect(o.bodyY).to.equal(0)
						expect(o.belly >= 0 and o.belly <= preset.breathe + 1e-9).to.equal(true)
						most = math.max(most, o.belly)
					end
					expect(most).to.be.near(preset.breathe, 1e-3)
				end
				expect(Logic.breathSeconds(style)).to.equal(preset.seconds)
			end
			-- awake cats keep their small whole-body breath
			expect(Logic.idle("stray", 1, "walk").belly).to.equal(0)
			expect(Logic.blank().belly).to.equal(0)
		end)

		it("nods the dozing head with the breath, inside its droop", function()
			local d = m.doze
			for t = 0, d.seconds * 2, 0.05 do
				local droop = -math.deg(Logic.idle("doze", t, "sit").headPitch)
				expect(droop >= d.headDroop - d.nod - 1e-6 and droop <= d.headDroop + d.nod + 1e-6).to.equal(
					true
				)
			end
		end)
	end)

	describe("Effects z's", function()
		local z = Presets.nap
		local inhale = Presets.motion.breath.inhale
		local seconds = Presets.motion.nap.seconds

		it("lets each z out in turn as the cat breathes out", function()
			for i = 1, z.labels do
				-- z i appears at the start of the breath out of breath i - 1 (counted from 0)
				local born = ((i - 1) + inhale) * seconds
				local x, y, size, fade = Logic.napZ(i, z.labels, born + 1e-6, seconds)
				expect(x).to.be.near(z.x, 1e-3)
				expect(y).to.be.near(z.y, 1e-3)
				expect(size).to.be.near(z.size, 1e-3)
				expect(fade).to.be.near(1, 1e-3) -- fading in from nothing
				-- and every labels breaths after that, back at the bottom again
				local again = born + z.labels * seconds
				local x2, y2 = Logic.napZ(i, z.labels, again + 1e-6, seconds)
				expect(x2).to.be.near(z.x, 1e-3)
				expect(y2).to.be.near(z.y, 1e-3)
			end
		end)

		it("rises, grows and fades out over its life, then waits hidden", function()
			local born = inhale * seconds
			local lastY, lastSize = math.huge, 0
			local seen = false
			for k = 0, 0.999, 0.01 do
				local t = born + k * z.life * seconds
				local x, y, size, fade, tilt = Logic.napZ(1, z.labels, t, seconds)
				expect(y <= lastY + 1e-9).to.equal(true) -- up the box (y counts down from the top)
				expect(size >= lastSize - 1e-9 and size <= 1).to.equal(true)
				expect(fade >= 0 and fade <= 1).to.equal(true)
				expect(math.abs(tilt) <= z.tilt + 1e-9).to.equal(true)
				expect(x >= 0 and x <= 1 and y >= 0 and y <= 1).to.equal(true) -- inside its box
				seen = seen or fade == 0
				lastY, lastSize = y, size
			end
			expect(seen).to.equal(true) -- fully shown for a while in the middle
			-- after its life it is hidden until its next turn
			if z.life < z.labels then
				local _, _, _, fade =
					Logic.napZ(1, z.labels, born + (z.life + 0.01) * seconds, seconds)
				expect(fade).to.equal(1)
			end
		end)

		it("never shows more z's than labels", function()
			for t = 0, 30, 0.07 do
				local shown = 0
				for i = 1, z.labels do
					local _, _, _, fade = Logic.napZ(i, z.labels, t, seconds)
					if fade < 1 then
						shown += 1
					end
				end
				expect(shown <= z.labels).to.equal(true)
			end
		end)
	end)
end
