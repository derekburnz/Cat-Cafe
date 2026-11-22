--!strict
-- UI/Components/RankOneTap (#5533, switch rankOneTap): when the goal card is the RANK UP button and which taps count.

return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local RankOneTap = require(Components:WaitForChild("RankOneTap")) :: any
	local LiveFlags = require(game:GetService("ReplicatedStorage").Shared.LiveFlags) :: any

	describe("RankOneTap", function()
		it("is a switch that ships off", function()
			expect(RankOneTap.FLAG).to.equal("rankOneTap")
			expect(LiveFlags.OFF_BY_DEFAULT[RankOneTap.FLAG]).to.equal(true)
			expect(LiveFlags.shown(RankOneTap.FLAG, nil)).to.equal(false)
		end)

		it("is the button only with the switch on and the rank up ready", function()
			expect(RankOneTap.active(true, true)).to.equal(true)
			expect(RankOneTap.active(true, false)).to.equal(false)
			expect(RankOneTap.active(false, true)).to.equal(false)
			expect(RankOneTap.active(false, false)).to.equal(false)
		end)

		it("ignores a tap in the first moment after the card turned into the button", function()
			expect(RankOneTap.accepts(10, nil, nil)).to.equal(false) -- never the button
			expect(RankOneTap.accepts(10.1, 10, nil)).to.equal(false)
			expect(RankOneTap.accepts(10 + RankOneTap.GUARD - 0.01, 10, nil)).to.equal(false)
			expect(RankOneTap.accepts(10 + RankOneTap.GUARD, 10, nil)).to.equal(true)
		end)

		it("rests after a counted tap, so a double tap sends one rank up", function()
			expect(RankOneTap.accepts(20.2, 10, 20)).to.equal(false)
			expect(RankOneTap.accepts(20 + RankOneTap.REST, 10, 20)).to.equal(true)
		end)

		it(
			"rankChain: the next tap counts a moment after the sync shows the new tier (#5656)",
			function()
				-- tapped at 20, no answer yet: rests as before, so a double tap still buys one tier
				expect(RankOneTap.acceptsChain(20.5, 10, 20, nil)).to.equal(false)
				expect(RankOneTap.acceptsChain(20 + RankOneTap.REST, 10, 20, nil)).to.equal(true)
				-- the sync showed the new tier at 20.3: a tap from 20.55 counts
				expect(RankOneTap.acceptsChain(20.4, 10, 20, 20.3)).to.equal(false)
				expect(RankOneTap.acceptsChain(20.3 + RankOneTap.CHAIN_GUARD, 10, 20, 20.3)).to.equal(
					true
				)
				-- an answer from before this tap does not count for it
				expect(RankOneTap.acceptsChain(20.6, 10, 20, 19)).to.equal(false)
				-- the card's own guard still holds, and the first tap is free
				expect(RankOneTap.acceptsChain(10.1, 10, nil, nil)).to.equal(false)
				expect(RankOneTap.acceptsChain(10 + RankOneTap.GUARD, 10, nil, nil)).to.equal(true)
			end
		)

		it("words the line under RANK UP! from the tier and its cost", function()
			expect(RankOneTap.line("Cozy Cafe", "$1,000 coins")).to.equal(
				"Cozy Cafe · $1,000 coins"
			)
			expect(RankOneTap.line("Cozy Cafe", nil)).to.equal("Cozy Cafe")
			expect(RankOneTap.line(nil, nil)).to.equal("")
		end)

		it("draws 1.3 times as big only on a tablet with tabletRankBig on (#5669)", function()
			expect(RankOneTap.TABLET_FLAG).to.equal("tabletRankBig")
			expect(LiveFlags.OFF_BY_DEFAULT[RankOneTap.TABLET_FLAG]).to.equal(true)
			expect(RankOneTap.size(true, true)).to.equal(1.3)
			expect(RankOneTap.size(true, false)).to.equal(1)
			expect(RankOneTap.size(false, true)).to.equal(1)
		end)
	end)
end
