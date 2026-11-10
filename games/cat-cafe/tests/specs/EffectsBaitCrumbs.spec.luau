--!strict
-- The first bait cat's crumbs (#2946): small, slow and short.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Presets = require(Client:WaitForChild("Effects"):WaitForChild("Presets")) :: any

	describe("Effects bait crumbs", function()
		it("stays small, under 3 Hz and short", function()
			local p = Presets.baitCrumbs
			expect(Presets.emitters[p.preset]).to.be.ok()
			expect(p.count <= Presets.budget.low.maxBurst).to.equal(true)
			expect(p.gap >= 1 / 3).to.equal(true)
			expect(p.most <= 5).to.equal(true)
		end)
	end)
end
