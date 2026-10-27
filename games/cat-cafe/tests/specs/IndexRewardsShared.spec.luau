--!strict
-- shared/IndexRewards.luau, shared/Prizes.luau and the Index reward tables (F48, F54; data-model section 11b,
-- golden-fish.md sections 4, 5, 5b and 8).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
	local Catalog = require(ReplicatedStorage.Shared.Catalog)
	local Config = require(ReplicatedStorage.Shared.Config)
	local Prizes = require(ReplicatedStorage.Shared.Prizes)
	local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)

	local AREAS = { "alley", "park", "neighbourhood", "woods", "sewer" }
	local POOLS = { "alley", "park", "neighbourhood", "woods", "sewer", "classic" }
	local AREA_MILESTONES = { "cats3", "cats6", "cats10", "gold1", "gold2", "gold4", "gold6", "gold8", "gold10" }

	local function sum(prizes: { [string]: any }, field: string): number
		local total = 0
		for _, prize in pairs(prizes) do
			total += prize[field] or 0
		end
		return total
	end

	describe("Catalog tables (F54, golden-fish.md sections 5 and 5b)", function()
		it("has every milestone once, each with a track and a count", function()
			local ids: { string } = {}
			for _, milestone in Catalog.indexMilestones do
				table.insert(ids, milestone.id)
				expect(table.find({ "normal", "gold", "decor" }, milestone.track) ~= nil).to.equal(true)
				expect(milestone.needs > 0).to.equal(true)
				local digits = tonumber(string.match(milestone.id, "%d+$"))
				expect(digits).to.equal(milestone.needs)
			end
			expect(ids :: any).to.deepEqual({
				"cats3",
				"cats6",
				"cats10",
				"gold1",
				"gold2",
				"gold4",
				"gold6",
				"gold8",
				"gold10",
				"total5",
				"total10",
				"total15",
				"total20",
				"total25",
				"total30",
				"total35",
				"total40",
				"total45",
				"total50",
				"decor5",
				"decor10",
			})
		end)

		it("gives every area page both tracks: +7% tips and +30% gold luck forever", function()
			for _, areaId in AREAS do
				local prizes = Catalog.indexPrizes[areaId]
				assert(prizes)
				local ids: { string } = {}
				for id in pairs(prizes) do
					table.insert(ids, id)
				end
				table.sort(ids)
				local want = table.clone(AREA_MILESTONES)
				table.sort(want)
				expect(ids :: any).to.deepEqual(want)
				expect(sum({ cats3 = prizes.cats3, cats6 = prizes.cats6, cats10 = prizes.cats10 }, "bonus")).to.be.near(0.07, 1e-9)
				expect(sum(prizes, "goldLuck")).to.be.near(0.30, 1e-9)
				expect(sum(prizes, "baitSpeed")).to.equal(0)
				expect(prizes.gold10.tag).to.equal(((Catalog.getArea(areaId) :: any).name) .. " Gold Master")
				-- the finishing prizes (v0.10): the area's Golden Crate at cats10, two at gold10
				expect((prizes.cats10.crates :: any)[areaId .. "_golden_crate"]).to.equal(1)
				expect((prizes.gold10.crates :: any)[areaId .. "_golden_crate"]).to.equal(2)
			end
		end)

		it("pays the Alleyway rows as the design table says", function()
			local alley = Catalog.indexPrizes.alley
			expect(alley.cats3 :: any).to.deepEqual({ coins = 300, coinSeconds = 600, fish = 5, spins = 1 })
			expect(alley.cats6 :: any).to.deepEqual({
				lures = { tuna = 3 },
				crates = { alley_crate = 1 },
				bonus = 0.02,
			})
			expect(alley.cats10 :: any).to.deepEqual({
				lures = { salmon = 2 },
				crates = { alley_crate = 2, alley_golden_crate = 1 },
				fish = 25,
				spins = 2,
				bonus = 0.05,
			})
			expect(alley.gold1 :: any).to.deepEqual({
				fish = 10,
				spins = 1,
				crates = { alley_crate = 1 },
				goldLuck = 0.02,
			})
			expect(alley.gold10 :: any).to.deepEqual({
				coins = 5000,
				coinSeconds = 3600,
				crates = { alley_golden_crate = 2 },
				fish = 100,
				spins = 5,
				tag = "Alleyway Gold Master",
				goldLuck = 0.10,
			})
		end)

		it("gives All Cats ten milestones worth 38% faster bait, ending with Cat Master", function()
			local all = Catalog.indexPrizes.all
			local n = 0
			for id, prize in pairs(all) do
				n += 1
				expect(string.sub(id, 1, 5)).to.equal("total")
				expect(prize.bonus).never.to.be.ok()
				expect(prize.goldLuck).never.to.be.ok()
			end
			expect(n).to.equal(10)
			expect(sum(all, "baitSpeed")).to.be.near(0.38, 1e-9)
			expect(all.total30.crates :: any).to.deepEqual({ highest = 1 })
			expect(all.total50 :: any).to.deepEqual({
				fish = 150,
				crates = { classic_golden_crate = 2 },
				spins = 10,
				tag = "Cat Master",
				baitSpeed = 0.10,
			})
		end)

		it("gives each Decor Index page 25 fish at five pieces and +5% tips forever at ten", function()
			for _, pool in POOLS do
				local page = Catalog.indexPrizes["decor_" .. pool]
				assert(page)
				expect(page.decor5 :: any).to.deepEqual({ fish = Config.DecorIndexHalfFish })
				expect(page.decor10 :: any).to.deepEqual({ bonus = Config.DecorIndexBonus })
			end
		end)

		it("has no page beyond the areas, All Cats and the six Decor Index pages", function()
			for pageId in pairs(Catalog.indexPrizes) do
				local known = table.find(AREAS, pageId) ~= nil
					or pageId == "all"
					or table.find(POOLS, string.sub(pageId, 7)) ~= nil and string.sub(pageId, 1, 6) == "decor_"
				expect(known).to.equal(true)
			end
		end)

		it("the prize table is frozen, so no write can change a prize (S61)", function()
			expect(table.isfrozen(Catalog.indexPrizes)).to.equal(true)
			expect(table.isfrozen(Catalog.indexPrizes.alley)).to.equal(true)
			expect(table.isfrozen(Catalog.indexPrizes.alley.cats3)).to.equal(true)
			expect(table.isfrozen(Catalog.indexPrizes.alley.cats6.lures :: any)).to.equal(true)
			expect(table.isfrozen(Catalog.indexPrizes.alley.cats6.crates :: any)).to.equal(true)
			expect(pcall(function()
				(Catalog.indexPrizes.alley :: any).cats3 = true
			end)).to.equal(false)
		end)

		it("every prize names real foods and crates, and never decor", function()
			for _, prizes in pairs(Catalog.indexPrizes) do
				for _, prize in pairs(prizes) do
					expect((prize :: any).decorId).never.to.be.ok()
					for lureId, count in pairs(prize.lures or {}) do
						expect(Catalog.getLure(lureId)).to.be.ok()
						expect(count > 0).to.equal(true)
					end
					for crateId, count in pairs(prize.crates or {}) do
						expect(crateId == Prizes.HIGHEST or Catalog.getCrate(crateId) ~= nil).to.equal(true)
						expect(count > 0).to.equal(true)
					end
					local kinds = (if prize.bonus then 1 else 0)
						+ (if prize.goldLuck then 1 else 0)
						+ (if prize.baitSpeed then 1 else 0)
					expect(kinds <= 1).to.equal(true)
				end
			end
		end)

		it("retired the gold Index decor; the five Index pieces are their zones' Epics", function()
			for _, areaId in AREAS do
				expect(Catalog.getDecor("index_" .. areaId .. "_gold")).never.to.be.ok()
				local piece = Catalog.getDecor("index_" .. areaId)
				assert(piece)
				expect(piece.source).to.equal("crate")
				expect(piece.crate).to.equal(areaId)
				expect(piece.rarity).to.equal("Epic")
				expect(piece.bonus).to.be.near(0.08)
				expect(piece.replaces).never.to.be.ok()
				expect(table.find(Catalog.decor, piece)).never.to.be.ok()
			end
		end)
	end)

	describe("Prizes", function()
		it("pays seconds of the day rate, never under the minimum", function()
			expect(Prizes.coins(300, 600, 0)).to.equal(300)
			expect(Prizes.coins(300, 600, 2)).to.equal(1200)
			expect(Prizes.coins(300, 600, 0.4)).to.equal(300)
			expect(Prizes.coins(nil, nil, 5)).to.equal(0)
			expect(Prizes.coins(1000, nil, 50)).to.equal(1000)
		end)

		it("resolves highest to the plain crate of the highest zone the tier opens", function()
			expect(Prizes.crateFor(Prizes.HIGHEST, 1)).to.equal("alley_crate")
			for _, area in Catalog.areas do
				expect(Prizes.crateFor(Prizes.HIGHEST, area.tier)).to.equal(area.id .. "_crate")
			end
			expect(Prizes.crateFor(Prizes.HIGHEST, 99)).to.equal("sewer_crate")
			expect(Prizes.crateFor("classic_golden_crate", 1)).to.equal("classic_golden_crate")
			expect(Prizes.crateFor("nope", 3)).never.to.be.ok()
		end)
	end)

	describe("progress and claims", function()
		local function profileWith(catIds: { string }, goldIds: { string }?): any
			local profile = ProfileSchema.template(1000)
			for _, catId in ipairs(catIds) do
				profile.collection[catId] = 1000
			end
			for _, catId in ipairs(goldIds or {}) do
				profile.goldCollection[catId] = 1000
			end
			return profile
		end

		local ALLEY_CATS = {
			"tabby",
			"tuxedo",
			"ginger",
			"smoke",
			"calico",
			"tortie",
			"sphynx",
			"maine_coon",
			"void",
			"midnight",
		}

		it("counts only the area's cats in the collection", function()
			local profile = profileWith({ "tabby", "tuxedo", "snow", "cream" })
			expect(IndexRewards.progress(profile.collection, "alley")).to.equal(2)
			expect(IndexRewards.progress(profile.collection, "park")).to.equal(2)
			expect(IndexRewards.progress(profile.collection, "woods")).to.equal(0)
			profile.collection.dragon = 5 -- not a cat
			expect(IndexRewards.progress(profile.collection, "alley")).to.equal(2)
		end)

		it("a milestone is claimable once the count is met, and only once", function()
			local profile = profileWith({ "tabby", "tuxedo" })
			profile.collection.tabby = nil -- the template's starter is already in; start from one cat
			expect(IndexRewards.blocker(profile, "alley", "cats3")).to.equal(
				"Find 2 more cats first"
			)
			profile.collection.tabby = 1000
			expect(IndexRewards.blocker(profile, "alley", "cats3")).to.equal("Find 1 more cat first")
			profile.collection.ginger = 1000
			expect(IndexRewards.blocker(profile, "alley", "cats3")).never.to.be.ok()
			profile.indexRewards.alley = { cats3 = true }
			expect(IndexRewards.blocker(profile, "alley", "cats3")).to.equal("Already claimed")
			expect(IndexRewards.claimed(profile, "alley", "cats3")).to.equal(true)
			expect(IndexRewards.claimed(profile, "park", "cats3")).to.equal(false)
		end)

		it("gold10 counts the gold collection", function()
			local profile = profileWith(ALLEY_CATS, { "tabby", "tuxedo" })
			expect(IndexRewards.blocker(profile, "alley", "cats10")).never.to.be.ok()
			expect(IndexRewards.blocker(profile, "alley", "gold10")).to.equal(
				"Find 8 more gold cats first"
			)
			for _, catId in ipairs(ALLEY_CATS) do
				profile.goldCollection[catId] = 1000
			end
			expect(IndexRewards.blocker(profile, "alley", "gold10")).never.to.be.ok()
		end)

		it("refuses unknown areas and milestones", function()
			local profile = profileWith(ALLEY_CATS)
			expect(IndexRewards.blocker(profile, "moon", "cats3")).to.equal("Unknown reward")
			expect(IndexRewards.blocker(profile, "alley", "cats99")).to.equal("Unknown reward")
			expect(IndexRewards.milestone("cats6")).to.equal(Catalog.indexMilestones[2])
			expect(IndexRewards.prize("alley", "cats3")).to.equal(Catalog.indexPrizes.alley.cats3)
			expect(IndexRewards.prize("alley", "nope")).never.to.be.ok()
		end)
	end)
	describe("All Cats, the Decor Index and the permanent bonuses (F54)", function()
		local function fresh(): any
			return ProfileSchema.template(1000)
		end

		it("counts different cats of every area on the All Cats page", function()
			local profile = fresh()
			table.clear(profile.collection)
			for _, catId in { "tabby", "tuxedo", "ginger", "snow", "cream" } do
				profile.collection[catId] = 1000
			end
			profile.goldCollection.tabby = 1000 -- a gold cat is not a second entry
			expect(IndexRewards.progress(profile.collection, IndexRewards.ALL)).to.equal(5)
			expect(IndexRewards.blocker(profile, "all", "total5")).never.to.be.ok()
			expect(IndexRewards.blocker(profile, "all", "total10")).to.equal("Find 5 more cats first")
			expect(IndexRewards.blocker(profile, "all", "cats3")).to.equal("Unknown reward")
			expect(IndexRewards.blocker(profile, "alley", "total5")).to.equal("Unknown reward")
		end)

		it("counts a Decor Index page from the crate's pieces owned", function()
			local profile = fresh()
			local owned = 0
			for _, def in Catalog.crateDecor do
				if def.crate == "park" and owned < 5 then
					profile.decorOwned[def.id] = true
					owned += 1
				end
			end
			expect(IndexRewards.blocker(profile, "decor_park", "decor5")).never.to.be.ok()
			expect(IndexRewards.blocker(profile, "decor_park", "decor10")).to.equal("Find 5 more pieces first")
			expect(IndexRewards.blocker(profile, "decor_woods", "decor5")).to.equal("Find 5 more pieces first")
			expect(IndexRewards.blocker(profile, "decor_park", "gold1")).to.equal("Unknown reward")
		end)

		it("sums the claimed milestones' bonuses, with gold luck and bait speed capped", function()
			local profile = fresh()
			local totals = IndexRewards.totals(profile)
			expect(totals :: any).to.deepEqual({ bonus = 0, goldLuck = 0, baitSpeed = 0 })
			profile.indexRewards.alley = { cats6 = true, cats10 = true, gold1 = true, gold10 = true }
			profile.indexRewards.all = { total5 = true, total50 = true }
			profile.indexRewards.decor_classic = { decor10 = true }
			totals = IndexRewards.totals(profile)
			expect(totals.bonus).to.be.near(0.02 + 0.05 + 0.05, 1e-9)
			expect(totals.goldLuck).to.be.near(0.12, 1e-9)
			expect(totals.baitSpeed).to.be.near(0.12, 1e-9)
			for _, areaId in AREAS do
				local claims: { [string]: boolean } = {}
				for _, id in AREA_MILESTONES do
					claims[id] = true
				end
				profile.indexRewards[areaId] = claims
			end
			local all: { [string]: boolean } = {}
			for id in pairs(Catalog.indexPrizes.all) do
				all[id] = true
			end
			profile.indexRewards.all = all
			totals = IndexRewards.totals(profile)
			expect(totals.goldLuck).to.be.near(Config.GoldLuckMax, 1e-9)
			expect(totals.baitSpeed).to.be.near(0.38, 1e-9)
		end)

		it("lifts a gold chance by gold luck, at most to 2.5 times", function()
			expect(IndexRewards.goldChance(0.05, 0)).to.be.near(0.05, 1e-9)
			expect(IndexRewards.goldChance(0.05, 0.3)).to.be.near(0.065, 1e-9)
			expect(IndexRewards.goldChance(0.05, 1.5)).to.be.near(0.125, 1e-9)
			expect(IndexRewards.goldChance(0.10, 9)).to.be.near(0.25, 1e-9)
		end)

		it("rolls shared cats with the best luck among players who have the area open", function()
			local low, high, locked = fresh(), fresh(), fresh()
			low.indexRewards.alley = { gold1 = true }
			high.indexRewards.alley = { gold1 = true, gold2 = true, gold4 = true }
			locked.indexRewards.alley = { gold8 = true, gold10 = true }
			low.tier, high.tier, locked.tier = 3, 3, 1
			local function tierOf(profile: any): number
				return profile.tier
			end
			-- an Alleyway stray (Tier 1): everyone has it open, the best luck wins
			expect(IndexRewards.bestGoldLuck({ low, high, locked }, 1, tierOf)).to.be.near(0.15, 1e-9)
			-- a Park stray (Tier 2): the Tier 1 player's luck does not count
			expect(IndexRewards.bestGoldLuck({ low, high, locked }, 2, tierOf)).to.be.near(0.10, 1e-9)
			expect(IndexRewards.bestGoldLuck({ low, locked }, 2, tierOf)).to.be.near(0.02, 1e-9)
			expect(IndexRewards.bestGoldLuck({ low, high, locked }, 4, tierOf)).to.equal(0)
			expect(IndexRewards.bestGoldLuck({}, 1, tierOf)).to.equal(0)
		end)

		it("names the first player with that luck for the Index Board, none at 0", function()
			local low, high, twin = fresh(), fresh(), fresh()
			low.indexRewards.alley = { gold1 = true }
			high.indexRewards.alley = { gold1 = true, gold2 = true }
			twin.indexRewards.alley = { gold1 = true, gold2 = true }
			low.tier, high.tier, twin.tier = 3, 1, 3
			local function tierOf(profile: any): number
				return profile.tier
			end
			local luck, from = IndexRewards.luckiest({ low, high, twin }, 1, tierOf)
			expect(luck).to.be.near(0.05, 1e-9)
			expect(from).to.equal(2)
			luck, from = IndexRewards.luckiest({ low, high, twin }, 2, tierOf)
			expect(luck).to.be.near(0.05, 1e-9)
			expect(from).to.equal(3)
			luck, from = IndexRewards.luckiest({ fresh() }, 1, tierOf)
			expect(luck).to.equal(0)
			expect(from).never.to.be.ok()
		end)
	end)
end
