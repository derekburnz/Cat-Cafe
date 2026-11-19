--!strict
-- UI/Components/MarketBangLogic.fitSize (#5390): the "!" bubble's words get a size that fits their box by hand, so a
-- billboard never draws them blank the way TextScaled sometimes did.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local MarketBangLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("MarketBangLogic")
	) :: any

	describe("MarketBangLogic.fitSize", function()
		it("fits the height for one short line and the width for a long one", function()
			expect(MarketBangLogic.fitSize("Hi", 200, 23)).to.equal(20)
			expect(MarketBangLogic.fitSize("📦 2 crates to open", 120, 40)).to.equal(11)
		end)

		it("splits on the line break and never goes under 8 or over 100", function()
			local two = MarketBangLogic.fitSize("🍪 Treats and perks\nto check out!", 400, 46)
			expect(two).to.equal(20)
			expect(MarketBangLogic.fitSize("words", 0, 0)).to.equal(8)
			expect(MarketBangLogic.fitSize("a", 1000, 1000)).to.equal(100)
		end)
	end)
end
