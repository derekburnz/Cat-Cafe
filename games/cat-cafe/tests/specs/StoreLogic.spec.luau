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

		it(
			"offers X2 Cash with its price with none owned while the 2x pass is on sale (#1759)",
			function()
				local badge = StoreLogic.moneyBadge(CONFIG, {}, onSale)
				expect(badge.text).to.equal("X2 Cash")
				expect(badge.price).to.equal("Only R$5")
				expect(badge.owned).to.equal(false)
				expect(StoreLogic.moneyBadge(CONFIG, { [200] = true }, onSale).price).to.equal(nil)
			end
		)

		it(
			"gives the X2 Cash pill the 2x pass id to buy, never while owned or quiet (#2353)",
			function()
				expect(StoreLogic.moneyBadge(CONFIG, {}, onSale).id).to.equal(200)
				expect(StoreLogic.moneyBadge(CONFIG, { [200] = true }, onSale).id).to.equal(nil)
				expect(StoreLogic.moneyBadge(CONFIG, {}, onSale, 2).id).to.equal(nil)
				expect(StoreLogic.moneyBadge(CONFIG, {}, onSale, nil, true).id).to.equal(nil)
			end
		)

		it(
			"says a plain x2 with no price in the first 30 minutes, and owned stays owned (#1936)",
			function()
				local badge = StoreLogic.moneyBadge(CONFIG, {}, onSale, nil, true)
				expect(badge.text).to.equal("x2")
				expect(badge.price).to.equal(nil)
				expect(badge.quiet).to.equal(true)
				expect(badge.owned).to.equal(false)
				expect(StoreLogic.moneyBadge(CONFIG, { [300] = true }, onSale, nil, true).text).to.equal(
					"3x"
				)
				expect(StoreLogic.moneyBadge(CONFIG, {}, {}, nil, true)).to.equal(nil)
			end
		)

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
			expect(rows[1].effect).to.equal("Multiplies ALL your bonuses x2.")
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
			expect(rows[1].effect).to.equal("Multiplies ALL your bonuses x3, in place of x2.")
			rows = StoreLogic.rows(CONFIG, { [300] = true }, false)
			expect(rows[1].passId).to.equal(400)
			expect(rows[1].effect).to.equal("Multiplies ALL your bonuses x4, in place of x3.")
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
					id = "steady_paw_pack",
					name = "Steady Paw Pack",
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
			local rows = StoreLogic.rows({ ProductIds = { steady_paw_pack = 0 } }, {}, nil, view)
			expect(#rows).to.equal(0)
			expect(#StoreLogic.productIds({ ProductIds = { steady_paw_pack = 0 } })).to.equal(0)
		end)
		it("puts the packs after VIP, with exact contents and the bag count", function()
			local config = {
				VipPassId = 13,
				RoyalCatPassId = 14,
				ProductIds = { steady_paw_pack = 31, potion_pack_s = 32 }, -- the S pack is no longer a Store card
			}
			local rows = StoreLogic.rows(config, {}, nil, view)
			local keys = {}
			for _, row in rows do
				table.insert(keys, row.key)
			end
			-- Derek 2026-11-13: no potion pack is a Store card any more (their receipts still pay)
			expect(table.concat(keys, ",")).to.equal("vip,royalCat")
			expect(table.concat(StoreLogic.productIds(config), ",")).to.equal("")
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
			ProductIds = { steady_paw_pack = 31, starter_bundle = 40 },
		}
		local view = {
			products = {
				{
					id = "steady_paw_pack",
					name = "Steady Paw Pack",
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
			expect(keys(StoreLogic.tabRows(rows, "potions"))).to.equal("") -- no packs since 2026-11-13
			local tabs = {}
			for _, tab in StoreLogic.tabs(rows) do
				table.insert(tabs, tab.id)
			end
			-- no Cafe Pass card yet, so no Cafe Pass tab; Codes always (#1428)
			expect(table.concat(tabs, ",")).to.equal("featured,passes,cats,codes")
		end)

		it("lights a New dot only on a tab the rail shows (#1823 section 4)", function()
			local rows = StoreLogic.rows(config, {}, nil, view)
			local unseen = { featured = true, cafePass = true, potions = true, codes = true }
			local new = StoreLogic.newTabs(unseen, rows)
			-- no Cafe Pass card between seasons, so its dot never keeps the HUD's Store dot lit
			expect(new.cafePass).to.equal(nil)
			expect(new.featured).to.equal(true)
			expect(new.potions).to.equal(nil) -- the Potions tab has no cards, so it is not on the rail
			expect(new.codes).to.equal(true)
			expect(new.passes).to.equal(nil)
			expect(next(StoreLogic.newTabs({}, rows))).to.equal(nil)
		end)

		it(
			"features the Starter Bundle, then 2x Money, the Royal Cat and the King Cat Pack (#3562)",
			function()
				local featured = StoreLogic.featured(StoreLogic.rows(config, {}, nil, view))
				expect(featured.hero.key).to.equal("starterBundle")
				expect(featured.hero.passId).to.equal(40)
				expect(keys(featured.picks)).to.equal("money,royalCat,kingPack")
			end
		)

		it(
			"swaps the hero to the Royal Cat once the bundle is bought, with the King Cat Pack as a pick",
			function()
				local bought: any = table.clone(view)
				bought.starterBought = true
				local rows = StoreLogic.rows(config, {}, nil, bought)
				expect(keys(StoreLogic.tabRows(rows, "cats"))).to.equal("royalCat,kingPack")
				local featured = StoreLogic.featured(rows)
				expect(featured.hero.key).to.equal("royalCat")
				expect(keys(featured.picks)).to.equal("money,kingPack,vip")
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
					.. "\n10x Big Money, 5x Swift potions" -- #2850: one line, so the bigger bundle fits the hero
			)
			-- a cat or style with no name yet still reads as words
			expect(StoreLogic.extras({
				potions = {},
				cats = { "new_cat" },
				signStyles = { "odd_style" },
			})).to.equal("New Cat the cat, Odd Style sign style")
			expect(StoreLogic.extras({ potions = { swift_potion = 1 } })).to.equal(nil)
			-- #2850: the 2x Money for good leads the extras once the prize carries it
			expect(StoreLogic.extras({
				potions = {},
				cats = { "sprinkles" },
				moneyMultiplier = 2,
			}, { sprinkles = "Sprinkles" })).to.equal("2x Money for good, Sprinkles the cat")
			expect(StoreLogic.extras({ potions = {}, moneyMultiplier = 1 })).to.equal(nil)
			expect(
				StoreLogic.contentsLine(
					{ swift_potion = 5, big_tip_potion = 10 },
					{ big_tip_potion = "Big Money Potion", swift_potion = "Swift Potion" }
				)
			).to.equal("10x Big Money, 5x Swift potions")
		end)

		it(
			"closes the Cafe Pass card for the next season in the last minutes of one (#2129)",
			function()
				local passConfig: any = table.clone(config)
				passConfig.ProductIds =
					{ steady_paw_pack = 31, starter_bundle = 40, cafe_pass = 50 }
				local function card(saleOpen: boolean?, paid: boolean): any
					local running: any = table.clone(view)
					running.starterBought = true
					running.cafePass = {
						season = 1,
						name = "Season 1: Maple",
						paid = paid,
						contents = "x",
						saleOpen = saleOpen,
					}
					local rows = StoreLogic.rows(passConfig, {}, nil, running)
					return StoreLogic.tabRows(rows, "cafePass")[1]
				end
				local price = { robux = 299, forSale = true }
				expect(StoreLogic.button(card(true, false), price).enabled).to.equal(true)
				expect(StoreLogic.button(card(nil, false), price).enabled).to.equal(true) -- no word: on sale
				local closed = StoreLogic.button(card(false, false), price)
				expect(closed.enabled).to.equal(false)
				expect(closed.text).to.equal("Next season")
				-- a buyer still reads Yours, never "Next season"
				expect(StoreLogic.button(card(false, true), price).text).to.equal("Yours")
			end
		)

		it(
			"shows the Cafe Pass card only while a season runs, Yours once bought (#1646)",
			function()
				local passConfig: any = table.clone(config)
				passConfig.ProductIds =
					{ steady_paw_pack = 31, starter_bundle = 40, cafe_pass = 50 }
				expect(table.concat(StoreLogic.productIds(passConfig), ",")).to.equal("40,50")
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
				-- #3562: after the Starter Bundle the Royal Cat is the hero and the ladder leads the picks; the season's
				-- pass comes after the cat bundles and the passes that bring more cats (never with a restarting timer)
				expect(StoreLogic.featured(rows).hero.key).to.equal("royalCat")
				expect(StoreLogic.featured(rows).picks[1].key).to.equal("money")
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
				expect(after.hero.key).to.equal("royalCat")
				expect(after.picks[1].key).to.equal("money")
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
			expect(table.concat(StoreLogic.productIds(config), ",")).to.equal("40")
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
				expect(featured.hero.key).to.equal("royalCat")
				expect(keys(featured.picks)).to.equal("money,kingPack,vip")
			end
		)

		describe("a player who owns the top picks (#2303)", function()
			local function row(key: string, owned: boolean, product: boolean?): any
				return {
					key = key,
					passId = 1,
					owned = owned,
					product = product,
					name = key,
					icon = "",
					effect = "",
					tab = if product then "potions" else "passes",
				}
			end
			-- the Store's own order: the ladder, Long Nap, VIP, the potion packs, then the rest
			local function store(passOwned: boolean): { any }
				return {
					row("money", true),
					row("longNap", true),
					row("vip", passOwned),
					row("steadyPaw", false, true),
					row("accessories", true), -- was Potion Pack S, off the Store since 2026-11-13
					row("steadyPaw", false, true),
					row("uniforms", passOwned),
					row("extraSlot", passOwned),
					row("royalCat", true),
					row("secondBowl", passOwned),
					row("kingPack", true),
					row("cafePass", true, true),
				}
			end

			it(
				"puts the King Cat Pack, the Second Bait Bowl and the Extra Slot first once the ladder is done (#3562)",
				function()
					local rows = store(false)
					rows[11] = row("kingPack", false)
					rows[12] = row("cafePass", false, true)
					table.insert(rows, row("starterBundle", false, true))
					local featured = StoreLogic.featured(rows)
					expect(featured.hero.key).to.equal("starterBundle")
					expect(keys(featured.picks)).to.equal("kingPack,secondBowl,extraSlot")
				end
			)

			it("sees the Second Bait Bowl and the next two passes, and no potion pack", function()
				expect(keys(StoreLogic.featured(store(false)).picks)).to.equal(
					"secondBowl,extraSlot,vip"
				)
			end)

			it("gets a pass outside the pass order before any potion pack", function()
				local rows = store(true)
				rows[7] = row("uniforms", false)
				expect(keys(StoreLogic.featured(rows).picks)).to.equal("uniforms,steadyPaw,money")
			end)

			it(
				"leads with the next rung and the cat bundles after the first buys (#3562)",
				function()
					-- the Starter Bundle and 2x Money bought: the money card is now the 3x rung, not owned
					local rows = store(false)
					rows[1] = row("money", false)
					rows[9] = row("royalCat", false)
					rows[11] = row("kingPack", false)
					local featured = StoreLogic.featured(rows)
					expect(featured.hero.key).to.equal("royalCat")
					expect(keys(featured.picks)).to.equal("money,kingPack,secondBowl")
				end
			)

			it(
				"shows no potion pack while a pass or another product can be bought (#3562)",
				function()
					local rows = store(true)
					table.insert(rows, row("thankYou", false, true)) -- a product that is not a potion pack
					expect(keys(StoreLogic.featured(rows).picks)).to.equal(
						"steadyPaw,thankYou,money"
					)
					rows[7] = row("uniforms", false)
					expect(keys(StoreLogic.featured(rows).picks)).to.equal(
						"uniforms,steadyPaw,thankYou"
					)
				end
			)

			it("passes over a card that is off sale or has no price (#3562)", function()
				local rows = store(false)
				for index, entry in rows do
					entry.passId = index
				end
				rows[1] = row("money", false)
				rows[1].passId = 1
				rows[9] = row("royalCat", false)
				rows[9].passId = 9
				local prices: { [number]: any } = {
					[1] = { forSale = false }, -- 2x Money off sale
					[9] = { robux = 199, forSale = true },
					[10] = { forSale = true }, -- the Second Bait Bowl has no price
				}
				local featured = StoreLogic.featured(rows, prices)
				expect(featured.hero.key).to.equal("royalCat")
				-- a price still loading (the Extra Slot, VIP) does not count as off sale
				expect(keys(featured.picks)).to.equal("extraSlot,vip,uniforms")
				-- with nothing else left, a passed over card may still fill the tab
				local few = { rows[1], rows[9] }
				expect(keys(StoreLogic.featured(few, prices).picks)).to.equal("money")
			end)

			it("still gets three picks with every pass owned: potions, then Owned", function()
				local rows = store(true)
				table.remove(rows, 6) -- no Steady Paw card
				table.remove(rows, 5) -- nor the S pack
				expect(keys(StoreLogic.featured(rows).picks)).to.equal("steadyPaw,money,kingPack")
			end)
		end)

		it("still shows a hero, marked Yours, when every hero card is owned (#2072)", function()
			local function owned(key: string): any
				return {
					key = key,
					passId = 1,
					owned = true,
					name = key,
					icon = "",
					effect = "",
					tab = "cats",
				}
			end
			local featured = StoreLogic.featured({
				owned("royalCat"),
				owned("cafePass"),
				owned("kingPack"),
			})
			expect(featured.hero).to.be.ok()
			expect(featured.hero.key).to.equal("royalCat")
		end)

		it("has no hero and no picks in an empty Store", function()
			local featured = StoreLogic.featured({})
			expect(featured.hero == nil).to.equal(true)
			expect(#featured.picks).to.equal(0)
		end)
	end)
	describe("StoreLogic.justBought (#1823)", function()
		local function row(key: string, passId: number, owned: boolean, product: boolean?): any
			return {
				key = key,
				passId = passId,
				owned = owned,
				product = product,
				name = key,
				icon = "",
				effect = "",
				tab = "passes",
			}
		end
		it("says nothing on the first render", function()
			local bought = StoreLogic.justBought({}, { row("vip", 1, true) })
			expect(#bought).to.equal(0)
		end)
		it("names a card that turned Owned", function()
			local _, seen = StoreLogic.justBought(
				{},
				{ row("vip", 1, false), row("nap", 2, false) }
			)
			local bought =
				StoreLogic.justBought(seen, { row("vip", 1, true), row("nap", 2, false) })
			expect(#bought).to.equal(1)
			expect(bought[1]).to.equal("vip")
		end)
		it("names the money card when it moves up a rung", function()
			local _, seen = StoreLogic.justBought({}, { row("money", 10, false) })
			local bought = StoreLogic.justBought(seen, { row("money", 11, false) })
			expect(bought[1]).to.equal("money")
		end)
		it("never names a product or a card that was already owned", function()
			local _, seen = StoreLogic.justBought(
				{},
				{ row("pack", 5, false, true), row("vip", 1, true) }
			)
			local bought =
				StoreLogic.justBought(seen, { row("pack", 6, false, true), row("vip", 1, true) })
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
			local rows = StoreLogic.rows(
				{ KingPackPassId = 100, KingCatPassId = 0 },
				{},
				false,
				nil
			)
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
		describe("the Sale badge (#3572)", function()
			local Config = require(
				game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")
			) :: any
			local function card(key: string, owned: boolean?): any
				return {
					key = key,
					passId = 1,
					owned = owned == true,
					name = key,
					icon = "",
					effect = "",
					tab = "passes",
				}
			end
			local before = Config.StoreSaleEnds - 1

			it("shows the true old price at the sale price or lower", function()
				local half = { robux = 499, forSale = true }
				expect(StoreLogic.saleWas(card("kingPack"), half, Config, before)).to.equal(999)
				expect(StoreLogic.saleBadge(999)).to.equal("SALE  was <s>R$999</s>")
				for _, robux in { 450, 498 } do
					local price = { robux = robux, forSale = true }
					expect(StoreLogic.saleWas(card("kingPack"), price, Config, before)).to.equal(
						999
					)
				end
				-- above the sale price (a regional price, a price that went up): no badge
				for _, robux in { 500, 998, 999, 1200 } do
					local price = { robux = robux, forSale = true }
					expect(StoreLogic.saleWas(card("kingPack"), price, Config, before)).to.equal(
						nil
					)
				end
				expect(StoreLogic.saleWas(card("kingPack"), nil, Config, before)).to.equal(nil)
				expect(
					StoreLogic.saleWas(
						card("kingPack"),
						{ robux = 499, forSale = false },
						Config,
						before
					)
				).to.equal(nil)
				expect(StoreLogic.saleWas(card("kingPack", true), half, Config, before)).to.equal(
					nil
				)
			end)

			it("comes off after 30 days and never shows on an item that was selling", function()
				local half = { robux = 499, forSale = true }
				expect(StoreLogic.saleWas(card("kingPack"), half, Config, Config.StoreSaleEnds)).to.equal(
					nil
				)
				for _, key in
					{
						"money",
						"vip",
						"longNap",
						"accessories",
						"secondBowl",
						"gardenDecor",
						"signStylePack",
						"starterBundle",
					}
				do
					expect(Config.StoreWasPrice[key]).to.equal(nil)
				end
				expect(
					StoreLogic.saleWas(card("vip"), { robux = 13, forSale = true }, Config, before)
				).to.equal(nil)
			end)

			it(
				"lists the Store cards of Derek's fifteen items, each at half within half a Robux",
				function()
					local count = 0
					for _, entry in Config.StoreWasPrice do
						count += 1
						expect(math.abs(entry.was / 2 - entry.now) <= 0.5).to.equal(true)
					end
					expect(count).to.equal(9) -- the Golden Pond pass has no Store card; the potion packs left the Store
					-- every key is a card the Store can show
					local cards: { [string]: boolean } = {
						[StoreLogic.STARTER.key] = true,
						[StoreLogic.CAFE_PASS.key] = true,
						[StoreLogic.THANK_YOU.key] = true,
					}
					for _, pass in StoreLogic.PASSES do
						cards[pass.key] = true
					end
					for _, product in StoreLogic.PRODUCTS do
						cards[product.key] = true
					end
					for key in Config.StoreWasPrice do
						expect(cards[key]).to.equal(true)
					end
					expect(Config.StoreSaleEnds).to.equal(1797120000) -- 2026-12-13 00:00 UTC
				end
			)
		end)

		it("gives Best Value only at 1.25 x the price or more", function()
			expect(StoreLogic.badge(pack, prices(799, 452))).to.equal("Best Value")
			expect(StoreLogic.badge(pack, prices(799, 400))).to.equal(nil) -- 1195 < 1248.75
		end)
		it(
			"counts only the parts not owned yet, dropping the line and badge below the price",
			function()
				local owned = { [200] = true }
				expect(StoreLogic.worth(pack, prices(799, 452), owned)).to.equal(450)
				expect(StoreLogic.worthLine(pack, prices(799, 452), owned)).to.equal(nil)
				expect(StoreLogic.badge(pack, prices(799, 452), owned)).to.equal(nil)
			end
		)
	end)
	describe("StoreLogic #1168 cards", function()
		local view = {
			products = {
				{
					id = "steady_paw_pack",
					name = "Steady Paw Pack",
					prize = { potions = { steady_potion = 10 } },
				},
			},
			potionNames = { steady_potion = "Steady Paw" },
			have = {},
		}
		local function find(rows: { any }, key: string): any
			for _, row in rows do
				if row.key == key then
					return row
				end
			end
			return nil
		end
		it("no longer shows the Steady Paw Pack (Derek 2026-11-13)", function()
			local rows = StoreLogic.rows({ ProductIds = { steady_paw_pack = 77 } }, {}, nil, view)
			expect(find(rows, "steadyPaw")).to.equal(nil)
			expect(
				find(
					StoreLogic.rows({ ProductIds = { steady_paw_pack = 0 } }, {}, nil, view),
					"steadyPaw"
				)
			).to.equal(nil)
		end)
		it(
			"hides the Garden Decor Pack while its pass is 0 and lists its six pieces once made",
			function()
				expect(
					find(
						StoreLogic.rows({ GardenDecorPackPassId = 0 }, {}, nil, view),
						"gardenDecor"
					)
				).to.equal(nil)
				local row = find(
					StoreLogic.rows({ GardenDecorPackPassId = 55 }, {}, nil, view),
					"gardenDecor"
				)
				expect(row).to.be.ok()
				expect(row.tab).to.equal("passes")
				for _, name in
					{
						"Hanging Fern Basket",
						"Sunflower Pot",
						"Watering Can Planter",
						"Potted Lemon Tree",
						"Ivy Trellis",
						"Garden Swing Seat",
					}
				do
					expect(string.find(row.effect, name, 1, true)).to.be.ok()
				end
				-- #2006: every piece adds money now, nothing reads "Looks only"
				expect(string.find(row.effect, "Looks only", 1, true)).to.equal(nil)
			end
		)
		it(
			"shows the Second Bait Bowl on the Cats tab once its pass is made, priced once, and Owned when bought (#2010)",
			function()
				expect(find(StoreLogic.rows({ SecondBowlPassId = 0 }, {}, nil, view), "secondBowl")).to.equal(
					nil
				)
				local row =
					find(StoreLogic.rows({ SecondBowlPassId = 77 }, {}, nil, view), "secondBowl")
				expect(row).to.be.ok()
				expect(row.tab).to.equal("cats")
				expect(row.passId).to.equal(77)
				expect(row.owned).to.equal(false)
				expect(string.find(row.effect, "two baits", 1, true)).to.be.ok()
				local bought = find(
					StoreLogic.rows({ SecondBowlPassId = 77 }, { [77] = true }, nil, view),
					"secondBowl"
				)
				expect(bought.owned).to.equal(true)
				local count = 0
				for _, id in StoreLogic.passIds({ SecondBowlPassId = 77 }) do
					if id == 77 then
						count += 1
					end
				end
				expect(count).to.equal(1)
			end
		)
	end)
	describe("StoreLogic #1168 Thank You Badge and Sign Style Pack cards", function()
		local function find(rows: { any }, key: string): any
			for _, row in rows do
				if row.key == key then
					return row
				end
			end
			return nil
		end
		local config: any = { ProductIds = { thank_you_badge = 55 }, SignStylePackPassId = 66 }
		it("shows the Thank You Badge under Passes until the player is a supporter", function()
			local row = find(StoreLogic.rows(config, {}, nil, { supporter = false }), "thankYou")
			expect(row).to.be.ok()
			expect(row.passId).to.equal(55)
			expect(row.product).to.equal(true)
			expect(row.tab).to.equal("passes")
			expect(row.effect:find("chat tag", 1, true)).to.be.ok()
			expect(row.effect:find("gold heart", 1, true)).to.be.ok()
			-- #2073: a supporter still sees the card, marked Yours, so it is not bought twice and does not vanish
			local owned = find(StoreLogic.rows(config, {}, nil, { supporter = true }), "thankYou")
			expect(owned).to.be.ok()
			expect(owned.owned).to.equal(true)
			expect(StoreLogic.button(owned, { robux = 5, forSale = true }).text).to.equal("Yours")
			expect(row.owned).to.equal(false)
			expect(table.find(StoreLogic.productIds(config), 55)).to.be.ok()
		end)
		it("hides the Thank You Badge while its product id is 0", function()
			local zero: any = { ProductIds = { thank_you_badge = 0 } }
			expect(find(StoreLogic.rows(zero, {}, nil, { supporter = false }), "thankYou")).to.equal(
				nil
			)
			expect(table.find(StoreLogic.productIds(zero), 0)).to.equal(nil)
		end)
		it("lists the pack's three sign styles by name, and hides it while the id is 0", function()
			local row = find(StoreLogic.rows(config, {}, nil, nil), "signStylePack")
			expect(row).to.be.ok()
			expect(row.passId).to.equal(66)
			for _, name in { "Flower Box", "Starry Night", "Paw Chalkboard", "Looks only" } do
				expect(row.effect:find(name, 1, true)).to.be.ok()
			end
			expect(row.owned).to.equal(false)
			expect(find(StoreLogic.rows(config, { [66] = true }, nil, nil), "signStylePack").owned).to.equal(
				true
			)
			expect(
				find(StoreLogic.rows({ SignStylePackPassId = 0 }, {}, nil, nil), "signStylePack")
			).to.equal(nil)
		end)
		it("names every style the pass sells in shared/SignStyles", function()
			local SignStyles = require(
				game:GetService("ReplicatedStorage")
					:WaitForChild("Shared")
					:WaitForChild("SignStyles")
			) :: any
			local row = find(StoreLogic.rows(config, {}, nil, nil), "signStylePack")
			for _, style in SignStyles.LIST do
				if style.passKey == "SignStylePackPassId" then
					expect(row.effect:find(style.name, 1, true)).to.be.ok()
				end
			end
		end)
	end)
	describe("StoreLogic #1875 free Jukebox", function()
		it("has no Jukebox Pass card, even with a pass id set", function()
			for _, row in StoreLogic.rows({ JukeboxPassId = 77 }, {}, nil, nil) do
				expect(row.key).never.to.equal("jukebox")
				expect(row.name:find("Jukebox", 1, true)).to.equal(nil)
			end
		end)
	end)

	describe("the reworked Store (#3572, storeRework)", function()
		it("puts Cats above Passes on the rail with the rework on, as before without", function()
			local ids = {}
			for _, tab in StoreLogic.railTabs(true) do
				table.insert(ids, tab.id)
			end
			expect(table.concat(ids, ",")).to.equal(
				"featured,packs,cats,passes,potions,cafePass,codes"
			) -- #4026: Packs under Featured
			expect(StoreLogic.railTabs(false)).to.equal(StoreLogic.TABS)
			expect(#StoreLogic.railTabs(true)).to.equal(#StoreLogic.TABS)
		end)

		it("gives each tab its header line, Codes the window's own", function()
			expect(StoreLogic.subtitle("passes")).to.equal(
				"Passes are yours to keep. Prices are in Robux."
			)
			expect(StoreLogic.subtitle("potions")).to.equal(
				"Potions are used from your Bag. Prices are in Robux."
			)
			expect(StoreLogic.subtitle("featured")).to.equal("Prices are in Robux.")
			expect(StoreLogic.subtitle("codes")).to.equal(StoreLogic.SUBTITLE_DEFAULT)
			for _, tab in StoreLogic.TABS do
				expect(#StoreLogic.subtitle(tab.id) > 0).to.equal(true)
			end
		end)

		it("lists each potion a pack holds once, by name, with the bag's count", function()
			local view: any = {
				products = {
					{ id = "s", prize = { potions = { tip = 3, swift = 1 } } },
					{ id = "m", prize = { potions = { tip = 5, steady = 2 } } },
					{ id = "badge", prize = { potions = {} } },
					{ id = "odd", prize = {} },
				},
				potionNames = {
					tip = "Big Money Potion",
					swift = "Swift Potion",
					steady = "Steady Paw Potion",
				},
				have = { tip = 3, steady = 2.7, other = 9 },
			}
			local bag = StoreLogic.bag(view)
			expect(#bag).to.equal(3)
			expect(bag[1].name).to.equal("Big Money Potion")
			expect(bag[1].count).to.equal(3)
			expect(bag[2].id).to.equal("steady")
			expect(bag[2].count).to.equal(2)
			expect(bag[3].id).to.equal("swift")
			expect(bag[3].count).to.equal(0)
			expect(#StoreLogic.bag(nil)).to.equal(0)
			expect(#StoreLogic.bag({ products = {} } :: any)).to.equal(0)
		end)

		it("orders rows cheapest first, unpriced and off sale last, ties as before", function()
			local function row(key: string, passId: number): any
				return { key = key, passId = passId, tab = "passes" }
			end
			local rows = { row("a", 1), row("b", 2), row("c", 3), row("d", 4), row("e", 5) }
			local prices = {
				[1] = { robux = 149, forSale = true },
				[2] = { robux = 5, forSale = true },
				[3] = { robux = 149, forSale = true },
				[4] = { robux = 25, forSale = false }, -- off sale
				-- 5 not in yet
			}
			local keys = {}
			for _, r in StoreLogic.cheapestFirst(rows, prices) do
				table.insert(keys, r.key)
			end
			expect(table.concat(keys, ",")).to.equal("b,a,c,d,e")
			expect(rows[1].key).to.equal("a") -- the list given is not changed
			local none = {}
			for _, r in StoreLogic.cheapestFirst(rows, nil) do
				table.insert(none, r.key)
			end
			expect(table.concat(none, ",")).to.equal("a,b,c,d,e")
		end)

		-- #4026: the outfit packs
		it("gives every outfit pack four pieces worth +100% with the set", function()
			for _, key in { "stylish", "winter", "chef", "space" } do
				local pack = StoreLogic.PACKS[key]
				expect(pack).to.be.ok()
				expect(#pack.pieces).to.equal(4)
				expect(StoreLogic.packTotal(key)).to.equal(100)
				local lines = StoreLogic.packLines(key)
				expect(#lines).to.equal(6)
				expect(lines[5].left).to.equal("All four in use")
				expect(lines[6].right).to.equal("+100% money")
			end
			expect(StoreLogic.packTotal("nope")).to.equal(0)
			expect(#StoreLogic.packLines("nope")).to.equal(0)
		end)

		it("shows a pack on the Packs tab only once its pass id is set", function()
			local hidden = StoreLogic.rows({ StylishPackPassId = 0 }, {})
			expect(#StoreLogic.tabRows(hidden, "packs")).to.equal(0)
			local rows = StoreLogic.rows(
				{ StylishPackPassId = 77, WinterPackPassId = 78 },
				{ [78] = true }
			)
			local packs = StoreLogic.tabRows(rows, "packs")
			expect(#packs).to.equal(2)
			expect(packs[1].key).to.equal("packStylish")
			expect(packs[1].pack).to.equal("stylish")
			expect(packs[1].perk).to.equal("Up to +100% money")
			expect(packs[1].owned).to.equal(false)
			expect(packs[2].owned).to.equal(true)
			local shown = false
			for _, tab in StoreLogic.tabs(rows) do
				shown = shown or tab.id == "packs"
			end
			expect(shown).to.equal(true)
		end)

		it("puts the newest pack still to buy beside 2x Money on Featured", function()
			local config =
				{ MoneyPassIds = { [2] = 11 }, WinterPackPassId = 78, StylishPackPassId = 77 }
			local rows = StoreLogic.rows(config, {})
			local featured = StoreLogic.featured(rows, nil)
			expect(featured.picks[1].key).to.equal("money")
			expect(featured.picks[2].key).to.equal("packWinter")
			local owned = StoreLogic.rows(config, { [78] = true })
			expect(StoreLogic.featured(owned, nil).picks[2].key).to.equal("packStylish")
		end)

		it("lists the cards on sale not already on Featured, biggest saving first", function()
			local rows: { any } = {
				{ key = "royalCat", name = "Royal Cat", passId = 1, tab = "cats", owned = false },
				{
					key = "kingPack",
					name = "King Cat Pack",
					passId = 2,
					tab = "cats",
					owned = false,
				},
				{
					key = "cafeStyle",
					name = "Cafe Style",
					passId = 3,
					tab = "passes",
					owned = false,
				},
				{ key = "vip", name = "VIP", passId = 4, tab = "passes", owned = false },
			}
			local config = {
				StoreWasPrice = {
					royalCat = { was = 599, now = 299 },
					kingPack = { was = 999, now = 499 },
					cafeStyle = { was = 249, now = 125 },
				},
				StoreSaleEnds = 2000,
			}
			local prices = {
				[1] = { robux = 299, forSale = true },
				[2] = { robux = 499, forSale = true },
				[3] = { robux = 125, forSale = true },
				[4] = { robux = 25, forSale = true },
			}
			local list = StoreLogic.saleList(rows, prices, config, 1000, 3, { royalCat = true })
			expect(#list).to.equal(2)
			expect(list[1].key).to.equal("kingPack")
			expect(list[1].robux).to.equal(499)
			expect(list[2].key).to.equal("cafeStyle")
			expect(#StoreLogic.saleList(rows, prices, config, 1000, 1, nil)).to.equal(1)
			expect(#StoreLogic.saleList(rows, prices, config, 3000, 3, nil)).to.equal(0) -- the sale is over
			expect(#StoreLogic.saleList(rows, nil, config, 1000, 3, nil)).to.equal(0)
		end)
	end)
end
