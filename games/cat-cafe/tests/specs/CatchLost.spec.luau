--!strict
-- shared/CatchLost.luau (#5500 part 1): why a started catch ended with no cat.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatchLost = require(Shared.CatchLost)
	local LiveFlags = require(Shared.LiveFlags)

	describe("CatchLost", function()
		it("names a forfeit before the ring that missed", function()
			expect(CatchLost.missReason("too_far", "missed_late")).to.equal("too_far")
			expect(CatchLost.missReason("carrying", nil)).to.equal("carrying")
		end)

		it("names the first missed ring, else missed", function()
			expect(CatchLost.missReason(nil, "missed_early")).to.equal("missed_early")
			expect(CatchLost.missReason(nil, "missed_late")).to.equal("missed_late")
			expect(CatchLost.missReason(nil, "missed_none")).to.equal("missed_none")
			expect(CatchLost.missReason(nil, nil)).to.equal("missed")
			expect(CatchLost.missReason(nil, "something_else")).to.equal("missed")
		end)

		it("is off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[CatchLost.FLAG]).to.equal(true)
		end)
	end)
end
