--!strict
-- CornerShop.luau, Catalog.cornerShop and Economy.cornerPrice against corner-shop.md (#1052): the five rows and their
-- prices in seconds of the day rate, the chances of 0 to 3, a roll the same for everyone and apart from the Fresh
-- Catch, the buy's refusals in order (QA checks 2 to 4 and 7), the snack cap by UTC day, and the save (version 29).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local CornerShop = require(Shared.CornerShop)
	local Economy = require(Shared.Economy)
	local FreshCatch = require(Shared.FreshCatch)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Types = require(Shared.Types)

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

	local function buy(itemId: string, window: number, shownPrice: number, ownsCat: boolean?): CornerShop.Buy
		return { itemId = itemId, seenWindow = window, shownPrice = shownPrice, ownsCat = ownsCat ~= false }
	end

	describe("the shelf (section 2)", function()
		it("sells the five rows at the design's seconds and floors, in order", function()
			local want = {
				{ "swift_potion", "potion", 120, 200 },
				{ "cat_snack", "snack", 300, 500 },
				{ "big_cat_snack", "snack", 1200, 2500 },
				{ "bubble_machine", "show", 600, 1000 },
				{ "cafe_fireworks", "show", 900, 1500 },
			}
			expect(#Catalog.cornerShop).to.equal(#want)
			for index, row in Catalog.cornerShop do
				expect(row.id).to.equal(want[index][1])
				expect(row.kind).to.equal(want[index][2])
				expect(row.seconds).to.equal(want[index][3])
				expect(row.atLeast).to.equal(want[index][4])
				expect(Catalog.getCornerShopRow(row.id)).to.equal(row)
			end
			expect((Catalog.getCornerShopRow("cat_snack") :: any).xp).to.equal(1200)
			expect((Catalog.getCornerShopRow("big_cat_snack") :: any).xp).to.equal(6000)
			expect(Catalog.getPotion("swift_potion")).to.be.ok()
			expect((Catalog.getCornerShopRow("bubble_machine") :: any).showSeconds).to.equal(600)
			expect((Catalog.getCornerShopRow("cafe_fireworks") :: any).showSeconds).to.equal(20)
			expect(table.isfrozen(Catalog.cornerShop)).to.equal(true)
		end)

		it("has the design's chances of 0 to 3 of each row, out of 100", function()
			local means = {
				swift_potion = 2.2,
				cat_snack = 1.7,
				big_cat_snack = 0.45,
				bubble_machine = 0.9,
				cafe_fireworks = 0.7,
			}
			for _, row in Catalog.cornerShop do
				local weights = assert(Config.CornerShopAmountWeights[row.id], row.id)
				expect(#weights).to.equal(4)
				local total, mean = 0, 0
				for index, weight in weights do
					total += weight
					mean += (index - 1) * weight / 100
				end
				expect(total).to.equal(100)
				expect(mean).to.be.near(means[row.id], 1e-9)
			end
			expect(Config.CornerShopWindowSeconds).to.equal(300)
			expect(Config.CornerShopRange).to.equal(14)
			expect(Config.CornerSnackXpPerDay).to.equal(12000)
		end)
	end)

	describe("the price (section 2, QA check 2)", function()
		it("is the row's seconds of the day rate, never under its floor", function()
			local swift = Catalog.getCornerShopRow("swift_potion") :: Types.CornerShopRow
			expect(Economy.cornerPrice(swift, 0)).to.equal(200)
			expect(Economy.cornerPrice(swift, 1)).to.equal(200)
			expect(Economy.cornerPrice(swift, 10)).to.equal(1200)
			expect(Economy.cornerPrice(swift, 20)).to.equal(2400) -- a 2x Money pass doubles the day rate
			expect(Economy.cornerPrice(swift, 10.75)).to.equal(1290)
			expect(Economy.cornerPrice(swift, -5)).to.equal(200)
		end)

		it("reads the day rate without running potions (incomePerSecond)", function()
			local profile = ProfileSchema.template(NOW)
			local before = Economy.incomePerSecond(profile)
			profile.buffs.tip_potion = 300
			expect(Economy.incomePerSecond(profile)).to.equal(before)
		end)
	end)

	describe("the roll (section 4, QA check 1)", function()
		it("is the same for every server in a window and stays inside each row's chances", function()
			for window = WINDOW, WINDOW + 50 do
				local a, b = CornerShop.stock(window), CornerShop.stock(window)
				expect(a :: any).to.deepEqual(b)
				expect(#a).to.equal(#Catalog.cornerShop)
				for index, item in a do
					expect(item.itemId).to.equal(Catalog.cornerShop[index].id)
					local weights = Config.CornerShopAmountWeights[item.itemId]
					expect(weights[item.amount + 1] > 0).to.equal(true)
				end
			end
		end)

		it("differs from the Fresh Catch's roll in some windows", function()
			local differs = false
			for window = WINDOW, WINDOW + 50 do
				if CornerShop.seed(window) ~= FreshCatch.seed(window) then
					differs = true
				end
			end
			expect(differs).to.equal(true)
		end)

		it("comes near the design's average stock over many windows", function()
			local count = 4000
			local sums: { [string]: number } = {}
			for window = WINDOW, WINDOW + count - 1 do
				for _, item in CornerShop.stock(window) do
					sums[item.itemId] = (sums[item.itemId] or 0) + item.amount
				end
			end
			expect(sums.swift_potion / count).to.be.near(2.2, 0.1)
			expect(sums.cat_snack / count).to.be.near(1.7, 0.1)
			expect(sums.big_cat_snack / count).to.be.near(0.45, 0.06)
			expect(sums.bubble_machine / count).to.be.near(0.9, 0.08)
			expect(sums.cafe_fireworks / count).to.be.near(0.7, 0.08)
		end)
	end)

	describe("a buy (section 5, QA checks 3, 4 and 7)", function()
		it("refuses a buy across a restock, a raised price and too few coins, and passes a good one", function()
			local window = assert(windowWith("swift_potion", WINDOW))
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, CornerShop.day(window * 300))
			expect(CornerShop.buyBlocker(state, buy("swift_potion", window - 1, 200), window, 200, 1000)).to.equal(
				"The Corner Shop just restocked. Take another look."
			)
			expect(CornerShop.buyBlocker(state, buy("swift_potion", window, 199), window, 200, 1000)).to.equal(
				"The price just changed. Take another look."
			)
			expect(CornerShop.buyBlocker(state, buy("swift_potion", window, 200), window, 200, 199)).to.equal(
				"Not enough coins"
			)
			expect(CornerShop.buyBlocker(state, buy("swift_potion", window, 250), window, 200, 200)).to.equal(nil)
			expect(CornerShop.buyBlocker(state, buy("kibble", window, 999), window, 1, 1000)).to.equal(
				"That isn't in the Corner Shop."
			)
		end)

		it("sells up to the window's amount, then none until the next window", function()
			local window = assert(windowWith("swift_potion", WINDOW))
			local amount = CornerShop.amountOf(window, "swift_potion")
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, 0)
			state.bought.swift_potion = amount
			local blocker = CornerShop.buyBlocker(state, buy("swift_potion", window, 200), window, 200, 1000)
			expect(blocker == "You bought the only one this time." or blocker == "You bought them all this time.").to.equal(
				true
			)
			CornerShop.refresh(state, window - 1, 0) -- a server a second behind never clears it
			expect(state.bought.swift_potion).to.equal(amount)
			expect(CornerShop.buyBlocker(state, buy("swift_potion", window - 1, 200), window - 1, 200, 1000)).to.equal(
				"The shop is restocking. Try again in a moment."
			)
			CornerShop.refresh(state, window + 1, 0)
			expect(state.bought.swift_potion).never.to.be.ok()
		end)

		it("needs one of the player's cats for a snack and stops snacks at 12,000 XP a UTC day", function()
			local window = assert(windowWith("big_cat_snack", WINDOW))
			local day = 20400
			local state = CornerShop.fresh()
			CornerShop.refresh(state, window, day)
			expect(CornerShop.buyBlocker(state, buy("big_cat_snack", window, 2500, false), window, 2500, 99999)).to.equal(
				"Pick one of your cats for the snack."
			)
			expect(CornerShop.buyBlocker(state, buy("big_cat_snack", window, 2500), window, 2500, 99999)).to.equal(nil)
			state.snackXp = 6000
			expect(CornerShop.snackRoom(state)).to.equal(6000)
			expect(CornerShop.buyBlocker(state, buy("big_cat_snack", window, 2500), window, 2500, 99999)).to.equal(nil)
			state.snackXp = 6001
			expect(CornerShop.buyBlocker(state, buy("big_cat_snack", window, 2500), window, 2500, 99999)).to.equal(
				"Snacks are full for today"
			)
			CornerShop.refresh(state, window, day + 1) -- 00:00 UTC
			expect(state.snackXp).to.equal(0)
			expect(CornerShop.buyBlocker(state, buy("big_cat_snack", window, 2500), window, 2500, 99999)).to.equal(nil)
		end)

		it("never asks for golden fish or Robux and sells nothing random (QA check 7)", function()
			for _, row in Catalog.cornerShop do
				local any = row :: any
				expect(any.fish).never.to.be.ok()
				expect(any.robux).never.to.be.ok()
				expect(any.crateId).never.to.be.ok()
				expect(row.kind == "potion" or row.kind == "snack" or row.kind == "show").to.equal(true)
			end
		end)
	end)

	describe("the window's numbers", function()
		it("shows each row's price, amount and bought count, and when it restocks", function()
			local state = CornerShop.fresh()
			CornerShop.refresh(state, WINDOW, 0)
			state.bought.cat_snack = 1
			state.snackXp = 1200
			local view = CornerShop.view(state, WINDOW, 10)
			expect(view.window).to.equal(WINDOW)
			expect(view.restocksAt).to.equal((WINDOW + 1) * 300)
			expect(view.snackXp).to.equal(1200)
			expect(#view.stock).to.equal(5)
			expect(view.stock[1].price).to.equal(1200)
			expect(view.stock[2].bought).to.equal(1)
			expect(view.stock[2].amount).to.equal(CornerShop.amountOf(WINDOW, "cat_snack"))
		end)
	end)

	describe("save version 29", function()
		it("starts an older save with nothing bought and makes a damaged one whole", function()
			expect(ProfileSchema.VERSION >= 29).to.equal(true)
			local raw: any = ProfileSchema.template(NOW)
			raw.version = 28
			raw.cornerShop = nil
			expect(ProfileSchema.migrate(raw, NOW).cornerShop :: any).to.deepEqual(CornerShop.fresh())
			raw.cornerShop = {
				window = 9e9,
				bought = { swift_potion = 9, big_cat_snack = 2.5, cafe_fireworks = "1", kibble = 3 },
				snackDay = 1e9,
				snackXp = 99999,
			}
			expect(ProfileSchema.migrate(raw, NOW).cornerShop :: any).to.deepEqual({
				window = WINDOW + 1,
				bought = { swift_potion = 3, big_cat_snack = 2 },
				snackDay = CornerShop.day(NOW),
				snackXp = 12000,
			})
		end)
	end)
end
