--!strict
-- UI/Components/CatVariant.luau: what the UI counts as a gold or a rainbow cat.
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

		it("names the coat and its money (F99)", function()
			expect(CatVariant.isRainbow("rainbow")).to.equal(true)
			expect(CatVariant.isRainbow("gold")).to.equal(false)
			expect(CatVariant.coat("rainbow")).to.equal("rainbow")
			expect(CatVariant.coat("gold")).to.equal("gold")
			expect(CatVariant.coat(nil)).to.equal("base")
			expect(CatVariant.word("rainbow")).to.equal("Rainbow ")
			expect(CatVariant.word("base")).to.equal("")
			expect(CatVariant.multiplier("rainbow")).to.equal(3)
			expect(CatVariant.multiplier("base")).to.equal(1)
			expect(CatVariant.multiplier("rainbow") / CatVariant.multiplier("gold")).to.equal(2)
		end)

		it("reads rainbowCollection, else nothing", function()
			expect(CatVariant.rainbowCollection({ rainbowCollection = { a = 2 } }).a).to.equal(2)
			expect(next(CatVariant.rainbowCollection({}))).never.to.be.ok()
		end)
	end)

	describe("CatVariant.spawnLine (F99)", function()
		it("words the rainbow stray's toast as the server's shout-out", function()
			expect(CatVariant.spawnLine("Tabby", "Woods")).to.equal(
				"🌈 A Rainbow Tabby is out in the Woods!"
			)
		end)
	end)
end
