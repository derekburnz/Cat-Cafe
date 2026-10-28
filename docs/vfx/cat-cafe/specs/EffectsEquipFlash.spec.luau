--!strict
-- The green flash on decor you just put out (Derek 2026-10-28 01:25): which pieces a ProfileSync newly put in use,
-- what flashes for each kind and that the flash is brief. Written by the vfx-animator for QA to move into
-- tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects decor equip flash", function()
		it("flashes only the pieces newly in use, never on the first sync", function()
			expect(#Logic.newlyPlaced(nil, { rug = true, plants = true })).to.equal(0)
			expect(#Logic.newlyPlaced({ rug = true }, nil)).to.equal(0)
			local ids = Logic.newlyPlaced(
				{ rug = true },
				{ rug = true, plants = true, lamp = true }
			)
			expect(#ids).to.equal(2)
			expect(ids[1]).to.equal("lamp")
			expect(ids[2]).to.equal("plants")
			-- putting a piece away flashes nothing; putting it back out flashes it again
			expect(#Logic.newlyPlaced({ rug = true, plants = true }, { rug = true })).to.equal(0)
			local again = Logic.newlyPlaced({ rug = true }, { rug = true, plants = true })
			expect(#again).to.equal(1)
			expect(again[1]).to.equal("plants")
			expect(#Logic.newlyPlaced({}, { rug = false })).to.equal(0)
		end)

		it("flashes the model, or the floor for a floor style, never wallpaper or paint", function()
			expect(Logic.equipTarget(nil)).to.equal("piece")
			expect(Logic.equipTarget("furniture")).to.equal("piece")
			expect(Logic.equipTarget("decoration")).to.equal("piece")
			expect(Logic.equipTarget("floor")).to.equal("floor")
			expect(Logic.equipTarget("wallpaper") == nil).to.equal(true)
			expect(Logic.equipTarget("paint") == nil).to.equal(true)
		end)

		it("is a brief flash within the Highlight limit", function()
			local e = Presets.equipFlash
			local seconds = e.fadeIn + e.hold + e.fade
			expect(seconds >= 1 and seconds <= 2.5).to.equal(true)
			expect(e.fill > 0 and e.fill < 1).to.equal(true)
			expect(e.most >= 1 and e.most <= 8).to.equal(true)
			expect(e.wait > 0).to.equal(true)
		end)
	end)
end
