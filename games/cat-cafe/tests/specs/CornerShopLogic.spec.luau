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
		family = "snack",
		size = "regular",
		kind = "food",
		foodId = "cat_snack",
		price = 1500,
		xp = 1200,
	}

	describe("CornerShopLogic", function()
		it("counts down to the restock in m:ss", function()
			expect(Logic.clock(1192, 1000)).to.equal("Restocks in 3:12")
			expect(Logic.clock(900, 1000)).to.equal("Restocks in 0:00")
		end)
		it("says how often a row is in stock from the weights", function()
			-- by size (corner-shop-v2.md section 1): small {0,..}, regular 20 of 100 none, big 70, mega 90
			expect(Logic.chance("swift_potion_small")).to.equal("Always in stock")
			expect(Logic.chance("cat_snack")).to.equal("In stock 8 times in 10")
			expect(Logic.chance("big_cat_snack")).to.equal("In stock 3 times in 10")
			expect(Logic.chance("cat_feast")).to.equal("In stock 1 time in 10")
			expect(Logic.effect(snack)).to.equal("+1,200 XP cat food, into your Bag")
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
			expect(Logic.button(item, snack, 9000, 1000).text).to.equal("Food full")
			expect(
				Logic.button({ itemId = "x", price = 1, amount = 1, bought = 1 }, nil, 9, 0).text
			).to.equal("Sold out")
			expect(
				Logic.button({ itemId = "x", price = 1, amount = 0, bought = 0 }, nil, 9, 0).text
			).to.equal("None")
		end)
		it(
			"gates a row by tier and leaves the daily limit to the server (corner-shop-v2.md, #1190)",
			function()
				local big = {
					itemId = "swift_potion_big",
					price = 9,
					amount = 2,
					bought = 0,
					needsTier = 3,
					today = 0,
				}
				expect(Logic.gate(big, 2)).to.equal("Opens at Tier 3")
				expect(Logic.gate(big, 3)).to.equal(nil)
				expect(Logic.button(big, nil, 100, 0, 2).text).to.equal("Tier 3")
				expect(Logic.button(big, nil, 100, 0, 2).enabled).to.equal(false)
				expect(Logic.button(big, nil, 100, 0, 3).enabled).to.equal(true)
				-- #1190: no daily-limit words or grey state; the server's toast says it
				local quick = {
					itemId = "quick_bait_potion",
					price = 9,
					amount = 3,
					bought = 0,
					today = 2,
					perDay = 2,
				}
				expect(Logic.button(quick, nil, 100, 0, 5).enabled).to.equal(true)
				expect(Logic.todayLine).to.equal(nil)
			end
		)
		it("says the cat food XP left today", function()
			expect(Logic.snackLine(4800)).to.equal("Cat food today: 4,800 / 20,000 XP")
			expect(Logic.snackRoom(19000)).to.equal(1000)
			expect(Logic.snackRoom(21000)).to.equal(0)
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
