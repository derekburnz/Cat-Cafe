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
	local TABLE: { [string]: { [number]: { number } } } = {
		kibble = {
			[1] = { 70, 25, 4, 0.9, 0.1 },
			[3] = { 64.4, 28.6, 5.68, 1.15, 0.17 },
			[5] = { 58.8, 32.2, 7.36, 1.4, 0.24 },
		},
		tuna = {
			[1] = { 40, 45, 12, 2.6, 0.4 },
			[3] = { 36.8, 44.6, 14.64, 3.35, 0.61 },
			[5] = { 33.6, 44.2, 17.28, 4.1, 0.82 },
		},
		salmon = {
			[1] = { 15, 45, 30, 8.5, 1.5 },
			[3] = { 13.8, 42.6, 31.2, 10.22, 2.18 },
			[5] = { 12.6, 40.2, 32.4, 11.94, 2.86 },
		},
		sardines = {
			[1] = { 30, 45, 20, 4.5, 0.5 },
			[3] = { 27.6, 43.8, 22, 5.74, 0.86 },
			[5] = { 25.2, 42.6, 24, 6.98, 1.22 },
		},
		caviar = {
			[1] = { 10, 35, 38, 14, 3 },
			[3] = { 9.2, 33, 37.76, 15.92, 4.12 },
			[5] = { 8.4, 31, 37.52, 17.84, 5.24 },
		},
		moon_milk = {
			[1] = { 0, 20, 45, 28, 7 },
			[3] = { 0, 18.4, 43, 29.36, 9.24 },
			[5] = { 0, 16.8, 41, 30.72, 11.48 },
		},
		star_treat = {
			[1] = { 0, 0, 40, 45, 15 },
			[3] = { 0, 0, 36.8, 44.6, 18.6 },
			[5] = { 0, 0, 33.6, 44.2, 22.2 },
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

		it("every food at every level still adds to 100, and Mythical never loses its own share", function()
			for _, def in Catalog.lures do
				for level = 1, Bait.MAX_LEVEL do
					local odds: any = Bait.oddsFor(def.odds, level)
					expect(total(odds)).to.be.near(100, 1e-9)
					expect(odds.Mythical >= def.odds.Mythical).to.equal(true)
				end
			end
		end)

		it("level 1 and no bowl leave the odds as they are; past the top reads as the Royal Bowl", function()
			local salmon: any = (Catalog.getLure("salmon") :: any).odds
			for _, level in { 0, 1 } do
				local odds: any = Bait.oddsFor(salmon, level)
				for _, rarity in Catalog.rarityOrder do
					expect(odds[rarity]).to.equal(salmon[rarity])
				end
			end
			expect((Bait.oddsFor(salmon, 9) :: any).Legendary).to.be.near(11.94, 1e-9)
		end)

		it("the upgrade card's example: Salmon Legendary 8.5% to 9.36% at level 2", function()
			local salmon: any = (Catalog.getLure("salmon") :: any).odds
			expect((Bait.oddsFor(salmon, 2) :: any).Legendary).to.be.near(9.36, 1e-9)
		end)

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

		it("day waits 10:00 to 8:00, the Big Bowl a fifth off, night half", function()
			local day = { 600, 570, 540, 510, 480 }
			local big = { 480, 456, 432, 408, 384 }
			for level = 1, 5 do
				expect(Bait.waitSeconds(level, false)).to.equal(day[level])
				expect(Bait.waitSeconds(level, true)).to.equal(big[level])
				expect(Bait.waitSeconds(level, false, true)).to.equal(day[level] // 2)
				expect(Bait.waitSeconds(level, true, true)).to.equal(big[level] // 2)
			end
			expect(Bait.waitSeconds(0, false)).to.equal(Config.LureWaitSeconds)
		end)

		it("names the five bowls", function()
			local names = {}
			for level = 1, 5 do
				table.insert(names, Bait.bowlName(level))
			end
			expect(table.concat(names, ", ")).to.equal("Bait Bowl, Comfy Bowl, Fancy Bowl, Deluxe Bowl, Royal Bowl")
			expect(Bait.bowlName(0)).to.equal("Bait Bowl")
		end)
	end)
end
