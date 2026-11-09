--!strict
-- shared/Products.luau and Catalog.products against #1182 step 1 and monetization-policy: a receipt is granted once
-- per PurchaseId, the saved list stays whole and bounded, only made product ids are sold, and every product holds a
-- fixed set of allowed potions (never coins, golden fish, crates, spins or odds-changing potions). Save version 31.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Products = require(Shared.Products)

	describe("receipts", function()
		it("records a PurchaseId once and keeps the newest RECEIPT_LIMIT", function()
			local receipts: { string } = {}
			expect(Products.granted(receipts, "a")).to.equal(false)
			Products.record(receipts, "a")
			Products.record(receipts, "a")
			expect(#receipts).to.equal(1)
			expect(Products.granted(receipts, "a")).to.equal(true)
			for i = 1, Products.RECEIPT_LIMIT do
				Products.record(receipts, "id" .. i)
			end
			expect(#receipts).to.equal(Products.RECEIPT_LIMIT)
			expect(Products.granted(receipts, "a")).to.equal(false)
			expect(receipts[#receipts]).to.equal("id" .. Products.RECEIPT_LIMIT)
		end)

		it("makes a saved list whole", function()
			expect(Products.sanitize(nil) :: any).to.deepEqual({})
			expect(Products.sanitize("x") :: any).to.deepEqual({})
			expect(
				Products.sanitize({ "a", 5, "", "a", string.rep("x", Products.ID_BYTES + 1), "b" }) :: any
			).to.deepEqual({
				"a",
				"b",
			})
			local long: { string } = {}
			for i = 1, Products.RECEIPT_LIMIT + 5 do
				table.insert(long, "id" .. i)
			end
			local kept = Products.sanitize(long)
			expect(#kept).to.equal(Products.RECEIPT_LIMIT)
			expect(kept[1]).to.equal("id6")
		end)
	end)

	describe("products", function()
		it("sells only made ids that Config names", function()
			expect(Products.forProductId(0)).to.equal(nil)
			expect(Products.forProductId(-1)).to.equal(nil)
			expect(Products.forProductId("1")).to.equal(nil)
			expect(Products.forProductId(123456789123)).to.equal(nil)
			for id, productId in Config.ProductIds do
				expect(Catalog.getProduct(id)).to.be.ok()
				if productId ~= 0 then
					expect((Products.forProductId(productId) :: any).id).to.equal(id)
				end
			end
		end)

		it("holds the plan's fixed potions, only the allowed ones (monetization-policy)", function()
			local want = {
				potion_pack_xs = { big_tip_potion = 2 },
				potion_pack_s = { big_tip_potion = 3, swift_potion = 1, steady_potion = 1 },
				potion_pack_m = { big_tip_potion = 5, swift_potion = 3, steady_potion = 2 },
				potion_pack_l = { big_tip_potion = 10, swift_potion = 6, steady_potion = 6 },
				steady_paw_pack = { steady_potion = 10 }, -- #1168 row 8
				starter_bundle = { big_tip_potion = 10, swift_potion = 5 }, -- #1625
				thank_you_badge = {}, -- #1168 row 4: a supporter mark only
				cafe_pass = {}, -- #1626: everything comes from the paid track's levels
			}
			-- #1625: besides potions only the Starter Bundle's named cat and sign style, never anything random
			local extras = { cats = true, signStyles = true }
			for _, product in Catalog.products do
				expect(Config.ProductIds[product.id]).to.be.ok()
				expect(product.prize.potions :: any).to.deepEqual(want[product.id])
				local any = product.prize :: any
				for key in any do
					expect(
						key == "potions" or (product.id == "starter_bundle" and extras[key] == true)
					).to.equal(true)
				end
				for potionId, count in product.prize.potions do
					expect(Products.ALLOWED_POTIONS[potionId]).to.equal(true)
					expect(Catalog.getPotion(potionId)).to.be.ok()
					expect(count > 0 and count == math.floor(count)).to.equal(true)
				end
				expect(table.isfrozen(product)).to.equal(true)
			end
		end)

		it("sells the Cafe Pass as the season's paid track and nothing else (#1626)", function()
			local pass = Catalog.getProduct("cafe_pass") :: any
			expect(pass).to.be.ok()
			expect(pass.seasonPass).to.equal(true)
			expect(pass.oncePerAccount).to.equal(nil)
			expect(Products.forProductId(3728336202)).to.equal(pass)
			for _, product in Catalog.products do
				expect((product :: any).seasonPass == true).to.equal(product.id == "cafe_pass")
			end
		end)
	end)

	describe("save version 31", function()
		it("starts with no receipts and keeps a saved list whole", function()
			expect(ProfileSchema.VERSION >= 31).to.equal(true)
			expect(#ProfileSchema.template(1000).receipts).to.equal(0)
			local raw: any = ProfileSchema.template(1000)
			raw.version = 30
			raw.receipts = nil
			expect(#ProfileSchema.migrate(raw, 1000).receipts).to.equal(0)
			raw.receipts = { "abc", 7, "abc", "def" }
			expect(ProfileSchema.migrate(raw, 1000).receipts :: any).to.deepEqual({ "abc", "def" })
		end)
	end)

	describe("the Thank You Badge (#1168 row 4)", function()
		it("is once per account, holds nothing, and makes the buyer a supporter for good", function()
			local badge = Catalog.getProduct("thank_you_badge") :: any
			expect(badge.oncePerAccount).to.equal(true)
			expect(badge.supporter).to.equal(true)
			expect(next(badge.prize.potions)).to.equal(nil)
			local profile = ProfileSchema.template(1000)
			expect(Products.isSupporter(profile)).to.equal(false)
			local give, first = Products.prizeFor(profile, badge)
			expect(first).to.equal(true)
			Products.markBought(profile, badge, give.signStyles)
			expect(Products.isSupporter(profile)).to.equal(true)
			expect(Products.sanitizeOnce(profile.onceBought).thank_you_badge).to.equal(true)
			local _, again = Products.prizeFor(profile, badge)
			expect(again).to.equal(false)
		end)
	end)

	describe("the Starter Bundle (#1625)", function()
		local bundle = Catalog.getProduct("starter_bundle") :: any

		it("is Sprinkles, 10 Big Money, 5 Swift and Bakery Stripes, once per account", function()
			expect(bundle.oncePerAccount).to.equal(true)
			expect(bundle.prize.cats).to.deepEqual({ "sprinkles" })
			expect(bundle.prize.signStyles).to.deepEqual({ "bakery_stripes" })
			expect(Config.ProductIds.starter_bundle).to.equal(3728336166)
			local sprinkles = Catalog.getCat("sprinkles") :: any
			expect(sprinkles.rarity).to.equal("Epic")
			expect(sprinkles.exclusive).to.equal(true)
			expect(sprinkles.source).to.equal("shop")
		end)

		it("gives everything the first time, then only the potions", function()
			local profile = ProfileSchema.template(1000)
			local give, first = Products.prizeFor(profile, bundle)
			expect(first).to.equal(true)
			expect(give.cats).to.deepEqual({ "sprinkles" })
			expect(give.signStyles).to.deepEqual({ "bakery_stripes" })
			Products.markBought(profile, bundle, give.signStyles)
			expect(profile.onceBought.starter_bundle).to.equal(true)
			expect(profile.signStyles.bakery_stripes).to.equal(true)
			local again, firstAgain = Products.prizeFor(profile, bundle)
			expect(firstAgain).to.equal(false)
			expect(#again.cats).to.equal(0)
			expect(#again.signStyles).to.equal(0)
			expect(again.potions :: any).to.deepEqual({ big_tip_potion = 10, swift_potion = 5 })
		end)

		it("never marks a repeatable product bought", function()
			local profile = ProfileSchema.template(1000)
			local pack = Catalog.getProduct("potion_pack_s") :: any
			local _, first = Products.prizeFor(profile, pack)
			expect(first).to.equal(true)
			Products.markBought(profile, pack, {})
			expect(next(profile.onceBought)).to.equal(nil)
			local _, still = Products.prizeFor(profile, pack)
			expect(still).to.equal(true)
		end)

		it("keeps only known once-per-account ids in a save (version 35)", function()
			expect(Products.sanitizeOnce({
				starter_bundle = true,
				potion_pack_s = true,
				nope = true,
				x = 1,
			}) :: any).to.deepEqual({ starter_bundle = true })
			expect(Products.sanitizeOnce("x") :: any).to.deepEqual({})
			local raw: any = ProfileSchema.template(1000)
			raw.version = 34
			raw.onceBought = nil
			raw.signStyles = nil
			raw.signStyle = "made_up"
			local profile = ProfileSchema.migrate(raw, 1000)
			expect(next(profile.onceBought)).to.equal(nil)
			expect(next(profile.signStyles)).to.equal(nil)
			expect(profile.signStyle).to.equal(nil)
		end)
	end)
end
