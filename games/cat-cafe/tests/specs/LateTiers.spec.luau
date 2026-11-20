--!strict
-- LateTiers: Tiers 8 to 10 launched together (Derek 2026-11-14) and their switches were retired (#4656), so no late
-- tier waits for a switch now; the specs' setOpen override still closes them for tests.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LateTiers = require(Shared.LateTiers)

	local function reader(on: { [string]: boolean }): (string) -> boolean
		return function(flag: string): boolean
			return on[flag] == true
		end
	end

	describe("LateTiers.throughFor", function()
		it("opens every tier with no switch on, since no late tier has one now", function()
			expect(next(LateTiers.FLAGS)).to.equal(nil)
			expect(LateTiers.throughFor(reader({}))).to.equal(math.huge)
		end)

		it("opens Tiers 8 to 10 with the specs' override cleared", function()
			LateTiers.setOpen(nil)
			expect(LateTiers.tierOpen(8)).to.equal(true)
			expect(LateTiers.tierOpen(9)).to.equal(true)
			expect(LateTiers.tierOpen(10)).to.equal(true)
		end)
	end)
end
