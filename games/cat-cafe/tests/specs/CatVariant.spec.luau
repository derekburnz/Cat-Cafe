--!strict
-- UI/Components/CatVariant.luau: gold cats under the new name and the old one ("shiny"), until the rename lands.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CatVariant = require(Components:WaitForChild("CatVariant")) :: any

	describe("CatVariant", function()
		it("counts gold and the old shiny as gold", function()
			expect(CatVariant.isGold("gold")).to.equal(true)
			expect(CatVariant.isGold("shiny")).to.equal(true)
			expect(CatVariant.isGold("base")).to.equal(false)
			expect(CatVariant.isGold(nil)).to.equal(false)
		end)

		it("prefers the Gold attribute and falls back to Shiny", function()
			expect(CatVariant.goldFlag(true, nil)).to.equal(true)
			expect(CatVariant.goldFlag(false, true)).to.equal(false)
			expect(CatVariant.goldFlag(nil, true)).to.equal(true)
			expect(CatVariant.goldFlag(nil, nil)).to.equal(false)
		end)

		it("reads goldCollection, then shinyCollection", function()
			expect(
				CatVariant.collection({ goldCollection = { a = 1 }, shinyCollection = { b = 2 } }).a
			).to.equal(1)
			expect(CatVariant.collection({ shinyCollection = { b = 2 } }).b).to.equal(2)
			expect(next(CatVariant.collection({}))).never.to.be.ok()
		end)
	end)
end
