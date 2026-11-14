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
	local Traits = require(Shared.Traits)

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
				starter_bundle = { big_tip_potion = 10, swift_potion = 5, steady_potion = 5 }, -- #1625, #2850
				thank_you_badge = {}, -- #1168 row 4: a supporter mark only
				cafe_pass = {}, -- #1626: everything comes from the paid track's levels
				trait_tokens_20 = {}, -- #3864: Trait Tokens only
				trait_tokens_50 = {},
				-- #3996: Today's Deal (todays-deal-3996.md section 2)
				deal_1 = { big_tip_potion = 5, swift_potion = 2 },
				deal_2 = {}, -- 7 Trait Tokens
				deal_3 = { steady_potion = 10, big_tip_potion = 2 },
				deal_4 = { big_tip_potion = 4, swift_potion = 1, steady_potion = 2 },
			}
			-- #1625: besides potions only the Starter Bundle's named cat and sign style, never anything random
			-- #2850: a fixed 2x, not random; #4020: and the fixed potions in its place for a buyer who owns a Money pass
			local extras =
				{ cats = true, signStyles = true, moneyMultiplier = true, moneySwap = true }
			for _, product in Catalog.products do
				expect(Config.ProductIds[product.id]).to.be.ok()
				expect(product.prize.potions :: any).to.deepEqual(want[product.id])
				local any = product.prize :: any
				for key in any do
					expect(
						key == "potions"
							or (product.id == "starter_bundle" and extras[key] == true)
							or (
								key == "traitTokens"
								and (
									string.sub(product.id, 1, 13) == "trait_tokens_"
									or product.id == "deal_2"
								)
							)
					).to.equal(true)
				end
				for potionId, count in product.prize.moneySwap or {} do
					expect(Products.ALLOWED_POTIONS[potionId]).to.equal(true)
					expect(count > 0 and count == math.floor(count)).to.equal(true)
				end
				for potionId, count in product.prize.potions do
					expect(Products.ALLOWED_POTIONS[potionId]).to.equal(true)
					expect(Catalog.getPotion(potionId)).to.be.ok()
					expect(count > 0 and count == math.floor(count)).to.equal(true)
				end
				expect(table.isfrozen(product)).to.equal(true)
			end
		end)

		it(
			"sells Trait Tokens in the two bundles Traits.BUNDLES offers, 20 and 50 (#3864)",
			function()
				expect(#Traits.BUNDLES).to.equal(2)
				for _, bundle in Traits.BUNDLES do
					local product = Catalog.getProduct(bundle.product) :: any
					expect(product).to.be.ok()
					expect(product.prize.traitTokens).to.equal(bundle.tokens)
					expect(product.oncePerAccount).to.equal(nil)
					expect(Config.ProductIds[bundle.product]).to.be.ok()
				end
				expect(Traits.BUNDLES[1].tokens).to.equal(20)
				expect(Traits.BUNDLES[1].robux).to.equal(99)
				expect(Traits.BUNDLES[2].tokens).to.equal(50)
				expect(Traits.BUNDLES[2].robux).to.equal(199)
			end
		)

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
		it(
			"is once per account, holds nothing, and makes the buyer a supporter for good",
			function()
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
			end
		)
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
			expect(again.potions :: any).to.deepEqual({
				big_tip_potion = 10,
				swift_potion = 5,
				steady_potion = 5,
			})
		end)

		it(
			"pays the swap potions in place of the 2x to a buyer with a Money pass (#4020)",
			function()
				expect(bundle.prize.moneyMultiplier).to.equal(2)
				expect(bundle.prize.moneySwap :: any).to.deepEqual({
					big_tip_potion = 10,
					swift_potion = 5,
				})
				-- no pass (or the multiplier not given): the bundle as sold, its 2x included
				expect(Products.prizeFor(ProfileSchema.template(1000), bundle).swapped).to.equal(
					false
				)
				for _, owned in { 1, 0 } do
					local give, first =
						Products.prizeFor(ProfileSchema.template(1000), bundle, owned)
					expect(first).to.equal(true)
					expect(give.swapped).to.equal(false)
					expect(give.potions :: any).to.deepEqual({
						big_tip_potion = 10,
						swift_potion = 5,
						steady_potion = 5,
					})
				end
				-- 2x, 3x or 4x Money owned: 10 more Big Money and 5 more Swift on top of the potions
				for _, owned in { 2, 3, 4 } do
					local profile = ProfileSchema.template(1000)
					local give, first = Products.prizeFor(profile, bundle, owned)
					expect(first).to.equal(true)
					expect(give.swapped).to.equal(true)
					expect(give.potions :: any).to.deepEqual({
						big_tip_potion = 20,
						swift_potion = 10,
						steady_potion = 5,
					})
					expect(give.cats).to.deepEqual({ "sprinkles" })
					-- the Catalog's own prize is left as it is
					expect(bundle.prize.potions.big_tip_potion).to.equal(10)
					-- a second receipt pays only the bundle's potions, never the swap again
					Products.markBought(profile, bundle, give.signStyles)
					local again, firstAgain = Products.prizeFor(profile, bundle, owned)
					expect(firstAgain).to.equal(false)
					expect(again.swapped).to.equal(false)
					expect(again.potions.big_tip_potion).to.equal(10)
				end
			end
		)

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
