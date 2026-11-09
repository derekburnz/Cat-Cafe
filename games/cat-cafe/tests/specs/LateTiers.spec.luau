--!strict
-- LateTiers.luau against docs/design/cat-cafe/tier6-7-areas.md sections 1, 2 and 6 (#2580, #2651).
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local LateTiers = require(Shared.LateTiers)

	local ROLES = { "barista", "waiter", "greeter", "entertainer" }
	local PER_AREA: { [string]: number } =
		{ Common = 4, Rare = 2, Epic = 2, Legendary = 1, Mythical = 1 }
	local PATTERNS: { [string]: boolean } = {}
	for _, def in Catalog.cats do
		PATTERNS[def.pattern] = true
	end

	describe("the areas", function()
		it("comes after the Sewer, one per tier, each paying three times the one before", function()
			local last = Catalog.areas[#Catalog.areas]
			expect(#LateTiers.areas).to.equal(2)
			for i, area in LateTiers.areas do
				expect(area.id).to.equal(LateTiers.AREAS[i])
				expect(area.tier).to.equal(last.tier + i)
				expect(Catalog.areasById[area.id]).to.equal(nil)
				expect(area.incomeMultiplier).to.equal(last.incomeMultiplier * 3 ^ i)
				expect(area.incomeMultiplier).to.equal(LateTiers.AREA_INCOME[area.id])
			end
		end)

		it("uses every area's odds and the current wave", function()
			local odds = Catalog.areas[1].odds
			for _, area in LateTiers.areas do
				local sum = 0
				for rarity, weight in (area.odds :: any) :: { [string]: number } do
					expect(weight).to.equal((odds :: any)[rarity])
					sum += weight
				end
				expect(math.abs(sum - 100) < 1e-9).to.equal(true)
				expect(area.waveSize).to.equal(Catalog.areas[#Catalog.areas].waveSize)
				expect(area.rescueSpots).to.equal(5)
				expect(area.spawnPoints >= area.waveSize * 5).to.equal(true)
			end
		end)

		it(
			"sits on the free diagonals about 2000 studs out, long axis along Z (section 2)",
			function()
				local desert, ruins = LateTiers.areas[1], LateTiers.areas[2]
				expect(desert.centre.x > 0 and desert.centre.z < 0).to.equal(true) -- south-east
				expect(ruins.centre.x > 0 and ruins.centre.z > 0).to.equal(true) -- north-east
				for _, area in LateTiers.areas do
					local out = math.sqrt(area.centre.x ^ 2 + area.centre.z ^ 2)
					expect(out > 1900 and out < 2100).to.equal(true)
					expect(area.size.depth > area.size.width).to.equal(true)
				end
			end
		)

		it("leans the pity cat toward the high areas", function()
			expect(LateTiers.areas[2].pityWeight > LateTiers.areas[1].pityWeight).to.equal(true)
		end)
	end)

	describe("the tiers", function()
		it("continue Catalog.tiers: dearer, more cats, more slots, a higher multiplier", function()
			local before = Catalog.tiers[Catalog.maxTier]
			for i, tier in LateTiers.tiers do
				expect(tier.tier).to.equal(Catalog.maxTier + i)
				expect(tier.area).to.equal(LateTiers.areas[i].id)
				expect(tier.cost > before.cost * 10).to.equal(true)
				expect(tier.distinctCats > before.distinctCats).to.equal(true)
				expect(tier.slots).to.equal(before.slots + 2)
				expect(tier.multiplier).to.equal(before.multiplier + 0.25)
				expect(tier.needsRarity).to.equal("Mythical")
				for key, cap in (tier.caps :: any) :: { [string]: number } do
					expect(cap >= (before.caps :: any)[key]).to.equal(true)
				end
				before = tier :: any
			end
			expect(LateTiers.tiers[1].name).to.equal("Sunstone Cafe")
			expect(LateTiers.tiers[2].name).to.equal("Wonder Cafe")
		end)

		it("asks for no more different cats than a player of the tier before can reach", function()
			local reachable = 0
			for _, def in Catalog.cats do
				if Catalog.areasById[def.area] then
					reachable += 1
				end
			end
			for i, tier in LateTiers.tiers do
				-- at rank up you have the areas below this tier's: Catalog's plus the late ones before it
				local can = reachable + 10 * (i - 1)
				expect(tier.distinctCats <= can).to.equal(true)
				expect(tier.distinctCats >= math.floor(can * 0.6)).to.equal(true)
			end
		end)
	end)

	describe("the 20 cats", function()
		it(
			"puts ten in each area: four Common, one per role, two Rare, two Epic, a Legendary and a Mythical",
			function()
				expect(#LateTiers.cats).to.equal(20)
				for _, area in LateTiers.areas do
					local counts: { [string]: number } = {}
					local commonRoles: { [string]: boolean } = {}
					for _, def in LateTiers.cats do
						if def.area == area.id then
							counts[def.rarity] = (counts[def.rarity] or 0) + 1
							if def.rarity == "Common" then
								commonRoles[def.favoriteRole] = true
							end
						end
					end
					for rarity, want in PER_AREA do
						expect(counts[rarity]).to.equal(want)
					end
					for _, role in ROLES do
						expect(commonRoles[role]).to.equal(true)
					end
				end
			end
		)

		it("has new ids and model names that clash with no cat already in the game", function()
			local seen: { [string]: boolean } = {}
			for _, def in LateTiers.cats do
				expect(seen[def.id]).to.equal(nil)
				seen[def.id] = true
				expect(Catalog.catsById[def.id]).to.equal(nil)
				expect(Catalog.catsByModelName[Catalog.catModelName(def.id)]).to.equal(nil)
				expect(LateTiers.catsById[def.id]).to.equal(def)
			end
			-- the Mythical Sphinx is not the DJ Cat (`sphynx`, the breed)
			expect(Catalog.catModelName("sphinx")).to.equal("CatCafe_Cat_Sphinx")
			expect(Catalog.catModelName("jade_guardian")).to.equal("CatCafe_Cat_JadeGuardian")
			expect(Catalog.catModelName("glyph")).to.equal("CatCafe_Cat_Glyph")
		end)

		it("earns its rarity's income times its area's", function()
			for _, def in LateTiers.cats do
				local want = Catalog.rarities[def.rarity].incomePerSecond
					* LateTiers.AREA_INCOME[def.area]
				expect(def.incomePerSecond).to.equal(want)
			end
		end)

		it("uses known roles and patterns, a colour and a blurb", function()
			local roles: { [string]: boolean } = {}
			for _, role in ROLES do
				roles[role] = true
			end
			for _, def in LateTiers.cats do
				expect(roles[def.favoriteRole]).to.equal(true)
				expect(PATTERNS[def.pattern]).to.equal(true)
				expect(#def.color).to.equal(3)
				for _, channel in def.color do
					expect(channel >= 0 and channel <= 255).to.equal(true)
				end
				expect(#def.description > 0 and #def.description <= 60).to.equal(true)
			end
		end)

		it(
			"keeps Derek2's picks: the Golem is the Legendary, the Jade Guardian the Mythical",
			function()
				expect(LateTiers.catsById.golem.rarity).to.equal("Legendary")
				expect(LateTiers.catsById.jade_guardian.rarity).to.equal("Mythical")
				expect(LateTiers.catsById.sphinx.rarity).to.equal("Mythical")
			end
		)
	end)
end
