--!strict
-- UI/Components/CornerShopLogic.luau: the Corner Shop window's words and rules (#1052, corner-shop.md section 4).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local Logic = require(Components:WaitForChild("CornerShopLogic")) :: any

	local snack = {
		id = "cat_snack",
		name = "Cat Snack",
		kind = "snack",
		xp = 1200,
		seconds = 300,
		atLeast = 500,
	}

	describe("CornerShopLogic", function()
		it("counts down to the restock in m:ss", function()
			expect(Logic.clock(1192, 1000)).to.equal("Restocks in 3:12")
			expect(Logic.clock(900, 1000)).to.equal("Restocks in 0:00")
		end)
		it("says how often a row is in stock from the weights", function()
			expect(Logic.chance("swift_potion")).to.equal("Always in stock")
			expect(Logic.chance("cat_snack")).to.equal("In stock 9 times in 10")
			expect(Logic.chance("big_cat_snack")).to.equal("In stock 4 times in 10")
			expect(Logic.chance("nothing")).to.equal("")
		end)
		it("words the stock line", function()
			expect(Logic.stockLine({ itemId = "x", price = 1, amount = 0, bought = 0 })).to.equal(
				"None this time"
			)
			expect(Logic.stockLine({ itemId = "x", price = 1, amount = 3, bought = 1 })).to.equal(
				"x2 left"
			)
			expect(Logic.stockLine({ itemId = "x", price = 1, amount = 2, bought = 2 })).to.equal(
				"You bought 2"
			)
		end)
		it("greys the button the server would refuse", function()
			local item = { itemId = "cat_snack", price = 1500, amount = 2, bought = 0 }
			local ok = Logic.button(item, snack, 2000, 12000)
			expect(ok.text).to.equal("Buy · $1,500")
			expect(ok.enabled).to.equal(true)
			expect(Logic.button(item, snack, 1000, 12000).enabled).to.equal(false)
			expect(Logic.button(item, snack, 9000, 1000).text).to.equal("Snacks full")
			expect(
				Logic.button({ itemId = "x", price = 1, amount = 1, bought = 1 }, nil, 9, 0).text
			).to.equal("Sold out")
			expect(
				Logic.button({ itemId = "x", price = 1, amount = 0, bought = 0 }, nil, 9, 0).text
			).to.equal("None")
		end)
		it("says the snack XP left today", function()
			expect(Logic.snackLine(4800)).to.equal("Snacks today: 4,800 / 12,000 XP")
			expect(Logic.snackRoom(11000)).to.equal(1000)
			expect(Logic.snackRoom(13000)).to.equal(0)
		end)
		it("lists the cats highest level first", function()
			local cats = Logic.catsByLevel({
				a = { catId = "tabby", level = 3 },
				b = { catId = "tuxedo", level = 9, name = "Mittens" },
				c = { catId = "ginger" },
			}, { tabby = "Tabby", ginger = "Ginger" })
			expect(cats[1].uid).to.equal("b")
			expect(cats[1].name).to.equal("Mittens")
			expect(cats[2].uid).to.equal("a")
			expect(cats[3].level).to.equal(1)
		end)
	end)
end
