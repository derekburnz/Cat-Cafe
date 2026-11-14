--!strict
-- #3883: when the map theme bubble by the Feedback tile shows.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("FeedbackCalloutLogic")
	) :: any
	local WAIT = Logic.WAIT_SECONDS

	describe("Map theme bubble", function()
		it("waits for the tutorial to be done and WAIT_SECONDS", function()
			expect(Logic.due(5, nil, 1000, false)).to.equal(false)
			expect(Logic.due(3, 0, 1000, false)).to.equal(false)
			expect(Logic.due(5, 100, 100 + WAIT - 1, false)).to.equal(false)
			expect(Logic.due(5, 100, 100 + WAIT, false)).to.equal(true)
			expect(Logic.due(nil, 100, 100 + WAIT, false)).to.equal(true)
		end)

		it("shows once a join", function()
			expect(Logic.due(5, 100, 100 + WAIT * 3, true)).to.equal(false)
		end)

		it("asks for a map theme and says the name gets featured", function()
			expect(Logic.WORDS:find("map theme", 1, true) ~= nil).to.equal(true)
			expect(Logic.WORDS:find("featured", 1, true) ~= nil).to.equal(true)
			expect(Logic.SHOW_SECONDS <= 30).to.equal(true)
		end)
	end)
end
