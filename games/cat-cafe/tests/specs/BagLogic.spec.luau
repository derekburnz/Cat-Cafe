--!strict
-- UI/Components/BagLogic.luau: the Bag's Cat Food tab (#1181, corner-shop-v2.md section 3).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Bag = require(Components:WaitForChild("BagLogic")) :: any
	local defs = {
		{ id = "small_cat_snack", name = "Small Snack", xp = 600 },
		{ id = "cat_snack", name = "Cat Snack", xp = 2000 },
		{ id = "cat_feast", name = "Cat Feast", xp = 20000 },
	}

	describe("BagLogic", function()
		it("lists only the foods the player has, in catalog order", function()
			local foods =
				Bag.foods(defs, { cat_feast = 1, cat_snack = 3, small_cat_snack = 0, unknown = 4 })
			expect(#foods).to.equal(2)
			expect(foods[1].id).to.equal("cat_snack")
			expect(foods[1].count).to.equal(3)
			expect(foods[2].id).to.equal("cat_feast")
			expect(#Bag.foods(defs, nil)).to.equal(0)
			expect(#Bag.foods(nil, { cat_snack = 1 })).to.equal(0)
		end)
		it("lists the bait foods the player has, in catalog order (#1281)", function()
			local lures = {
				{ id = "kibble", name = "Kibble" },
				{ id = "tuna", name = "Tuna" },
				{ id = "salmon", name = "Salmon" },
			}
			local baits = Bag.baits(lures, { salmon = 2, kibble = 5, tuna = 0, caviar = 1 })
			expect(#baits).to.equal(2)
			expect(baits[1].id).to.equal("kibble")
			expect(baits[1].count).to.equal(5)
			expect(baits[2].name).to.equal("Salmon")
			expect(baits[2].def.id).to.equal("salmon")
			expect(#Bag.baits(lures, nil)).to.equal(0)
			expect(#Bag.baits(nil, { kibble = 1 })).to.equal(0)
		end)
		it("counts everything in the Bag", function()
			expect(Bag.total({ potions = { tip_potion = 2 }, catFood = { cat_snack = 3 } })).to.equal(
				5
			)
			expect(Bag.total({})).to.equal(0)
		end)
		it("words the XP and the cat's level line", function()
			expect(Bag.xpLine(2000)).to.equal("+2,000 XP")
			-- level 23 needs 120 x 23 = 2,760 XP to 24; with 1,360 in, 1,400 to go
			expect(Bag.catLine(23, 1360)).to.equal("Level 23 · 1,400 XP to 24")
			expect(Bag.catLine(50, 0)).to.equal("Level 50 · Max")
			expect(Bag.canFeed(49)).to.equal(true)
			expect(Bag.canFeed(50)).to.equal(false)
		end)
	end)
end
