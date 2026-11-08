--!strict
-- The green flash on decor you just put out (Derek 2026-10-28 01:25): which pieces a ProfileSync newly put in use,
-- what flashes for each kind and that the flash is brief. Written by the vfx-animator; QA moved it into tests/specs
-- and added the edges.
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

	describe("Effects decor equip flash edges (QA)", function()
		it("flashes only string ids marked exactly true, each once and sorted", function()
			local current = { [1] = true, rug = "yes", lamp = 1, plants = true, bench = true, arch = true } :: any
			local ids = Logic.newlyPlaced({ bench = false }, current)
			expect(#ids).to.equal(3)
			expect(ids[1]).to.equal("arch")
			expect(ids[2]).to.equal("bench")
			expect(ids[3]).to.equal("plants")
		end)

		it("flashes nothing for a sync that changed nothing or held no table", function()
			local same = { rug = true, lamp = true }
			expect(#Logic.newlyPlaced(same, same)).to.equal(0)
			expect(#Logic.newlyPlaced("rug", { rug = true })).to.equal(0)
			expect(#Logic.newlyPlaced({}, "rug")).to.equal(0)
			expect(#Logic.newlyPlaced({}, {})).to.equal(0)
		end)

		it("flashes a model for any kind but floor, wallpaper and paint", function()
			for _, kind in { "rug", "table", "door", "catflap", "", "Floor" } do
				expect(Logic.equipTarget(kind)).to.equal("piece")
			end
		end)

		it("matches the effects list: 0.15 s in, 0.6 s held, 0.75 s out, 4 at once within 150 studs", function()
			local e = Presets.equipFlash
			expect(e.fadeIn).to.equal(0.15)
			expect(e.hold).to.equal(0.6)
			expect(e.fade).to.equal(0.75)
			expect(e.most).to.equal(4)
			expect(e.maxDistance).to.equal(150)
			expect(e.wait).to.equal(3)
		end)
	end)
end
