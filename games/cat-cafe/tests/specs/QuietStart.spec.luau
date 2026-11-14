--!strict
-- shared/QuietStart.luau (#4005): a new player's first 15 minutes without other players' pop ups, and the extras
-- that wait for Tier 2.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local LiveFlags = require(Shared.LiveFlags)
	local QuietStart = require(Shared.QuietStart)

	describe("QuietStart", function()
		it("is a switch that starts off", function()
			expect(LiveFlags.OFF_BY_DEFAULT[QuietStart.FLAG]).to.equal(true)
			expect(table.find(LiveFlags.KEYS, QuietStart.FLAG) ~= nil).to.equal(true)
		end)

		it("counts the account's first 15 minutes across visits", function()
			expect(QuietStart.untilAt(1000, 0)).to.equal(1900)
			expect(QuietStart.untilAt(1000, 600)).to.equal(1300)
			expect(QuietStart.untilAt(1000, 900)).to.equal(nil)
			expect(QuietStart.untilAt(1000, 5000)).to.equal(nil)
			expect(QuietStart.untilAt(1000, nil)).to.equal(nil)
			expect(QuietStart.untilAt(1000, 0 / 0)).to.equal(nil)
		end)

		it("is quiet only with the switch on and before the end", function()
			expect(QuietStart.quiet(true, 1900, 1899)).to.equal(true)
			expect(QuietStart.quiet(true, 1900, 1900)).to.equal(false)
			expect(QuietStart.quiet(false, 1900, 1000)).to.equal(false)
			expect(QuietStart.quiet(true, nil, 1000)).to.equal(false)
		end)

		it("holds the extra tips until Tier 2 and the tackle try while quiet", function()
			for _, id in { "spin_wheel", "golden_fish", "potion", "codes_cat", "luck" } do
				expect(QuietStart.holdsTip(true, id, 1, false, false)).to.equal(true)
				expect(QuietStart.holdsTip(true, id, nil, false, false)).to.equal(true)
				expect(QuietStart.holdsTip(true, id, 2, true, false)).to.equal(false)
				expect(QuietStart.holdsTip(false, id, 1, true, true)).to.equal(false)
			end
			expect(QuietStart.holdsTip(true, "tackle_try", 3, true, false)).to.equal(true)
			expect(QuietStart.holdsTip(true, "tackle_try", 1, false, false)).to.equal(false)
			for _, id in { "bowl", "second_cat", "night", "perfect" } do
				expect(QuietStart.holdsTip(true, id, 1, true, true)).to.equal(false)
			end
		end)

		it("cuts the rank up camera cut only beside the walk through", function()
			expect(QuietStart.holdsTip(true, "rank_up", 1, false, true)).to.equal(true)
			expect(QuietStart.holdsTip(true, "rank_up", 1, false, false)).to.equal(false)
			expect(QuietStart.holdsTip(false, "rank_up", 1, false, true)).to.equal(false)
		end)

		it("holds the first visit calls until Tier 2", function()
			expect(QuietStart.holdsFirstVisit(true, 1)).to.equal(true)
			expect(QuietStart.holdsFirstVisit(true, nil)).to.equal(true)
			expect(QuietStart.holdsFirstVisit(true, 2)).to.equal(false)
			expect(QuietStart.holdsFirstVisit(false, 1)).to.equal(false)
		end)

		it("makes a later new kind below Epic a toast before Tier 2", function()
			expect(QuietStart.foundToast(true, 1, "Common", false)).to.equal(true)
			expect(QuietStart.foundToast(true, 1, "Rare", false)).to.equal(true)
			expect(QuietStart.foundToast(true, 1, "Common", true)).to.equal(false) -- the tutorial's catch
			for _, rarity in { "Epic", "Legendary", "Mythical", "Secret", "Golden" } do
				expect(QuietStart.foundToast(true, 1, rarity, false)).to.equal(false)
			end
			expect(QuietStart.foundToast(true, 2, "Common", false)).to.equal(false)
			expect(QuietStart.foundToast(false, 1, "Common", false)).to.equal(false)
		end)

		it("keeps the Daily Treat window shut on the first day only", function()
			expect(QuietStart.treatOpensItself(true, 20405, 20405)).to.equal(false)
			expect(QuietStart.treatOpensItself(true, 20405, 20406)).to.equal(true)
			expect(QuietStart.treatOpensItself(true, 0, 20405)).to.equal(true)
			expect(QuietStart.treatOpensItself(true, nil, 20405)).to.equal(true)
			expect(QuietStart.treatOpensItself(false, 20405, 20405)).to.equal(true)
		end)
	end)
end
