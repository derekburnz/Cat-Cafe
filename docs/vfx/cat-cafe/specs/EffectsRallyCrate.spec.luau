--!strict
-- The Rally Crate's pieces (F101, Model-Agent's #766): its Mythical Trophy Gold paint gets Gold Leaf's look, and the
-- Rally Crate opens at the counter as the others do. Written by the vfx-animator for QA to move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Rally Crate", function()
		it("glints Trophy Gold like Gold Leaf and finds the Rally Crate's model", function()
			local trophy = Presets.decor.rally_trophy_gold
			local leaf = Presets.decor.classic_gold_leaf
			expect(trophy ~= nil).to.equal(true)
			expect(trophy.look).to.equal(leaf.look)
			expect(trophy.on).to.equal("Paint")
			expect(trophy.emitter).to.equal(leaf.emitter)
			expect(Presets.emitters[trophy.emitter].rate <= 2).to.equal(true)
			-- a crate whose area is "rally" opens Model-Agent's CatCafe_Prop_Crate_Rally
			expect(Logic.crateModelName("rally", false)).to.equal("CatCafe_Prop_Crate_Rally")
		end)
	end)
end
