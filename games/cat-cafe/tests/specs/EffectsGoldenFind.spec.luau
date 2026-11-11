--!strict
-- Effects/GoldenFind (#3222): the Golden find's burst, keyed off LawnService.giveDrop's toast.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local GoldenFind = require(Effects:WaitForChild("GoldenFind")) :: any

	describe("Effects golden find", function()
		it("plays only for the Golden find toast", function()
			expect(GoldenFind.matches("Golden find! The cat left you a Golden Cat Throne.")).to.equal(
				true
			)
			expect(GoldenFind.matches("Golden fish +3")).to.equal(false)
			expect(GoldenFind.matches("golden find! lower case")).to.equal(false)
			expect(GoldenFind.matches(nil)).to.equal(false)
			expect(GoldenFind.matches(42)).to.equal(false)
		end)

		it("stays inside the budgets and under 3 Hz", function()
			local p = Presets.goldenFind
			expect(p.sparkles <= Presets.budget.high.maxBurst).to.equal(true)
			expect(p.confetti <= Presets.confetti.maxLive).to.equal(true)
			expect(p.rings <= 2).to.equal(true)
			expect(p.gap >= 1).to.equal(true)
		end)
	end)
end
