--!strict
-- shared/FreeStart (#5533, switches freeStart, streetCats and goalChip): the play first start for new saves.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local FreeStart = require(Shared.FreeStart)

	describe("FreeStart.joins", function()
		it("takes a brand new save on its first session while the switch is on", function()
			expect(FreeStart.joins(true, 1, 0, nil, nil)).to.equal(true)
			expect(FreeStart.joins(true, 0, 0, nil, nil)).to.equal(true)
		end)
		it("leaves everyone else as they are", function()
			expect(FreeStart.joins(false, 1, 0, nil, nil)).to.equal(false) -- switch off
			expect(FreeStart.joins(true, 2, 0, nil, nil)).to.equal(false) -- a later session
			expect(FreeStart.joins(true, 1, 1, nil, nil)).to.equal(false) -- a step done
			expect(FreeStart.joins(true, 1, 0, true, nil)).to.equal(false) -- joined already
			expect(FreeStart.joins(true, 1, 0, nil, "bowl")).to.equal(false) -- in an orderSplit arm
		end)
		it(
			"takes a save that left before its first step on a later session with spawnAlley (#5616)",
			function()
				expect(FreeStart.joins(true, 2, 0, nil, nil, true)).to.equal(true)
				expect(FreeStart.joins(true, 5, 0, nil, nil, true)).to.equal(true)
				expect(FreeStart.joins(true, 2, 1, nil, nil, true)).to.equal(false) -- a step done
				expect(FreeStart.joins(true, 2, 0, nil, "bowl", true)).to.equal(false) -- in an orderSplit arm
				expect(FreeStart.joins(false, 2, 0, nil, nil, true)).to.equal(false) -- freeStart off
			end
		)
	end)

	describe("FreeStart.active", function()
		it("holds for a joined save below UNTIL_TIER only", function()
			expect(FreeStart.active(true, 1)).to.equal(true)
			expect(FreeStart.active(true, FreeStart.UNTIL_TIER - 1)).to.equal(true)
			expect(FreeStart.active(true, FreeStart.UNTIL_TIER)).to.equal(false)
			expect(FreeStart.active(nil, 1)).to.equal(false)
		end)
	end)

	describe("FreeStart.streetDue and easyDue", function()
		it("keeps the street's cats for STREET_SECONDS of play", function()
			expect(FreeStart.streetDue(true, 0)).to.equal(true)
			expect(FreeStart.streetDue(true, FreeStart.STREET_SECONDS)).to.equal(false)
			expect(FreeStart.streetDue(nil, 0)).to.equal(false)
		end)
		it("makes the first EASY_CATCHES plain Common or Uncommon catches easy", function()
			expect(FreeStart.easyDue(true, 0, "Common", nil)).to.equal(true)
			expect(FreeStart.easyDue(true, 2, "Uncommon", "base")).to.equal(true)
			expect(FreeStart.easyDue(true, FreeStart.EASY_CATCHES, "Common", nil)).to.equal(false)
			expect(FreeStart.easyDue(true, 0, "Rare", nil)).to.equal(false)
			expect(FreeStart.easyDue(true, 0, "Rare", nil, true)).to.equal(true) -- #5562: any rarity in the Park
			expect(FreeStart.easyDue(true, 2, "Legendary", "base", true)).to.equal(true)
			expect(FreeStart.easyDue(true, FreeStart.EASY_CATCHES, "Rare", nil, true)).to.equal(
				false
			)
			expect(FreeStart.easyDue(true, 0, "Common", "gold")).to.equal(false)
			expect(FreeStart.easyDue(nil, 0, "Common", nil)).to.equal(false)
		end)
	end)

	describe("FreeStart.goals and paid bits", function()
		it("gives the two goals for an active save, nil otherwise", function()
			local goals = FreeStart.goals(true, 1, 1, 0)
			expect(goals ~= nil and goals.caught).to.equal(true)
			expect(goals ~= nil and goals.home).to.equal(false)
			expect(FreeStart.goals(true, FreeStart.UNTIL_TIER, 1, 1)).to.equal(nil)
			expect(FreeStart.goals(nil, 1, 0, 0)).to.equal(nil)
		end)
		it("reads each goal's paid bit", function()
			expect(FreeStart.unpaid(nil, FreeStart.PAID_CAUGHT)).to.equal(true)
			expect(FreeStart.unpaid(FreeStart.PAID_CAUGHT, FreeStart.PAID_CAUGHT)).to.equal(false)
			expect(FreeStart.unpaid(FreeStart.PAID_CAUGHT, FreeStart.PAID_HOME)).to.equal(true)
			expect(FreeStart.unpaid(3, FreeStart.PAID_HOME)).to.equal(false)
		end)
		it("keeps only a whole startPaid from 0 to 3", function()
			expect(FreeStart.validPaid(2)).to.equal(2)
			expect(FreeStart.validPaid(4)).to.equal(nil)
			expect(FreeStart.validPaid(1.5)).to.equal(nil)
			expect(FreeStart.validPaid(0 / 0)).to.equal(nil)
			expect(FreeStart.validPaid("1")).to.equal(nil)
		end)
	end)

	describe("FreeStart.quiet", function()
		it("is off for a player without the attribute", function()
			expect(FreeStart.quiet(1)).to.equal(false)
		end)
	end)
end
