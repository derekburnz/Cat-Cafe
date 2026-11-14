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
			"has four products with the listed contents and nothing random but deal 2's tokens",
			function()
				expect(#DailyDeal.LIST).to.equal(4)
				for n, deal in DailyDeal.LIST do
					expect(deal.n).to.equal(n)
					expect(deal.product).to.equal("deal_" .. n)
					expect(Catalog.getProduct(deal.product)).to.be.ok()
					expect(DailyDeal.ofProduct(deal.product)).to.equal(deal)
				end
				expect(potions("deal_1")).to.equal(7)
				expect((assert(Catalog.getProduct("deal_2"))).prize.traitTokens).to.equal(7)
				expect(potions("deal_3")).to.equal(12)
				expect(potions("deal_4")).to.equal(7)
				expect((assert(Catalog.getProduct("deal_4"))).prize.potions).to.deepEqual({
					big_tip_potion = 4,
					swift_potion = 1,
					steady_potion = 2,
				})
				expect(DailyDeal.ofProduct("potion_pack_s")).to.equal(nil)
			end
		)

		it("turns by UTC day, the token deal falling back to deal 1", function()
			expect(DailyDeal.dayOf(NOW)).to.equal(DAY)
			expect(DailyDeal.dayOf(DAY * 86400 - 1)).to.equal(DAY - 1)
			expect(DailyDeal.dealFor(DAY, true)).to.equal(3)
			expect(DailyDeal.dealFor(DAY + 1, true)).to.equal(4)
			expect(DailyDeal.dealFor(DAY + 2, true)).to.equal(1)
			expect(DailyDeal.dealFor(DAY + 3, true)).to.equal(2)
			expect(DailyDeal.dealFor(DAY + 3, false)).to.equal(1)
			expect(DailyDeal.dealFor(DAY + 3, nil)).to.equal(1)
			expect(DailyDeal.roomFor(990, 7, 999)).to.equal(true)
			expect(DailyDeal.roomFor(993, 7, 999)).to.equal(false)
		end)
	end)

	describe("view and prompt (sections 3 and 5)", function()
		it("shows nothing below Tier 2, then today, bought and tomorrow", function()
			local profile = ProfileSchema.template(NOW)
			expect(DailyDeal.view(profile, NOW, true, 1)).to.equal(false)
			expect(DailyDeal.view(profile, NOW, true, 2)).to.deepEqual({
				deal = 3,
				bought = false,
				tomorrow = 4,
			})
			profile.dealDay = DAY
			expect(DailyDeal.view(profile, NOW, true, 2)).to.deepEqual({
				deal = 3,
				bought = true,
				tomorrow = 4,
			})
			-- the next UTC day it is open again, with no rejoin
			expect(DailyDeal.view(profile, NOW + 86400, true, 2)).to.deepEqual({
				deal = 4,
				bought = false,
				tomorrow = 1,
			})
			expect((DailyDeal.view(profile, NOW + 2 * 86400, true, 2) :: any).tomorrow).to.equal(2)
			expect((DailyDeal.view(profile, NOW + 2 * 86400, false, 2) :: any).tomorrow).to.equal(1)
		end)

		it("opens the prompt only for today's deal, once a day, from Tier 2", function()
			local profile = ProfileSchema.template(NOW)
			expect(DailyDeal.promptBlocker(profile, NOW, true, 2, "deal_3")).to.equal(nil)
			expect(DailyDeal.promptBlocker(profile, NOW, true, 2, "deal_1")).never.to.equal(nil)
			expect(DailyDeal.promptBlocker(profile, NOW, true, 1, "deal_3")).never.to.equal(nil)
			profile.dealDay = DAY
			expect(DailyDeal.promptBlocker(profile, NOW, true, 2, "deal_3")).to.equal(
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
