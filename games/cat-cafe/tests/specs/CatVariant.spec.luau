--!strict
-- UI/Components/CatVariant.luau: what the UI counts as a gold cat.
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local Components = Client:WaitForChild("UI"):WaitForChild("Components")
	local CatVariant = require(Components:WaitForChild("CatVariant")) :: any

	describe("CatVariant", function()
		it("counts only the gold variant as gold", function()
			expect(CatVariant.isGold("gold")).to.equal(true)
			expect(CatVariant.isGold("base")).to.equal(false)
			expect(CatVariant.isGold("shiny")).to.equal(false)
			expect(CatVariant.isGold(nil)).to.equal(false)
		end)

		it("reads goldCollection, else nothing", function()
			expect(CatVariant.collection({ goldCollection = { a = 1 } }).a).to.equal(1)
			expect(next(CatVariant.collection({}))).never.to.be.ok()
		end)
	end)
end
