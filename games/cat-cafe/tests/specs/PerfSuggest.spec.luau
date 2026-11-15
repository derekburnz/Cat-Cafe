--!strict
-- PerfSuggest: the one Low performance ask on a slow touch device (#4311).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local PerfSuggest = require(Shared.PerfSuggest)
	local Settings = require(Shared.Settings)

	describe("PerfSuggest", function()
		it("counts slow windows in a row and resets on a fast one", function()
			local low = PerfSuggest.LOW_FPS - 5
			expect(PerfSuggest.step(0, low, true)).to.equal(1)
			expect(PerfSuggest.step(1, low, true)).to.equal(2)
			expect(PerfSuggest.step(2, PerfSuggest.LOW_FPS + 10, true)).to.equal(0)
			expect(PerfSuggest.step(1, 0 / 0, true)).to.equal(0)
		end)

		it("leaves the run as it is for a window that does not count", function()
			expect(PerfSuggest.step(1, 5, false)).to.equal(1)
			expect(PerfSuggest.step(0, 5, false)).to.equal(0)
		end)

		it(
			"asks only on a slow touch device with Low performance off, once, after the first minute",
			function()
				local run, after = PerfSuggest.WINDOWS, PerfSuggest.SKIP_SECONDS
				expect(PerfSuggest.due(run, after, true, false, false)).to.equal(true)
				expect(PerfSuggest.due(run - 1, after, true, false, false)).to.equal(false)
				expect(PerfSuggest.due(run, after - 1, true, false, false)).to.equal(false)
				expect(PerfSuggest.due(run, after, false, false, false)).to.equal(false)
				expect(PerfSuggest.due(run, after, true, true, false)).to.equal(false)
				expect(PerfSuggest.due(run, after, true, false, true)).to.equal(false)
			end
		)

		it("saves its answer as a switch that starts off", function()
			expect((Settings.kinds :: any)[PerfSuggest.ASKED_KEY]).to.equal("switch")
			expect((Settings.defaults() :: any)[PerfSuggest.ASKED_KEY]).to.equal(false)
		end)
	end)
end
