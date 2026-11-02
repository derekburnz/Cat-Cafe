--!strict
-- The leaderboard crown's glint and burst (F98, leaderboards.md section 3). Written by the vfx-animator for QA to
-- move into tests/specs.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects Crown", function()
		it("bursts only when the crown goes from off to on while you watch", function()
			expect(Logic.crownEarned(false, true)).to.equal(true)
			expect(Logic.crownEarned(nil, true)).to.equal(false) -- first seen: a join or this client starting
			expect(Logic.crownEarned(true, true)).to.equal(false)
			expect(Logic.crownEarned(true, false)).to.equal(false)
			expect(Logic.crownEarned(false, false)).to.equal(false)
		end)

		it("glints now and then, a few stars at a time", function()
			local c = Presets.crown
			expect(c.every[1] >= 1 and c.every[1] < c.every[2]).to.equal(true)
			expect(c.glint > 0 and c.glint <= 4).to.equal(true)
			expect(c.spread > 0 and c.spread < 1).to.equal(true) -- round the crown, never off the head
			local glint = Presets.emitters.crownGlint
			expect(glint ~= nil).to.equal(true)
			expect(glint.rate).to.equal(0) -- bursts only
			expect(glint.lifetime[2] < c.every[1]).to.equal(true) -- one glint is gone before the next
		end)

		it("keeps the earned burst inside the phone's budget and in gold", function()
			local e = Presets.crown.earned
			expect(e.sparkles > 0 and e.sparkles <= Presets.budget.low.maxBurst).to.equal(true)
			expect(e.stars > 0 and e.stars <= Presets.budget.low.maxBurst).to.equal(true)
			expect(e.confetti > 0 and e.confetti <= 0.5).to.equal(true)
			expect(e.colour).to.equal(Presets.palette.golden)
			expect(e.ring > 0 and e.ringSeconds > 0).to.equal(true)
		end)

		it("glints on a few crowns at once, fewest in Low performance", function()
			local b = Presets.budget
			expect(b.lowPerformance.crownGlints <= b.low.crownGlints).to.equal(true)
			expect(b.low.crownGlints <= b.high.crownGlints).to.equal(true)
			expect(b.high.crownGlints <= 10).to.equal(true)
			expect(Presets.crown.within <= 80).to.equal(true) -- no glint where the UI hides the crown
		end)
	end)
end
