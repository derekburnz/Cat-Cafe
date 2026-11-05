--!strict
-- The Picnic Basket's ready glow (#1133): one soft light, inside the night glow budget, that reads the picnic's held
-- potions. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects picnic glow", function()
		it("stays a soft light inside the night glow budget", function()
			local g = Presets.picnicGlow
			expect(g.brightness > 0 and g.brightness <= 1).to.equal(true)
			expect(g.range > 0 and g.range <= 10).to.equal(true)
			expect(g.under > 0 and g.under < 1).to.equal(true) -- under the parasol, above the ground
		end)

		it("glows only while a potion waits", function()
			expect(Logic.campHeld({ picnic = { open = true, held = 1 } }, "picnic") > 0).to.equal(true)
			expect(Logic.campHeld({ picnic = { open = true, held = 0 } }, "picnic")).to.equal(0)
			expect(Logic.campHeld(nil, "picnic")).to.equal(0)
		end)
	end)
end
