--!strict
-- #4920: Effects/RankUpPulse finds the RANK UP buttons it glows.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local RankUpPulse = require(Client:WaitForChild("Effects"):WaitForChild("RankUpPulse")) :: any

	describe("RankUpPulse", function()
		it("glows the strip's button and the Rank Up window's", function()
			expect(RankUpPulse.isRankButton("TutorialBuy")).to.equal(true)
			expect(RankUpPulse.isRankButton("RankUpButton")).to.equal(true)
			expect(RankUpPulse.isRankButton("Tutorial")).to.equal(false)
			expect(RankUpPulse.isRankButton("Buy")).to.equal(false)
		end)

		it(
			"plays the goal card's ready moment only under the switch, for Tier 2, once (#5031)",
			function()
				expect(RankUpPulse.goalDue(true, 1, false)).to.equal(true)
				expect(RankUpPulse.goalDue(nil, 1, false)).to.equal(false) -- off until the store says true
				expect(RankUpPulse.goalDue(false, 1, false)).to.equal(false)
				expect(RankUpPulse.goalDue("true", 1, false)).to.equal(false)
				expect(RankUpPulse.goalDue(true, 2, false)).to.equal(false) -- later tiers keep the RANK UP glow only
				expect(RankUpPulse.goalDue(true, nil, false)).to.equal(false)
				expect(RankUpPulse.goalDue(true, 1, true)).to.equal(false)
			end
		)
	end)
end
