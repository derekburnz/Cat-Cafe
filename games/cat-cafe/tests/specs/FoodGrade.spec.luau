--!strict
-- UI/Components/FoodGrade.luau: how good a food is, for its badge and border (F69, data-model section 8).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local FoodGrade = require(Components:WaitForChild("FoodGrade")) :: any
	local Catalog = require(game:GetService("ReplicatedStorage").Shared.Catalog) :: any

	local function lure(id: string, attracts: string, rarity: string?)
		return { id = id, name = id, attracts = attracts, rarity = rarity }
	end

	describe("FoodGrade.of", function()
		it("grades every catalog food as the design does (round 4 Q11)", function()
			local want = {
				kibble = "Common",
				tuna = "Rare",
				sardines = "Rare",
				salmon = "Epic",
				caviar = "Epic",
				moon_milk = "Legendary",
				star_treat = "Mythical",
			}
			local seen = 0
			for _, def in Catalog.lures do
				expect(FoodGrade.of(def)).to.equal(want[def.id])
				seen += 1
			end
			expect(seen).to.equal(7)
		end)

		it("reads the catalog's own rarity first, when the engineer adds it", function()
			expect(FoodGrade.of(lure("tuna", "Rare", "Epic"))).to.equal("Epic")
			expect(FoodGrade.of(lure("tuna", "Rare", "Shiny"))).to.equal("Rare")
		end)

		it("falls back to what an unknown food attracts, then Common", function()
			expect(FoodGrade.of(lure("cake", "Legendary"))).to.equal("Legendary")
			expect(FoodGrade.of(lure("cake", "Odd"))).to.equal("Common")
			expect(FoodGrade.of(nil)).to.equal("Common")
		end)
	end)

	describe("FoodGrade text", function()
		it("writes the badge as a word, or a letter for a small picture", function()
			expect(FoodGrade.badge("Legendary")).to.equal("LEGENDARY")
			expect(FoodGrade.badge("Mythical", true)).to.equal("M")
		end)

		it("keeps the attracts chip's meaning", function()
			expect(FoodGrade.attracts(lure("moon_milk", "Epic"))).to.equal("Attracts Epic")
		end)
	end)
end
