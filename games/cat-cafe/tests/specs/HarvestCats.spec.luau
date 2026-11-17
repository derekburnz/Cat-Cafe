--!strict
-- #4251 Harvest Hollow's eight cats (harvest-hollow-spec 3b): kept, each earns like the cat two rarities lower in the
-- owner's newest area (never below Common), and they count toward no Index page, total or badge.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local CatStats = require(Shared.CatStats)
	local IndexRewards = require(Shared.IndexRewards)

	local LIKE = {
		Common = "Common",
		Rare = "Common",
		Epic = "Common",
		Legendary = "Rare",
		Mythical = "Epic",
	}

	describe("Harvest cats", function()
		it("are the spec's eight, in the harvest area, with the earns-like rarity", function()
			expect(#Catalog.harvestCats).to.equal(8)
			local byRarity: { [string]: number } = {}
			for _, def in Catalog.harvestCats do
				expect(def.area).to.equal("harvest")
				expect(def.earnsLike).to.equal((LIKE :: any)[def.rarity])
				byRarity[def.rarity] = (byRarity[def.rarity] or 0) + 1
			end
			expect(byRarity.Common).to.equal(2)
			expect(byRarity.Rare).to.equal(3)
			expect(byRarity.Epic).to.equal(1)
			expect(byRarity.Legendary).to.equal(1)
			expect(byRarity.Mythical).to.equal(1)
			expect(Catalog.getCat("harvest_moon")).to.be.ok()
			expect(Catalog.catModelName("harvest_moon")).to.equal("CatCafe_Cat_HarvestMoon")
			expect(Catalog.catModelName("acorn_cap")).to.equal("CatCafe_Cat_AcornCap")
		end)

		it("earn like the earns-like rarity at the owner's newest area, at every tier", function()
			for tier = 1, #Catalog.tiers do
				local best = 1
				for _, area in Catalog.areas do
					if area.tier <= tier and area.incomeMultiplier > best then
						best = area.incomeMultiplier
					end
				end
				for _, def in Catalog.harvestCats do
					local cat = CatStats.newInstance("h", def.id, 0, CatStats.MIN_CHARM)
					local like = Catalog.rarities[(LIKE :: any)[def.rarity]].incomePerSecond
					local want = like * best * CatStats.charmMultiplier(CatStats.MIN_CHARM)
					expect(math.abs(CatStats.rating(cat, tier) - want) < 1e-6).to.equal(true)
				end
			end
		end)

		it("count on no Index page or total", function()
			local found: { [string]: number } = {}
			for _, def in Catalog.harvestCats do
				found[def.id] = 1
			end
			expect(IndexRewards.progress(found, IndexRewards.ALL)).to.equal(0)
			expect(IndexRewards.progress(found, "harvest")).to.equal(0)
		end)

		it("count toward no rank up need or collection badge (Review-QA on #4439)", function()
			local Economy = require(Shared.Economy)
			local ProfileSchema = require(Shared.ProfileSchema)
			local profile = ProfileSchema.template(1000) :: any
			local before = Economy.distinctCats(profile)
			local epicBefore = Economy.distinctCatsAtLeast(profile, "Epic")
			local rankBefore = Economy.rankUpCatCount(profile.collection)
			local rankEpicBefore = Economy.rankUpCatsAtLeast(profile.collection, "Epic")
			for _, def in Catalog.harvestCats do
				profile.collection[def.id] = profile.collection[def.id] or true
				expect(Economy.countsForRankUp(def.id)).to.equal(false)
			end
			expect(Economy.distinctCats(profile)).to.equal(before)
			expect(Economy.distinctCatsAtLeast(profile, "Epic")).to.equal(epicBefore)
			expect(Economy.rankUpCatCount(profile.collection)).to.equal(rankBefore)
			expect(Economy.rankUpCatsAtLeast(profile.collection, "Epic")).to.equal(rankEpicBefore)
		end)

		it("clear no rare quest and give no coat badge (Design spec 3b)", function()
			local Badges = require(Shared.Badges)
			local ProfileSchema = require(Shared.ProfileSchema)
			local Quests = require(Shared.Quests)
			local profile = ProfileSchema.template(1000) :: any
			local mythicals = Quests.measure(profile, "mythicalCats")
			for _, def in Catalog.harvestCats do
				profile.collection[def.id] = true
				profile.goldCollection[def.id] = 1
			end
			expect(Quests.measure(profile, "mythicalCats")).to.equal(mythicals)
			expect(table.find(Badges.earned(profile), "goldenCoat")).to.equal(nil)
		end)
	end)
end
