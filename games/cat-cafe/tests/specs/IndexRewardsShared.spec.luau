--!strict
-- shared/IndexRewards.luau and the Index reward tables (F48, data-model section 11b).
return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local IndexRewards = require(ReplicatedStorage.Shared.IndexRewards)
	local Catalog = require(ReplicatedStorage.Shared.Catalog)
	local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)

	local AREAS = { "alley", "park", "neighbourhood", "woods", "sewer" }

	describe("Catalog tables (section 11b)", function()
		it("has the four milestones in order", function()
			expect(Catalog.indexMilestones :: any).to.deepEqual({
				{ id = "cats3", need = 3 },
				{ id = "cats6", need = 6 },
				{ id = "cats10", need = 10 },
				{ id = "gold10", need = 10, gold = true },
			})
		end)

		it("pays the 11b prizes in every area", function()
			-- area -> { cats3 coins, cats6 food and count, cats10 food and count }
			local expected: { [string]: { any } } = {
				alley = { 300, "tuna", 2, "salmon", 1 },
				park = { 1000, "salmon", 2, "caviar", 1 },
				neighbourhood = { 3000, "caviar", 2, "moon_milk", 1 },
				woods = { 10000, "moon_milk", 2, "star_treat", 1 },
				sewer = { 30000, "star_treat", 2, "star_treat", 2 },
			}
			for _, areaId in ipairs(AREAS) do
				local row = expected[areaId]
				local prizes = Catalog.indexPrizes[areaId]
				expect(prizes).to.be.ok()
				expect(prizes.cats3 :: any).to.deepEqual({ coins = row[1] })
				expect(prizes.cats6 :: any).to.deepEqual({ lures = { [row[2]] = row[3] } })
				expect(prizes.cats10 :: any).to.deepEqual({
					lures = { [row[4]] = row[5] },
					decorId = "index_" .. areaId,
				})
				expect(prizes.gold10 :: any).to.deepEqual({ decorId = "index_" .. areaId .. "_gold" })
				expect(Catalog.getArea(areaId)).to.be.ok()
			end
			for areaId in pairs(Catalog.indexPrizes) do
				expect(table.find(AREAS, areaId) ~= nil).to.equal(true)
			end
		end)

		it("the prize table is frozen, so no write can change a prize (S61)", function()
			expect(table.isfrozen(Catalog.indexPrizes)).to.equal(true)
			expect(table.isfrozen(Catalog.indexPrizes.alley)).to.equal(true)
			expect(table.isfrozen(Catalog.indexPrizes.alley.cats3)).to.equal(true)
			expect(table.isfrozen(Catalog.indexPrizes.alley.cats6.lures :: any)).to.equal(true)
			expect(pcall(function()
				(Catalog.indexPrizes.alley :: any).cats3 = true
			end)).to.equal(false)
		end)

		it("every prize names real foods and Index decor", function()
			for _, prizes in pairs(Catalog.indexPrizes) do
				for _, prize in pairs(prizes) do
					for lureId, count in pairs(prize.lures or {}) do
						expect(Catalog.getLure(lureId)).to.be.ok()
						expect(count > 0).to.equal(true)
					end
					if prize.decorId ~= nil then
						local decor = Catalog.getDecor(prize.decorId)
						expect(decor).to.be.ok()
						expect((decor :: any).source).to.equal("index")
					end
				end
			end
		end)

		it(
			"has an Index decor piece and a gold one per area, never sold, the gold one replacing the normal one",
			function()
				for _, areaId in ipairs(AREAS) do
					local piece = Catalog.getDecor("index_" .. areaId)
					local gold = Catalog.getDecor("index_" .. areaId .. "_gold")
					assert(piece and gold)
					expect(piece.cost).to.equal(0)
					expect(gold.cost).to.equal(0)
					expect(piece.source).to.equal("index")
					expect(gold.source).to.equal("index")
					expect(piece.bonus).to.be.near(0.05)
					expect(gold.bonus).to.be.near(0.10)
					expect(piece.replaces).never.to.be.ok()
					expect(gold.replaces).to.equal(piece.id)
					expect(gold.asset).to.equal(piece.asset .. "_Gold")
					expect(piece.requiresTier).never.to.be.ok()
				end
			end
		)
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
end
