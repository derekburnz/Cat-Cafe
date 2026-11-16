--!strict
-- The dragon who lives in the Dragon Keep (#4567, Effects/KeepDragon): which dragon a `dragon` view shows and where
-- he stands. Written by the asset-artist.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local KeepDragon = require(Effects:WaitForChild("KeepDragon")) :: any
	local DragonKeep = require(ReplicatedStorage.Shared.DragonKeep) :: any

	describe("Effects Keep dragon", function()
		it("shows no dragon while the Keep is shut or Cinder has not hatched", function()
			expect(KeepDragon.stageOf(nil)).to.equal(0)
			expect(KeepDragon.stageOf(false)).to.equal(0)
			expect(KeepDragon.stageOf({})).to.equal(0)
			expect(KeepDragon.stageOf({ stage = 0 })).to.equal(0)
			expect(KeepDragon.stageOf({ stage = "3" })).to.equal(0)
			expect(KeepDragon.stageOf({ stage = 0 / 0 })).to.equal(0)
			expect(KeepDragon.assetOf(0)).to.equal(nil)
		end)

		it("shows the dragon of the player's own stage, one model per DragonKeep stage", function()
			for at, row in DragonKeep.STAGES do
				expect(KeepDragon.stageOf({ stage = at })).to.equal(at)
				expect(KeepDragon.assetOf(at)).to.equal("CatCafe_Dragon_" .. row.name)
			end
			expect(KeepDragon.stageOf({ stage = 9 })).to.equal(DragonKeep.MAX_STAGE)
			expect(KeepDragon.stageOf({ stage = 2.7 })).to.equal(2)
		end)

		it(
			"stands him on the yard's paving, the Crowned one forward so his tail clears the wall",
			function()
				for at = 1, DragonKeep.MAX_STAGE do
					local up, forward = KeepDragon.spot(at)
					expect(up > 0 and up < 0.5).to.equal(true)
					expect(forward >= 0 and forward <= 1).to.equal(true)
				end
				local _, crowned = KeepDragon.spot(5)
				local _, elder = KeepDragon.spot(4)
				expect(crowned > elder).to.equal(true)
			end
		)
	end)
end
