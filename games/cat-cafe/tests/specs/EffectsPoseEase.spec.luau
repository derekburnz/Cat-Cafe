--!strict
-- #4601 strayWalkSlow: Pose.read (through Logic.easeShare) eases a server step in instead of snapping to it. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects pose step ease", function()
		it("goes from 0 to 1 over its seconds and is done at once with none", function()
			expect(Logic.easeShare(0, 0.1)).to.equal(0)
			expect(Logic.easeShare(0.05, 0.1)).to.be.near(0.5, 1e-6)
			expect(Logic.easeShare(0.2, 0.1)).to.equal(1)
			expect(Logic.easeShare(-1, 0.1)).to.equal(0)
			expect(Logic.easeShare(0, 0)).to.equal(1)
		end)

		it("eases about as long as one 10 Hz server step and reads the switch by name", function()
			local e = Presets.motion.stepEase
			expect(e.flag).to.equal("strayWalkSlow")
			expect(e.seconds >= 0.05 and e.seconds <= 0.15).to.equal(true)
		end)
	end)
end
