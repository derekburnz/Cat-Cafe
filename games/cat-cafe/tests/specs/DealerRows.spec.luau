--!strict
-- UI/Components/DealerRows.luau: the night dealer's stock as shop rows (data-model section 8b v0.8, F59).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local DealerRows = require(Components:WaitForChild("DealerRows")) :: any
	local Catalog = require(
		game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Catalog")
	) :: any

	local lureById = Catalog.luresById

	describe("DealerRows.normalize", function()
		it("keeps F59's amounts and buys in the server's order, with the window", function()
			local stock = DealerRows.normalize({
				window = 5912,
				restocksAt = 100,
				stock = {
					{ lureId = "sardines", cost = 1000, amount = 3, bought = 1 },
					{ lureId = "caviar", cost = 3000, amount = 0, bought = 0 },
					{ lureId = "moon_milk", cost = 10000, amount = 1, bought = 1 },
					{ lureId = "star_treat", cost = 40000, amount = 0, bought = 0 },
				},
			})
			expect(stock.window).to.equal(5912)
			expect(stock.restocksAt).to.equal(100)
			expect(#stock.stock).to.equal(4)
			expect(stock.stock[1].amount).to.equal(3)
			expect(stock.stock[1].bought).to.equal(1)
			expect(stock.stock[2].lureId).to.equal("caviar")
			expect(stock.stock[4].lureId).to.equal("star_treat")
		end)

		it("reads the pre-F59 slots as amounts, so either shape works", function()
			local stock = DealerRows.normalize({
				slots = {
					{ lureId = "sardines", cost = 800, bought = true },
					{ lureId = "caviar", cost = 3000, bought = false },
					{ lureId = "sardines", cost = 800, bought = false },
				},
				restocksAt = 0,
			})
			expect(stock.window).to.equal(nil)
			expect(#stock.stock).to.equal(2)
			expect(stock.stock[1].lureId).to.equal("sardines")
			expect(stock.stock[1].amount).to.equal(2)
			expect(stock.stock[1].bought).to.equal(1)
			expect(stock.stock[2].amount).to.equal(1)
			expect(stock.stock[2].bought).to.equal(0)
		end)

		it("drops broken entries and reads bad counts as 0", function()
			local stock = DealerRows.normalize({
				restocksAt = 0,
				stock = {
					{ lureId = "sardines", cost = 1000, amount = 0 / 0, bought = -2 },
					{ lureId = 7, cost = 1000, amount = 1, bought = 0 },
					"caviar",
					{ lureId = "caviar", cost = 3000, amount = 2.7, bought = "1" },
				},
			})
			expect(#stock.stock).to.equal(2)
			expect(stock.stock[1].amount).to.equal(0)
			expect(stock.stock[1].bought).to.equal(0)
			expect(stock.stock[2].amount).to.equal(2)
			expect(stock.stock[2].bought).to.equal(0)
			expect(DealerRows.normalize(nil)).to.equal(nil)
			expect(DealerRows.normalize({ stock = {} })).to.equal(nil)
			expect(DealerRows.normalize({ restocksAt = 0 })).to.equal(nil)
		end)
	end)

	describe("DealerRows.group", function()
		it("gives every food a row with what is left, a 0 amount included", function()
			local rows = DealerRows.group({
				window = 1,
				restocksAt = 0,
				stock = {
					{ lureId = "sardines", cost = 1000, amount = 2, bought = 0 },
					{ lureId = "caviar", cost = 2500, amount = 0, bought = 0 },
					{ lureId = "moon_milk", cost = 10000, amount = 1, bought = 1 },
				},
			}, lureById)
			expect(#rows).to.equal(3)
			expect(rows[1].left).to.equal(2)
			expect(rows[2].amount).to.equal(0)
			expect(rows[2].left).to.equal(0)
			expect(rows[2].cost).to.equal(2500)
			expect(rows[3].left).to.equal(0)
		end)

		it("skips foods the catalog does not know and never goes below 0 left", function()
			local rows = DealerRows.group({
				restocksAt = 0,
				stock = {
					{ lureId = "mystery", cost = 1, amount = 4, bought = 0 },
					{ lureId = "star_treat", cost = 40000, amount = 1, bought = 3 },
				},
			}, lureById)
			expect(#rows).to.equal(1)
			expect(rows[1].lureId).to.equal("star_treat")
			expect(rows[1].left).to.equal(0)
		end)
	end)

	describe("DealerRows.amountOdds", function()
		it("lists the chance of each amount, leaving out the impossible ones", function()
			expect(DealerRows.amountOdds({ 15, 25, 30, 20, 10 })).to.equal(
				"Stock odds: 0 (15%) · 1 (25%) · 2 (30%) · 3 (20%) · 4 (10%)"
			)
			expect(DealerRows.amountOdds({ 90, 10, 0, 0, 0 })).to.equal("Stock odds: 0 (90%) · 1 (10%)")
			expect(DealerRows.amountOdds({ 60, 32.5, 7.5 })).to.equal("Stock odds: 0 (60%) · 1 (32.5%) · 2 (7.5%)")
			expect(DealerRows.amountOdds(nil)).to.equal(nil)
			expect(DealerRows.amountOdds({})).to.equal(nil)
		end)

		it("adds up to 100 for every dealer food in the catalog", function()
			local weights = Catalog.dealerAmountWeights
			expect(weights).to.be.ok()
			for lureId, row in weights do
				local sum = 0
				for _, weight in row do
					sum += weight
				end
				expect(sum).to.be.near(100, 1e-9)
				expect(DealerRows.amountOdds(row)).to.be.ok()
				expect(lureById[lureId]).to.be.ok()
			end
		end)
	end)

	describe("DealerRows.clock", function()
		it("counts minutes and seconds and stops at zero", function()
			expect(DealerRows.clock(252)).to.equal("4:12")
			expect(DealerRows.clock(59.2)).to.equal("1:00")
			expect(DealerRows.clock(5)).to.equal("0:05")
			expect(DealerRows.clock(-3)).to.equal("0:00")
		end)
	end)
end
