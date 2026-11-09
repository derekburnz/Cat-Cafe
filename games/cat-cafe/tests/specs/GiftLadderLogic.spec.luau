--!strict
-- UI/Components/GiftLadderLogic.luau: the gift ladder's next steps on the Rewards tile (#2791).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local GiftLadderLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GiftLadderLogic")
	) :: any

	describe("GiftLadderLogic.words", function()
		it("names what each step pays, short", function()
			expect(GiftLadderLogic.words({ spins = 1 })).to.equal("+1 spin")
			expect(GiftLadderLogic.words({ fish = 5 })).to.equal("+5 golden fish")
			expect(GiftLadderLogic.words({ potions = { swift_potion = 1 } })).to.equal(
				"Swift Potion"
			)
			expect(GiftLadderLogic.words({ lures = { tuna = 1 } })).to.equal("Bait food")
			expect(GiftLadderLogic.words({ coinSeconds = 60 }, 10)).to.equal("$600")
			expect(GiftLadderLogic.words(nil)).to.equal("A gift")
		end)

		it("names at most two things, so a row stays one line", function()
			local words = GiftLadderLogic.words({
				coinSeconds = 60,
				potions = { tip_potion = 1, lucky_potion = 1, swift_potion = 1 },
			}, 10)
			expect(words).to.equal("$600, Lucky Potion")
		end)
	end)

	describe("GiftLadderLogic.rows", function()
		it("counts down from the play time, never below zero, two steps at most", function()
			local steps = {
				{ id = "m2", at = 120, prize = { coinSeconds = 60 } },
				{ id = "m4", at = 240, prize = { lures = { tuna = 1 } } },
				{ id = "m6", at = 360, prize = { spins = 1 } },
			}
			local rows = GiftLadderLogic.rows(steps, 15, 10)
			expect(#rows).to.equal(2)
			expect(rows[1].left).to.equal(105)
			expect(GiftLadderLogic.line(rows[1])).to.equal("1:45  $600")
			expect(GiftLadderLogic.rows(steps, 500)[1].left).to.equal(0)
		end)

		it("is empty once the ladder is done, and from a server without it", function()
			expect(#GiftLadderLogic.rows({}, 100)).to.equal(0)
			expect(#GiftLadderLogic.rows(nil, 100)).to.equal(0)
			expect(#GiftLadderLogic.rows({ { id = "m2", at = 120 } }, nil)).to.equal(0)
		end)
	end)
end
