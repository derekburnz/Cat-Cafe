--!strict
-- #5414: with `plushSecret` on, the Booth Plush Cat earns like Abyss (the Tier 9 Secret); off, as before.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local CatStats = require(Shared.CatStats)

	describe("plushSecret", function()
		it("the plush earns as the Tier 9 Secret only when on", function()
			local plush = Catalog.getCat(CatStats.PLUSH_ID)
			local like = Catalog.getCat(CatStats.PLUSH_LIKE)
			expect(plush ~= nil and like ~= nil).to.equal(true)
			if plush == nil or like == nil then
				return
			end
			expect(like.rarity).to.equal("Secret")
			expect(like.secretArea).to.equal("waterpark")
			expect(CatStats.earnsAs(plush, true)).to.equal(like)
			expect(CatStats.earnsAs(plush, false)).to.equal(plush)
			expect(plush.exclusive).to.equal(true) -- it stays Exclusive
		end)

		it("leaves every other cat alone", function()
			local like = Catalog.getCat(CatStats.PLUSH_LIKE)
			if like ~= nil then
				expect(CatStats.earnsAs(like, true)).to.equal(like)
			end
		end)

		it("the switch off by default keeps today's rate", function()
			expect(
				CatStats.maxRating(CatStats.PLUSH_ID, 9)
					< CatStats.maxRating(CatStats.PLUSH_LIKE, 9)
			).to.equal(true)
		end)
	end)
end
