--!strict
-- Dealer.luau against data-model section 8b and rewards-and-shops.md section 4 (F94): each server rolls one stock at
-- dusk with its own Random, an amount of each dealer food from DealerAmountWeights (v0.8 F59), and it holds all
-- night. The 5 minute windows the dealer had from v0.5 F43 to F94 moved to the Fresh Catch shelf (FreshCatch.spec).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Dealer = require(Shared.Dealer)

	-- A roll function that hands out `values` in order, then 0.
	local function rolls(values: { number }): () -> number
		local n = 0
		return function()
			n += 1
			return values[n] or 0
		end
	end

	describe("one stock a night (F94)", function()
		it("rolls an amount of every dealer food in order, one roll each", function()
			local stock = Dealer.roll(rolls({ 0, 0.99, 0.2, 0.95 }))
			expect(#stock).to.equal(#Dealer.FOODS)
			for index, food in stock do
				expect(food.lureId).to.equal(Dealer.FOODS[index])
				local def = Catalog.getLure(food.lureId)
				expect(def).to.be.ok()
				expect((def :: any).source).to.equal("dealer")
			end
			-- #3011: sardines { 5, 15, 30, 30, 20 } at 0, caviar { 15, 35, 30, 15, 5 } at 0.99, moon milk
			-- { 25, 40, 25, 10 } at 0.2, star treat { 55, 35, 10 } at 0.95
			expect(stock[1].amount).to.equal(0)
			expect(stock[2].amount).to.equal(4)
			expect(stock[3].amount).to.equal(0)
			expect(stock[4].amount).to.equal(2)
		end)

		it("follows DealerAmountWeights over many nights", function()
			local counts: { [string]: { number } } = {}
			local nights = 6000
			local random = Random.new(94)
			local function nextNumber(): number
				return random:NextNumber()
			end
			for _ = 1, nights do
				for _, food in Dealer.roll(nextNumber) do
					local row = counts[food.lureId] or { 0, 0, 0, 0, 0 }
					row[food.amount + 1] += 1
					counts[food.lureId] = row
				end
			end
			for lureId, weights in Catalog.dealerAmountWeights do
				local row = counts[lureId]
				assert(row, lureId)
				for index, weight in weights do
					expect(row[index] / nights).to.be.near(weight / 100, 0.03)
				end
			end
		end)

		it("gives two servers their own nights", function()
			local a, b = Random.new(1), Random.new(2)
			local differs = 0
			for _ = 1, 20 do
				local first = Dealer.roll(function()
					return a:NextNumber()
				end)
				local second = Dealer.roll(function()
					return b:NextNumber()
				end)
				for index = 1, #Dealer.FOODS do
					if first[index].amount ~= second[index].amount then
						differs += 1
					end
				end
			end
			expect(differs > 10).to.equal(true)
		end)

		it("reads a food's amount from a stock, 0 for a food the dealer does not sell", function()
			local stock = Dealer.roll(rolls({ 0.99, 0.99, 0.99, 0.99 }))
			expect(Dealer.amountIn(stock, "sardines")).to.equal(4)
			expect(Dealer.amountIn(stock, "star_treat")).to.equal(2) -- #3011: up to 2 at once
			expect(Dealer.amountIn(stock, "kibble")).to.equal(0)
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

	-- #3011 (Derek2 2026-11-10: "buff how often night market stocks good items and amount"): after
	-- Config.DealerDryNights nights in a row with none of a food on one server, the next night stocks at least 1
	describe("no long dry spells (#3011)", function()
		local Config: any = require(Shared.Config)
		local function none(): number
			return 0 -- every food rolls 0
		end

		it("names the two top foods and how long each may be missing", function()
			expect(Config.DealerDryNights :: any).to.deepEqual({ star_treat = 4, moon_milk = 3 })
			for lureId in Config.DealerDryNights do
				expect(Catalog.dealerAmountWeights[lureId]).to.be.ok()
			end
		end)

		it("counts a night without the food and starts again on a night with it", function()
			local dry = Dealer.dryAfter(nil, Dealer.roll(none))
			expect(dry :: any).to.deepEqual({ star_treat = 1, moon_milk = 1 })
			dry = Dealer.dryAfter(dry, Dealer.roll(none))
			expect(dry :: any).to.deepEqual({ star_treat = 2, moon_milk = 2 })
			-- a night with Moon Milk and no Star Treat
			dry = Dealer.dryAfter(dry, Dealer.roll(rolls({ 0, 0, 0.5, 0 })))
			expect(dry :: any).to.deepEqual({ star_treat = 3, moon_milk = 0 })
			-- the old table is left alone, and sardines and caviar are never counted
			local before = { star_treat = 1, moon_milk = 2 }
			Dealer.dryAfter(before, Dealer.roll(none))
			expect(before :: any).to.deepEqual({ star_treat = 1, moon_milk = 2 })
		end)

		it("stocks 1 the night after the limit, and only then", function()
			-- one night short of each limit: still nothing
			local short = Dealer.roll(none, { star_treat = 3, moon_milk = 2 })
			expect(Dealer.amountIn(short, "star_treat")).to.equal(0)
			expect(Dealer.amountIn(short, "moon_milk")).to.equal(0)
			-- at the limit: at least 1 of each, the others as rolled
			local forced = Dealer.roll(none, { star_treat = 4, moon_milk = 3 })
			expect(Dealer.amountIn(forced, "star_treat")).to.equal(1)
			expect(Dealer.amountIn(forced, "moon_milk")).to.equal(1)
			expect(Dealer.amountIn(forced, "sardines")).to.equal(0)
			expect(Dealer.amountIn(forced, "caviar")).to.equal(0)
			-- a real roll is never cut down to 1
			local lucky =
				Dealer.roll(rolls({ 0, 0, 0.95, 0.95 }), { star_treat = 9, moon_milk = 9 })
			expect(Dealer.amountIn(lucky, "star_treat")).to.equal(2)
			expect(Dealer.amountIn(lucky, "moon_milk")).to.equal(3)
			-- no count (a caller that keeps none) is the plain roll
			expect(Dealer.amountIn(Dealer.roll(none), "star_treat")).to.equal(0)
		end)

		it(
			"never goes 5 nights without a Star Treat or 4 without Moon Milk in 1,000 nights, on 20 servers",
			function()
				for seed = 1, 20 do
					local random = Random.new(3011 + seed)
					local dry: any = nil
					local run: { [string]: number } = { star_treat = 0, moon_milk = 0 }
					local longest: { [string]: number } = { star_treat = 0, moon_milk = 0 }
					local forced = 0
					for _ = 1, 1000 do
						local before = dry
						local stock = Dealer.roll(function()
							return random:NextNumber()
						end, dry)
						dry = Dealer.dryAfter(dry, stock)
						for lureId, limit in Config.DealerDryNights do
							if Dealer.amountIn(stock, lureId) == 0 then
								run[lureId] += 1
								longest[lureId] = math.max(longest[lureId], run[lureId])
							else
								if before ~= nil and (before[lureId] or 0) >= limit then
									forced += 1
								end
								run[lureId] = 0
							end
						end
					end
					expect(longest.star_treat <= 4).to.equal(true)
					expect(longest.moon_milk <= 3).to.equal(true)
					-- the rule is a backstop, not the main source: under one night in ten
					expect(forced < 100).to.equal(true)
				end
			end
		)
	end)

	describe("dealer amounts edges (QA, F59)", function()
		it(
			"the weights match the design: 0 to 4 of each, out of 100, Sardines most and Star Treat least",
			function()
				local means =
					{ sardines = 2.45, caviar = 1.60, moon_milk = 1.20, star_treat = 0.55 } -- #3011
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
			end
		)

		it("never rolls an amount with no weight, whatever the roll", function()
			for step = 0, 1000 do
				local roll = step / 1000
				local function always(): number
					return roll
				end
				for _, food in Dealer.roll(always) do
					local weights = Catalog.dealerAmountWeights[food.lureId]
					if weights[food.amount + 1] == 0 then
						error(
							string.format(
								"roll %.3f gave %d %s, a zero weight",
								roll,
								food.amount,
								food.lureId
							)
						)
					end
				end
			end
		end)
	end)
	describe("Buy all (#2573)", function()
		local function row(lureId: string, cost: number, amount: number, bought: number): any
			return { lureId = lureId, cost = cost, amount = amount, bought = bought }
		end
		-- the dealer's rows in their order: Rare, Epic, Legendary, Mythical
		local function stock(): { any }
			return {
				row("sardines", 100, 3, 1),
				row("caviar", 500, 2, 0),
				row("moon_milk", 1000, 1, 0),
				row("star_treat", 3000, 1, 0),
			}
		end

		it("buys everything left when it all fits, best grade first", function()
			local plan, total = Dealer.planAll(stock(), 10000)
			expect(plan :: any).to.deepEqual({
				{ lureId = "star_treat", count = 1 },
				{ lureId = "moon_milk", count = 1 },
				{ lureId = "caviar", count = 2 },
				{ lureId = "sardines", count = 2 },
			})
			expect(total).to.equal(3000 + 1000 + 1000 + 200)
		end)

		it("buys what fits, passing a food it can't afford for a cheaper one", function()
			-- 1,750: no Star Treat (3,000), the Moon Milk (1,000), one Caviar (500), two Sardines (200)
			local plan, total = Dealer.planAll(stock(), 1750)
			expect(plan :: any).to.deepEqual({
				{ lureId = "moon_milk", count = 1 },
				{ lureId = "caviar", count = 1 },
				{ lureId = "sardines", count = 2 },
			})
			expect(total).to.equal(1700)
			local none, nothing = Dealer.planAll(stock(), 99)
			expect(#none).to.equal(0)
			expect(nothing).to.equal(0)
			expect(#Dealer.planAll(stock(), -5)).to.equal(0)
		end)

		it("keeps to row order within a grade and skips sold out, free and unknown rows", function()
			local plan = Dealer.planAll({
				row("sardines", 100, 2, 2), -- bought out
				row("unknown_food", 10, 5, 0),
				row("caviar", 0, 3, 0), -- no price
				row("star_treat", 3000, 1, 0),
			}, 5000)
			expect(plan :: any).to.deepEqual({ { lureId = "star_treat", count = 1 } })
			expect(#Dealer.planAll({}, 1000)).to.equal(0)
			-- the grade comes from the Catalog
			expect((Catalog.getLure("star_treat") :: any).rarity).to.equal("Mythical")
			expect((Catalog.getLure("sardines") :: any).rarity).to.equal("Rare")
		end)
	end)
end
