--!strict
-- A gate opening in its area's colour (#4069, #4070, #4071; Effects/Plots' dissolve): every area with effects of its
-- own has the tint and the puff the gate uses, and the extra stays a small burst. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects gate opening in the area's colour", function()
		it("has a tint and a puff for each of the late areas", function()
			for _, area in { "desert", "ruins", "snowy", "waterpark", "castle" } do
				local spec = Presets.areaFx.areas[area]
				expect(spec).to.be.ok()
				expect(Presets.emitters[spec.puffPreset]).to.be.ok()
				expect(Presets.cannon.tints[area]).to.be.ok()
			end
		end)

		it("keeps the extra puffs small", function()
			local g = Presets.gate
			expect(g.areaPuff >= 1).to.equal(true)
			expect(g.areaPuff * Presets.areas.points <= Presets.budget.low.maxBurst).to.equal(true)
		end)
	end)
end
