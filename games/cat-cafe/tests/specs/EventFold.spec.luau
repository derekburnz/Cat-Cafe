--!strict
-- shared/EventFold: Growth Nov 22, the dark custom events sent under names that record (switch eventFold).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local EventFold = require(Shared:WaitForChild("EventFold")) :: any
	local LiveFlags = require(Shared:WaitForChild("LiveFlags")) :: any

	local function joined(name: string, value: number, fields: { string }): string
		local host, out = EventFold.fold(name, value, fields)
		return host .. ":" .. table.concat(out, "|")
	end

	describe("EventFold", function()
		it("is behind eventFold, off by default", function()
			expect(EventFold.FLAG).to.equal("eventFold")
			expect(LiveFlags.defaults().eventFold).to.equal(false)
		end)

		it("sends each dark event under a host that records, the old name in field 1", function()
			expect(joined("picnic_cat_caught", 3, { "Rare", "maine_coon" })).to.equal(
				"picnic_started:cat_3|Rare|maine_coon"
			)
			expect(joined("start_cannon", 95, { "town", "picker" })).to.equal(
				"free_start:cannon_town|picker"
			)
			expect(joined("hood_welcome", 1, { "caught", "Epic" })).to.equal(
				"tier3_trip:welcome_caught|Epic"
			)
			expect(joined("days_played", 7, { "cat", "phone" })).to.equal(
				"daily_gift:days_7|cat|phone"
			)
			expect(joined("return_card", 30, { "yes", "pc", "milestone" })).to.equal(
				"daily_gift:return_milestone|yes|pc"
			)
			expect(joined("quick_return", 12, { "tier_2", "10_30", "s2" })).to.equal(
				"daily_gift:quick_10_30|tier_2|s2"
			)
			expect(joined("rank_up_spotlight_closed", 1, { "tablet" })).to.equal(
				"rank_up_spotlight_shown:tablet|closed"
			)
			expect(joined("snowglobe_catch", 5, { "Legendary" })).to.equal(
				"camp_extra:snowglobe|catch|Legendary"
			)
			expect(joined("gift_buy", 400, { "acc_santa_hat", "T3" })).to.equal(
				"camp_extra:gift_stall|acc_santa_hat|T3"
			)
		end)

		it("keeps every other event as it is, and never more than three fields", function()
			local fields = { "a", "b", "c" }
			local host, out = EventFold.fold("session_end", 60, fields)
			expect(host).to.equal("session_end")
			expect(out).to.equal(fields)
			expect(EventFold.folds("session_end")).to.equal(false)
			for _, name in
				{
					"picnic_cat_caught",
					"start_cannon",
					"hood_welcome",
					"days_played",
					"return_card",
					"quick_return",
					"rank_up_spotlight_closed",
					"snowglobe_catch",
					"gift_buy",
				}
			do
				expect(EventFold.folds(name)).to.equal(true)
				local _, folded = EventFold.fold(name, 0 / 0, {})
				expect(#folded <= 3).to.equal(true)
				for _, value in folded do
					expect(type(value)).to.equal("string")
				end
			end
		end)
	end)
end
