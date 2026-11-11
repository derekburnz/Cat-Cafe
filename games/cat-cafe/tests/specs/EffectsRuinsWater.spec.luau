--!strict
-- Effects/RuinsWater (#3257): the Ruins waterfall and fountain run inside the budget and find their sheets.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local RuinsWater = require(Effects:WaitForChild("RuinsWater")) :: any

	describe("Effects Ruins water", function()
		it("finds the waterfall and fountain water by name", function()
			expect(RuinsWater.isWater("CatCafe_Ruins_Set_166_Waterfall_Water")).to.equal(true)
			expect(RuinsWater.isWater("CatCafe_Ruins_Set_089_Fountain_Water")).to.equal(true)
			expect(RuinsWater.isWater("CatCafe_Ruins_Set_166_Waterfall_Decor")).to.equal(false)
			expect(RuinsWater.isWater("_Waterfall_Water")).to.equal(false)
		end)

		it("takes tall thin parts as falling sheets, not the pool", function()
			local up = Vector3.new(0, 1, 0) -- standing as built
			local flat = Vector3.new(1, 0, 0) -- turned 90 degrees, its X axis pointing up
			expect(RuinsWater.isSheet(up, Vector3.new(2.6, 11.1, 0.3))).to.equal(true)
			expect(RuinsWater.isSheet(up, Vector3.new(0.14, 3.51, 0.9))).to.equal(true)
			-- the spout pipes are short; the pool disc lies flat
			expect(RuinsWater.isSheet(up, Vector3.new(0.22, 1.1, 0.22))).to.equal(false)
			expect(RuinsWater.isSheet(flat, Vector3.new(0.46, 12.1, 12.1))).to.equal(false)
			expect(
				math.abs(RuinsWater.halfHeight(flat, Vector3.new(0.46, 12.1, 12.1)) - 0.23) < 1e-3
			).to.equal(true)
		end)

		it("shares one mist between feet close together, at the lowest", function()
			local feet = RuinsWater.feet({
				Vector3.new(56.8, 0.5, 6),
				Vector3.new(56.58, 1.3, 6.3),
				Vector3.new(56.58, 2.1, 6.95),
				Vector3.new(0, 0.6, 236),
			})
			expect(#feet).to.equal(2)
			expect(feet[1].Y).to.equal(0.5)
		end)

		it("stays inside every budget", function()
			for _, tier in { "low", "high", "console", "lowPerformance" } do
				local b = Presets.budget[tier]
				expect(b.waterfalls >= 1 and b.waterfalls <= 3).to.equal(true)
			end
			expect(Presets.budget.lowPerformance.waterfalls <= Presets.budget.low.waterfalls).to.equal(
				true
			)
			local p = Presets.ruinsWater
			expect(Presets.emitters[p.streaks]).to.be.ok()
			expect(Presets.emitters[p.mist]).to.be.ok()
			expect(1 / p.rippleEvery < 3).to.equal(true)
		end)
	end)
end
