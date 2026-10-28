--!strict
-- Bedtime (F79, data-model 12c; Derek 2026-10-28: working cats sleep on the cat trees and in cat beds at night): a
-- working cat on its way to its sleep spot or back moves like a stray, and naps like one on the spot. Written by the
-- Animation-Engineer (QA said new specs may go straight in here).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any

	describe("Effects bedtime", function()
		it("walks like a stray on the way to its spot and back", function()
			expect(Logic.bedtimeStyle(true, nil)).to.equal("stray")
			expect(Logic.bedtimeStyle(true, false)).to.equal("stray")
		end)

		it("naps like a stray once it lies on its spot", function()
			expect(Logic.bedtimeStyle(true, true)).to.equal("nap")
		end)

		it(
			"leaves the station idles and the old station nap alone when the cat is not on a bedtime trip",
			function()
				expect(Logic.bedtimeStyle(nil, nil)).to.equal(nil)
				expect(Logic.bedtimeStyle(false, nil)).to.equal(nil)
				expect(Logic.bedtimeStyle(false, true)).to.equal(nil)
				expect(Logic.bedtimeStyle("yes", true)).to.equal(nil)
			end
		)
	end)

	describe("Effects bedtime edges (QA)", function()
		it("lies a cat down only when Asleep is exactly true", function()
			for _, asleep in { "yes", 1, 0, {}, "true" } :: { any } do
				expect(Logic.bedtimeStyle(true, asleep)).to.equal("stray")
			end
		end)

		it("never starts a trip from a truthy Bedtime that is not true", function()
			for _, bedtime in { 1, "true", {} } :: { any } do
				expect(Logic.bedtimeStyle(bedtime, true)).to.equal(nil)
				expect(Logic.bedtimeStyle(bedtime, nil)).to.equal(nil)
			end
		end)
	end)
end
