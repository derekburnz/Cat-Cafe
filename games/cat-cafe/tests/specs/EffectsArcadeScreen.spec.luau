--!strict
-- The Cat Arcade attract screen's loop pattern. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local ArcadeScreen = require(Effects:WaitForChild("ArcadeScreen")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Cat Arcade attract screen", function()
		it("never pops the same hole twice running, bops and golds on their beats", function()
			local p = Presets.arcadeScreen
			local last = nil
			local bops, golds = 0, 0
			for n = 0, 41 do
				local hole, kind, bop = ArcadeScreen.beatAt(n, p.holes, p)
				expect(hole >= 1 and hole <= p.holes).to.equal(true)
				expect(hole ~= last).to.equal(true)
				last = hole
				if bop then
					bops += 1
				end
				if kind == "GoldMouse" then
					golds += 1
				end
			end
			expect(bops).to.equal(42 // p.bopEvery)
			expect(golds).to.equal(42 // p.goldEvery)
		end)

		it("draws only pictures on Mouse Dash's sheet", function()
			local p = Presets.arcadeScreen
			for _, name in
				{ "Mouse", "MouseHit", "GoldMouse", "GoldMouseHit", "Hole", "Dust", "Paw", "PawBop" }
			do
				expect(p.cells[name] ~= nil).to.equal(true)
			end
		end)
	end)
end
