--!strict
-- UI/Components/ShopIcons.luau: the uploaded crate, food, perk, net, potion and prize icons found by the game's ids.
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
			expect(ShopIcons.crate("rally_crate")).to.equal(ShopIcons.image("Crate_Rally")) -- F101, banked only
			expect(ShopIcons.crateModel("rally_crate")).to.equal("CatCafe_Prop_Crate_Rally")
			expect(ShopIcons.crate("highest")).to.equal(nil)
			expect(ShopIcons.crate(nil)).to.equal(nil)
		end)

		it("gives a potion size its regular potion's bottle (#1250)", function()
			expect(ShopIcons.potion("swift_potion_small")).to.equal(
				ShopIcons.potion("swift_potion")
			)
			expect(ShopIcons.potion("quick_bait_potion_big")).to.equal(
				ShopIcons.potion("quick_bait_potion")
			)
			expect(ShopIcons.potion("cat_whistle_big")).to.equal(ShopIcons.potion("cat_whistle"))
			expect(ShopIcons.potion("cat_whistle") ~= nil).to.equal(true)
		end)
		it("lists every bottle a potion has, flask first (#1256)", function()
			local all = ShopIcons.potionAll("swift_potion")
			expect(#all).to.equal(3)
			expect(all[1]).to.equal(ShopIcons.potion("swift_potion"))
			expect(all[1] ~= all[2]).to.equal(true)
			expect(#ShopIcons.potionAll("not_a_potion")).to.equal(0)
			expect(#ShopIcons.potionAll(nil)).to.equal(0)
		end)
		it("has the three shop cats' pictures (#1191)", function()
			expect(ShopIcons.shopCat("Sprinkles")).to.equal("rbxassetid://123101439533132")
			expect(ShopIcons.shopCat("DuchessMarzipan")).to.equal("rbxassetid://105207350898043")
			expect(ShopIcons.shopCat("KingCroissant")).to.equal("rbxassetid://127183027799927")
			expect(ShopIcons.shopCat("Nobody")).to.equal(nil)
		end)
		it("has a bottle for every potion in the catalog", function()
			-- the clean bottle first (#1070), the old picture behind it
			expect(ShopIcons.potion("gold_rush_potion")).to.equal("rbxassetid://133671235439574") -- the #1193 flask (#1204)
			local missing: { string } = {}
			for _, potion in Catalog.potions do
				if ShopIcons.potion(potion.id) == nil then
					table.insert(missing, potion.id)
				end
			end
			expect(table.concat(missing, ",")).to.equal("")
			expect(ShopIcons.potion("moon_potion")).to.equal(nil)
		end)

		it("draws the Market's perks and every food in the catalog (F97)", function()
			for _, row in Catalog.fishShop do
				if row.kind == "perk" then
					expect(ShopIcons.perk(row.id)).to.be.ok()
				end
			end
			-- the clean food pictures (#1070)
			expect(ShopIcons.food("star_treat")).to.equal("rbxassetid://127060767808144")
			expect(ShopIcons.food("moon_milk")).to.equal("rbxassetid://107176560784324")
			-- the spin wheel's food (#1242)
			expect(ShopIcons.food("caviar")).to.equal(ShopIcons.clean("Caviar"))
			-- #1242: every food in the catalog, shop and dealer alike, resolves to its clean 2D picture, so
			-- ItemIcon never falls back to the old 3D render for a food
			local clean: { [string]: string } = {
				kibble = "Kibble",
				tuna = "Tuna",
				salmon = "Salmon",
				sardines = "Sardines",
				caviar = "Caviar",
				moon_milk = "MoonMilk",
				star_treat = "StarTreat",
			}
			local missing: { string } = {}
			for _, lure in Catalog.lures do
				local picture = ShopIcons.food(lure.id)
				local name = clean[lure.id]
				if picture == nil or name == nil or picture ~= ShopIcons.clean(name) then
					-- a new food needs a clean picture and a line above
					table.insert(missing, lure.id)
				end
			end
			expect(table.concat(missing, ",")).to.equal("")
			expect(ShopIcons.food("pizza")).to.equal(nil)
			expect(ShopIcons.food(nil)).to.equal(nil)
		end)

		it("has the clean money, golden fish and spin prize pictures (#1242)", function()
			expect(ShopIcons.prize("coins")).to.equal(ShopIcons.clean("Bag"))
			-- the same id as Theme.textures.fishCoin
			expect(ShopIcons.prize("fish")).to.equal(ShopIcons.clean("Fish"))
			expect(ShopIcons.prize("spins")).to.equal(ShopIcons.clean("Spin"))
			for _, kind in { "coins", "fish", "spins" } do
				local picture = ShopIcons.prize(kind) :: string
				expect(string.match(picture, "^rbxassetid://%d+$")).to.be.ok()
			end
			expect(ShopIcons.prize("lure")).to.equal(nil)
			expect(ShopIcons.prize(nil)).to.equal(nil)
		end)

		it("has the prize pictures for coins and spins (F97 section 4)", function()
			expect(ShopIcons.image("Coins")).to.equal("rbxassetid://114567888385946")
			expect(ShopIcons.image("Spin")).to.equal("rbxassetid://126057350997233") -- the clean wheel (#1070)
		end)

		it("offers the next net, staying on the top one", function()
			-- levels 0 Basic, 1 Sturdy, 2 Pro, 3 Master: the row shows the net a buy gets
			expect(ShopIcons.net(0)).to.equal(ShopIcons.image("Net_L2"))
			expect(ShopIcons.net(1)).to.equal(ShopIcons.image("Net_L3"))
			expect(ShopIcons.net(2)).to.equal(ShopIcons.image("Net_L4"))
			expect(ShopIcons.net(3)).to.equal(ShopIcons.image("Net_L4"))
			expect(ShopIcons.net(nil)).to.equal(ShopIcons.image("Net_L2"))
			expect(ShopIcons.image("Net_L4")).to.be.ok()
		end)

		it("has a clean picture for every decor piece in the catalog (#1072)", function()
			local missing: { string } = {}
			for _, decor in Catalog.decor do
				if ShopIcons.decor(decor.id) == nil then
					table.insert(missing, decor.id)
				end
			end
			expect(table.concat(missing, ",")).to.equal("")
			expect(ShopIcons.decor("alley_brick_wall")).to.equal("rbxassetid://95796519921389")
			expect(ShopIcons.decor("not_a_piece")).to.equal(nil)
			expect(ShopIcons.decor(nil)).to.equal(nil)
		end)

		it("has the HUD's Decor picture", function()
			expect(ShopIcons.image("Icon_Decor")).to.equal("rbxassetid://132974074427583")
		end)

		it("has a clean symbol for every HUD tile (2026-11-03)", function()
			for _, name in
				{ "Store", "Cats", "Index", "Quests", "Upgrades", "Decor", "Tutorial", "Rewards" }
			do
				expect(ShopIcons.clean(name)).to.equal(ShopIcons.image("Icon_Clean_" .. name))
				expect(string.match(ShopIcons.clean(name) :: string, "^rbxassetid://%d+$")).to.be.ok()
			end
			for _, name in { "Feedback", "Menu", "Home", "Cannon", "Areas", "Potion", "Bowl" } do
				expect(ShopIcons.clean(name)).to.be.ok()
			end
			expect(ShopIcons.clean("Store")).to.equal("rbxassetid://125596282319075")
			expect(ShopIcons.clean("Nope")).to.equal(nil)
		end)
	end)
end
