--!strict
-- #4383: rank up first after the tutorial, and a stray press only rests the walk-through (shared/RankFirst).

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
	local RankFirst = require(Shared:WaitForChild("RankFirst"))

	describe("RankFirst", function()
		it("is a live switch that only an explicit false turns off", function()
			expect(table.find(LiveFlags.KEYS, RankFirst.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[RankFirst.FLAG]).to.equal(nil)
			expect(LiveFlags.shown(RankFirst.FLAG, nil)).to.equal(true)
			expect(LiveFlags.shown(RankFirst.FLAG, false)).to.equal(false)
		end)

		it(
			"holds the stuck cat goal only for a Tier 1 cafe that can rank up, with the switch on",
			function()
				expect(RankFirst.holds(true, 1, true)).to.equal(true)
				expect(RankFirst.holds(true, nil, true)).to.equal(true) -- a state with no tier yet reads as Tier 1
				expect(RankFirst.holds(false, 1, true)).to.equal(false) -- the switch
				expect(RankFirst.holds(true, 1, false)).to.equal(false) -- a need not met: the stuck cat goal as before
				expect(RankFirst.holds(true, 2, true)).to.equal(false) -- past Tier 2
			end
		)

		it("knows its own strip lines, so the cannon's wrap-up hint gives way to them", function()
			for _, device in { "touch", "keyboard", "gamepad" } do
				local line = RankFirst.line(device)
				expect(RankFirst.isLine(line)).to.equal(true)
			end
			expect(RankFirst.isLine("Hop in the cannon to catch more cats!")).to.equal(false)
			expect(RankFirst.isLine(nil)).to.equal(false)
		end)

		it("names the goal card in each device's words, one strip line each", function()
			expect(RankFirst.line("touch")).to.equal("Rank up! Tap YOUR GOAL")
			expect(RankFirst.line("keyboard")).to.equal("Rank up! Click YOUR GOAL")
			expect(RankFirst.line("gamepad")).to.equal("Rank up! Select YOUR GOAL")
			expect(RankFirst.line("vr")).to.equal(RankFirst.line("keyboard"))
			for _, line in RankFirst.LINES :: any do
				expect((utf8.len(line) or 99) <= 50).to.equal(true) -- the strip holds about 50 characters (TutorialHints)
			end
		end)

		it(
			"puts the walk-through away only at the third press with the switch on, at the first with it off",
			function()
				expect(RankFirst.PRESSES).to.equal(3)
				expect(RankFirst.forGood(true, 1)).to.equal(false)
				expect(RankFirst.forGood(true, 2)).to.equal(false)
				expect(RankFirst.forGood(true, 3)).to.equal(true)
				expect(RankFirst.forGood(false, 1)).to.equal(true)
				expect(RankFirst.REST_SECONDS > 0).to.equal(true)
			end
		)
	end)
end
