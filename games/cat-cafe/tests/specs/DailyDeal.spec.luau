--!strict
-- DailyDeal.luau (#3996, todays-deal-3996.md): the four R$25 deals by UTC day, the token deal's fallback, once a day,
-- Tier 2 and up, the prompt check and the save's dealDay.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local DailyDeal = require(Shared.DailyDeal)
	local ProfileSchema = require(Shared.ProfileSchema)

	local DAY = 20406 -- a UTC day number; DAY % 4 == 2, so deal 3
	local NOW = DAY * 86400 + 3600

	local function potions(id: string): number
		local product = assert(Catalog.getProduct(id))
		local n = 0
		for _, count in product.prize.potions do
			n += count
		end
		return n
	end

	describe("the deals (section 2)", function()
		it(
			"has four products, no potions in any (#4238), golden fish, tokens and golden crates",
			function()
				expect(#DailyDeal.LIST).to.equal(4)
				for n, deal in DailyDeal.LIST do
					expect(deal.n).to.equal(n)
					expect(deal.product).to.equal("deal_" .. n)
					expect(Catalog.getProduct(deal.product)).to.be.ok()
					expect(DailyDeal.ofProduct(deal.product)).to.equal(deal)
				end
				for n = 1, 4 do
					expect(potions("deal_" .. n)).to.equal(0)
				end
				expect((assert(Catalog.getProduct("deal_1"))).prize.fish).to.equal(250)
				expect(DailyDeal.LIST[1].needs).to.equal(nil) -- the fallback is never random
				expect((assert(Catalog.getProduct("deal_2"))).prize.traitTokens).to.equal(10)
				expect(DailyDeal.LIST[2].needs).to.equal("tokens")
				expect((assert(Catalog.getProduct("deal_3"))).prize.crates).to.deepEqual({
					highest_golden = 10,
				})
				expect(DailyDeal.LIST[3].needs).to.equal("crates")
				local haul = (assert(Catalog.getProduct("deal_4"))).prize
				expect(haul.crates).to.deepEqual({ highest_golden = 5 })
				expect(haul.fish).to.equal(100)
				expect(DailyDeal.LIST[4].needs).to.equal("crates")
				expect(DailyDeal.ofProduct("potion_pack_s")).to.equal(nil)
			end
		)

		it("turns by UTC day, the token and crate deals falling back to deal 1", function()
			expect(DailyDeal.dayOf(NOW)).to.equal(DAY)
			expect(DailyDeal.dayOf(DAY * 86400 - 1)).to.equal(DAY - 1)
			expect(DailyDeal.dealFor(DAY, true, true)).to.equal(3)
			expect(DailyDeal.dealFor(DAY + 1, true, true)).to.equal(4)
			expect(DailyDeal.dealFor(DAY + 2, true, true)).to.equal(1)
			expect(DailyDeal.dealFor(DAY + 3, true, true)).to.equal(2)
			-- #4238: where paid random items are restricted, a crate day shows the golden fish
			expect(DailyDeal.dealFor(DAY, true, false)).to.equal(1)
			expect(DailyDeal.dealFor(DAY + 1, true, nil)).to.equal(1)
			expect(DailyDeal.dealFor(DAY + 3, true, false)).to.equal(2)
			expect(DailyDeal.dealFor(DAY + 3, false)).to.equal(1)
			expect(DailyDeal.dealFor(DAY + 3, nil)).to.equal(1)
			expect(DailyDeal.roomFor(990, 7, 999)).to.equal(true)
			expect(DailyDeal.roomFor(993, 7, 999)).to.equal(false)
		end)
	end)

	describe("view and prompt (sections 3 and 5)", function()
		it("shows nothing below Tier 2, then today, bought and tomorrow", function()
			local profile = ProfileSchema.template(NOW)
			expect(DailyDeal.view(profile, NOW, true, 1, true)).to.equal(false)
			expect(DailyDeal.view(profile, NOW, true, 2, false)).to.deepEqual({
				deal = 1,
				bought = false,
				tomorrow = 1,
			})
			expect(DailyDeal.view(profile, NOW, true, 2, true)).to.deepEqual({
				deal = 3,
				bought = false,
				tomorrow = 4,
			})
			profile.dealDay = DAY
			expect(DailyDeal.view(profile, NOW, true, 2, true)).to.deepEqual({
				deal = 3,
				bought = true,
				tomorrow = 4,
			})
			-- the next UTC day it is open again, with no rejoin
			expect(DailyDeal.view(profile, NOW + 86400, true, 2, true)).to.deepEqual({
				deal = 4,
				bought = false,
				tomorrow = 1,
			})
			expect((DailyDeal.view(profile, NOW + 2 * 86400, true, 2, true) :: any).tomorrow).to.equal(
				2
			)
			expect((DailyDeal.view(profile, NOW + 2 * 86400, false, 2, true) :: any).tomorrow).to.equal(
				1
			)
		end)

		it("opens the prompt only for today's deal, once a day, from Tier 2", function()
			local profile = ProfileSchema.template(NOW)
			expect(DailyDeal.promptBlocker(profile, NOW, true, 2, "deal_3", true)).to.equal(nil)
			expect(DailyDeal.promptBlocker(profile, NOW, true, 2, "deal_1", true)).never.to.equal(
				nil
			)
			expect(DailyDeal.promptBlocker(profile, NOW, true, 1, "deal_3", true)).never.to.equal(
				nil
			)
			-- #4238: no crate deal where paid random items are restricted, the golden fish instead
			expect(DailyDeal.promptBlocker(profile, NOW, true, 2, "deal_3", false)).never.to.equal(
				nil
			)
			expect(DailyDeal.promptBlocker(profile, NOW, true, 2, "deal_1", false)).to.equal(nil)
			profile.dealDay = DAY
			expect(DailyDeal.promptBlocker(profile, NOW, true, 2, "deal_3", true)).to.equal(
				"Bought today. A new deal comes tomorrow."
			)
			-- token day for a player who cannot get tokens: deal 1, never deal 2
			local tokenDay = (DAY + 3) * 86400
			profile.dealDay = nil
			expect(DailyDeal.promptBlocker(profile, tokenDay, false, 2, "deal_2")).never.to.equal(
				nil
			)
			expect(DailyDeal.promptBlocker(profile, tokenDay, false, 2, "deal_1")).to.equal(nil)
		end)
	end)

	describe("the save", function()
		it("keeps a whole dealDay and drops anything else", function()
			expect(ProfileSchema.template(NOW).dealDay).to.equal(nil)
			local raw = ProfileSchema.template(NOW) :: any
			raw.dealDay = DAY
			expect(ProfileSchema.migrate(raw, NOW).dealDay).to.equal(DAY)
			raw.dealDay = "x"
			expect(ProfileSchema.migrate(raw, NOW).dealDay).to.equal(nil)
			expect(DailyDeal.sanitizeDay(-1)).to.equal(nil)
			expect(DailyDeal.sanitizeDay(0 / 0)).to.equal(nil)
			expect(DailyDeal.sanitizeDay(12.5)).to.equal(12)
		end)
	end)
end
