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
			}
			for _, product in Catalog.products do
				expect(Config.ProductIds[product.id]).to.be.ok()
				expect(product.prize.potions :: any).to.deepEqual(want[product.id])
				local any = product.prize :: any
				for key in any do
					expect(key).to.equal("potions")
				end
				for potionId, count in product.prize.potions do
					expect(Products.ALLOWED_POTIONS[potionId]).to.equal(true)
					expect(Catalog.getPotion(potionId)).to.be.ok()
					expect(count > 0 and count == math.floor(count)).to.equal(true)
				end
				expect(table.isfrozen(product)).to.equal(true)
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
end
