--!strict
-- The Dragon Keep's set looks (Effects/KeepSets): reading the DragonSets attribute and the level 5 scale. Written by
-- the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local KeepSets = require(Effects:WaitForChild("KeepSets")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Dragon Keep set looks", function()
		it("reads each lit family and its level from the attribute", function()
			local sets = KeepSets.parse("flame5,claw3,wing3")
			expect(sets.flame).to.equal(5)
			expect(sets.claw).to.equal(3)
			expect(sets.wing).to.equal(3)
			expect(sets.hoard).to.equal(nil)
			expect(next(KeepSets.parse(nil))).to.equal(nil)
			expect(next(KeepSets.parse(""))).to.equal(nil)
			expect(next(KeepSets.parse("dragon5,flame2"))).to.equal(nil)
			expect(KeepSets.parse("crown7").crown).to.equal(5)
			expect(KeepSets.parse(" heart3 , heart5").heart).to.equal(5)
		end)

		it("has a look for every family, bigger at level 5", function()
			for _, family in { "flame", "claw", "wing", "hoard", "heart", "crown" } do
				local name = Presets.dragonSets.families[family]
				expect(Presets.emitters[name] ~= nil).to.equal(true)
			end
			local rate3, size3 = KeepSets.scale(3)
			local rate5, size5 = KeepSets.scale(5)
			expect(rate3).to.equal(1)
			expect(size3).to.equal(1)
			expect(rate5 > rate3 and size5 > size3).to.equal(true)
			expect(rate5 <= 2 and size5 <= 1.5).to.equal(true)
		end)
	end)
end
