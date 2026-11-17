--!strict
-- ReturnAB.luau (Derek 2026-11-17): the tomorrowCard and palDay 50/50s by user id, new accounts only.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local ReturnAB = require(Shared.ReturnAB)

	local CARD = ReturnAB.TESTS.tomorrowCard.startDay
	local PAL = ReturnAB.TESTS.palDay.startDay

	describe("ReturnAB", function()
		it("splits by floor(id / 2) and floor(id / 4), never id % 2", function()
			expect(ReturnAB.group("tomorrowCard", 4, CARD)).to.equal("on")
			expect(ReturnAB.group("tomorrowCard", 5, CARD)).to.equal("on")
			expect(ReturnAB.group("tomorrowCard", 6, CARD)).to.equal("off")
			expect(ReturnAB.group("palDay", 4, PAL)).to.equal("off")
			expect(ReturnAB.group("palDay", 8, PAL)).to.equal("on")
		end)

		it("is close to 50/50 and crosses the intro split evenly", function()
			local cells: { [string]: number } = {}
			for id = 1, 8000 do
				local key = tostring(id % 2)
					.. (ReturnAB.group("tomorrowCard", id, PAL) or "x")
					.. (ReturnAB.group("palDay", id, PAL) or "x")
				cells[key] = (cells[key] or 0) + 1
			end
			local n = 0
			for _, count in cells do
				n += 1
				expect(count).to.equal(1000)
			end
			expect(n).to.equal(8)
		end)

		it("leaves out accounts first seen before the start, and Studio ids", function()
			expect(ReturnAB.group("tomorrowCard", 6, CARD - 1)).to.equal(nil)
			expect(ReturnAB.group("palDay", 8, PAL - 1)).to.equal(nil)
			expect(ReturnAB.group("tomorrowCard", -1, CARD)).to.equal(nil)
			expect(ReturnAB.group("tomorrowCard", 6, nil)).to.equal(nil)
		end)

		it("blocks only the off group", function()
			expect(ReturnAB.allows("tomorrowCard", 6, CARD)).to.equal(false)
			expect(ReturnAB.allows("tomorrowCard", 4, CARD)).to.equal(true)
			expect(ReturnAB.allows("tomorrowCard", 6, CARD - 1)).to.equal(true)
		end)
	end)
end
