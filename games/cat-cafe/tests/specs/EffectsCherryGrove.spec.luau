--!strict
-- Cherry Blossom Grove's ambience rows (#4386, a future area with id "cherry"): petals in the air, a stray puff, a
-- catch touch, a cannon tint, koi ripples on its pond and the falls' running water (RuinsWater), all inside the budgets the other areas keep.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local AreaWater = require(Effects:WaitForChild("AreaWater")) :: any
	local RuinsWater = require(Effects:WaitForChild("RuinsWater")) :: any

	describe("Effects Cherry Blossom Grove", function()
		it("has thin petals in the air, a stray puff and a cannon tint", function()
			local spec = Presets.areaFx.areas.cherry
			expect(spec).to.be.ok()
			local air = Presets.emitters[spec.air]
			expect(air).to.be.ok()
			expect(air.rate <= 14).to.equal(true) -- no thicker than the snow
			expect(air.size[1] <= 0.25).to.equal(true)
			expect(Presets.emitters[spec.puffPreset]).to.be.ok()
			expect(Presets.cannon.tints.cherry).to.be.ok()
		end)

		it("makes a catch there bigger as the cat gets rarer", function()
			local function size(rarity: string): number
				local plan = Logic.catchFlavour("cherry", "some_cat", rarity)
				return plan.puff + plan.flakes + plan.ringScale * 10 + plan.gusts * 10
			end
			expect(size("Epic") > size("Rare")).to.equal(true)
			expect(size("Legendary") > size("Epic")).to.equal(true)
			expect(size("Mythical") > size("Legendary")).to.equal(true)
		end)

		it("reads the blockout's pond as water with slow ripples", function()
			local kind = AreaWater.kindOf("CatCafe_Cherry_Set_003_Pond_Water")
			expect(kind).to.be.ok()
			expect(kind.piece).to.equal("Pond")
			expect(kind.ringEvery >= 1).to.equal(true) -- far under 3 a second
			expect(AreaWater.kindOf("CatCafe_Cherry_Set_004_Petals_Decor")).to.equal(nil)
		end)

		it("leaves the blockout's falls to RuinsWater, so they get one mist, not two", function()
			-- Model-Agent's #4423 eaff71fe6: the three falls are their own object
			local falls = "CatCafe_Cherry_Set_005_Waterfall_Water"
			expect(RuinsWater.isWater(falls)).to.equal(true) -- streaks, mist at the foot and rings
			local kind = AreaWater.kindOf(falls)
			expect(kind == nil or kind.mist == nil).to.equal(true)
		end)
	end)
end
