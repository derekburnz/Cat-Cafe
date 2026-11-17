--!strict
-- shared/QuietStart.luau (#4005): a new player's first 15 minutes without other players' pop ups, and the extras
-- that wait for Tier 2.

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local QuietStart = require(Shared.QuietStart)

	describe("QuietStart", function()
		it("counts the account's first 15 minutes across visits", function()
			expect(QuietStart.untilAt(1000, 0)).to.equal(1900)
			expect(QuietStart.untilAt(1000, 600)).to.equal(1300)
			expect(QuietStart.untilAt(1000, 900)).to.equal(nil)
			expect(QuietStart.untilAt(1000, 5000)).to.equal(nil)
			expect(QuietStart.untilAt(1000, nil)).to.equal(nil)
			expect(QuietStart.untilAt(1000, 0 / 0)).to.equal(nil)
		end)

		it("is quiet only before the end", function()
			expect(QuietStart.quiet(1900, 1899)).to.equal(true)
			expect(QuietStart.quiet(1900, 1900)).to.equal(false)
			expect(QuietStart.quiet(nil, 1000)).to.equal(false)
		end)

		it("holds the extra tips until Tier 2 and the tackle try while quiet", function()
			for _, id in { "spin_wheel", "golden_fish", "potion", "codes_cat", "luck" } do
				expect(QuietStart.holdsTip(id, 1, false, false)).to.equal(true)
				expect(QuietStart.holdsTip(id, nil, false, false)).to.equal(true)
				expect(QuietStart.holdsTip(id, 2, true, false)).to.equal(false)
			end
			expect(QuietStart.holdsTip("tackle_try", 3, true, false)).to.equal(true)
			expect(QuietStart.holdsTip("tackle_try", 1, false, false)).to.equal(false)
			for _, id in { "bowl", "second_cat", "night", "perfect" } do
				expect(QuietStart.holdsTip(id, 1, true, true)).to.equal(false)
			end
		end)

		it("cuts the rank up camera cut only beside the walk through", function()
			expect(QuietStart.holdsTip("rank_up", 1, false, true)).to.equal(true)
			expect(QuietStart.holdsTip("rank_up", 1, false, false)).to.equal(false)
		end)

		it("holds the first visit calls until Tier 2", function()
			expect(QuietStart.holdsFirstVisit(1)).to.equal(true)
			expect(QuietStart.holdsFirstVisit(nil)).to.equal(true)
			expect(QuietStart.holdsFirstVisit(2)).to.equal(false)
		end)

		it("makes a later new kind below Epic a toast before Tier 2", function()
			expect(QuietStart.foundToast(1, "Common", false)).to.equal(true)
			expect(QuietStart.foundToast(1, "Rare", false)).to.equal(true)
			expect(QuietStart.foundToast(1, "Common", true)).to.equal(false) -- the tutorial's catch
			for _, rarity in { "Epic", "Legendary", "Mythical", "Secret", "Golden" } do
				expect(QuietStart.foundToast(1, rarity, false)).to.equal(false)
			end
			expect(QuietStart.foundToast(2, "Common", false)).to.equal(false)
		end)

		it("keeps the Daily Treat window shut on the first day only", function()
			expect(QuietStart.treatOpensItself(20405, 20405)).to.equal(false)
			expect(QuietStart.treatOpensItself(20405, 20406)).to.equal(true)
			expect(QuietStart.treatOpensItself(0, 20405)).to.equal(true)
			expect(QuietStart.treatOpensItself(nil, 20405)).to.equal(true)
		end)
	end)

	describe("the first cat hold (#4821)", function()
		it("holds before the bowl cat is claimed and FIRST_CAT_AFTER seconds after", function()
			expect(QuietStart.FIRST_CAT_AFTER).to.equal(10)
			expect(QuietStart.firstCatHolds(true, nil, 100)).to.equal(true)
			expect(QuietStart.firstCatHolds(false, 100, 100)).to.equal(true)
			expect(QuietStart.firstCatHolds(false, 100, 109.9)).to.equal(true)
			expect(QuietStart.firstCatHolds(false, 100, 110)).to.equal(false)
		end)

		it("does not hold for a player whose claim was not seen this session", function()
			expect(QuietStart.firstCatHolds(false, nil, 5)).to.equal(false)
		end)
	end)

	describe("the walk-through hold (Derek 2026-11-16)", function()
		it("holds under bowl first until Tier 2, whatever the step", function()
			expect(QuietStart.tutorialHolds(true, 0, 1)).to.equal(true)
			expect(QuietStart.tutorialHolds(true, 5, 1)).to.equal(true)
			expect(QuietStart.tutorialHolds(true, nil, nil)).to.equal(true)
			expect(QuietStart.tutorialHolds(true, 2, 2)).to.equal(false)
			expect(QuietStart.tutorialHolds(true, 5, 4)).to.equal(false)
		end)

		it("holds under catch first until the last step or Tier 2", function()
			expect(QuietStart.tutorialHolds(false, 4, 1)).to.equal(true)
			expect(QuietStart.tutorialHolds(false, nil, 1)).to.equal(true)
			expect(QuietStart.tutorialHolds(false, 5, 1)).to.equal(false)
			expect(QuietStart.tutorialHolds(false, 3, 2)).to.equal(false)
		end)

		it("holds the pop-ups through the account's first 5 minutes of play (#4946)", function()
			expect(QuietStart.EARLY_SECONDS).to.equal(300)
			local now = 1000000
			-- joined just now on a new account: QuietUntil is now + SECONDS
			local fresh = now + QuietStart.SECONDS
			expect(QuietStart.earlyHolds(fresh, now)).to.equal(true)
			expect(QuietStart.earlyEndsAt(fresh, now)).to.equal(now + QuietStart.EARLY_SECONDS)
			-- 299 s in: still held; 300 s in: free
			expect(QuietStart.earlyHolds(fresh, now + 299)).to.equal(true)
			expect(QuietStart.earlyHolds(fresh, now + 300)).to.equal(false)
			expect(QuietStart.earlyEndsAt(fresh, now + 300)).to.equal(nil)
			-- a returning account with 4 minutes played: one more minute
			local back = now + QuietStart.SECONDS - 240
			expect(QuietStart.earlyHolds(back, now + 59)).to.equal(true)
			expect(QuietStart.earlyHolds(back, now + 60)).to.equal(false)
			-- no attribute (an old account past its quiet start): never held
			expect(QuietStart.earlyHolds(nil, now)).to.equal(false)
		end)

		it("lets one held pop-up through every 5 minutes (#4946)", function()
			expect(QuietStart.POP_GAP_SECONDS).to.equal(300)
			expect(QuietStart.popFree(nil, 10)).to.equal(true)
			expect(QuietStart.popFree(10, 309)).to.equal(false)
			expect(QuietStart.popFree(10, 310)).to.equal(true)
		end)
	end)
end
