--!strict
-- The getaway and the startled stars (F55, F57) and the areas closing at dusk and opening at sunrise (F66): when a
-- timed character state is new, how long it runs, what an AreasOpen change means and that the new bursts fit the
-- budgets. Written by the vfx-animator for QA to move into tests/specs next to EffectsLogic.spec.luau.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any
	local Presets = require(Effects:WaitForChild("Presets")) :: any

	local function fits(count: number, budget: any): boolean
		return math.clamp(math.floor(count * budget.burstScale + 0.5), 1, budget.maxBurst) <= 12
	end

	describe("Effects chase and night", function()
		it("starts a rush or a startle once and runs it to its end", function()
			local now = 1000
			-- a first rush, and one after the last ran out, are new
			local left, fresh = Logic.timedState(now + 5, nil, now, 30)
			expect(left).to.equal(5)
			expect(fresh).to.equal(true)
			left, fresh = Logic.timedState(now + 5, now - 20, now, 30)
			expect(left == 5 and fresh == true).to.equal(true)
			-- moving the end of one still running is not a new one
			left, fresh = Logic.timedState(now + 4, now + 2, now, 30)
			expect(left == 4 and fresh == false).to.equal(true)
			-- a character seen mid-rush gets the rest of it without the start
			left, fresh = Logic.timedState(now + 3, now + 3, now, 30)
			expect(left == 3 and fresh == false).to.equal(true)
		end)

		it(
			"plays nothing for a state that is over or not a time, and cuts one far ahead",
			function()
				local now = 1000
				for _, ends in { now, now - 1, 0, "soon", true } do
					local left, fresh = Logic.timedState(ends, nil, now, 30)
					expect(left == 0 and fresh == false).to.equal(true)
				end
				local left = Logic.timedState(now + 500, nil, now, Presets.chase.longest)
				expect(left).to.equal(Presets.chase.longest)
			end
		)

		it("reads dusk and sunrise from AreasOpen, never the first value it sees", function()
			expect(Logic.areasTurn(true, false)).to.equal("dusk")
			expect(Logic.areasTurn(false, true)).to.equal("sunrise")
			expect(Logic.areasTurn(nil, true)).to.equal(nil)
			expect(Logic.areasTurn(nil, false)).to.equal(nil)
			expect(Logic.areasTurn(true, true)).to.equal(nil)
			expect(Logic.areasTurn(true, nil)).to.equal(nil)
			expect(Logic.areasTurn(1, 0)).to.equal(nil)
		end)

		it(
			"spreads the getaway ring as far as the push and keeps the new effects in budget",
			function()
				-- CatchBurstRadiusStuds is 10 (data-model section 10c)
				expect(Presets.chase.ringDiameter).to.equal(20)
				expect(Presets.emitters.duskHaze ~= nil and Presets.emitters.gateSparkle ~= nil).to.equal(
					true
				)
				local low, high, saver =
					Presets.budget.low, Presets.budget.high, Presets.budget.lowPerformance
				expect(#Presets.chase.lines >= high.rushLines).to.equal(true)
				expect(saver.rushLines >= 1 and saver.rushLines <= low.rushLines).to.equal(true)
				expect(low.rushLines <= high.rushLines).to.equal(true)
				for _, count in
					{
						Presets.chase.dust,
						Presets.chase.pushedDust,
						Presets.bursts.duskHaze,
						Presets.areas.sparkle,
					}
				do
					expect(fits(count, low)).to.equal(true)
				end
				-- one gate's sunrise on a phone stays a single burst's worth
				local perGate = Presets.areas.points
					* math.clamp(
						math.floor(Presets.areas.sparkle * low.burstScale + 0.5),
						1,
						low.maxBurst
					)
				expect(perGate <= 12).to.equal(true)
			end
		)
	end)
end
