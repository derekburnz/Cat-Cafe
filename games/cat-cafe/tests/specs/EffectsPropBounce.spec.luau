--!strict
-- The new areas' Common cats bounce their head prop as they walk (Presets.motion.propBounce, Logic.propBounce;
-- #4069, #4070, #4071). Written by Motion-FX-Agent.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any
	local Catalog = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
	) :: any

	describe("Effects prop bounce on the new areas' commons", function()
		it("names only Common cats the Catalog has, each with a small swing", function()
			for catId, degrees in Presets.motion.propBounce.cats do
				local def = Catalog.catsById[catId]
				expect(def ~= nil).to.equal(true)
				expect(def.rarity).to.equal("Common")
				expect(degrees > 0 and degrees <= 6).to.equal(true)
			end
		end)

		it("stays still while the cat stands and for a cat with none", function()
			local g = Presets.motion.gait
			local still = Logic.blank()
			Logic.propBounce(still, g.moveFrom / 2, 0.4, 5)
			expect(still.capTip).to.equal(0)
			local none = Logic.blank()
			Logic.propBounce(none, 4, 0.4, 0)
			expect(none.capTip).to.equal(0)
		end)

		it("swings both ways with the stride, never past the cat's degrees", function()
			local degrees = 5
			local most, least = 0, 0
			for i = 0, 40 do
				local o = Logic.blank()
				Logic.propBounce(o, 4, i / 40, degrees)
				most = math.max(most, o.capTip)
				least = math.min(least, o.capTip)
			end
			expect(most > 0 and least < 0).to.equal(true)
			expect(most <= math.rad(degrees) + 1e-9).to.equal(true)
			expect(-least <= math.rad(degrees) + 1e-9).to.equal(true)
		end)

		it("adds on top of a cap tip already set", function()
			local o = Logic.blank()
			o.capTip = 0.1
			Logic.propBounce(o, 4, 0.5, 5)
			local alone = Logic.blank()
			Logic.propBounce(alone, 4, 0.5, 5)
			expect(o.capTip).to.be.near(0.1 + alone.capTip, 1e-9)
		end)
	end)
end
