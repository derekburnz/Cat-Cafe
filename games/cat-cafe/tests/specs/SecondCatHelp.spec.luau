--!strict
-- SecondCatHelp.luau (#4452, #4453): the auto first bait and the Tier 2 top up at the first tamed bait cat.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Bait = require(Shared.Bait)
	local Catalog = require(Shared.Catalog)
	local Economy = require(Shared.Economy)
	local LiveFlags = require(Shared.LiveFlags)
	local ProfileSchema = require(Shared.ProfileSchema)
	local SecondCatHelp = require(Shared.SecondCatHelp)

	local function fresh()
		local profile = ProfileSchema.template(1_800_000_000)
		profile.tutorialStep = 4
		profile.upgradeLevels.lure_bowl = math.max(profile.upgradeLevels.lure_bowl or 0, 1)
		profile.lures = { kibble = 1 }
		return profile
	end

	-- `n` different kinds that count for a rank up
	local function kinds(n: number): { [string]: number }
		local collection = {}
		local have = 0
		for _, def in Catalog.cats do
			if have < n and Economy.countsForRankUp(def.id) then
				collection[def.id] = 1
				have += 1
			end
		end
		return collection
	end

	local tier2 = Catalog.getTier(2) :: any

	describe("switches", function()
		it("both are known and on unless switched off", function()
			for _, key in { SecondCatHelp.AUTO_BAIT_FLAG, SecondCatHelp.TOP_UP_FLAG } do
				expect(table.find(LiveFlags.KEYS, key) ~= nil).to.equal(true)
				expect(LiveFlags.OFF_BY_DEFAULT[key]).to.equal(nil)
			end
		end)
	end)

	describe("autoBaitDue", function()
		it("puts the starter Kibble in on the bowl step of an account that never baited", function()
			expect(SecondCatHelp.autoBaitDue(fresh(), true)).to.equal(true)
		end)

		it("never with the switch off", function()
			expect(SecondCatHelp.autoBaitDue(fresh(), false)).to.equal(false)
		end)

		it("only once: not after any food went in", function()
			local profile = fresh()
			profile.stats.luresUsed = 1
			expect(SecondCatHelp.autoBaitDue(profile, true)).to.equal(false)
		end)

		it("not before or after the bowl step", function()
			for _, step in { 1, 2, 3, 5 } do
				local profile = fresh()
				profile.tutorialStep = step
				expect(SecondCatHelp.autoBaitDue(profile, true)).to.equal(false)
			end
		end)

		it("not without the bowl, without a Kibble or with food in bowl 1", function()
			local noBowl = fresh()
			noBowl.upgradeLevels.lure_bowl = 0
			expect(SecondCatHelp.autoBaitDue(noBowl, true)).to.equal(false)
			local noFood = fresh()
			noFood.lures = {}
			expect(SecondCatHelp.autoBaitDue(noFood, true)).to.equal(false)
			local full = fresh()
			Bait.setState(
				full,
				1,
				{
					lureId = "kibble",
					placedAt = 0,
					readyAt = 5,
					catId = "x",
					variant = "base",
					charm = 1,
				} :: any
			)
			expect(SecondCatHelp.autoBaitDue(full, true)).to.equal(false)
		end)
	end)

	describe("topUpFor", function()
		local function tamed(coins: number)
			local profile = fresh()
			profile.tutorialStep = 5
			profile.stats.baitsTamed = 1
			profile.collection = kinds(tier2.distinctCats)
			profile.coins = coins
			return profile
		end

		it("pays the gap to exactly Tier 2's cost at the first tamed bait cat", function()
			expect(SecondCatHelp.topUpFor(tamed(400), true)).to.equal(tier2.cost - 400)
			expect(SecondCatHelp.topUpFor(tamed(0), true)).to.equal(tier2.cost)
		end)

		it("pays nothing to a player who has the coins", function()
			expect(SecondCatHelp.topUpFor(tamed(tier2.cost), true)).to.equal(0)
			expect(SecondCatHelp.topUpFor(tamed(tier2.cost + 50), true)).to.equal(0)
		end)

		it("never with the switch off", function()
			expect(SecondCatHelp.topUpFor(tamed(400), false)).to.equal(0)
		end)

		it("only once", function()
			local profile = tamed(400)
			profile.stats.tier2TopUp = tier2.cost - 400
			expect(SecondCatHelp.topUpFor(profile, true)).to.equal(0)
		end)

		it("not on a later bait cat", function()
			local profile = tamed(400)
			profile.stats.baitsTamed = 2
			expect(SecondCatHelp.topUpFor(profile, true)).to.equal(0)
		end)

		it(
			"#4674: under bowl first any catch that completes Tier 2's kinds pays it, once",
			function()
				local profile = tamed(300)
				profile.stats.baitsTamed = 0
				expect(SecondCatHelp.topUpFor(profile, true)).to.equal(0)
				expect(SecondCatHelp.topUpFor(profile, true, true)).to.equal(tier2.cost - 300)
				profile.stats.baitsTamed = 2
				expect(SecondCatHelp.topUpFor(profile, true, true)).to.equal(tier2.cost - 300)
				profile.stats.tier2TopUp = 1
				expect(SecondCatHelp.topUpFor(profile, true, true)).to.equal(0)
				profile.stats.tier2TopUp = 0
				profile.collection = kinds(tier2.distinctCats - 1)
				expect(SecondCatHelp.topUpFor(profile, true, true)).to.equal(0)
				expect(SecondCatHelp.topUpFor(profile, false, true)).to.equal(0)
			end
		)

		it("not short of Tier 2's kinds", function()
			local profile = tamed(400)
			profile.collection = kinds(tier2.distinctCats - 1)
			expect(SecondCatHelp.topUpFor(profile, true)).to.equal(0)
		end)

		it("not past Tier 1", function()
			local profile = tamed(400)
			profile.tier = 2
			expect(Economy.tier(profile)).to.equal(2)
			expect(SecondCatHelp.topUpFor(profile, true)).to.equal(0)
		end)

		-- Derek 2026-11-17 15:14 UTC: "rank up should be ready as soon as they catch their first cat from alleyway
		-- ... free starting cat, into food bowl into alleyway cannon, 1 catch into rankup"
		it(
			"a new save's starter, the bowl cat and one Alleyway catch make the Rank Up ready",
			function()
				local CatStats = require(Shared.CatStats)
				local profile = ProfileSchema.template(1_800_000_000)
				expect(Economy.rankUpCats(profile.collection, profile.cats, tier2)).to.equal(1) -- the starter Tabby
				-- the bowl cat and the first Alleyway catch, both Tabbies like the starter: duplicates count for Tier 2
				profile.cats.bowl_cat = CatStats.newInstance("bowl_cat", "tabby", 1_800_000_010)
				profile.stats.baitsTamed = 1
				expect(Economy.rankUpCats(profile.collection, profile.cats, tier2)).to.equal(2)
				expect(SecondCatHelp.topUpFor(profile, true, true)).to.equal(0) -- one short, no money yet
				profile.cats.alley_cat = CatStats.newInstance("alley_cat", "tabby", 1_800_000_020)
				profile.stats.catsCaught = 2
				expect(Economy.rankUpCats(profile.collection, profile.cats, tier2)).to.equal(
					tier2.distinctCats
				)
				profile.coins = 120
				expect(SecondCatHelp.topUpFor(profile, true, true)).to.equal(tier2.cost - 120)
				profile.coins += SecondCatHelp.topUpFor(profile, true, true)
				expect(Economy.rankUpBlocker(profile)).to.equal(nil)
			end
		)

		it("a new save starts with nothing paid", function()
			expect(ProfileSchema.template(0).stats.tier2TopUp).to.equal(0)
		end)
	end)
end
