--!strict
-- #4920: Effects/RankUpPulse finds the RANK UP buttons it glows.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local RankUpPulse = require(Client:WaitForChild("Effects"):WaitForChild("RankUpPulse")) :: any

	describe("RankUpPulse", function()
		it("glows the strip's button and anything reading RANK UP", function()
			expect(RankUpPulse.isRankButton("TutorialBuy", nil)).to.equal(true)
			expect(RankUpPulse.isRankButton("Button", "RANK UP  ·  $1.2K")).to.equal(true)
			expect(RankUpPulse.isRankButton("Label", "Rank up! Tap RANK UP")).to.equal(false)
			expect(RankUpPulse.isRankButton("Buy", "Buy")).to.equal(false)
			expect(RankUpPulse.isRankButton("Buy", nil)).to.equal(false)
		end)
	end)
end
