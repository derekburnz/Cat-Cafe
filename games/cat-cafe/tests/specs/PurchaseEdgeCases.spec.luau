--!strict
-- #2118: purchase edge cases the cloud runner can check. ProductService.processReceipt itself needs Roblox's
-- MarketplaceService and a DataStore, so these specs run its pure steps (shared/Products) in the same order the service
-- does: the PurchaseId is recorded first, then the once-per-account mark and the prize, with no yield between. The
-- parts that need a live server (a save failing, the DataStore down, a pass refunded) are the Studio checklist in
-- docs/growth/purchase-edge-cases-2026-11-07.md.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Products = require(Shared.Products)

	-- One delivery of a receipt, as ProductService.processReceipt does it. Returns the potions it paid and the cats.
	local function deliver(
		profile: any,
		product: any,
		purchaseId: string
	): ({ [string]: number }, { string })
		if Products.granted(profile.receipts, purchaseId) then
			return {}, {}
		end
		Products.record(profile.receipts, purchaseId)
		local give = Products.prizeFor(profile, product)
		Products.markBought(profile, product, give.signStyles)
		return give.potions, give.cats
	end

	-- What a save and a rejoin do to a profile: only what ProfileSchema.migrate keeps comes back.
	local function rejoin(profile: any): any
		local copy: any = {}
		for key, value in profile do
			copy[key] = value
		end
		copy.receipts = table.clone(profile.receipts)
		copy.onceBought = table.clone(profile.onceBought)
		copy.signStyles = table.clone(profile.signStyles)
		return ProfileSchema.migrate(copy, 2000)
	end

	local function total(paid: { [string]: number }): number
		local sum = 0
		for _, count in paid do
			sum += count
		end
		return sum
	end

	local pack = Catalog.getProduct("potion_pack_s") :: any
	local bundle = Catalog.getProduct("starter_bundle") :: any

	describe("the same receipt delivered twice (case 5)", function()
		it("pays a repeatable product once per PurchaseId", function()
			local profile: any = ProfileSchema.template(1000)
			local first = deliver(profile, pack, "p1")
			local again = deliver(profile, pack, "p1")
			expect(total(first) > 0).to.equal(true)
			expect(total(again)).to.equal(0)
			expect(#profile.receipts).to.equal(1)
		end)

		it("pays two different PurchaseIds of a repeatable product twice", function()
			local profile: any = ProfileSchema.template(1000)
			local a = deliver(profile, pack, "p1")
			local b = deliver(profile, pack, "p2")
			expect(total(a)).to.equal(total(b))
			expect(#profile.receipts).to.equal(2)
		end)

		it(
			"gives the Starter Bundle's cat and sign once, even for two different PurchaseIds",
			function()
				local profile: any = ProfileSchema.template(1000)
				local _, cats1 = deliver(profile, bundle, "s1")
				local potions2, cats2 = deliver(profile, bundle, "s2")
				expect(#cats1).to.equal(1)
				expect(#cats2).to.equal(0)
				expect(total(potions2) > 0).to.equal(true) -- the Robux were spent: the potions still come
			end
		)
	end)

	describe("rejoining after a purchase (case 2)", function()
		it("keeps the receipt, so a delivery after a rejoin pays nothing", function()
			local profile: any = ProfileSchema.template(1000)
			deliver(profile, pack, "p1")
			local back = rejoin(profile)
			expect(Products.granted(back.receipts, "p1")).to.equal(true)
			expect(total((deliver(back, pack, "p1")))).to.equal(0)
		end)

		it("keeps the once-per-account mark and the sign style the bundle gave", function()
			local profile: any = ProfileSchema.template(1000)
			deliver(profile, bundle, "s1")
			local back = rejoin(profile)
			expect(back.onceBought.starter_bundle).to.equal(true)
			expect(back.signStyles.bakery_stripes).to.equal(true)
			local _, cats = deliver(back, bundle, "s9")
			expect(#cats).to.equal(0)
		end)

		it(
			"pays a receipt that was never saved (the save failed or the player left at once)",
			function()
				-- the grant happened in memory, the save did not reach the DataStore: the next join starts from the old
				-- save, which has no id, so Roblox's redelivery pays once, not zero times and not twice
				local saved: any = ProfileSchema.template(1000)
				local lost: any = rejoin(saved)
				deliver(lost, pack, "p1") -- the unsaved session
				local again: any = rejoin(saved) -- the old save is what comes back
				local paid = deliver(again, pack, "p1")
				expect(total(paid) > 0).to.equal(true)
				expect(total((deliver(again, pack, "p1")))).to.equal(0)
			end
		)

		it(
			"does not pay a Starter Bundle sign twice when the receipt falls off the list",
			function()
				local profile: any = ProfileSchema.template(1000)
				deliver(profile, bundle, "s1")
				for i = 1, Products.RECEIPT_LIMIT do
					Products.record(profile.receipts, "later" .. i) -- 100 newer purchases push "s1" off the list
				end
				expect(Products.granted(profile.receipts, "s1")).to.equal(false)
				local _, cats = deliver(profile, bundle, "s1")
				expect(#cats).to.equal(0) -- the once-per-account mark does not depend on the list
			end
		)
	end)

	describe("what a bad save or a bad id cannot do (cases 1, 4, 6)", function()
		it("ignores a receipt id that is not a usable string", function()
			local list = Products.sanitize({ 5, "", string.rep("x", Products.ID_BYTES + 1), "ok" })
			expect(table.concat(list, ",")).to.equal("ok")
		end)

		it(
			"never sells a product id Config does not name, so an unknown receipt pays nothing",
			function()
				expect(Products.forProductId(0)).to.equal(nil)
				expect(Products.forProductId(nil)).to.equal(nil)
				expect(Products.forProductId(-5)).to.equal(nil)
			end
		)

		it("keeps a free player's earned coins and cats through a save and a rejoin", function()
			local profile: any = ProfileSchema.template(1000)
			profile.coins = 12345
			local cats = 0
			for _ in profile.cats do
				cats += 1
			end
			local back = rejoin(profile)
			expect(back.coins).to.equal(12345)
			local after = 0
			for _ in back.cats do
				after += 1
			end
			expect(after).to.equal(cats)
			expect(#back.receipts).to.equal(0)
			expect(next(back.onceBought)).to.equal(nil)
		end)
	end)
end
