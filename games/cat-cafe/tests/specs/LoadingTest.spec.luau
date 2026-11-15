--!strict
-- LoadingTest.luau (#4314): the loading screen A/B for new saves, its arm from a Creator Hub Experiment.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LoadingTest = require(Shared.LoadingTest)
	local Onboarding = require(Shared.Onboarding)

	describe("LoadingTest", function()
		it("takes only the two arms", function()
			expect(LoadingTest.arm("on")).to.equal("on")
			expect(LoadingTest.arm("off")).to.equal("off")
			expect(LoadingTest.arm("ON")).to.equal(nil)
			expect(LoadingTest.arm(1)).to.equal(nil)
			expect(LoadingTest.arm(nil)).to.equal(nil)
		end)

		it("takes in only a save on its first session that has not seen the intro", function()
			expect(LoadingTest.joins(0, false)).to.equal(true)
			expect(LoadingTest.joins(1, false)).to.equal(true)
			expect(LoadingTest.joins(2, false)).to.equal(false)
			expect(LoadingTest.joins(1, true)).to.equal(false)
		end)

		it("lets the arm decide over the switch, and the switch decide with no arm", function()
			expect(LoadingTest.shows("on", false)).to.equal(true)
			expect(LoadingTest.shows("on", true)).to.equal(true)
			expect(LoadingTest.shows("off", true)).to.equal(false)
			expect(LoadingTest.shows("off", false)).to.equal(false)
			expect(LoadingTest.shows(nil, true)).to.equal(true)
			expect(LoadingTest.shows(nil, false)).to.equal(false)
		end)

		it("stops at a playtime step that exists, past every mark Derek named", function()
			local last = table.find(Onboarding.PLAYTIME_STEPS, LoadingTest.LAST_STEP)
			expect(last ~= nil).to.equal(true)
			for _, mark in
				{ "played_30s", "played_1m", "played_2m", "played_3m", "played_4m", "played_5m" }
			do
				local at = table.find(Onboarding.PLAYTIME_STEPS, mark)
				expect(at ~= nil and at <= (last :: number)).to.equal(true)
			end
		end)
	end)
end
