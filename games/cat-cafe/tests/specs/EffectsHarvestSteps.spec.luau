--!strict
-- Harvest Hollow's steps (#4251): your steps there kick up a few dry leaves and crunch, though the area has no box.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local AudioLogic = require(Client:WaitForChild("Audio"):WaitForChild("Logic")) :: any
	local Cues = require(Client:WaitForChild("Audio"):WaitForChild("Cues")) :: any

	describe("Effects Harvest Hollow steps", function()
		it("walks in Harvest Hollow near the Thankful Board, and a box area always wins", function()
			expect(Logic.walkArea(nil, 40, 130)).to.equal("harvest")
			expect(Logic.walkArea(nil, 130, 130)).to.equal("harvest")
			expect(Logic.walkArea(nil, 131, 130)).to.equal(nil)
			expect(Logic.walkArea(nil, nil, 130)).to.equal(nil)
			expect(Logic.walkArea("snowy", 40, 130)).to.equal("snowy")
			expect(Logic.walkArea("desert", nil, 130)).to.equal("desert")
		end)

		it("has a small leaf puff for the area's steps, within the burst budget", function()
			local spec = Presets.areaFx.areas.harvest
			expect(spec).to.be.ok()
			expect(spec.footPuff >= 1 and spec.footPuff <= 3).to.equal(true)
			expect(Presets.emitters[spec.footPreset]).to.be.ok()
			expect(spec.footStuds >= 2).to.equal(true)
		end)

		it("plays a quiet leaf crunch on each step, never stacking", function()
			expect(AudioLogic.areaCue("step", "harvest", nil)).to.equal("leafStep")
			local cue = Cues.leafStep
			expect(cue).to.be.ok()
			expect(cue.sheet).to.equal("sheetKeep")
			expect(cue.region[2] > cue.region[1]).to.equal(true)
			expect(cue.volume <= 0.3).to.equal(true)
			expect(cue.minGap >= 0.2).to.equal(true)
			expect(cue.pitch[1] > 1 and cue.pitch[2] > cue.pitch[1]).to.equal(true)
		end)
	end)
end
