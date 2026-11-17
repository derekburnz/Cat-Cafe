--!strict
-- The Cannon button's glow while Tier 2 is short of cats (Design-Agent 2026-11-17, the phone drop between the bowl
-- cat's tame and the rank up): when it glows, and that it stays behind its own switch. Written by the vfx-animator.
return function()
	local Effects = game:GetService("StarterPlayer")
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("Client")
		:WaitForChild("Effects")
	local CannonCue = require(Effects:WaitForChild("CannonCue")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Cannon cue after the bowl cat", function()
		it(
			"glows only with the switch exactly on, cats short, in the hometown, before a press",
			function()
				expect(CannonCue.due(true, 1, nil, false)).to.equal(true)
				expect(CannonCue.due(true, 2, "Cafe", false)).to.equal(true)
				expect(CannonCue.due(nil, 1, nil, false)).to.equal(false)
				expect(CannonCue.due(false, 1, nil, false)).to.equal(false)
				expect(CannonCue.due("true", 1, nil, false)).to.equal(false)
				expect(CannonCue.due(true, 0, nil, false)).to.equal(false)
				expect(CannonCue.due(true, nil, nil, false)).to.equal(false)
				expect(CannonCue.due(true, 1, "Alley", false)).to.equal(false)
				expect(CannonCue.due(true, 1, "Park", false)).to.equal(false)
				expect(CannonCue.due(true, 1, nil, true)).to.equal(false)
			end
		)

		it("keeps a calm pace behind its own switch", function()
			local c = Presets.cannonCue
			expect(c.flag).to.equal("cannonCue")
			expect(c.every >= 3).to.equal(true)
			expect(c.calmEvery >= c.every).to.equal(true)
			expect(type(Presets.rankUpPulse.displayOrder)).to.equal("number")
		end)
	end)
end
