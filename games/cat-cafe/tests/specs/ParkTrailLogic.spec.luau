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
			-- #3893: reaching the Park ends it
			expect(ParkTrailLogic.due(true, 2, false, true)).to.equal(false)
			expect(ParkTrailLogic.due(true, 2, false, false)).to.equal(true)
			expect(ParkTrailLogic.reached(false, false)).to.equal(false)
			expect(ParkTrailLogic.reached(true, false)).to.equal(true)
			expect(ParkTrailLogic.reached(false, true)).to.equal(true)
		end)
	end)

	describe("ParkTrailLogic.hoodDue and hoodGoal (#5517)", function()
		it("needs the switch, Tier 3 exactly, no landing and no Neighbourhood cat", function()
			expect(ParkTrailLogic.hoodDue(true, 3, false, false)).to.equal(true)
			expect(ParkTrailLogic.hoodDue(false, 3, false, false)).to.equal(false)
			expect(ParkTrailLogic.hoodDue(true, 2, false, false)).to.equal(false)
			expect(ParkTrailLogic.hoodDue(true, 4, false, false)).to.equal(false)
			expect(ParkTrailLogic.hoodDue(true, nil, false, false)).to.equal(false)
			expect(ParkTrailLogic.hoodDue(true, 3, true, false)).to.equal(false)
			expect(ParkTrailLogic.hoodDue(true, 3, false, true)).to.equal(false)
		end)
		it("says when the Neighbourhood opens at night, and is shorter on a narrow card", function()
			expect(ParkTrailLogic.hoodGoal(false, false)).to.equal("Visit the Neighbourhood 🐾")
			expect(ParkTrailLogic.hoodGoal(false, true)).to.equal("Visit Neighbourhood 🐾")
			expect(ParkTrailLogic.hoodGoal(true, false)).to.equal("Neighbourhood opens at sunrise")
			expect(ParkTrailLogic.hoodGoal(true, true)).to.equal("Neighbourhood opens at sunrise")
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

		it(
			"comes back after BACK_AFTER seconds while walking, only with the switch on (#5045)",
			function()
				local rest = ParkTrailLogic.rest()
				ParkTrailLogic.step(rest, ParkTrailLogic.REST_AFTER, true)
				expect(rest.resting).to.equal(true)
				-- switch off: walking keeps it resting however long
				expect(ParkTrailLogic.step(rest, ParkTrailLogic.BACK_AFTER * 4, true)).to.equal(
					false
				)
				local on = ParkTrailLogic.rest()
				ParkTrailLogic.step(on, ParkTrailLogic.REST_AFTER, true)
				expect(ParkTrailLogic.step(on, ParkTrailLogic.BACK_AFTER - 1, true, true)).to.equal(
					false
				)
				expect(ParkTrailLogic.step(on, 1, true, true)).to.equal(true)
				expect(on.active).to.equal(0)
				expect(on.off).to.equal(0)
				-- and rests again after its full time
				expect(ParkTrailLogic.step(on, ParkTrailLogic.REST_AFTER - 1, true, true)).to.equal(
					true
				)
				expect(ParkTrailLogic.step(on, 1, true, true)).to.equal(false)
				expect(on.off).to.equal(0)
			end
		)

		it("gets its full time again at a restart", function()
			local rest = ParkTrailLogic.rest()
			ParkTrailLogic.step(rest, ParkTrailLogic.REST_AFTER, false)
			ParkTrailLogic.restart(rest)
			expect(ParkTrailLogic.step(rest, 1, true)).to.equal(true)
		end)
	end)
end
