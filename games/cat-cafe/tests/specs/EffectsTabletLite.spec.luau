--!strict
-- #5686 tabletLite: a struggling tablet gets fewer particles and lighter glows. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("tabletLite", function()
		local side = Presets.tabletLite.minSide

		it("calls an iPad sized touch screen a tablet, not a phone or a PC", function()
			expect(Logic.isTablet("low", Vector2.new(1024, 768), side)).to.equal(true)
			expect(Logic.isTablet("low", Vector2.new(844, 390), side)).to.equal(false)
			expect(Logic.isTablet("high", Vector2.new(1920, 1080), side)).to.equal(false)
		end)

		it("gives a struggling tablet the tabletLite budget only with the switch on", function()
			local _, on = Logic.budgetFor("low", false, false, true, true)
			expect(on).to.equal(Presets.budget.tabletLite)
			local _, off = Logic.budgetFor("low", false, false, true, false)
			expect(off).to.equal(Presets.budget.lite)
			local _, fine = Logic.budgetFor("low", false, false, false, true)
			expect(fine).to.equal(Presets.budget.low)
			local _, lowPerf = Logic.budgetFor("low", true, false, true, true)
			expect(lowPerf).to.equal(Presets.budget.lowPerformance)
		end)

		it("is lighter than lite and has every budget field", function()
			local lite, tab = Presets.budget.lite, Presets.budget.tabletLite
			for key, value in lite do
				expect(type(tab[key])).to.equal(type(value))
				expect(tab[key] <= value).to.equal(true)
			end
			expect(tab.rateScale < lite.rateScale).to.equal(true)
			expect(tab.maxBurst < lite.maxBurst).to.equal(true)
			expect(tab.rainbowOutlines).to.equal(0)
		end)

		it("watches tablets on a higher fps line than phones", function()
			expect(Presets.tabletLite.slow.fps > Presets.slow.fps).to.equal(true)
		end)
	end)
end
