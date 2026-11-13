--!strict
-- UI/Components/ParkTrailLogic.luau: the goal and paw trail to a first Park catch (#3554).

return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local ParkTrailLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("ParkTrailLogic")
	) :: any

	describe("ParkTrailLogic.due", function()
		it("needs the switch, Tier 2 and no Park cat yet", function()
			expect(ParkTrailLogic.due(true, 2, false)).to.equal(true)
			expect(ParkTrailLogic.due(true, 5, false)).to.equal(true)
			expect(ParkTrailLogic.due(false, 2, false)).to.equal(false)
			expect(ParkTrailLogic.due(true, 1, false)).to.equal(false)
			expect(ParkTrailLogic.due(true, nil, false)).to.equal(false)
			expect(ParkTrailLogic.due(true, 2, true)).to.equal(false)
		end)
	end)

	describe("ParkTrailLogic.phase and goal", function()
		it("sends the player to the Park, then to a Park cat", function()
			expect(ParkTrailLogic.phase(nil)).to.equal("visit")
			expect(ParkTrailLogic.phase("alley")).to.equal("visit")
			expect(ParkTrailLogic.phase("park")).to.equal("catch")
			expect(ParkTrailLogic.goal("visit")).to.equal("Visit the Park 🐾")
			expect(ParkTrailLogic.goal("catch")).to.equal("Catch a Park cat 🐾")
		end)
	end)

	describe("ParkTrailLogic.step", function()
		it("rests after REST_AFTER seconds, walking or not", function()
			local rest = ParkTrailLogic.rest()
			expect(ParkTrailLogic.step(rest, ParkTrailLogic.REST_AFTER - 1, true)).to.equal(true)
			expect(ParkTrailLogic.step(rest, 1, false)).to.equal(false)
			expect(rest.resting).to.equal(true)
		end)

		it("comes back after IDLE_BACK seconds standing still in a row", function()
			local rest = ParkTrailLogic.rest()
			ParkTrailLogic.step(rest, ParkTrailLogic.REST_AFTER, false)
			expect(ParkTrailLogic.step(rest, ParkTrailLogic.IDLE_BACK - 1, false)).to.equal(false)
			expect(ParkTrailLogic.step(rest, 5, true)).to.equal(false) -- a step starts the count again
			expect(ParkTrailLogic.step(rest, ParkTrailLogic.IDLE_BACK - 1, false)).to.equal(false)
			expect(ParkTrailLogic.step(rest, 1, false)).to.equal(true)
			expect(rest.active).to.equal(0)
		end)

		it("gets its full time again at a restart", function()
			local rest = ParkTrailLogic.rest()
			ParkTrailLogic.step(rest, ParkTrailLogic.REST_AFTER, false)
			ParkTrailLogic.restart(rest)
			expect(ParkTrailLogic.step(rest, 1, true)).to.equal(true)
		end)
	end)
end
