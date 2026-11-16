--!strict
-- shared/TutorialOrder (#4518): the walk-through's order behind the catchFirst switch.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LiveFlags = require(Shared.LiveFlags)
	local TutorialOrder = require(Shared.TutorialOrder)

	describe("TutorialOrder", function()
		it(
			"is a switch on by default (today's order), so bowl first needs an explicit false",
			function()
				expect(TutorialOrder.FLAG).to.equal("catchFirst")
				expect(table.find(LiveFlags.KEYS, TutorialOrder.FLAG) ~= nil).to.equal(true)
				expect(LiveFlags.OFF_BY_DEFAULT[TutorialOrder.FLAG]).to.equal(nil)
				expect(TutorialOrder.bowlFirst()).to.equal(false)
			end
		)

		it(
			"keeps the bowl part pending until the first food's cat is claimed, before the first check-in",
			function()
				expect(TutorialOrder.bowlPending(0, 0, false)).to.equal(true)
				expect(TutorialOrder.bowlPending(0, 1, true)).to.equal(true) -- its cat waits at the bowl
				expect(TutorialOrder.bowlPending(0, 1, false)).to.equal(false) -- tamed or let go
				expect(TutorialOrder.bowlPending(1, 0, false)).to.equal(true)
				expect(TutorialOrder.bowlPending(2, 0, false)).to.equal(false) -- past the first check-in
			end
		)

		it("names the bowl part's three funnel stand-ins (#4674)", function()
			expect(TutorialOrder.REPORT).to.equal("bowl_step")
			expect(TutorialOrder.BOWL_STEPS.food).to.equal("tut_bowl_food")
			expect(TutorialOrder.BOWL_STEPS.waiting).to.equal("tut_bowl_waiting")
			expect(TutorialOrder.BOWL_STEPS.arrived).to.equal("tut_bowl_arrived")
		end)
	end)
end
