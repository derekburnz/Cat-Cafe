--!strict
-- CornerShop.luau, Catalog.cornerShop, Catalog.catFood and the size potions against corner-shop-v2.md (#1180, #1181):
-- the rows at fixed prices with their sizes and tier gates, the Day Cart's roll by price (#1577, day-cart.md section 2),
-- a roll the same for everyone and apart from the Fresh Catch, the buy's refusals (QA checks 1 to 4), the daily limits by UTC day, the sizes sharing one
-- timer (QA check 7), nothing for Robux or golden fish (QA check 9), and the save (version 32).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local CornerShop = require(Shared.CornerShop)
	local FreshCatch = require(Shared.FreshCatch)
	local Potions = require(Shared.Potions)
	local ProfileSchema = require(Shared.ProfileSchema)

	local NOW = Config.ClockEpoch + 3 * 86400 + 10 -- 2026-11-04 00:00:10 UTC, game days count from the epoch (#1437)
	local WINDOW = CornerShop.window(NOW)

	-- The first window from `from` that stocks at least one of `itemId`.
	local function windowWith(itemId: string, from: number): number?
		for window = from, from + 5000 do
			if CornerShop.amountOf(window, itemId) > 0 then
				return window
			end
		end
		return nil
	end

	local function buy(itemId: string, window: number, tier: number?, coins: number?, held: number?): CornerShop.Buy
		return { itemId = itemId, seenWindow = window, tier = tier or 5, coins = coins or 1e12, foodHeld = held or 0 }
	end

	describe("the stock (section 1)", function()
		it("sells every family's sizes at the design's fixed prices, in order", function()
			local want = {
				{ "swift_potion_small", "swift", "small", 3000 },
				{ "swift_potion", "swift", "regular", 100000 },
				{ "swift_potion_big", "swift", "big", 20000000 },
				{ "steady_potion_small", "steady", "small", 10000 },
				{ "steady_potion", "steady", "regular", 400000 },
				{ "steady_potion_big", "steady", "big", 80000000 },
				{ "quick_bait_potion_small", "quick_bait", "small", 25000 },
				{ "quick_bait_potion", "quick_bait", "regular", 1200000 },
				{ "quick_bait_potion_big", "quick_bait", "big", 240000000 },
				{ "cat_whistle_small", "whistle", "small", 8000 },
				{ "cat_whistle", "whistle", "regular", 300000 },
				{ "cat_whistle_big", "whistle", "big", 60000000 },
				{ "small_cat_snack", "food", "small", 4000 },
				{ "cat_snack", "food", "regular", 300000 },
				{ "big_cat_snack", "food", "big", 40000000 },
				{ "cat_feast", "food", "mega", 3200000000 },
				-- #1281: the bait foods, last, at their Tier 1 price (Catalog.lures cost)
				{ "kibble", "bait", "small", (Catalog.getLure("kibble") :: any).cost },
				{ "tuna", "bait", "regular", (Catalog.getLure("tuna") :: any).cost },
				{ "salmon", "bait", "big", (Catalog.getLure("salmon") :: any).cost },
			}
			expect(#Catalog.cornerShop).to.equal(#want)
			for index, row in Catalog.cornerShop do
				expect(row.id).to.equal(want[index][1])
				expect(row.family).to.equal(want[index][2])
				expect(row.size).to.equal(want[index][3])
				expect(row.price).to.equal(want[index][4])
				expect(Catalog.getCornerShopRow(row.id)).to.equal(row)
				-- QA check 3: Big from Tier 3, the Cat Feast from Tier 4, the rest for everyone
				local gate = if row.kind == "bait" then nil
					elseif row.size == "big" then 3
					elseif row.size == "mega" then 4
					else nil
				expect(row.needsTier).to.equal(gate)
				if row.kind == "potion" then
					expect(Catalog.getPotion(row.potionId :: string)).to.be.ok()
				elseif row.kind == "food" then
					local food = Catalog.getCatFood(row.foodId :: string)
					expect(food).to.be.ok()
					expect(row.xp).to.equal((food :: any).xp)
				elseif row.kind == "bait" then
					local lure = Catalog.getLure(row.lureId :: string)
					expect(lure).to.be.ok()
					expect((lure :: any).source).to.equal("shop") -- dealer foods stay with the dealer
				else
					error(row.id .. ": no shows since #1381") -- the Bubble Machine and Cafe Fireworks are gone
				end
			end
			expect(table.isfrozen(Catalog.cornerShop)).to.equal(true)
		end)

		it("has the four cat foods and their XP (section 3)", function()
			local want = { small_cat_snack = 600, cat_snack = 2000, big_cat_snack = 6000, cat_feast = 20000 }
			expect(#Catalog.catFood).to.equal(4)
			for _, food in Catalog.catFood do
				expect(food.xp).to.equal(want[food.id])
			end
		end)

		it("has the Day Cart's odds (#1577, day-cart.md section 2) and the day's limits", function()
			expect(Config.DayCartTopChance).to.equal(0.95)
			expect(Config.DayCartStep).to.equal(0.045)
			expect(Config.DayCartFloor).to.equal(0.05)
			expect(Config.DayCartQtyOdds :: any).to.deepEqual({ 50, 30, 20 })
			expect((Config :: any).CornerShopSizeWeights).never.to.be.ok() -- the size table went with the cart
			expect(CornerShop.MOST).to.equal(3)
			expect(CornerShop.stockChance(1)).to.be.near(0.95, 1e-9)
			expect(CornerShop.stockChance(2)).to.be.near(0.905, 1e-9)
			expect(CornerShop.stockChance(11)).to.be.near(0.5, 1e-9)
			expect(CornerShop.stockChance(21)).to.be.near(0.05, 1e-9)
			expect(CornerShop.stockChance(40)).to.equal(0.05)
			expect(Config.CornerDailyLimits.steady).to.equal(4)
			expect(Config.CornerDailyLimits.quick_bait).to.equal(2)
			expect(Config.CornerDailyLimits.whistle).to.equal(4)
			expect(Config.CornerDailyLimits.swift).never.to.be.ok()
			expect((Config :: any).CornerFoodXpPerDay).never.to.be.ok() -- #1255: no daily cat food cap
		end)
	end)

	describe("the roll (QA check 2)", function()
		it("is the same for every server in a window and differs from the Fresh Catch's", function()
			local differs = false
			for window = WINDOW, WINDOW + 50 do
				local a, b = CornerShop.stock(window), CornerShop.stock(window)
				expect(a :: any).to.deepEqual(b)
				expect(#a).to.equal(#Catalog.cornerShop)
				if CornerShop.seed(window) ~= FreshCatch.seed(window) then
					differs = true
				end
			end
			expect(differs).to.equal(true)
		end)

		it("lists every row once, cheapest Tier 1 price first, ties in Catalog order (#1577)", function()
			local order = CornerShop.listOrder()
			expect(#order).to.equal(#Catalog.cornerShop)
			local seen: { [number]: boolean } = {}
			for place, index in order do
				expect(seen[index]).never.to.be.ok()
				seen[index] = true
				if place > 1 then
					local before, row = Catalog.cornerShop[order[place - 1]], Catalog.cornerShop[index]
					expect(before.price <= row.price).to.equal(true)
					if before.price == row.price then
						expect(order[place - 1] < index).to.equal(true)
					end
				end
			end
			expect(Catalog.cornerShop[order[#order]].id).to.equal("cat_feast") -- the dearest, so the rarest
		end)

		it("stocks each row at its place's chance and 1, 2 or 3 at 50/30/20 over 20,000 days (QA check 2)", function()
			-- 20,000 days, not QA's 100,000: the cloud runner keeps every table a spec makes (its collector is off)
			local count = 20000
			local inStock: { number } = table.create(#Catalog.cornerShop, 0)
			local amounts = { 0, 0, 0 }
			local shown = 0
			for window = WINDOW, WINDOW + count - 1 do
				for index, item in CornerShop.stock(window) do
					if item.amount > 0 then
						inStock[index] += 1
						amounts[item.amount] += 1
						shown += 1
					end
				end
			end
			for place, index in CornerShop.listOrder() do
				expect(inStock[index] / count).to.be.near(CornerShop.stockChance(place), 0.015)
			end
			expect(amounts[1] / shown).to.be.near(0.5, 0.01)
			expect(amounts[2] / shown).to.be.near(0.3, 0.01)
			expect(amounts[3] / shown).to.be.near(0.2, 0.01)
		end)

		it("draws both rolls for every row down the list, so one row's result never moves another's", function()
			local odds = { 0, 50, 30, 20 }
			for window = WINDOW, WINDOW + 50 do
				local stock = CornerShop.stock(window)
				local state = CornerShop.seed(window)
				for place, index in CornerShop.listOrder() do
					state = (state * 48271) % 2147483647
					local inStock = state / 2147483647 < CornerShop.stockChance(place)
					state = (state * 48271) % 2147483647
					local want = if inStock then FreshCatch.pickAmount(odds, state / 2147483647) else 0
					expect(stock[index].itemId).to.equal(Catalog.cornerShop[index].id)
					expect(stock[index].amount).to.equal(want)
				end
			end
		end)
	end)

	describe("a buy (QA checks 1, 3 and 4)", function()
		it("charges the fixed price and refuses a restock, a tier gate and too few coins", function()
			local window = assert(windowWith("swift_potion_small", WINDOW))
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, CornerShop.day(CornerShop.restocksAt(window - 1)))
			local row = Catalog.getCornerShopRow("swift_potion_small") :: any
			expect(CornerShop.view(state, window).stock[1].price).to.equal(3000)
			expect(row.price).to.equal(3000)
			expect(CornerShop.buyBlocker(state, buy("swift_potion_small", window - 1), window)).to.equal(
				"The Corner Shop just restocked. Take another look."
			)
			expect(CornerShop.buyBlocker(state, buy("swift_potion_small", window, 1, 2999), window)).to.equal(
				"Not enough coins"
			)
			expect(CornerShop.buyBlocker(state, buy("swift_potion_small", window, 1, 3000), window)).to.equal(nil)
			expect(CornerShop.buyBlocker(state, buy("caviar", window), window)).to.equal("That isn't in the Corner Shop.")
			expect(CornerShop.buyBlocker(state, buy("steady_potion_big", window, 2), window)).to.equal(
				"Opens at Tier 3"
			)
			expect(CornerShop.buyBlocker(state, buy("cat_feast", window, 3), window)).to.equal("Opens at Tier 4")
		end)

		it("sells up to the window's amount, then none until the next window", function()
			local window = assert(windowWith("swift_potion_small", WINDOW))
			local amount = CornerShop.amountOf(window, "swift_potion_small")
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, 0)
			state.bought.swift_potion_small = amount
			local blocker = CornerShop.buyBlocker(state, buy("swift_potion_small", window), window)
			expect(blocker == "You bought the only one this time." or blocker == "You bought them all this time.").to.equal(
				true
			)
			CornerShop.refresh(state, window - 1, 0) -- a server a second behind never clears it
			expect(state.bought.swift_potion_small).to.equal(amount)
			expect(CornerShop.buyBlocker(state, buy("swift_potion_small", window - 1), window - 1)).to.equal(
				"The shop is restocking. Try again in a moment."
			)
			CornerShop.refresh(state, window + 1, 0)
			expect(state.bought.swift_potion_small).never.to.be.ok()
		end)

		it("stops each row at its family's daily limit on its own until the next game day (#1629, #1712)", function()
			local window = assert(windowWith("quick_bait_potion_small", WINDOW))
			local day = 20400
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, day)
			-- #1712 (Derek2): the other sizes' buys never use up this one's
			CornerShop.record(state, "quick_bait_potion")
			CornerShop.record(state, "quick_bait_potion_big")
			CornerShop.record(state, "quick_bait_potion_big")
			expect(CornerShop.buyBlocker(state, buy("quick_bait_potion_small", window), window)).to.equal(nil)
			CornerShop.record(state, "quick_bait_potion_small")
			CornerShop.record(state, "quick_bait_potion_small")
			state.bought = {} -- the window's own count is checked first; this test is about the day's
			expect(CornerShop.buyBlocker(state, buy("quick_bait_potion_small", window), window)).to.equal(
				"That's all the Small Quick Bait Potion for today, back at sunrise!"
			)
			local steadyWindow = assert(windowWith("steady_potion_small", window))
			CornerShop.refresh(state, steadyWindow, day)
			for _ = 1, 4 do
				CornerShop.record(state, "steady_potion_small")
			end
			state.bought = {} -- the window's own count is checked first; this test is about the day's
			expect(CornerShop.buyBlocker(state, buy("steady_potion_small", steadyWindow), steadyWindow)).to.equal(
				"That's all the Small Steady Paw Potion for today, back at sunrise!"
			)
			CornerShop.refresh(state, window, day)
			-- #1190: the row never carries the day's count or the limit
			expect((CornerShop.view(state, window).stock[7] :: any).today).to.equal(nil)
			expect((CornerShop.view(state, window).stock[7] :: any).perDay).to.equal(nil)
			-- the Swift Potion has no limit
			local swiftWindow = assert(windowWith("swift_potion_small", window))
			CornerShop.refresh(state, swiftWindow, day)
			for _ = 1, 10 do
				CornerShop.record(state, "swift_potion_small")
			end
			state.bought = {}
			expect(CornerShop.buyBlocker(state, buy("swift_potion_small", swiftWindow), swiftWindow)).to.equal(nil)
		end)

		it("resets the family limits at the next game day, not at 00:00 UTC (#1629)", function()
			local window = assert(windowWith("quick_bait_potion_small", WINDOW))
			local day = 20400
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, day)
			CornerShop.record(state, "quick_bait_potion_small")
			CornerShop.record(state, "quick_bait_potion_small")
			expect(state.today.quick_bait_potion_small).to.equal(2)
			-- the same game day on another server, or a second's step back, keeps the count
			CornerShop.refresh(state, window, day)
			CornerShop.refresh(state, window - 1, day)
			expect(state.today.quick_bait_potion_small).to.equal(2)
			-- the next sunrise clears it within the same UTC day
			local later = assert(windowWith("quick_bait_potion_small", window + 1))
			CornerShop.refresh(state, later, day)
			expect(state.today.quick_bait_potion_small).never.to.be.ok()
			expect(CornerShop.buyBlocker(state, buy("quick_bait_potion_small", later), later)).to.equal(nil)
		end)

		it("marks a row out today once it hits its family's limit, and nothing else (#1435, #1712)", function()
			local window = WINDOW
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, 20400)
			local function outRows(): { [string]: boolean }
				local out: { [string]: boolean } = {}
				for _, item in CornerShop.view(state, window).stock do
					expect(item.outToday == nil or item.outToday == true).to.equal(true)
					if item.outToday then
						out[item.itemId] = true
					end
				end
				return out
			end
			expect(next(outRows())).to.equal(nil)
			CornerShop.record(state, "quick_bait_potion")
			expect(next(outRows())).to.equal(nil) -- one of two: still for sale
			CornerShop.record(state, "quick_bait_potion")
			local out = outRows()
			for _, row in Catalog.cornerShop do
				-- #1712: only the row bought out; the Small and Big Quick Bait stay for sale
				expect(out[row.id] == true).to.equal(row.id == "quick_bait_potion")
			end
			-- the Swift Potion has no limit, so it is never out today
			for _ = 1, 20 do
				CornerShop.record(state, "swift_potion_small")
			end
			expect(outRows().swift_potion_small).to.equal(nil)
			-- a new UTC day clears it
			CornerShop.refresh(state, window, 20401)
			expect(next(outRows())).to.equal(nil)
		end)

		it("sells food past any XP a day (#1255) but never past a full Bag", function()
			local window = assert(windowWith("big_cat_snack", WINDOW))
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, 0)
			state.foodXpToday = 500000
			expect(CornerShop.buyBlocker(state, buy("big_cat_snack", window), window)).to.equal(nil)
			state.foodXpToday = 0
			expect(CornerShop.buyBlocker(state, buy("big_cat_snack", window, 5, 1e12, Config.CatFoodMax), window)).to.equal(
				"Your Bag is full of that food"
			)
			CornerShop.record(state, "big_cat_snack")
			expect(state.foodXpToday).to.equal(6000)
			expect(CornerShop.view(state, window).snackXp).to.equal(6000)
		end)

		it("never asks for golden fish or Robux and sells nothing random (QA check 9)", function()
			for _, row in Catalog.cornerShop do
				local any = row :: any
				expect(any.fish).never.to.be.ok()
				expect(any.robux).never.to.be.ok()
				expect(any.crateId).never.to.be.ok()
			end
		end)
	end)

	describe("the size potions (QA check 7)", function()
		it("runs a Small and a Big Steady Paw on one timer", function()
			local profile = ProfileSchema.template(NOW)
			profile.potions.steady_potion_small = 1
			profile.potions.steady_potion_big = 1
			expect(Potions.use(profile, "steady_potion_small", NOW)).to.equal(true)
			expect(Potions.use(profile, "steady_potion_big", NOW)).to.equal(true)
			expect(Potions.left(profile, "steady_potion", NOW)).to.equal(35 * 60)
			expect(profile.buffs.steady_potion_small).never.to.be.ok()
			expect(Potions.runningIds(profile, NOW) :: any).to.deepEqual({ "steady_potion" })
			expect(Potions.buffOf("cat_whistle_big")).to.equal("cat_whistle")
			expect(Potions.buffOf("swift_potion")).to.equal("swift_potion")
		end)

		it("keeps the Corner Shop's own potions out of Mystery gifts", function()
			for _ = 1, 400 do
				local gift = Potions.rollGift(function(): number
					return math.random()
				end)
				if gift.kind == "potion" then
					expect((Catalog.getPotion(gift.id :: string) :: any).shopOnly).never.to.be.ok()
				end
			end
		end)
	end)

	describe("where cat food comes from (section 3, QA check 6)", function()
		local Collector = require(Shared.Collector)
		local DailyTreat = require(Shared.DailyTreat)

		it("gives food on Daily Treat days 1, 3 and 5 beside their coins", function()
			expect(DailyTreat.prize(1).catFood :: any).to.deepEqual({ small_cat_snack = 2 })
			expect(DailyTreat.prize(3).catFood :: any).to.deepEqual({ cat_snack = 1 })
			expect(DailyTreat.prize(5).catFood :: any).to.deepEqual({ cat_snack = 1 })
			expect(DailyTreat.prize(2).catFood).never.to.be.ok()
			for _, day in { 1, 3, 5 } do
				expect((DailyTreat.prize(day).coins or 0) > 0).to.equal(true)
			end
		end)

		it("lets the Collector offer 2 Big Snacks between his fish offers", function()
			local offer = Collector.offerFor(8)
			expect(offer.catFood :: any).to.deepEqual({ big_cat_snack = 2 })
			expect(Collector.prize(offer, "alley").catFood :: any).to.deepEqual({ big_cat_snack = 2 })
			expect(Collector.offerFor(11).fish).to.equal(20)
		end)

		it("drops a Small Snack 1 time in 10 on a catch and gives one per rescue", function()
			expect(Config.CatchSnackChance).to.equal(0.1)
			expect(Catalog.getCatFood(Config.RescueSnack)).to.be.ok()
		end)
	end)

	describe("the bait foods (section 1b, #1281)", function()
		local Economy = require(Shared.Economy)

		it("rolls Kibble, Tuna and Salmon by their place in the list, like every row (#1577)", function()
			for _, id in { "kibble", "tuna", "salmon" } do
				expect((Catalog.getCornerShopRow(id) :: any).weights).never.to.be.ok() -- their own chances went
				expect(windowWith(id, WINDOW)).to.be.ok()
			end
		end)

		it("charges the food's price for the tier and shows it", function()
			local window = assert(windowWith("salmon", WINDOW))
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, 0)
			local row = Catalog.getCornerShopRow("salmon") :: any
			for tier = 1, 5 do
				expect(CornerShop.priceOf(row, tier)).to.equal(Economy.foodPrice("salmon", tier))
			end
			local view = CornerShop.view(state, window, 4)
			for index, item in view.stock do
				if Catalog.cornerShop[index].kind == "bait" then
					expect(item.price).to.equal(Economy.foodPrice(item.itemId, 4))
				else
					expect(item.price).to.equal(Catalog.cornerShop[index].price) -- the fixed rows don't move
				end
			end
			local price = Economy.foodPrice("salmon", 4)
			local function baitBuy(coins: number, held: number?, shown: number?): CornerShop.Buy
				local b = buy("salmon", window, 4, coins)
				b.lureHeld = held
				b.shownPrice = shown
				return b
			end
			expect(CornerShop.buyBlocker(state, baitBuy(price - 1), window)).to.equal("Not enough coins")
			expect(CornerShop.buyBlocker(state, baitBuy(price), window)).to.equal(nil)
			expect(CornerShop.buyBlocker(state, baitBuy(price, 0, price), window)).to.equal(nil)
			-- a rank up while the window was open: the shown price is the old tier's
			expect(CornerShop.buyBlocker(state, baitBuy(1e12, 0, Economy.foodPrice("salmon", 3)), window)).to.equal(
				"The price changed. Take another look."
			)
			expect(CornerShop.buyBlocker(state, baitBuy(1e12, CornerShop.LURE_MAX), window)).to.equal(
				"You have all the Salmon you can carry"
			)
			expect(CornerShop.buyBlocker(state, baitBuy(1e12, CornerShop.LURE_MAX - 1), window)).to.equal(nil)
		end)

		it("has no daily limit and no tier gate", function()
			local window = assert(windowWith("kibble", WINDOW))
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, 0)
			expect(CornerShop.perDay("bait")).to.equal(nil)
			state.today.bait = 500
			expect(CornerShop.buyBlocker(state, buy("kibble", window, 1, 100), window)).to.equal(nil)
			CornerShop.record(state, "kibble")
			expect(state.bought.kibble).to.equal(1)
			expect(state.foodXpToday).to.equal(0)
		end)
	end)

	describe("save version 32", function()
		it("starts an older save afresh for the day and keeps the Bag's food whole", function()
			expect(ProfileSchema.VERSION >= 32).to.equal(true)
			local raw: any = ProfileSchema.template(NOW)
			raw.version = 31
			raw.cornerShop = { window = WINDOW, bought = { swift_potion = 2 }, snackDay = 20000, snackXp = 900 }
			raw.catFood = nil
			local migrated = ProfileSchema.migrate(raw, NOW)
			expect(migrated.cornerShop :: any).to.deepEqual({
				window = WINDOW,
				bought = { swift_potion = 2 },
				day = 0,
				today = {},
				foodXpToday = 0,
			})
			expect(migrated.catFood :: any).to.deepEqual({})
			raw.cornerShop = {
				window = WINDOW + 1, -- the next window, from a server a moment ahead
				bought = { swift_potion_small = 9, big_cat_snack = 2.5, cafe_fireworks = "1", caviar = 3 },
				day = 1e9,
				-- #1712: counts by row; an older save's family counts (quick_bait) start the day afresh
				today = { quick_bait = 9, quick_bait_potion = 9, swift_potion = 5, nope = 1 },
				foodXpToday = 99999,
			}
			raw.catFood = { cat_snack = 3.7, cat_feast = 5000, kibble = 2, small_cat_snack = -1 }
			migrated = ProfileSchema.migrate(raw, NOW)
			expect(migrated.cornerShop :: any).to.deepEqual({
				window = WINDOW + 1,
				bought = { swift_potion_small = 3, big_cat_snack = 2 },
				day = CornerShop.day(NOW),
				today = { quick_bait_potion = 2, swift_potion = 5 },
				foodXpToday = 99999, -- kept as counted: there is no cap to clamp it to (#1255)
			})
			expect(migrated.catFood :: any).to.deepEqual({ cat_snack = 3, cat_feast = Config.CatFoodMax })
		end)

		it("starts a window from the old 5 minute count afresh and keeps the day's counts (#1437)", function()
			local raw: any = ProfileSchema.template(NOW)
			raw.cornerShop = {
				window = math.floor(NOW / 300), -- the old count, far past today's game day window
				bought = { swift_potion_small = 2 },
				day = CornerShop.day(NOW),
				today = { quick_bait_potion = 1 },
				foodXpToday = 40,
			}
			local migrated = ProfileSchema.migrate(raw, NOW)
			expect(migrated.cornerShop :: any).to.deepEqual({
				window = 0,
				bought = {},
				day = CornerShop.day(NOW),
				today = { quick_bait_potion = 1 },
				foodXpToday = 40,
			})
			local blocker = CornerShop.buyBlocker(migrated.cornerShop, buy("swift_potion_small", WINDOW), WINDOW)
			expect(blocker).never.to.equal("The shop is restocking. Try again in a moment.")
		end)
	end)
end
