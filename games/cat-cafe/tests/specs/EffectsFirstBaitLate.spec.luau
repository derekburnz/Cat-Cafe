--!strict
-- #5548 follow-up: a freeStart save's owed first bait scene plays at the bowl with the cat there, waits otherwise, and
-- is dropped once the cat has gone. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects first bait owed scene", function()
		it("plays only near the bowl with the cat there", function()
			expect(Logic.firstBaitLate(true, true, true)).to.equal("play")
			expect(Logic.firstBaitLate(false, true, true)).to.equal("wait")
		end)

		it("waits for a cat not out yet and drops one that has gone", function()
			expect(Logic.firstBaitLate(true, false, false)).to.equal("wait")
			expect(Logic.firstBaitLate(false, false, false)).to.equal("wait")
			expect(Logic.firstBaitLate(true, false, true)).to.equal("drop")
			expect(Logic.firstBaitLate(false, false, true)).to.equal("drop")
		end)

		it("starts outside the 8 stud walk-up ring, inside the scene's own reach", function()
			local p = Presets.firstBaitCut
			expect(p.lateNear > 8).to.equal(true)
			expect(p.lateNear + p.lateMargin <= p.maxDistance).to.equal(true)
			expect(p.lateCheck * 16 < p.lateMargin).to.equal(true) -- a walking player cannot pass the margin between looks
		end)
	end)
end
