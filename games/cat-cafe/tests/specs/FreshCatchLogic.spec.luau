--!strict
-- UI/Components/FreshCatchLogic.luau: the Fresh Catch tab's and chalkboard's sums (F94, rewards-and-shops.md
-- section 3).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local FreshCatchLogic =
		require(Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("FreshCatchLogic")) :: any

	local function sample()
		return {
			window = 5900000,
			restocksAt = 1770000300,
			stock = {
				{ itemId = "tip_potion", fish = 10, amount = 2, bought = 1 },
				{ itemId = "swift_potion", fish = 6, amount = 0, bought = 0 },
				{ itemId = "gold_rush_potion", fish = 30, amount = 1, bought = 1 },
			},
		}
	end

	describe("FreshCatchLogic.normalize", function()
		it("keeps a good stock and drops bad rows", function()
			local raw = sample() :: any
			table.insert(raw.stock, { itemId = 7, fish = 1, amount = 1, bought = 0 })
			table.insert(raw.stock, { itemId = "lucky_potion", fish = 0 / 0, amount = 1, bought = 0 })
			table.insert(raw.stock, "junk")
			local stock = FreshCatchLogic.normalize(raw)
			expect(stock).to.be.ok()
			expect(#stock.stock).to.equal(3)
			expect(stock.window).to.equal(5900000)
			expect(stock.stock[1].itemId).to.equal("tip_potion")
		end)

		it("reads nil and junk as no stock (night)", function()
			expect(FreshCatchLogic.normalize(nil)).to.equal(nil)
			expect(FreshCatchLogic.normalize("closed")).to.equal(nil)
			expect(FreshCatchLogic.normalize({ window = 1 })).to.equal(nil)
		end)

		it("never lets amounts or bought go negative", function()
			local stock = FreshCatchLogic.normalize({
				window = 1,
				restocksAt = 300,
				stock = { { itemId = "tip_potion", fish = 10, amount = -3, bought = -1 } },
			})
			expect(stock.stock[1].amount).to.equal(0)
			expect(stock.stock[1].bought).to.equal(0)
		end)
	end)

	describe("FreshCatchLogic.left", function()
		it("counts what this player can still buy", function()
			local stock = FreshCatchLogic.normalize(sample())
			expect(FreshCatchLogic.left(stock.stock[1])).to.equal(1)
			expect(FreshCatchLogic.left(stock.stock[2])).to.equal(0)
			expect(FreshCatchLogic.left(stock.stock[3])).to.equal(0)
		end)
	end)

	describe("FreshCatchLogic chances", function()
		it("reads the share of windows with at least one", function()
			expect(FreshCatchLogic.inStock({ 10, 30, 40, 20 })).to.be.near(0.9, 1e-9)
			expect(FreshCatchLogic.inStock({ 75, 25, 0, 0 })).to.be.near(0.25, 1e-9)
			expect(FreshCatchLogic.inStock({ 90, 10, 0, 0 })).to.be.near(0.1, 1e-9)
			expect(FreshCatchLogic.inStock(nil)).to.equal(nil)
			expect(FreshCatchLogic.inStock({})).to.equal(nil)
		end)

		it("says it in words a child reads", function()
			expect(FreshCatchLogic.chanceText(0.9)).to.equal("In stock 9 times in 10")
			expect(FreshCatchLogic.chanceText(0.4)).to.equal("In stock 4 times in 10")
			expect(FreshCatchLogic.chanceText(0.25)).to.equal("In stock 1 time in 4")
			expect(FreshCatchLogic.chanceText(0.1)).to.equal("In stock 1 time in 10")
			expect(FreshCatchLogic.chanceText(0.05)).to.equal("In stock 1 time in 20")
			expect(FreshCatchLogic.chanceText(1)).to.equal("Always in stock")
			expect(FreshCatchLogic.chanceText(nil)).to.equal(nil)
		end)
	end)

	describe("FreshCatchLogic.countdown", function()
		it("counts down to the next window", function()
			expect(FreshCatchLogic.countdown(192)).to.equal("Fresh catch in 3:12")
			expect(FreshCatchLogic.countdown(0.2)).to.equal("Fresh catch in 0:01")
			expect(FreshCatchLogic.countdown(-5)).to.equal("Fresh catch in 0:00")
		end)
	end)

	describe("FreshCatchLogic.board", function()
		it("lists only what the window stocks, with the amount and price", function()
			local stock = FreshCatchLogic.normalize(sample())
			local lines = FreshCatchLogic.board(stock, function(id: string): string
				return id:upper()
			end)
			expect(#lines).to.equal(2)
			expect(lines[1].name).to.equal("TIP_POTION")
			expect(lines[1].amount).to.equal(2)
			expect(lines[2].itemId).to.equal("gold_rush_potion")
			expect(lines[2].fish).to.equal(30)
		end)

		it("is empty at night", function()
			expect(#FreshCatchLogic.board(nil, tostring)).to.equal(0)
		end)
	end)
end
