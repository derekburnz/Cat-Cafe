--!strict
-- The Speed Shoes' trail (#3523, Effects/SpeedShoes): it shows only on a wearer who carries a cat on the move with
-- feet on the ground, and it is a thin, steady stream inside the phone's budget. Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Logic = require(Effects:WaitForChild("Logic")) :: any

	describe("Effects speed shoes trail", function()
		it("runs only for a wearer carrying a cat on the move", function()
			local least = Presets.speedShoes.moving
			expect(Logic.shoeTrailOn(true, true, 1, true, least)).to.equal(true)
			-- the shoes only speed up carrying: no cat, no trail
			expect(Logic.shoeTrailOn(true, false, 1, true, least)).to.equal(false)
			-- no shoes, no trail
			expect(Logic.shoeTrailOn(false, true, 1, true, least)).to.equal(false)
			-- standing still, or barely leaning on the stick
			expect(Logic.shoeTrailOn(true, true, 0, true, least)).to.equal(false)
			expect(Logic.shoeTrailOn(true, true, least / 2, true, least)).to.equal(false)
			expect(Logic.shoeTrailOn(true, true, least, true, least)).to.equal(true)
			-- in the air (a jump, a cannon flight): no puffs at the heels
			expect(Logic.shoeTrailOn(true, true, 1, false, least)).to.equal(false)
			expect(Logic.shoeTrailOn(true, true, 0 / 0, true, least)).to.equal(false)
		end)

		it("is a thin steady stream that reads apart from the Swift Potion's wisps", function()
			local trail = Presets.emitters.shoeTrail
			local swift = Presets.emitters.potionSwift
			expect(trail ~= nil).to.equal(true)
			-- on screen at once: rate times the longest life, well inside one burst of the phone's cap
			expect(trail.rate * trail.lifetime[2] <= Presets.budget.low.maxBurst).to.equal(true)
			-- small puffs that fade right out and shrink, shorter lived than the potion's
			expect(trail.size[1] <= 0.8 and trail.size[2] < trail.size[1]).to.equal(true)
			expect(trail.transparency[2]).to.equal(1)
			expect(trail.lifetime[2] < swift.lifetime[2]).to.equal(true)
			-- not the potion's blues
			expect(trail.colors[1]).never.to.equal(swift.colors[1])
		end)

		it("is checked often enough to stop with the player and shown near you only", function()
			local p = Presets.speedShoes
			expect(p.pickEvery <= 0.3).to.equal(true)
			expect(p.radius <= Presets.potionFx.radius).to.equal(true)
			expect(p.moving > 0 and p.moving < 1).to.equal(true)
			expect(p.model).to.equal("CatCafe_Item_SpeedShoes")
			-- Low performance shows no trails only because its potionGlows budget is 0 (the trail shares that count):
			-- if that budget is ever raised, give the trail its own switch
			expect(Presets.budget.low.potionGlows >= 1).to.equal(true)
			expect(Presets.budget.lowPerformance.potionGlows).to.equal(0)
		end)
	end)
end
