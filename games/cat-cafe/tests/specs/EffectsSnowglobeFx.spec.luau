--!strict
-- Snowglobe Village's snow and portal swirl rules. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Fx = require(Effects:WaitForChild("SnowglobeFx")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Snowglobe Village", function()
		it(
			"snows only near the village, thinner with Reduce Motion, none on Low performance",
			function()
				local p = Presets.snowglobeFx
				expect(Fx.air(nil, p.airWithin, false, false, p.calmRate)).to.equal(0)
				expect(Fx.air(p.airWithin + 1, p.airWithin, false, false, p.calmRate)).to.equal(0)
				expect(Fx.air(10, p.airWithin, false, false, p.calmRate)).to.equal(1)
				expect(Fx.air(10, p.airWithin, false, true, p.calmRate)).to.equal(p.calmRate)
				expect(Fx.air(10, p.airWithin, true, false, p.calmRate)).to.equal(0)
			end
		)

		it("swirls the portal only when near, not on Low performance or Reduce Motion", function()
			local p = Presets.snowglobeFx
			expect(Fx.swirls(10, p.portalWithin, false, false)).to.equal(true)
			expect(Fx.swirls(p.portalWithin + 1, p.portalWithin, false, false)).to.equal(false)
			expect(Fx.swirls(10, p.portalWithin, true, false)).to.equal(false)
			expect(Fx.swirls(10, p.portalWithin, false, true)).to.equal(false)
			expect(Presets.emitters[p.swirl] ~= nil).to.equal(true)
			expect(Presets.emitters[p.snow] ~= nil).to.equal(true)
		end)
	end)
end
