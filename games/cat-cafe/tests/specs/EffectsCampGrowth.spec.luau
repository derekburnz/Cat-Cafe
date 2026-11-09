--!strict
-- The camp growth (#2687 part 2): which townsfolk cats sit at each camp. CampGrowth.luau places Model-Agent's real
-- models, so where they stand is checked in Studio. Written by the Animation-Engineer.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Effects = Client:WaitForChild("Effects")
	local Logic = require(Effects:WaitForChild("Logic")) :: any

	local areas = { "park", "neighbourhood", "woods", "sewer", "desert", "ruins" }

	describe("Effects camp growth", function()
		it("seats the camp's own townsfolk cat first, then the next camps'", function()
			expect(Logic.folkAt(areas, "park", 1)).to.equal(1)
			expect(Logic.folkAt(areas, "park", 2)).to.equal(2)
			expect(Logic.folkAt(areas, "park", 3)).to.equal(3)
			expect(Logic.folkAt(areas, "sewer", 1)).to.equal(4)
		end)

		it("wraps round the list, so the Ruins' crowd is three different cats", function()
			expect(Logic.folkAt(areas, "ruins", 1)).to.equal(6)
			expect(Logic.folkAt(areas, "ruins", 2)).to.equal(1)
			expect(Logic.folkAt(areas, "ruins", 3)).to.equal(2)
		end)

		it("seats nobody at an area it does not know", function()
			expect(Logic.folkAt(areas, "alley", 1)).to.equal(nil)
			expect(Logic.folkAt({}, "park", 1)).to.equal(nil)
		end)
	end)
end
