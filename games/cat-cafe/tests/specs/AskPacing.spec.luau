--!strict
-- UI/Components/AskPacing.luau: the pace of the slide-in ask cards (#2880).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local AskPacing = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("AskPacing")
	) :: any

	describe("AskPacing.allow", function()
		local first = AskPacing.FIRST_SECONDS
		local gap = AskPacing.GAP_SECONDS

		it("asks nothing in a session's first minutes", function()
			expect(first >= 8 * 60).to.equal(true)
			expect(AskPacing.allow(0, nil)).to.equal(false)
			expect(AskPacing.allow(first - 1, nil)).to.equal(false)
			expect(AskPacing.allow(first, nil)).to.equal(true)
		end)

		it("waits the gap after an ask before the next", function()
			expect(gap >= 5 * 60).to.equal(true)
			expect(AskPacing.allow(first + 10, first)).to.equal(false)
			expect(AskPacing.allow(first + gap - 1, first)).to.equal(false)
			expect(AskPacing.allow(first + gap, first)).to.equal(true)
		end)
	end)
end
