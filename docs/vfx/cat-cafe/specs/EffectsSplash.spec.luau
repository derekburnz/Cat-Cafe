--!strict
-- Splashes when walking through water (Derek 2026-10-28 01:33): which parts are water, when feet are in it and how
-- often a step splashes. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects water splashes", function()
		it("knows water by its name", function()
			expect(Logic.isWaterName("Water")).to.equal(true)
			expect(Logic.isWaterName("CatCafe_Park_Fountain_Water")).to.equal(true)
			expect(Logic.isWaterName("CatCafe_Sewer_Set_022_DripPuddle_Water")).to.equal(true)
			expect(Logic.isWaterName("CatCafe_Alley_Puddle")).to.equal(true)
			expect(Logic.isWaterName("CatCafe_Woods_Set_011_WaterfallPond")).to.equal(false) -- the pond's rocks
			expect(Logic.isWaterName("Basin")).to.equal(false)
		end)

		it("splashes in the water, not above it, past its edge or on a fountain's rim", function()
			local s = Presets.splash
			expect(Logic.wading(0, 0, 0, 3, 3, false)).to.equal(true) -- on a puddle
			expect(Logic.wading(-1.2, 1, 1, 3, 3, true)).to.equal(true) -- wading in a fountain
			expect(Logic.wading(s.above + 0.1, 0, 0, 3, 3, false)).to.equal(false) -- jumping over
			expect(Logic.wading(-s.depth - 0.1, 0, 0, 3, 3, false)).to.equal(false)
			expect(Logic.wading(0, 3.2, 0, 3, 3, false)).to.equal(false)
			-- a round pool's corner is outside it
			expect(Logic.wading(0, 2.5, 2.5, 3, 3, false)).to.equal(true)
			expect(Logic.wading(0, 2.5, 2.5, 3, 3, true)).to.equal(false)
		end)

		it("splashes once a stride and never banks splashes", function()
			local stride = Presets.splash.stride.player
			local due, carried = Logic.waterStep(0, stride * 0.5, stride)
			expect(due).to.equal(false)
			due, carried = Logic.waterStep(carried, stride * 0.6, stride)
			expect(due).to.equal(true)
			expect(math.abs(carried - stride * 0.1) < 1e-6).to.equal(true)
			due, carried = Logic.waterStep(0, stride * 5, stride)
			expect(due).to.equal(true)
			expect(carried <= stride).to.equal(true)
			expect(Presets.splash.stride.cat < stride).to.equal(true)
			expect(Presets.emitters.splashDrops ~= nil).to.equal(true)
			expect(Presets.emitters.splashDrops.rate).to.equal(0)
		end)
	end)
end
