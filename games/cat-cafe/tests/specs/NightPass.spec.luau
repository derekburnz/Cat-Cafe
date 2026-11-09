--!strict
-- NightPass.luau (#2692): a beginner before their first check-in is untouched by the night.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local NightPass = require(Shared.NightPass)
	local Config = require(Shared.Config)

	describe("NightPass", function()
		it("holds until the first check-in moves the tutorial to TutorialGuaranteedStrayStep", function()
			expect(Config.TutorialGuaranteedStrayStep).to.equal(2)
			expect(NightPass.has(0)).to.equal(true)
			expect(NightPass.has(1)).to.equal(true)
			expect(NightPass.has(2)).to.equal(false)
			expect(NightPass.has(5)).to.equal(false)
		end)

		it("opens the areas for its holder only", function()
			expect(NightPass.open(true, false)).to.equal(true)
			expect(NightPass.open(true, true)).to.equal(true)
			expect(NightPass.open(false, true)).to.equal(true)
			expect(NightPass.open(false, false)).to.equal(false)
		end)

		it("names the player attribute the client reads", function()
			expect(NightPass.ATTRIBUTE).to.equal("NightPass")
		end)
	end)
end
