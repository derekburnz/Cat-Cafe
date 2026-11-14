--!strict
-- FishStore.luau (#4055): the Store passes sold for golden fish, their prices (50 fish a Robux, to the nearest 50),
-- the passes that are never on the list, the save's sanitising and why a buy is refused.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Config = require(Shared.Config)
	local FishStore = require(Shared.FishStore)
	local ProfileSchema = require(Shared.ProfileSchema)

	describe("the list", function()
		it("holds the ten approved passes, each a Config pass id field", function()
			expect(#FishStore.LIST).to.equal(10)
			for _, item in FishStore.LIST do
				expect(type((Config :: any)[item.passField])).to.equal("number")
				expect(FishStore.item(item.key)).to.equal(item)
			end
		end)

		it(
			"never holds the money passes, VIP, slots, the second bowl or the shop cats (Robux only)",
			function()
				local banned: { [string]: boolean } = {
					VipPassId = true,
					LongNapPassId = true,
					SecondBowlPassId = true,
					GoldenPondPassId = true,
				}
				for _, item in FishStore.LIST do
					expect(banned[item.passField] == true).to.equal(false)
					local id = FishStore.passId(item)
					if id ~= 0 then
						for _, money in Config.MoneyPassIds do
							expect(id == money).to.equal(false)
						end
						for _, slot in Config.ExtraSlotPassIds do
							expect(id == slot).to.equal(false)
						end
					end
				end
			end
		)

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
