--!strict
-- shared/Crates.luau and the 60 crate pieces (F53, golden-fish.md sections 3, 4 and 8): the rolls, the lucky
-- twentieth, refunds, decor spots, style slots, Decor Index pages, what opens and what the Market sells, and the
-- income they add.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)
	local Crates = require(Shared.Crates)
	local Economy = require(Shared.Economy)
	local ProfileSchema = require(Shared.ProfileSchema)

	local POOLS = { "alley", "park", "neighbourhood", "woods", "sewer", "classic" }
	local KINDS = { "wallpaper", "floor", "paint", "furniture", "decoration" }
	local PER_RARITY: { [string]: number } = { Common = 4, Rare = 3, Epic = 1, Legendary = 1, Mythical = 1 }

	local function fresh(): any
		return ProfileSchema.template(1000)
	end

	-- The first piece of `pool` with this rarity and, when given, kind.
	local function pieceOf(pool: string, rarity: string, kind: string?): any
		for _, def in Catalog.crateDecor do
			if def.crate == pool and def.rarity == rarity and (kind == nil or def.kind == kind) then
				return def
			end
		end
		error(string.format("no %s %s piece in %s", rarity, tostring(kind), pool))
	end

	local function own(profile: any, def: any, placed: boolean)
		profile.decorOwned[def.id] = true
		if placed then
			profile.decorPlaced[def.id] = true
		end
	end

	describe("the 60 pieces (section 4)", function()
		it("gives each pool ten pieces: two of each kind, rarities 4, 3, 1, 1 and 1", function()
			expect(#Catalog.crateDecor).to.equal(60)
			for _, pool in POOLS do
				local kinds: { [string]: number } = {}
				local rarities: { [string]: number } = {}
				for _, def in Catalog.crateDecor do
					if def.crate == pool then
						kinds[def.kind :: string] = (kinds[def.kind :: string] or 0) + 1
						rarities[def.rarity :: string] = (rarities[def.rarity :: string] or 0) + 1
					end
				end
				for _, kind in KINDS do
					expect(kinds[kind]).to.equal(2)
				end
				for rarity, n in PER_RARITY do
					expect(rarities[rarity]).to.equal(n)
				end
			end
		end)

		it("prices nothing, boosts tips by rarity and is found by Catalog.getDecor", function()
			local seen: { [string]: boolean } = {}
			for _, def in Catalog.crateDecor do
				expect(seen[def.id]).never.to.be.ok()
				seen[def.id] = true
				expect(def.cost).to.equal(0)
				expect(def.bonus).to.be.near(Config.CratePieceBonus[def.rarity :: string], 1e-9)
				expect(Catalog.getDecor(def.id)).to.equal(def)
				expect(def.name ~= "" and def.effect ~= "").to.equal(true)
				if Crates.isStyle(def.kind) then
					expect(def.color).to.be.ok()
					expect(def.material).to.be.ok()
					expect(string.sub(def.asset, 1, 14)).to.equal("CatCafe_Style_")
				else
					expect(string.sub(def.asset, 1, 14)).to.equal("CatCafe_Decor_")
				end
			end
		end)

		it("keeps the F48 Index pieces as their zone's Epic, the rest sourced from crates only", function()
			for _, def in Catalog.crateDecor do
				if def.source == "index" then
					expect(def.id).to.equal("index_" .. (def.crate :: string))
					expect(def.rarity).to.equal("Epic")
				else
					expect(def.source).to.equal("crate")
				end
			end
			for _, pool in { "alley", "park", "neighbourhood", "woods", "sewer" } do
				expect(pieceOf(pool, "Epic").id).to.equal("index_" .. pool)
			end
		end)

		it("leaves crate-only pieces out of the Decor shop list", function()
			for _, def in Catalog.decor do
				expect(def.source ~= "crate").to.equal(true)
			end
		end)

		it("gives a crate and its golden crate the same pieces", function()
			for _, pool in POOLS do
				local crate = Catalog.getCrate(pool .. "_crate")
				local golden = Catalog.getCrate(pool .. "_golden_crate")
				assert(crate and golden)
				expect(#crate.pieces).to.equal(10)
				expect(golden.pieces).to.equal(crate.pieces)
				for _, decorId in crate.pieces do
					expect((Catalog.getDecor(decorId) :: any).crate).to.equal(pool)
				end
			end
		end)
	end)

	describe("odds and rolls", function()
		local alley = Catalog.getCrate("alley_crate") :: any
		local golden = Catalog.getCrate("alley_golden_crate") :: any

		it("shows each piece's chance: its rarity's odds split among that rarity's pieces", function()
			local each: { [string]: number } = { Common = 15, Rare = 9, Epic = 10, Legendary = 2.5, Mythical = 0.5 }
			local total = 0
			for decorId, chance in Crates.pieceChances(alley, alley.odds) do
				total += chance
				expect(chance).to.be.near(each[(Catalog.getDecor(decorId) :: any).rarity], 1e-9)
			end
			expect(total).to.be.near(100, 1e-9)
			local goldenTotal = 0
			for _, chance in Crates.pieceChances(golden, golden.odds) do
				goldenTotal += chance
			end
			expect(goldenTotal).to.be.near(100, 1e-9)
		end)

		it("rolls the rarity by the odds, rarest last", function()
			local function rarityAt(roll: number, luck: number?): string
				local decorId = Crates.roll(alley, luck or 0, roll, 0)
				return (Catalog.getDecor(decorId) :: any).rarity
			end
			expect(rarityAt(0)).to.equal("Common")
			expect(rarityAt(0.5999)).to.equal("Common")
			expect(rarityAt(0.6)).to.equal("Rare")
			expect(rarityAt(0.8699)).to.equal("Rare")
			expect(rarityAt(0.87)).to.equal("Epic")
			expect(rarityAt(0.97)).to.equal("Legendary")
			expect(rarityAt(0.995)).to.equal("Mythical")
			expect(rarityAt(1)).to.equal("Mythical")
		end)

		it("picks each piece of the rarity equally", function()
			local picked: { [string]: boolean } = {}
			for i = 0, 3 do
				picked[(Crates.roll(alley, 0, 0, (i + 0.5) / 4))] = true
			end
			local n = 0
			for decorId in picked do
				n += 1
				expect((Catalog.getDecor(decorId) :: any).rarity).to.equal("Common")
			end
			expect(n).to.equal(4)
		end)

		it("opens a golden crate on Epic or better only", function()
			local decorId, lucky = Crates.roll(golden, 0, 0, 0)
			expect((Catalog.getDecor(decorId) :: any).rarity).to.equal("Epic")
			expect(lucky).to.equal(false)
			expect((Catalog.getDecor((Crates.roll(golden, 0, 0.8, 0))) :: any).rarity).to.equal("Legendary")
			expect((Catalog.getDecor((Crates.roll(golden, 0, 0.975, 0))) :: any).rarity).to.equal("Mythical")
		end)

		it("opens the twentieth crate on golden odds after 19 without Epic or better", function()
			expect(Crates.isLucky(alley, 18)).to.equal(false)
			expect(Crates.isLucky(alley, 19)).to.equal(true)
			expect(Crates.isLucky(golden, 19)).to.equal(false)
			local decorId, lucky = Crates.roll(alley, 19, 0, 0)
			expect(lucky).to.equal(true)
			expect((Catalog.getDecor(decorId) :: any).rarity).to.equal("Epic")
			expect(Crates.oddsFor(alley, 19)).to.equal(golden.odds)
			expect(Crates.oddsFor(alley, 18)).to.equal(alley.odds)
		end)

		it("counts opens since the last Epic or better, capped at 19", function()
			expect(Crates.luckAfter(0, "Common")).to.equal(1)
			expect(Crates.luckAfter(7, "Rare")).to.equal(8)
			expect(Crates.luckAfter(18, "Common")).to.equal(19)
			expect(Crates.luckAfter(19, "Common")).to.equal(19)
			expect(Crates.luckAfter(12, "Epic")).to.equal(0)
			expect(Crates.luckAfter(19, "Mythical")).to.equal(0)
		end)

		it("refunds a duplicate by its rarity", function()
			expect(Crates.refund("Common")).to.equal(10)
			expect(Crates.refund("Rare")).to.equal(20)
			expect(Crates.refund("Epic")).to.equal(40)
			expect(Crates.refund("Legendary")).to.equal(80)
			expect(Crates.refund("Mythical")).to.equal(150)
		end)
	end)

	describe("decor spots and style slots", function()
		it("has 2 spots at Tier 1 up to 6 at Tier 5, plus one per Extra Decor Spot level", function()
			expect(Crates.spotCap(1, 0)).to.equal(2)
			expect(Crates.spotCap(3, 0)).to.equal(4)
			expect(Crates.spotCap(5, 0)).to.equal(6)
			expect(Crates.spotCap(5, 2)).to.equal(8)
			expect(Crates.spotCap(0, 1)).to.equal(3)
		end)

		it("counts owned and placed furniture and decorations, never styles", function()
			local profile = fresh()
			own(profile, pieceOf("alley", "Common", "furniture"), true)
			own(profile, pieceOf("park", "Rare", "furniture"), true)
			own(profile, pieceOf("alley", "Common", "wallpaper"), true)
			own(profile, pieceOf("woods", "Common", "furniture"), false)
			profile.decorPlaced[pieceOf("sewer", "Common", "furniture").id] = true -- placed but not owned
			expect(Crates.spotsUsed(profile, {})).to.equal(2)
			expect(Crates.spotsUsed(profile, { [pieceOf("alley", "Common", "furniture").id] = true })).to.equal(1)
		end)

		it("finds the wallpaper, floor or paint in use", function()
			local profile = fresh()
			local paper = pieceOf("park", "Common", "wallpaper")
			expect(Crates.styleInUse(profile, "wallpaper")).never.to.be.ok()
			own(profile, paper, true)
			own(profile, pieceOf("park", "Common", "floor"), false)
			expect(Crates.styleInUse(profile, "wallpaper")).to.equal(paper.id)
			expect(Crates.styleInUse(profile, "floor")).never.to.be.ok()
			expect(Crates.takesSpot(paper)).to.equal(false)
			expect(Crates.takesSpot(pieceOf("park", "Rare", "furniture"))).to.equal(true)
		end)
	end)

	describe("style looks (the client's StyleController)", function()
		it("maps each style slot to its plot attribute and tag", function()
			local byKind: { [string]: string } = {}
			for _, slot in Crates.STYLE_SLOTS do
				byKind[slot.kind] = slot.attribute
			end
			expect(byKind :: any).to.deepEqual({ wallpaper = "Wallpaper", floor = "Floor", paint = "Paint" })
		end)

		it("gives a style piece's colour and material only for its own kind", function()
			local paint = pieceOf("neighbourhood", "Common", "paint")
			local color, material = Crates.styleLook(paint.id, "paint")
			expect(color).to.equal(paint.color)
			expect(material).to.equal(paint.material)
			expect((Crates.styleLook(paint.id, "wallpaper"))).never.to.be.ok()
			expect((Crates.styleLook(nil, "paint"))).never.to.be.ok()
			expect((Crates.styleLook("nope", "paint"))).never.to.be.ok()
			expect((Crates.styleLook(pieceOf("alley", "Common", "furniture").id, "floor"))).never.to.be.ok()
		end)
	end)

	describe("Decor Index pages", function()
		it("counts a pool's pieces owned and the pages with all ten", function()
			local profile = fresh()
			for _, def in Catalog.crateDecor do
				if def.crate == "woods" then
					own(profile, def, false)
				end
			end
			own(profile, pieceOf("park", "Common"), false)
			expect(Crates.pageCount(profile, "woods")).to.equal(10)
			expect(Crates.pageCount(profile, "park")).to.equal(1)
			expect(Crates.fullPages(profile)).to.equal(1)
		end)
	end)

	describe("what opens (OpenCrate's checks without range and cooldown)", function()
		local function parkTier(): number
			return (Catalog.getArea("park") :: any).tier
		end

		it("refuses an unknown crate and a zone crate above the player's tier", function()
			local profile = fresh()
			profile.goldenFish = 500
			expect(Crates.openBlocker(profile, 1, "nope")).to.equal("Unknown crate")
			expect(Crates.openBlocker(profile, parkTier() - 1, "park_crate")).to.equal("Unlock this zone first")
			expect(Crates.openBlocker(profile, parkTier(), "park_crate")).never.to.be.ok()
		end)

		it("opens the Classic and Alley Crates from Tier 1 for 60 fish", function()
			local profile = fresh()
			profile.goldenFish = 59
			expect(Crates.openBlocker(profile, 1, "classic_crate")).to.equal("Not enough golden fish")
			profile.goldenFish = 60
			expect(Crates.openBlocker(profile, 1, "classic_crate")).never.to.be.ok()
			expect(Crates.openBlocker(profile, 1, "alley_crate")).never.to.be.ok()
		end)

		it("opens a banked crate free, golden ones only when banked", function()
			local profile = fresh()
			expect(Crates.openBlocker(profile, 1, "alley_golden_crate")).to.equal("Golden crates come from the Index")
			profile.crates.alley_golden_crate = 1
			profile.crates.alley_crate = 2
			expect(Crates.openBlocker(profile, 1, "alley_golden_crate")).never.to.be.ok()
			expect(Crates.openBlocker(profile, 1, "alley_crate")).never.to.be.ok()
		end)
	end)

	describe("what the Market sells (BuyFishItem's cost)", function()
		local function row(id: string): any
			return Catalog.getFishShopRow(id)
		end

		it("sends crates to OpenCrate", function()
			local profile = fresh()
			profile.goldenFish = 999
			local cost, reason = Crates.buyCost(profile, row("alley_crate"))
			expect(cost).never.to.be.ok()
			expect(reason).to.equal("Open crates at the Market")
		end)

		it("sells the Star Treat for 80", function()
			local profile = fresh()
			profile.goldenFish = 79
			expect(select(2, Crates.buyCost(profile, row("star_treat")))).to.equal("Not enough golden fish")
			profile.goldenFish = 80
			expect(Crates.buyCost(profile, row("star_treat"))).to.equal(80)
		end)

		it("prices each perk level and stops at the top", function()
			local profile = fresh()
			profile.goldenFish = 10000
			local costs = { 40, 80, 150, 250, 400 }
			for level = 0, 4 do
				profile.fishPerks.golden_espresso = if level > 0 then level else nil
				expect(Crates.buyCost(profile, row("golden_espresso"))).to.equal(costs[level + 1])
			end
			profile.fishPerks.golden_espresso = 5
			expect(select(2, Crates.buyCost(profile, row("golden_espresso")))).to.equal("Already at the top level")
			expect(Crates.buyCost(profile, row("big_bowl"))).to.equal(150)
			profile.fishPerks.big_bowl = 1
			expect(Crates.buyCost(profile, row("big_bowl"))).never.to.be.ok()
			profile.fishPerks.extra_decor_spot = 1
			expect(Crates.buyCost(profile, row("extra_decor_spot"))).to.equal(250)
		end)
	end)

	describe("income (section 8: Income)", function()
		it("adds a crate piece's bonus only while in use", function()
			local profile = fresh()
			local base = Economy.cafeMultiplier(profile)
			local jukebox = pieceOf("alley", "Legendary")
			own(profile, jukebox, false)
			expect(Economy.cafeMultiplier(profile)).to.be.near(base, 1e-9)
			profile.decorPlaced[jukebox.id] = true
			expect(Economy.cafeMultiplier(profile)).to.be.near(base + 0.15, 1e-9)
		end)

		it("adds 5% per full Decor Index page and per Golden Espresso level", function()
			local profile = fresh()
			local base = Economy.cafeMultiplier(profile)
			profile.fishPerks.golden_espresso = 3
			expect(Economy.cafeMultiplier(profile)).to.be.near(base + 0.15, 1e-9)
			for _, def in Catalog.crateDecor do
				if def.crate == "classic" then
					own(profile, def, false)
				end
			end
			expect(Economy.cafeMultiplier(profile)).to.be.near(base + 0.15 + 0.05, 1e-9)
		end)

		it("shortens the bait wait to 8 minutes with the Big Bowl", function()
			local profile = fresh()
			expect(Economy.lureWaitSeconds(profile)).to.equal(Config.LureWaitSeconds)
			profile.fishPerks.big_bowl = 1
			expect(Economy.lureWaitSeconds(profile)).to.equal(480)
		end)
	end)

	-- QA edges (qa-playtester): the odds a crate card shows are the odds the server rolls, the lucky twentieth
	-- holds over a long seeded run, and what opens or sells follows golden-fish.md sections 3 and 4 for every crate,
	-- tier, bank and wallet.
	describe("Crates edges (QA)", function()
		-- Park and Miller's generator: every product stays below 2^53, so each step is exact in a double
		local seed = 1793059200
		local function uniform(): number
			seed = seed * 48271 % 2147483647
			return seed / 2147483647
		end

		it(
			"rolls each piece exactly as often as the card's chance says, plain and lucky, on every crate",
			function()
				-- A grid of rarity rolls and piece rolls stands in for the server's Random: the share of the grid each
				-- piece gets is its real chance, to within one rarity step (1 / N).
				local N, M = 2000, 12 -- 12 splits 1, 2, 3 or 4 pieces of a rarity evenly
				for _, crate in Catalog.crates do
					for _, luck in { 0, Config.CrateLuckyEvery - 1 } do
						local shown = Crates.pieceChances(crate, Crates.oddsFor(crate, luck))
						local hits: { [string]: number } = {}
						for i = 1, N do
							for j = 1, M do
								local decorId =
									Crates.roll(crate, luck, (i - 0.5) / N, (j - 0.5) / M)
								hits[decorId] = (hits[decorId] or 0) + 1
							end
						end
						for decorId, chance in shown do
							local got = 100 * (hits[decorId] or 0) / (N * M)
							if math.abs(got - chance) > 100 / N then
								error(
									string.format(
										"%s luck %d: %s shows %.3f%%, rolls %.3f%%",
										crate.id,
										luck,
										decorId,
										chance,
										got
									)
								)
							end
						end
						for decorId in hits do
							expect(shown[decorId] ~= nil and shown[decorId] > 0).to.equal(true)
						end
					end
				end
			end
		)

		it(
			"never lets 20 opens of a pool pass without Epic or better over 60,000 seeded opens",
			function()
				for _, pool in { "alley", "classic" } do
					local crate = assert(Catalog.getCrate(pool .. "_crate"))
					local luck, dry, longest = 0, 0, 0
					local count: { [string]: number } = {}
					local refunds = 0
					local opens = 60000
					for _ = 1, opens do
						local decorId, lucky = Crates.roll(crate, luck, uniform(), uniform())
						local def = assert(Catalog.getDecor(decorId))
						local rarity = def.rarity :: any
						expect(def.crate).to.equal(pool)
						expect(lucky).to.equal(luck == Config.CrateLuckyEvery - 1)
						count[rarity] = (count[rarity] or 0) + 1
						refunds += Crates.refund(rarity)
						if Catalog.rarityRank[rarity] >= Catalog.rarityRank.Epic then
							dry = 0
						else
							dry += 1
							longest = math.max(longest, dry)
						end
						luck = Crates.luckAfter(luck, rarity)
						expect(luck).to.equal(dry)
					end
					expect(longest).to.equal(Config.CrateLuckyEvery - 1)
					-- Legendary and Mythical reset the count, so each is a renewal: one every ~37.8 and ~192.4 opens
					local legendary = opens / (count.Legendary or 1)
					local mythical = opens / (count.Mythical or 1)
					expect(legendary > 34 and legendary < 42).to.equal(true)
					expect(mythical > 165 and mythical < 225).to.equal(true)
					-- section 4: "on a 60 fish crate the average refund is about 18" (18.15 at plain odds, a little
					-- more with the lucky twentieth)
					local average = refunds / opens
					expect(average > 17.5 and average < 19.5).to.equal(true)
				end
			end
		)

		it("opens what section 4 says for every crate, tier, bank and wallet", function()
			for _, crate in Catalog.crates do
				local area = Catalog.getArea(crate.area)
				local opensAt = if crate.area == "classic" then 1 else (assert(area)).tier
				for tier = 1, 6 do
					for _, banked in { 0, 1 } do
						for _, fish in { 0, 59, 60, 1000 } do
							local profile = fresh()
							profile.goldenFish = fish
							if banked > 0 then
								profile.crates[crate.id] = banked
							end
							local want: string? = nil
							if tier < opensAt then
								want = "Unlock this zone first"
							elseif banked > 0 then
								want = nil
							elseif crate.golden then
								want = "Golden crates come from the Index"
							elseif fish < 60 then
								want = "Not enough golden fish"
							end
							expect(Crates.openBlocker(profile, tier, crate.id)).to.equal(want)
						end
					end
				end
			end
			for _, odd in { "", "alley", "ALLEY_CRATE", "alley_crate ", "golden_crate", "highest" } do
				expect(Crates.openBlocker(fresh(), 5, odd)).to.equal("Unknown crate")
			end
		end)

		it(
			"sells each perk level once at its price, refusing one fish short and past the top",
			function()
				for _, row in Catalog.fishShop do
					if row.kind == "perk" then
						local costs = assert(row.costs)
						local profile = fresh()
						for level = 0, #costs do
							if level > 0 then
								profile.fishPerks[row.id] = level
							end
							for _, extra in { -1, 0, 1000 } do
								profile.goldenFish = (costs[level + 1] or 0) + extra
								local cost, reason = Crates.buyCost(profile, row)
								if level >= (row.maxLevel or 1) then
									expect(cost).to.equal(nil)
									expect(reason).to.equal("Already at the top level")
								elseif extra < 0 then
									expect(cost).to.equal(nil)
									expect(reason).to.equal("Not enough golden fish")
								else
									expect(cost).to.equal(costs[level + 1])
								end
							end
						end
					end
				end
			end
		)

		it(
			"counts decor spots from the tier, clamped, plus only positive Extra Decor Spot levels",
			function()
				local spots = Config.DecorSpots
				for tier = -1, 8 do
					for _, extra in { -3, 0, 1, 2 } do
						local want = spots[math.clamp(tier, 1, #spots)] + math.max(0, extra)
						expect(Crates.spotCap(tier, extra)).to.equal(want)
					end
				end
			end
		)
	end)

	describe("GoldenFish guards (QA, after F53)", function()
		local GoldenFish = require(Shared.GoldenFish)

		it("ignores NaN and infinite amounts, so a bad number never reaches the save", function()
			local profile = fresh()
			GoldenFish.credit(profile, 40)
			for _, bad in { 0 / 0, math.huge, -math.huge } do
				GoldenFish.credit(profile, bad)
				expect(GoldenFish.trySpend(profile, bad)).to.equal(false)
			end
			expect(profile.goldenFish).to.equal(40)
			expect(profile.lifetimeGoldenFish).to.equal(40)
			expect(profile.stats.fishEarned).to.equal(40)
		end)
	end)
end
