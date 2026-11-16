--!strict
-- Harvest Hollow's strays (#4251): a puff where they come and go and the area's own touch on a catch, in budget.
-- The area's id is "harvest" (IndexRewards.HARVEST_AREA, the strays' `Area` attribute). Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Logic = require(Effects:WaitForChild("Logic")) :: any

	describe("Effects Harvest Hollow strays", function()
		it("puffs in the area's colour where a stray comes and goes", function()
			local spec = Presets.areaFx.areas.harvest
			expect(spec).to.be.ok()
			expect(Presets.emitters[spec.puffPreset]).to.be.ok()
			expect(Presets.emitters[spec.air]).to.be.ok()
			expect(spec.puff <= Presets.budget.low.maxBurst).to.equal(true)
		end)

		it("makes a catch there bigger as the cat gets rarer", function()
			local spec = Presets.catchFlavour.areas.harvest
			expect(Presets.emitters[spec.preset]).to.be.ok()
			local function size(cat: string, rarity: string): number
				local plan = Logic.catchFlavour("harvest", cat, rarity)
				return plan.puff + plan.flakes + plan.ringScale * 10 + plan.gusts * 10
			end
			expect(size("hay_bale", "Common")).to.equal(size("apple_pie", "Rare"))
			expect(size("some_cat", "Epic") > size("some_cat", "Rare")).to.equal(true)
			expect(size("some_cat", "Legendary") > size("some_cat", "Epic")).to.equal(true)
			expect(size("some_cat", "Mythical") > size("some_cat", "Legendary")).to.equal(true)
			expect(size("harvest_moon", "Mythical") > size("some_cat", "Mythical")).to.equal(true)
			expect(spec.gustEvery >= 0.1).to.equal(true) -- quick, never a flicker
		end)
	end)
end
