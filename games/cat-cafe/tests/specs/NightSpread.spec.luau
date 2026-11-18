--!strict
-- shared/NightSpread.luau (#5164): dusk's strays leave in runs of PER_STEP, in order, none lost or repeated.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local NightSpread = require(Shared.NightSpread)

	describe("NightSpread", function()
		it("cuts a list into runs of at most the size, in order", function()
			local list = {}
			for i = 1, 19 do
				table.insert(list, i)
			end
			local runs = NightSpread.chunks(list, 8)
			expect(#runs).to.equal(3)
			expect(#runs[1]).to.equal(8)
			expect(#runs[3]).to.equal(3)
			local seen = 0
			for _, run in runs do
				for _, n in run do
					seen += 1
					expect(n).to.equal(seen)
				end
			end
			expect(seen).to.equal(19)
		end)

		it("gives no runs for an empty list and never a size under 1", function()
			expect(#NightSpread.chunks({}, 8)).to.equal(0)
			expect(#NightSpread.chunks({ 1, 2 }, 0)).to.equal(2)
		end)

		it("is off by default", function()
			local LiveFlags = require(Shared.LiveFlags)
			expect(LiveFlags.OFF_BY_DEFAULT[NightSpread.FLAG]).to.equal(true)
		end)
	end)
end
