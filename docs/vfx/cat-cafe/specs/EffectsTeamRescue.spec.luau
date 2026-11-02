--!strict
-- The Team Rescue pop (F92, playing-together.md section 3): "Team Rescue!" over the trap's spot when a helped rescue
-- frees its cat, with sparkles, rings and a little confetti. Written by the vfx-animator for QA to move into
-- tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Team Rescue", function()
		it("pops a small word over the trap that reads from nearby", function()
			local t = Presets.teamRescue
			expect(t.text).to.equal("Team Rescue!")
			expect(t.width > t.height).to.equal(true)
			expect(t.width <= 6).to.equal(true) -- small, as the spec asks
			expect(t.above > Presets.rescueFree.above).to.equal(true) -- over the rarity pop
			expect(t.popIn < t.seconds / 2).to.equal(true) -- in before it starts to fade
			expect(t.seconds >= 1 and t.seconds <= 2.5).to.equal(true)
			expect(t.rise > 0).to.equal(true)
			expect(t.maxDistance >= 40).to.equal(true)
		end)

		it("bursts in both colours and keeps the confetti small", function()
			local t = Presets.teamRescue
			expect(#t.colours).to.equal(2)
			expect(t.colours[1]).to.equal(Presets.palette.mint)
			expect(t.colours[2]).to.equal(Presets.palette.golden)
			expect(t.textColour).to.equal(Presets.palette.golden)
			expect(t.sparkles > 0 and t.sparkles <= Presets.budget.high.maxBurst).to.equal(true)
			expect(t.confetti > 0 and t.confetti <= 0.5).to.equal(true)
			expect((#t.colours - 1) * t.ringGap + t.ringSeconds < t.seconds).to.equal(true)
		end)
	end)
end
