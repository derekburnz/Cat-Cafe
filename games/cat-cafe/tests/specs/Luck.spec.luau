--!strict
-- Luck.luau, Clock's day numbers and the rolls Luck touches against luck-and-rare-moments.md section 1 (F88): one
-- number from x1.0 that adds up the Lucky Cat statue, a running Lucky Potion and a Lucky Day, at most LuckMax; on a
-- roll it multiplies the Epic and rarer chances, Rare keeps its chance and Common takes the rest; every
-- LuckyDayEvery-th day of a server is a Lucky Day.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Bait = require(Shared.Bait)
	local Catalog = require(Shared.Catalog)
	local Catching = require(Shared.Catching)
	local Clock = require(Shared.Clock)
	local Config = require(Shared.Config)
	local Crates = require(Shared.Crates)
	local Luck = require(Shared.Luck)
	local Potions = require(Shared.Potions)
	local ProfileSchema = require(Shared.ProfileSchema)
	local Types = require(Shared.Types)

	local NOW = 100000
	local RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythical" }

	local function total(odds: { [string]: number }): number
		local sum = 0
		for _, rarity in RARITIES do
			sum += odds[rarity] or 0
		end
		return sum
	end

	local function fresh(): Types.PlayerProfile
		return ProfileSchema.template(NOW)
	end

	describe("apply", function()
		it("turns Kibble on a level 1 bowl into the section's example at x1.5", function()
			local kibble = (Catalog.getLure("kibble") :: Types.LureDef).odds
			local odds = Luck.apply(Bait.oddsFor(kibble, 1), 1.5)
			expect(odds.Common).to.be.near(67.5, 1e-9)
			expect(odds.Rare).to.be.near(25, 1e-9)
			expect(odds.Epic).to.be.near(6, 1e-9)
			expect(odds.Legendary).to.be.near(1.35, 1e-9)
			expect(odds.Mythical).to.be.near(0.15, 1e-9)
		end)

		it("leaves the odds as they are at x1 or less, in a new table", function()
			local kibble = (Catalog.getLure("kibble") :: Types.LureDef).odds
			for _, luck in { 1, 0.5, 0 } do
				local odds = Luck.apply(kibble, luck)
				expect(odds ~= kibble).to.equal(true)
				expect(odds :: any).to.deepEqual(kibble)
			end
		end)

		it("keeps every food's total at every Luck up to LuckMax, never below 0", function()
			for _, lure in Catalog.lures do
				for bowl = 1, #Config.BowlLuck do
					local base = Bait.oddsFor(lure.odds, bowl) :: any
					for luck = 1, Config.LuckMax, 0.1 do
						local odds = Luck.apply(base, luck) :: any
						expect(total(odds)).to.be.near(total(base), 1e-6)
						for _, rarity in RARITIES do
							expect(odds[rarity] >= 0).to.equal(true)
						end
						-- the Epic and rarer chances never shrink
						for _, rarity in { "Epic", "Legendary", "Mythical" } do
							expect(odds[rarity] >= base[rarity] - 1e-9).to.equal(true)
						end
					end
				end
			end
		end)

		it("takes the rest off Rare once Common is used up", function()
			local odds =
				Luck.apply({ Common = 10, Rare = 50, Epic = 20, Legendary = 10, Mythical = 5 }, 2)
			expect(odds.Common).to.equal(0)
			expect(odds.Rare).to.be.near(25, 1e-9) -- 95 less 40, 20 and 10
			expect(odds.Epic).to.be.near(40, 1e-9)
			expect(total(odds :: any)).to.be.near(95, 1e-9)
		end)

		it("scales the rare ones to fill the total when they alone reach it", function()
			local odds =
				Luck.apply({ Common = 10, Rare = 10, Epic = 50, Legendary = 25, Mythical = 5 }, 2)
			expect(odds.Common).to.equal(0)
			expect(odds.Rare).to.equal(0)
			expect(odds.Epic).to.be.near(62.5, 1e-9)
			expect(odds.Legendary).to.be.near(31.25, 1e-9)
			expect(odds.Mythical).to.be.near(6.25, 1e-9)
		end)

		it("never brings in a rarity a table does not have", function()
			-- no Common: the rest goes to Rare
			local noCommon =
				Luck.apply({ Common = 0, Rare = 50, Epic = 30, Legendary = 15, Mythical = 5 }, 1.5)
			expect(noCommon.Common).to.equal(0)
			expect(noCommon.Rare).to.be.near(25, 1e-9)
			-- neither Common nor Rare: the rare ones keep their shares of the total
			local top = Luck.applyMap({ Epic = 80, Legendary = 20 }, 2)
			expect(top.Common).to.equal(0)
			expect(top.Rare).to.equal(0)
			expect(top.Epic).to.be.near(80, 1e-9)
			expect(top.Legendary).to.be.near(20, 1e-9)
			expect(top.Mythical).to.equal(0)
		end)
	end)

	describe("sources and of", function()
		it("gives a fresh player no source and x1.0", function()
			local profile = fresh()
			expect(#Luck.sources(profile, NOW, false)).to.equal(0)
			expect(Luck.of(profile, NOW, false)).to.equal(1)
			expect(Luck.text(Luck.of(profile, NOW, false))).to.equal("Luck x1.0")
		end)

		it("adds LuckPerStatueLevel for each Lucky Cat level", function()
			local profile = fresh()
			for level = 1, 5 do
				profile.upgradeLevels[Luck.UPGRADE] = level
				local sources = Luck.sources(profile, NOW, false)
				expect(#sources).to.equal(1)
				expect(sources[1].id).to.equal("statue")
				expect(sources[1].value).to.be.near(level * Config.LuckPerStatueLevel, 1e-9)
				expect(Luck.of(profile, NOW, false)).to.equal(1 + level / 10)
			end
			expect(Luck.text(Luck.of(profile, NOW, false))).to.equal("Luck x1.5")
		end)

		it(
			"adds the Lucky Potion while it runs and the Lucky Day, in the order statue, potion, day",
			function()
				local profile = fresh()
				profile.upgradeLevels[Luck.UPGRADE] = 3
				profile.buffs[Potions.LUCKY] = 600
				local sources = Luck.sources(profile, NOW, true)
				expect(#sources).to.equal(3)
				expect(sources[1].id).to.equal("statue")
				expect(sources[2].id).to.equal("potion")
				expect(sources[2].value).to.equal(Config.LuckyPotionLuck)
				expect(sources[3].id).to.equal("lucky_day")
				expect(sources[3].value).to.equal(Config.LuckyDayPlayerLuck)
				expect(Luck.of(profile, NOW, true)).to.equal(2.3)
				expect(Luck.text(Luck.of(profile, NOW, true))).to.equal("Luck x2.3")
				-- the potion's 10 minutes run out
				expect(Luck.of(profile, NOW + 600, false)).to.equal(1.3)
			end
		)

		it("is never more than LuckMax nor less than x1", function()
			local profile = fresh()
			profile.upgradeLevels[Luck.UPGRADE] = 99
			expect(Luck.of(profile, NOW, true)).to.equal(Config.LuckMax)
			profile.upgradeLevels[Luck.UPGRADE] = -4
			expect(Luck.of(profile, NOW, false)).to.equal(1)
		end)

		it("reaches x2.5 with every source at its most, under LuckMax", function()
			local profile = fresh()
			profile.upgradeLevels[Luck.UPGRADE] = 5
			profile.buffs[Potions.LUCKY] = 600
			expect(Luck.of(profile, NOW, true)).to.equal(2.5)
			expect(2.5 <= Config.LuckMax).to.equal(true)
			expect(Luck.text(2)).to.equal("Luck x2.0")
			expect(Luck.text(1.25)).to.equal("Luck x1.25")
		end)
	end)

	describe("the Lucky Cat upgrade", function()
		it("is a coins-only upgrade of five levels, level n at Tier n", function()
			local def = Catalog.getUpgrade(Luck.UPGRADE) :: Types.UpgradeDef
			expect(def ~= nil).to.equal(true)
			expect(def.maxLevel).to.equal(5)
			expect(def.startLevel).to.equal(0)
			for tier, row in Catalog.tiers do
				expect(row.caps.lucky_cat).to.equal(tier)
			end
		end)
	end)

	describe("Lucky Days on the server's clock", function()
		local firstDay = Config.ServerStartDaySeconds
		local cycle = Config.NightLengthSeconds + Config.DayLengthSeconds

		it("numbers the days from 1, a night counting as the day that ended", function()
			expect(Clock.dayAt(-5)).to.equal(1)
			expect(Clock.dayAt(0)).to.equal(1)
			expect(Clock.dayAt(firstDay)).to.equal(1) -- the first night
			expect(Clock.dayAt(firstDay + Config.NightLengthSeconds - 1)).to.equal(1)
			expect(Clock.dayAt(firstDay + Config.NightLengthSeconds)).to.equal(2) -- sunrise
			expect(Clock.dayAt(firstDay + Config.NightLengthSeconds + Config.DayLengthSeconds)).to.equal(
				2
			)
			expect(Clock.dayAt(firstDay + Config.NightLengthSeconds + cycle)).to.equal(3)
			-- day n starts with a "day" phase
			for n = 2, 9 do
				local sunrise = firstDay + Config.NightLengthSeconds + (n - 2) * cycle
				expect(Clock.dayAt(sunrise + 1)).to.equal(n)
				expect((Clock.phaseAt(sunrise + 1))).to.equal("day")
			end
		end)

		it("makes every LuckyDayEvery-th day a Lucky Day", function()
			expect(Config.LuckyDayEvery).to.equal(4)
			for _, n in { 0, 1, 2, 3, 5, 6, 7, 9 } do
				expect(Clock.isLuckyDay(n)).to.equal(false)
			end
			for _, n in { 4, 8, 12 } do
				expect(Clock.isLuckyDay(n)).to.equal(true)
			end
		end)

		it("starts each day at its sunrise, the night before it ending there", function()
			expect(Clock.sunriseOf(1)).to.equal(0)
			for n = 2, 9 do
				local sunrise = Clock.sunriseOf(n)
				expect(Clock.dayAt(sunrise)).to.equal(n)
				expect((Clock.phaseAt(sunrise))).to.equal("day")
				expect(Clock.dayAt(sunrise - 1)).to.equal(n - 1)
				expect((Clock.phaseAt(sunrise - 1))).to.equal("night")
			end
		end)

		it("names the next Lucky Day after this one", function()
			expect(Clock.nextLuckyDay(0)).to.equal(4)
			expect(Clock.nextLuckyDay(1)).to.equal(4)
			expect(Clock.nextLuckyDay(3)).to.equal(4)
			expect(Clock.nextLuckyDay(4)).to.equal(8)
			expect(Clock.nextLuckyDay(7)).to.equal(8)
		end)

		it("words the warning, the banner and a Lucky Day Mythical as the section does", function()
			expect(Luck.DAY_WARNING).to.equal("A Lucky Day starts at sunrise!")
			expect(Luck.DAY_BANNER).to.equal("Lucky Day! Rare cats are twice as likely until night")
			expect(Catching.waveShoutOut("Mythical", "base", "Woods", true)).to.equal(
				"A Mythical cat appeared in the Woods on a Lucky Day!"
			)
			expect(Catching.waveShoutOut("Mythical", "gold", "Park", true)).to.equal(
				"A gold Mythical cat appeared in the Park on a Lucky Day!"
			)
			expect(Catching.waveShoutOut("Mythical", "base", "Woods", false)).to.equal(
				"A Mythical cat appeared in the Woods!"
			)
		end)
	end)

	describe("crates", function()
		it("puts the player's Luck in a plain open's odds", function()
			for _, crate in Catalog.crates do
				if not crate.golden then
					local odds = Crates.oddsFor(crate, 0, 1.5)
					expect(odds :: any).to.deepEqual(Luck.applyMap(crate.odds, 1.5))
					expect(total(odds)).to.be.near(total(crate.odds), 1e-6)
					-- no Luck, or x1: the crate's own table
					expect(Crates.oddsFor(crate, 0)).to.equal(crate.odds)
					expect(Crates.oddsFor(crate, 0, 1)).to.equal(crate.odds)
				end
			end
		end)

		it("leaves the lucky twentieth and the golden crates as they were", function()
			for _, crate in Catalog.crates do
				local lucky = Config.CrateLuckyEvery - 1
				if crate.golden then
					expect(Crates.oddsFor(crate, 0, 2)).to.equal(crate.odds)
				else
					expect(Crates.oddsFor(crate, lucky, 2)).to.equal(Crates.oddsFor(crate, lucky))
				end
			end
		end)

		it("rolls a rarer piece more often with Luck", function()
			local classic = Catalog.getCrate("classic_crate") :: Types.CrateDef
			local function rareShare(playerLuck: number): number
				local hits, steps = 0, 2000
				for i = 0, steps - 1 do
					local decorId = Crates.roll(classic, 0, (i + 0.5) / steps, 0, playerLuck)
					local decor = Catalog.getDecor(decorId) :: any
					if Catalog.rarityRank[decor.rarity] >= Catalog.rarityRank.Epic then
						hits += 1
					end
				end
				return hits / steps
			end
			expect(rareShare(2) > rareShare(1)).to.equal(true)
		end)
	end)

	describe("Luck edges (QA)", function()
		local TOP = { "Epic", "Legendary", "Mythical" }

		-- Every odds table a Luck roll touches in play: the areas' waves and traps (a Lucky Day's LuckyDayWaveLuck),
		-- the bait foods on every bowl and the plain crates (a player's Luck up to LuckMax).
		local function tables(): { { name: string, odds: { [string]: number } } }
			local out = {}
			for _, area in Catalog.areas do
				table.insert(out, { name = area.id .. " wave", odds = area.odds :: any })
				table.insert(out, { name = area.id .. " traps", odds = Catching.rescueOdds(area.odds) :: any })
			end
			for _, lure in Catalog.lures do
				for bowl = 1, #Config.BowlLuck do
					local odds: any = Bait.oddsFor(lure.odds, bowl)
					table.insert(out, { name = lure.id .. " bowl " .. bowl, odds = odds })
				end
			end
			for _, crate in Catalog.crates do
				if not crate.golden then
					table.insert(out, { name = crate.id, odds = crate.odds })
				end
			end
			return out
		end

		it("keeps every table whole and in order as Luck rises: rarer up, Common down, shares kept", function()
			for _, entry in tables() do
				local base = Luck.applyMap(entry.odds, 1)
				local before = base
				for step = 0, math.floor((Config.LuckMax - 1) * 20 + 0.5) do
					local luck = 1 + step / 20
					local odds = Luck.applyMap(entry.odds, luck)
					local where = string.format("%s at x%.2f", entry.name, luck)
					expect(math.abs(total(odds) - total(base)) < 1e-6 or error(where .. ": total moved")).to.equal(true)
					for _, rarity in RARITIES do
						local value = odds[rarity]
						expect(value == value and value >= 0 or error(where .. ": " .. rarity .. " not a chance"))
							.to.equal(true)
						-- a rarity the table never had never appears
						if (entry.odds[rarity] or 0) == 0 then
							expect(value == 0 or error(where .. ": " .. rarity .. " appeared")).to.equal(true)
						end
					end
					for _, rarity in TOP do
						expect(odds[rarity] >= before[rarity] - 1e-9 or error(where .. ": " .. rarity .. " fell"))
							.to.equal(true)
					end
					expect(odds.Common <= before.Common + 1e-9 or error(where .. ": Common rose")).to.equal(true)
					-- Luck multiplies the three alike, so their shares of each other stay as they were
					local top = odds.Epic + odds.Legendary + odds.Mythical
					local baseTop = base.Epic + base.Legendary + base.Mythical
					if baseTop > 0 then
						for _, rarity in TOP do
							local drift = math.abs(odds[rarity] / top - base[rarity] / baseTop)
							expect(drift < 1e-9 or error(where .. ": " .. rarity .. "'s share moved")).to.equal(true)
						end
					end
					before = odds
				end
			end
		end)

		it("gives only pieces a crate holds, at every Luck up to LuckMax", function()
			for _, crate in Catalog.crates do
				local held: { [string]: boolean } = {}
				for _, id in crate.pieces do
					held[id] = true
				end
				for _, luck in { 1, 1.1, 1.5, 2, 2.5, Config.LuckMax } do
					for i = 0, 199 do
						for _, pieceRoll in { 0, 0.5, 0.999999 } do
							local decorId = Crates.roll(crate, 0, (i + 0.5) / 200, pieceRoll, luck)
							local where = string.format("%s gave %s at x%.1f", crate.id, decorId, luck)
							expect(held[decorId] == true or error(where)).to.equal(true)
						end
					end
				end
			end
		end)

		it("is a Luck from x1 to LuckMax for any statue level a save could hold", function()
			for _, level in { 0 / 0, -3, 0.5, 2.7, 5, 6, 1e9, math.huge, -math.huge, "5" :: any, true :: any } do
				for _, luckyDay in { false, true } do
					local profile = fresh()
					profile.upgradeLevels[Luck.UPGRADE] = level
					local luck = Luck.of(profile, NOW, luckyDay)
					local where = string.format(
						"level %s, Lucky Day %s: x%s",
						tostring(level),
						tostring(luckyDay),
						tostring(luck)
					)
					expect(luck == luck and luck >= 1 and luck <= Config.LuckMax or error(where)).to.equal(true)
				end
			end
			-- a broken level counts as none
			local profile = fresh()
			profile.upgradeLevels[Luck.UPGRADE] = 0 / 0
			expect(Luck.of(profile, NOW, false)).to.equal(1)
		end)

		it("reads every Luck the sources can add up to back as the same number", function()
			for level = 0, 5 do
				for _, potion in { false, true } do
					for _, luckyDay in { false, true } do
						local profile = fresh()
						profile.upgradeLevels[Luck.UPGRADE] = level
						if potion then
							profile.buffs[Potions.LUCKY] = 600
						end
						local luck = Luck.of(profile, NOW, luckyDay)
						local text = Luck.text(luck)
						expect(string.match(text, "^Luck x%d%.%d%d?$") ~= nil or error(text)).to.equal(true)
						expect(math.abs((tonumber(string.sub(text, 7)) :: number) - luck) < 1e-9 or error(text))
							.to.equal(true)
					end
				end
			end
		end)

		it("turns the day number over exactly at sunrise, and a Lucky Day is one whole day phase", function()
			local cycle = Config.DayLengthSeconds + Config.NightLengthSeconds
			local first = Config.ServerStartDaySeconds + Config.NightLengthSeconds -- day 2's sunrise
			-- at every sunrise, a hair before is the night of the day that ended and a hair after the new day
			for k = 0, 400 do
				local sunrise = first + k * cycle
				for _, t in { sunrise - 1e-6, sunrise - sunrise * 2 ^ -50, sunrise, sunrise + 1e-6 } do
					local phase = Clock.phaseAt(t)
					local day = Clock.dayAt(t)
					local where = string.format("t %.9f (sunrise %d): %s, day %d", t, k + 2, phase, day)
					if phase == "day" then
						expect(day == k + 2 or error(where)).to.equal(true)
					else
						expect(day == k + 1 or error(where)).to.equal(true)
					end
				end
			end
			-- eight days and nights at half a second: Lucky only in the day phase of days 4 and 8, whole each time
			local lucky, lastDay = 0, 1
			for i = 0, (Config.ServerStartDaySeconds + 8 * cycle) * 2 - 1 do
				local t = i / 2
				local day = Clock.dayAt(t)
				expect(day >= lastDay or error("the day number went back at " .. t)).to.equal(true)
				lastDay = day
				if Clock.phaseAt(t) == "day" and Clock.isLuckyDay(day) then
					lucky += 0.5
				end
			end
			expect(lucky).to.equal(2 * Config.DayLengthSeconds)
			-- the warning before a Lucky Day's sunrise comes in the night before it
			local warn = Config.LuckyDayWarnSeconds
			expect(warn > 0 and warn <= Config.NightLengthSeconds).to.equal(true)
		end)
	end)
end
