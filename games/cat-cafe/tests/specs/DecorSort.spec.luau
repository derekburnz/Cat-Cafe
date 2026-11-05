--!strict
-- UI/Components/DecorPieces.byRarity: every Decor list rarest first (#1409).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local DecorPieces = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("DecorPieces")
	) :: any

	local function rarityOf(entry: any): string?
		return entry.rarity
	end

	describe("DecorPieces.byRarity", function()
		it("puts the rarest first and keeps catalog order within a rarity", function()
			local list = {
				{ id = "a", rarity = "Common" },
				{ id = "b", rarity = "Mythical" },
				{ id = "c", rarity = "Rare" },
				{ id = "d", rarity = "Common" },
				{ id = "e", rarity = "Legendary" },
			}
			local ids = {}
			for _, entry in DecorPieces.byRarity(list, rarityOf) do
				table.insert(ids, entry.id)
			end
			expect(table.concat(ids, ",")).to.equal("b,e,c,a,d")
		end)

		it("ranks the lawn's Golden and Uncommon, and puts no rarity last", function()
			local list = {
				{ id = "plain" },
				{ id = "mint", rarity = "Uncommon" },
				{ id = "gold", rarity = "Golden" },
				{ id = "common", rarity = "Common" },
			}
			local ids = {}
			for _, entry in DecorPieces.byRarity(list, rarityOf) do
				table.insert(ids, entry.id)
			end
			expect(table.concat(ids, ",")).to.equal("gold,mint,common,plain")
		end)

		it("leaves the list it was given alone", function()
			local list = { { id = "x", rarity = "Common" }, { id = "y", rarity = "Epic" } }
			DecorPieces.byRarity(list, rarityOf)
			expect(list[1].id).to.equal("x")
		end)
	end)
end
