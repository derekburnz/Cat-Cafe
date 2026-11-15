--!strict
-- Effects/HarvestFx (#4251): what a patch pumpkin's Ready change means, when the leaves fall and how thick, which
-- ready pumpkins glint, and that the numbers stay calm.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local HarvestFx = require(Effects:WaitForChild("HarvestFx")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Harvest Hollow (#4251)", function()
		it("reads a pick and a regrow from Ready, and nothing from the first sight", function()
			expect(HarvestFx.change(true, false)).to.equal("pick")
			expect(HarvestFx.change(false, true)).to.equal("regrow")
			expect(HarvestFx.change(nil, true)).never.to.be.ok()
			expect(HarvestFx.change(nil, false)).never.to.be.ok()
			expect(HarvestFx.change(true, true)).never.to.be.ok()
			expect(HarvestFx.change(false, false)).never.to.be.ok()
		end)

		it(
			"drops leaves only in the area, thinner with Reduce Motion and never in Low performance",
			function()
				expect(HarvestFx.air(40, 130, false, false, 0.2)).to.equal(1)
				expect(HarvestFx.air(130, 130, false, false, 0.2)).to.equal(1)
				expect(HarvestFx.air(131, 130, false, false, 0.2)).to.equal(0)
				expect(HarvestFx.air(nil, 130, false, false, 0.2)).to.equal(0) -- the area is not in the world
				expect(HarvestFx.air(40, 130, false, true, 0.2)).to.equal(0.2)
				expect(HarvestFx.air(40, 130, true, false, 0.2)).to.equal(0)
				expect(HarvestFx.air(40, 130, true, true, 0.2)).to.equal(0)
			end
		)

		it("glints the nearest ready pumpkins only", function()
			local picked = HarvestFx.glinters({ 50, 12, 90, 30, 12 }, 60, 3)
			expect(#picked).to.equal(3)
			expect(picked[1]).to.equal(2)
			expect(picked[2]).to.equal(5) -- a tie goes to the earlier spot
			expect(picked[3]).to.equal(4)
			expect(#HarvestFx.glinters({ 61, 200 }, 60, 3)).to.equal(0)
			expect(#HarvestFx.glinters({}, 60, 3)).to.equal(0)
			expect(#HarvestFx.glinters({ 5 }, 60, 3)).to.equal(1)
		end)

		it("keeps its numbers calm and its presets real", function()
			local p = Presets.harvestFx
			expect(Presets.emitters[p.air]).to.be.ok()
			expect(Presets.emitters[p.pick]).to.be.ok()
			expect(Presets.emitters[p.regrow]).to.be.ok()
			expect(Presets.emitters[p.glint]).to.be.ok()
			expect(Presets.emitters[p.air].rate <= 10).to.equal(true)
			expect(p.glintEvery >= 3).to.equal(true) -- far under 3 Hz
			expect(p.glintMost <= 3).to.equal(true)
			expect(p.pickCount <= 12).to.equal(true)
			expect(p.calmRate < 1).to.equal(true)
			-- the server's names (server/World/HarvestWorld, Services/HarvestService)
			expect(p.pumpkinTag).to.equal("HarvestPumpkin")
			expect(p.boardTag).to.equal("HarvestBoard")
			expect(p.readyAttribute).to.equal("Ready")
		end)
	end)
end
