--!strict
-- UI/Components/GiftCardLogic.luau: the like and favourite gift cards' words, pictures and timing (#1947,
-- like-prompts.md section 2).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local GiftCardLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("GiftCardLogic")
	) :: any

	describe("GiftCardLogic.TEXT", function()
		it("never says the gift needs a like or a favourite", function()
			for _, text in GiftCardLogic.TEXT do
				local words = (text.title .. " " .. text.body):lower()
				expect(words:find("gift", 1, true) ~= nil).to.equal(true)
				expect(words:find("to get", 1, true)).to.equal(nil)
				expect(words:find("for a", 1, true)).to.equal(nil)
				expect(words:find("unlock", 1, true)).to.equal(nil)
			end
		end)

		it("names each card's first button as the playtime_gift report does", function()
			expect(GiftCardLogic.TEXT.like.button).to.equal("like")
			expect(GiftCardLogic.TEXT.fav.button).to.equal("favourite")
			expect(GiftCardLogic.report("like", "like")).to.equal("like:like")
			expect(GiftCardLogic.report("fav", "favourite")).to.equal("fav:favourite")
			expect(GiftCardLogic.report("fav", GiftCardLogic.CLOSE_BUTTON)).to.equal("fav:close")
		end)

		it(
			"never asks a player to leave now for the 👍, and has Got it alone on touch (#2705)",
			function()
				local like = GiftCardLogic.TEXT.like
				local lines: { string } = { like.body, like.after }
				for _, words in lines do
					local low = string.lower(words)
					expect(string.find(low, "when you leave", 1, true)).to.equal(nil)
					expect(string.find(low, "next time", 1, true) ~= nil).to.equal(true)
				end
				expect(GiftCardLogic.single("like", true)).to.equal(true)
				expect(GiftCardLogic.single("like", false)).to.equal(false)
				expect(GiftCardLogic.single("fav", true)).to.equal(false)
				expect(GiftCardLogic.report("like", GiftCardLogic.GOT_IT_BUTTON)).to.equal(
					"like:gotit"
				)
			end
		)
	end)

	describe("GiftCardLogic.prize", function()
		local like = { coinSeconds = 900, potions = { tip_potion = 1 } }

		it("draws the coins Payout really paid", function()
			local prize = GiftCardLogic.prize(like, { "+$12345", "1 Tip Potion" })
			expect(prize.coins).to.equal(12345)
			expect(prize.coinSeconds).to.equal(nil)
			expect(prize.potions.tip_potion).to.equal(1)
			expect(like.coinSeconds).to.equal(900) -- the shared prize is not changed
		end)

		it("keeps coinSeconds with no coins line", function()
			expect(GiftCardLogic.prize(like, nil).coinSeconds).to.equal(900)
			expect(GiftCardLogic.prize(like, { "1 Tip Potion" }).coins).to.equal(nil)
		end)
	end)

	describe("GiftCardLogic.canShow", function()
		local function gate(over: { [string]: any })
			local base = {
				idleSeconds = 4,
				idleNeeded = 3,
				catching = false,
				carrying = false,
				intro = false,
				menuOpen = false,
			}
			for key, value in over do
				base[key] = value
			end
			return base
		end

		it("waits for the player to be idle and out of everything else", function()
			expect(GiftCardLogic.canShow(gate({}))).to.equal(true)
			expect(GiftCardLogic.canShow(gate({ idleSeconds = 2 }))).to.equal(false)
			expect(GiftCardLogic.canShow(gate({ catching = true }))).to.equal(false)
			expect(GiftCardLogic.canShow(gate({ carrying = true }))).to.equal(false)
			expect(GiftCardLogic.canShow(gate({ intro = true }))).to.equal(false)
			expect(GiftCardLogic.canShow(gate({ menuOpen = true }))).to.equal(false)
		end)
	end)
end
