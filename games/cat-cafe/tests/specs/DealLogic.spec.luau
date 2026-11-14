--!strict
-- UI/Components/DealLogic.luau: the words on the Store's Today's Deal card (#3996).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Logic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("DealLogic")
	) :: any

	local NOON = 20000 * 86400 + 12 * 3600 -- a UTC noon

	describe("DealLogic.card", function()
		it("names the golden fish, the honest value and tomorrow's deal (#4238)", function()
			local card =
				Logic.card({ deal = 1, bought = false, tomorrow = 2 }, NOON, "Roll odds: x")
			expect(card.product).to.equal("deal_1")
			expect(card.kind).to.equal("fish")
			expect(card.contents).to.equal("250 Golden Fish")
			expect(card.value).to.equal("250 golden fish for R$25")
			expect(card.tomorrow).to.equal("Tomorrow: Trait Token deal")
			expect(card.price).to.equal("R$25")
			expect(card.odds).to.equal(nil) -- golden fish are not random
			expect(string.find(card.full, card.value, 1, true) ~= nil).to.equal(true)
		end)
		it("puts the golden crate's decor odds on a crate deal (#4238)", function()
			local card = Logic.card({ deal = 3, bought = false, tomorrow = 4 }, NOON, nil)
			expect(card.kind).to.equal("crate")
			expect(card.contents).to.equal("10 Golden Crates (your best area)")
			expect(card.value).to.equal("Each opens to an Epic or better decor piece")
			expect(card.odds).to.equal("Odds: Epic 70%, Legendary 24%, Mythical 6%")
			expect(card.tomorrow).to.equal("Tomorrow: Golden Haul deal")
			expect(string.find(card.short, "Odds: Epic", 1, true) ~= nil).to.equal(true)
			local haul = Logic.card({ deal = 4, bought = false, tomorrow = 1 }, NOON, nil)
			expect(haul.contents).to.equal("5 Golden Crates (your best area) · 100 Golden Fish")
			expect(haul.odds).to.equal(card.odds)
			expect(haul.fish).to.equal(true)
			expect(card.fish).to.equal(false)
		end)
		it("names the best open area's golden crate once the tier is known (#4238)", function()
			local card = Logic.card({ deal = 3, bought = false, tomorrow = 4 }, NOON, nil, 2)
			expect(card.crate).to.equal("park_golden_crate")
			expect(card.contents).to.equal("10 Golden Park Crates")
			local haul = Logic.card({ deal = 4, bought = false, tomorrow = 1 }, NOON, nil, 1)
			expect(haul.crate).to.equal("alley_golden_crate")
			expect(haul.contents).to.equal("5 Golden Alley Crates · 100 Golden Fish")
		end)
		it("puts the roll odds on the token deal, kept on a small card", function()
			local card = Logic.card(
				{ deal = 2, bought = false, tomorrow = 3 },
				NOON,
				"Roll odds: Common 35% · Rare 65%"
			)
			expect(card.kind).to.equal("token")
			expect(card.contents).to.equal("10 Trait Tokens")
			expect(card.value).to.equal("10 Trait Tokens, more than the 20 pack gives for R$25")
			expect(card.odds).to.equal("Roll odds: Common 35%, Rare 65%")
			expect(string.find(card.short, "Roll odds", 1, true) ~= nil).to.equal(true)
			expect(string.find(card.full, Logic.TOKEN_LINE, 1, true) ~= nil).to.equal(true)
		end)
		it("never offers a potion (#4238)", function()
			for n = 1, 4 do
				local card =
					Logic.card({ deal = n, bought = false, tomorrow = 1 }, NOON, "Roll odds: x")
				expect(card.kind).never.to.equal("potion")
				expect(string.find(string.lower(card.full), "potion", 1, true)).to.equal(nil)
			end
		end)
		it("says bought today and drops the button's words", function()
			local card = Logic.card({ deal = 4, bought = true, tomorrow = 1 }, NOON, nil)
			expect(card.bought).to.equal(true)
			expect(string.find(card.full, Logic.BOUGHT_LINE, 1, true) ~= nil).to.equal(true)
			expect(string.find(card.full, "new deal each day", 1, true)).to.equal(nil)
		end)
		it("shows nothing without a deal", function()
			expect(Logic.card(false, NOON, nil)).to.equal(nil)
			expect(Logic.card(nil, NOON, nil)).to.equal(nil)
			expect(Logic.card({ deal = 9, bought = false, tomorrow = 1 }, NOON, nil)).to.equal(nil)
		end)
	end)

	describe("DealLogic.changeText", function()
		it("names a clock time and never a countdown", function()
			local line = Logic.changeText(NOON)
			expect(string.match(line, "^A new deal each day at %d+:%d%d [AP]M$") ~= nil).to.equal(
				true
			)
			for _, word in { "left", "ends", "only", "last", "hurry" } do
				expect(string.find(string.lower(line), word, 1, true)).to.equal(nil)
			end
		end)
	end)
end
