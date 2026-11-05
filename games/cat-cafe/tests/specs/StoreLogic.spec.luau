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
			expect(rows[3].effect:find("3 Big Money, 1 Swift Potion · You have 4", 1, true) ~= nil).to.equal(
				true
			)
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

		it("says Owned and cannot be pressed for an owned pass", function()
			local owned = table.clone(row)
			owned.owned = true
			local button = StoreLogic.button(owned, { robux = 5, forSale = true })
			expect(button.text).to.equal("Owned")
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
			-- no Cafe Pass card yet, so no Cafe Pass tab
			expect(table.concat(tabs, ",")).to.equal("featured,passes,cats,potions")
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
end
