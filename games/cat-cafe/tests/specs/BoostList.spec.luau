--!strict
-- UI/Components/BoostList.luau: the money card's list of what lifts the cafe's money (Derek 2026-10-28).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local BoostList = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("BoostList")
	) :: any
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared:WaitForChild("Catalog")) :: any
	local Economy = require(Shared:WaitForChild("Economy")) :: any

	local NOW = 1770000000

	local function state(extra: { [string]: any }?): any
		local base: { [string]: any } = {
			money = 0,
			incomePerSecond = 0,
			tier = 1,
			catsOwned = {},
			upgradeLevels = {},
			decorOwned = {},
			decorPlaced = {},
			lures = {},
			fishPerks = {},
			indexRewards = {},
			buffs = {},
		}
		for key, value in extra or {} do
			base[key] = value
		end
		return base
	end

	local function byKey(rows: { any }): { [string]: any }
		local out: { [string]: any } = {}
		for _, row in rows do
			out[row.key] = row
		end
		return out
	end

	describe("BoostList words", function()
		it("writes percents and multipliers short", function()
			expect(BoostList.percent(0.25)).to.equal("+25%")
			expect(BoostList.percent(0)).to.equal("+0%")
			expect(BoostList.percent(0.025)).to.equal("+2.5%")
			expect(BoostList.percent(0.6000000001)).to.equal("+60%")
			expect(BoostList.times(1.5)).to.equal("x1.5")
			expect(BoostList.times(2)).to.equal("x2")
			expect(BoostList.times(1.725)).to.equal("x1.73")
		end)
	end)

	describe("BoostList.rows", function()
		it("lists every source a new cafe has, the empty ones grey", function()
			local rows = BoostList.rows(Catalog, state(), NOW)
			local keys = {}
			for _, row in rows do
				table.insert(keys, row.key)
			end
			expect(table.concat(keys, ",")).to.equal(
				"tables,espresso,decor,golden_espresso,index,tier,total"
			)
			local named = byKey(rows)
			expect(named.tables.value).to.equal("+0%")
			expect(named.tables.active).to.equal(false)
			expect(named.espresso.value).to.equal("+0%") -- the espresso machine starts at level 1
			expect(named.tier.value).to.equal("x1")
			expect(named.total.value).to.equal("x1")
		end)

		it("adds the cafe's percents, times the tier, as the server's formula does", function()
			local s = state({
				tier = 3,
				upgradeLevels = { tables = 6, espresso = 3 },
				fishPerks = { golden_espresso = 2 },
			})
			local named = byKey(BoostList.rows(Catalog, s, NOW))
			expect(named.tables.name).to.equal("Tables (6)")
			expect(named.tables.value).to.equal("+60%")
			expect(named.espresso.value).to.equal("+30%")
			expect(named.golden_espresso.value).to.equal("+10%")
			local tierDef = Catalog.getTier(3)
			expect(named.tier.amount).to.equal(tierDef.multiplier)
			-- the server's own sums for the same cafe
			local profile = {
				tier = 3,
				upgradeLevels = s.upgradeLevels,
				decorOwned = {},
				decorPlaced = {},
				fishPerks = s.fishPerks,
				indexRewards = {},
				cats = {},
			}
			local expected = Economy.cafeMultiplier(profile) * Economy.tierMultiplier(profile)
			expect(named.total.amount).to.be.near(expected, 1e-9)
		end)

		it("counts only placed decor the player owns", function()
			local pieces: { any } = {}
			for _, def in Catalog.decor do
				if def.bonus and def.bonus > 0 then
					table.insert(pieces, def)
				end
			end
			expect(#pieces >= 2).to.equal(true)
			local a, b = pieces[1], pieces[2]
			local s = state({
				decorOwned = { [a.id] = true, [b.id] = true },
				decorPlaced = { [a.id] = true, [b.id] = false },
			})
			local named = byKey(BoostList.rows(Catalog, s, NOW))
			expect(named.decor.name).to.equal("Decor (1 placed)")
			expect(named.decor.amount).to.be.near(a.bonus, 1e-9)
		end)

		it("shows running money potions, capped together, and not finished ones", function()
			local s = state({
				buffs = {
					tip_potion = NOW + 300,
					big_tip_potion = NOW + 60,
					lucky_potion = NOW + 300,
				},
			})
			local named = byKey(BoostList.rows(Catalog, s, NOW))
			expect(named.tip_potion.value).to.equal("+25%")
			expect(named.big_tip_potion.value).to.equal("+50%")
			expect(named.lucky_potion).to.equal(nil)
			expect(named.total.value).to.equal("x1.75")
			local ended =
				byKey(BoostList.rows(Catalog, state({ buffs = { tip_potion = NOW - 1 } }), NOW))
			expect(ended.tip_potion).to.equal(nil)
		end)
	end)
end
