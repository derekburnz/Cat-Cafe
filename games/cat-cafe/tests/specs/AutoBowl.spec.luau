--!strict
-- AutoBowl.luau (#4266): when the Auto Bowl pass acts, and which owned food its refill uses.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local AutoBowl = require(Shared.AutoBowl)
	local Catalog = require(Shared.Catalog)
	local Settings = require(Shared.Settings)

	describe("active", function()
		it("needs the switch known and on, the pass owned and the pass made", function()
			local made = AutoBowl.passId() ~= 0
			expect(AutoBowl.active(true, true, true)).to.equal(made)
			expect(AutoBowl.active(false, true, true)).to.equal(false)
			expect(AutoBowl.active(true, false, true)).to.equal(false)
			expect(AutoBowl.active(true, true, false)).to.equal(false)
		end)
	end)

	describe("bestFood", function()
		it("picks the owned food with the highest sortOrder, and nil with none owned", function()
			expect(AutoBowl.bestFood(Catalog.lures, {})).to.equal(nil)
			expect(AutoBowl.bestFood(Catalog.lures, { kibble = 3 })).to.equal("kibble")
			expect(AutoBowl.bestFood(Catalog.lures, { kibble = 3, salmon = 1, tuna = 2 })).to.equal(
				"salmon"
			)
			expect(AutoBowl.bestFood(Catalog.lures, { kibble = 3, salmon = 0 })).to.equal("kibble")
		end)

		it("never names a food the player does not have", function()
			for _, lure in Catalog.lures do
				local have = { [lure.id] = 1 }
				expect(AutoBowl.bestFood(Catalog.lures, have)).to.equal(lure.id)
			end
		end)
	end)

	describe("settings", function()
		it("saves the three switches, on by default", function()
			local defaults = Settings.defaults() :: any
			expect(defaults.autoBowlClaim).to.equal(true)
			expect(defaults.autoBowlRefill).to.equal(true)
			expect(defaults.bowlNewCatCard).to.equal(true)
			local kept = Settings.sanitize({ autoBowlClaim = false, bowlNewCatCard = false }) :: any
			expect(kept.autoBowlClaim).to.equal(false)
			expect(kept.autoBowlRefill).to.equal(true)
			expect(kept.bowlNewCatCard).to.equal(false)
			expect(Settings.clean(AutoBowl.KEYS.claim, "yes")).to.equal(nil)
		end)
	end)
end
