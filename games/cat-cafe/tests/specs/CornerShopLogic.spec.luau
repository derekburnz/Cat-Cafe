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
				expect(Logic.chance(cheapest)).to.equal("In stock 100% of days")
				expect(Logic.chance(second)).to.equal("In stock 97% of days")
				-- #1740: 100% less 3% a place reaches the 25% floor by the 26th place
				local floor = if #order >= 26 then "In stock 25% of days" else nil
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
		it("shows the Day Cart's name (#1577) and no help line (#1688)", function()
			expect(Logic.TITLE).to.equal("Day Cart")
			expect((Logic :: any).HELP).to.equal(nil)
		end)
		it("words the stock line", function()
			-- #1678: no "None this time" or "You bought 2", the button says None or Sold out
			expect(Logic.stockLine({ itemId = "x", price = 1, amount = 0, bought = 0 })).to.equal(
				""
			)
			expect(Logic.stockLine({ itemId = "x", price = 1, amount = 3, bought = 1 })).to.equal(
				"x2 left"
			)
			expect(Logic.stockLine({ itemId = "x", price = 1, amount = 2, bought = 2 })).to.equal(
				""
			)
			-- #1671: past the daily limit, no "x3 left" beside "Back at sunrise"
			local out: any = { itemId = "x", price = 1, amount = 3, bought = 0, outToday = true }
			expect(Logic.stockLine(out)).to.equal("")
			expect(Logic.button(out, nil, 1000, 0, nil).text).to.equal("Back at sunrise")
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
		it("greys a row whose family hit its limit as Back at sunrise (#1435, #1631)", function()
			local out: any = { itemId = "x", price = 1, amount = 3, bought = 0, outToday = true }
			local view = Logic.button(out, nil, 9, 0)
			expect(view.text).to.equal("Back at sunrise")
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

		it(
			"groups the stock under Potions, Cat food and Bait in the stock's order (#1599)",
			function()
				local function item(id: string): any
					return { itemId = id, price = 100, amount = 1, bought = 0 }
				end
				local sections = Logic.sections({
					item("swift_potion"),
					item("cat_snack"),
					item("kibble"),
					item("steady_potion"),
					item("mystery"),
					item("tuna"),
				})
				expect(#sections).to.equal(4)
				expect(sections[1].title).to.equal("Potions")
				expect(table.concat(sections[1].indexes, ",")).to.equal("1,4")
				expect(sections[2].title).to.equal("Cat food")
				expect(table.concat(sections[2].indexes, ",")).to.equal("2")
				expect(sections[3].title).to.equal("Bait")
				expect(table.concat(sections[3].indexes, ",")).to.equal("3,6")
				expect(sections[4].title).to.equal("More")
				expect(table.concat(sections[4].indexes, ",")).to.equal("5")
				expect(#Logic.sections({})).to.equal(0)
			end
		)
	end)

	describe("CornerShopLogic.buyAll (#2593)", function()
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		local CornerShop = require(Shared:WaitForChild("CornerShop")) :: any
		local Catalog = require(Shared:WaitForChild("Catalog")) :: any
		local NONE = { catFood = {}, lures = {} }
		local function windowFor(kind: string, rows: number): number
			for window = 5000, 10000 do
				local n = 0
				for _, item in CornerShop.stock(window) do
					local row = Catalog.getCornerShopRow(item.itemId)
					if row.kind == kind and item.amount > 0 then
						n += 1
					end
				end
				if n >= rows then
					return window
				end
			end
			error("no window")
		end
		local function state(window: number): any
			return { window = window, bought = {}, day = 0, today = {}, foodXpToday = 0 }
		end

		it(
			"plans from the shown stock exactly as the server's planAll on the same state",
			function()
				for _, kind in { "potion", "food", "bait" } do
					local window = windowFor(kind, 2)
					local view = CornerShop.view(state(window), window, 5)
					local plan = Logic.buyAll(view, kind, 5, 1e12, NONE)
					local server, total =
						CornerShop.planAll(state(window), window, kind, 5, 1e12, NONE)
					local count = 0
					for _, item in server do
						count += item.count
					end
					expect(plan.count).to.equal(count)
					expect(plan.total).to.equal(total)
					expect(plan.partial).to.equal(nil)
					expect(string.find(plan.list, "^%d+ ")).to.be.ok()
				end
			end
		)

		it("says how many fit when coins run short, and is nil when none do", function()
			local window = windowFor("potion", 2)
			local view = CornerShop.view(state(window), window, 5)
			local all = Logic.buyAll(view, "potion", 5, 1e12, NONE)
			local some = Logic.buyAll(view, "potion", 5, all.total - 1, NONE)
			if some then
				expect(some.count < all.count).to.equal(true)
				expect(some.of).to.equal(all.count)
				expect(some.partial).to.equal(
					("You can afford %d of %d. The best go first."):format(some.count, all.count)
				)
			end
			expect(Logic.buyAll(view, "potion", 5, 0, NONE)).to.equal(nil)
			expect(Logic.buyAll(nil, "potion", 5, 1e12, NONE)).to.equal(nil)
		end)

		it("rebuilds today's counts from leftToday, else outToday", function()
			local limited: any = nil
			for _, row in Catalog.cornerShop do
				if CornerShop.perDay(row.family) ~= nil then
					limited = row
					break
				end
			end
			expect(limited).to.be.ok()
			local limit = CornerShop.perDay(limited.family)
			local rebuilt = Logic.stateFromView({
				window = 9,
				restocksAt = 0,
				snackXp = 0,
				stock = {
					{
						itemId = limited.id,
						price = 1,
						amount = 3,
						bought = 1,
						size = "regular",
						leftToday = 1,
					},
					{
						itemId = "x_unknown",
						price = 1,
						amount = 1,
						bought = 0,
						size = "regular",
						outToday = true,
					},
				},
			} :: any)
			expect(rebuilt.window).to.equal(9)
			expect(rebuilt.bought[limited.id]).to.equal(1)
			expect(rebuilt.today[limited.id]).to.equal(limit - 1)
			expect(rebuilt.today.x_unknown).to.equal(nil)
			local out = Logic.stateFromView({
				window = 9,
				restocksAt = 0,
				snackXp = 0,
				stock = {
					{
						itemId = limited.id,
						price = 1,
						amount = 3,
						bought = 0,
						size = "regular",
						outToday = true,
					},
				},
			} :: any)
			expect(out.today[limited.id]).to.equal(limit)
		end)
	end)
end
