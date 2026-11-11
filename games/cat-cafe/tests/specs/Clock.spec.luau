--!strict
-- Clock.luau against data-model section 9: a first day of ServerStartDaySeconds, then night and day forever, and
-- v0.9's night closing texts (F66).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Clock = require(Shared.Clock)
	local Config = require(Shared.Config)

	local firstDay = Config.ServerStartDaySeconds
	local night = Config.NightLengthSeconds
	local day = Config.DayLengthSeconds

	describe("night closing texts (v0.9, F66)", function()
		it("say what data-model section 9 says", function()
			expect(Clock.CLOSED_TEXT).to.equal(
				"The areas are closed at night. They open at sunrise."
			)
			expect(Clock.SENT_HOME_TEXT).to.equal("Night fell, so you headed home.")
		end)
	end)

	-- #3253 (shorter nights, Derek2): the numbers the nights and the shelf restock are built on. If one moves on
	-- purpose, change it here too.
	describe("cycle lengths (#3253)", function()
		it("keep a 45 s night, a 345 s day and a 390 s cycle", function()
			expect(night).to.equal(45)
			expect(day).to.equal(345)
			expect(night + day).to.equal(390)
		end)

		it("start the clock on a whole day", function()
			expect(firstDay).to.equal(day)
		end)
	end)

	describe("phaseAt", function()
		it("starts in day with the whole first day left", function()
			local phase, left = Clock.phaseAt(0)
			expect(phase).to.equal("day")
			expect(left).to.equal(firstDay)
		end)

		it("treats a negative time as the server start", function()
			local phase, left = Clock.phaseAt(-5)
			expect(phase).to.equal("day")
			expect(left).to.equal(firstDay)
		end)

		it("turns night when the first day runs out, with the whole night left", function()
			local phase, left = Clock.phaseAt(firstDay - 0.5)
			expect(phase).to.equal("day")
			expect(left).to.be.near(0.5)
			phase, left = Clock.phaseAt(firstDay)
			expect(phase).to.equal("night")
			expect(left).to.equal(night)
		end)

		it("follows the night with a full day, then loops", function()
			local phase, left = Clock.phaseAt(firstDay + night)
			expect(phase).to.equal("day")
			expect(left).to.equal(day)
			phase, left = Clock.phaseAt(firstDay + night + day)
			expect(phase).to.equal("night")
			expect(left).to.equal(night)
			phase, left = Clock.phaseAt(firstDay + 3 * (night + day) + night + 10)
			expect(phase).to.equal("day")
			expect(left).to.equal(day - 10)
		end)

		it("counts down without jumps and only switches phase at zero", function()
			local lastPhase, lastLeft = Clock.phaseAt(0)
			local switches = 0
			for step = 1, 4 * (firstDay + night + day) do
				local t = step * 0.5
				local phase, left = Clock.phaseAt(t)
				expect(left > 0).to.equal(true)
				if phase == lastPhase then
					expect(left).to.be.near(lastLeft - 0.5)
				else
					switches += 1
					expect(lastLeft).to.be.near(0.5)
					expect(left).to.equal(if phase == "night" then night else day)
				end
				lastPhase, lastLeft = phase, left
			end
			expect(switches > 0).to.equal(true)
		end)
	end)

	describe("startOf", function()
		it("points at the first full run of each phase", function()
			expect(Clock.startOf("night")).to.equal(firstDay)
			expect(Clock.startOf("day")).to.equal(firstDay + night)
			for _, phase in { "day", "night" } :: { any } do
				local found, left = Clock.phaseAt(Clock.startOf(phase))
				expect(found).to.equal(phase)
				expect(left).to.equal(if phase == "night" then night else day)
			end
		end)
	end)

	describe("nightSecondsBetween (F31, section 11)", function()
		local start = firstDay

		it("is 0 in the first day and for an empty or backwards window", function()
			expect(Clock.nightSecondsBetween(0, start)).to.equal(0)
			expect(Clock.nightSecondsBetween(start + 10, start + 10)).to.equal(0)
			expect(Clock.nightSecondsBetween(start + 50, start + 10)).to.equal(0)
		end)

		it("counts only the night part of a window that crosses dusk or dawn", function()
			expect(Clock.nightSecondsBetween(start - 30, start + 40)).to.equal(40)
			expect(Clock.nightSecondsBetween(start + night - 25, start + night + 60)).to.equal(25)
		end)

		it("adds up whole cycles", function()
			expect(Clock.nightSecondsBetween(0, start + 2 * (night + day))).to.equal(2 * night)
			expect(Clock.nightSecondsBetween(start + night, start + night + day)).to.equal(0)
		end)

		it("agrees with phaseAt second by second", function()
			local counted = 0
			for t = 0, start + 2 * (night + day) do
				if Clock.phaseAt(t + 0.5) == "night" then
					counted += 1
				end
			end
			expect(Clock.nightSecondsBetween(0, start + 2 * (night + day) + 1)).to.equal(counted)
		end)
	end)
	describe("#2192: longer days, shorter nights, the same game day", function()
		it(
			"a game day is still 390 s, so every sunrise stays on a whole game day from the epoch",
			function()
				expect(night + day).to.equal(390)
				expect(firstDay).to.equal(day)
				for k = 1, 5 do
					expect(Clock.phaseAt(k * 390 - 0.5)).to.equal("night")
					expect(Clock.phaseAt(k * 390 + 0.5)).to.equal("day")
					expect(Clock.dayAt(k * 390 + 0.5)).to.equal(Clock.dayAt(k * 390 - 0.5) + 1)
				end
			end
		)

		it("the restock windows still turn at sunrise", function()
			expect(Config.FreshCatchWindowSeconds).to.equal(night + day)
			expect(Config.CornerShopWindowSeconds).to.equal(night + day)
		end)
	end)

	describe("firstDayUntil (#2184: a new server opens by day)", function()
		local cycle = night + day
		it("leaves a server booted with plenty of day on the global clock", function()
			expect(Clock.firstDayUntil(10)).to.equal(10)
			expect(Clock.firstDayUntil(firstDay + night + 5)).to.equal(firstDay + night + 5)
		end)

		it("skips the night under way: day until the next global sunrise", function()
			expect(Clock.firstDayUntil(firstDay + 30)).to.equal(firstDay + night)
			expect(Clock.firstDayUntil(firstDay + cycle + 1)).to.equal(firstDay + cycle + night)
		end)

		it("skips the coming night when under FIRST_DAY_MIN_SECONDS of day are left", function()
			local t = firstDay - (Clock.FIRST_DAY_MIN_SECONDS - 1)
			expect(Clock.firstDayUntil(t)).to.equal(firstDay + night)
			local enough = firstDay - Clock.FIRST_DAY_MIN_SECONDS
			expect(Clock.firstDayUntil(enough)).to.equal(enough)
		end)

		-- Desktop-Tester's #2185 check: a boot with 85 s of day left showed PhaseEndsAt 475 s away. That is the skipped
		-- night (85 + 90 + 300 then): the first dusk is the global dusk after the next sunrise, never an off-cycle one.
		it(
			"a new server's first dusk is a global dusk, at least FIRST_DAY_MIN_SECONDS away",
			function()
				for t = 0, 3 * cycle, 0.5 do
					local untilT = Clock.firstDayUntil(t)
					local dusk: number
					if t < untilT then
						local _, after = Clock.phaseAt(untilT)
						dusk = untilT + after -- ClockService.tick's secondsLeft while t < dayUntil
					else
						local phase, left = Clock.phaseAt(t)
						expect(phase).to.equal("day")
						dusk = t + left
					end
					expect(Clock.phaseAt(dusk - 0.25)).to.equal("day")
					expect(Clock.phaseAt(dusk + 0.25)).to.equal("night")
					expect(dusk - t >= Clock.FIRST_DAY_MIN_SECONDS).to.equal(true)
					expect(dusk - t <= Clock.FIRST_DAY_MIN_SECONDS + night + day).to.equal(true)
				end
			end
		)

		it("always ends on a global sunrise, where the global clock is day", function()
			for t = 0, 3 * cycle, 7 do
				local untilT = Clock.firstDayUntil(t)
				local phase = Clock.phaseAt(untilT)
				expect(phase).to.equal("day")
				if untilT ~= t then
					expect(Clock.dayAt(untilT)).to.equal(Clock.dayAt(untilT - 0.5) + 1)
				end
			end
		end)
	end)
	describe("where a player left (#2562)", function()
		it("names day, dusk or night and which third of it", function()
			local warn = Config.DuskWarningSeconds
			expect({ Clock.leavePhase("night", night) } :: any).to.deepEqual({
				"night",
				"night_early",
			})
			expect({ Clock.leavePhase("night", night / 2) } :: any).to.deepEqual({
				"night",
				"night_mid",
			})
			expect({ Clock.leavePhase("night", 0) } :: any).to.deepEqual({ "night", "night_late" })
			expect({ Clock.leavePhase("day", day) } :: any).to.deepEqual({ "day", "day_early" })
			expect({ Clock.leavePhase("day", warn + 1) } :: any).to.deepEqual({ "day", "day_late" })
			expect({ Clock.leavePhase("day", warn) } :: any).to.deepEqual({ "dusk", "dusk_early" })
			expect({ Clock.leavePhase("day", 0) } :: any).to.deepEqual({ "dusk", "dusk_late" })
			-- a clock read a moment out never falls outside the phase
			expect({ Clock.leavePhase("night", night + 5) } :: any).to.deepEqual({
				"night",
				"night_early",
			})
			expect({ Clock.leavePhase("day", -2) } :: any).to.deepEqual({ "dusk", "dusk_late" })
		end)
	end)
end
