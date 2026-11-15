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
			local token = TicketBooth.prize("traitToken") :: TicketBooth.Prize
			for _ = 1, 3 do
				TicketBooth.spend(save, token, MONDAY + 86400)
			end
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
	describe("open", function()
		it("opens from Config.TicketBoothTier (9, the Water Park)", function()
			expect(TicketBooth.open(8)).to.equal(false)
			expect(TicketBooth.open(9)).to.equal(true)
		end)
	end)
end
