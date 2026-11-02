--!strict
-- shared/FreshCatch.luau and Catalog.freshCatch against rewards-and-shops.md section 3 (F94): the shelf's rows and
-- prices, a stock every FreshCatchWindowSeconds that is the same on every server (the roll the night dealer used from
-- v0.8 F59 to F94), bought counts cleared only when the window moves forward (reviewer N32), the once a window heads
-- up and the saved state. QA checks 4 and 6.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local FreshCatch = require(Shared.FreshCatch)

	-- the real windows from 2026-10-28 00:00 UTC
	local TODAY = FreshCatch.window(1793145600)

	-- A window at or after `from` whose stock has `itemId`, else nil.
	local function windowWith(itemId: string, from: number): number?
		for window = from, from + 5000 do
			if FreshCatch.amountOf(window, itemId) > 0 then
				return window
			end
		end
		return nil
	end

	describe("the shelf (section 3)", function()
		it("sells the design's eight rows at the design's prices, in order", function()
			local want = {
				{ "tip_potion", "potion", 10 },
				{ "swift_potion", "potion", 6 },
				{ "steady_potion", "potion", 12 },
				{ "quick_bait_potion", "potion", 15 },
				{ "big_tip_potion", "potion", 25 },
				{ "lucky_potion", "potion", 25 },
				{ "gold_rush_potion", "potion", 30 },
				{ "classic_crate", "crate", 50 },
			}
			expect(#Catalog.freshCatch).to.equal(#want)
			for index, row in Catalog.freshCatch do
				expect(row.id).to.equal(want[index][1])
				expect(row.kind).to.equal(want[index][2])
				expect(row.fish).to.equal(want[index][3])
				expect(Catalog.getFreshCatchRow(row.id)).to.equal(row)
				if row.kind == "potion" then
					expect(row.potionId).to.equal(row.id)
					expect(Catalog.getPotion(row.potionId :: string)).to.be.ok()
				else
					expect(row.crateId).to.equal(row.id)
					expect(Catalog.getCrate(row.crateId :: string)).to.be.ok()
				end
			end
			expect(Catalog.getFreshCatchRow("kibble")).never.to.be.ok()
			expect(table.isfrozen(Catalog.freshCatch)).to.equal(true)
		end)

		it("sells the Classic Crate 10 golden fish under its Market price", function()
			local crate = Catalog.getCrate("classic_crate")
			assert(crate ~= nil)
			expect((Catalog.getFreshCatchRow("classic_crate") :: any).fish).to.equal(
				(crate.price :: number) - 10
			)
		end)

		it("alerts on the Gold Rush Potion and the cheap crate only", function()
			for _, row in Catalog.freshCatch do
				expect(row.alert == true).to.equal(
					row.id == "gold_rush_potion" or row.id == "classic_crate"
				)
			end
		end)

		it("has the design's chances of 0 to 3 of each row, out of 100", function()
			local means = {
				tip_potion = 1.7,
				swift_potion = 1.7,
				steady_potion = 0.95,
				quick_bait_potion = 0.75,
				big_tip_potion = 0.45,
				lucky_potion = 0.45,
				gold_rush_potion = 0.25,
				classic_crate = 0.1,
			}
			for _, row in Catalog.freshCatch do
				local weights = Config.FreshCatchAmountWeights[row.id]
				assert(weights, row.id)
				expect(#weights).to.equal(4)
				local total, mean = 0, 0
				for index, weight in weights do
					total += weight
					mean += (index - 1) * weight / 100
				end
				expect(total).to.equal(100)
				expect(mean).to.be.near(means[row.id], 1e-9)
			end
		end)
	end)

	describe("windows and stock (QA check 4)", function()
		it("are FreshCatchWindowSeconds long and restock at the next one", function()
			local w = Config.FreshCatchWindowSeconds
			expect(w).to.equal(300)
			expect(FreshCatch.window(0)).to.equal(0)
			expect(FreshCatch.window(w - 1)).to.equal(0)
			expect(FreshCatch.window(w)).to.equal(1)
			expect(FreshCatch.restocksAt(FreshCatch.window(w * 5 + 30))).to.equal(w * 6)
		end)

		it("is the same stock for everyone in a window, in shelf order", function()
			local first = FreshCatch.stock(TODAY)
			local again = FreshCatch.stock(TODAY)
			expect(#first).to.equal(#Catalog.freshCatch)
			for index, item in first do
				expect(item.itemId).to.equal(Catalog.freshCatch[index].id)
				expect(item.amount).to.equal(again[index].amount)
				expect(FreshCatch.amountOf(TODAY, item.itemId)).to.equal(item.amount)
			end
			expect(FreshCatch.amountOf(TODAY, "kibble")).to.equal(0)
		end)

		it(
			"follows FreshCatchAmountWeights over many windows and never rolls a zero weight",
			function()
				local counts: { [string]: { number } } = {}
				local windows = 70 * 288
				for window = TODAY, TODAY + windows - 1 do
					for _, item in FreshCatch.stock(window) do
						local weights = Config.FreshCatchAmountWeights[item.itemId]
						if weights[item.amount + 1] == 0 then
							error(
								string.format(
									"window %d rolled %d %s, a zero weight",
									window,
									item.amount,
									item.itemId
								)
							)
						end
						local row = counts[item.itemId] or { 0, 0, 0, 0 }
						row[item.amount + 1] += 1
						counts[item.itemId] = row
					end
				end
				for itemId, weights in Config.FreshCatchAmountWeights do
					local row = counts[itemId]
					assert(row, itemId)
					for index, weight in weights do
						expect(row[index] / windows).to.be.near(weight / 100, 0.02)
					end
				end
			end
		)

		it(
			"rolls each window afresh: a row matches the window before about as often as chance",
			function()
				local count = 70 * 288
				local amounts: { [string]: { number } } = {}
				for window = TODAY, TODAY + count - 1 do
					for _, item in FreshCatch.stock(window) do
						local list = amounts[item.itemId] or {}
						table.insert(list, item.amount)
						amounts[item.itemId] = list
					end
				end
				for itemId, weights in Config.FreshCatchAmountWeights do
					local chance = 0
					for _, weight in weights do
						chance += (weight / 100) ^ 2
					end
					local list = amounts[itemId]
					local same = 0
					for index = 2, count do
						if list[index] == list[index - 1] then
							same += 1
						end
					end
					expect(same / (count - 1)).to.be.near(chance, 0.03)
				end
			end
		)
	end)

	describe("bought counts (reviewer N32)", function()
		it("clear only when the window moves forward", function()
			local state = { window = 10, bought = { tip_potion = 2 }, alerted = 0 }
			FreshCatch.refresh(state, 10)
			expect(state.bought.tip_potion).to.equal(2)
			FreshCatch.refresh(state, 9) -- another server a second behind at the edge
			expect(state.window).to.equal(10)
			expect(state.bought.tip_potion).to.equal(2)
			FreshCatch.refresh(state, 11)
			expect(state.window).to.equal(11)
			expect(state.bought.tip_potion).never.to.be.ok()
		end)

		it("count every row as bought out while the window is behind the saved one", function()
			local state = { window = 10, bought = {}, alerted = 0 }
			expect(FreshCatch.behind(state, 9)).to.equal(true)
			expect(FreshCatch.behind(state, 10)).to.equal(false)
			FreshCatch.refresh(state, 11)
			expect(FreshCatch.behind(state, 11)).to.equal(false)
		end)
	end)

	describe("the heads up (QA check 6)", function()
		it("names an alert row in stock that the player can afford, once a window", function()
			local window = windowWith("gold_rush_potion", TODAY)
			assert(window ~= nil, "no Gold Rush Potion in 5000 windows")
			local state = FreshCatch.fresh()
			local row = FreshCatch.alertFor(state, window, 30)
			expect(row).to.be.ok()
			expect((row :: any).alert).to.equal(true)
			expect(FreshCatch.alertFor(state, window, 29)).never.to.be.ok() -- 30 for the potion, 50 for the crate
			state.alerted = window
			expect(FreshCatch.alertFor(state, window, 1000)).never.to.be.ok()
		end)

		it("stays quiet in a window with no alert row and with too few golden fish", function()
			local quiet: number? = nil
			for window = TODAY, TODAY + 200 do
				if #FreshCatch.alerts(window) == 0 then
					quiet = window
					break
				end
			end
			assert(quiet ~= nil)
			expect(FreshCatch.alertFor(FreshCatch.fresh(), quiet, 10000)).never.to.be.ok()
			local window = windowWith("gold_rush_potion", TODAY) :: number
			expect(FreshCatch.alertFor(FreshCatch.fresh(), window, 0)).never.to.be.ok()
		end)

		it("goes out only with the Shop alerts switch saved and on (review S100)", function()
			local Settings = require(Shared.Settings)
			local settings: any = Settings.defaults()
			expect(FreshCatch.alertsOn(settings)).to.equal(settings.shopAlerts == true)
			settings.shopAlerts = nil
			expect(FreshCatch.alertsOn(settings)).to.equal(false)
			settings.shopAlerts = false
			expect(FreshCatch.alertsOn(settings)).to.equal(false)
			settings.shopAlerts = true
			expect(FreshCatch.alertsOn(settings)).to.equal(true)
		end)

		it("comes up in about a third of windows", function()
			local count, alerting = 2000, 0
			for window = TODAY, TODAY + count - 1 do
				if #FreshCatch.alerts(window) > 0 then
					alerting += 1
				end
			end
			-- 1 - 0.75 x 0.9 = 0.325
			expect(alerting / count).to.be.near(0.325, 0.04)
		end)
	end)

	describe("saved state (save version 18)", function()
		it("starts fresh and sanitizes a damaged save", function()
			expect(FreshCatch.fresh() :: any).to.deepEqual({ window = 0, bought = {}, alerted = 0 })
			local now = 20 * 300 + 5 -- window 20
			expect(FreshCatch.sanitize(nil, now) :: any).to.deepEqual({
				window = 0,
				bought = {},
				alerted = 0,
			})
			expect(FreshCatch.sanitize({ window = -5, alerted = 0 / 0, bought = "x" }, now) :: any).to.deepEqual({
				window = 0,
				bought = {},
				alerted = 0,
			})
			-- a window or alert past the next window (a damaged or future-dated save) comes back to it (review N299)
			expect(FreshCatch.sanitize({ window = 99, alerted = 50, bought = {} }, now) :: any).to.deepEqual({
				window = 21,
				bought = {},
				alerted = 21,
			})
			expect(
				FreshCatch.sanitize(
					{ window = 12.5, alerted = 11, bought = { tip_potion = 9, nope = 1 } },
					now
				) :: any
			).to.deepEqual({
				window = 12,
				bought = { tip_potion = 3 },
				alerted = 11,
			})
		end)
	end)
end
