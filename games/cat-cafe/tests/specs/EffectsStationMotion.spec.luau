--!strict
-- The Oasis Spa's floating cats and the Relic Museum's dropping exhibits (#2897): the float stays gentle, a ready cat
-- follows the Spa card's rule, and the drop starts high, lands and settles. Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	describe("Effects station motion", function()
		it("floats a soaking cat gently and keeps it in the water", function()
			local s = Presets.stationMotion
			local most = 0
			for i = 0, 400 do
				local up, roll, turn = Logic.soakBob(i * 0.05, 0.3, false)
				most = math.max(most, math.abs(up))
				expect(math.abs(up) <= s.bob + 1e-9).to.equal(true)
				expect(math.abs(roll) <= math.rad(s.sway) + 1e-9).to.equal(true)
				expect(math.abs(turn) <= math.rad(s.yaw) + 1e-9).to.equal(true)
			end
			expect(most > 0).to.equal(true)
		end)

		it(
			"hops a ready cat for readyLength out of every readyEvery, and never faster than 3 a second",
			function()
				local s = Presets.stationMotion
				expect(s.readyEvery >= 1 / 3).to.equal(true)
				expect(s.readyLength < s.readyEvery).to.equal(true)
				-- phase 0: the hop runs from 0 to readyLength, then it floats as usual until readyEvery
				local hopUp = Logic.soakBob(s.readyLength / 2, 0, true)
				local floatUp = Logic.soakBob(s.readyLength / 2, 0, false)
				expect(hopUp > floatUp).to.equal(true)
				local laterReady = Logic.soakBob(s.readyLength + 0.5, 0, true)
				local laterFloat = Logic.soakBob(s.readyLength + 0.5, 0, false)
				expect(math.abs(laterReady - laterFloat) < 1e-9).to.equal(true)
			end
		)

		it("puts two cats out of step", function()
			local a = Logic.soakBob(1, Logic.phaseOf("SpaSoak_1"), false)
			local b = Logic.soakBob(1, Logic.phaseOf("SpaSoak_2"), false)
			expect(a ~= b).to.equal(true)
		end)

		it("calls a soaker ready by the Spa card's rule", function()
			expect(Logic.soakReady(100, nil, nil, nil)).to.equal(false)
			expect(Logic.soakReady(99, 100, 0, 50)).to.equal(false)
			expect(Logic.soakReady(100, 100, 0, 50)).to.equal(true) -- the first level lands at doneAt
			expect(Logic.soakReady(200, 100, 1, 150)).to.equal(true)
			-- a top-level cat: a state after doneAt still showed no level, so it never gets ready
			expect(Logic.soakReady(200, 100, 0, 150)).to.equal(false)
		end)

		it("drops an exhibit from the top, lands it, bounces once and settles", function()
			local s = Presets.stationMotion
			expect(Logic.dropBounce(0)).to.equal(1)
			expect(Logic.dropBounce(1)).to.equal(0)
			expect(math.abs(Logic.dropBounce(s.dropFall)) < 1e-9).to.equal(true)
			local bounce = Logic.dropBounce(s.dropFall + (1 - s.dropFall) / 2)
			expect(math.abs(bounce - s.dropBounce) < 1e-9).to.equal(true)
			local last = 1
			for i = 1, 10 do
				local h = Logic.dropBounce(s.dropFall * i / 10)
				expect(h <= last).to.equal(true)
				last = h
			end
		end)

		it("keeps the sparkles inside the phone's burst cap", function()
			local s = Presets.stationMotion
			local most = Presets.budget.low.maxBurst
			expect(s.readySparkle <= most).to.equal(true)
			expect(s.dropSparkle <= most).to.equal(true)
			expect(s.rate >= 1 / 60).to.equal(true)
		end)
	end)
end
