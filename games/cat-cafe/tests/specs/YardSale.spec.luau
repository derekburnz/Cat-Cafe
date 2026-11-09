--!strict
-- shared/YardSale.luau (#1537, lawn-nursery.md section 7): the Yard Sale's lawn rows each global game day, the same on
-- every server, rolled by rarity with a step down when a rarity runs out, bought once each a day, and the save's
-- sanitizing.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Clock = require(Shared.Clock)
	local Config = require(Shared.Config)
	local ProfileSchema = require(Shared.ProfileSchema)
	local YardSale = require(Shared.YardSale)

	local function rarityOf(id: string): string
		local piece = Catalog.getLawn(id)
		if piece ~= nil then
			return piece.rarity
		end
		local style = Catalog.getLawnStyle(id)
		return if style ~= nil and style.rarity ~= nil then style.rarity else "?"
	end

	describe("YardSale", function()
		it("has section 7's numbers", function()
			expect(Config.YardDecorRows).to.equal(6)
			expect(Config.YardDecorRarityWeights :: any).to.deepEqual({
				Common = 28,
				Uncommon = 25,
				Rare = 20,
				Epic = 14,
				Legendary = 8,
				Mythical = 4,
				Golden = 1,
			})
		end)

		it("sells every lawn piece and priced style, never the free Grey Slabs", function()
			local count = 0
			for _, rarity in YardSale.RARITIES do
				for _, id in YardSale.poolOf(rarity) do
					expect(rarityOf(id)).to.equal(rarity)
					expect(id).never.to.equal("grey_slabs")
					count += 1
				end
			end
			local expected = #Catalog.lawn
			for _, style in Catalog.lawnStyles do
				if style.rarity ~= nil and style.price > 0 then
					expected += 1
				end
			end
			expect(count).to.equal(expected)
		end)

		it("turns at each global sunrise", function()
			local epoch = Config.ClockEpoch
			local day = YardSale.dayAt(epoch + 5000)
			expect(day).to.equal(Clock.dayAt(5000))
			local next = YardSale.restocksAt(day)
			expect(YardSale.dayAt(next - 1)).to.equal(day)
			expect(YardSale.dayAt(next)).to.equal(day + 1)
		end)

		it("picks a rarity by the weights", function()
			expect(YardSale.pickRarity(0)).to.equal("Common")
			expect(YardSale.pickRarity(0.279)).to.equal("Common")
			expect(YardSale.pickRarity(0.281)).to.equal("Uncommon")
			expect(YardSale.pickRarity(0.98)).to.equal("Mythical")
			expect(YardSale.pickRarity(0.995)).to.equal("Golden")
		end)

		it("rolls six different rows, the same for the same day", function()
			for day = 1, 300 do
				local rows = YardSale.stock(day)
				expect(#rows).to.equal(6)
				local seen: { [string]: boolean } = {}
				for _, id in rows do
					expect(seen[id]).never.to.be.ok()
					seen[id] = true
				end
			end
			local a = YardSale.stock(41)
			YardSale.stock(42)
			expect(YardSale.stock(41)).to.deepEqual(a)
			expect(YardSale.stock(42)).never.to.deepEqual(a)
		end)

		it("lands near the table over many days, stepping down when a rarity runs out", function()
			local days = 10000
			local counts: { [string]: number } = {}
			local mythicalDays, goldenDays = 0, 0
			for day = 1, days do
				local hasMythical, hasGolden = false, false
				for _, id in YardSale.stock(day) do
					local rarity = rarityOf(id)
					counts[rarity] = (counts[rarity] or 0) + 1
					hasMythical = hasMythical or rarity == "Mythical"
					hasGolden = hasGolden or rarity == "Golden"
				end
				mythicalDays += if hasMythical then 1 else 0
				goldenDays += if hasGolden then 1 else 0
			end
			local rows = days * 6
			-- the top rarities rarely run out within a day, so they land on the table
			expect(math.abs((counts.Golden or 0) / rows - 0.01) < 0.003).to.equal(true)
			expect(math.abs((counts.Mythical or 0) / rows - 0.04) < 0.005).to.equal(true)
			expect(math.abs((counts.Legendary or 0) / rows - 0.08) < 0.006).to.equal(true)
			-- section 7: about 1 day in 5 has a Mythical row, about 1 in 17 a Golden one
			expect(math.abs(mythicalDays / days - 0.21) < 0.03).to.equal(true)
			expect(math.abs(goldenDays / days - 0.058) < 0.012).to.equal(true)
		end)

		it("refuses a row not on sale, bought today, or while behind the saved day", function()
			local day = 77
			local id = YardSale.stock(day)[1]
			local state = YardSale.fresh()
			YardSale.refresh(state, day)
			expect(YardSale.buyBlocker(state, day, id, nil)).to.equal(nil)
			expect(YardSale.buyBlocker(state, day, id, "You already have it.")).to.equal("You already have it.")
			local notToday = "golden_paw_statue"
			if YardSale.inStock(day, notToday) then
				notToday = "tulip_bed"
			end
			if not YardSale.inStock(day, notToday) then
				expect(YardSale.buyBlocker(state, day, notToday, nil)).to.equal(YardSale.Messages.notToday)
			end
			state.bought[id] = true
			expect(YardSale.buyBlocker(state, day, id, nil)).to.equal(YardSale.Messages.boughtToday)
			-- a server a day behind sells nothing; the next day clears the rows, a step back never does
			expect(YardSale.buyBlocker(state, day - 1, id, nil)).to.equal(YardSale.Messages.newStock)
			YardSale.refresh(state, day - 1)
			expect(state.bought[id]).to.equal(true)
			YardSale.refresh(state, day + 1)
			expect(next(state.bought)).to.equal(nil)
			expect(state.day).to.equal(day + 1)
		end)

		it("shows each row with its price, tier and whether it's bought or owned", function()
			local day = 12
			local profile: any = ProfileSchema.template(1000)
			local rows = YardSale.stock(day)
			profile.lawnOwned[rows[2]] = true
			profile.yardDecor.day = day
			profile.yardDecor.bought[rows[1]] = true
			local view = YardSale.view(profile, profile.yardDecor, day)
			expect(#view).to.equal(6)
			expect(view[1].id).to.equal(rows[1])
			expect(view[1].bought).to.equal(true)
			expect(view[2].owned).to.equal(true)
			expect(view[3].bought).to.equal(false)
			expect(view[3].price).to.equal(YardSale.priceOf(rows[3]))
			expect(view[3].price > 0).to.equal(true)
			expect(view[3].rarity).to.equal(rarityOf(rows[3]))
		end)

		it("sanitizes the save", function()
			expect(YardSale.sanitize(nil)).to.deepEqual({ day = 0, bought = {} })
			expect(YardSale.sanitize({ day = "x", bought = 5 })).to.deepEqual({ day = 0, bought = {} })
			local raw0 = { day = 12.7, bought = { tulip_bed = true, nope = true, mailbox = 1 } }
			expect(YardSale.sanitize(raw0)).to.deepEqual({ day = 12, bought = { tulip_bed = true } })
			local raw: any = ProfileSchema.template(1000)
			raw.yardDecor = { day = 9, bought = { red_brick = true } }
			local profile = ProfileSchema.migrate(raw, 1000)
			expect(profile.yardDecor.day).to.equal(9)
			expect(profile.yardDecor.bought.red_brick).to.equal(true)
		end)
	end)
end
