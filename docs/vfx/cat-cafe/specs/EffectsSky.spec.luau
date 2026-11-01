--!strict
-- Clouds in the sky (Sky.luau; Derek 2026-10-28 17:05: "add clouds in sky"): the numbers keep a soft, partly cloudy
-- sky with the skybox showing through and a slow drift. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects sky", function()
		it("leaves the skybox showing between soft clouds", function()
			local s = Presets.sky
			expect(s.cover >= 0.3 and s.cover <= 0.7).to.equal(true)
			expect(s.density >= 0.3 and s.density <= 0.7).to.equal(true)
			expect(math.min(s.color.R, s.color.G, s.color.B) > 0.9).to.equal(true) -- white, lit by the sun
		end)

		it("drifts them slowly and level", function()
			local wind = Presets.sky.wind
			expect(wind.Magnitude > 0 and wind.Magnitude <= 6).to.equal(true)
			expect(wind.Y).to.equal(0)
		end)
	end)
end
