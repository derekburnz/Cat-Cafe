--!strict
-- #3066: shared/FeedbackStand, the Town Square's feedback stand: its ring fits in front of it, its prompt shows
-- before the ring opens the window, and the ring's window takes the cursor only for a keyboard player standing still.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BugReport = require(ReplicatedStorage.Shared.BugReport)
local FeedbackStand = require(ReplicatedStorage.Shared.FeedbackStand)
local WalkUp = require(ReplicatedStorage.Shared.WalkUp)

return function()
	describe("FeedbackStand", function()
		it("opens the Feedback window on a chip the form knows", function()
			expect(FeedbackStand.WINDOW).to.equal("BugReport")
			expect(table.find(BugReport.Kinds, FeedbackStand.KIND)).to.be.ok()
		end)

		it("has room for a whole ring touching the stand's front", function()
			-- the model is 3.8 deep, front -Z, pivot at the base centre
			local front = 1.9
			local out = WalkUp.frontOffset(front, WalkUp.FRONT_RADIUS, FeedbackStand.RANGE)
			expect(out).to.equal(front + WalkUp.FRONT_RADIUS)
			-- and the prompt's pill reaches the whole ring's middle, so a window closed by hand opens with a press
			expect(FeedbackStand.PROMPT_RANGE >= WalkUp.FRONT_RADIUS).to.equal(true)
		end)

		it("puts the cursor in the box once, for a keyboard player who stands still", function()
			local looks = FeedbackStand.STILL_LOOKS
			expect(FeedbackStand.focusNow(looks - 1, false, true)).to.equal(false) -- still walking in
			expect(FeedbackStand.focusNow(looks, false, true)).to.equal(true)
			expect(FeedbackStand.focusNow(looks + 5, true, true)).to.equal(false) -- only once
			expect(FeedbackStand.focusNow(looks + 5, false, false)).to.equal(false) -- a phone waits for a tap
		end)
	end)
end
