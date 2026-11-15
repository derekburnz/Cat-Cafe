--!strict
-- LateTiers: the three new worlds' switches (Derek 2026-11-14: all 3 areas go live together).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local LateTiers = require(Shared.LateTiers)

	local function reader(on: { [string]: boolean }): (string) -> boolean
		return function(flag: string): boolean
			return on[flag] == true
		end
	end

	describe("LateTiers.throughFor", function()
		it("opens Tiers 8 to 10 together, only when every switch is on", function()
			expect(LateTiers.TOGETHER).to.equal(true)
			expect(LateTiers.throughFor(reader({}))).to.equal(7)
			expect(LateTiers.throughFor(reader({ tier8 = true }))).to.equal(7)
			expect(LateTiers.throughFor(reader({ tier8 = true, tier9 = true }))).to.equal(7)
			expect(LateTiers.throughFor(reader({ tier9 = true, tier10 = true }))).to.equal(7)
			expect(LateTiers.throughFor(reader({ tier10 = true }))).to.equal(7)
			expect(LateTiers.throughFor(reader({ tier8 = true, tier9 = true, tier10 = true }))).to.equal(
				math.huge
			)
		end)

		it("covers every late tier from FIRST with no gap", function()
			local count = 0
			for tier = LateTiers.FIRST, LateTiers.FIRST + 10 do
				if LateTiers.FLAGS[tier] ~= nil then
					count += 1
					expect(tier).to.equal(LateTiers.FIRST + count - 1)
				end
			end
			expect(count).to.equal(3)
		end)
	end)
end
