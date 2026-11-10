--!strict
-- Bait.luau against data-model section 8 v0.13.15 (F82): the bowl levels' luck, which moves that share of every
-- rarity's chance up one rarity, and their waits. The odds table is the section's levels 1, 3 and 5 for every food,
-- which the doc rounds to two places (Kibble's 1.148 reads 1.15), so a cell matches within half a hundredth.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Bait = require(Shared.Bait)
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)

	-- food -> level -> Common, Rare, Epic, Legendary, Mythical (section 8's table)
	-- #2239 (Derek2 2026-11-07: "nerf food bowl high rarity chance slightly"): level 1 is each food's new row
	local TABLE: { [string]: { [number]: { number } } } = {
		kibble = {
			[1] = { 70.375, 25.375, 3.4, 0.765, 0.085 },
			[3] = { 64.745, 28.975, 5.158, 0.9758, 0.1462 },
			[5] = { 59.115, 32.575, 6.916, 1.1866, 0.2074 },
		},
		tuna = {
			[1] = { 41.125, 46.125, 10.2, 2.21, 0.34 },
			[3] = { 37.835, 45.725, 13.074, 2.8492, 0.5168 },
			[5] = { 34.545, 45.325, 15.948, 3.4884, 0.6936 },
		},
		salmon = {
			[1] = { 18, 48, 25.5, 7.225, 1.275 },
			[3] = { 16.56, 45.6, 27.3, 8.687, 1.853 },
			[5] = { 15.12, 43.2, 29.1, 10.149, 2.431 },
		},
		sardines = {
			[1] = { 31.875, 46.875, 17, 3.825, 0.425 },
			[3] = { 29.325, 45.675, 19.39, 4.879, 0.731 },
			[5] = { 26.775, 44.475, 21.78, 5.933, 1.037 },
		},
		caviar = {
			[1] = { 16.55, 34, 35, 11.9, 2.55 },
			[3] = { 15.226, 32.604, 34.92, 13.748, 3.502 },
			[5] = { 13.902, 31.208, 34.84, 15.596, 4.454 },
		},
		moon_milk = {
			[1] = { 0, 32, 38.25, 23.8, 5.95 },
			[3] = { 0, 29.44, 37.75, 24.956, 7.854 },
			[5] = { 0, 26.88, 37.25, 26.112, 9.758 },
		},
		star_treat = {
			[1] = { 0, 0, 43.25, 44, 12.75 },
			[3] = { 0, 0, 39.79, 43.94, 16.27 },
			[5] = { 0, 0, 36.33, 43.88, 19.79 },
		},
	}

	local function total(odds: any): number
		local sum = 0
		for _, rarity in Catalog.rarityOrder do
			sum += odds[rarity]
		end
		return sum
	end

	describe("oddsFor (section 8's table)", function()
		for lureId, levels in TABLE do
			for level, row in levels do
				it(string.format("%s in a level %d bowl", lureId, level), function()
					local def = Catalog.getLure(lureId)
					expect(def).to.be.ok()
					local odds: any = Bait.oddsFor((def :: any).odds, level)
					for index, rarity in Catalog.rarityOrder do
						expect(odds[rarity]).to.be.near(row[index], 0.005)
					end
				end)
			end
		end

		it(
			"every food at every level still adds to 100, and Mythical never loses its own share",
			function()
				for _, def in Catalog.lures do
					for level = 1, Bait.MAX_LEVEL do
						local odds: any = Bait.oddsFor(def.odds, level)
						expect(total(odds)).to.be.near(100, 1e-9)
						expect(odds.Mythical >= def.odds.Mythical).to.equal(true)
					end
				end
			end
		)

		it(
			"level 1 and no bowl leave the odds as they are; past the top reads as the Royal Bowl",
			function()
				local salmon: any = (Catalog.getLure("salmon") :: any).odds
				for _, level in { 0, 1 } do
					local odds: any = Bait.oddsFor(salmon, level)
					for _, rarity in Catalog.rarityOrder do
						expect(odds[rarity]).to.equal(salmon[rarity])
					end
				end
				expect((Bait.oddsFor(salmon, 9) :: any).Legendary).to.be.near(10.149, 1e-9)
			end
		)

		it(
			"the upgrade card's example: Salmon Legendary 7.225% to 7.956% at level 2 (#2239)",
			function()
				local salmon: any = (Catalog.getLure("salmon") :: any).odds
				expect((Bait.oddsFor(salmon, 2) :: any).Legendary).to.be.near(7.956, 1e-9)
			end
		)

		it("a missing rarity counts as 0 and the input is left alone", function()
			local odds: any = { Common = 50, Rare = 50 }
			local moved: any = Bait.oddsFor(odds, 5)
			expect(moved.Common).to.be.near(42, 1e-9)
			expect(moved.Rare).to.be.near(50 * 0.84 + 50 * 0.16, 1e-9)
			expect(moved.Epic).to.be.near(8, 1e-9)
			expect(moved.Legendary).to.equal(0)
			expect(moved.Mythical).to.equal(0)
			expect(odds.Epic).never.to.be.ok()
		end)
	end)

	describe("luck, waits and names", function()
		it("luck is BowlLuck by level", function()
			expect(Bait.luck(0)).to.equal(0)
			expect(Bait.luck(1)).to.equal(0)
			expect(Bait.luck(3)).to.equal(0.08)
			expect(Bait.luck(5)).to.equal(0.16)
			expect(Bait.MAX_LEVEL).to.equal(Catalog.upgradesById.lure_bowl.maxLevel)
		end)

		it("day waits 10:00 to 8:00, the Big Bowl two minutes off (F95), night half", function()
			local day = { 600, 570, 540, 510, 480 }
			local big = { 480, 450, 420, 390, 360 }
			for level = 1, 5 do
				expect(Bait.waitSeconds(level, false)).to.equal(day[level])
				expect(Bait.waitSeconds(level, true)).to.equal(big[level])
				expect(Bait.waitSeconds(level, false, true)).to.equal(day[level] // 2)
				expect(Bait.waitSeconds(level, true, true)).to.equal(big[level] // 2)
			end
			expect(Bait.waitSeconds(0, false)).to.equal(Config.LureWaitSeconds)
		end)

		it(
			"the account's first bait waits at most 2 minutes, later ones as usual (#1895)",
			function()
				expect(Config.FirstBaitWaitSeconds).to.equal(1) -- #2946: was 45 (#2774), 120 before
				expect(Bait.firstWait(600, 0)).to.equal(1)
				expect(Bait.firstWait(0.5, 0)).to.equal(0.5) -- a speed-up only ever shortens it
				expect(Bait.firstWait(600, 1)).to.equal(600)
				expect(Bait.firstWait(480, 7)).to.equal(480)
			end
		)

		it("the account's first bait is Rare or better, once (#1897, #2793)", function()
			expect(Bait.wowDue(false)).to.equal(true) -- the first bait (#2793: was the second), or the next for an
			-- account that set baits before without one
			expect(Bait.wowDue(true)).to.equal(false) -- had it
			expect(Bait.WOW_EPIC_CHANCE).to.be.near(0.15, 1e-12)
			expect(Bait.wowRarity("Common", 0.5)).to.equal("Rare")
			expect(Bait.wowRarity("Common", 0.149)).to.equal("Epic")
			expect(Bait.wowRarity("Common", 0.15)).to.equal("Rare")
			for _, rarity in { "Rare", "Epic", "Legendary", "Mythical" } do
				expect(Bait.wowRarity(rarity :: any, 0)).to.equal(rarity)
			end
		end)

		it("names the five bowls", function()
			local names = {}
			for level = 1, 5 do
				table.insert(names, Bait.bowlName(level))
			end
			expect(table.concat(names, ", ")).to.equal(
				"Bait Bowl, Comfy Bowl, Fancy Bowl, Deluxe Bowl, Royal Bowl"
			)
			expect(Bait.bowlName(0)).to.equal("Bait Bowl")
		end)
	end)

	describe("the Second Bait Bowl (#1161)", function()
		local ProfileSchema = require(Shared.ProfileSchema)

		local function bait(lureId: string, placedAt: number): any
			return {
				lureId = lureId,
				placedAt = placedAt,
				catId = "tabby",
				variant = "base",
				charm = 50,
			}
		end

		it("keeps each bowl's bait apart: bowl 1 in bait, bowl 2 in bait2", function()
			local profile = ProfileSchema.template(1000)
			Bait.setState(profile, 1, bait("kibble", 10))
			Bait.setState(profile, 2, bait("tuna", 20))
			expect((Bait.stateOf(profile, 1) :: any).lureId).to.equal("kibble")
			expect((Bait.stateOf(profile, 2) :: any).lureId).to.equal("tuna")
			expect((profile.bait :: any).placedAt).to.equal(10)
			expect((profile.bait2 :: any).placedAt).to.equal(20)
			Bait.setState(profile, 2, nil)
			expect(profile.bait2).never.to.be.ok()
			expect((Bait.stateOf(profile, 1) :: any).lureId).to.equal("kibble")
			expect(Bait.BOWLS).to.equal(2)
		end)

		it(
			"is on with the pass and offered without it (capacity, not a paid random item)",
			function()
				expect(Bait.secondBowl(true)).to.equal("on")
				expect(Bait.secondBowl(false)).to.equal("offer")
			end
		)

		it(
			"lists every food's odds at a level, the first bowl's odds, each summing to 100",
			function()
				for level = 1, Bait.MAX_LEVEL do
					local rows = Bait.oddsCard(level)
					expect(#rows).to.equal(#Catalog.lures)
					for index, row in rows do
						local lure = Catalog.lures[index]
						expect(row.lureId).to.equal(lure.id)
						expect(row.name).to.equal(lure.name)
						expect(row.odds :: any).to.deepEqual(Bait.oddsFor(lure.odds, level) :: any)
						local sum = 0
						for _, rarity in Catalog.rarityOrder do
							sum += (row.odds :: any)[rarity] or 0
						end
						expect(sum).to.be.near(100, 1e-6)
					end
				end
			end
		)
	end)
end
