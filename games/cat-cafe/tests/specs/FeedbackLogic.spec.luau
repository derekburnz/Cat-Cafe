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
			expect(FeedbackLogic.FACES[1].label).to.equal("Love it")
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
end
