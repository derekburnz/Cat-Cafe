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
				-- decor10 keeps its id but needs all twelve pieces since F80 (golden-fish.md 4b)
				expect(digits).to.equal(if milestone.id == "decor10" then 10 else milestone.needs)
				if milestone.id == "decor10" then
					expect(milestone.needs).to.equal(12)
				end
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

		it("gives each Decor Index page 25 fish at five pieces and +5% tips forever at all twelve", function()
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
			expect(IndexRewards.blocker(profile, "decor_park", "decor10")).to.equal("Find 7 more pieces first")
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
			-- rounded to six decimals, so the UI's plain floor of 600 x (1 - baitSpeed) is 372 too (review N184)
			expect(totals.baitSpeed).to.equal(0.38)
			expect(math.floor(600 * (1 - totals.baitSpeed))).to.equal(372)
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

	describe("Index rewards and Prizes edges (QA, after F54)", function()
		local Client = game:GetService("StarterPlayer")
			:WaitForChild("StarterPlayerScripts")
			:WaitForChild("Client")
		local Components = Client:WaitForChild("UI"):WaitForChild("Components")
		local CrateLogic = require(Components:WaitForChild("CrateLogic")) :: any
		local UIRewards = require(Components:WaitForChild("IndexRewards")) :: any
		local Economy = require(ReplicatedStorage.Shared.Economy)
		local Types = require(ReplicatedStorage.Shared.Types)

		-- Park and Miller's generator: exact in doubles, so a run is the same everywhere
		local seed = 54
		local function uniform(): number
			seed = seed * 48271 % 2147483647
			return seed / 2147483647
		end

		local function pages(): { string }
			local out: { string } = {}
			for areaId in pairs(Catalog.indexPrizes) do
				table.insert(out, areaId)
			end
			table.sort(out)
			return out
		end

		local function milestonesOf(areaId: string): { string }
			local out: { string } = {}
			for milestoneId in pairs(Catalog.indexPrizes[areaId]) do
				table.insert(out, milestoneId)
			end
			table.sort(out)
			return out
		end

		local function fullProfile(): any
			local profile: any = ProfileSchema.template(1000)
			for _, def in Catalog.cats do
				profile.collection[def.id] = 1000
				profile.goldCollection[def.id] = 1000
			end
			for _, def in Catalog.crateDecor do
				profile.decorOwned[def.id] = true
			end
			return profile
		end

		local function claim(profile: any, areaId: string, milestoneId: string)
			profile.indexRewards[areaId] = profile.indexRewards[areaId] or {}
			profile.indexRewards[areaId][milestoneId] = true
		end

		-- What a page counts, worked out here from the profile rather than through IndexRewards.count.
		local function ownCount(profile: any, areaId: string, track: string): number
			local n = 0
			if track == "decor" then
				for _, def in Catalog.crateDecor do
					if "decor_" .. tostring(def.crate) == areaId and profile.decorOwned[def.id] then
						n += 1
					end
				end
				return n
			end
			local collection = if track == "gold"
				then profile.goldCollection
				else profile.collection
			for _, def in Catalog.cats do
				if collection[def.id] ~= nil and (areaId == "all" or def.area == areaId) then
					n += 1
				end
			end
			return n
		end

		-- A crate chip shows CrateLogic.resolve and the claim or the wheel pays Prizes.crateFor, so the
		-- player gets the crate the card pictured at any tier.
		it("pays the crate the card shows, for highest and every crate id at any tier", function()
			local crates = CrateLogic.byId(Catalog.crates)
			local ids: { string } = { Prizes.HIGHEST }
			for _, crate in Catalog.crates do
				table.insert(ids, crate.id)
			end
			for _, tier in { 1, 2, 3, 4, 5, 6, 99, 1.5, 2.5, 4.99 } do
				for _, id in ids do
					local at = string.format("%s at tier %s: ", id, tostring(tier))
					local shown = CrateLogic.resolve(id, crates, Catalog.areas, tier)
					expect(at .. tostring(Prizes.crateFor(id, tier))).to.equal(at .. shown)
				end
			end
			-- Below Tier 1 (never: Economy.tier reads 1 to 5) the server pays no crate and the card keeps
			-- "highest", which it draws as a plain crate.
			for _, tier in { 0, 0.5, -1 } do
				expect(Prizes.crateFor(Prizes.HIGHEST, tier)).never.to.be.ok()
				local shown = CrateLogic.resolve(Prizes.HIGHEST, crates, Catalog.areas, tier)
				expect(shown).to.equal(CrateLogic.HIGHEST)
			end
		end)

		it(
			"pays a real crate for every crate an Index prize or a wheel slice names, at every tier",
			function()
				local named: { string } = {}
				for _, areaId in pages() do
					for _, prize in pairs(Catalog.indexPrizes[areaId]) do
						for crateId in pairs(prize.crates or {}) do
							table.insert(named, crateId)
						end
					end
				end
				for _, row in Catalog.spinWheel do
					if row.kind == "crate" then
						table.insert(named, row.crate or Prizes.HIGHEST)
					end
				end
				expect(#named > 0).to.equal(true)
				for tier = 1, 5 do
					for _, crateId in named do
						local paid = Prizes.crateFor(crateId, tier)
						local real = paid ~= nil and Catalog.getCrate(paid) ~= nil
						expect(string.format("%s at tier %d %s", crateId, tier, tostring(real))).to.equal(
							string.format("%s at tier %d true", crateId, tier)
						)
					end
				end
			end
		)

		-- The card prices coinSeconds with the UI's IndexRewards.coins; the claim pays Prizes.coins.
		-- At the same day rate they must agree on every card, odd rates included.
		it("prices every card's coins as the claim pays them, at any day rate", function()
			local rates = { 0, 0.4, 1, 1.5, 2.75, 7.3, 123.456, 1e4, 3.3e6, -5, -math.huge, 0 / 0 }
			local checked = 0
			for _, areaId in pages() do
				for _, milestoneId in milestonesOf(areaId) do
					local prize = Catalog.indexPrizes[areaId][milestoneId]
					for _, rate in rates do
						local at =
							string.format("%s.%s at %s: ", areaId, milestoneId, tostring(rate))
						local pays = Prizes.coins(prize.coins, prize.coinSeconds, rate)
						expect(at .. UIRewards.coins(prize, rate)).to.equal(at .. pays)
						local shown = 0
						for _, part in UIRewards.prizeParts(prize, rate) do
							if part.kind == "coins" then
								shown += part.amount
							end
						end
						expect(at .. shown).to.equal(at .. pays)
						checked += 1
					end
				end
			end
			expect(checked > 0).to.equal(true)
		end)

		-- ClaimIndexReward takes any two strings Guard.id lets through. Only a pair the prize table has
		-- can pay; every other pair, odd page ids and track mixes included, is "Unknown reward".
		it(
			"pays only the pairs the prize table has, whatever page and milestone ids arrive",
			function()
				local profile = fullProfile()
				local pageIds = pages()
				for _, odd in
					{
						"decor_",
						"decor",
						"decor_decor_alley",
						"decor_alley_crate",
						"decor_alley_golden",
						"decor_all",
						"all_",
						"alley_crate",
						"classic",
						"golden",
						"street",
						"__index",
					}
				do
					table.insert(pageIds, odd)
				end
				local milestoneIds: { string } = {}
				for _, milestone in Catalog.indexMilestones do
					table.insert(milestoneIds, milestone.id)
				end
				for _, odd in
					{
						"cats0",
						"cats3_",
						"gold0",
						"gold3",
						"total0",
						"total55",
						"decor0",
						"decor15",
						"__index",
					}
				do
					table.insert(milestoneIds, odd)
				end
				local function sweep(claimed: boolean): number
					local paying = 0
					for _, areaId in pageIds do
						for _, milestoneId in milestoneIds do
							local page = Catalog.indexPrizes[areaId]
							local has = page ~= nil and page[milestoneId] ~= nil
							local want = if not has
								then "Unknown reward"
								elseif claimed then "Already claimed"
								else "nil"
							local at = string.format('"%s" "%s": ', areaId, milestoneId)
							local blocker = IndexRewards.blocker(profile, areaId, milestoneId)
							expect(at .. tostring(blocker)).to.equal(at .. want)
							if blocker == nil then
								paying += 1
							end
						end
					end
					return paying
				end
				local total = 0
				for _, areaId in pages() do
					total += #milestonesOf(areaId)
				end
				expect(sweep(false)).to.equal(total)
				for _, areaId in pages() do
					for _, milestoneId in milestonesOf(areaId) do
						claim(profile, areaId, milestoneId)
					end
				end
				expect(sweep(true)).to.equal(0)
			end
		)

		-- golden-fish.md sections 4, 5 and 5b: +7% tips a normal track, +5% a full Decor page, +30% gold
		-- luck a gold track up to GoldLuckMax, 38% faster bait. No cap may eat a bonus a card promises.
		it("sums the whole Index once: +65% tips, gold luck at its cap, 38% faster bait", function()
			local profile = fullProfile()
			local sums = { bonus = 0, goldLuck = 0, baitSpeed = 0 }
			for _, areaId in pages() do
				for _, prize in pairs(Catalog.indexPrizes[areaId]) do
					sums.bonus += prize.bonus or 0
					sums.goldLuck += prize.goldLuck or 0
					sums.baitSpeed += prize.baitSpeed or 0
				end
			end
			expect(sums.goldLuck <= Config.GoldLuckMax + 1e-9).to.equal(true)
			expect(sums.baitSpeed <= Config.BaitSpeedMax + 1e-9).to.equal(true)
			local before = Economy.cafeMultiplier(profile)
			for _, areaId in pages() do
				for _, milestoneId in milestonesOf(areaId) do
					claim(profile, areaId, milestoneId)
				end
			end
			local totals = IndexRewards.totals(profile)
			expect(math.abs(totals.bonus - 0.65) < 1e-9).to.equal(true)
			expect(math.abs(totals.goldLuck - Config.GoldLuckMax) < 1e-9).to.equal(true)
			expect(math.abs(totals.baitSpeed - 0.38) < 1e-9).to.equal(true)
			-- the full Decor pages count through their decor10 claims only, not a second time for being full
			expect(math.abs(Economy.cafeMultiplier(profile) - before - 0.65) < 1e-9).to.equal(true)
			expect(
				math.abs(IndexRewards.goldChance(Config.GoldChanceBait, totals.goldLuck) - 0.125)
					< 1e-9
			).to.equal(true)
		end)

		-- The Collection header's "Forever" pills read the UI's IndexRewards.totals (UI PR #332), and the
		-- server rolls and pays with the shared one; any set of claims must give the same three numbers.
		it("shows the forever totals the server applies, for any set of claims", function()
			expect(UIRewards.GOLD_LUCK_MAX).to.equal(Config.GoldLuckMax)
			expect(UIRewards.BAIT_SPEED_MAX).to.equal(Config.BaitSpeedMax)
			expect(UIRewards.GOLD_CHANCE).to.equal(Config.GoldChanceBait)
			local all: { { string } } = {}
			for _, areaId in pages() do
				for _, milestoneId in milestonesOf(areaId) do
					table.insert(all, { areaId, milestoneId })
				end
			end
			for run = 0, 40 do
				local profile: any = ProfileSchema.template(1000)
				local share = run / 40
				for _, pair in all do
					if uniform() < share then
						claim(profile, pair[1], pair[2])
					end
				end
				local server = IndexRewards.totals(profile)
				local shown = UIRewards.totals(Catalog, { indexRewards = profile.indexRewards })
				for _, key in { "bonus", "goldLuck", "baitSpeed" } do
					local gap = math.abs((shown :: any)[key] - (server :: any)[key])
					expect(string.format("run %d %s %s", run, key, tostring(gap < 1e-9))).to.equal(
						string.format("run %d %s true", run, key)
					)
				end
				for _, luck in { 0, server.goldLuck, 0.3, Config.GoldLuckMax, 2, -1 } do
					local ui = UIRewards.goldChance(Config.GoldChanceBait, luck)
					local real = IndexRewards.goldChance(Config.GoldChanceBait, luck)
					expect(math.abs(ui - real) < 1e-12).to.equal(true)
				end
			end
			expect(UIRewards.perkLabel("goldLuck", 0.3)).to.equal("+30% gold luck (gold 6.5%)")
			expect(UIRewards.perkLabel("goldLuck", Config.GoldLuckMax)).to.equal(
				"+150% gold luck (gold 12.5%)"
			)
			expect(UIRewards.perkLabel("baitSpeed", 0.38)).to.equal("+38% faster bait")
		end)

		it(
			"keeps blockers, claims and bonuses in step over 60 seeded collections and claim orders",
			function()
				local all: { { string } } = {}
				for _, areaId in pages() do
					for _, milestoneId in milestonesOf(areaId) do
						table.insert(all, { areaId, milestoneId })
					end
				end
				for _ = 1, 60 do
					local profile: any = ProfileSchema.template(1000)
					table.clear(profile.collection)
					local keep = uniform()
					for _, def in Catalog.cats do
						if uniform() < keep then
							profile.collection[def.id] = 1000
							if uniform() < keep then
								profile.goldCollection[def.id] = 1000
							end
						end
					end
					for _, def in Catalog.crateDecor do
						if uniform() < keep then
							profile.decorOwned[def.id] = true
						end
					end
					local order = table.clone(all)
					for i = #order, 2, -1 do
						local j = 1 + math.floor(uniform() * i)
						order[i], order[j] = order[j], order[i]
					end
					local want = { bonus = 0, goldLuck = 0, baitSpeed = 0 }
					for _, pair in order do
						local areaId, milestoneId = pair[1], pair[2]
						local milestone =
							IndexRewards.milestone(milestoneId) :: Types.IndexMilestone
						local left = milestone.needs - ownCount(profile, areaId, milestone.track)
						local blocker = IndexRewards.blocker(profile, areaId, milestoneId)
						local at = areaId .. "." .. milestoneId .. ": "
						if left > 0 then
							local what = if milestone.track == "decor"
								then "piece"
								elseif milestone.track == "gold" then "gold cat"
								else "cat"
							local text = string.format(
								"Find %d more %s%s first",
								left,
								what,
								if left == 1 then "" else "s"
							)
							expect(at .. tostring(blocker)).to.equal(at .. text)
							continue
						end
						expect(at .. tostring(blocker)).to.equal(at .. "nil")
						claim(profile, areaId, milestoneId)
						expect(IndexRewards.blocker(profile, areaId, milestoneId)).to.equal(
							"Already claimed"
						)
						local prize = Catalog.indexPrizes[areaId][milestoneId]
						want.bonus += prize.bonus or 0
						want.goldLuck += prize.goldLuck or 0
						want.baitSpeed += prize.baitSpeed or 0
						local totals = IndexRewards.totals(profile)
						expect(math.abs(totals.bonus - want.bonus) < 1e-9).to.equal(true)
						expect(
							math.abs(totals.goldLuck - math.min(want.goldLuck, Config.GoldLuckMax))
								< 1e-9
						).to.equal(true)
						expect(
							math.abs(
								totals.baitSpeed - math.min(want.baitSpeed, Config.BaitSpeedMax)
							) < 1e-9
						).to.equal(true)
					end
				end
			end
		)

		-- golden-fish.md section 5: "the full track takes the day wait from 10:00 to 6:12". Each All Cats
		-- claim takes whole percents off; the wait loses exactly that, never a second more to a float sum.
		it(
			"takes exactly the claimed percent off the bait wait, with and without the Big Bowl",
			function()
				local order = milestonesOf("all")
				table.sort(order, function(a: string, b: string): boolean
					local ma = IndexRewards.milestone(a) :: Types.IndexMilestone
					local mb = IndexRewards.milestone(b) :: Types.IndexMilestone
					return ma.needs < mb.needs
				end)
				for _, bowl in { 0, 1 } do
					local profile: any = ProfileSchema.template(1000)
					if bowl == 1 then
						profile.fishPerks.big_bowl = 1
					end
					local base = if bowl == 1
						then Config.BigBowlLureWaitSeconds
						else Config.LureWaitSeconds
					expect(Economy.baitWaitSeconds(profile)).to.equal(base)
					local off = 0
					for _, milestoneId in order do
						local speed = Catalog.indexPrizes.all[milestoneId].baitSpeed :: number
						local percent = math.floor(speed * 100 + 0.5)
						expect(math.abs(speed * 100 - percent) < 1e-9).to.equal(true)
						off += percent
						claim(profile, "all", milestoneId)
						local at = string.format("%s, bowl %d: ", milestoneId, bowl)
						local want = math.floor(base * (100 - off) / 100)
						expect(at .. Economy.baitWaitSeconds(profile)).to.equal(at .. want)
					end
					expect(off).to.equal(38)
					expect(Economy.baitWaitSeconds(profile)).to.equal(
						if bowl == 1 then 297 else 372
					)
				end
			end
		)

		it("keeps a Decor page's claims through F80: twelve pieces for decor10, an earlier claim kept", function()
			local decor10 = assert(IndexRewards.milestone("decor10"))
			local decor5 = assert(IndexRewards.milestone("decor5"))
			for _, pool in POOLS do
				local page = "decor_" .. pool
				local older: { any } = {}
				local door: any, flap: any = nil, nil
				for _, def in Catalog.crateDecor do
					if def.crate ~= pool then
						continue
					elseif def.kind == "door" then
						door = def
					elseif def.kind == "catflap" then
						flap = def
					else
						table.insert(older, def)
					end
				end
				expect(#older).to.equal(10)
				assert(door and flap)
				-- the ten pieces a page had before F80 leave decor10 two short, then one, then claimable
				local profile = ProfileSchema.template(1000) :: any
				for _, def in older do
					profile.decorOwned[def.id] = true
				end
				expect(IndexRewards.blocker(profile, page, "decor5")).never.to.be.ok()
				expect(IndexRewards.blocker(profile, page, "decor10")).to.equal("Find 2 more pieces first")
				profile.decorOwned[door.id] = true
				expect(IndexRewards.blocker(profile, page, "decor10")).to.equal("Find 1 more piece first")
				profile.decorOwned[flap.id] = true
				expect(IndexRewards.blocker(profile, page, "decor10")).never.to.be.ok()
				-- a door set and a cat flap count toward decor5 like any piece
				local early = ProfileSchema.template(1000) :: any
				early.decorOwned[door.id] = true
				early.decorOwned[flap.id] = true
				for i = 1, 3 do
					early.decorOwned[older[i].id] = true
				end
				expect(IndexRewards.blocker(early, page, "decor5")).never.to.be.ok()
				early.decorOwned[older[3].id] = nil
				expect(IndexRewards.blocker(early, page, "decor5")).to.equal("Find 1 more piece first")
				-- section 4b: a page claimed at ten before F80 keeps its claim and its +5%
				local before = ProfileSchema.template(1000) :: any
				for _, def in older do
					before.decorOwned[def.id] = true
				end
				before.indexRewards[page] = { decor10 = true }
				expect(IndexRewards.blocker(before, page, "decor10")).to.equal("Already claimed")
				expect(IndexRewards.totals(before).bonus).to.be.near(Config.DecorIndexBonus, 1e-9)
				expect(UIRewards.totals(Catalog, { indexRewards = before.indexRewards }).bonus).to.be.near(
					Config.DecorIndexBonus,
					1e-9
				)
				-- the page's cards read "5 pieces" and "All 12" from the catalog's twelve
				local counts = UIRewards.counts(Catalog, { decorOwned = before.decorOwned }, page)
				expect(counts.total).to.equal(12)
				expect(counts.found).to.equal(10)
				expect(UIRewards.needLabel(decor5, counts.total, page)).to.equal("5 pieces")
				expect(UIRewards.needLabel(decor10, counts.total, page)).to.equal("All 12")
			end
		end)
	end)
end
