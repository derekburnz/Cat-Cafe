--!strict
-- shared/RarityFunnel.luau (#3876): rarity_v1's steps, the best rarity in an Index and the steps still due.
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Catalog = require(ReplicatedStorage.Shared.Catalog)
	local RarityFunnel = require(ReplicatedStorage.Shared.RarityFunnel)

	local function firstOf(rarity: string): string
		for _, def in Catalog.cats do
			if def.rarity == rarity then
				return def.id
			end
		end
		error("no " .. rarity .. " cat")
	end

	describe("RarityFunnel", function()
		it("has one step per cat rarity, in rarity order", function()
			expect(#RarityFunnel.STEPS).to.equal(#Catalog.catRarityOrder)
			expect(RarityFunnel.STEPS[1]).to.equal("found_common")
			expect(RarityFunnel.STEPS[6]).to.equal("found_secret")
		end)

		it("reads the best rarity off the Index", function()
			expect(RarityFunnel.best({})).to.equal(0)
			expect(RarityFunnel.best({ [firstOf("Common")] = 1 })).to.equal(1)
			expect(RarityFunnel.best({ [firstOf("Common")] = 1, [firstOf("Epic")] = 2 })).to.equal(3)
			expect(RarityFunnel.best({ [firstOf("Secret")] = 1 })).to.equal(6)
			expect(RarityFunnel.best({ not_a_cat = 1 })).to.equal(0)
		end)

		it("logs every step up to the best one, once", function()
			expect(table.concat(RarityFunnel.due(0, 3), " ")).to.equal("1 2 3")
			expect(table.concat(RarityFunnel.due(3, 3), " ")).to.equal("")
			expect(table.concat(RarityFunnel.due(3, 5), " ")).to.equal("4 5")
			expect(table.concat(RarityFunnel.due(0, 0), " ")).to.equal("")
			expect(table.concat(RarityFunnel.due(5, 9), " ")).to.equal("6")
		end)
	end)
end
