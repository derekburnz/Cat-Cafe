--!strict
-- The opened crate on the Market counter (F53): which model each crate shows and how its lid swings. Written by the
-- vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects crate on the counter", function()
		it("names each crate's model and its golden twin", function()
			expect(Logic.crateModelName("alley", false)).to.equal("CatCafe_Prop_Crate_Alley")
			expect(Logic.crateModelName("neighbourhood", false)).to.equal(
				"CatCafe_Prop_Crate_Neighbourhood"
			)
			expect(Logic.crateModelName("classic", true)).to.equal(
				"CatCafe_Prop_Crate_Classic_Gold"
			)
			expect(Logic.crateModelName("sewer", nil)).to.equal("CatCafe_Prop_Crate_Sewer")
			expect(Logic.crateModelName("", false) == nil).to.equal(true)
			expect(Logic.crateModelName(nil, true) == nil).to.equal(true)
		end)

		it("swings the lid open quickly and never past wide open", function()
			local c = Presets.marketCrate
			expect(Logic.lidAngle(0, c.lidSeconds, c.lidDegrees)).to.equal(0)
			expect(
				Logic.lidAngle(c.lidSeconds * 0.5, c.lidSeconds, c.lidDegrees) > c.lidDegrees * 0.5
			).to.equal(true)
			expect(Logic.lidAngle(c.lidSeconds, c.lidSeconds, c.lidDegrees)).to.equal(c.lidDegrees)
			expect(Logic.lidAngle(c.lidSeconds * 4, c.lidSeconds, c.lidDegrees)).to.equal(
				c.lidDegrees
			)
			expect(Logic.lidAngle(0, 0, c.lidDegrees)).to.equal(c.lidDegrees)
			expect(c.lidDegrees <= 105).to.equal(true) -- crates.py: wide open with no clipping
			expect(c.hold > c.lidSeconds).to.equal(true)
		end)
	end)
end
