--!strict
-- #5303 (switch companionTraits): Mystic Pool traits that raise the Cat Companion boosts (shared/Traits, Follower).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatStats = require(Shared.CatStats)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local Follower = require(Shared.Follower)
	local Luck = require(Shared.Luck)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Traits = require(Shared.Traits)

	local NOW = 100000

	local function withCat(trait: string?, variant: string?): (any, string)
		local profile: any = ProfileSchema.template(NOW)
		profile.tier = 2
		local instance: any = CatStats.newInstance("u_follow", "tabby", NOW, 1)
		instance.trait = if trait then { id = trait } else nil
		instance.variant = variant
		profile.cats[instance.uid] = instance
		profile.follower = { uid = instance.uid, boost = "money" }
		return profile, instance.uid
	end

	local function luckOf(profile: any): number
		for _, source in Luck.sources(profile, NOW, false, nil, nil) do
			if source.id == "follower" then
				return source.value
			end
		end
		return 0
	end

	describe("Companion traits (#5303)", function()
		beforeEach(function()
			Follower.setOn(true)
			Follower.setBoth(true)
		end)
		afterEach(function()
			Traits.setCompanion(false)
			Follower.setOn(nil)
			Follower.setBoth(nil)
		end)

		it("joins the pool only while on, and the rarity odds still sum to 100", function()
			expect(#Traits.ofRarity("common")).to.equal(6)
			expect(#Traits.ofRarity("legendary")).to.equal(4)
			Traits.setCompanion(true)
			expect(#Traits.ofRarity("common")).to.equal(8)
			expect(#Traits.ofRarity("epic")).to.equal(10)
			expect(#Traits.ofRarity("legendary")).to.equal(6)
			expect(#Traits.ofRarity("mythic")).to.equal(4)
			for _, secret in { true, false } do
				local total = 0
				for _, rarity in Traits.rarities(secret) do
					total += math.floor(rarity.odds * 10 + 0.5)
				end
				expect(total).to.equal(1000)
			end
			Traits.setCompanion(false)
			expect(#Traits.ofRarity("common")).to.equal(6)
			expect(#Traits.ofRarity("mythic")).to.equal(3)
			-- a saved id survives the switch going off
			expect(Traits.sanitize({ id = "loyalHeart_rare" })).to.be.ok()
		end)

		it("gives Eclipse every kind at the highest amount while on", function()
			Traits.setCompanion(true)
			for kind in Traits.KINDS do
				local best = 0
				for _, def in Traits.LIST do
					if def.id ~= "eclipse" then
						best = math.max(best, Traits.amount({ id = def.id }, kind))
					end
				end
				for _, def in Traits.COMPANION_LIST do
					best = math.max(best, Traits.amount({ id = def.id }, kind))
				end
				expect(Traits.amount({ id = "eclipse" }, kind)).to.equal(best)
			end
			Traits.setCompanion(false)
			expect(Traits.amount({ id = "eclipse" }, "companionMoney")).to.equal(0)
			expect(#(Traits.get("eclipse") :: any).effects).to.equal(6)
		end)

		it("adds to the companion only while that cat follows and the switch is on", function()
			local profile, uid = withCat("loyalHeart_rare")
			local base = Economy.tipMultiplier(profile, NOW)
			Traits.setCompanion(true)
			expect(Economy.tipMultiplier(profile, NOW) - base).to.be.near(0.03, 1e-9) -- Common 3% + 3%
			profile.follower.uid = ""
			local home = Economy.tipMultiplier(profile, NOW)
			profile.follower.uid = uid
			expect(Economy.tipMultiplier(profile, NOW) - home).to.be.near(0.06, 1e-9)
			Traits.setCompanion(false)
			expect(Economy.tipMultiplier(profile, NOW) - home).to.be.near(0.03, 1e-9)
		end)

		it("leaves the trait part out of the coat and keeps Luck under LuckMax", function()
			Traits.setCompanion(true)
			local cat: any = { variant = "rainbow", trait = { id = "eclipse" } }
			expect(Follower.catAmount(cat, "Secret", "money")).to.be.near(0.42, 1e-9)
			expect(Follower.catAmount(cat, "Secret", "luck")).to.be.near(0.85, 1e-9)
			local profile = withCat("luckyShadow_epic")
			expect(luckOf(profile)).to.be.near(0.05 + 0.12, 1e-9)
			expect(Luck.of(profile, NOW, false) <= Config.LuckMax).to.equal(true)
		end)

		it("shows the trait chip and the roll card's words", function()
			Traits.setCompanion(true)
			expect(Follower.traitChip({ id = "loyalHeart_rare" })).to.equal("Loyal Heart +3%")
			expect(Follower.traitChip({ id = "luckyShadow_epic" })).to.equal("Lucky Shadow +0.12")
			expect(Follower.traitChip({ id = "bigTipper_rare" })).to.equal(nil)
			local lines = Traits.effectLines({ id = "loyalHeart_rare" })
			expect(lines[1]).to.equal("+3% Companion Money (while following you)")
			expect(Traits.effectLines({ id = "luckyShadow_rare" })[1]).to.equal(
				"+0.08 Companion Luck (while following you)"
			)
		end)
	end)
end
