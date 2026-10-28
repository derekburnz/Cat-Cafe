--!strict
-- UI/Components/ShopIcons.luau: the uploaded crate, treat, perk, net and potion icons found by the game's ids.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local ShopIcons = require(Components:WaitForChild("ShopIcons")) :: any
	local Catalog = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
	) :: any

	describe("ShopIcons", function()
		it("has a picture for every crate in the catalog, plain and golden", function()
			expect(ShopIcons.crate("park_crate")).to.equal(ShopIcons.image("Crate_Park"))
			expect(ShopIcons.crate("neighbourhood_golden_crate")).to.equal(
				ShopIcons.image("Crate_Neighbourhood_Gold")
			)
			local missing: { string } = {}
			for _, crate in Catalog.crates do
				if ShopIcons.crate(crate.id) == nil then
					table.insert(missing, crate.id)
				end
			end
			expect(table.concat(missing, ",")).to.equal("")
			expect(ShopIcons.crate("highest")).to.equal(nil)
			expect(ShopIcons.crate(nil)).to.equal(nil)
		end)

		it("has a bottle for every potion in the catalog", function()
			expect(ShopIcons.potion("gold_rush_potion")).to.equal(ShopIcons.image("Potion_GoldRush"))
			local missing: { string } = {}
			for _, potion in Catalog.potions do
				if ShopIcons.potion(potion.id) == nil then
					table.insert(missing, potion.id)
				end
			end
			expect(table.concat(missing, ",")).to.equal("")
			expect(ShopIcons.potion("moon_potion")).to.equal(nil)
		end)

		it("draws the Market's perks and the Star Treat, and nothing for other foods", function()
			for _, row in Catalog.fishShop do
				if row.kind == "perk" then
					expect(ShopIcons.perk(row.id)).to.be.ok()
				end
			end
			expect(ShopIcons.food("star_treat")).to.equal(ShopIcons.image("StarTreat"))
			expect(ShopIcons.food("tuna")).to.equal(nil)
		end)

		it("offers the next net, staying on the top one", function()
			expect(ShopIcons.net(0)).to.equal(ShopIcons.image("Net_L1"))
			expect(ShopIcons.net(1)).to.equal(ShopIcons.image("Net_L2"))
			expect(ShopIcons.net(2)).to.equal(ShopIcons.image("Net_L3"))
			expect(ShopIcons.net(3)).to.equal(ShopIcons.image("Net_L3"))
			expect(ShopIcons.net(nil)).to.equal(ShopIcons.image("Net_L1"))
		end)
	end)
end
