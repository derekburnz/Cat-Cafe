--!strict
-- Splashes when walking through water (Derek 2026-10-28 01:33): which parts are water, when feet are in it and how
-- often a step splashes. Written by the vfx-animator; QA moved it into tests/specs and added the edges.
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

	describe("Effects water splashes edges (QA)", function()
		it("reads only names ending in Water or Puddle, capitals as written", function()
			expect(Logic.isWaterName("Puddle")).to.equal(true)
			expect(Logic.isWaterName("CatCafe_Woods_Set_011_WaterfallPond_Water")).to.equal(true)
			expect(Logic.isWaterName("CatCafe_Woods_Stream_Water")).to.equal(true)
			expect(Logic.isWaterName("water")).to.equal(false)
			expect(Logic.isWaterName("CatCafe_Park_WateringCan")).to.equal(false)
			expect(Logic.isWaterName("Waterfall")).to.equal(false)
			expect(Logic.isWaterName("")).to.equal(false)
		end)

		it("counts the edges themselves as in the water", function()
			local s = Presets.splash
			expect(Logic.wading(s.above, 0, 0, 3, 3, false)).to.equal(true)
			expect(Logic.wading(-s.depth, 0, 0, 3, 3, false)).to.equal(true)
			expect(Logic.wading(0, 3, -3, 3, 3, false)).to.equal(true)
			expect(Logic.wading(0, 3, 0, 3, 5, true)).to.equal(true)
			expect(Logic.wading(0, 0, 3.01, 3, 5, true)).to.equal(false) -- a round pool uses the smaller half
		end)

		it("splashes exactly on the stride and carries at most one stride over", function()
			local stride = Presets.splash.stride.player
			local due, carried = Logic.waterStep(0, stride, stride)
			expect(due).to.equal(true)
			expect(carried).to.equal(0)
			due, carried = Logic.waterStep(0, stride * 5, stride)
			expect(due).to.equal(true)
			expect(carried).to.equal(stride)
			due, carried = Logic.waterStep(carried, 0, stride)
			expect(due).to.equal(true) -- the carried stride is the next step, never more than one banked
			expect(carried).to.equal(0)
		end)

		it("matches the effects list's numbers", function()
			local s = Presets.splash
			expect(s.stride.player).to.equal(2.6)
			expect(s.stride.cat).to.equal(1.1)
			expect(s.drops.player).to.equal(5)
			expect(s.drops.cat).to.equal(3)
			expect(s.ripple.player).to.equal(1.8)
			expect(s.ripple.cat).to.equal(1)
			expect(s.rippleSeconds).to.equal(0.5)
			expect(s.maxDistance).to.equal(60)
			expect(s.most.high).to.equal(6)
			expect(s.most.low).to.equal(3)
			expect(s.above).to.equal(0.4)
			expect(s.depth).to.equal(3)
		end)
	end)
end
