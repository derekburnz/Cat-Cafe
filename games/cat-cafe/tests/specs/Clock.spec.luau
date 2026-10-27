--!strict
-- Clock.luau against data-model section 9: a short first day, then night and day forever.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Clock = require(Shared.Clock)
	local Config = require(Shared.Config)

	local firstDay = Config.ServerStartDaySeconds
	local night = Config.NightLengthSeconds
	local day = Config.DayLengthSeconds

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
end
