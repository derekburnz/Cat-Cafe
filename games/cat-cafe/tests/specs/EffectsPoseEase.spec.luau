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
		it("draws on up to ahead, then falls back to the write by stale", function()
			expect(Logic.reckonShare(0, 0.15, 0.3)).to.equal(0)
			expect(Logic.reckonShare(0.1, 0.15, 0.3)).to.be.near(0.1, 1e-6)
			expect(Logic.reckonShare(0.15, 0.15, 0.3)).to.be.near(0.15, 1e-6)
			expect(Logic.reckonShare(0.225, 0.15, 0.3)).to.be.near(0.075, 1e-6)
			expect(Logic.reckonShare(0.3, 0.15, 0.3)).to.equal(0)
			expect(Logic.reckonShare(1, 0.15, 0.3)).to.equal(0)
		end)

		it("goes from 0 to 1 over its seconds and is done at once with none", function()
			expect(Logic.easeShare(0, 0.1)).to.equal(0)
			expect(Logic.easeShare(0.05, 0.1)).to.be.near(0.5, 1e-6)
			expect(Logic.easeShare(0.2, 0.1)).to.equal(1)
			expect(Logic.easeShare(-1, 0.1)).to.equal(0)
			expect(Logic.easeShare(0, 0)).to.equal(1)
		end)

		it("eases a step in, draws on past a 10 Hz write and reads the switch by name", function()
			local e = Presets.motion.stepEase
			expect(e.flag).to.equal("strayWalkSlow")
			expect(e.seconds >= 0.05 and e.seconds <= 0.2).to.equal(true)
			expect(e.ahead > 0.1 and e.stale > e.ahead).to.equal(true)
		end)
	end)
end
