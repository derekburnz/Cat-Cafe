--!strict
-- UI/Components/TagHeight (#3696): a cat's name and money label follows the top of its model.
-- Written by the vfx-animator.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local TagHeight = require(Components:WaitForChild("TagHeight")) :: any

	describe("Tag height", function()
		it("goes up at once when the cat stands up or wears a hat", function()
			expect(TagHeight.settle(1.2, 2.1)).to.equal(2.1)
			expect(TagHeight.settle(1.2, 1.2 + TagHeight.RISE + 0.01)).to.equal(
				1.2 + TagHeight.RISE + 0.01
			)
		end)

		it("does not shake with the breath or the tail", function()
			expect(TagHeight.settle(1.2, 1.2 + TagHeight.RISE / 2)).to.equal(1.2)
			expect(TagHeight.settle(1.2, 1.1)).to.equal(1.2)
			expect(TagHeight.settle(1.2, 1.2 - TagHeight.FALL + 0.01)).to.equal(1.2)
		end)

		it("comes down when the cat sits again", function()
			expect(TagHeight.settle(2.1, 1.2)).to.equal(1.2)
		end)

		it("keeps its place on a measure that cannot be the cat", function()
			expect(TagHeight.settle(1.2, TagHeight.MAX + 1)).to.equal(1.2)
			expect(TagHeight.settle(1.2, -1)).to.equal(1.2)
			expect(TagHeight.settle(1.2, 0 / 0)).to.equal(1.2)
		end)

		it("checks often enough to be seen as one move, and not every frame", function()
			expect(TagHeight.CHECK_SECONDS <= 1).to.equal(true)
			expect(TagHeight.CHECK_SECONDS >= 0.25).to.equal(true)
		end)

		it("measures only the cats whose tag can be seen", function()
			expect(TagHeight.near(10, 70)).to.equal(true)
			expect(TagHeight.near(70 + TagHeight.NEAR_MARGIN, 70)).to.equal(true)
			expect(TagHeight.near(71 + TagHeight.NEAR_MARGIN, 70)).to.equal(false)
		end)
	end)
end
