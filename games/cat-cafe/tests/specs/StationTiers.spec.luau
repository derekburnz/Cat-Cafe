--!strict
-- #4539: the Mystery Market, Cat Arcade and Mystic Pool open from Tiers 2, 3 and 4 (shared/StationTiers).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Shared: any = ReplicatedStorage:WaitForChild("Shared")
	local StationTiers = require(Shared.StationTiers)
	local Arcade = require(Shared.Arcade)
	local Traits = require(Shared.Traits)
	local LiveFlags = require(Shared.LiveFlags)

	describe("StationTiers (#4539)", function()
		it(
			"opens the Mystery Market at Tier 2, the Cat Arcade at 3 and the Mystic Pool at 4",
			function()
				expect(StationTiers.tierOf("MysteryMarket")).to.equal(2)
				expect(StationTiers.tierOf(Arcade.TAG)).to.equal(3)
				expect(StationTiers.tierOf(Traits.TAG)).to.equal(4)
				expect(StationTiers.tierOf("CatCannon")).to.equal(nil)
			end
		)
		it("locks below the tier and keeps it open at and past it", function()
			expect(StationTiers.locked("MysteryMarket", 1, true)).to.equal(true)
			expect(StationTiers.locked("MysteryMarket", 2, true)).to.equal(false)
			expect(StationTiers.locked(Arcade.TAG, 2, true)).to.equal(true)
			expect(StationTiers.locked(Arcade.TAG, 3, true)).to.equal(false)
			expect(StationTiers.locked(Traits.TAG, 3, true)).to.equal(true)
			expect(StationTiers.locked(Traits.TAG, 4, true)).to.equal(false)
			expect(StationTiers.locked(Traits.TAG, 10, true)).to.equal(false)
			expect(StationTiers.locked("CatCannon", 1, true)).to.equal(false)
		end)
		it(
			"opens everything while the switch is off, and reads a missing tier as Tier 1",
			function()
				expect(StationTiers.locked(Traits.TAG, 1, false)).to.equal(false)
				expect(StationTiers.locked("MysteryMarket", nil, true)).to.equal(true)
			end
		)
		it("is a switch that starts on", function()
			expect(table.find(LiveFlags.KEYS, StationTiers.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[StationTiers.FLAG] == true).to.equal(false)
		end)
		it("signs and refusals name the tier", function()
			expect(StationTiers.sign(Arcade.TAG)).to.equal("🔒 Unlocks at Tier 3")
			expect(StationTiers.refusal("MysteryMarket")).to.equal("Juniper's cart opens at Tier 2")
		end)
	end)
end
