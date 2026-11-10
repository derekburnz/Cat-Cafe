--!strict
-- The Desert's and the Ruins' effects (#2657): which area's box you stand in, and their presets stay in budget.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local areas = {
		{ id = "desert", centre = { x = 1400, z = -1400 }, size = { width = 150, depth = 560 } },
		{ id = "ruins", centre = { x = 1400, z = 1400 }, size = { width = 140, depth = 600 } },
	}

	describe("Effects Desert and Ruins", function()
		it("finds the area you stand in, its long axis along Z", function()
			expect(Logic.areaAt(1400, -1400, areas, 0)).to.equal("desert")
			expect(Logic.areaAt(1400, -1400 + 279, areas, 0)).to.equal("desert")
			expect(Logic.areaAt(1400 + 80, -1400, areas, 0)).to.equal(nil)
			expect(Logic.areaAt(1400 + 80, -1400, areas, 10)).to.equal("desert")
			expect(Logic.areaAt(1400, 1400 + 299, areas, 0)).to.equal("ruins")
			expect(Logic.areaAt(0, 0, areas, 30)).to.equal(nil)
		end)

		it("has air, a puff and the cannon tint for both areas, within the burst budget", function()
			for _, id in { "desert", "ruins" } do
				local spec = Presets.areaFx.areas[id]
				expect(spec).to.be.ok()
				expect(Presets.emitters[spec.air]).to.be.ok()
				expect(Presets.emitters[spec.puffPreset]).to.be.ok()
				expect(spec.puff <= Presets.budget.low.maxBurst).to.equal(true)
				expect(Presets.cannon.tints[id] ~= nil).to.equal(true)
			end
			local ruins = Presets.areaFx.areas.ruins
			expect(ruins.mist <= Presets.budget.low.maxBurst).to.equal(true)
			expect(ruins.mistDepth > 0).to.equal(true)
			local dunes = Presets.areaFx.dunes
			expect(Presets.emitters[dunes.emitter]).to.be.ok()
			expect(dunes.most.low <= dunes.most.high).to.equal(true)
			expect(dunes.most.low <= Presets.budget.low.steadyEmitters).to.equal(true)
			local b = Presets.budget
			expect(b.lowPerformance.areaPuffs <= b.low.areaPuffs).to.equal(true)
			expect(b.low.areaPuffs <= b.high.areaPuffs).to.equal(true)
		end)
	end)
end
