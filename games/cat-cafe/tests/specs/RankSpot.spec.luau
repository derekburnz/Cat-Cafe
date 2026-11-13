--!strict
-- #3555: the first rank up's walk-through (shared/RankSpot).

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
	local RankSpot = require(Shared:WaitForChild("RankSpot"))
	local Tips = require(Shared:WaitForChild("Tips"))

	describe("RankSpot", function()
		it("is behind a switch that starts off", function()
			expect(LiveFlags.OFF_BY_DEFAULT[RankSpot.FLAG]).to.equal(true)
			expect(LiveFlags.shown(RankSpot.FLAG, nil)).to.equal(false)
		end)

		it(
			"is due only for a Tier 1 cafe the server would rank up, in the safe area, not put away",
			function()
				expect(RankSpot.due(true, 1, false, nil, nil)).to.equal(true)
				expect(RankSpot.due(false, 1, false, nil, nil)).to.equal(false) -- the switch
				expect(RankSpot.due(true, 2, false, nil, nil)).to.equal(false) -- later rank ups: no dim
				expect(RankSpot.due(true, 1, true, nil, nil)).to.equal(false) -- put away
				expect(RankSpot.due(true, 1, false, "Not enough coins", nil)).to.equal(false)
				expect(RankSpot.due(true, 1, false, nil, "alley")).to.equal(false) -- a catching area
			end
		)

		it("waits until the player has been free for 2 seconds", function()
			expect(RankSpot.FREE_SECONDS).to.equal(2)
			expect(RankSpot.phase(true, "none", 1.9, nil)).to.equal("none")
			expect(RankSpot.phase(true, "none", 2, nil)).to.equal("button")
			expect(RankSpot.phase(false, "none", 10, nil)).to.equal("none")
		end)

		it("closes at once when the server's word goes or something else starts", function()
			expect(RankSpot.phase(false, "button", 10, nil)).to.equal("none")
			expect(RankSpot.phase(false, "confirm", 10, RankSpot.WINDOW)).to.equal("none")
			expect(RankSpot.phase(true, "button", 0, nil)).to.equal("none") -- a catch, a rescue, a carry
			expect(RankSpot.phase(true, "button", 10, "Store")).to.equal("none") -- another window
		end)

		it("lights the rank up window's button once the window is open", function()
			expect(RankSpot.phase(true, "button", 0.25, RankSpot.WINDOW)).to.equal("confirm")
			expect(RankSpot.phase(true, "confirm", 5, RankSpot.WINDOW)).to.equal("confirm")
			expect(RankSpot.phase(true, "confirm", 5, nil)).to.equal("button") -- the window closed
			expect(RankSpot.phase(true, "none", 0.5, RankSpot.WINDOW)).to.equal("none")
			expect(RankSpot.phase(true, "none", 2, RankSpot.WINDOW)).to.equal("confirm")
		end)

		it("puts it away for good only for a press after 2 seconds on screen", function()
			expect(RankSpot.putsAway(0.3)).to.equal(false)
			expect(RankSpot.putsAway(RankSpot.KEEP_SECONDS)).to.equal(true)
			-- a press while another card is up (a gift card's Close) never puts it away for good
			expect(RankSpot.putsAway(10, "button", "other")).to.equal(false)
			expect(RankSpot.putsAway(10, "button", RankSpot.WINDOW)).to.equal(false)
			expect(RankSpot.putsAway(10, "confirm", "other")).to.equal(false)
			expect(RankSpot.putsAway(10, "confirm", RankSpot.WINDOW)).to.equal(true)
			expect(RankSpot.putsAway(10, "button", nil)).to.equal(true)
		end)

		it("says only what to do", function()
			expect(RankSpot.WORDS.button).to.equal("You can rank up!")
			expect(RankSpot.WORDS.confirm).to.equal("Press to rank up")
		end)

		it("is saved in tipsSeen through TipSeen and kept by a load", function()
			expect(Tips.seenId(RankSpot.SEEN)).to.equal(true)
			expect(Tips.sanitizeSeen({ [RankSpot.SEEN] = true }, false)[RankSpot.SEEN]).to.equal(
				true
			)
		end)
	end)
end
