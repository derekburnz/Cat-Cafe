--!strict
-- The townsfolk cats (#2687 part 2): their idle, ear flick, greet wave and head turn. Townsfolk.luau moves Model-Agent's
-- real models, so how it looks is checked in Studio. Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local c = Presets.townsfolk

	describe("Effects townsfolk", function()
		it("idles within its limits and differently for each phase", function()
			for t = 0, 60, 0.7 do
				local yaw, pitch, tail = Logic.townsfolkIdle(t, 0.3, c)
				expect(math.abs(yaw) <= c.lookYaw + 1e-9).to.equal(true)
				expect(math.abs(pitch) <= c.lookPitch + 1e-9).to.equal(true)
				expect(math.abs(tail) <= c.tailYaw + 1e-9).to.equal(true)
			end
			local a = Logic.townsfolkIdle(5, 0.1, c)
			local b = Logic.townsfolkIdle(5, 0.6, c)
			expect(math.abs(a - b) > 1e-3).to.equal(true)
		end)

		it("twitches an ear and settles back", function()
			local f = c.flick
			expect(Logic.townsfolkFlick(-0.1, f.seconds, f.degrees)).to.equal(0)
			expect(Logic.townsfolkFlick(f.seconds, f.seconds, f.degrees)).to.equal(0)
			local mid = Logic.townsfolkFlick(f.seconds * 0.3, f.seconds, f.degrees)
			expect(mid > 0 and mid <= f.degrees).to.equal(true)
		end)

		it("lifts the paw, waves it and puts it down", function()
			local w = c.wave
			local lift0 = Logic.townsfolkWave(0, w)
			expect(lift0).to.equal(0)
			local lift, side = Logic.townsfolkWave(w.up + w.wave / (4 * w.waves), w)
			expect(lift).to.equal(w.lift)
			expect(side).to.be.near(w.side, 1e-6)
			local last = Logic.townsfolkWave(w.up * 2 + w.wave - 1e-6, w)
			expect(last < 0.01).to.equal(true)
			expect(Logic.townsfolkWave(w.up * 2 + w.wave, w)).to.equal(nil)
		end)

		it("turns the head to you, within the limit", function()
			expect(Logic.lookYaw(0, -5, 60)).to.equal(0) -- right in front (-Z)
			expect(Logic.lookYaw(-5, -5, 60)).to.be.near(45, 1e-9) -- front left: turned left (+Y)
			expect(Logic.lookYaw(5, -5, 60)).to.be.near(-45, 1e-9)
			expect(Logic.lookYaw(5, 5, 60)).to.equal(-60) -- behind: held at the limit
			expect(Logic.lookYaw(0, 0, 60)).to.equal(0)
		end)
	end)
end
