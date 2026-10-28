--!strict
-- Dealer.luau against data-model section 8b: the night dealer's stock, shared by every player on every server in
-- the same window since v0.5 F43, an amount of each dealer food from DealerAmountWeights since v0.8 F59, with bought
-- counts cleared only when the window moves forward (reviewer N32).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Dealer = require(Shared.Dealer)

	describe("windows", function()
		it("are DealerWindowSeconds long and restock at the next one", function()
			local w = Config.DealerWindowSeconds
			expect(Dealer.window(0)).to.equal(0)
			expect(Dealer.window(w - 1)).to.equal(0)
			expect(Dealer.window(w)).to.equal(1)
			expect(Dealer.restocksAt(Dealer.window(w * 5 + 30))).to.equal(w * 6)
		end)
	end)

	describe("stock", function()
		it("is the same amount of every dealer food for everyone in a window (F59)", function()
			local first = Dealer.stock(2900000)
			local again = Dealer.stock(2900000)
			expect(#first).to.equal(#Dealer.FOODS)
			for index, food in first do
				expect(food.lureId).to.equal(Dealer.FOODS[index])
				expect(food.amount).to.equal(again[index].amount)
				expect(food.amount >= 0 and food.amount <= 4).to.equal(true)
				local def = Catalog.getLure(food.lureId)
				expect(def).to.be.ok()
				expect((def :: any).source).to.equal("dealer")
				expect(Dealer.amountOf(2900000, food.lureId)).to.equal(food.amount)
			end
			expect(Dealer.amountOf(2900000, "kibble")).to.equal(0)
		end)

		it("changes from window to window", function()
			local differs = 0
			for window = 2900000, 2900019 do
				local a, b = Dealer.stock(window), Dealer.stock(window + 1)
				for index = 1, #Dealer.FOODS do
					if a[index].amount ~= b[index].amount then
						differs += 1
					end
				end
			end
			expect(differs > 20).to.equal(true)
		end)

		it("follows DealerAmountWeights over many windows", function()
			local counts: { [string]: { number } } = {}
			local windows = 6000
			for window = 1, windows do
				for _, food in Dealer.stock(2900000 + window * 7) do
					local row = counts[food.lureId] or { 0, 0, 0, 0, 0 }
					row[food.amount + 1] += 1
					counts[food.lureId] = row
				end
			end
			for lureId, weights in Catalog.dealerAmountWeights do
				local row = counts[lureId]
				assert(row, lureId)
				for index, weight in weights do
					expect(row[index] / windows).to.be.near(weight / 100, 0.03)
				end
			end
		end)

		it("rolls each window afresh: a food matches the window before about as often as chance (QA)", function()
			-- with fresh rolls, the chance a food's amount equals the one `lag` windows before is the sum of the
			-- squared weights (Moon Milk 0.6^2 + 0.35^2 + 0.05^2 = 0.485), at every lag
			local count = 70 * 288 -- 70 days of windows from 2026-10-28 (window 5977152)
			local amounts: { [string]: { number } } = {}
			for window = 5977152, 5977152 + count - 1 do
				for _, food in Dealer.stock(window) do
					local list = amounts[food.lureId] or {}
					table.insert(list, food.amount)
					amounts[food.lureId] = list
				end
			end
			for _, lureId in Dealer.FOODS do
				local chance = 0
				for _, weight in Catalog.dealerAmountWeights[lureId] do
					chance += (weight / 100) ^ 2
				end
				local list = amounts[lureId]
				for lag = 1, 12 do
					local same = 0
					for index = lag + 1, count do
						if list[index] == list[index - lag] then
							same += 1
						end
					end
					local share = same / (count - lag)
					if math.abs(share - chance) > 0.03 then
						error(
							string.format(
								"%s matches the window %d before %.3f of the time, chance is %.3f",
								lureId,
								lag,
								share,
								chance
							)
						)
					end
				end
			end
		end)

		it("pickAmount walks the weights from 0 and clamps the roll", function()
			local weights = { 1, 1, 0, 2 }
			expect(Dealer.pickAmount(weights, 0)).to.equal(0)
			expect(Dealer.pickAmount(weights, 0.3)).to.equal(1)
			expect(Dealer.pickAmount(weights, 0.6)).to.equal(3)
			expect(Dealer.pickAmount(weights, 1)).to.equal(3)
			expect(Dealer.pickAmount(weights, -2)).to.equal(0)
			expect(Dealer.pickAmount({ 90, 10, 0, 0, 0 }, 0.95)).to.equal(1)
		end)
	end)

	describe("refresh", function()
		it("clears the bought marks only when the window moves forward", function()
			local state = { window = 10, bought = { caviar = 2 } }
			Dealer.refresh(state, 10)
			expect(state.bought.caviar).to.equal(2)
			Dealer.refresh(state, 9) -- another server a second behind at the edge
			expect(state.window).to.equal(10)
			expect(state.bought.caviar).to.equal(2)
			Dealer.refresh(state, 11)
			expect(state.window).to.equal(11)
			expect(state.bought.caviar).never.to.be.ok()
		end)

		it("counts every food as bought out while the window is behind the saved one (N32)", function()
			local state = { window = 10, bought = {} }
			Dealer.refresh(state, 9)
			expect(Dealer.behind(state, 9)).to.equal(true)
			expect(Dealer.behind(state, 10)).to.equal(false)
			Dealer.refresh(state, 11)
			expect(Dealer.behind(state, 11)).to.equal(false)
		end)
	end)

	describe("dealer amounts edges (QA, F59)", function()
		-- the real windows from 2026-10-28 00:00 UTC for 70 days, 288 a day
		local TODAY = Dealer.window(1793145600)
		local DAYS = 70

		it("the weights match the design: 0 to 4 of each, out of 100, Sardines most and Star Treat least", function()
			local means = { sardines = 1.85, caviar = 0.95, moon_milk = 0.45, star_treat = 0.10 }
			for _, lureId in Dealer.FOODS do
				local weights = Catalog.dealerAmountWeights[lureId]
				assert(weights, lureId)
				expect(#weights).to.equal(5)
				local total, mean = 0, 0
				for index, weight in weights do
					expect(weight >= 0).to.equal(true)
					total += weight
					mean += (index - 1) * weight / 100
				end
				expect(total).to.equal(100)
				expect(mean).to.be.near(means[lureId], 1e-9)
				expect(weights[1] < 100).to.equal(true) -- every food can come up
			end
		end)

		it("never rolls an amount with no weight over the next 70 days of windows", function()
			for window = TODAY, TODAY + DAYS * 288 - 1 do
				for _, food in Dealer.stock(window) do
					local weights = Catalog.dealerAmountWeights[food.lureId]
					if weights[food.amount + 1] == 0 then
						error(string.format("window %d rolled %d %s, a zero weight", window, food.amount, food.lureId))
					end
				end
			end
		end)
	end)
end
