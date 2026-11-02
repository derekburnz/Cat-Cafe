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
end
