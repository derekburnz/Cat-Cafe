--!strict
-- #4383: rank up first after the tutorial, and a stray press only rests the walk-through (shared/RankFirst).

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
	local RankFirst = require(Shared:WaitForChild("RankFirst"))

	describe("RankFirst", function()
		it("has no live switch any more (#4654)", function()
			expect(table.find(LiveFlags.KEYS, "rankFirst")).to.equal(nil)
		end)

		it(
			"holds the stuck cat goal only for a Tier 1 cafe that can rank up, with the switch on",
			function()
				expect(RankFirst.holds(1, true)).to.equal(true)
				expect(RankFirst.holds(nil, true)).to.equal(true) -- a state with no tier yet reads as Tier 1
				expect(RankFirst.holds(1, false)).to.equal(false) -- a need not met: the stuck cat goal as before
				expect(RankFirst.holds(2, true)).to.equal(false) -- past Tier 2
			end
		)

		it("knows its own strip lines, so the cannon's wrap-up hint gives way to them", function()
			for _, device in { "touch", "keyboard", "gamepad" } do
				local line = RankFirst.line(device)
				expect(RankFirst.isLine(line)).to.equal(true)
			end
			expect(RankFirst.isLine("Hop in the cannon: catch more cats to rank up!")).to.equal(
				false
			)
			expect(RankFirst.isLine(nil)).to.equal(false)
		end)

		it("names the goal card in each device's words, one strip line each", function()
			expect(RankFirst.line("touch")).to.equal("Rank up! Tap YOUR GOAL to open the Park")
			expect(RankFirst.line("keyboard")).to.equal("Rank up! Click YOUR GOAL to open the Park")
			expect(RankFirst.line("gamepad")).to.equal("Rank up! Select YOUR GOAL to open the Park")
			expect(RankFirst.line("vr")).to.equal(RankFirst.line("keyboard"))
			for _, line in RankFirst.LINES :: any do
				expect((utf8.len(line) or 99) <= 50).to.equal(true) -- the strip holds about 50 characters (TutorialHints)
			end
		end)

		it("gives the strip's button short words that are not a strip line", function()
			expect(RankFirst.BUTTON).to.equal("RANK UP")
			expect(RankFirst.isLine(RankFirst.BUTTON)).to.equal(false)
		end)

		it(
			"puts the walk-through away only at the third press with the switch on, at the first with it off",
			function()
				expect(RankFirst.PRESSES).to.equal(3)
				expect(RankFirst.forGood(1)).to.equal(false)
				expect(RankFirst.forGood(2)).to.equal(false)
				expect(RankFirst.forGood(3)).to.equal(true)
				expect(RankFirst.REST_SECONDS > 0).to.equal(true)
			end
		)

		it("never puts it away with rankSpotStay, and rests it for less", function()
			expect(RankFirst.forGood(3, true)).to.equal(false)
			expect(RankFirst.forGood(50, true)).to.equal(false)
			expect(RankFirst.forGood(3, false)).to.equal(true)
			expect(RankFirst.rest(true)).to.equal(RankFirst.STAY_REST)
			expect(RankFirst.rest(false)).to.equal(RankFirst.REST_SECONDS)
			expect(RankFirst.STAY_REST < RankFirst.REST_SECONDS).to.equal(true)
			-- each press rests it longer, up to the cap
			expect(RankFirst.rest(true, 1)).to.equal(8)
			expect(RankFirst.rest(true, 2)).to.equal(16)
			expect(RankFirst.rest(true, 3)).to.equal(24)
			expect(RankFirst.rest(true, 4)).to.equal(30)
			expect(RankFirst.rest(true, 40)).to.equal(30)
			expect(RankFirst.rest(false, 4)).to.equal(RankFirst.REST_SECONDS)
		end)
	end)
end
