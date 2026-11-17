--!strict
-- FishStore.luau (#4055): the Store passes sold for golden fish, their prices (50 fish a Robux, to the nearest 50),
-- the Money passes that are never on the list (#4610: the only ones), the save's sanitising and why a buy is refused.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local FishStore = require(Shared.FishStore)
	local ProfileSchema = require(Shared.ProfileSchema)

	describe("the list", function()
		it("holds every Store pass, each a Config pass id field", function()
			expect(#FishStore.LIST).to.equal(17)
			for _, item in FishStore.LIST do
				local field = (Config :: any)[item.passField]
				expect(type(field) == "number" or type(field) == "table").to.equal(true)
				expect(FishStore.item(item.key)).to.equal(item)
			end
		end)

		it("leaves only the 2x, 3x and 4x Money passes Robux only (#4610)", function()
			expect(#FishStore.ROBUX_ONLY_PASSES).to.equal(1)
			expect(FishStore.ROBUX_ONLY_PASSES[1]).to.equal("MoneyPassIds")
			for _, item in FishStore.LIST do
				expect(item.passField == "MoneyPassIds").to.equal(false)
				local id = FishStore.passId(item)
				if id ~= 0 then
					for _, money in Config.MoneyPassIds do
						expect(id == money).to.equal(false)
					end
				end
			end
			for _, key in
				{ "vip", "extraSlot", "longNap", "secondBowl", "autoBowl", "royalCat", "kingPack" }
			do
				expect(FishStore.item(key) ~= nil).to.equal(true)
			end
			expect(FishStore.item("starterBundle")).to.equal(nil)
		end)

		it("reads a list field's first made id (Extra Slot)", function()
			local slot = FishStore.item("extraSlot") :: FishStore.Item
			local first = 0
			for _, id in Config.ExtraSlotPassIds do
				if id ~= 0 then
					first = id
					break
				end
			end
			expect(FishStore.passId(slot)).to.equal(first)
			expect(
				FishStore.passId({ key = "x", name = "x", passField = "NoSuchField", robux = 1 })
			).to.equal(0)
		end)

		it("waits for the Auto Bowl's own switch", function()
			expect((FishStore.item("autoBowl") :: FishStore.Item).flag).to.equal("autoBowl")
			expect((FishStore.item("vip") :: FishStore.Item).flag).to.equal(nil)
		end)

		it("prices 25 fish a Robux to the nearest 50 (Derek 2026-11-17: half)", function()
			local prices: { [string]: number } = {}
			for _, item in FishStore.LIST do
				prices[item.key] = FishStore.price(item)
			end
			expect(prices.stylishPack).to.equal(2500)
			expect(prices.signStyles).to.equal(2000)
			expect(prices.accessories).to.equal(3750)
			expect(prices.cafeStyle).to.equal(6250)
			expect(prices.grand).to.equal(20000)
			-- #4610: from the full price, never the half price sale
			expect(prices.vip).to.equal(650)
			expect(prices.autoBowl).to.equal(500)
			expect(prices.extraSlot).to.equal(3750)
			expect(prices.longNap).to.equal(5000)
			expect(prices.royalCat).to.equal(15000)
			expect(prices.kingPack).to.equal(25000)
		end)
	end)

	describe("the products (#4610 part 2)", function()
		it("sells the Thank You Badge and the Cafe Pass, never the Starter Bundle", function()
			expect(#FishStore.PRODUCTS).to.equal(2)
			expect(FishStore.product("thankYou") ~= nil).to.equal(true)
			expect(FishStore.product("cafePass") ~= nil).to.equal(true)
			expect(FishStore.product("starterBundle")).to.equal(nil)
			expect(FishStore.ROBUX_ONLY_PRODUCTS[1]).to.equal("starter_bundle")
			for _, product in FishStore.PRODUCTS do
				expect(product.productId == "starter_bundle").to.equal(false)
				expect(Config.ProductIds[product.productId] ~= nil).to.equal(true)
				expect(FishStore.item(product.key)).to.equal(nil) -- never both a pass and a product
			end
			expect(FishStore.price(FishStore.product("thankYou") :: FishStore.Product)).to.equal(
				650
			)
			expect(FishStore.price(FishStore.product("cafePass") :: FishStore.Product)).to.equal(
				7500
			)
		end)

		it("sells the badge once an account", function()
			local profile = ProfileSchema.template(1700000000)
			local badge = FishStore.product("thankYou") :: FishStore.Product
			profile.goldenFish = 649
			expect(FishStore.productBlocker(profile, badge, 1, true)).to.equal(
				"Not enough golden fish yet"
			)
			profile.goldenFish = 650
			expect(FishStore.productBlocker(profile, badge, 0, false)).to.equal(nil) -- no season needed
			profile.onceBought.thank_you_badge = true
			expect(FishStore.productBlocker(profile, badge, 1, true)).to.equal(
				"You own this already"
			)
		end)

		it("sells the Cafe Pass once a running season, while its sale is open", function()
			local profile = ProfileSchema.template(1700000000)
			local pass = FishStore.product("cafePass") :: FishStore.Product
			profile.goldenFish = 20000
			expect(FishStore.productBlocker(profile, pass, 0, true)).never.to.equal(nil)
			expect(FishStore.productBlocker(profile, pass, 2, false)).never.to.equal(nil)
			expect(FishStore.productBlocker(profile, pass, 2, true)).to.equal(nil)
			profile.pass.season = 2
			profile.pass.paidSeason = 2
			expect(FishStore.productBlocker(profile, pass, 2, true)).to.equal(
				"You own this already"
			)
			expect(FishStore.productBlocker(profile, pass, 3, true)).to.equal(nil) -- a new season sells again
		end)

		it("puts both in the view with whether this save has them", function()
			local profile = ProfileSchema.template(1700000000)
			profile.onceBought.thank_you_badge = true
			local byKey: { [string]: FishStore.ViewRow } = {}
			for _, row in FishStore.view(profile) do
				byKey[row.key] = row
			end
			expect(byKey.thankYou.bought).to.equal(true)
			expect(byKey.thankYou.fish).to.equal(650)
			expect(byKey.cafePass.bought).to.equal(false)
			expect(byKey.starterBundle).to.equal(nil)
		end)
	end)

	describe("the save", function()
		it("keeps only known keys set true", function()
			local out =
				FishStore.sanitize({ cafeStyle = true, grand = false, moneyX2 = true, [1] = true })
			expect(out.cafeStyle).to.equal(true)
			expect(out.grand).to.equal(nil)
			expect((out :: any).moneyX2).to.equal(nil)
			expect(next(FishStore.sanitize("nope"))).to.equal(nil)
		end)

		it("survives a migrate and gives the made passes' ids", function()
			local profile = ProfileSchema.migrate(
				{ version = 49, fishBought = { uniforms = true } },
				1700000000
			)
			expect(profile.fishBought.uniforms).to.equal(true)
			local ids = FishStore.boughtIds(profile.fishBought)
			local item = FishStore.item("uniforms") :: FishStore.Item
			expect(#ids).to.equal(if FishStore.passId(item) ~= 0 then 1 else 0)
		end)
	end)

	describe("blocker", function()
		it("refuses an owned pass, too few fish and a pass not made", function()
			local profile = ProfileSchema.template(1700000000)
			local item = FishStore.item("signStyles") :: FishStore.Item
			local made = FishStore.passId(item) ~= 0
			profile.goldenFish = FishStore.price(item)
			if made then
				expect(FishStore.blocker(profile, item, false)).to.equal(nil)
				expect(FishStore.blocker(profile, item, true)).to.equal("You own this already")
				profile.fishBought.signStyles = true
				expect(FishStore.blocker(profile, item, false)).to.equal("You own this already")
				profile.fishBought.signStyles = nil
				profile.goldenFish -= 1
				expect(FishStore.blocker(profile, item, false)).to.equal(
					"Not enough golden fish yet"
				)
			else
				expect(FishStore.blocker(profile, item, false)).to.equal("Coming soon")
			end
		end)
	end)
end
