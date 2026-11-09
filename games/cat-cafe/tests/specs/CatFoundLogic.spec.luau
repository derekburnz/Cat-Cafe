--!strict
-- UI/Components/CatFoundLogic.luau: the big cat found card only for new or Legendary+ catches (#2833).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local CatFoundLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("CatFoundLogic")
	) :: any

	describe("CatFoundLogic.big", function()
		it("keeps the big card for a new cat of any rarity", function()
			expect(CatFoundLogic.big("Common", true, nil)).to.equal(true)
			expect(CatFoundLogic.big("Rare", true, {})).to.equal(true)
		end)

		it("keeps it for Legendary, Mythical and Golden repeats", function()
			expect(CatFoundLogic.big("Legendary", false, nil)).to.equal(true)
			expect(CatFoundLogic.big("Mythical", false, nil)).to.equal(true)
			expect(CatFoundLogic.big("Golden", false, nil)).to.equal(true)
		end)

		it("gives repeats below Legendary the toast", function()
			for _, rarity in { "Common", "Uncommon", "Rare", "Epic" } do
				expect(CatFoundLogic.big(rarity, false, nil)).to.equal(false)
				expect(CatFoundLogic.big(rarity, nil, { charmGain = 2 })).to.equal(false)
			end
		end)

		it("keeps it for a gold or rainbow coat and a card with its own words", function()
			expect(CatFoundLogic.big("Common", false, { shiny = true })).to.equal(true)
			expect(CatFoundLogic.big("Common", false, { rainbow = true })).to.equal(true)
			expect(CatFoundLogic.big("Common", false, { banner = "FREE COMMON CAT!" })).to.equal(
				true
			)
			expect(
				CatFoundLogic.big("Common", false, { line = "The Bellhop Cat joined your cafe!" })
			).to.equal(true)
		end)
	end)
end
