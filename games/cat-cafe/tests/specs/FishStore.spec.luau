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

		it("prices 50 fish a Robux to the nearest 50", function()
			local prices: { [string]: number } = {}
			for _, item in FishStore.LIST do
				prices[item.key] = FishStore.price(item)
			end
			expect(prices.stylishPack).to.equal(4950)
			expect(prices.signStyles).to.equal(3950)
			expect(prices.accessories).to.equal(7450)
			expect(prices.cafeStyle).to.equal(12450)
			expect(prices.grand).to.equal(39950)
			-- #4610: from the full price, never the half price sale
			expect(prices.vip).to.equal(1250)
			expect(prices.autoBowl).to.equal(950)
			expect(prices.extraSlot).to.equal(7450)
			expect(prices.longNap).to.equal(9950)
			expect(prices.royalCat).to.equal(29950)
			expect(prices.kingPack).to.equal(49950)
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
