--!strict
-- UI/Components/RescueBangLogic.luau (#2214 add-on, Derek2: "show exclamation mark when someone is doing a rescue
-- also"): the "!" over a rescue spot shows to everyone but the rescuer and the helper while a rescue is on.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local RescueBangLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("RescueBangLogic")
	) :: any
	local ME = 42

	describe("RescueBangLogic", function()
		it("shows nothing at a free spot", function()
			expect(RescueBangLogic.line(0, 0, ME)).to.equal(nil)
			expect(RescueBangLogic.line(nil, nil, ME)).to.equal(nil)
		end)

		it("asks others to come help while someone rescues", function()
			expect(RescueBangLogic.line(7, 0, ME)).to.equal(RescueBangLogic.OPEN)
		end)

		it("says a Team Rescue is on once a helper joined", function()
			expect(RescueBangLogic.line(7, 9, ME)).to.equal(RescueBangLogic.FULL)
		end)

		it("hides it from the rescuer and the helper", function()
			expect(RescueBangLogic.line(ME, 0, ME)).to.equal(nil)
			expect(RescueBangLogic.line(7, ME, ME)).to.equal(nil)
		end)
	end)
end
