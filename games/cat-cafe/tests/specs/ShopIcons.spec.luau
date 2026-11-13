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
		end)
		it("lists every bottle a potion has, flask first (#1256)", function()
			local all = ShopIcons.potionAll("swift_potion")
			expect(#all).to.equal(3)
			expect(all[1]).to.equal(ShopIcons.potion("swift_potion"))
			expect(all[1] ~= all[2]).to.equal(true)
			expect(#ShopIcons.potionAll("not_a_potion")).to.equal(0)
			-- #3462: a Day Cart top potion draws its own flask first, then its smaller kind's bottles
			local topPotions: { [string]: string } = {
				big_lucky_potion = "lucky_potion",
				big_gold_rush_potion = "gold_rush_potion",
				mega_tip_potion = "big_tip_potion",
			}
			for big, small in topPotions do
				local bottles = ShopIcons.potionAll(big)
				local own = bottles[1]
				expect(own).to.be.ok()
				expect(own).never.to.equal(ShopIcons.potion(small))
				expect(table.find(bottles, ShopIcons.potion(small) :: string)).to.be.ok()
			end
			expect(#ShopIcons.potionAll(nil)).to.equal(0)
		end)
		it("has the three shop cats' pictures (#1191)", function()
			expect(ShopIcons.shopCat("Sprinkles")).to.equal("rbxassetid://132934776901111")
			expect(ShopIcons.shopCat("DuchessMarzipan")).to.equal("rbxassetid://120092810809619")
			expect(ShopIcons.shopCat("KingCroissant")).to.equal("rbxassetid://97923289789222")
			expect(ShopIcons.shopCat("Nobody")).to.equal(nil)
		end)
		it("has a dish picture for every menu item (#950)", function()
			local Catalog = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
			)
			local missing = {}
			for _, item in Catalog.menu do
				if ShopIcons.menu(item.id) == nil then
					table.insert(missing, item.id)
				end
			end
			expect(table.concat(missing, ",")).to.equal("")
			expect(ShopIcons.menu("paw_cookie")).to.equal("rbxassetid://99959252804941")
			expect(ShopIcons.menu("nothing")).to.equal(nil)
		end)
		it("has a bottle for every potion in the catalog", function()
			-- the clean bottle first (#1070), the old picture behind it
			expect(ShopIcons.potion("gold_rush_potion")).to.equal("rbxassetid://111453568394621") -- the #1193 flask (#1204)
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
			expect(ShopIcons.food("star_treat")).to.equal("rbxassetid://109199304319470")
			expect(ShopIcons.food("moon_milk")).to.equal("rbxassetid://109614940712323")
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
				-- #3462: the Day Cart's own two
				honey_cream = "HoneyCream",
				comet_treat = "CometTreat",
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
			-- the 8-slice wheel once uploaded (#1665), else the flat clean wheel
			expect(ShopIcons.prize("spins")).to.equal(ShopIcons.hud("Spin"))
			for _, kind in { "coins", "fish", "spins" } do
				local picture = ShopIcons.prize(kind) :: string
				expect(string.match(picture, "^rbxassetid://%d+$")).to.be.ok()
			end
			expect(ShopIcons.prize("lure")).to.equal(nil)
			expect(ShopIcons.prize(nil)).to.equal(nil)
		end)

		it("has the prize pictures for coins and spins (F97 section 4)", function()
			expect(ShopIcons.image("Coins")).to.equal("rbxassetid://136732540501959")
			-- the 8-slice wheel once uploaded (#1665), else the clean wheel (#1070)
			expect(ShopIcons.image("Spin")).to.equal(ShopIcons.hud("Spin"))
			expect(ShopIcons.clean("Spin")).to.equal("rbxassetid://92256242473029")
		end)

		it("keeps each HUD picture's clean symbol as its backup (#1665)", function()
			expect(ShopIcons.backup(ShopIcons.hud("Cats"))).to.equal(ShopIcons.clean("Cats"))
			expect(ShopIcons.backup(ShopIcons.hud("Home"))).to.equal(ShopIcons.clean("Home"))
			expect(ShopIcons.backup(ShopIcons.hud("Spin"))).to.equal(
				if ShopIcons.hud("Spin") == ShopIcons.clean("Spin")
					then nil
					else ShopIcons.clean("Spin")
			)
			expect(ShopIcons.backup(ShopIcons.clean("Cats"))).to.equal(nil)
			expect(ShopIcons.backup(nil)).to.equal(nil)
			-- #2866: the redrawn Bag falls back to the group's earlier backpack, not the window's potion glyph
			expect(ShopIcons.backup(ShopIcons.hud("Bag"))).to.equal("rbxassetid://88244676943674")
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

		it(
			"has a clean picture for every decor piece in the catalog and every event piece (#1072, #2486)",
			function()
				local missing: { string } = {}
				for _, decor in Catalog.decor do
					if ShopIcons.decor(decor.id) == nil then
						table.insert(missing, decor.id)
					end
				end
				for _, decor in Catalog.eventDecor do
					if ShopIcons.decor(decor.id) == nil then
						table.insert(missing, decor.id)
					end
				end
				expect(table.concat(missing, ",")).to.equal("")
				expect(ShopIcons.decor("Decor_PartyBunting")).to.equal(
					"rbxassetid://100203816605384"
				)
				expect(ShopIcons.decor("alley_brick_wall")).to.equal("rbxassetid://124215158995706")
				expect(ShopIcons.decor("not_a_piece")).to.equal(nil)
				expect(ShopIcons.decor(nil)).to.equal(nil)
			end
		)

		it("has the HUD's Decor picture", function()
			expect(ShopIcons.image("Icon_Decor")).to.equal("rbxassetid://88901788469222")
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
			expect(ShopIcons.clean("Store")).to.equal("rbxassetid://111734554524173")
			expect(ShopIcons.clean("Nope")).to.equal(nil)
		end)

		it(
			"gives every Store card its own picture, the money card by rung (Tools-Agent 11-05)",
			function()
				local StoreLogic = require(Components:WaitForChild("StoreLogic")) :: any
				for _, card in StoreLogic.PASSES do
					expect(ShopIcons.store(card.key)).never.to.equal(nil)
				end
				for _, card in StoreLogic.PRODUCTS do
					expect(ShopIcons.store(card.key)).never.to.equal(nil)
				end
				expect(ShopIcons.store(StoreLogic.STARTER.key)).to.equal(
					"rbxassetid://83823033546025"
				)
				-- #1168: the new cards' own pictures (Tools-Agent 11-06), no stand-ins
				expect(ShopIcons.store(StoreLogic.THANK_YOU.key)).to.equal(
					"rbxassetid://124763763193731"
				)
				expect(ShopIcons.store("steadyPaw")).to.equal("rbxassetid://124844091674201")
				expect(ShopIcons.store("signStylePack")).to.equal("rbxassetid://111176293548634")
				expect(ShopIcons.store("gardenDecor")).to.equal("rbxassetid://76001339098213")
				expect(ShopIcons.store("longNap")).to.equal("rbxassetid://136378395182949")
				expect(ShopIcons.store("money", 2)).to.equal("rbxassetid://82155674128354")
				expect(ShopIcons.store("money", 3)).to.equal("rbxassetid://97377712325581")
				expect(ShopIcons.store("money", 4)).to.equal("rbxassetid://120063755686083")
				expect(ShopIcons.store("money")).to.equal(nil)
				expect(ShopIcons.store("money", 9)).to.equal(nil)
				expect(ShopIcons.store("nope")).to.equal(nil)
				expect(ShopIcons.store(nil)).to.equal(nil)
			end
		)

		it("gives every Store sidebar tab a picture (#1674)", function()
			local StoreLogic = require(Components:WaitForChild("StoreLogic")) :: any
			for _, tab in StoreLogic.TABS do
				expect(ShopIcons.storeTab(tab.id)).never.to.equal(nil)
			end
			expect(ShopIcons.storeTab("featured")).to.equal("rbxassetid://137967213846475")
			expect(ShopIcons.storeTab("codes")).to.equal("rbxassetid://96392852887729")
			expect(ShopIcons.storeTab("cafePass")).to.equal(ShopIcons.store("cafePass"))
			expect(ShopIcons.storeTab("nope")).to.equal(nil)
		end)

		it("draws the Fish Market tabs and the Night Market bubble (Tools-Agent 11-05)", function()
			expect(ShopIcons.market("Crates")).to.equal("rbxassetid://86512063079182")
			expect(ShopIcons.market("Treats")).to.equal("rbxassetid://86498761565767")
			expect(ShopIcons.market("FreshCatch")).to.equal("rbxassetid://74465916818248")
			expect(ShopIcons.hud("NightMarket")).to.equal("rbxassetid://73145081487107")
		end)

		it("gives each cat food its own glyph, not the same star (#1616)", function()
			local seen: { [string]: boolean } = {}
			for _, food in Catalog.catFood do
				local glyph = ShopIcons.snackGlyph(food.id)
				expect(seen[glyph]).to.equal(nil)
				seen[glyph] = true
				expect(ShopIcons.catFood(food.id)).to.equal(nil)
			end
			expect(ShopIcons.snackGlyph("cat_snack")).to.equal("🍪")
			expect(ShopIcons.snackGlyph("big_cat_snack")).to.equal("🧁")
			expect(ShopIcons.snackGlyph("nope")).to.equal(ShopIcons.SNACK_GLYPH)
			expect(ShopIcons.catFood("nope")).never.to.equal(nil)
			expect(ShopIcons.catFood(nil)).to.equal(nil)
		end)

		it("lists every Store picture once, for the background fetch (#2500)", function()
			local list = ShopIcons.storeImages()
			expect(#list > 20).to.equal(true)
			local seen: { [string]: boolean } = {}
			for _, id in list do
				expect(seen[id]).to.equal(nil)
				seen[id] = true
				expect(string.sub(id, 1, 13)).to.equal("rbxassetid://")
			end
			expect(seen[ShopIcons.clean("Bag") :: string]).to.equal(true)
			expect(
				seen[ShopIcons.storeTab("Passes") :: string] or ShopIcons.storeTab("Passes") == nil
			).to.equal(true)
		end)

		it("draws the #2836 icons that were emoji", function()
			local names = {
				"MysteryMarket",
				"Codes",
				"Collector",
				"CornerShop",
				"LawnStall",
				"RankUp",
				"Bellhop",
			}
			for _, name in { "YardSale", "BigBackpack", "LongNet", "NightMarket" } do
				table.insert(names, name)
			end
			for _, name in names do
				expect(ShopIcons.hud(name)).never.to.equal(nil)
			end
			for _, id in { "tables", "espresso", "lure_bowl", "lucky_cat" } do
				expect(ShopIcons.upgrade(id)).never.to.equal(nil)
			end
			expect(ShopIcons.upgrade("net")).to.equal(nil) -- the Net row has ShopIcons.net
			for _, role in { "barista", "waiter", "greeter", "entertainer" } do
				expect(ShopIcons.role(role)).never.to.equal(nil)
			end
			expect(ShopIcons.role(nil)).to.equal(nil)
			for _, glyph in { "⬇️", "🎬", "🏷️", "🍽️" } do
				expect(ShopIcons.glyph(glyph)).never.to.equal(nil)
			end
			expect(ShopIcons.glyph("🐱")).to.equal(nil)
		end)

		it("draws every Settings switch row (#2836 pass 2)", function()
			local SettingsList = require(Components:WaitForChild("SettingsList")) :: any
			for _, section in SettingsList.SECTIONS do
				for _, row in section.rows do
					expect(ShopIcons.setting(row.key)).never.to.equal(nil)
				end
			end
			expect(ShopIcons.setting("resetSave")).to.equal(nil)
			expect(ShopIcons.setting(nil)).to.equal(nil)
		end)

		it("shares the station ring pictures with the server rings (#3396)", function()
			local StationIcons = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared")
					:WaitForChild("StationIcons")
			) :: any
			local names = {
				arcade = "Arcade",
				index = "Index",
				lostFound = "LostFound",
				museum = "Museum",
				picnic = "Picnic",
				pond = "Pond",
				spa = "Spa",
				yardSale = "YardSale",
			}
			local count = 0
			for key, id in StationIcons do
				count += 1
				expect(names[key]).never.to.equal(nil)
				expect(string.match(id, "^rbxassetid://%d+$")).never.to.equal(nil)
				expect(ShopIcons.clean(names[key])).to.equal(id)
			end
			expect(count).to.equal(8)
		end)
	end)
end
