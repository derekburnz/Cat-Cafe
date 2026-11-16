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
	end)
end
