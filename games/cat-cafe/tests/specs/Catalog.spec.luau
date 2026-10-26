--!strict
-- Catalog.luau against docs/design/cat-cafe/data-model.md sections 2, 3, 5, 6, 7, 8, 9.
-- If the designer changes a number in the doc, change it here in the same commit.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)

	local SPOT_TYPES: { [string]: boolean } = { counter = true, window = true, cushion = true, shelf = true, cattree = true, patio = true }
	local AREAS = { alley = true, park = true, both = true }
	local RARITIES = { "Common", "Rare", "Epic", "Legendary", "Secret" }

	local function ids(list: { any }): { string }
		local out = {}
		for _, def in ipairs(list) do
			table.insert(out, def.id)
		end
		return out
	end

	local function assertUniqueSnakeCaseIds(list: { any })
		local seen = {}
		for _, def in ipairs(list) do
			expect(def.id).to.be.a("string")
			expect(string.match(def.id, "^[a-z][a-z0-9_]*$") ~= nil).to.equal(true)
			expect(seen[def.id]).never.to.be.ok()
			seen[def.id] = true
		end
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

		it("rarity order and rank agree", function()
			expect(Catalog.rarityOrder).to.deepEqual(RARITIES)
			for rank, rarity in ipairs(RARITIES) do
				expect(Catalog.rarityRank[rarity]).to.equal(rank)
			end
		end)

		it("model names derive from ids", function()
			expect(Catalog.catModelName("tabby")).to.equal("CatCafe_Cat_Tabby")
			expect(Catalog.catModelName("void")).to.equal("CatCafe_Cat_Void")
		end)
	end)

	describe("rarities (section 2)", function()
		local expected = {
			Common = { incomePerSecond = 1, baseCatchChance = 0.90, fleesOnMiss = false, sellValue = 25, firstCatchReward = 50, color = "#8E97B2" },
			Rare = { incomePerSecond = 3, baseCatchChance = 0.65, fleesOnMiss = true, sellValue = 150, firstCatchReward = 300, color = "#5FA8FF" },
			Epic = { incomePerSecond = 8, baseCatchChance = 0.45, fleesOnMiss = true, sellValue = 600, firstCatchReward = 1500, color = "#C07CFF" },
			Legendary = { incomePerSecond = 25, baseCatchChance = 0.25, fleesOnMiss = true, sellValue = 3000, firstCatchReward = 8000, color = "#FFC94D" },
			Secret = { incomePerSecond = 60, baseCatchChance = 0.20, fleesOnMiss = true, sellValue = 10000, firstCatchReward = 25000, color = "#3FD0B5" },
		}
		for _, rarity in ipairs(RARITIES) do
			it(rarity .. " matches the table", function()
				expect(Catalog.rarities[rarity]).to.deepEqual(expected[rarity])
			end)
		end

		it("colors are 6 digit hex", function()
			for _, def in pairs(Catalog.rarities) do
				expect(string.match(def.color, "^#%x%x%x%x%x%x$") ~= nil).to.equal(true)
			end
		end)
	end)

	describe("cats (section 3)", function()
		local expected: { [string]: { string } } = {
			tabby = { "Common", "both", "counter" },
			tuxedo = { "Common", "both", "window" },
			ginger = { "Common", "both", "cushion" },
			smoke = { "Common", "both", "shelf" },
			snow = { "Common", "both", "window" },
			calico = { "Rare", "both", "cushion" },
			siamese = { "Rare", "both", "counter" },
			tortie = { "Rare", "park", "shelf" },
			bengal = { "Rare", "park", "cattree" },
			sphynx = { "Epic", "both", "cushion" },
			ragdoll = { "Epic", "park", "cattree" },
			void = { "Legendary", "both", "shelf" },
		}

		it("has exactly the 12 slice cats", function()
			expect(#Catalog.cats).to.equal(12)
			for _, def in ipairs(Catalog.cats) do
				expect(expected[def.id]).to.be.ok()
			end
			for id in pairs(expected) do
				expect(Catalog.getCat(id)).to.be.ok()
			end
		end)

		it("no Secret cats in the slice", function()
			for _, def in ipairs(Catalog.cats) do
				expect(def.rarity).never.to.equal("Secret")
			end
		end)

		for id, row in pairs(expected) do
			it(id .. " has the rarity, area and favorite spot from the table", function()
				local def = Catalog.getCat(id)
				expect(def).to.be.ok()
				assert(def)
				expect(def.rarity).to.equal(row[1])
				expect(def.area).to.equal(row[2])
				expect(def.favoriteSpot).to.equal(row[3])
				expect(def.incomePerSecond).to.equal(Catalog.rarities[def.rarity].incomePerSecond)
			end)
		end

		it("every cat has display fields and a valid placeholder color", function()
			for _, def in ipairs(Catalog.cats) do
				expect(#def.name > 0).to.equal(true)
				expect(#def.description > 0).to.equal(true)
				expect(#def.pattern > 0).to.equal(true)
				expect(SPOT_TYPES[def.favoriteSpot]).to.equal(true)
				expect(AREAS[def.area]).to.equal(true)
				expect(#def.color).to.equal(3)
				for _, channel in ipairs(def.color) do
					expect(channel >= 0 and channel <= 255 and channel == math.floor(channel)).to.equal(true)
				end
			end
		end)

		it("getCat returns nil for unknown ids", function()
			expect(Catalog.getCat("golden")).never.to.be.ok()
			expect(Catalog.getCat("")).never.to.be.ok()
		end)
	end)

	describe("spots (section 5)", function()
		it("opens the listed spots at the listed cafe levels", function()
			local expected: { [string]: { any } } = {
				counter_1 = { "counter", 1 },
				window_1 = { "window", 1 },
				cushion_1 = { "cushion", 2 },
				shelf_1 = { "shelf", 3 },
				cattree_1 = { "cattree", 4 },
				patio_1 = { "patio", 5 },
				patio_2 = { "patio", 5 },
			}
			expect(#Catalog.spots).to.equal(7)
			for id, row in pairs(expected) do
				local spot = Catalog.getSpot(id)
				expect(spot).to.be.ok()
				assert(spot)
				expect(spot.spotType).to.equal(row[1])
				expect(spot.cafeLevel).to.equal(row[2])
				expect(string.match(id, "^" .. row[1] .. "_%d+$") ~= nil).to.equal(true)
			end
		end)

		it("every spot type has furniture and every favorite spot exists", function()
			for spotType in pairs(SPOT_TYPES) do
				local furniture: string = Catalog.spotFurniture[spotType]
				expect(furniture).to.be.a("string")
				expect(string.sub(furniture, 1, 18)).to.equal("CatCafe_Furniture_")
			end
			for _, def in ipairs(Catalog.cats) do
				local found = false
				for _, spot in ipairs(Catalog.spots) do
					if spot.spotType == def.favoriteSpot then
						found = true
					end
				end
				expect(found).to.equal(true)
			end
		end)
	end)

	describe("upgrades (section 6)", function()
		local expected: { [string]: { maxLevel: number, costs: { number }, startLevel: number, requiresCafeLevel: number? } } = {
			cafe_level = { maxLevel = 5, costs = { 0, 250, 800, 2500, 8000 }, startLevel = 1, requiresCafeLevel = nil },
			tables = { maxLevel = 6, costs = { 100, 250, 600, 1500, 3500, 8000 }, startLevel = 0, requiresCafeLevel = nil },
			espresso = { maxLevel = 3, costs = { 0, 300, 1200, 4000, 12000 }, startLevel = 1, requiresCafeLevel = nil },
			gloves = { maxLevel = 3, costs = { 500, 2500, 10000 }, startLevel = 0, requiresCafeLevel = nil },
			lure_bowl = { maxLevel = 1, costs = { 400 }, startLevel = 0, requiresCafeLevel = 2 },
			park_access = { maxLevel = 1, costs = { 1000 }, startLevel = 0, requiresCafeLevel = 3 },
		}

		it("has exactly the six slice upgrades", function()
			expect(#Catalog.upgrades).to.equal(6)
			for _, def in ipairs(Catalog.upgrades) do
				expect(expected[def.id]).to.be.ok()
			end
		end)

		for id, row in pairs(expected) do
			it(id .. " matches the table", function()
				local def = Catalog.getUpgrade(id)
				expect(def).to.be.ok()
				assert(def)
				expect(def.maxLevel).to.equal(row.maxLevel)
				expect(def.costs).to.deepEqual(row.costs)
				expect(def.startLevel).to.equal(row.startLevel)
				expect(def.requiresCafeLevel).to.equal(row.requiresCafeLevel)
				expect(#def.costs >= def.maxLevel).to.equal(true)
			end)
		end

		it("espresso level 3 needs cafe level 3", function()
			local def = Catalog.getUpgrade("espresso")
			assert(def)
			expect(def.requiresCafeLevelAtLevel).to.be.ok()
			assert(def.requiresCafeLevelAtLevel)
			expect(def.requiresCafeLevelAtLevel[3]).to.equal(3)
		end)

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
		local expected: { [string]: { cost: number, bonus: number, requiresCafeLevel: number?, asset: string } } = {
			plants = { cost = 150, bonus = 0.05, requiresCafeLevel = nil, asset = "CatCafe_Decor_WindowPlants" },
			rug = { cost = 400, bonus = 0.05, requiresCafeLevel = nil, asset = "CatCafe_Decor_Rug" },
			neon_sign = { cost = 1500, bonus = 0.10, requiresCafeLevel = 4, asset = "CatCafe_Decor_NeonSign" },
			fish_tank = { cost = 5000, bonus = 0.10, requiresCafeLevel = 4, asset = "CatCafe_Decor_FishTank" },
		}

		it("has exactly the four slice decor items", function()
			expect(#Catalog.decor).to.equal(4)
			for id, row in pairs(expected) do
				local def = Catalog.getDecor(id)
				expect(def).to.be.ok()
				assert(def)
				expect(def.cost).to.equal(row.cost)
				expect(def.bonus).to.be.near(row.bonus)
				expect(def.requiresCafeLevel).to.equal(row.requiresCafeLevel)
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

	describe("lures (section 8)", function()
		local expected: { [string]: { cost: number, attracts: string, odds: { [string]: number } } } = {
			kibble = { cost = 25, attracts = "Common", odds = { Common = 70, Rare = 26, Epic = 3.5, Legendary = 0.5 } },
			tuna = { cost = 100, attracts = "Rare", odds = { Common = 45, Rare = 42, Epic = 11, Legendary = 2 } },
			salmon = { cost = 500, attracts = "Epic", odds = { Common = 15, Rare = 50, Epic = 28, Legendary = 7 } },
		}

		it("has exactly the three slice lures with the table odds", function()
			expect(#Catalog.lures).to.equal(3)
			for id, row in pairs(expected) do
				local def = Catalog.getLure(id)
				expect(def).to.be.ok()
				assert(def)
				expect(def.cost).to.equal(row.cost)
				expect(def.attracts).to.equal(row.attracts)
				expect(def.odds :: any).to.deepEqual(row.odds)
			end
		end)

		it("odds are percentages that sum to 100 (paid random items rule)", function()
			for _, def in ipairs(Catalog.lures) do
				local total = def.odds.Common + def.odds.Rare + def.odds.Epic + def.odds.Legendary
				expect(total).to.be.near(100, 1e-9)
				for _, value in pairs(def.odds :: any) do
					expect((value :: number) >= 0).to.equal(true)
				end
			end
		end)

		it("attracts means: odds of that rarity or better are at least the free alley's (section 8)", function()
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
			-- Numbers from the doc: kibble 100 vs 100, tuna 55 vs 25, salmon 35 vs 5.
			local expected: { [string]: { number } } = { kibble = { 100, 100 }, tuna = { 55, 25 }, salmon = { 35, 5 } }
			for _, def in ipairs(Catalog.lures) do
				expect(Catalog.rarityRank[def.attracts]).to.be.ok()
				local lure = orBetter(def.odds, def.attracts)
				local free = orBetter(alley.odds, def.attracts)
				expect(lure >= free).to.equal(true)
				local row = expected[def.id]
				if row ~= nil then
					expect(lure).to.be.near(row[1], 1e-9)
					expect(free).to.be.near(row[2], 1e-9)
				end
			end
		end)
	end)

	describe("areas (section 9)", function()
		it("alley and park match the table", function()
			expect(#Catalog.areas).to.equal(2)
			local alley = Catalog.getArea("alley")
			local park = Catalog.getArea("park")
			assert(alley and park)
			expect(alley.unlock).never.to.be.ok()
			expect(alley.spawnPoints).to.equal(8)
			expect(alley.maxStrays).to.equal(6)
			expect(alley.spawnInterval).to.equal(20)
			expect(alley.despawnAfter).to.equal(120)
			expect(alley.odds).to.deepEqual({ Common = 75, Rare = 20, Epic = 4.5, Legendary = 0.5 })
			expect(park.unlock).to.equal("park_access")
			expect(park.spawnPoints).to.equal(10)
			expect(park.maxStrays).to.equal(6)
			expect(park.spawnInterval).to.equal(20)
			expect(park.despawnAfter).to.equal(120)
			expect(park.odds).to.deepEqual({ Common = 55, Rare = 32, Epic = 10, Legendary = 3 })
		end)

		it("area odds sum to 100 and unlock ids exist", function()
			for _, def in ipairs(Catalog.areas) do
				local total = def.odds.Common + def.odds.Rare + def.odds.Epic + def.odds.Legendary
				expect(total).to.be.near(100, 1e-9)
				if def.unlock ~= nil then
					expect(Catalog.getUpgrade(def.unlock)).to.be.ok()
				end
			end
		end)

		it("lure spots: 2 in the alley, 3 in the park", function()
			expect(Catalog.lureSpotsPerArea.alley).to.equal(2)
			expect(Catalog.lureSpotsPerArea.park).to.equal(3)
		end)

		it("every area can spawn something of every non-Secret rarity it lists odds for", function()
			for _, area in ipairs(Catalog.areas) do
				for rarity, weight in pairs(area.odds :: any) do
					if (weight :: number) > 0 then
						local found = false
						for _, def in ipairs(Catalog.cats) do
							if def.rarity == rarity and (def.area == "both" or def.area == area.id) then
								found = true
							end
						end
						expect(found).to.equal(true)
					end
				end
			end
		end)
	end)
end
