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
		it(
			"says how often a row is in stock from its place by price (#1577, day-cart.md)",
			function()
				local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
				local Catalog = require(Shared:WaitForChild("Catalog")) :: any
				local CornerShop = require(Shared:WaitForChild("CornerShop")) :: any
				local order = CornerShop.listOrder()
				local cheapest = Catalog.cornerShop[order[1]].id
				local second = Catalog.cornerShop[order[2]].id
				local dearest = Catalog.cornerShop[order[#order]].id
				expect(Logic.chance(cheapest)).to.equal("In stock 95% of days")
				expect(Logic.chance(second)).to.equal("In stock 90.5% of days")
				-- 95% less 4.5% a place reaches the 5% floor by the 21st place
				local floor = if #order >= 21 then "In stock 5% of days" else nil
				if floor then
					expect(Logic.chance(dearest)).to.equal(floor)
				end
				expect(Logic.effect(snack)).to.equal("+1,200 XP cat food, into your Bag")
				-- #1281: a bait food row says how many the player has
				local tuna = {
					id = "tuna",
					name = "Tuna",
					family = "bait",
					size = "regular",
					kind = "bait",
					price = 500,
				}
				expect(Logic.effect(tuna, 3)).to.equal("Bait for your bowl · You have 3")
				expect(Logic.effect(tuna)).to.equal("Bait for your bowl · You have 0")
				expect(Logic.chance("nothing")).to.equal("")
			end
		)
		it("shows the Day Cart's name and help line (#1577)", function()
			expect(Logic.TITLE).to.equal("Day Cart")
			expect(Logic.HELP).to.equal(
				"Coins only. New stock at sunrise. The same cart for everyone."
			)
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
		it("greys a row whose family hit its daily limit as Back tomorrow (#1435)", function()
			local out: any = { itemId = "x", price = 1, amount = 3, bought = 0, outToday = true }
			local view = Logic.button(out, nil, 9, 0)
			expect(view.text).to.equal("Back tomorrow")
			expect(view.enabled).to.equal(false)
			-- the window's own stock still reads first
			out.bought = 3
			expect(Logic.button(out, nil, 9, 0).text).to.equal("Sold out")
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
		it("shows no cat food line and never fills, with no daily cap (#1255)", function()
			expect(Logic.snackLine(4800)).to.equal("")
			expect(Logic.snackRoom(500000)).to.equal(math.huge)
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
