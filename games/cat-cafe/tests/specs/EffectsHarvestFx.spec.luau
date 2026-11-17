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

		it("knows when you are in the area, for the song", function()
			expect(HarvestFx.within(40, 130)).to.equal(true)
			expect(HarvestFx.within(130, 130)).to.equal(true)
			expect(HarvestFx.within(131, 130)).to.equal(false)
			expect(HarvestFx.within(nil, 130)).to.equal(false)
		end)

		it("celebrates a new Feast Pie slice, and the last one more", function()
			expect(HarvestFx.pie(2, 3, 8)).to.equal("slice")
			expect(HarvestFx.pie(7, 8, 8)).to.equal("full")
			expect(HarvestFx.pie(3, 8, 8)).to.equal("full")
			expect(HarvestFx.pie(nil, 3, 8)).never.to.be.ok() -- the first value only sets the mark
			expect(HarvestFx.pie(3, 3, 8)).never.to.be.ok()
			expect(HarvestFx.pie(8, 8, 8)).never.to.be.ok()
			expect(HarvestFx.pie(4, 2, 8)).never.to.be.ok() -- a count never goes down, and a drop is not news
			expect(HarvestFx.pie(2, nil, 8)).never.to.be.ok()
			expect(HarvestFx.pie(2, "3", 8)).never.to.be.ok()
			expect(Presets.harvestFx.pieAttribute).to.equal("HarvestPieSlices") -- HarvestPieService's name
			expect(Presets.harvestFx.pieFull).to.equal(8)
			expect(Presets.emitters[Presets.harvestFx.pieBurst]).to.be.ok()
		end)

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

		it("swirls leaves when you walk in, not when you pace the edge", function()
			expect(HarvestFx.arrive(nil, true, nil, 90)).to.equal(true) -- the first look finds you inside
			expect(HarvestFx.arrive(false, true, nil, 90)).to.equal(true)
			expect(HarvestFx.arrive(false, true, 30, 90)).to.equal(false)
			expect(HarvestFx.arrive(false, true, 90, 90)).to.equal(true)
			expect(HarvestFx.arrive(true, true, 500, 90)).to.equal(false)
			expect(HarvestFx.arrive(true, false, 500, 90)).to.equal(false)
			local p = Presets.harvestFx
			expect(p.arriveSpots * p.arriveCount <= 24).to.equal(true)
			expect(p.arriveSparkles <= Presets.budget.low.maxBurst).to.equal(true)
			expect(p.arriveGap >= 60).to.equal(true)
		end)

		it("puffs only for a new pin on the Thankful Board and knows when it is yours", function()
			expect(HarvestFx.newPin(nil, "[]")).to.equal(false) -- the first sight sets the mark
			expect(HarvestFx.newPin("[]", "[]")).to.equal(false)
			expect(HarvestFx.newPin("[]", nil)).to.equal(false)
			expect(HarvestFx.newPin("[]", 3)).to.equal(false)
			expect(HarvestFx.newPin("[]", '[{"userId":7,"note":2}]')).to.equal(true)
			expect(HarvestFx.lastPinner('[{"userId":7,"note":2},{"userId":9,"note":1}]')).to.equal(
				9
			)
			expect(HarvestFx.lastPinner("[]")).never.to.be.ok()
			expect(HarvestFx.lastPinner("not json")).never.to.be.ok()
			expect(HarvestFx.lastPinner('[{"note":1}]')).never.to.be.ok()
			local p = Presets.harvestFx
			expect(p.notesAttribute).to.equal("HarvestNotes")
			expect(p.pinCount <= 8).to.equal(true)
			expect(p.pinSparkles <= Presets.budget.low.maxBurst).to.equal(true)
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

		it("fills a regrow spot's ring toward RegrowAt (#4251 spec section 3)", function()
			expect(HarvestFx.regrowTotal(150, 150, 300)).to.equal(150)
			expect(HarvestFx.regrowTotal(80, 150, 300)).to.equal(150)
			expect(HarvestFx.regrowTotal(299, 150, 300)).to.equal(300)
			expect(HarvestFx.regrowShare(300, 300)).to.equal(0)
			expect(HarvestFx.regrowShare(150, 300)).to.equal(0.5)
			expect(HarvestFx.regrowShare(0, 300)).to.equal(1)
			expect(HarvestFx.regrowShare(-5, 300)).to.equal(1)
			expect(HarvestFx.regrowShare(400, 300)).to.equal(0)
			expect(HarvestFx.regrowShare(10, 0)).to.equal(1)
			local p = Presets.harvestFx
			expect(p.regrowAttribute).to.equal("RegrowAt")
			expect(p.sproutMost <= 12).to.equal(true)
		end)
	end)
end
