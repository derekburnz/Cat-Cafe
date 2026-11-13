--!strict
-- UI/Components/FeedbackLogic.luau: the feedback faces, chips, the one ask and one send per answer (F87 section 4).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local FeedbackLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("FeedbackLogic")
	) :: any
	local Tips = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Tips")
	) :: any

	describe("FeedbackLogic choices", function()
		it("offers the server's faces and chips, in its order, with words", function()
			expect(#FeedbackLogic.FACES).to.equal(#Tips.FACES)
			for index, face in FeedbackLogic.FACES do
				expect(face.id).to.equal(Tips.FACES[index])
				expect(face.label ~= face.id).to.equal(true)
			end
			expect(#FeedbackLogic.CHIPS).to.equal(#Tips.CHIPS)
			for index, chip in FeedbackLogic.CHIPS do
				expect(chip.id).to.equal(Tips.CHIPS[index])
				expect(chip.label ~= chip.id).to.equal(true)
			end
			expect(FeedbackLogic.FACES[1].label).to.equal("Good")
			expect(FeedbackLogic.CHIPS[5].label).to.equal("Want more cats")
		end)
	end)

	describe("FeedbackLogic.askDue", function()
		local minutes = FeedbackLogic.ASK_MINUTES
		it("asks once the session has run its minutes, between activities", function()
			expect(FeedbackLogic.askDue(false, minutes * 60, true)).to.equal(true)
			expect(FeedbackLogic.askDue(false, minutes * 60 - 1, true)).to.equal(false)
			expect(FeedbackLogic.askDue(false, minutes * 60, false)).to.equal(false)
		end)

		it("never asks again, and waits for the save to say", function()
			expect(FeedbackLogic.askDue(true, 3600, true)).to.equal(false)
			expect(FeedbackLogic.askDue(nil, 3600, true)).to.equal(false)
		end)
	end)

	describe("FeedbackLogic.earlyDue", function()
		local early = FeedbackLogic.EARLY_MINUTES * 60
		local served = 45
		it(
			"asks a player never asked at the early minutes, before the usual ask (#2681)",
			function()
				expect(early < FeedbackLogic.ASK_MINUTES * 60).to.equal(true)
				expect(FeedbackLogic.earlyDue(false, early, 0, true)).to.equal(true)
				expect(FeedbackLogic.earlyDue(false, early - 1, 0, true)).to.equal(false)
			end
		)

		it(
			"no longer asks sooner once a cat has served customers, and not before 8 minutes (#2880)",
			function()
				expect(FeedbackLogic.EARLY_MINUTES >= 8).to.equal(true)
				expect(FeedbackLogic.earlyDue(false, 60, served, true)).to.equal(false)
				expect(FeedbackLogic.earlyDue(false, early - 1, 600, true)).to.equal(false)
			end
		)

		it("waits for a quiet moment and never asks an account already asked", function()
			expect(FeedbackLogic.earlyDue(false, early, served, false)).to.equal(false)
			expect(FeedbackLogic.earlyDue(true, early, served, true)).to.equal(false)
			expect(FeedbackLogic.earlyDue(nil, early, served, true)).to.equal(false)
		end)
	end)

	describe("FeedbackLogic.answer", function()
		it("sends the face with the first chip, once", function()
			local answer = FeedbackLogic.answer()
			answer:pick("love", 0)
			local face, chip = answer:chip("boring")
			expect(face).to.equal("love")
			expect(chip).to.equal("boring")
			expect(answer:chip("laggy")).to.equal(nil)
			expect(answer:flush()).to.equal(nil)
			expect(answer:due(999)).to.equal(nil)
		end)

		it("sends the face alone after the wait or at a flush", function()
			local answer = FeedbackLogic.answer()
			answer:pick("ok", 10)
			expect(answer:due(10 + FeedbackLogic.WAIT_SECONDS - 1)).to.equal(nil)
			local face, chip = answer:due(10 + FeedbackLogic.WAIT_SECONDS)
			expect(face).to.equal("ok")
			expect(chip).to.equal(nil)
			expect(answer:chip("boring")).to.equal(nil)

			local closed = FeedbackLogic.answer()
			closed:pick("no", 0)
			expect(closed:flush()).to.equal("no")
			expect(closed:flush()).to.equal(nil)
		end)

		it("sends nothing without a face", function()
			local answer = FeedbackLogic.answer()
			expect(answer:chip("boring")).to.equal(nil)
			expect(answer:flush()).to.equal(nil)
			expect(answer:face()).to.equal(nil)
		end)
	end)

	describe("the slide-in ask's reasons (#3657)", function()
		it(
			"offers four reasons after a plain face or a thumbs down, none after a thumbs up",
			function()
				expect(#FeedbackLogic.reasons("ok")).to.equal(4)
				expect(#FeedbackLogic.reasons("no")).to.equal(4)
				expect(#FeedbackLogic.reasons("love")).to.equal(0)
				expect(#FeedbackLogic.reasons("nonsense")).to.equal(0)
				local ids = {}
				for _, reason in FeedbackLogic.reasons("no") do
					table.insert(ids, reason.id)
					expect(#reason.label > 0).to.equal(true)
				end
				expect(table.concat(ids, ",")).to.equal("too_hard,confusing,boring,laggy")
			end
		)

		it("turns the answer into a chip the server takes, or none", function()
			expect(FeedbackLogic.reasonChip("boring")).to.equal("boring")
			expect(FeedbackLogic.reasonChip("laggy")).to.equal("laggy")
			expect(FeedbackLogic.reasonChip(FeedbackLogic.SKIP)).to.equal(nil)
			expect(FeedbackLogic.reasonChip(nil)).to.equal(nil)
			expect(FeedbackLogic.reasonChip("more_cats")).to.equal(nil)
			expect(FeedbackLogic.reasonChip("x")).to.equal(nil)
		end)
	end)
end
