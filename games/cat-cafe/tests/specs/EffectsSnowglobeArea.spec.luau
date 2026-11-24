--!strict
-- #5704: Snowglobe Village's catch flavour, stray puffs and steps in the snow. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Snowglobe Village effects", function()
		it("gives a village catch its own flavour, a taller column for Star Topper", function()
			local common = Logic.catchFlavour("snowglobe", "snowball", "Common")
			expect(common).never.to.equal(nil)
			expect(common.gusts).to.equal(0)
			local mythical = Logic.catchFlavour("snowglobe", "snowball", "Mythical")
			expect(mythical.gusts).to.equal(Presets.catchFlavour.areas.snowglobe.gusts)
			local star = Logic.catchFlavour("snowglobe", "star_topper", "Mythical")
			expect(star.gusts > mythical.gusts).to.equal(true)
		end)

		it("puffs where its strays come and go and kicks snow at your feet", function()
			local spec = Presets.areaFx.areas.snowglobe
			expect(spec).never.to.equal(nil)
			expect(spec.footPuff > 0).to.equal(true)
		end)

		it("counts your steps in the village by its middle, and only when it is given", function()
			local within = Presets.snowglobeFx.airWithin
			expect(Logic.walkArea(nil, nil, 130, 20, within)).to.equal("snowglobe")
			expect(Logic.walkArea(nil, nil, 130, within + 1, within)).to.equal(nil)
			expect(Logic.walkArea(nil, nil, 130, nil, within)).to.equal(nil)
			expect(Logic.walkArea(nil, 40, 130, 20, within)).to.equal("harvest")
			expect(Logic.walkArea("snowy", nil, 130, 20, within)).to.equal("snowy")
			expect(Presets.snowglobeFx.flag).to.equal("christmasEvent")
		end)
	end)
end
