--!strict
-- Effects/StormFall (#4197): what a Cat Storm's landing draws, and its numbers. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local StormFall = require(Effects:WaitForChild("StormFall")) :: any
	local Cues = require(Client:WaitForChild("Audio"):WaitForChild("Cues")) :: any
	local AudioLogic = require(Client:WaitForChild("Audio"):WaitForChild("Logic")) :: any

	describe("Effects storm fall", function()
		it(
			"draws the whole fall near you, the puff alone when still, nothing far off or over the count",
			function()
				expect(StormFall.plan(30, 0, false, 140, 4)).to.equal("fall")
				expect(StormFall.plan(30, 3, false, 140, 4)).to.equal("fall")
				expect(StormFall.plan(30, 0, true, 140, 4)).to.equal("puff")
				expect(StormFall.plan(141, 0, false, 140, 4)).to.equal("none")
				expect(StormFall.plan(30, 4, false, 140, 4)).to.equal("none")
				expect(StormFall.plan(30, 4, true, 140, 4)).to.equal("none")
			end
		)

		it(
			"drifts only while a storm runs, and never with Reduce Motion or Low performance",
			function()
				expect(StormFall.drifts(true, false)).to.equal(true)
				expect(StormFall.drifts(true, true)).to.equal(false)
				expect(StormFall.drifts(false, false)).to.equal(false)
			end
		)

		it("has its emitters, a landing cue and a fall short enough to read as one drop", function()
			local p = Presets.stormFall
			expect(Presets.emitters[p.puff]).to.be.ok()
			expect(Presets.emitters[p.drift]).to.be.ok()
			expect(p.seconds > 0.3 and p.seconds <= 1).to.equal(true)
			expect(p.height >= 30).to.equal(true)
			expect(Cues[AudioLogic.STORM_LAND_CUE]).to.be.ok()
			expect(Cues[AudioLogic.STORM_LAND_CUE].minGap >= 0.3).to.equal(true)
		end)
	end)
end
