--!strict
-- RoyalPack.luau (#4261): the Royal Cat Pack's contents and its one-time gift of Potion Pack S's potions.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Products = require(Shared.Products)
	local ProfileSchema = require(Shared.ProfileSchema)
	local RoyalPack = require(Shared.RoyalPack)

	describe("contents", function()
		it("lists the Royal Cat and Potion Pack S, each a real thing", function()
			local kinds = {}
			for _, item in RoyalPack.contents() do
				table.insert(kinds, item.kind)
			end
			expect(kinds :: any).to.deepEqual({ "cat", "potions" })
			expect(Catalog.getCat(RoyalPack.CAT)).to.be.ok()
			expect(Catalog.getProduct(RoyalPack.POTION_PRODUCT)).to.be.ok()
			expect(RoyalPack.passId()).never.to.equal(0)
		end)

		it("pays Potion Pack S's potion set, a copy", function()
			local product = Catalog.getProduct(RoyalPack.POTION_PRODUCT) :: any
			local potions = RoyalPack.potions()
			expect(potions :: any).to.deepEqual(product.prize.potions)
			potions.x = 1
			expect(product.prize.potions.x).to.equal(nil)
		end)
	end)

	describe("gift", function()
		it("is owed only to an owner, once", function()
			local profile = ProfileSchema.template(1000)
			expect(RoyalPack.due(profile, false)).to.equal(false)
			expect(RoyalPack.gift(profile, false)).to.equal(nil)
			expect(RoyalPack.due(profile, true)).to.equal(true)
			expect(RoyalPack.gift(profile, true) :: any).to.deepEqual(RoyalPack.potions())
			expect(profile.onceBought[RoyalPack.MARK]).to.equal(true)
			expect(RoyalPack.due(profile, true)).to.equal(false)
			expect(RoyalPack.gift(profile, true)).to.equal(nil)
		end)

		it("keeps its mark through a save clean", function()
			expect(Products.sanitizeOnce({ [RoyalPack.MARK] = true })[RoyalPack.MARK]).to.equal(
				true
			)
		end)
	end)
end
