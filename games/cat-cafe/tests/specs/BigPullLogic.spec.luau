--!strict
-- UI/Components/BigPullLogic.luau: which big pull card plays, its rarity word and its times (F89,
-- luck-and-rare-moments.md 2a and 2b; F99 rainbow-coat.md section 2).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local BigPullLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("BigPullLogic")
	) :: any

	describe("BigPullLogic.forCat", function()
		it("plays the big card for a Legendary, a Mythical and a gold Epic or better", function()
			expect(BigPullLogic.forCat("Legendary", false, "base")).to.equal("big")
			expect(BigPullLogic.forCat("Mythical", false, nil)).to.equal("big")
			expect(BigPullLogic.forCat("Epic", true, "gold")).to.equal("big")
			expect(BigPullLogic.forCat("Mythical", true, nil)).to.equal("big")
		end)

		it("plays the big card for every rainbow cat, whatever its rarity", function()
			expect(BigPullLogic.forCat("Common", false, "rainbow")).to.equal("big")
			expect(BigPullLogic.forCat("Rare", false, "rainbow")).to.equal("big")
		end)

		it("plays the smaller card for a plain Epic, which the server sends only for the first", function()
			expect(BigPullLogic.forCat("Epic", false, "base")).to.equal("first_epic")
		end)

		it("plays nothing for a plain or gold Common or Rare", function()
			expect(BigPullLogic.forCat("Common", false, nil)).to.equal(nil)
			expect(BigPullLogic.forCat("Rare", true, "gold")).to.equal(nil)
			expect(BigPullLogic.forCat(nil :: any, false, nil)).to.equal(nil)
		end)
	end)

	describe("BigPullLogic.forPiece", function()
		it("plays the big card for a Legendary or Mythical crate piece only", function()
			expect(BigPullLogic.forPiece("Legendary")).to.equal("big")
			expect(BigPullLogic.forPiece("Mythical")).to.equal("big")
			expect(BigPullLogic.forPiece("Epic")).to.equal(nil)
			expect(BigPullLogic.forPiece(nil)).to.equal(nil)
		end)
	end)

	describe("BigPullLogic.word and tone", function()
		it("says the rarity, with GOLD or RAINBOW before it", function()
			expect(BigPullLogic.word("big", "Legendary", false, nil)).to.equal("LEGENDARY!")
			expect(BigPullLogic.word("big", "Mythical", true, "gold")).to.equal("GOLD MYTHICAL!")
			expect(BigPullLogic.word("big", "Epic", true, nil)).to.equal("GOLD EPIC!")
			expect(BigPullLogic.word("big", "Common", false, "rainbow")).to.equal("RAINBOW COMMON!")
			expect(BigPullLogic.word("big", "Mythical", true, "rainbow")).to.equal("RAINBOW MYTHICAL!")
			expect(BigPullLogic.word("first_epic", "Epic", false, "base")).to.equal("FIRST EPIC!")
		end)

		it("colours a gold coat gold and a rainbow coat in bands", function()
			expect(BigPullLogic.tone(false, "base")).to.equal("rarity")
			expect(BigPullLogic.tone(true, nil)).to.equal("gold")
			expect(BigPullLogic.tone(false, "gold")).to.equal("gold")
			expect(BigPullLogic.tone(true, "rainbow")).to.equal("rainbow")
		end)
	end)

	describe("BigPullLogic.times and mine", function()
		it("takes a tap after 1 s and closes by itself at 2.4 s, the first Epic at 2 s", function()
			local tapAfter, closeAt = BigPullLogic.times("big")
			expect(tapAfter).to.equal(1)
			expect(closeAt).to.equal(2.4)
			tapAfter, closeAt = BigPullLogic.times("first_epic")
			expect(tapAfter).to.equal(1)
			expect(closeAt).to.equal(2)
		end)

		it("waits for the crate's lid, the word slams from 1.6 times", function()
			expect(BigPullLogic.CRATE_HOLD).to.equal(0.6)
			expect(BigPullLogic.SLAM).to.equal(1.6)
		end)

		it("plays only for the securing player", function()
			expect(BigPullLogic.mine(42, 42)).to.equal(true)
			expect(BigPullLogic.mine(7, 42)).to.equal(false)
			expect(BigPullLogic.mine("42", 42)).to.equal(false)
		end)
	end)
end
