--!strict
-- The Cat Whistle's paw ring (corner-shop-v2.md section 4): one small teal pulse at a steady beat, inside the phone
-- budget. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects cat whistle", function()
		it("pulses a small teal ring no more than once a second", function()
			local w = Presets.whistle
			expect(w.every >= 1).to.equal(true)
			expect(w.ringSeconds < w.every).to.equal(true)
			expect(w.sparkles <= 6).to.equal(true) -- one small burst
			expect(w.pick <= 0.5).to.equal(true) -- follows the marker's 0.5 s step
		end)

		it("matches the potion's own glow colour", function()
			expect(Presets.whistle.colour).to.equal(Presets.potions.cat_whistle.colour)
		end)
	end)
end
