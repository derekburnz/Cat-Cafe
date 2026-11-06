--!strict
-- UI/Components/StoreLogic.luau: the Store window's cards and buttons (shop-and-pass-plan, Derek 2026-11-02 20:01).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local StoreLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("StoreLogic")
	) :: any

	local CONFIG = {
		OfflineRate = 0.5,
		OfflineCapSeconds = 28800,
		OfflineRatePass = 1.0,
		OfflineCapPassSeconds = 57600,
		LongNapPassId = 900,
		MoneyPassIds = { [2] = 200, [3] = 300, [4] = 400 },
	}

	describe("StoreLogic.passIds", function()
		it("lists the money ladder low to high, then Long Nap", function()
			local ids = StoreLogic.passIds(CONFIG)
			expect(#ids).to.equal(4)
			expect(ids[1]).to.equal(200)
			expect(ids[3]).to.equal(400)
			expect(ids[4]).to.equal(900)
		end)

		it("skips passes not made yet (id 0)", function()
			local ids =
				StoreLogic.passIds({ LongNapPassId = 0, MoneyPassIds = { [2] = 200, [3] = 0 } })
			expect(#ids).to.equal(1)
			expect(ids[1]).to.equal(200)
			expect(#StoreLogic.passIds({})).to.equal(0)
		end)
	end)

	describe("StoreLogic.moneyBadge (#1606)", function()
		local onSale = { [200] = { robux = 5, forSale = true } }

		it("shows the highest money pass owned", function()
			local badge = StoreLogic.moneyBadge(CONFIG, { [200] = true, [400] = true }, onSale)
			expect(badge.text).to.equal("4x")
			expect(badge.owned).to.equal(true)
			expect(StoreLogic.moneyBadge(CONFIG, { [300] = true }, {}).text).to.equal("3x")
			-- the server's PlayerState.passBoosts.money counts too
			expect(StoreLogic.moneyBadge(CONFIG, {}, {}, 2).text).to.equal("2x")
			expect(StoreLogic.moneyBadge(CONFIG, { [200] = true }, {}, 4).text).to.equal("4x")
			expect(StoreLogic.moneyBadge(CONFIG, {}, onSale, 1).text).to.equal("X2 Cash")
		end)

		it("offers X2 Cash with its price with none owned while the 2x pass is on sale (#1759)", function()
			local badge = StoreLogic.moneyBadge(CONFIG, {}, onSale)
			expect(badge.text).to.equal("X2 Cash")
			expect(badge.price).to.equal("Only R$5")
			expect(badge.owned).to.equal(false)
			expect(StoreLogic.moneyBadge(CONFIG, { [200] = true }, onSale).price).to.equal(nil)
		end)

		it(
			"hides while the 2x pass is off sale or not priced yet, or with no money passes",
			function()
				expect(StoreLogic.moneyBadge(CONFIG, {}, {})).to.equal(nil)
				expect(
					StoreLogic.moneyBadge(CONFIG, {}, { [200] = { robux = 5, forSale = false } })
				).to.equal(nil)
				expect(StoreLogic.moneyBadge({ MoneyPassIds = {} }, {}, onSale)).to.equal(nil)
			end
		)
	end)

	describe("StoreLogic.rows", function()
		it("shows the first rung and Long Nap for a new player", function()
			local rows = StoreLogic.rows(CONFIG, {}, false)
			expect(#rows).to.equal(2)
			expect(rows[1].key).to.equal("money")
			expect(rows[1].passId).to.equal(200)
			expect(rows[1].name).to.equal("2x Money")
			expect(rows[1].effect).to.equal("All your cafe's money x2.")
			expect(rows[1].owned).to.equal(false)
			expect(rows[2].key).to.equal("longNap")
			expect(rows[2].effect).to.equal(
				"Away money at 100% for up to 16 h.\nWithout it: 50% for up to 8 h."
			)
			expect(rows[2].owned).to.equal(false)
		end)

		it("shows only the next rung above the highest owned", function()
			local rows = StoreLogic.rows(CONFIG, { [200] = true }, false)
			expect(rows[1].passId).to.equal(300)
			expect(rows[1].effect).to.equal("All your cafe's money x3, in place of x2.")
			rows = StoreLogic.rows(CONFIG, { [300] = true }, false)
			expect(rows[1].passId).to.equal(400)
			expect(rows[1].effect).to.equal("All your cafe's money x4, in place of x3.")
		end)

		it("marks the top rung Owned once every rung is bought", function()
			local rows = StoreLogic.rows(CONFIG, { [400] = true }, false)
			expect(rows[1].passId).to.equal(400)
			expect(rows[1].owned).to.equal(true)
		end)

		it("counts Long Nap owned from Roblox or from the save", function()
			expect(StoreLogic.rows(CONFIG, { [900] = true }, false)[2].owned).to.equal(true)
			expect(StoreLogic.rows(CONFIG, {}, true)[2].owned).to.equal(true)
		end)

		it("leaves out passes not made yet", function()
			local rows = StoreLogic.rows({ LongNapPassId = 0, MoneyPassIds = {} }, {}, false)
			expect(#rows).to.equal(0)
			rows = StoreLogic.rows({ LongNapPassId = 900 }, {}, nil)
			expect(#rows).to.equal(1)
			expect(rows[1].key).to.equal("longNap")
		end)
	end)

	describe("StoreLogic pass cards (#1182)", function()
		it("hides a pass card while its Config id is 0 or missing", function()
			local rows = StoreLogic.rows({ VipPassId = 0, ExtraSlotPassIds = {} }, {}, nil)
			expect(#rows).to.equal(0)
		end)
		it("shows made passes after the ladder and Long Nap, in the shop's order", function()
			local config = {
				MoneyPassIds = { [2] = 11 },
				LongNapPassId = 12,
				KingPackPassId = 20,
				VipPassId = 13,
				ExtraSlotPassIds = { 0, 15 },
			}
			local keys = {}
			for _, row in StoreLogic.rows(config, { [13] = true }, nil) do
				table.insert(keys, row.key)
			end
			expect(table.concat(keys, ",")).to.equal("money,longNap,vip,extraSlot,kingPack")
			local ids = StoreLogic.passIds(config)
			expect(table.concat(ids, ",")).to.equal("11,12,13,15,20")
		end)
		it("marks a bought pass Owned and adds the can't-be-traded line", function()
			local rows = StoreLogic.rows(
				{ VipPassId = 13, RoyalCatPassId = 14 },
				{ [13] = true },
				nil
			)
			expect(rows[1].owned).to.equal(true)
			expect(rows[2].owned).to.equal(false)
			expect(rows[2].effect:find("Can't be traded", 1, true) ~= nil).to.equal(true)
		end)
	end)

	describe("StoreLogic product cards (#1182)", function()
		local view = {
			products = {
				{
					id = "potion_pack_xs",
					name = "Potion Pack XS",
					prize = { potions = { big_tip_potion = 2 } },
				},
				{
					id = "potion_pack_s",
					name = "Potion Pack S",
					prize = { potions = { big_tip_potion = 3, swift_potion = 1 } },
				},
			},
			potionNames = { big_tip_potion = "Big Money", swift_potion = "Swift Potion" },
			have = { big_tip_potion = 4 },
		}
		it("hides a product while its id is 0", function()
			local rows = StoreLogic.rows({ ProductIds = { potion_pack_xs = 0 } }, {}, nil, view)
			expect(#rows).to.equal(0)
			expect(#StoreLogic.productIds({ ProductIds = { potion_pack_xs = 0 } })).to.equal(0)
		end)
		it("puts the packs after VIP, with exact contents and the bag count", function()
			local config = {
				VipPassId = 13,
				RoyalCatPassId = 14,
				ProductIds = { potion_pack_xs = 31, potion_pack_s = 32 },
			}
			local rows = StoreLogic.rows(config, {}, nil, view)
			local keys = {}
			for _, row in rows do
				table.insert(keys, row.key)
			end
			expect(table.concat(keys, ",")).to.equal("vip,potionXS,potionS,royalCat")
			expect(rows[3].product).to.equal(true)
			expect(rows[3].owned).to.equal(false)
			-- #1715: a row per potion, then the bag count on its own line
			expect(rows[3].effect).to.equal("3x Big Money\n1x Swift Potion\nIn your bag: 4")
			expect(table.concat(StoreLogic.productIds(config), ",")).to.equal("31,32")
		end)
	end)

	describe("StoreLogic.button", function()
		local row = {
			key = "money",
			passId = 200,
			name = "2x Money",
			icon = "",
			effect = "",
			owned = false,
		}

		it("reads the price from Roblox's answer", function()
			local button = StoreLogic.button(row, { robux = 5, forSale = true })
			expect(button.text).to.equal("R$5")
			expect(button.style).to.equal("store")
			expect(button.enabled).to.equal(true)
		end)

		it("waits with ... until the price is known", function()
			local button = StoreLogic.button(row, nil)
			expect(button.text).to.equal("...")
			expect(button.enabled).to.equal(false)
		end)

		it("says Soon while the pass is off sale", function()
			expect(StoreLogic.button(row, { robux = 5, forSale = false }).text).to.equal("Soon")
			expect(StoreLogic.button(row, { forSale = true }).text).to.equal("Soon")
		end)

		it("says Yours (#1823) and cannot be pressed for an owned pass", function()
			local owned = table.clone(row)
			owned.owned = true
			local button = StoreLogic.button(owned, { robux = 5, forSale = true })
			expect(button.text).to.equal("Yours")
			expect(button.enabled).to.equal(false)
		end)
	end)
	describe("StoreLogic tabs and Featured (#1425)", function()
		local config = {
			MoneyPassIds = { [2] = 11 },
			LongNapPassId = 12,
			VipPassId = 13,
			RoyalCatPassId = 14,
			KingPackPassId = 20,
			ProductIds = { potion_pack_xs = 31, starter_bundle = 40 },
		}
		local view = {
			products = {
				{
					id = "potion_pack_xs",
					name = "Potion Pack XS",
					prize = { potions = { big_tip_potion = 2 } },
				},
				{
					id = "starter_bundle",
					name = "Starter Bundle",
					prize = { potions = { big_tip_potion = 10 } },
				},
			},
			potionNames = { big_tip_potion = "Big Money" },
			have = {},
			starterBought = false,
		}
		local function keys(rows: { any }): string
			local out: { string } = {}
			for _, row in rows do
				table.insert(out, row.key)
			end
			return table.concat(out, ",")
		end

		it("puts each card under its rail tab", function()
			local rows = StoreLogic.rows(config, {}, nil, view)
			expect(keys(StoreLogic.tabRows(rows, "passes"))).to.equal("money,longNap,vip")
			expect(keys(StoreLogic.tabRows(rows, "cats"))).to.equal(
				"starterBundle,royalCat,kingPack"
			)
			expect(keys(StoreLogic.tabRows(rows, "potions"))).to.equal("potionXS")
			local tabs = {}
			for _, tab in StoreLogic.tabs(rows) do
				table.insert(tabs, tab.id)
			end
			-- no Cafe Pass card yet, so no Cafe Pass tab; Codes always (#1428)
			expect(table.concat(tabs, ",")).to.equal("featured,passes,cats,potions,codes")
		end)

		it("features the Starter Bundle, then the ladder, Long Nap and King Cat Pack", function()
			local featured = StoreLogic.featured(StoreLogic.rows(config, {}, nil, view))
			expect(featured.hero.key).to.equal("starterBundle")
			expect(featured.hero.passId).to.equal(40)
			expect(keys(featured.picks)).to.equal("money,longNap,kingPack")
		end)

		it(
			"swaps the hero to the King Cat Pack once the bundle is bought, with the Royal Cat as a pick",
			function()
				local bought: any = table.clone(view)
				bought.starterBought = true
				local rows = StoreLogic.rows(config, {}, nil, bought)
				expect(keys(StoreLogic.tabRows(rows, "cats"))).to.equal("royalCat,kingPack")
				local featured = StoreLogic.featured(rows)
				expect(featured.hero.key).to.equal("kingPack")
				expect(keys(featured.picks)).to.equal("money,longNap,royalCat")
			end
		)

		it("lists the Starter Bundle's exact contents on its card (#1625)", function()
			local full: any = table.clone(view)
			full.products = {
				{
					id = "starter_bundle",
					name = "Starter Bundle",
					prize = {
						potions = { big_tip_potion = 10, swift_potion = 5 },
						cats = { "sprinkles" },
						signStyles = { "bakery_stripes" },
					},
				},
			}
			full.potionNames = { big_tip_potion = "Big Money", swift_potion = "Swift" }
			full.catNames = { sprinkles = "Sprinkles" }
			full.have = { swift_potion = 2 }
			local starter = StoreLogic.tabRows(StoreLogic.rows(config, {}, nil, full), "cats")[1]
			expect(starter.key).to.equal("starterBundle")
			expect(starter.effect).to.equal(
				StoreLogic.STARTER.effect
					.. "\nSprinkles the cat, Bakery Stripes sign style"
					.. "\n10x Big Money\n5x Swift\nIn your bag: 2"
			)
			-- a cat or style with no name yet still reads as words
			expect(StoreLogic.extras({
				potions = {},
				cats = { "new_cat" },
				signStyles = { "odd_style" },
			})).to.equal("New Cat the cat, Odd Style sign style")
			expect(StoreLogic.extras({ potions = { swift_potion = 1 } })).to.equal(nil)
		end)

		it(
			"shows the Cafe Pass card only while a season runs, Yours once bought (#1646)",
			function()
				local passConfig: any = table.clone(config)
				passConfig.ProductIds = { potion_pack_xs = 31, starter_bundle = 40, cafe_pass = 50 }
				expect(table.concat(StoreLogic.productIds(passConfig), ",")).to.equal("31,40,50")
				-- no season: no card and no Cafe Pass tab
				expect(#StoreLogic.tabRows(StoreLogic.rows(passConfig, {}, nil, view), "cafePass")).to.equal(
					0
				)
				local running: any = table.clone(view)
				running.starterBought = true
				running.cafePass = {
					season = 1,
					name = "Season 1: Maple",
					paid = false,
					contents = "Season cat Maple Muffin and 15 potions",
				}
				local rows = StoreLogic.rows(passConfig, {}, nil, running)
				local card = StoreLogic.tabRows(rows, "cafePass")[1]
				expect(card.passId).to.equal(50)
				expect(card.product).to.equal(true)
				expect(card.name).to.equal("Cafe Pass")
				expect(card.effect).to.equal(
					"Season 1 paid track:\nSeason cat Maple Muffin and 15 potions"
				)
				-- #1823 (store-layout-v2.md §1): after the Starter Bundle the King Cat bundle is the hero, and the season's
				-- pass leads the picks (never with a restarting timer)
				expect(StoreLogic.featured(rows).hero.key).to.equal("kingPack")
				expect(StoreLogic.featured(rows).picks[1].key).to.equal("cafePass")
				expect(StoreLogic.button(card, { robux = 299, forSale = true }).text).to.equal(
					"R$299"
				)
				running.cafePass.paid = true
				local bought =
					StoreLogic.tabRows(StoreLogic.rows(passConfig, {}, nil, running), "cafePass")[1]
				expect(StoreLogic.button(bought, { robux = 299, forSale = true }).text).to.equal(
					"Yours"
				)
				local after = StoreLogic.featured(StoreLogic.rows(passConfig, {}, nil, running))
				expect(after.hero.key).to.equal("kingPack")
				expect(after.picks[1].key).to.equal("money") -- bought: it gives its spot to one still for sale
				-- a closed season (0) hides it again
				running.cafePass.season = 0
				expect(
					#StoreLogic.tabRows(StoreLogic.rows(passConfig, {}, nil, running), "cafePass")
				).to.equal(0)
			end
		)

		it("keeps the Starter Bundle hidden until the server says it is not bought", function()
			local unknown: any = table.clone(view)
			unknown.starterBought = nil
			local rows = StoreLogic.rows(config, {}, nil, unknown)
			expect(keys(StoreLogic.tabRows(rows, "cats"))).to.equal("royalCat,kingPack")
			expect(table.concat(StoreLogic.productIds(config), ",")).to.equal("31,40")
		end)

		it(
			"fills an owned pick from the rest of the Store, and never shows a card twice",
			function()
				local rows = StoreLogic.rows(
					config,
					{ [12] = true },
					nil,
					{ products = view.products, have = {} }
				)
				local featured = StoreLogic.featured(rows)
				expect(featured.hero.key).to.equal("kingPack")
				expect(keys(featured.picks)).to.equal("money,royalCat,vip")
			end
		)

		it("has no hero and no picks in an empty Store", function()
			local featured = StoreLogic.featured({})
			expect(featured.hero == nil).to.equal(true)
			expect(#featured.picks).to.equal(0)
		end)
	end)
	describe("StoreLogic.justBought (#1823)", function()
		local function row(key: string, passId: number, owned: boolean, product: boolean?): any
			return { key = key, passId = passId, owned = owned, product = product, name = key, icon = "", effect = "", tab = "passes" }
		end
		it("says nothing on the first render", function()
			local bought = StoreLogic.justBought({}, { row("vip", 1, true) })
			expect(#bought).to.equal(0)
		end)
		it("names a card that turned Owned", function()
			local _, seen = StoreLogic.justBought({}, { row("vip", 1, false), row("nap", 2, false) })
			local bought = StoreLogic.justBought(seen, { row("vip", 1, true), row("nap", 2, false) })
			expect(#bought).to.equal(1)
			expect(bought[1]).to.equal("vip")
		end)
		it("names the money card when it moves up a rung", function()
			local _, seen = StoreLogic.justBought({}, { row("money", 10, false) })
			local bought = StoreLogic.justBought(seen, { row("money", 11, false) })
			expect(bought[1]).to.equal("money")
		end)
		it("never names a product or a card that was already owned", function()
			local _, seen = StoreLogic.justBought({}, { row("pack", 5, false, true), row("vip", 1, true) })
			local bought = StoreLogic.justBought(seen, { row("pack", 6, false, true), row("vip", 1, true) })
			expect(#bought).to.equal(0)
		end)
	end)
	describe("StoreLogic King Cat cards (#1822)", function()
		local config = {
			KingPackPassId = 100,
			KingCatPassId = 200,
			ProductIds = { potion_pack_m = 300 },
		}
		local function find(rows: { any }, key: string): any
			for _, row in rows do
				if row.key == key then
					return row
				end
			end
			return nil
		end
		it("shows the King Cat alone just before its bundle, under Cats", function()
			local rows = StoreLogic.rows(config, {}, false, nil)
			local cat, pack
			for index, row in rows do
				if row.key == "kingCat" then
					cat = index
				elseif row.key == "kingPack" then
					pack = index
				end
			end
			expect(cat).to.be.ok()
			expect(pack).to.equal(cat + 1)
			expect(rows[cat].tab).to.equal("cats")
		end)
		it("hides the King Cat alone while its pass is not made", function()
			local rows = StoreLogic.rows({ KingPackPassId = 100, KingCatPassId = 0 }, {}, false, nil)
			expect(find(rows, "kingCat")).to.equal(nil)
			expect(find(rows, "kingPack").worthIds).to.equal(nil)
		end)
		it("adds up the parts for the worth line, only when it beats the bundle's price", function()
			local pack = find(StoreLogic.rows(config, {}, false, nil), "kingPack")
			local prices = {
				[100] = { robux = 999, forSale = true },
				[200] = { robux = 799, forSale = true },
				[300] = { robux = 450, forSale = true },
			}
			expect(StoreLogic.worthLine(pack, prices)).to.equal("Worth R$1,245")
			prices[300] = { robux = 150, forSale = true }
			expect(StoreLogic.worthLine(pack, prices)).to.equal(nil)
			prices[300] = nil
			expect(StoreLogic.worthLine(pack, prices)).to.equal(nil)
		end)
		it("drops the worth line once the bundle is owned", function()
			local pack = find(StoreLogic.rows(config, { [100] = true }, false, nil), "kingPack")
			local prices = {
				[100] = { robux = 999, forSale = true },
				[200] = { robux = 799, forSale = true },
				[300] = { robux = 450, forSale = true },
			}
			expect(StoreLogic.worthLine(pack, prices)).to.equal(nil)
		end)
	end)
	describe("StoreLogic bundle worth and badge (#1823, store-layout-v2.md §2 and §4)", function()
		local pack: any = {
			key = "kingPack",
			passId = 100,
			owned = false,
			worthIds = { 200, 300 },
			name = "King Cat Pack",
			icon = "",
			effect = "",
			tab = "cats",
		}
		local function prices(cat: number?, potions: number?): any
			return {
				[100] = { robux = 999, forSale = true },
				[200] = if cat then { robux = cat, forSale = true } else nil,
				[300] = if potions then { robux = potions, forSale = true } else nil,
			}
		end
		it("sums the live prices rounded down to R$5, and hides when one is missing", function()
			expect(StoreLogic.worth(pack, prices(799, 452))).to.equal(1250)
			expect(StoreLogic.worthLine(pack, prices(799, 452))).to.equal("Worth R$1,250")
			expect(StoreLogic.worth(pack, prices(799, nil))).to.equal(nil)
		end)
		it("gives Best Value only at 1.25 x the price or more", function()
			expect(StoreLogic.badge(pack, prices(799, 452))).to.equal("Best Value")
			expect(StoreLogic.badge(pack, prices(799, 400))).to.equal(nil) -- 1195 < 1248.75
		end)
		it("counts only the parts not owned yet, dropping the line and badge below the price", function()
			local owned = { [200] = true }
			expect(StoreLogic.worth(pack, prices(799, 452), owned)).to.equal(450)
			expect(StoreLogic.worthLine(pack, prices(799, 452), owned)).to.equal(nil)
			expect(StoreLogic.badge(pack, prices(799, 452), owned)).to.equal(nil)
		end)
	end)
end
