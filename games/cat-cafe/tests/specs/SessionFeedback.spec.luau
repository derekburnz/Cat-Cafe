--!strict
-- shared/SessionFeedback.luau (#3272): the once-a-day "Enjoying Catch a Cat Cafe?" ask at a calm moment.
return function()
	local SessionFeedback = require(game:GetService("ReplicatedStorage").Shared.SessionFeedback)
	local Tips = require(game:GetService("ReplicatedStorage").Shared.Tips) :: any

	local NOW = 20000 * 86400 + 3600
	local TODAY = SessionFeedback.day(NOW)
	local PLAYED = SessionFeedback.MIN_PLAY_SECONDS

	describe("SessionFeedback.due", function()
		it("asks at a natural stop once the session has run its minutes", function()
			expect(SessionFeedback.due(PLAYED, 0, 0, NOW, true, true)).to.equal(true)
			expect(SessionFeedback.due(PLAYED, SessionFeedback.IDLE_SECONDS, 0, NOW, true, false)).to.equal(
				true
			)
			-- not during play
			expect(SessionFeedback.due(PLAYED, 5, 0, NOW, true, false)).to.equal(false)
		end)

		it("never asks early in a session, mid-activity, or twice in a UTC day", function()
			expect(SessionFeedback.due(PLAYED - 1, 999, 0, NOW, true, true)).to.equal(false)
			expect(SessionFeedback.due(PLAYED, 999, 0, NOW, false, true)).to.equal(false)
			expect(SessionFeedback.due(PLAYED, 999, TODAY, NOW, true, true)).to.equal(false)
			expect(SessionFeedback.due(PLAYED, 999, TODAY - 1, NOW, true, true)).to.equal(true)
			expect(SessionFeedback.due(PLAYED, 999, nil, NOW, true, true)).to.equal(true)
		end)
	end)

	describe("SessionFeedback answers and buckets", function()
		it("takes the faces' ids and skipped", function()
			for _, face in Tips.FACES :: { string } do
				expect(table.find(SessionFeedback.ANSWERS, face) ~= nil).to.equal(true)
			end
			expect(table.find(SessionFeedback.ANSWERS, "skipped") ~= nil).to.equal(true)
		end)

		it("buckets session length and cats owned", function()
			expect(SessionFeedback.sessionBucket(6 * 60)).to.equal("5-10")
			expect(SessionFeedback.sessionBucket(25 * 60)).to.equal("20-40")
			expect(SessionFeedback.sessionBucket(3 * 3600)).to.equal("90+")
			expect(SessionFeedback.catsBucket(1)).to.equal("0-1")
			expect(SessionFeedback.catsBucket(3)).to.equal("2-3")
			expect(SessionFeedback.catsBucket(30)).to.equal("25+")
		end)
	end)
end
