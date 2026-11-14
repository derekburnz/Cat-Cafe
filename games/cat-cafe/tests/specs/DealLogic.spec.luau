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
		it("names the contents, the honest value and tomorrow's deal", function()
			local card = Logic.card({ deal = 1, bought = false, tomorrow = 2 }, NOON, "Roll odds: x")
			expect(card.product).to.equal("deal_1")
			expect(card.contents).to.equal("5 Big Money · 2 Swift")
			expect(card.value).to.equal("7 potions for R$25, more than Potion Pack S")
			expect(card.tomorrow).to.equal("Tomorrow: Trait Token deal")
			expect(card.price).to.equal("R$25")
			expect(card.odds).to.equal(nil) -- a potion deal has nothing random
			expect(string.find(card.full, card.value, 1, true) ~= nil).to.equal(true)
		end)
		it("compares the Steady Paw deal with the Steady Paw Pack", function()
			local card = Logic.card({ deal = 3, bought = false, tomorrow = 4 }, NOON, nil)
			expect(card.contents).to.equal("2 Big Money · 10 Steady Paw")
			expect(card.value).to.equal("12 potions, 2 more than the Steady Paw Pack")
			expect(card.tomorrow).to.equal("Tomorrow: Potion Mix deal")
		end)
		it("puts the roll odds on the token deal, kept on a small card", function()
			local card = Logic.card({ deal = 2, bought = false, tomorrow = 3 }, NOON, "Roll odds: Common 35% · Rare 65%")
			expect(card.kind).to.equal("token")
			expect(card.contents).to.equal("7 Trait Tokens")
			expect(card.value).to.equal("7 Trait Tokens, more than the 20 pack gives for R$25")
			expect(card.odds).to.equal("Roll odds: Common 35%, Rare 65%")
			expect(string.find(card.short, "Roll odds", 1, true) ~= nil).to.equal(true)
			expect(string.find(card.full, Logic.TOKEN_LINE, 1, true) ~= nil).to.equal(true)
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
			expect(string.match(line, "^A new deal each day at %d+:%d%d [AP]M$") ~= nil).to.equal(true)
			for _, word in { "left", "ends", "only", "last", "hurry" } do
				expect(string.find(string.lower(line), word, 1, true)).to.equal(nil)
			end
		end)
	end)
end
