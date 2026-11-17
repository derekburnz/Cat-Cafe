--!strict
-- #4913 Pal Day's moment (Effects/PalDayFx): its numbers stay small and in reach of the hearts. Written by the
-- vfx-animator. (PalDayFx itself needs the avatar rig, which cloud tests do not have; Studio checks the moment.)
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Presets = require(Client:WaitForChild("Effects"):WaitForChild("Presets")) :: any

	describe("Effects Pal Day", function()
		it("keeps its numbers small and inside the hearts' reach", function()
			local p = Presets.palDay
			expect(p.range <= Presets.petCat.range).to.equal(true)
			expect(p.palDelay > 0 and p.palDelay < 1).to.equal(true)
			expect(p.most >= 1 and p.most <= 20).to.equal(true)
			expect(p.overHead >= 0 and p.up > 0).to.equal(true)
			expect(p.colour).to.equal(Presets.petCat.colour)
		end)

		it("keeps the hearts over pals few, still and in reach (#4913)", function()
			local h = Presets.palDay.heart
			expect(h.most >= 1 and h.most <= 4).to.equal(true) -- Design: at most 4 BillboardGuis
			expect(h.range <= Presets.palDay.range).to.equal(true)
			expect(h.every >= 0.25).to.equal(true)
			expect(type(h.due)).to.equal("string")
			expect(#h.glyph > 0).to.equal(true)
		end)
	end)
end
