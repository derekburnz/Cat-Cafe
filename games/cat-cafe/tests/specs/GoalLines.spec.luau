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
	end)
end
