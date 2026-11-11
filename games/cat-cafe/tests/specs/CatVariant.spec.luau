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
			expect(CatVariant.multiplier("rainbow")).to.equal(2)
			expect(CatVariant.multiplier("base")).to.equal(1)
			expect(CatVariant.multiplier("rainbow") > CatVariant.multiplier("gold")).to.equal(true)
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

		it(
			"names a cat with its coat: Forest Cat, Gold Forest Cat, Rainbow Forest Cat (#2110)",
			function()
				expect(CatVariant.name("Forest Cat", "base")).to.equal("Forest Cat")
				expect(CatVariant.name("Forest Cat", nil)).to.equal("Forest Cat")
				expect(CatVariant.name("Forest Cat", "gold")).to.equal("Gold Forest Cat")
				expect(CatVariant.name("Forest Cat", "rainbow")).to.equal("Rainbow Forest Cat")
				-- never "Stray": a cat whose name is not known yet reads "Cat"
				expect(CatVariant.name(nil, "gold")).to.equal("Gold Cat")
				expect(CatVariant.name("", nil)).to.equal("Cat")
			end
		)
	end)

	describe("CatchHeader.fromStray (#3224)", function()
		local CatchHeader = require(Components:WaitForChild("CatchHeader")) :: any
		local function stray(attributes: { [string]: any }): any
			return {
				GetAttribute = function(_self: any, name: string): any
					return attributes[name]
				end,
			}
		end
		local function defOf(catId: string?): any
			return if catId == "sand_cat" then { name = "Sand Cat", rarity = "Rare" } else nil
		end

		it("names a stray from its own attributes when no prompt card is up", function()
			local named = CatchHeader.fromStray(
				"s1",
				stray({
					CatId = "sand_cat",
					CatName = "Sand Cat",
					Rarity = "Rare",
					Variant = "base",
				}),
				defOf
			)
			expect(named.strayId).to.equal("s1")
			expect(named.catName).to.equal("Sand Cat")
			expect(named.rarity).to.equal("Rare")
			expect(named.shiny).to.equal(false)
			expect(named.rainbow).to.equal(false)
		end)

		it("reads the coat, and falls back to the catalog for a missing name or rarity", function()
			local gold =
				CatchHeader.fromStray("s2", stray({ CatId = "sand_cat", Variant = "gold" }), defOf)
			expect(gold.catName).to.equal("Sand Cat")
			expect(gold.rarity).to.equal("Rare")
			expect(gold.shiny).to.equal(true)
			local rainbow = CatchHeader.fromStray(
				"s3",
				stray({ CatId = "sand_cat", Variant = "rainbow", Gold = false }),
				defOf
			)
			expect(rainbow.rainbow).to.equal(true)
			expect(rainbow.shiny).to.equal(false)
			local older =
				CatchHeader.fromStray("s4", stray({ CatId = "sand_cat", Gold = true }), defOf)
			expect(older.shiny).to.equal(true)
		end)

		it("gives nothing for no model or a model with no cat on it", function()
			expect(CatchHeader.fromStray("s5", nil, defOf)).to.equal(nil)
			expect(CatchHeader.fromStray("s6", stray({}), defOf)).to.equal(nil)
		end)
	end)
end
