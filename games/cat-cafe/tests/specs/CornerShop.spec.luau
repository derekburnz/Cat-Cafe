--!strict
-- CornerShop.luau, Catalog.cornerShop, Catalog.catFood and the size potions against corner-shop-v2.md (#1180, #1181):
-- the rows at fixed prices with their sizes and tier gates, the size chances, a roll the same for everyone and apart
-- from the Fresh Catch, the buy's refusals (QA checks 1 to 4), the daily limits by UTC day, the sizes sharing one
-- timer (QA check 7), nothing for Robux or golden fish (QA check 9), and the save (version 32).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local CornerShop = require(Shared.CornerShop)
	local FreshCatch = require(Shared.FreshCatch)
	local Potions = require(Shared.Potions)
	local ProfileSchema = require(Shared.ProfileSchema)

	local NOW = 5977152 * 300 + 10 -- 2026-10-28 00:00 UTC, in window 5977152
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
			}
			expect(#Catalog.cornerShop).to.equal(#want)
			for index, row in Catalog.cornerShop do
				expect(row.id).to.equal(want[index][1])
				expect(row.family).to.equal(want[index][2])
				expect(row.size).to.equal(want[index][3])
				expect(row.price).to.equal(want[index][4])
				expect(Catalog.getCornerShopRow(row.id)).to.equal(row)
				-- QA check 3: Big from Tier 3, the Cat Feast from Tier 4, the rest for everyone
				local gate = if row.size == "big" then 3 elseif row.size == "mega" then 4 else nil
				expect(row.needsTier).to.equal(gate)
				if row.kind == "potion" then
					expect(Catalog.getPotion(row.potionId :: string)).to.be.ok()
				elseif row.kind == "food" then
					local food = Catalog.getCatFood(row.foodId :: string)
					expect(food).to.be.ok()
					expect(row.xp).to.equal((food :: any).xp)
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

		it("has each size's chances of 0 to 3, out of 100, and the day's limits", function()
			local means: { [string]: number } = { small = 2.5, regular = 1.15, big = 0.35, mega = 0.1 }
			for size, mean in means do
				local weights = assert(Config.CornerShopSizeWeights[size], size)
				expect(#weights).to.equal(4)
				local total, got = 0, 0
				for index, weight in weights do
					total += weight
					got += (index - 1) * weight / 100
				end
				expect(total).to.equal(100)
				expect(got).to.be.near(mean, 1e-9)
			end
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

		it("keeps Small rows in stock, Big about 30% and the Cat Feast about 10% over many windows", function()
			local count = 2000
			local inStock: { [string]: number } = {}
			for window = WINDOW, WINDOW + count - 1 do
				for _, item in CornerShop.stock(window) do
					if item.amount > 0 then
						inStock[item.itemId] = (inStock[item.itemId] or 0) + 1
					end
				end
			end
			expect((inStock.swift_potion_small or 0) / count >= 0.95).to.equal(true)
			expect((inStock.steady_potion_big or 0) / count).to.be.near(0.3, 0.05)
			expect((inStock.cat_feast or 0) / count).to.be.near(0.1, 0.03)
		end)
	end)

	describe("a buy (QA checks 1, 3 and 4)", function()
		it("charges the fixed price and refuses a restock, a tier gate and too few coins", function()
			local window = assert(windowWith("swift_potion_small", WINDOW))
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, CornerShop.day(window * 300))
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
			expect(CornerShop.buyBlocker(state, buy("kibble", window), window)).to.equal("That isn't in the Corner Shop.")
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

		it("stops a family at its daily limit, any size, until 00:00 UTC", function()
			local window = assert(windowWith("quick_bait_potion_small", WINDOW))
			local day = 20400
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, day)
			CornerShop.record(state, "quick_bait_potion")
			CornerShop.record(state, "quick_bait_potion_big")
			expect(CornerShop.buyBlocker(state, buy("quick_bait_potion_small", window), window)).to.equal(
				"That's all the Quick Bait for today, back tomorrow!"
			)
			for _ = 1, 4 do
				CornerShop.record(state, "steady_potion_small")
			end
			state.bought = {} -- the window's own count is checked first; this test is about the day's
			local steadyWindow = assert(windowWith("steady_potion_small", window))
			CornerShop.refresh(state, steadyWindow, day)
			expect(CornerShop.buyBlocker(state, buy("steady_potion_small", steadyWindow), steadyWindow)).to.equal(
				"That's all the Steady Paw for today, back tomorrow!"
			)
			CornerShop.refresh(state, window, day)
			-- #1190: the row never carries the day's count or the limit
			expect((CornerShop.view(state, window).stock[7] :: any).today).to.equal(nil)
			expect((CornerShop.view(state, window).stock[7] :: any).perDay).to.equal(nil)
			-- the Swift Potion has no limit
			for _ = 1, 10 do
				CornerShop.record(state, "swift_potion_small")
			end
			state.bought = {}
			local swiftWindow = assert(windowWith("swift_potion_small", window))
			CornerShop.refresh(state, swiftWindow, day)
			expect(CornerShop.buyBlocker(state, buy("swift_potion_small", swiftWindow), swiftWindow)).to.equal(nil)
			CornerShop.refresh(state, swiftWindow, day + 1)
			expect(state.today.quick_bait).never.to.be.ok()
		end)

		it("marks every row of a family out today once it hits its limit, and nothing else (#1435)", function()
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
			CornerShop.record(state, "quick_bait_potion_big")
			local out = outRows()
			for _, row in Catalog.cornerShop do
				expect(out[row.id] == true).to.equal(row.family == "quick_bait")
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
				window = 9e9,
				bought = { swift_potion_small = 9, big_cat_snack = 2.5, cafe_fireworks = "1", kibble = 3 },
				day = 1e9,
				today = { quick_bait = 9, swift = 5, nope = 1 },
				foodXpToday = 99999,
			}
			raw.catFood = { cat_snack = 3.7, cat_feast = 5000, kibble = 2, small_cat_snack = -1 }
			migrated = ProfileSchema.migrate(raw, NOW)
			expect(migrated.cornerShop :: any).to.deepEqual({
				window = WINDOW + 1,
				bought = { swift_potion_small = 3, big_cat_snack = 2 },
				day = CornerShop.day(NOW),
				today = { quick_bait = 2, swift = 5 },
				foodXpToday = 99999, -- kept as counted: there is no cap to clamp it to (#1255)
			})
			expect(migrated.catFood :: any).to.deepEqual({ cat_snack = 3, cat_feast = Config.CatFoodMax })
		end)
	end)
end
