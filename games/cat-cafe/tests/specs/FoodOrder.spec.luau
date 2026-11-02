--!strict
-- UI/Components/FoodOrder.luau: every food list in rarity order (F97 section 3).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local FoodOrder = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("FoodOrder")
	) :: any
	local Catalog = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
	) :: any

	local function ids(list: { any }): string
		local out: { string } = {}
		for _, item in list do
			table.insert(out, item.id)
		end
		return table.concat(out, ",")
	end

	describe("FoodOrder", function()
		it("puts the catalog's foods in the section 3 order, shop and dealer together", function()
			expect(ids(FoodOrder.defs(Catalog.lures))).to.equal(
				"kibble,tuna,sardines,salmon,caviar,moon_milk,star_treat"
			)
		end)

		it("leaves the catalog's own list alone", function()
			local before = ids(Catalog.lures)
			FoodOrder.defs(Catalog.lures)
			expect(ids(Catalog.lures)).to.equal(before)
		end)

		it("follows the catalog's sortOrder once it has one", function()
			local foods = {
				{ id = "kibble", cost = 100, rarity = "Common", sortOrder = 3 },
				{ id = "tuna", cost = 500, rarity = "Rare", sortOrder = 1 },
				{ id = "salmon", cost = 2500, rarity = "Epic", sortOrder = 2 },
			}
			expect(ids(FoodOrder.defs(foods :: any))).to.equal("tuna,salmon,kibble")
		end)

		it("orders by grade, then price, then the design's list for bare ids", function()
			local foods = {
				{ id = "b", cost = 900, rarity = "Rare" },
				{ id = "a", cost = 50, rarity = "Epic" },
				{ id = "c", cost = 10, rarity = "Rare" },
			}
			expect(ids(FoodOrder.defs(foods :: any))).to.equal("c,b,a")
			local bare =
				{ { id = "star_treat" }, { id = "sardines" }, { id = "tuna" }, { id = "kibble" } }
			FoodOrder.sort(bare, function(entry: any): (string, any)
				return entry.id, nil
			end)
			expect(ids(bare)).to.equal("kibble,tuna,sardines,star_treat")
		end)
	end)
end
