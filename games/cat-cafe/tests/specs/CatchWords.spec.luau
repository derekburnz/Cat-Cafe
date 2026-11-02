--!strict
-- UI/Components/CatchWords.luau: the catch's result word (F93, catch-rework.md section 3), the same rule as
-- Effects/Logic.catchWord so the word and its burst agree.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CatchWords =
		require(Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CatchWords")) :: any
	local EffectsLogic = require(Client:WaitForChild("Effects"):WaitForChild("Logic")) :: any

	describe("CatchWords.result", function()
		it("reads PURRFECT! when every circle is Perfect", function()
			expect(CatchWords.result({ "perfect", "perfect", "perfect" }, true)).to.equal("purrfect")
			expect(CatchWords.TEXT.purrfect).to.equal("PURRFECT!")
		end)

		it("reads EXCELLENT! when at least half are Perfect", function()
			expect(CatchWords.result({ "perfect", "good", "perfect", "good" }, true)).to.equal("excellent")
			expect(CatchWords.result({ "perfect", "perfect", "good" }, true)).to.equal("excellent")
		end)

		it("reads GREAT! when every circle is Good or better and fewer than half Perfect", function()
			expect(CatchWords.result({ "good", "good", "perfect" }, true)).to.equal("great")
			expect(CatchWords.result({ "good", "good", "good", "good", "good" }, true)).to.equal("great")
		end)

		it("reads So close! on a Miss, a failed catch or no circles", function()
			expect(CatchWords.result({ "perfect", "miss" }, false)).to.equal("close")
			expect(CatchWords.result({ "perfect", "miss" }, true)).to.equal("close")
			expect(CatchWords.result({}, true)).to.equal("close")
			expect(CatchWords.TEXT.close).to.equal("So close!")
		end)

		it("agrees with the burst Effects picks for the same grades", function()
			local cases = {
				{ "perfect", "perfect", "perfect" },
				{ "perfect", "good", "perfect", "good" },
				{ "good", "good", "perfect" },
				{ "perfect", "miss" },
				{ "good" },
				{ "perfect", "perfect", "good", "good", "good" },
			}
			for _, grades in cases do
				local burst = EffectsLogic.catchWord(grades)
				local word = CatchWords.result(grades, true)
				expect(word).to.equal(if burst == nil then "close" else burst)
			end
		end)
	end)
end
