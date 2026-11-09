--!strict
-- UI/Components/CozyLogic.luau: the Cozy Cafe line on the Rewards list (#2798).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CozyLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CozyLogic")
	) :: any

	describe("CozyLogic.line", function()
		it("counts down to the next bag while you stay in your cafe", function()
			local line, ready = CozyLogic.line(true, 1130, 0, 1000)
			expect(line).to.equal("Cozy gift in 2:10")
			expect(ready).to.equal(false)
			expect((CozyLogic.line(true, 900, 0, 1000))).to.equal("Cozy gift in 0:00")
		end)

		it("says a bag waits, in the cafe or out of it", function()
			local line, ready = CozyLogic.line(false, nil, 990, 1000)
			expect(line).to.equal(CozyLogic.WAITING)
			expect(ready).to.equal(true)
		end)

		it("says nothing outside the cafe with no bag, or from a server without it", function()
			expect((CozyLogic.line(false, nil, 0, 1000))).to.equal(nil)
			expect((CozyLogic.line(nil, nil, nil, 1000))).to.equal(nil)
			expect((CozyLogic.line(true, nil, 0, 1000))).to.equal(nil)
			expect((CozyLogic.line(true, 0, 0, 1000))).to.equal(nil) -- the timer stopped (today's cap)
		end)
	end)
end
