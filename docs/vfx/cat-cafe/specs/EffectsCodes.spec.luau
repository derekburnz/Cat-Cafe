--!strict
-- The Codes Cat's circle glow (F65; Derek 2026-10-28 00:47: "too bright and can't see what symbol its showing"): a
-- faint ring round the inside of the rim, never a disc over the middle, so the ticket on the circle stays clear.
-- Written by the vfx-animator for QA to move into tests/specs next to EffectsSignature.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Codes Cat circle glow", function()
		it("keeps the ring at the edge and the middle clear", function()
			local c = Presets.codes
			local inner = c.radius - c.inset - c.ring - c.halo
			-- the modelled ticket reaches about 2.2 studs from the centre of a 4 stud circle
			expect(inner >= c.radius * 0.6).to.equal(true)
			expect(c.inset > 0 and c.ring > 0 and c.halo > 0).to.equal(true)
			expect(c.pixelsPerStud * c.ring >= 2).to.equal(true) -- wide enough to draw
		end)

		it("stays faint, a little brighter while you stand in it", function()
			local c = Presets.codes
			expect(c.glow[1] < 1 and c.glow[2] < c.glow[1]).to.equal(true)
			expect(c.inside < c.glow[2] and c.inside >= 0.2).to.equal(true)
			expect(c.haloShare > 0 and c.haloShare < 1).to.equal(true)
		end)
	end)
end
