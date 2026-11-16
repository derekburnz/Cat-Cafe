--!strict
-- UI/Components/ReturnHookLine.luau: the minute 6 "come back tomorrow" line for players before Tier 3 (#4626).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local ReturnHookLine = require(Components:WaitForChild("ReturnHookLine")) :: any
	local RecapLogic = require(Components:WaitForChild("RecapLogic")) :: any

	describe("ReturnHookLine.due", function()
		it("waits for minute 6", function()
			expect(ReturnHookLine.AT_SECONDS).to.equal(360)
			expect(ReturnHookLine.due(359, 1, true, false)).to.equal(false)
			expect(ReturnHookLine.due(360, 1, true, false)).to.equal(true)
			expect(ReturnHookLine.due(900, 2, true, false)).to.equal(true)
		end)

		it("stays away during the tutorial, from Tier 3 and once shown", function()
			expect(ReturnHookLine.due(600, 1, false, false)).to.equal(false)
			expect(ReturnHookLine.due(600, 3, true, false)).to.equal(false)
			expect(ReturnHookLine.due(600, nil, true, false)).to.equal(false)
			expect(ReturnHookLine.due(600, 1, true, true)).to.equal(false)
		end)
	end)

	describe("ReturnHookLine.words", function()
		it("uses the recap card's tomorrow words behind a gift", function()
			expect(ReturnHookLine.words({ kind = "gift" })).to.equal(
				"\u{1F381} " .. RecapLogic.GIFT_LINE
			)
			expect(ReturnHookLine.words({ kind = "treat", day = 2, prize = "2 Cat Snacks" })).to.equal(
				"\u{1F381} Tomorrow: Daily Treat day 2, 2 Cat Snacks"
			)
		end)

		it("says nothing without a gift or treat hook", function()
			expect(ReturnHookLine.words(nil)).to.equal(nil)
			expect(ReturnHookLine.words("gift")).to.equal(nil)
			expect(ReturnHookLine.words({ kind = "bait" })).to.equal(nil)
			expect(ReturnHookLine.words({ kind = "quests" })).to.equal(nil)
			expect(ReturnHookLine.words({ kind = "nope" })).to.equal(nil)
		end)

		it("reports the kind the server allows", function()
			expect(ReturnHookLine.kind({ kind = "gift" })).to.equal("gift")
			expect(ReturnHookLine.kind({ kind = "treat", day = 3 })).to.equal("treat")
			expect(ReturnHookLine.kind({ kind = "bait" })).to.equal(nil)
		end)
	end)
end
