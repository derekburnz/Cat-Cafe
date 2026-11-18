--!strict
-- shared/NextGoal.luau (#5202): the "What next?" card's words and reports.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local NextGoal = require(Shared.NextGoal) :: any
	local Tips = require(Shared.Tips) :: any

	local function money(n: number): string
		return "$" .. tostring(n)
	end

	describe("NextGoal", function()
		it("says what Tier 3 still needs, cats first", function()
			local card = NextGoal.card({
				catsHave = 3,
				catsNeed = 5,
				rarity = nil,
				rarityHave = 0,
				rarityNeed = 0,
				coinsHave = 400,
				coinsNeed = 1500,
			}, money)
			expect(card.variant).to.equal("A")
			expect(card.first).to.equal("cats")
			expect(card.line).to.equal("Tier 3 needs 2 more kinds of cat and $1100.")
			card = NextGoal.card({
				catsHave = 5,
				catsNeed = 5,
				rarity = "Rare",
				rarityHave = 0,
				rarityNeed = 1,
				coinsHave = 2000,
				coinsNeed = 1500,
			}, money)
			expect(card.first).to.equal("cats")
			expect(card.line).to.equal("Tier 3 needs a Rare or better cat.")
			expect(card.rarity).to.equal("Rare")
			card = NextGoal.card({
				catsHave = 6,
				catsNeed = 5,
				rarity = nil,
				rarityHave = 0,
				rarityNeed = 0,
				coinsHave = 100,
				coinsNeed = 1500,
			}, money)
			expect(card.first).to.equal("cafe")
			expect(card.line).to.equal("Tier 3 needs $1400.")
		end)

		it("gives the long goals after Tier 3", function()
			local card = NextGoal.card(nil, money)
			expect(card.variant).to.equal("B")
			expect(card.first).to.equal("cats")
		end)

		it("encodes and decodes only the fixed reports", function()
			expect(NextGoal.encode("shown", "A")).to.equal("shown:A")
			expect(NextGoal.encode("tap", "cafe")).to.equal("tap:cafe")
			expect(NextGoal.encode("tap", "store")).to.equal(nil)
			local kind, value = NextGoal.decode("tap:closed")
			expect(kind).to.equal("tap")
			expect(value).to.equal("closed")
			expect((NextGoal.decode("shown:C"))).to.equal(nil)
			expect((NextGoal.decode("buy:cats"))).to.equal(nil)
			expect((NextGoal.decode(5))).to.equal(nil)
		end)

		it("is kept in tipsSeen like the asks, Show tips again included", function()
			expect(NextGoal.SEEN).to.equal(Tips.NEXT_GOAL)
			expect(Tips.seenId(NextGoal.SEEN)).to.equal(true)
			expect(Tips.cleared({ [NextGoal.SEEN] = true })[NextGoal.SEEN]).to.equal(true)
		end)
	end)
end
