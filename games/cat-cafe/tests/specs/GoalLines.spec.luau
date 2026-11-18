--!strict
-- UI/Components/GoalLines.luau: the line under the new kinds goal (#4098).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local GoalLines = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GoalLines")
	) :: any

	describe("GoalLines.opens", function()
		it("names the tier and its area on a wide card", function()
			expect(GoalLines.opens("Cozy Cafe", false)).to.equal(
				"Opens Cozy Cafe and the Park 🏆"
			)
		end)
		it("keeps to the tier on a phone's card", function()
			expect(GoalLines.opens("Cozy Cafe", true)).to.equal("Opens Cozy Cafe 🏆")
		end)
		it("says nothing at the top tier", function()
			expect(GoalLines.opens(nil, false)).to.equal(nil)
			expect(GoalLines.opens("", true)).to.equal(nil)
		end)
		it(
			"reads the Rank Up window's noRankOpens switch, off by default (#5218, #5258)",
			function()
				local LiveFlags =
					require(game:GetService("ReplicatedStorage").Shared.LiveFlags) :: any
				expect(GoalLines.NO_OPENS_FLAG).to.equal("noRankOpens")
				expect(LiveFlags.OFF_BY_DEFAULT[GoalLines.NO_OPENS_FLAG]).to.equal(true)
			end
		)
	end)
	describe("GoalLines.coins (#4625)", function()
		local rows = {
			{ short = "Coins", status = "$40 / $1,500", met = false },
			{ short = "Different cats", status = "2 / 5", met = false },
		}
		it("names the coins half of the tier", function()
			expect(GoalLines.coins(rows, false)).to.equal("💰 Coins too: $40 / $1,500")
			expect(GoalLines.coins(rows, true)).to.equal("💰 $40 / $1,500")
		end)
		it("says nothing once the coins are there, or with no tier", function()
			expect(GoalLines.coins({ { short = "Coins", status = "Done", met = true } }, false)).to.equal(
				nil
			)
			expect(GoalLines.coins(nil, true)).to.equal(nil)
		end)
	end)
end
