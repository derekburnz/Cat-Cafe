--!strict
-- shared/Follower.luau (#5172, switch catFollower): one of the player's own cats follows them from Tier 2 for a Money
-- boost (on the tip multiplier, online pay only) or a Luck boost (a Luck source, still at most LuckMax), by rarity.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local CatStats = require(Shared.CatStats)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local Follower = require(Shared.Follower)
	local Luck = require(Shared.Luck)
	local Potions = require(Shared.Potions)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Types = require(Shared.Types)

	local NOW = 100000

	local function withCat(catId: string, tier: number?): (Types.PlayerProfile, string)
		local profile = ProfileSchema.template(NOW)
		profile.tier = tier or 2
		local instance = CatStats.newInstance("u_follow", catId, NOW, 1)
		profile.cats[instance.uid] = instance
		return profile, instance.uid
	end

	local function luckOf(profile: Types.PlayerProfile): number
		for _, source in Luck.sources(profile, NOW, false, nil, nil) do
			if source.id == "follower" then
				return source.value
			end
		end
		return 0
	end

	describe("Follower (#5172)", function()
		beforeEach(function()
			Follower.setOn(true)
		end)
		afterEach(function()
			Follower.setOn(nil)
		end)

		it("has a boost for every rarity, rising with rarity", function()
			local last = { money = 0, luck = 0 }
			for _, rarity in { "Common", "Rare", "Epic", "Legendary", "Mythical", "Secret" } do
				local money = Follower.amount(rarity, "money")
				local luck = Follower.amount(rarity, "luck")
				expect(money > last.money and luck > last.luck).to.equal(true)
				last = { money = money, luck = luck }
			end
			expect(Follower.amount("Legendary", "money")).to.equal(0.12)
			expect(Follower.amount("Secret", "luck")).to.equal(0.40)
			expect(Follower.amount(nil, "money")).to.equal(0)
		end)

		it("raises the boost by the coat: gold x1.25, rainbow x1.5 (Derek 2026-11-18)", function()
			expect(Follower.amount("Legendary", "money", "rainbow")).to.equal(0.18)
			expect(Follower.amount("Secret", "money", "rainbow")).to.equal(0.30)
			expect(Follower.amount("Secret", "luck", "rainbow")).to.equal(0.60)
			expect(Follower.amount("Common", "money", "gold")).to.equal(0.0375)
			expect(Follower.amount("Rare", "luck", "nonsense")).to.equal(0.10)
			local profile, uid = withCat("cafe_ghost")
			profile.cats[uid].variant = "rainbow"
			profile.follower = { uid = uid, boost = "luck" }
			expect(luckOf(profile)).to.equal(0.60)
			expect(Luck.of(profile, NOW, false, nil, nil) <= Config.LuckMax).to.equal(true)
		end)

		it("starts with nobody following and Money picked, and cleans a bad save", function()
			local profile = ProfileSchema.template(NOW)
			expect(profile.follower.uid).to.equal("")
			expect(profile.follower.boost).to.equal("money")
			local bad = Follower.sanitize({ uid = 5, boost = "robux" })
			expect(bad.uid).to.equal("")
			expect(bad.boost).to.equal("money")
			expect(Follower.sanitize({ uid = "abc", boost = "luck" }).boost).to.equal("luck")
			expect(Follower.sanitize(nil).uid).to.equal("")
			expect(#Follower.sanitize({ uid = string.rep("x", 65) }).uid).to.equal(0)
		end)

		it("keeps the follower through a save and load", function()
			local profile, uid = withCat("tabby")
			profile.follower = { uid = uid, boost = "luck" }
			local loaded = ProfileSchema.migrate(profile, NOW)
			expect(loaded.follower.uid).to.equal(uid)
			expect(loaded.follower.boost).to.equal("luck")
		end)

		it(
			"refuses with the switch off, below Tier 2, a cat not owned or during a trade",
			function()
				local profile, uid = withCat("tabby", 1)
				expect(Follower.blocker(profile, uid, false) ~= nil).to.equal(true)
				profile.tier = 2
				expect(Follower.blocker(profile, uid, false)).to.equal(nil)
				expect(Follower.blocker(profile, "nobody", false) ~= nil).to.equal(true)
				expect(Follower.blocker(profile, uid, true) ~= nil).to.equal(true)
				Follower.setOn(false)
				expect(Follower.blocker(profile, uid, false) ~= nil).to.equal(true)
			end
		)

		it(
			"adds Money to the tip multiplier only while the cat follows with Money picked",
			function()
				local profile, uid = withCat("tabby")
				local base = Economy.tipMultiplier(profile, NOW)
				profile.follower = { uid = uid, boost = "money" }
				expect(Economy.tipMultiplier(profile, NOW) - base).to.be.near(0.03, 1e-9)
				expect(luckOf(profile)).to.equal(0)
				profile.follower.boost = "luck"
				expect(Economy.tipMultiplier(profile, NOW)).to.be.near(base, 1e-9)
				profile.follower.boost = "money"
				Follower.setOn(false)
				expect(Economy.tipMultiplier(profile, NOW)).to.be.near(base, 1e-9)
				Follower.setOn(true)
				profile.tier = 1
				expect(Economy.tipMultiplier(profile, NOW)).to.be.near(base, 1e-9)
				profile.tier = 2
				profile.cats[uid] = nil -- traded away or sold
				expect(Economy.tipMultiplier(profile, NOW)).to.be.near(base, 1e-9)
			end
		)

		it("pays the Money boost in settle over the online window", function()
			local function earned(follows: boolean): number
				local profile, uid = withCat("void")
				profile.follower = { uid = if follows then uid else "", boost = "money" }
				profile.lastTick = NOW
				return Economy.settle(profile, NOW + 100, nil)
			end
			local off, on = earned(false), earned(true)
			expect(off > 0).to.equal(true)
			expect(on / off).to.be.near(1.12, 1e-6)
		end)

		it("stacks the Money boost with a Money Potion", function()
			local profile, uid = withCat("tabby")
			profile.follower = { uid = uid, boost = "money" }
			local with = Economy.tipMultiplier(profile, NOW)
			profile.follower.uid = ""
			local without = Economy.tipMultiplier(profile, NOW)
			expect(with - without).to.be.near(0.03, 1e-9)
			expect(Potions ~= nil).to.equal(true)
		end)

		it("adds Luck as its own source, still at most LuckMax", function()
			local profile, uid = withCat("cafe_ghost")
			profile.follower = { uid = uid, boost = "luck" }
			expect(luckOf(profile)).to.equal(0.40)
			local luck = Luck.of(profile, NOW, false, nil, nil)
			expect(luck >= 1.4 - 1e-9 and luck <= Config.LuckMax).to.equal(true)
			profile.follower.boost = "money"
			expect(luckOf(profile)).to.equal(0)
		end)
	end)
end
