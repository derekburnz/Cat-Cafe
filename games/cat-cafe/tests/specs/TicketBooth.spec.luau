--!strict
-- TicketBooth.luau (#4061): tickets per catch, the daily Ticket Rush, the fixed prizes and their limits, the save.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local ProfileSchema = require(Shared.ProfileSchema)
	local TicketBooth = require(Shared.TicketBooth)

	-- a Monday 00:00 UTC (2026-11-16)
	local MONDAY = 1794787200

	describe("tickets per catch", function()
		it(
			"pays by rarity, x2 gold, x5 rainbow, x2 in the rush, and nothing for a starter or trade",
			function()
				expect(TicketBooth.forCatch("Common", nil, "net", false)).to.equal(1)
				expect(TicketBooth.forCatch("Epic", "gold", "rescue", false)).to.equal(8)
				expect(TicketBooth.forCatch("Mythical", "rainbow", "bait", false)).to.equal(125)
				expect(TicketBooth.forCatch("Secret", nil, "net", true)).to.equal(120)
				expect(TicketBooth.forCatch("Legendary", nil, "starter", false)).to.equal(0)
				expect(TicketBooth.forCatch("Legendary", nil, "trade", true)).to.equal(0)
			end
		)

		it("starts the rush at the day's first catch, for one hour, once a day", function()
			local save = TicketBooth.fresh()
			local t = MONDAY + 3600
			expect(TicketBooth.credit(save, "Rare", nil, "net", t)).to.equal(4)
			expect(save.rushAt).to.equal(t)
			expect(TicketBooth.credit(save, "Rare", nil, "net", t + 3599)).to.equal(4)
			expect(TicketBooth.credit(save, "Rare", nil, "net", t + 3600)).to.equal(2)
			expect(save.rushAt).to.equal(t)
			expect(save.have).to.equal(10)
			-- the next day starts a new rush
			expect(TicketBooth.credit(save, "Rare", nil, "net", MONDAY + 86400 + 5)).to.equal(4)
		end)
	end)

	describe("prizes", function()
		it("names known potions and crates, and no prize is random or a pass", function()
			for _, prize in TicketBooth.PRIZES do
				expect(prize.price > 0).to.equal(true)
				local paid = prize.prize
				if paid ~= nil then
					for potionId in paid.potions or {} do
						local found = false
						for _, potion in Catalog.potions do
							if potion.id == potionId then
								found = true
							end
						end
						expect(found).to.equal(true)
					end
				end
			end
			expect(TicketBooth.prize("fish25")).to.be.ok()
		end)

		it(
			"sells Design-Agent's #4596 shelf: no potions, 10 tokens, spins, Moon Milk and the best golden crate",
			function()
				for _, gone in { "traitToken", "bigGoldRush", "bigLucky", "swiftPaws" } do
					expect(TicketBooth.prize(gone)).to.equal(nil)
				end
				for _, prize in TicketBooth.PRIZES do
					expect(prize.prize == nil or prize.prize.potions == nil).to.equal(true)
				end
				local tokens = TicketBooth.prize("tokens10") :: TicketBooth.Prize
				expect(tokens.tokens).to.equal(10)
				expect(tokens.price).to.equal(2000) -- #4960
				expect(tokens.limit).to.deepEqual({ per = "week", n = 1 })
				local spins = TicketBooth.prize("spins5") :: TicketBooth.Prize
				expect((spins.prize :: any).spins).to.equal(5)
				expect(spins.price).to.equal(1000)
				expect(spins.limit).to.deepEqual({ per = "day", n = 3 })
				-- #4959: a Legendary bait in place of Caviar
				expect(TicketBooth.prize("caviar")).to.equal(nil)
				local milk = TicketBooth.prize("moonMilk") :: TicketBooth.Prize
				expect((milk.prize :: any).lures.moon_milk).to.equal(1)
				expect(milk.price).to.equal(1200)
				expect(milk.limit).to.deepEqual({ per = "day", n = 3 })
				local best = TicketBooth.prize("bestGolden") :: TicketBooth.Prize
				expect((best.prize :: any).crates.highest_golden).to.equal(1)
				expect(best.price).to.equal(1800)
				expect(best.limit).to.deepEqual({ per = "day", n = 1 })
			end
		)

		it("keeps the day limit, then opens again the next day", function()
			local save = TicketBooth.fresh()
			save.have = 10000
			local fish = TicketBooth.prize("fish25") :: TicketBooth.Prize
			for _ = 1, 4 do
				expect(TicketBooth.blocker(save, fish, MONDAY + 10)).to.equal(nil)
				TicketBooth.spend(save, fish, MONDAY + 10)
			end
			expect(TicketBooth.blocker(save, fish, MONDAY + 10)).to.equal("That's all for today")
			expect(TicketBooth.left(save, fish, MONDAY + 86400)).to.equal(4)
			expect(save.have).to.equal(10000 - 1200)
			expect(save.spent).to.equal(1200)
		end)

		it("keeps the week limit until Monday 00:00 UTC", function()
			local save = TicketBooth.fresh()
			save.have = 10000
			save.have = 20000 -- the week's bundle and one more
			local token = TicketBooth.prize("tokens10") :: TicketBooth.Prize
			TicketBooth.spend(save, token, MONDAY + 86400)
			expect(TicketBooth.blocker(save, token, MONDAY + 6 * 86400 + 86399)).to.equal(
				"That's all for this week"
			)
			expect(TicketBooth.blocker(save, token, MONDAY + 7 * 86400)).to.equal(nil)
			expect(TicketBooth.weekEndsAt(MONDAY + 5)).to.equal(MONDAY + 7 * 86400)
		end)

		it("refuses too few tickets", function()
			local save = TicketBooth.fresh()
			save.have = 299
			local fish = TicketBooth.prize("fish25") :: TicketBooth.Prize
			expect(TicketBooth.blocker(save, fish, MONDAY)).to.equal("Not enough tickets yet")
		end)
	end)

	describe("the save", function()
		it("makes a broken save whole and survives a migrate", function()
			local out = TicketBooth.sanitize({
				have = -5,
				spent = 12.7,
				rushAt = "x",
				limits = { fish25 = { key = 3, n = 2 }, nope = { key = 1, n = 1 } },
			})
			expect(out.have).to.equal(0)
			expect(out.spent).to.equal(12)
			expect(out.rushAt).to.equal(0)
			expect(out.limits.fish25.n).to.equal(2)
			expect(out.limits.nope).to.equal(nil)
			local profile = ProfileSchema.migrate({ version = 49, tickets = { have = 40 } }, MONDAY)
			expect(profile.tickets.have).to.equal(40)
			expect(ProfileSchema.template(MONDAY).tickets.have).to.equal(0)
		end)
	end)
	describe("Booth Plush Cat and Park Regular", function()
		it(
			"sells the plush cat once for 8,000, an exclusive booth cat that is never gold",
			function()
				local prize = TicketBooth.prize("boothPlush")
				expect(prize).to.be.ok()
				local p = prize :: TicketBooth.Prize
				expect(p.price).to.equal(8000)
				expect((p.limit :: TicketBooth.Limit).per).to.equal("once")
				local def = Catalog.getCat(p.cat :: string)
				expect(def).to.be.ok()
				local d = def :: any
				expect(d.exclusive).to.equal(true)
				expect(d.source).to.equal("booth")
				expect(d.rarity).to.equal("Legendary")
				expect(Catalog.catModelName(d.id)).to.equal("CatCafe_Cat_BoothPlush")
				local save = TicketBooth.fresh()
				save.have = 20000
				expect(TicketBooth.blocker(save, p, MONDAY)).to.equal(nil)
				TicketBooth.spend(save, p, MONDAY)
				expect(save.have).to.equal(12000)
				expect(TicketBooth.blocker(save, p, MONDAY + 30 * 86400)).to.be.ok()
			end
		)

		it("gives Park Regular from 10,000 tickets spent, a tag in ChatTags", function()
			local ChatTags = require(Shared.ChatTags)
			local save = TicketBooth.fresh()
			save.spent = 9999
			expect(TicketBooth.regular(save)).to.equal(false)
			save.spent = 10000
			expect(TicketBooth.regular(save)).to.equal(true)
			expect(ChatTags.TAGS[TicketBooth.REGULAR_TAG]).to.be.ok()
			expect(table.find(ChatTags.ORDER, TicketBooth.REGULAR_TAG)).to.be.ok()
		end)
	end)
	describe("weekly Water Park shelf", function()
		it("shows four cards a week in turn, every one named in the Catalog or Looks", function()
			local Looks = require(Shared.Looks)
			local seen: { [string]: boolean } = {}
			for week = 0, 4 do
				local shelf = TicketBooth.weekShelf(MONDAY + week * 7 * 86400 + 5)
				expect(#shelf).to.equal(TicketBooth.SHELF_SIZE)
				for _, prize in shelf do
					seen[prize.id] = true
				end
			end
			for _, prize in TicketBooth.WEEKLY do
				expect(seen[prize.id]).to.equal(true) -- the whole pool comes round in five weeks
				local w = prize.weekly :: any
				expect((prize.limit :: TicketBooth.Limit).per).to.equal("once")
				if w.kind == "decor" then
					local def = Catalog.getDecor(w.item) :: any
					expect(def).to.be.ok()
					expect(def.source).to.equal("booth")
				else
					local found = false
					for _, acc in Looks.ACCESSORIES do
						if acc.id == w.item then
							found = true
						end
					end
					expect(found).to.equal(true)
				end
				expect(TicketBooth.prize(prize.id)).to.equal(prize)
			end
			-- the same week, all day long
			local a = TicketBooth.weekShelf(MONDAY + 10)
			local b = TicketBooth.weekShelf(MONDAY + 6 * 86400 + 86399)
			expect(a[1]).to.equal(b[1])
		end)

		it("sells a card only the week it is on the shelf, once", function()
			local save = TicketBooth.fresh()
			save.have = 100000
			local onNow = TicketBooth.weekShelf(MONDAY + 5)[1]
			local offNow: TicketBooth.Prize? = nil
			for _, prize in TicketBooth.WEEKLY do
				if not TicketBooth.onShelf(prize, MONDAY + 5) then
					offNow = prize
				end
			end
			expect(TicketBooth.blocker(save, onNow, MONDAY + 5)).to.equal(nil)
			expect(TicketBooth.blocker(save, offNow :: TicketBooth.Prize, MONDAY + 5)).to.equal(
				"Not on the shelf this week"
			)
			TicketBooth.spend(save, onNow, MONDAY + 5)
			expect(TicketBooth.owns(save, onNow)).to.equal(true)
			expect(TicketBooth.blocker(save, onNow, MONDAY + 5)).to.equal("You have this already")
			local migrated = TicketBooth.sanitize(save)
			expect(TicketBooth.owns(migrated, onNow)).to.equal(true) -- kept through a save round trip
		end)

		it(
			"adds owned wearables to the Looks items and pays the wear bonus only while worn",
			function()
				local save = TicketBooth.fresh()
				local cap: TicketBooth.Prize? = nil
				for _, prize in TicketBooth.WEEKLY do
					if prize.weekly ~= nil and prize.weekly.kind == "look" then
						cap = prize
						break
					end
				end
				local p = cap :: TicketBooth.Prize
				local item = (p.weekly :: any).item
				expect(TicketBooth.wearBonus(save, item)).to.equal(0)
				save.limits[p.id] = { key = 0, n = 1 }
				local items = { tag_maple = true }
				local out = TicketBooth.lookItems(save, items)
				expect(out[item]).to.equal(true)
				expect(out.tag_maple).to.equal(true)
				expect(items[item]).to.equal(nil) -- a copy
				expect(TicketBooth.wearBonus(save, item)).to.equal(TicketBooth.WEAR_BONUS)
				expect(TicketBooth.wearBonus(save, nil)).to.equal(0)
				expect(TicketBooth.wearBonus(save, "glasses")).to.equal(0)
			end
		)

		it("sends this week's cards with the view, owned marked", function()
			local save = TicketBooth.fresh()
			local view = TicketBooth.view(save, MONDAY + 5)
			expect(#view.week).to.equal(TicketBooth.SHELF_SIZE)
			expect(view.week[1].owned).to.equal(false)
			expect(view.week[1].kind ~= nil).to.equal(true)
			expect(view.prizes[1].kind).to.equal(nil)
		end)
	end)
	describe("open", function()
		it("opens from Config.TicketBoothTier (9, the Water Park)", function()
			expect(TicketBooth.open(8)).to.equal(false)
			expect(TicketBooth.open(9)).to.equal(true)
		end)
	end)
end
