--!strict
-- Effects/TrailSparkle (#3022): sparkles on every few of the guide trail's dots, inside the budget.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local TrailSparkle = require(Effects:WaitForChild("TrailSparkle")) :: any

	describe("Effects trail sparkle", function()
		it("lights every few dots, the first one first", function()
			expect(TrailSparkle.carries(1, 4, false)).to.equal(true)
			expect(TrailSparkle.carries(2, 4, false)).to.equal(false)
			expect(TrailSparkle.carries(5, 4, false)).to.equal(true)
			expect(TrailSparkle.carries(3, 2, false)).to.equal(true)
		end)

		it("is off in Low performance", function()
			expect(TrailSparkle.carries(1, 2, true)).to.equal(false)
		end)

		it("stays within the phone budget", function()
			local p = Presets.trailSparkle
			-- GuideTrail lays at most 48 dots
			local live = math.ceil(48 / p.everyLow) * Presets.emitters[p.emitter].rate
			expect(live <= 24).to.equal(true)
			expect(p.everyLow >= p.every).to.equal(true)
			expect(p.folder).to.equal("CatCafeTutorialTrail")
		end)
	end)
end
