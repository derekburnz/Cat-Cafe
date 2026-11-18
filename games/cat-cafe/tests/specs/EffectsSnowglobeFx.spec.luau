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

		it("part 2: knows the village's spin, star and glow parts by name", function()
			local parts = Presets.snowglobeFx.parts
			expect(Fx.role(parts.spin, parts)).to.equal("spin")
			expect(Fx.role(parts.star, parts)).to.equal("star")
			expect(Fx.role("CatCafe_Snowglobe_Stall_Glow", parts)).to.equal("light")
			expect(Fx.role("CatCafe_Snowglobe_Set_001_Sky_Glass", parts)).to.equal(nil)
		end)

		it(
			"part 2: night lights go to the star first, then the nearest, spread apart and capped",
			function()
				local spots = {
					{ at = Vector3.new(0, 0, 0), rank = 2, distance = 5 },
					{ at = Vector3.new(2, 0, 0), rank = 2, distance = 6 }, -- too close to the first
					{ at = Vector3.new(50, 0, 0), rank = 1, distance = 40 }, -- the star
					{ at = Vector3.new(20, 0, 0), rank = 2, distance = 20 },
					{ at = Vector3.new(500, 0, 0), rank = 2, distance = 500 }, -- too far
				}
				local picked = Fx.pickLights(spots, 90, 9, 10)
				expect(#picked).to.equal(3)
				expect(picked[1]).to.equal(3)
				expect(picked[2]).to.equal(1)
				expect(picked[3]).to.equal(4)
				expect(#Fx.pickLights(spots, 90, 9, 2)).to.equal(2)
			end
		)
	end)
end
