--!strict
-- StarterCat.luau and the Bellhop Cat's catalog row against starter-cat.md sections 2 and 4 (F96): the claim's
-- refusals in order (claimed, range, then the gate), the gate by Config.GroupId, and a free cat that earns like a
-- Rare at the owner's newest area but never spawns, never sells to the Collector and never counts toward ranks or
-- the Index.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local CatStats = require(Shared.CatStats)
	local Collector = require(Shared.Collector)
	local Config = require(Shared.Config)
	local Economy = require(Shared.Economy)
	local IndexRewards = require(Shared.IndexRewards)
	local ProfileSchema = require(Shared.ProfileSchema)
	local StarterCat = require(Shared.StarterCat)
	local Types = require(Shared.Types)

	local GROUP = 123456

	local function profileAt(step: number): Types.PlayerProfile
		local profile = ProfileSchema.template(1000)
		profile.tutorialStep = step
		return profile
	end

	describe("the gate", function()
		it("is the first goals while the game has no group, the group after", function()
			expect(StarterCat.gate(0)).to.equal("task")
			expect(StarterCat.gate(GROUP)).to.equal("group")
		end)

		it("waits for the first goals at tutorial step StarterCatTutorialStep", function()
			expect(Config.StarterCatTutorialStep).to.equal(5)
			local early = profileAt(Config.StarterCatTutorialStep - 1)
			expect(StarterCat.blocker(early, true, nil, 0)).to.equal(StarterCat.NEEDS_GOALS)
			-- the membership answer is never read on the task gate
			expect(StarterCat.blocker(early, true, true, 0)).to.equal(StarterCat.NEEDS_GOALS)
			expect(StarterCat.blocker(profileAt(Config.StarterCatTutorialStep), true, nil, 0)).to.equal(
				nil
			)
			expect(StarterCat.blocker(profileAt(9), true, false, 0)).to.equal(nil)
		end)

		it("asks for the group once the game has one, whatever the tutorial step", function()
			local early = profileAt(0)
			expect(StarterCat.blocker(early, true, true, GROUP)).to.equal(nil)
			expect(StarterCat.blocker(early, true, false, GROUP)).to.equal(StarterCat.NEEDS_GROUP)
			-- a failed IsInGroupAsync is neither a yes nor a no
			expect(StarterCat.blocker(early, true, nil, GROUP)).to.equal(StarterCat.TRY_AGAIN)
		end)
	end)

	describe("the refusals", function()
		it(
			"says it is already home before anything else, so a claimed account never asks Roblox",
			function()
				local profile = profileAt(0)
				profile.starterCatClaimed = true
				for _, groupId in { 0, GROUP } do
					for _, near in { true, false } do
						for _, member in { true, false } do
							expect(StarterCat.blocker(profile, near, member, groupId)).to.equal(
								StarterCat.CLAIMED
							)
						end
						expect(StarterCat.blocker(profile, near, nil, groupId)).to.equal(
							StarterCat.CLAIMED
						)
					end
				end
			end
		)

		it("sends a player who is not at the stand to it before the gate", function()
			local profile = profileAt(0)
			expect(StarterCat.blocker(profile, false, nil, 0)).to.equal(StarterCat.TOO_FAR)
			expect(StarterCat.blocker(profile, false, false, GROUP)).to.equal(StarterCat.TOO_FAR)
			expect(StarterCat.blocker(profile, false, nil, GROUP)).to.equal(StarterCat.TOO_FAR)
		end)

		it("words every refusal for the stand card", function()
			for _, line in
				{
					StarterCat.CLAIMED,
					StarterCat.TOO_FAR,
					StarterCat.NEEDS_GOALS,
					StarterCat.NEEDS_GROUP,
					StarterCat.TRY_AGAIN,
				}
			do
				expect(#line > 0 and #line <= 48).to.equal(true)
				expect(string.find(line, "%.$")).to.equal(nil)
			end
		end)
	end)

	describe("the Bellhop Cat", function()
		local def = Catalog.getCat(StarterCat.CAT_ID) :: Types.CatDef

		it("is a free exclusive Rare with no area of its own", function()
			expect(def ~= nil).to.equal(true)
			expect(def.name).to.equal("Bellhop Cat")
			expect(def.rarity).to.equal("Rare")
			expect(def.area).to.equal("exclusive")
			expect(def.exclusive).to.equal(true)
			expect(def.source).to.equal("free")
			expect(Catalog.getArea(def.area)).to.equal(nil)
		end)

		it("comes with StarterCatCharm, inside the charm range", function()
			expect(Config.StarterCatCharm >= CatStats.MIN_CHARM).to.equal(true)
			expect(Config.StarterCatCharm <= CatStats.MAX_CHARM).to.equal(true)
			local instance = CatStats.newInstance("gift", def.id, 0, Config.StarterCatCharm)
			expect(CatStats.charm(instance)).to.equal(Config.StarterCatCharm)
		end)

		it("earns like a Rare from the newest area the owner's tier opens", function()
			for _, tier in Catalog.tiers do
				local newest: Types.AreaDef? = nil
				for _, area in Catalog.areas do
					if
						area.tier <= tier.tier
						and (newest == nil or area.incomeMultiplier > newest.incomeMultiplier)
					then
						newest = area
					end
				end
				local rares = Catching.candidates("Rare", (newest :: Types.AreaDef).id)
				expect(#rares > 0).to.equal(true)
				local gift = CatStats.newInstance("gift", def.id, 0, Config.StarterCatCharm)
				local wild = CatStats.newInstance("wild", rares[1].id, 0, Config.StarterCatCharm)
				expect(CatStats.rating(gift, tier.tier)).to.be.near(
					CatStats.rating(wild, tier.tier),
					1e-9
				)
			end
		end)

		it("never spawns, never comes to the bait bowl and never goes to the Collector", function()
			for _, rarity in Catalog.rarityOrder do
				for _, area in Catalog.areas do
					for _, other in Catching.candidates(rarity, area.id) do
						expect(other.id ~= def.id).to.equal(true)
					end
				end
				for tier = 1, #Catalog.tiers do
					for roll = 0, 0.999, 0.037 do
						expect(Catching.pickBaitCat(rarity, tier, roll).id ~= def.id).to.equal(true)
					end
				end
			end
			local instance = CatStats.newInstance("gift", def.id, 0, Config.StarterCatCharm)
			expect(Collector.askable(instance)).to.equal(false)
		end)

		it("counts toward neither the rank up's different cats nor the Index", function()
			local profile = ProfileSchema.template(1000)
			local before = Economy.distinctCats(profile)
			local all = IndexRewards.progress(profile.collection, IndexRewards.ALL)
			profile.collection[def.id] = 1000
			expect(Economy.distinctCats(profile)).to.equal(before)
			expect(IndexRewards.progress(profile.collection, IndexRewards.ALL)).to.equal(all)
		end)
	end)
end
