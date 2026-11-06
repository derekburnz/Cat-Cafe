--!strict
-- UI/Components/LuckLogic.luau: the HUD's Luck chip, its card, the Lucky Day line under the clock and the Lucky Cat's
-- shop lines (F88, luck-and-rare-moments.md sections 1b to 1d).
return function()
	local Client =
		game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
	local LuckLogic = require(
		Client:WaitForChild("UI"):WaitForChild("Components"):WaitForChild("LuckLogic")
	) :: any
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared:WaitForChild("Catalog")) :: any
	local Crates = require(Shared:WaitForChild("Crates")) :: any

	local NOW = 100000

	local function player(extra: { [string]: any }?): any
		local state: { [string]: any } = {
			money = 0,
			incomePerSecond = 0,
			tier = 1,
			catsOwned = {},
			upgradeLevels = {},
			decorOwned = {},
			decorPlaced = {},
			lures = {},
		}
		for key, value in extra or {} do
			state[key] = value
		end
		return state
	end

	local THREE = {
		{ id = "statue", value = 0.3 },
		{ id = "potion", value = 0.5, endsAt = NOW + 492 },
		{ id = "lucky_day", value = 0.5, endsAt = NOW + 190 },
	}

	describe("LuckLogic.current, shown and lucky", function()
		it("always shows the chip, even at a plain 1x (#1150)", function()
			local state = player({ luck = 1, luckSources = {} })
			expect(LuckLogic.shown(state, NOW)).to.equal(true)
			expect(LuckLogic.current(state, NOW)).to.equal(1)
			expect(LuckLogic.boosted(state, NOW)).to.equal(false)
			expect(LuckLogic.text(LuckLogic.current(state, NOW))).to.equal("Luck x1")
			expect(LuckLogic.shown(player(), NOW)).to.equal(true)
			expect(LuckLogic.boosted(player(), NOW)).to.equal(false)
		end)

		it("adds the running sources as the server does", function()
			local state =
				player({ luck = 2.3, luckSources = THREE, upgradeLevels = { lucky_cat = 3 } })
			expect(LuckLogic.shown(state, NOW)).to.equal(true)
			expect(LuckLogic.current(state, NOW)).to.equal(2.3)
			expect(LuckLogic.lucky(state, NOW)).to.equal(true)
			expect(LuckLogic.text(LuckLogic.current(state, NOW))).to.equal("Luck x2.3")
		end)

		it("drops a timed source when it ends, before the next sync", function()
			local state =
				player({ luck = 2.3, luckSources = THREE, upgradeLevels = { lucky_cat = 3 } })
			expect(LuckLogic.current(state, NOW + 200)).to.equal(1.8)
			expect(LuckLogic.lucky(state, NOW + 200)).to.equal(false)
			expect(LuckLogic.current(state, NOW + 500)).to.equal(1.3)
			local potion =
				player({ luckSources = { { id = "potion", value = 0.5, endsAt = NOW + 10 } } })
			expect(LuckLogic.shown(potion, NOW + 11)).to.equal(true)
			expect(LuckLogic.boosted(potion, NOW)).to.equal(true)
			expect(LuckLogic.boosted(potion, NOW + 11)).to.equal(false)
		end)

		it("keeps state.luck when no sources came, at most LuckMax", function()
			expect(LuckLogic.current(player({ luck = 1.5 }), NOW)).to.equal(1.5)
			expect(LuckLogic.shown(player({ luck = 1.5 }), NOW)).to.equal(true)
			expect(LuckLogic.current(player({ luck = 9 }), NOW)).to.equal(3)
			local lots = {}
			for _ = 1, 30 do
				table.insert(lots, { id = "statue", value = 0.1 })
			end
			expect(LuckLogic.current(player({ luckSources = lots }), NOW)).to.equal(3)
		end)
	end)

	describe("LuckLogic.rows", function()
		it("lists each source with its share and time left", function()
			local rows = LuckLogic.rows(
				player({ luckSources = THREE, upgradeLevels = { lucky_cat = 3 } }),
				NOW
			)
			expect(#rows).to.equal(3)
			expect(rows[1].name).to.equal("Lucky Cat statue, level 3")
			expect(rows[1].value).to.equal("+0.3")
			expect(rows[1].time).to.equal(nil)
			expect(rows[2].name).to.equal("Lucky Potion")
			expect(rows[2].value).to.equal("+0.5")
			expect(rows[2].time).to.equal("8:12")
			expect(rows[3].name).to.equal("Lucky Day")
			expect(rows[3].time).to.equal("3:10")
		end)

		it("names the statue's level from its share when the level is missing", function()
			local rows =
				LuckLogic.rows(player({ luckSources = { { id = "statue", value = 0.2 } } }), NOW)
			expect(rows[1].name).to.equal("Lucky Cat statue, level 2")
		end)
	end)

	describe("LuckLogic.food and crate", function()
		local catalog = { cats = Catalog.cats, lures = Catalog.lures, crates = Catalog.crates }

		it("shows the rarest food in the bag, else Kibble", function()
			expect(LuckLogic.food(catalog, player()).id).to.equal("kibble")
			expect(LuckLogic.food(catalog, player({ lures = { tuna = 2, kibble = 5 } })).id).to.equal(
				"tuna"
			)
			expect(LuckLogic.food(catalog, player({ lures = { tuna = 2, star_treat = 1 } })).id).to.equal(
				"star_treat"
			)
			expect(LuckLogic.food(nil, player())).to.equal(nil)
		end)

		it("shows the first plain crate you own, else the Classic, never a golden one", function()
			expect(LuckLogic.crate(catalog, player()).id).to.equal("classic_crate")
			expect(LuckLogic.crate(catalog, player({ crates = { alley_crate = 1 } })).id).to.equal(
				"alley_crate"
			)
			expect(LuckLogic.crate(catalog, player({ crates = { alley_golden_crate = 2 } })).id).to.equal(
				"classic_crate"
			)
		end)

		it("shows the odds the server opens the crate on", function()
			local crate = Catalog.getCrate("classic_crate")
			for _, opens in { 0, 5, 19 } do
				local state = player({ crateLuck = { classic = opens } })
				local shown = LuckLogic.crateOdds(catalog, state, crate, 1.8)
				local rolled = Crates.oddsFor(crate, opens, 1.8)
				for _, rarity in Catalog.rarityOrder do
					expect(shown[rarity] or 0).to.be.near(rolled[rarity] or 0, 1e-9)
				end
			end
		end)
	end)

	describe("LuckLogic.dayLine (#1572, day rolls v2)", function()
		it("names today's kinds in the day, in a fixed order", function()
			expect(LuckLogic.dayLine({ luckyDay = true, phase = "day" })).to.equal("Lucky Day")
			expect(LuckLogic.dayLine({ goldenDay = true, phase = "day" })).to.equal("Golden Day")
			expect(LuckLogic.dayLine({ rainbowDay = true, luckyDay = true, phase = "day" })).to.equal(
				"Lucky · Rainbow Day"
			)
			expect(
				LuckLogic.dayLine({
					luckyDay = true,
					goldenDay = true,
					rainbowDay = true,
					phase = "day",
				})
			).to.equal("Lucky · Golden · Rainbow Day")
		end)

		it("shows nothing on a plain day or at night, and no countdown", function()
			expect(LuckLogic.dayLine({ day = 3, nextLuckyDay = 4, phase = "day" })).to.equal(nil)
			expect(LuckLogic.dayLine({ luckyDay = true, phase = "night" })).to.equal(nil)
			expect(LuckLogic.dayLine({})).to.equal(nil)
		end)

		it("gives each kind's card line and the sunrise banner", function()
			local view = { luckyDay = true, goldenDay = true, phase = "day" }
			local lines = LuckLogic.dayCard(view)
			expect(#lines).to.equal(2)
			expect(lines[1]).to.equal(
				"Lucky Day: +0.5 Luck: rarer cats more likely until night (1 day in 3)"
			)
			expect(lines[2]).to.equal("Golden Day: Gold cats x2 as likely until night (1 day in 5)")
			expect(LuckLogic.dayCard({ rainbowDay = true })[1]).to.equal(
				"Rainbow Day: Rainbow cats x3 as likely until night (1 day in 10)"
			)
			local title, line = LuckLogic.dayBanner(view)
			expect(title).to.equal("Lucky Day! Golden Day!")
			expect(line).to.equal(
				"+0.5 Luck: rarer cats more likely. Gold cats x2 as likely until night"
			)
			expect(LuckLogic.dayBanner({ phase = "day" })).to.equal(nil)
		end)
	end)

	describe("LuckLogic.oddsRich", function()
		local function hex(rarity: string): string
			return rarity:sub(1, 1):rep(6)
		end
		local function plain(text: string): string
			return (text:gsub("<[^>]+>", ""):gsub(utf8.char(0xA0), " "))
		end

		it("leaves out the rarities that cannot come and colours each part", function()
			local text = LuckLogic.oddsRich(
				{ Common = 0, Rare = 0, Epic = 71.56, Legendary = 23.44, Mythical = 5 },
				hex
			)
			expect(plain(text)).to.equal("Epic 72%   Legendary 23%\nMythical 5%")
			expect(text:find('<font color="#EEEEEE">', 1, true)).to.be.ok()
			expect(text:find("Common", 1, true)).to.equal(nil)
		end)

		it("keeps every line within 36 letters", function()
			local text = LuckLogic.oddsRich(
				{ Common = 43.1, Rare = 27, Epic = 23, Legendary = 5.75, Mythical = 1.15 },
				hex
			)
			expect(plain(text)).to.equal(
				"Common 43%   Rare 27%   Epic 23%\nLegendary 6%   Mythical 1%"
			)
			for line in plain(text):gmatch("[^\n]+") do
				expect(#line <= 36).to.equal(true)
			end
			expect(LuckLogic.oddsRich(nil, hex)).to.equal("")
		end)

		it("marks the rarities Luck makes more likely, in whole percents (#1153)", function()
			local before = { Common = 57.4, Rare = 27, Epic = 12, Legendary = 3, Mythical = 0.6 }
			local after = { Common = 50, Rare = 28, Epic = 16, Legendary = 5, Mythical = 1 }
			expect(plain(LuckLogic.oddsRich(after, hex, before))).to.equal(
				"Common 50%   Rare 28%↑   Epic 16%↑\nLegendary 5%↑   Mythical 1%↑"
			)
			expect(LuckLogic.percent(0.6)).to.equal("0.6%")
			expect(LuckLogic.percent(42.6)).to.equal("43%")
			expect(LuckLogic.percent(0.01)).to.equal("<0.1%")
		end)
	end)

	describe("LuckLogic.boostRich", function()
		local function hex(rarity: string): string
			return rarity:lower()
		end
		it("says how much more likely each rare rarity is (#1776)", function()
			expect(LuckLogic.boostRich(2, hex)).to.equal(
				'<font color="#epic">Epic</font> · <font color="#legendary">Legendary</font> · '
					.. '<font color="#mythical">Mythical</font>  <font color="#7CFC6A">+100%</font>'
			)
			expect(string.find(LuckLogic.boostRich(1.3, hex), "+30%", 1, true)).to.be.ok()
			expect(string.find(LuckLogic.boostRich(1.3, hex), "Rare", 1, true)).never.to.be.ok()
		end)
		it("is empty with no Luck", function()
			expect(LuckLogic.boostRich(1, hex)).to.equal("")
		end)
	end)

	describe("LuckLogic.statueLines", function()
		it("says what the Lucky Cat gives now and next", function()
			local first, second = LuckLogic.statueLines(0, 5)
			expect(first).to.equal("A beckoning cat by your front door")
			expect(second).to.equal("Each level: Luck +0.1, rarer bait cats and crate finds")
			first, second = LuckLogic.statueLines(2, 5)
			expect(first).to.equal("Luck +0.2 now, +0.3 next level")
			expect(second).to.equal("Rarer bait cats and crate finds")
			first = LuckLogic.statueLines(5, 5)
			expect(first).to.equal("Luck +0.5, the most it gives")
		end)
	end)
end
