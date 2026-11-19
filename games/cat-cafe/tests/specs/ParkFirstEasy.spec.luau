--!strict
-- shared/ParkFirstEasy.luau (#5182): the Park keeps the Alleyway's wider bands until the first Park catch.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local LiveFlags = require(Shared.LiveFlags)
	local ParkFirstEasy = require(Shared.ParkFirstEasy)

	describe("ParkFirstEasy", function()
		it("widens only Park catches, only before the first, only with the switch on", function()
			expect(ParkFirstEasy.scale("park", false, true)).to.equal(ParkFirstEasy.SCALE)
			expect(ParkFirstEasy.scale("park", true, true)).to.equal(1)
			expect(ParkFirstEasy.scale("park", false, false)).to.equal(1)
			expect(ParkFirstEasy.scale("alley", false, true)).to.equal(1)
			expect(ParkFirstEasy.scale(nil, false, true)).to.equal(1)
		end)

		it("is never wider than the widest area scale, so Config.spec S24 still holds", function()
			local widest = 1
			for _, def in Catalog.areas do
				widest = math.max(widest, (def :: any).catchWindowScale or 1)
			end
			expect(ParkFirstEasy.SCALE <= widest).to.equal(true)
			expect(Catalog.getArea(ParkFirstEasy.AREA) ~= nil).to.equal(true)
		end)

		it("is off by default", function()
			expect(LiveFlags.OFF_BY_DEFAULT[ParkFirstEasy.FLAG]).to.equal(true)
			expect(LiveFlags.OFF_BY_DEFAULT[ParkFirstEasy.CALM_FLAG]).to.equal(true)
		end)

		it(
			"#5496: calm Park misses only on touch or console, only before the first Park catch",
			function()
				expect(ParkFirstEasy.calm("park", false, "phone", true)).to.equal(true)
				expect(ParkFirstEasy.calm("park", false, "tablet", true)).to.equal(true)
				expect(ParkFirstEasy.calm("park", false, "console", true)).to.equal(true)
				expect(ParkFirstEasy.calm("park", false, "pc", true)).to.equal(false)
				expect(ParkFirstEasy.calm("park", false, nil, true)).to.equal(false)
				expect(ParkFirstEasy.calm("park", true, "phone", true)).to.equal(false)
				expect(ParkFirstEasy.calm("park", false, "phone", false)).to.equal(false)
				expect(ParkFirstEasy.calm("alley", false, "phone", true)).to.equal(false)
			end
		)
	end)
end
