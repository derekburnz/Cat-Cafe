--!strict
-- The Dragon Keep's Fire Trail card (#4558): embers at the heels only while the card is on and the walker moves on the
-- ground; numbers in budget. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local FireTrail = require(Effects:WaitForChild("FireTrail")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Fire Trail", function()
		it("runs only with the card on, moving, on the ground", function()
			local least = Presets.fireTrail.moving
			expect(FireTrail.on(true, 1, true, least)).to.equal(true)
			expect(FireTrail.on(false, 1, true, least)).to.equal(false)
			expect(FireTrail.on(true, 0, true, least)).to.equal(false)
			expect(FireTrail.on(true, 1, false, least)).to.equal(false)
			expect(FireTrail.on(true, 0 / 0, true, least)).to.equal(false)
		end)

		it("has its ember preset and stays off in Low performance", function()
			expect(Presets.emitters.fireTrail).to.be.ok()
			expect(Presets.emitters.fireTrail.rate <= 15).to.equal(true)
			expect(Presets.budget.lowPerformance.potionGlows).to.equal(0)
		end)
	end)
end
