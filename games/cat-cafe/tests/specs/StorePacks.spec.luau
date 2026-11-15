--!strict
-- StorePacks.luau (#4026): the four outfit packs' pieces exist in their lists, and the money each adds while in use
-- (sign 25, decor 25, uniform 15, wearable 15, the whole set 20 more: 100 for a pack).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Economy = require(Shared.Economy)
	local Looks = require(Shared.Looks)
	local ProfileSchema = require(Shared.ProfileSchema)
	local SignStyles = require(Shared.SignStyles)
	local StorePacks = require(Shared.StorePacks)

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-9
	end

	describe("the packs' pieces", function()
		it(
			"names a known sign, decor piece, uniform and wearable for each of the four packs",
			function()
				expect(#StorePacks.LIST).to.equal(4)
				for _, pack in StorePacks.LIST do
					local sign = SignStyles.get(pack.sign)
					expect(sign).to.be.ok()
					expect((sign :: any).passKey).to.equal(pack.passKey)
					local decor = Catalog.getDecor(pack.decor)
					expect(decor).to.be.ok()
					expect((decor :: any).passKey).to.equal(pack.passKey)
					expect((decor :: any).source).to.equal("pass")
					expect(near((decor :: any).bonus, StorePacks.DECOR)).to.equal(true)
					local uniform = Looks.uniform(pack.uniform)
					expect(uniform).to.be.ok()
					expect((uniform :: any).passKey).to.equal(pack.passKey)
					local accessory = Looks.accessory(pack.accessory)
					expect(accessory).to.be.ok()
					expect((accessory :: any).passKey).to.equal(pack.passKey)
					local at = Looks.attachmentOf(accessory :: any)
					expect(at == "Outfit_Hat" or at == "Outfit_Glasses").to.equal(true)
				end
			end
		)

		it("keeps an older accessory at its own Outfit_<piece> spot", function()
			expect(Looks.attachmentOf(Looks.accessory("glasses") :: any)).to.equal("Outfit_Glasses")
		end)
	end)

	describe("the money bonus", function()
		local stylish = StorePacks.LIST[1]

		local function dressed(): any
			local profile: any = ProfileSchema.template(1000)
			profile.signStyle = stylish.sign
			profile.decorOwned[stylish.decor] = true
			profile.decorPlaced[stylish.decor] = true
			profile.looks.uniform = stylish.uniform
			profile.looks.accessory = stylish.accessory
			return profile
		end

		it("adds nothing for a pack the player does not own, even with its picks saved", function()
			local profile = dressed()
			expect(StorePacks.bonus(profile, function(): boolean
				return false
			end)).to.equal(0)
			expect(Economy.packBonus(profile)).to.equal(0)
		end)

		it(
			"adds the sign, uniform, wearable and the set for a whole pack in use: 100 with the decor",
			function()
				local profile = dressed()
				local count, all = StorePacks.inUse(profile, stylish)
				expect(count).to.equal(4)
				expect(all).to.equal(true)
				local bonus = StorePacks.bonus(profile, function(key: string): boolean
					return key == "stylish"
				end)
				expect(near(bonus, 0.25 + 0.15 + 0.15 + 0.2)).to.equal(true)
				expect(near(bonus + StorePacks.DECOR, 1)).to.equal(true)
			end
		)

		it("drops the set bonus when one piece is not in use", function()
			local profile = dressed()
			profile.decorPlaced[stylish.decor] = false
			local bonus = StorePacks.bonus(profile, function(key: string): boolean
				return key == "stylish"
			end)
			expect(near(bonus, 0.25 + 0.15 + 0.15)).to.equal(true)
		end)

		it("goes into cafeMultiplier through the passes", function()
			local profile = dressed()
			local before = Economy.cafeMultiplier(profile)
			Economy.setPasses(
				profile,
				{ money = 1, longNap = false, slots = 0, packs = { stylish = true } }
			)
			expect(near(Economy.packBonus(profile), 0.75)).to.equal(true)
			expect(near(Economy.cafeMultiplier(profile) - before, 0.75)).to.equal(true)
			Economy.setPasses(profile, nil)
		end)
	end)
end
