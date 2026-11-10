--!strict
-- FeedbackFunnel.luau (#2681): the feedback_v1 steps, the minutes buckets and feedback_env's build field.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local FeedbackFunnel = require(Shared.FeedbackFunnel)

	describe("FeedbackFunnel", function()
		it("numbers its three steps in order", function()
			expect(FeedbackFunnel.NAME).to.equal("feedback_v1")
			expect(FeedbackFunnel.index("ask_shown")).to.equal(1)
			expect(FeedbackFunnel.index("face_picked")).to.equal(2)
			expect(FeedbackFunnel.index("chip_picked")).to.equal(3)
			expect(FeedbackFunnel.index("other")).to.equal(0)
		end)

		it("buckets minutes played with each edge in the lower bucket", function()
			expect(FeedbackFunnel.minutesBucket(-5)).to.equal("0-2")
			expect(FeedbackFunnel.minutesBucket(0)).to.equal("0-2")
			expect(FeedbackFunnel.minutesBucket(120)).to.equal("0-2")
			expect(FeedbackFunnel.minutesBucket(121)).to.equal("2-5")
			expect(FeedbackFunnel.minutesBucket(300)).to.equal("2-5")
			expect(FeedbackFunnel.minutesBucket(301)).to.equal("5-10")
			expect(FeedbackFunnel.minutesBucket(600)).to.equal("5-10")
			expect(FeedbackFunnel.minutesBucket(601)).to.equal("10-20")
			expect(FeedbackFunnel.minutesBucket(1200)).to.equal("10-20")
			expect(FeedbackFunnel.minutesBucket(1201)).to.equal("20+")
			expect(FeedbackFunnel.minutesBucket(1e7)).to.equal("20+")
		end)

		it("joins the place version and the error flag", function()
			expect(FeedbackFunnel.build(812, false)).to.equal("812:ok")
			expect(FeedbackFunnel.build(812, true)).to.equal("812:err")
			expect(FeedbackFunnel.build(0, false)).to.equal("0:ok")
			expect(FeedbackFunnel.build(-3.5, true)).to.equal("0:err")
		end)

		it("#2694: reads an ask's outcome and kind, and nothing else", function()
			local outcome, kind = FeedbackFunnel.outcome("closed:early")
			expect(outcome).to.equal("closed")
			expect(kind).to.equal("early")
			outcome, kind = FeedbackFunnel.outcome("answered:late")
			expect(outcome).to.equal("answered")
			expect(kind).to.equal("late")
			for _, bad in
				{ "closed", "closed:", "gone:early", "ignored:soon", "closed:early:x", "", 3, true }
			do
				outcome, kind = FeedbackFunnel.outcome(bad)
				expect(outcome).to.equal(nil)
				expect(kind).to.equal(nil)
			end
			outcome = FeedbackFunnel.outcome(string.rep("a", 40))
			expect(outcome).to.equal(nil)
		end)
	end)
end
