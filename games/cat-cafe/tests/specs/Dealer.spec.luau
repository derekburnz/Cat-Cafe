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
			local stock = Dealer.roll(rolls({ 0, 0.99, 0.4, 0.95 }))
			expect(#stock).to.equal(#Dealer.FOODS)
			for index, food in stock do
				expect(food.lureId).to.equal(Dealer.FOODS[index])
				local def = Catalog.getLure(food.lureId)
				expect(def).to.be.ok()
				expect((def :: any).source).to.equal("dealer")
			end
			-- sardines { 15, 25, 30, 20, 10 } at 0, caviar { 35, 40, 20, 5, 0 } at 0.99, moon milk { 45, 45, 10 } at
			-- 0.4, star treat { 80, 20 } at 0.95 (#1442)
			expect(stock[1].amount).to.equal(0)
			expect(stock[2].amount).to.equal(3)
			expect(stock[3].amount).to.equal(0)
			expect(stock[4].amount).to.equal(1)
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
			expect(Dealer.amountIn(stock, "star_treat")).to.equal(1)
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

	describe("dealer amounts edges (QA, F59)", function()
		it("the weights match the design: 0 to 4 of each, out of 100, Sardines most and Star Treat least", function()
			local means = { sardines = 1.85, caviar = 0.95, moon_milk = 0.65, star_treat = 0.20 } -- #1442
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

		it("never rolls an amount with no weight, whatever the roll", function()
			for step = 0, 1000 do
				local roll = step / 1000
				local function always(): number
					return roll
				end
				for _, food in Dealer.roll(always) do
					local weights = Catalog.dealerAmountWeights[food.lureId]
					if weights[food.amount + 1] == 0 then
						error(string.format("roll %.3f gave %d %s, a zero weight", roll, food.amount, food.lureId))
					end
				end
			end
		end)
	end)
end
