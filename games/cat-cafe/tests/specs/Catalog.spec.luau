--!strict
-- Catalog.luau against docs/design/cat-cafe/data-model.md v0.3.1 sections 1 to 9.
-- If the designer changes a number in the doc, change it here in the same commit.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)

	local ROLES = { "barista", "waiter", "greeter", "entertainer" }
	local ROLE_SET: { [string]: boolean } =
		{ barista = true, waiter = true, greeter = true, entertainer = true }
	local AREA_ORDER = { "alley", "park", "neighbourhood", "woods", "sewer" }
	local RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythical" }
	-- Per area: four Common, two Rare, two Epic, one Legendary, one Mythical (section 3).
	local PER_AREA: { [string]: number } =
		{ Common = 4, Rare = 2, Epic = 2, Legendary = 1, Mythical = 1 }

	local function assertUniqueSnakeCaseIds(list: { any })
		local seen = {}
		for _, def in ipairs(list) do
			expect(def.id).to.be.a("string")
			expect(string.match(def.id, "^[a-z][a-z0-9_]*$") ~= nil).to.equal(true)
			expect(seen[def.id]).never.to.be.ok()
			seen[def.id] = true
		end
	end

	local function oddsTotal(odds: any): number
		local total = 0
		for _, rarity in ipairs(RARITIES) do
			total += odds[rarity]
		end
		return total
	end

	local function assertFiveRarityOdds(odds: any)
		local keys = 0
		for key, value in pairs(odds) do
			keys += 1
			expect(Catalog.rarityRank[key]).to.be.ok()
			expect(value >= 0).to.equal(true)
		end
		expect(keys).to.equal(5)
		expect(oddsTotal(odds)).to.be.near(100, 1e-9)
	end

	describe("conventions (section 1)", function()
		it("every catalog uses unique lower snake_case ids", function()
			assertUniqueSnakeCaseIds(Catalog.cats)
			assertUniqueSnakeCaseIds(Catalog.upgrades)
			assertUniqueSnakeCaseIds(Catalog.decor)
			assertUniqueSnakeCaseIds(Catalog.lures)
			assertUniqueSnakeCaseIds(Catalog.areas)
			assertUniqueSnakeCaseIds(Catalog.spots)
		end)

		it("rarity order and rank agree, and Mythical replaces Secret", function()
			expect(Catalog.rarityOrder).to.deepEqual(RARITIES)
			for rank, rarity in ipairs(RARITIES) do
				expect(Catalog.rarityRank[rarity]).to.equal(rank)
			end
			expect(Catalog.rarities.Secret).never.to.be.ok()
			expect(Catalog.rarityRank.Secret).never.to.be.ok()
		end)

		it("model names derive from ids, and catsByModelName reverses it", function()
			expect(Catalog.catModelName("tabby")).to.equal("CatCafe_Cat_Tabby")
			expect(Catalog.catModelName("maine_coon")).to.equal("CatCafe_Cat_MaineCoon")
			expect(Catalog.catModelName("forest_cat")).to.equal("CatCafe_Cat_ForestCat")
			local count = 0
			for modelName, def in pairs(Catalog.catsByModelName) do
				count += 1
				expect(Catalog.catModelName(def.id)).to.equal(modelName)
			end
			expect(count).to.equal(#Catalog.cats)
		end)

		it(
			"a gold coat is its own model, the base name plus _Gold (v0.5 F42, renamed from shiny 2026-10-27)",
			function()
				expect(Catalog.goldModelName("tabby")).to.equal("CatCafe_Cat_Tabby_Gold")
				expect(Catalog.goldModelName("maine_coon")).to.equal("CatCafe_Cat_MaineCoon_Gold")
				for _, def in Catalog.cats do
					expect(Catalog.catsByModelName[Catalog.goldModelName(def.id)]).never.to.be.ok()
				end
			end
		)
	end)

	describe("rarities (section 2)", function()
		local expected = {
			-- v0.5: the fourth column is fleeStuds (the sprint after a miss), replacing the v0.4 patience
			Common = { 1, 1, 1.40, 12, 2, 25, 50, "#8E97B2" },
			Rare = { 3, 2, 1.15, 16, 3, 150, 300, "#5FA8FF" },
			Epic = { 8, 3, 0.95, 20, 4, 600, 1500, "#C07CFF" },
			Legendary = { 25, 4, 0.80, 26, 5, 3000, 8000, "#FFC94D" },
			Mythical = { 75, 5, 0.65, 32, 6, 12000, 30000, "#FF5E7E" },
		}
		for _, rarity in ipairs(RARITIES) do
			it(rarity .. " matches the table", function()
				local def = Catalog.rarities[rarity]
				expect(def).to.be.ok()
				assert(def)
				local row = expected[rarity]
				expect(def.incomePerSecond).to.equal(row[1])
				expect(def.circles).to.equal(row[2])
				expect(def.shrinkSeconds).to.be.near(row[3] :: number, 1e-9)
				expect(def.fleeStuds).to.equal(row[4])
				expect((def :: any).patience).never.to.be.ok()
				expect(def.rescueHits).to.equal(row[5])
				expect(def.sellValue).to.equal(row[6])
				expect(def.firstCatchReward).to.equal(row[7])
				expect(def.color).to.equal(row[8])
			end)
		end

		it("rarer means more circles, faster circles and more rescue hits", function()
			for i = 2, #RARITIES do
				local lower, higher =
					Catalog.rarities[RARITIES[i - 1]], Catalog.rarities[RARITIES[i]]
				expect(higher.circles > lower.circles).to.equal(true)
				expect(higher.shrinkSeconds < lower.shrinkSeconds).to.equal(true)
				expect(higher.rescueHits > lower.rescueHits).to.equal(true)
				expect(higher.incomePerSecond > lower.incomePerSecond).to.equal(true)
			end
		end)

		it("colors are 6 digit hex", function()
			for _, def in pairs(Catalog.rarities) do
				expect(string.match(def.color, "^#%x%x%x%x%x%x$") ~= nil).to.equal(true)
			end
		end)

		it("v0.3: baseCatchChance is gone, the circles decide the chance (F26)", function()
			for _, def in pairs(Catalog.rarities) do
				expect((def :: any).baseCatchChance).never.to.be.ok()
			end
		end)
	end)

	describe("cats (section 3)", function()
		-- Sections 3a and 3b: id -> { name, rarity, area, favoriteRole, description }
		local slice: { [string]: { string } } = {
			tabby = { "Tabby", "Common", "alley", "barista", "The starter. Stripes, snacks, naps." },
			tuxedo = {
				"Tuxedo",
				"Common",
				"alley",
				"waiter",
				"Dressed for dinner, waiting for it.",
			},
			ginger = { "Ginger", "Common", "alley", "greeter", "Warm, round, always in the sun." },
			smoke = { "Smoke", "Common", "alley", "entertainer", "Grey as a rainy morning." },
			calico = {
				"Pirate Cat",
				"Rare",
				"alley",
				"waiter",
				"Carries every tray like buried treasure.",
			},
			tortie = {
				"Rocker Cat",
				"Rare",
				"alley",
				"entertainer",
				"Knows one chord and plays it very loudly.",
			},
			sphynx = {
				"DJ Cat",
				"Epic",
				"alley",
				"greeter",
				"Drops a beat every time the door opens.",
			},
			maine_coon = {
				"Bandit Cat",
				"Epic",
				"alley",
				"barista",
				"Sneaks extra foam onto every latte.",
			},
			void = {
				"Ninja Cat",
				"Legendary",
				"alley",
				"waiter",
				"Silent, fast and never spills a drop.",
			},
			midnight = {
				"Wizard Cat",
				"Mythical",
				"alley",
				"barista",
				"Stirs a little starlight into every cup.",
			},
			snow = { "Snow", "Common", "park", "waiter", "All white, hates the muddy paths." },
			cream = {
				"Cream",
				"Common",
				"park",
				"barista",
				"The color of a latte, and smells faintly of one.",
			},
			brownie = {
				"Brownie",
				"Common",
				"park",
				"entertainer",
				"Chocolate stripes, chases every leaf.",
			},
			blue = { "Blue", "Common", "park", "greeter", "Silver-blue and very polite." },
			siamese = {
				"Nerd Cat",
				"Rare",
				"park",
				"barista",
				"Measures every latte to the last drop.",
			},
			bengal = {
				"Explorer Cat",
				"Rare",
				"park",
				"entertainer",
				"Tells tall tales about the wild side of the Park.",
			},
			ragdoll = {
				"Sleepy Cat",
				"Epic",
				"park",
				"greeter",
				"Says hello with an enormous yawn.",
			},
			persian = {
				"Fancy Cat",
				"Epic",
				"park",
				"waiter",
				"Serves every cup on a silver tray.",
			},
			blossom = {
				"Fairy Cat",
				"Legendary",
				"park",
				"barista",
				"Leaves a petal on every saucer.",
			},
			aurora = {
				"Astro Cat",
				"Mythical",
				"park",
				"entertainer",
				"Moonwalks between the tables.",
			},
		}
		-- Section 3c, provisional: id -> { name, rarity, area, favoriteRole }. Descriptions are placeholders.
		local reserved: { [string]: { string } } = {
			biscuit = { "Biscuit", "Common", "neighbourhood", "barista" },
			pepper = { "Pepper", "Common", "neighbourhood", "waiter" },
			socks = { "Socks", "Common", "neighbourhood", "greeter" },
			butter = { "Butter", "Common", "neighbourhood", "entertainer" },
			munchkin = { "Munchkin", "Rare", "neighbourhood", "entertainer" },
			fold = { "Fold", "Rare", "neighbourhood", "waiter" },
			chonk = { "Chonk", "Epic", "neighbourhood", "barista" },
			postie = { "Postie", "Epic", "neighbourhood", "greeter" },
			marshmallow = { "Marshmallow", "Legendary", "neighbourhood", "waiter" },
			comet = { "Comet", "Mythical", "neighbourhood", "entertainer" },
			moss = { "Moss", "Common", "woods", "greeter" },
			acorn = { "Acorn", "Common", "woods", "barista" },
			bramble = { "Bramble", "Common", "woods", "waiter" },
			fern = { "Fern", "Common", "woods", "entertainer" },
			pinecone = { "Pinecone", "Rare", "woods", "barista" },
			forest_cat = { "Forest Cat", "Rare", "woods", "greeter" },
			toadstool = { "Toadstool", "Epic", "woods", "entertainer" },
			firefly = { "Firefly", "Epic", "woods", "waiter" },
			old_oak = { "Old Oak", "Legendary", "woods", "barista" },
			wisp = { "Wisp", "Mythical", "woods", "greeter" },
			rusty = { "Rusty", "Common", "sewer", "waiter" },
			soot = { "Soot", "Common", "sewer", "barista" },
			pipes = { "Pipes", "Common", "sewer", "entertainer" },
			puddle = { "Puddle", "Common", "sewer", "greeter" },
			lantern = { "Lantern", "Rare", "sewer", "waiter" },
			bubbles = { "Bubbles", "Rare", "sewer", "entertainer" },
			gears = { "Gears", "Epic", "sewer", "barista" },
			glimmer = { "Glimmer", "Epic", "sewer", "greeter" },
			bottlecap = { "Bottlecap King", "Legendary", "sewer", "waiter" },
			eclipse = { "Eclipse", "Mythical", "sewer", "barista" },
		}

		it("has exactly the 50 cats: the 20 slice cats and the 30 reserved ids", function()
			expect(#Catalog.cats).to.equal(50)
			for _, def in ipairs(Catalog.cats) do
				expect(slice[def.id] ~= nil or reserved[def.id] ~= nil).to.equal(true)
			end
			for id in pairs(slice) do
				expect(Catalog.getCat(id)).to.be.ok()
			end
			for id in pairs(reserved) do
				expect(Catalog.getCat(id)).to.be.ok()
			end
		end)

		for id, row in pairs(slice) do
			it(id .. " matches its row in section 3a or 3b", function()
				local def = Catalog.getCat(id)
				expect(def).to.be.ok()
				assert(def)
				expect(def.name).to.equal(row[1])
				expect(def.rarity).to.equal(row[2])
				expect(def.area).to.equal(row[3])
				expect(def.favoriteRole).to.equal(row[4])
				expect(def.description).to.equal(row[5])
				expect(def.incomePerSecond).to.equal(Catalog.rarities[def.rarity].incomePerSecond)
			end)
		end

		it(
			"the reserved section 3c ids have the rarity, area and favorite role from the table",
			function()
				for id, row in pairs(reserved) do
					local def = Catalog.getCat(id)
					assert(def, id)
					expect(def.name).to.equal(row[1])
					expect(def.rarity).to.equal(row[2])
					expect(def.area).to.equal(row[3])
					expect(def.favoriteRole).to.equal(row[4])
					expect(def.incomePerSecond).to.equal(
						Catalog.rarities[def.rarity].incomePerSecond
					)
				end
			end
		)

		it(
			"each area has four Common, two Rare, two Epic, one Legendary and one Mythical",
			function()
				local counts: { [string]: { [string]: number } } = {}
				for _, area in ipairs(AREA_ORDER) do
					counts[area] = {}
				end
				for _, def in ipairs(Catalog.cats) do
					local area = counts[def.area]
					expect(area).to.be.ok()
					assert(area)
					area[def.rarity] = (area[def.rarity] or 0) + 1
				end
				for _, area in ipairs(AREA_ORDER) do
					for rarity, n in pairs(PER_AREA) do
						expect(counts[area][rarity]).to.equal(n)
					end
				end
			end
		)

		it(
			"every cat has display fields, one area, a role and a valid placeholder color",
			function()
				local areaSet: { [string]: boolean } = {}
				for _, area in ipairs(AREA_ORDER) do
					areaSet[area] = true
				end
				for _, def in ipairs(Catalog.cats) do
					expect(#def.name > 0).to.equal(true)
					expect(#def.description > 0).to.equal(true)
					expect(#def.pattern > 0).to.equal(true)
					expect(ROLE_SET[def.favoriteRole]).to.equal(true)
					expect(areaSet[def.area]).to.equal(true)
					expect((def :: any).favoriteSpot).never.to.be.ok()
					expect(#def.color).to.equal(3)
					for _, channel in ipairs(def.color) do
						expect(channel >= 0 and channel <= 255 and channel == math.floor(channel)).to.equal(
							true
						)
					end
				end
			end
		)

		it("getCat returns nil for unknown ids", function()
			expect(Catalog.getCat("golden")).never.to.be.ok()
			expect(Catalog.getCat("")).never.to.be.ok()
		end)
	end)

	describe("role slots (section 5)", function()
		it("opens the listed slots at the listed tiers", function()
			local expected: { [string]: { any } } = {
				barista_1 = { "barista", 1 },
				waiter_1 = { "waiter", 1 },
				waiter_2 = { "waiter", 2 },
				greeter_1 = { "greeter", 2 },
				barista_2 = { "barista", 3 },
				entertainer_1 = { "entertainer", 3 },
				waiter_3 = { "waiter", 4 },
				greeter_2 = { "greeter", 4 },
				barista_3 = { "barista", 5 },
				entertainer_2 = { "entertainer", 5 },
			}
			expect(#Catalog.spots).to.equal(10)
			for id, row in pairs(expected) do
				local spot = Catalog.getSpot(id)
				expect(spot).to.be.ok()
				assert(spot)
				expect(spot.spotType).to.equal(row[1])
				expect(spot.tier).to.equal(row[2])
				expect((spot :: any).cafeLevel).never.to.be.ok()
				expect(string.match(id, "^" .. row[1] .. "_%d+$") ~= nil).to.equal(true)
			end
			expect(Catalog.getSpot("counter_1")).never.to.be.ok()
			expect(Catalog.getSpot("window_1")).never.to.be.ok()
		end)

		it("slots are listed in opening order and each tier opens its slot count", function()
			local lastTier = 0
			for _, spot in ipairs(Catalog.spots) do
				expect(spot.tier >= lastTier).to.equal(true)
				lastTier = spot.tier
			end
			for _, tierDef in ipairs(Catalog.tiers) do
				local open = 0
				for _, spot in ipairs(Catalog.spots) do
					if spot.tier <= tierDef.tier then
						open += 1
					end
				end
				expect(open).to.equal(tierDef.slots)
			end
		end)

		it("every role has a slot and its favorite cats somewhere", function()
			for _, role in ipairs(ROLES) do
				local slot, fan = false, false
				for _, spot in ipairs(Catalog.spots) do
					slot = slot or spot.spotType == role
				end
				for _, def in ipairs(Catalog.cats) do
					fan = fan or def.favoriteRole == role
				end
				expect(slot).to.equal(true)
				expect(fan).to.equal(true)
			end
		end)

		it("station furniture is keyed by role and names a furniture model", function()
			for role, furniture in pairs(Catalog.spotFurniture) do
				expect(ROLE_SET[role]).to.equal(true)
				expect(string.sub(furniture, 1, 18)).to.equal("CatCafe_Furniture_")
			end
		end)

		it("every role has a two-piece outfit of distinct accessories (F25)", function()
			local seen: { [string]: boolean } = {}
			for _, role in ipairs(ROLES) do
				local pieces = Catalog.roleOutfits[role]
				expect(pieces).to.be.ok()
				assert(pieces)
				expect(#pieces).to.equal(2)
				for _, piece in pieces do
					expect(string.match(piece, "^%u%a+$") ~= nil).to.equal(true)
					expect(seen[piece]).never.to.be.ok()
					seen[piece] = true
				end
			end
			for role in pairs(Catalog.roleOutfits) do
				expect(ROLE_SET[role]).to.equal(true)
			end
			expect(Catalog.accessoryModelName("BaristaCap")).to.equal(
				"CatCafe_Accessory_BaristaCap"
			)
		end)

		it(
			"a themed cat's prop slot drops at most one piece of any outfit (v0.5.2 section 3)",
			function()
				local pieceSet: { [string]: boolean } = {}
				for _, pieces in pairs(Catalog.roleOutfits) do
					for _, piece in pieces do
						pieceSet[piece] = true
					end
				end
				for piece, slot in pairs(Catalog.outfitPieceSlots) do
					expect(pieceSet[piece]).to.equal(true)
					expect(slot == "Head" or slot == "Back").to.equal(true)
				end
				expect(Catalog.outfitPieceSlots.BaristaCap).to.equal("Head")
				expect(Catalog.outfitPieceSlots.Boater).to.equal("Head")
				expect(Catalog.outfitPieceSlots.PartyHat).to.equal("Head")
				expect(Catalog.outfitPieceSlots.Cape).to.equal("Back")
				-- Whatever the prop's slot, every role keeps at least one piece, so a working cat still reads as staff.
				for _, propSlot in ipairs({ "Head", "Face", "Back" }) do
					for _, role in ipairs(ROLES) do
						local kept = 0
						for _, piece in Catalog.roleOutfits[role] do
							if Catalog.outfitPieceSlots[piece] ~= propSlot then
								kept += 1
							end
						end
						expect(kept >= 1).to.equal(true)
					end
				end
			end
		)
	end)

	describe("tiers (section 5b)", function()
		-- tier -> { name, cost, distinctCats, needsRarity, needsRarityCount, slots, multiplier, area, caps }
		local expected: { { any } } = {
			{ "Corner Cafe", 0, 0, nil, nil, 2, 1.00, "alley", { 2, 2, 1 } },
			{ "Cozy Cafe", 1500, 5, nil, nil, 4, 1.25, "park", { 4, 3, 2 } },
			{ "Busy Cafe", 8000, 12, "Epic", 1, 6, 1.50, "neighbourhood", { 6, 4, 3 } },
			{ "Famous Cafe", 30000, 20, "Legendary", 1, 8, 1.75, "woods", { 6, 5, 3 } },
			{ "Grand Cafe", 120000, 30, "Legendary", 2, 10, 2.00, "sewer", { 6, 5, 3 } },
		}

		it("has five tiers matching the table", function()
			expect(#Catalog.tiers).to.equal(5)
			expect(Catalog.maxTier).to.equal(5)
			for tier, row in ipairs(expected) do
				local def = Catalog.getTier(tier)
				expect(def).to.be.ok()
				assert(def)
				expect(def.tier).to.equal(tier)
				expect(def.name).to.equal(row[1])
				expect(def.cost).to.equal(row[2])
				expect(def.distinctCats).to.equal(row[3])
				expect(def.needsRarity).to.equal(row[4])
				expect(def.needsRarityCount).to.equal(row[5])
				expect(def.slots).to.equal(row[6])
				expect(def.multiplier).to.be.near(row[7], 1e-9)
				expect(def.area).to.equal(row[8])
				expect(def.caps.tables).to.equal(row[9][1])
				expect(def.caps.espresso).to.equal(row[9][2])
				expect(def.caps.net).to.equal(row[9][3])
			end
			expect(Catalog.getTier(0)).never.to.be.ok()
			expect(Catalog.getTier(6)).never.to.be.ok()
		end)

		it("each tier opens one new area, in the order of section 9", function()
			for tier, def in ipairs(Catalog.tiers) do
				expect(def.area).to.equal(AREA_ORDER[tier])
			end
		end)

		it("every rank up is reachable from the areas the tier below has open", function()
			for tier = 2, #Catalog.tiers do
				local def = Catalog.tiers[tier]
				local open: { [string]: boolean } = {}
				for t = 1, tier - 1 do
					open[Catalog.tiers[t].area] = true
				end
				local catsOpen, rarityOpen = 0, 0
				for _, cat in ipairs(Catalog.cats) do
					if open[cat.area] then
						catsOpen += 1
						if def.needsRarity ~= nil and cat.rarity == def.needsRarity then
							rarityOpen += 1
						end
					end
				end
				expect(def.distinctCats <= catsOpen).to.equal(true)
				if def.needsRarity ~= nil then
					expect(rarityOpen >= (def.needsRarityCount or 1)).to.equal(true)
				end
			end
		end)

		it("costs, requirements, multipliers and caps never go down", function()
			for tier = 2, #Catalog.tiers do
				local lower, higher = Catalog.tiers[tier - 1], Catalog.tiers[tier]
				expect(higher.cost > lower.cost).to.equal(true)
				expect(higher.distinctCats > lower.distinctCats).to.equal(true)
				expect(higher.multiplier > lower.multiplier).to.equal(true)
				for _, id in ipairs({ "tables", "espresso", "net" }) do
					expect((higher.caps :: any)[id] >= (lower.caps :: any)[id]).to.equal(true)
				end
			end
		end)

		it("the top tier's caps are each upgrade's max level, and no cap is above it", function()
			for _, def in ipairs(Catalog.tiers) do
				for id, cap in pairs(def.caps :: any) do
					local upgrade = Catalog.getUpgrade(id)
					assert(upgrade, id)
					expect(cap <= upgrade.maxLevel).to.equal(true)
					expect(cap >= upgrade.startLevel).to.equal(true)
				end
			end
			local top = Catalog.tiers[Catalog.maxTier].caps :: any
			for id, cap in pairs(top) do
				local upgrade = Catalog.getUpgrade(id)
				assert(upgrade)
				expect(cap).to.equal(upgrade.maxLevel)
			end
		end)

		it("tierForLevel gives the lowest tier whose cap allows a level", function()
			local cases: { { any } } = {
				{ "tables", 1, 1 },
				{ "tables", 2, 1 },
				{ "tables", 3, 2 },
				{ "tables", 4, 2 },
				{ "tables", 5, 3 },
				{ "tables", 6, 3 },
				{ "tables", 7, nil },
				{ "espresso", 2, 1 },
				{ "espresso", 3, 2 },
				{ "espresso", 4, 3 },
				{ "espresso", 5, 4 },
				{ "net", 1, 1 },
				{ "net", 2, 2 },
				{ "net", 3, 3 },
				{ "lure_bowl", 1, nil },
				{ "nope", 1, nil },
			}
			for _, case in ipairs(cases) do
				expect(Catalog.tierForLevel(case[1], case[2])).to.equal(case[3])
			end
		end)
	end)

	describe("upgrades (section 6)", function()
		local expected: {
			[string]: {
				name: string,
				maxLevel: number,
				costs: { number },
				startLevel: number,
				atLevel: { [number]: number }?,
			},
		} =
			{
				tables = {
					name = "Tables",
					maxLevel = 6,
					costs = { 100, 250, 600, 1500, 3500, 8000 },
					startLevel = 0,
					atLevel = { [3] = 2, [4] = 2, [5] = 3, [6] = 3 },
				},
				espresso = {
					name = "Espresso machine",
					maxLevel = 5,
					costs = { 0, 300, 1200, 4000, 12000 },
					startLevel = 1,
					atLevel = { [3] = 2, [4] = 3, [5] = 4 },
				},
				net = {
					name = "Net",
					maxLevel = 3,
					costs = { 500, 3000, 15000 },
					startLevel = 0,
					atLevel = { [2] = 2, [3] = 3 },
				},
				lure_bowl = {
					name = "Bait bowl",
					maxLevel = 1,
					costs = { 400 },
					startLevel = 0,
					atLevel = nil,
				},
			}

		it(
			"has exactly the four v0.3 upgrades; cafe_level, park_access and gloves are gone",
			function()
				expect(#Catalog.upgrades).to.equal(4)
				for _, def in ipairs(Catalog.upgrades) do
					expect(expected[def.id]).to.be.ok()
				end
				expect(Catalog.getUpgrade("cafe_level")).never.to.be.ok()
				expect(Catalog.getUpgrade("park_access")).never.to.be.ok()
				expect(Catalog.getUpgrade("gloves")).never.to.be.ok()
				expect(Catalog.renamedUpgrades.gloves).to.equal("net")
			end
		)

		for id, row in pairs(expected) do
			it(id .. " matches the table, tier caps included", function()
				local def = Catalog.getUpgrade(id)
				expect(def).to.be.ok()
				assert(def)
				expect(def.name).to.equal(row.name)
				expect(def.maxLevel).to.equal(row.maxLevel)
				expect(def.costs).to.deepEqual(row.costs)
				expect(def.startLevel).to.equal(row.startLevel)
				-- The Bait bowl opens at Tier 1 (section 5b), so nothing needs a tier for level 1.
				expect(def.requiresTier).never.to.be.ok()
				if row.atLevel == nil then
					expect(def.requiresTierAtLevel).never.to.be.ok()
				else
					expect(def.requiresTierAtLevel :: any).to.deepEqual(row.atLevel)
				end
				expect(#def.costs).to.equal(def.maxLevel)
				local raw = def :: any
				expect(raw.requiresCafeLevel).never.to.be.ok()
				expect(raw.requiresCafeLevelAtLevel).never.to.be.ok()
			end)
		end

		it("costs rise with level and only start levels are free", function()
			for _, def in ipairs(Catalog.upgrades) do
				for level = 2, #def.costs do
					expect(def.costs[level] > def.costs[level - 1]).to.equal(true)
				end
				if def.startLevel >= 1 then
					expect(def.costs[1]).to.equal(0)
				else
					expect(def.costs[1] > 0).to.equal(true)
				end
			end
		end)
	end)

	describe("decor (section 7)", function()
		local expected: { [string]: { cost: number, bonus: number, requiresTier: number, asset: string } } =
			{
				plants = {
					cost = 150,
					bonus = 0.05,
					requiresTier = 2,
					asset = "CatCafe_Decor_WindowPlants",
				},
				rug = { cost = 400, bonus = 0.05, requiresTier = 2, asset = "CatCafe_Decor_Rug" },
				neon_sign = {
					cost = 1500,
					bonus = 0.10,
					requiresTier = 3,
					asset = "CatCafe_Decor_NeonSign",
				},
				fish_tank = {
					cost = 5000,
					bonus = 0.10,
					requiresTier = 4,
					asset = "CatCafe_Decor_FishTank",
				},
			}

		it("has exactly the four shop decor items with their tiers", function()
			local shop = 0
			for _, def in ipairs(Catalog.decor) do
				if def.source == nil or def.source == "shop" then
					shop += 1
				end
			end
			expect(shop).to.equal(4)
			for id, row in pairs(expected) do
				local def = Catalog.getDecor(id)
				expect(def).to.be.ok()
				assert(def)
				expect(def.cost).to.equal(row.cost)
				expect(def.bonus).to.be.near(row.bonus)
				expect(def.requiresTier).to.equal(row.requiresTier)
				expect((def :: any).requiresCafeLevel).never.to.be.ok()
				expect(def.asset).to.equal(row.asset)
				expect(#def.effect > 0).to.equal(true)
			end
		end)

		it("effect text states the bonus percentage", function()
			for _, def in ipairs(Catalog.decor) do
				local percent = math.floor(def.bonus * 100 + 0.5)
				expect(def.effect).to.contain(string.format("+%d%%", percent))
			end
		end)
	end)

	describe("foods (sections 8 and 8b)", function()
		local expected: {
			[string]: {
				cost: number,
				source: string,
				attracts: string,
				name: string,
				odds: { [string]: number },
			},
		} =
			{
				kibble = {
					name = "Kibble",
					cost = 25,
					source = "shop",
					attracts = "Common",
					odds = { Common = 70, Rare = 25, Epic = 4, Legendary = 0.9, Mythical = 0.1 },
				},
				tuna = {
					name = "Tuna",
					cost = 100,
					source = "shop",
					attracts = "Rare",
					odds = { Common = 40, Rare = 45, Epic = 12, Legendary = 2.6, Mythical = 0.4 },
				},
				salmon = {
					name = "Salmon",
					cost = 500,
					source = "shop",
					attracts = "Epic",
					odds = { Common = 15, Rare = 45, Epic = 30, Legendary = 8.5, Mythical = 1.5 },
				},
				sardines = {
					name = "Moonlit Sardines",
					cost = 800,
					source = "dealer",
					attracts = "Rare",
					odds = { Common = 30, Rare = 45, Epic = 20, Legendary = 4.5, Mythical = 0.5 },
				},
				caviar = {
					name = "Caviar",
					cost = 3000,
					source = "dealer",
					attracts = "Epic",
					odds = { Common = 10, Rare = 35, Epic = 38, Legendary = 14, Mythical = 3 },
				},
				moon_milk = {
					name = "Moon Milk",
					cost = 10000,
					source = "dealer",
					attracts = "Epic",
					odds = { Common = 0, Rare = 20, Epic = 45, Legendary = 28, Mythical = 7 },
				},
				star_treat = {
					name = "Star Treat",
					cost = 40000,
					source = "dealer",
					attracts = "Legendary",
					odds = { Common = 0, Rare = 0, Epic = 40, Legendary = 45, Mythical = 15 },
				},
			}

		it("has the three shop foods and four dealer foods with the table odds", function()
			expect(#Catalog.lures).to.equal(7)
			for id, row in pairs(expected) do
				local def = Catalog.getLure(id)
				expect(def).to.be.ok()
				assert(def)
				expect(def.name).to.equal(row.name)
				expect(def.cost).to.equal(row.cost)
				expect(def.source).to.equal(row.source)
				expect(def.attracts).to.equal(row.attracts)
				expect(def.odds :: any).to.deepEqual(row.odds)
				expect(string.sub(def.asset, 1, 13)).to.equal("CatCafe_Item_")
				expect(#def.description > 0).to.equal(true)
			end
		end)

		it("odds cover all five rarities and sum to 100 (paid random items rule)", function()
			for _, def in ipairs(Catalog.lures) do
				assertFiveRarityOdds(def.odds)
			end
		end)

		it("a dealer food attracts its likeliest rarity", function()
			for _, def in ipairs(Catalog.lures) do
				if def.source == "dealer" then
					local best, bestWeight = "", -1
					for _, rarity in ipairs(RARITIES) do
						if (def.odds :: any)[rarity] > bestWeight then
							best, bestWeight = rarity, (def.odds :: any)[rarity]
						end
					end
					expect(def.attracts).to.equal(best)
				end
			end
		end)

		it("a shop food beats the free Alleyway on its rarity or better (section 8)", function()
			local alley = Catalog.getArea("alley")
			assert(alley)
			local function orBetter(odds: any, rarity: string): number
				local total = 0
				for _, r in ipairs(Catalog.rarityOrder) do
					if Catalog.rarityRank[r] >= Catalog.rarityRank[rarity] then
						total += odds[r] or 0
					end
				end
				return total
			end
			-- From the tables: kibble 100 vs 100, tuna 60 vs 28, salmon 40 vs 6.
			local numbers: { [string]: { number } } =
				{ kibble = { 100, 100 }, tuna = { 60, 28 }, salmon = { 40, 6 } }
			for id, row in pairs(numbers) do
				local def = Catalog.getLure(id)
				assert(def)
				local food = orBetter(def.odds, def.attracts)
				local free = orBetter(alley.odds, def.attracts)
				expect(food).to.be.near(row[1], 1e-9)
				expect(free).to.be.near(row[2], 1e-9)
				expect(food >= free).to.equal(true)
			end
		end)

		it(
			"dealer slot weights are the one v0.5 row of section 8b and name only dealer foods (F43)",
			function()
				expect(Catalog.dealerSlotWeights :: any).to.deepEqual({
					sardines = 50,
					caviar = 33,
					moon_milk = 14,
					star_treat = 3,
				})
				local total = 0
				for id, weight in pairs(Catalog.dealerSlotWeights) do
					local def = Catalog.getLure(id)
					assert(def, id)
					expect(def.source).to.equal("dealer")
					total += weight
				end
				expect(total).to.be.near(100, 1e-9)
			end
		)
	end)

	describe("areas (section 9)", function()
		it("alley and park have the v0.3 odds and the tier that opens them", function()
			local alley = Catalog.getArea("alley")
			local park = Catalog.getArea("park")
			assert(alley and park)
			expect(alley.tier).to.equal(1)
			expect(alley.name).to.equal("Alleyway")
			expect(alley.odds :: any).to.deepEqual({
				Common = 72,
				Rare = 22,
				Epic = 5,
				Legendary = 0.9,
				Mythical = 0.1,
			})
			expect(park.tier).to.equal(2)
			expect(park.name).to.equal("Park")
			expect(park.odds :: any).to.deepEqual({
				Common = 60,
				Rare = 28,
				Epic = 9,
				Legendary = 2.5,
				Mythical = 0.5,
			})
			expect((park :: any).unlock).never.to.be.ok()
		end)

		it("each area's tier opens it in the tier table", function()
			for _, area in ipairs(Catalog.areas) do
				local tierDef = Catalog.getTier(area.tier)
				assert(tierDef, area.id)
				expect(tierDef.area).to.equal(area.id)
			end
		end)

		it("v0.2: areas spawn in night waves, the trickle fields are gone", function()
			for _, def in ipairs(Catalog.areas) do
				local raw = def :: any
				expect(raw.maxStrays).never.to.be.ok()
				expect(raw.spawnInterval).never.to.be.ok()
				expect(raw.despawnAfter).never.to.be.ok()
			end
		end)

		it("a full wave fits on the spawn points and every area has a rescue trap", function()
			for _, def in ipairs(Catalog.areas) do
				expect(def.waveSize >= 1).to.equal(true)
				expect(def.waveSize <= def.spawnPoints).to.equal(true)
				expect(def.rescueSpots >= 1).to.equal(true)
			end
		end)

		it("area odds cover all five rarities and sum to 100", function()
			for _, def in ipairs(Catalog.areas) do
				assertFiveRarityOdds(def.odds)
			end
		end)

		it("every area has a cat of every rarity it lists odds for", function()
			for _, area in ipairs(Catalog.areas) do
				for rarity, weight in pairs(area.odds :: any) do
					if (weight :: number) > 0 then
						local found = false
						for _, def in ipairs(Catalog.cats) do
							found = found or (def.rarity == rarity and def.area == area.id)
						end
						expect(found).to.equal(true)
					end
				end
			end
		end)

		it(
			"five areas in tier order with the section 9 spawn points, waves of 10 and odds (F23)",
			function()
				-- id -> { name, tier, spawnPoints, odds }
				local want = {
					{ "alley", "Alleyway", 1, 24, { 72, 22, 5, 0.9, 0.1 } }, -- v0.4 layout: 24 spawn points
					{ "park", "Park", 2, 14, { 60, 28, 9, 2.5, 0.5 } },
					{ "neighbourhood", "Neighbourhood", 3, 14, { 50, 32, 13, 4, 1 } },
					{ "woods", "Woods", 4, 16, { 42, 34, 17, 5.5, 1.5 } },
					{ "sewer", "Sewer", 5, 16, { 35, 35, 20, 7.5, 2.5 } },
				}
				expect(#Catalog.areas).to.equal(#want)
				for i, row in want do
					local def = Catalog.areas[i]
					expect(def.id).to.equal(row[1])
					expect(def.name).to.equal(row[2])
					expect(def.tier).to.equal(row[3])
					expect(def.spawnPoints).to.equal(row[4])
					expect(def.waveSize).to.equal(10)
					local odds = row[5] :: { number }
					expect(def.odds :: any).to.deepEqual({
						Common = odds[1],
						Rare = odds[2],
						Epic = odds[3],
						Legendary = odds[4],
						Mythical = odds[5],
					})
				end
			end
		)

		it("the trap lists per area (F27)")
	end)

	describe("player-facing words (QA)", function()
		-- Derek 2026-10-27 13:18: players see Gold, never Shiny. Any string the Catalog holds can reach a card, a
		-- toast or the book, so none may say shiny. Asset names (CatCafe_...) are never shown and are left out.
		it("no name, description or label in the Catalog says shiny", function()
			local found: { string } = {}
			local seen: { [any]: boolean } = {}
			local function walk(value: any, path: string)
				if type(value) == "string" then
					local text = value :: string
					local said = string.find(string.lower(text), "shiny", 1, true) ~= nil
					if said and string.sub(text, 1, 8) ~= "CatCafe_" then
						table.insert(found, path .. " = " .. text)
					end
				elseif type(value) == "table" and not seen[value] then
					seen[value] = true
					for key, child in value do
						walk(key, path .. " (key)")
						walk(child, path .. "." .. tostring(key))
					end
				end
			end
			walk(Catalog, "Catalog")
			expect(found).to.deepEqual({})
			expect((Catalog :: any).shinyModelName).never.to.be.ok()
		end)
	end)
end
