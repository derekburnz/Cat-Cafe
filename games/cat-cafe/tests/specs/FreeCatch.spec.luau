--!strict
-- FreeCatch: phone, tablet and console catches below Tier 2 are the tutorial's (Derek 2026-11-14, #4307).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local FreeCatch = require(Shared.FreeCatch)
	local LiveFlags = require(Shared.LiveFlags)

	describe("FreeCatch.applies", function()
		it("makes Tier 1 catches free on a phone, tablet or console", function()
			expect(FreeCatch.applies(true, "phone", 1)).to.equal(true)
			expect(FreeCatch.applies(true, "tablet", 1)).to.equal(true)
			expect(FreeCatch.applies(true, "console", 1)).to.equal(true)
		end)

		it("leaves a computer, an unreported device and Tier 2 on as they are", function()
			expect(FreeCatch.applies(true, "pc", 1)).to.equal(false)
			expect(FreeCatch.applies(true, nil, 1)).to.equal(false)
			expect(FreeCatch.applies(true, "phone", 2)).to.equal(false)
			expect(FreeCatch.applies(true, "console", 5)).to.equal(false)
		end)

		it("stops with its switch, which is on by default", function()
			expect(FreeCatch.applies(false, "phone", 1)).to.equal(false)
			expect(table.find(LiveFlags.KEYS, FreeCatch.FLAG) ~= nil).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[FreeCatch.FLAG]).never.to.be.ok()
		end)
	end)
end
