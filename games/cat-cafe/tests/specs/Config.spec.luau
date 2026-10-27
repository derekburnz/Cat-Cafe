--!strict
-- Config.luau against the tuning table in data-model.md section 17 (DesignParity), design v0.3.1.
-- `expected` holds what is built: v0.2 values the code still uses plus the v0.3 changes whose feature has landed.
-- `pending` lists the v0.3 values still to come, by feature; move a row into `expected` when its feature lands
-- (and delete the v0.2 row it replaces). World layout numbers in Config.World are the engineer's.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local Catalog = require(Shared.Catalog)
	local Config = require(Shared.Config)

	local expected: { [string]: any } = {
		ServerPlayers = 8,
		StartCoins = 50,
		FavoriteMultiplier = 1.5,
		TableBonus = 0.10,
		EspressoBonus = 0.15,
		OfflineRate = 0.25,
		OfflineCapSeconds = 3600,
		AutosaveSeconds = 60,
		-- the clock and night waves (section 9, v0.3 in F23): no trickle spawns, so SpawnIntervalSeconds and
		-- MaxStraysPerArea are gone, and the wave size lives per area in Catalog.areas (Catalog.spec)
		DayLengthSeconds = 300,
		NightLengthSeconds = 90, -- v0.9 (F66): a short night between hunts
		ServerStartDaySeconds = 300, -- v0.9: a new server opens at sunrise
		DuskWarningSeconds = 15,
		NightSweepSeconds = 2,
		StrayDespawnSeconds = 120,
		-- rescue minigames (F27, section 10b); RescueBarSpeed and RescueZoneWidth are tables, checked below
		RescueSpawnChance = 0.6,
		RescueMinStuck = 1,
		RescueTolerance = 0.03,
		RescuePatience = 3,
		RescueRetrySeconds = 3,
		RescueSelfRetrySeconds = 6,
		RescueAttemptMaxSeconds = 15,
		GoldChanceRescue = 0.10,
		RescuedTipsMultiplier = 1.0, -- v0.3 (F22): a rescue pays no more; its reward is the gold chance
		GrabRangeStuds = 10,
		CatchHoldSeconds = 0.5, -- Derek 2026-10-27: hold E to start a catch or a rescue
		GrabRetrySeconds = 2,
		-- v0.4 catching stakes (F34, section 10 step 5); v0.5 the chase after a miss (F40)
		StrayFleeSpeed = 26,
		StrayRestSeconds = 1.5,
		StraySelfRetrySeconds = 1, -- v0.5.1 (S44)
		PerfectCharmBonus = 4,
		PurrfectCharmMultiplier = 2,
		AutoPressFlagRate = 0.95,
		AutoPressClearRate = 0.85,
		-- v0.3 net circles (F26, section 10)
		CircleLeadInSeconds = 0.6,
		CircleGapMin = 0.40,
		CircleGapMax = 0.75,
		CircleScorePerfect = 1.0,
		CircleScoreGood = 0.5,
		CatchLatencyCapSeconds = 0.15,
		-- the bait bowl (F28, section 8)
		LureWaitSeconds = 600,
		BaitBowlRangeStuds = 12,
		BaitResolveRangeStuds = 20,
		GoldChanceBait = 0.05, -- v0.5 F42 (was 0.02)
		GoldChanceNet = 0.05, -- F30, v0.5 F42 (was 0.02)
		CarryWalkSpeed = 16, -- v0.4
		CheckInRangeStuds = 8,
		CustomerSpawnSeconds = 6,
		CustomerStayMin = 20,
		CustomerStayMax = 40,
		RemoteRateLimitPerSecond = 10,
		AnnounceMinRarity = "Epic",
		GrabCooldownSeconds = 2,
		TravelCooldownSeconds = 3, -- v0.4 (F19)
		SyncIntervalSeconds = 10,
		NormalWalkSpeed = 20, -- v0.4
		StrayWanderRadius = 5,
		StrayWanderSpeed = 3,
		CustomerCoinPopSeconds = 3,
		CustomerWalkSpeed = 7,
		SeatsPerTable = 2,
		MaxIdLength = 40,
		TutorialGuaranteedStrayStep = 2,
		-- cat stats (data-model section 4b)
		CatMaxLevel = 10,
		CatLevelBonus = 0.05,
		CatXpBase = 60,
		CatXpPerSecondPlaced = 1,
		CharmSpread = 0.20,
		GoldMultiplier = 1.5, -- v0.3 (F22)
		-- the night dealer (F32, section 8b)
		DealerRangeStuds = 12,
		DealerWindowSeconds = 600,
		-- night income and rich customers (F31, sections 11 and 12)
		NightIncomeMultiplier = 0.6,
		RichCheckSeconds = 60,
		RichChance = 0.15,
		RichTipSeconds = 45,
		RichTipStaySeconds = 90,
		-- the Spin Wheel station (F49, section 11c, design v0.6)
		SpinStationRange = 14,
		SpinCooldownSeconds = 4,
		SpinBankCap = 20,
		-- golden fish and crates (F52, F53, golden-fish.md section 8)
		TipJarStep12Fish = 5,
		CrateLuckyEvery = 20,
		CratePrice = 60,
		FishMarketRange = 14,
		CrateOpenCooldownSeconds = 2,
		DecorIndexBonus = 0.05,
		GoldenEspressoBonus = 0.05, -- section 3: +5% tips per Golden Espresso level
		BigBowlLureWaitSeconds = 480, -- section 3: the Big Bowl takes the bait wait from 10 to 8 minutes
		DecorIndexHalfFish = 25, -- F54: a Decor Index page's decor5 prize
		GoldLuckMax = 1.5, -- F54 (v0.10): the cap on summed Index gold luck
		BaitSpeedMax = 0.5, -- F54 (v0.10): the cap on summed Index bait speed
		-- codes (F65, section 11d, v0.10 circle and group codes)
		CodesCatRange = 12,
		CodesCircleRadius = 4,
		CodeMaxLength = 20,
		CodeWrongLimit = 5,
		CodeLockSeconds = 60,
		GroupId = 0,
		-- Shove (F29 and v0.5 F41, section 10c; v0.5 cooldowns 8 and 20, v0.5.1 target immunity S45; v0.8 F56)
		BumpEnabled = true,
		BumpRangeStuds = 6,
		BumpChance = 1.0, -- v0.8 F56: a shove always drops the cat
		BumpGraceSeconds = 3,
		BumpSafeRadiusStuds = 15,
		BumpCooldownSeconds = 8,
		BumpSameTargetSeconds = 20,
		ShoveKnockbackStuds = 10,
		ShoveTargetImmuneSeconds = 4,
		-- the Tackle (v0.11 F74, section 10c)
		TackleLungeStuds = 12,
		TackleLungeSeconds = 0.35,
		TackleHitGraceSeconds = 0.25,
		TackleHitRadiusStuds = 3,
		TackleHitSlackStuds = 1.5,
		TackleCooldownSeconds = 8,
		TackleHitRecoverSeconds = 0.4,
		TackleMissRecoverSeconds = 1.2,
		TackledDownSeconds = 0.8,
		-- naming cats (F33, section 4)
		CatNameMaxLength = 20,
		RenameCooldownSeconds = 5,
	}

	-- v0.3 section 17 values not built yet: name -> { value, feature }
	local pending: { [string]: { any } } = {}

	describe("data-model section 17 constants", function()
		for name, value in pairs(expected) do
			it(name .. " = " .. tostring(value), function()
				local actual = (Config :: any)[name]
				expect(actual).to.be.ok()
				if type(value) == "number" then
					expect(actual).to.be.near(value, 1e-9)
				else
					expect(actual).to.equal(value)
				end
			end)
		end

		for name, row in pairs(pending) do
			it(string.format("%s = %s (%s)", name, tostring(row[1]), row[2]))
		end

		it(
			"RenovateBonus is gone: tiers replace rebirth and nothing resets (section 5b)",
			function()
				expect((Config :: any).RenovateBonus).never.to.be.ok()
			end
		)

		it("has no extra top level tuning numbers the doc does not know about", function()
			-- LureReserveSeconds: the doc now says a lured stray is reserved until despawn, so the constant is optional.
			local known = {
				World = true,
				NetWindows = true, -- a table, checked below
				CharmStarOdds = true, -- a table, checked below
				RescueBarSpeed = true, -- a table, checked below
				RescueZoneWidth = true, -- a table, checked below
				ProfileStoreName = true,
				ProfileKeyPrefix = true,
				GrabRateLimitSeconds = true,
				LureReserveSeconds = true,
				RichTipRangeStuds = true, -- sections 12 and 15: ClaimRichTip within 12 studs of RichTipAnchor
				FishFirstCatch = true, -- a table, checked below
				FishRepeatCatch = true, -- a table, checked below
				FishRankUp = true, -- a table, checked below
				CratePieceBonus = true, -- a table, checked below
				CrateDuplicateRefund = true, -- a table, checked below
				DecorSpots = true, -- a table, checked below
				CodeWrongWindowSeconds = true, -- section 11d: "5 wrong codes in a minute"
				GroupCheckSeconds = true, -- section 11d: IsInGroup "cached per player for 60 s"
			}
			for name, value in pairs(Config :: any) do
				if expected[name] == nil and not known[name] then
					error(
						string.format(
							"Config.%s = %s is not in data-model section 17; add it to the doc or remove it",
							name,
							tostring(value)
						)
					)
				end
			end
		end)
	end)

	describe("internal consistency", function()
		it("golden fish by rarity and rank (F52, golden-fish.md section 2)", function()
			expect(Config.FishFirstCatch :: any).to.deepEqual({ Common = 1, Rare = 3, Epic = 8, Legendary = 20, Mythical = 40 })
			expect(Config.FishRepeatCatch :: any).to.deepEqual({ Epic = 1, Legendary = 3, Mythical = 8 })
			expect(Config.FishRankUp :: any).to.deepEqual({ 10, 25, 50, 100 })
		end)

		it("crate bonuses, refunds and decor spots (F53, golden-fish.md sections 4 and 8)", function()
			expect(Config.CratePieceBonus :: any).to.deepEqual({
				Common = 0.02,
				Rare = 0.04,
				Epic = 0.08,
				Legendary = 0.15,
				Mythical = 0.25,
			})
			expect(Config.CrateDuplicateRefund :: any).to.deepEqual({
				Common = 10,
				Rare = 20,
				Epic = 40,
				Legendary = 80,
				Mythical = 150,
			})
			expect(Config.DecorSpots :: any).to.deepEqual({ 2, 3, 4, 5, 6 })
			expect(Config.BigBowlLureWaitSeconds < Config.LureWaitSeconds).to.equal(true)
		end)

		it("NetWindows matches the section 10 net table, levels 0 to 3", function()
			local expectedWindows = {
				[0] = { perfect = 0.045, good = 0.11, jitter = 0.30 },
				[1] = { perfect = 0.055, good = 0.13, jitter = 0.20 },
				[2] = { perfect = 0.065, good = 0.155, jitter = 0.10 },
				[3] = { perfect = 0.08, good = 0.18, jitter = 0 },
			}
			local levels = 0
			for level, row in pairs(Config.NetWindows) do
				levels += 1
				local want = expectedWindows[level]
				expect(want).to.be.ok()
				assert(want)
				expect(row.perfect).to.be.near(want.perfect, 1e-9)
				expect(row.good).to.be.near(want.good, 1e-9)
				expect(row.jitter).to.be.near(want.jitter, 1e-9)
			end
			expect(levels).to.equal(4)
			local net = Catalog.getUpgrade("net")
			assert(net)
			expect(net.maxLevel).to.equal(3)
		end)

		-- Holds through any retune of the numbers above (from the engineer's spec, 067b953).
		it("net windows: Perfect inside Good, and a better net is never harder", function()
			for level = 0, 3 do
				local windows = Config.NetWindows[level]
				expect(windows.perfect < windows.good).to.equal(true)
				if level > 0 then
					local previous = Config.NetWindows[level - 1]
					expect(windows.perfect >= previous.perfect).to.equal(true)
					expect(windows.good >= previous.good).to.equal(true)
					expect(windows.jitter <= previous.jitter).to.equal(true)
				end
			end
		end)

		it("S24: CircleGapMin is above the widest good window plus the latency cap", function()
			-- Otherwise a late press for one circle could land on the next. Widening good means raising the gap.
			local widest = 0
			for _, row in pairs(Config.NetWindows) do
				widest = math.max(widest, row.good)
			end
			expect(Config.CircleGapMin > widest + Config.CatchLatencyCapSeconds).to.equal(true)
			expect(Config.CircleGapMin <= Config.CircleGapMax).to.equal(true)
		end)

		it("circle scores: Perfect beats Good beats a miss, and Perfect is a sure catch", function()
			expect(Config.CircleScorePerfect).to.equal(1)
			expect(Config.CircleScoreGood > 0 and Config.CircleScoreGood < 1).to.equal(true)
		end)

		it("v0.5 chase: a missed stray outruns a walking player and the one who missed waits a little longer", function()
			expect(Config.StrayFleeSpeed > Config.NormalWalkSpeed).to.equal(true)
			expect(Config.StrayRestSeconds > 0).to.equal(true)
			expect(Config.StraySelfRetrySeconds > 0).to.equal(true)
		end)

		it("v0.5 chase: the v0.4 wary wait and jump back are gone (F40)", function()
			local config = Config :: any
			expect(config.StrayWarySeconds).never.to.be.ok()
			expect(config.StrayJumpBackMin).never.to.be.ok()
			expect(config.StrayJumpBackMax).never.to.be.ok()
		end)

		it("v0.5 night: the cafe closes, so the night owls' spawn time is gone (F44)", function()
			expect((Config :: any).CustomerSpawnSecondsNight).never.to.be.ok()
			expect(Config.NightIncomeMultiplier).to.equal(0.6)
		end)

		it("v0.4 stakes: the scripted-press flag clears well below where it sets", function()
			expect(Config.AutoPressClearRate > 0).to.equal(true)
			expect(Config.AutoPressClearRate < Config.AutoPressFlagRate).to.equal(true)
			expect(Config.AutoPressFlagRate < 1).to.equal(true)
		end)

		it("v0.4 stakes: a Purrfect Mythical catch adds charm well inside the 100 cap", function()
			local most = Config.PerfectCharmBonus
				* Catalog.rarities.Mythical.circles
				* Config.PurrfectCharmMultiplier
			expect(most).to.equal(40)
			expect(most < 100).to.equal(true)
		end)

		it("carry speed is about 80% of normal walk speed (features F07)", function()
			expect(Config.CarryWalkSpeed / Config.NormalWalkSpeed).to.be.near(0.8, 0.02)
		end)

		it(
			"the lock covers the late-press allowance, so nobody can take a stray mid-catch",
			function()
				-- The lock runs to the last target + good + 1 s; the last press is accepted to target + good + cap.
				expect(Config.CatchLatencyCapSeconds < 1).to.equal(true)
			end
		)

		it(
			"the v0.1 names are gone (night waves replace the trickle, the net replaces gloves)",
			function()
				local config = Config :: any
				expect(config.SpawnIntervalSeconds).never.to.be.ok()
				expect(config.MaxStraysPerArea).never.to.be.ok()
				expect(config.GlovesBonus).never.to.be.ok()
			end
		)

		it(
			"v0.3: the hold ring and flat chance constants are gone (F26, section 17 Removed)",
			function()
				local config = Config :: any
				for _, name in ipairs({
					"GrabHoldSeconds",
					"GrabMinHoldSeconds",
					"GrabLockSeconds",
					"NetBonus",
					"LureBonus",
					"RingBonusPerfect",
					"RingBonusGood",
					"RingPerfectWindow",
					"RingGoodWindow",
					"CatchChanceMin",
					"CatchChanceMax",
					"RenovateBonus",
				}) do
					expect(config[name]).never.to.be.ok()
				end
			end
		)

		it("the v0.2 rescue hold's constants are gone (F27)", function()
			local config = Config :: any
			expect(config.RescueHoldSeconds).never.to.be.ok()
			expect(config.RescueLockSeconds).never.to.be.ok()
			expect(config.RingLatencyGraceSeconds).never.to.be.ok()
		end)
		it("LureDespawnSeconds and LureReserveSeconds are gone (F28)", function()
			local config = Config :: any
			expect(config.LureDespawnSeconds).never.to.be.ok()
			expect(config.LureReserveSeconds).never.to.be.ok()
		end)

		it(
			"clock (v0.9, F66): a new server opens at sunrise, nights are short, the warning fits in the day",
			function()
				expect(Config.ServerStartDaySeconds > 0).to.equal(true)
				expect(Config.ServerStartDaySeconds <= Config.DayLengthSeconds).to.equal(true)
				expect(Config.NightLengthSeconds > 0).to.equal(true)
				expect(Config.NightLengthSeconds < Config.DayLengthSeconds).to.equal(true)
				expect(Config.DuskWarningSeconds < Config.ServerStartDaySeconds).to.equal(true)
				expect(Config.NightSweepSeconds > 0).to.equal(true)
				expect(Config.NightSweepSeconds < Config.NightLengthSeconds).to.equal(true)
				-- the loop test still sees one full night inside its ten minutes
				expect(Config.ServerStartDaySeconds + Config.NightLengthSeconds <= 600).to.equal(
					true
				)
			end
		)

		it(
			"rescue: the player who failed waits longer, the chances are probabilities, a rescue pays no more",
			function()
				expect(Config.RescueSelfRetrySeconds > Config.RescueRetrySeconds).to.equal(true)
				expect(Config.RescueSpawnChance > 0 and Config.RescueSpawnChance <= 1).to.equal(
					true
				)
				expect(Config.GoldChanceRescue > 0 and Config.GoldChanceRescue < 1).to.equal(true)
				expect(Config.RescuedTipsMultiplier).to.equal(1)
			end
		)

		it("the rescue bar matches the section 10b table: rarer is faster and narrower", function()
			local rows = {
				Common = { 0.8, 0.30 },
				Rare = { 1.0, 0.24 },
				Epic = { 1.2, 0.19 },
				Legendary = { 1.4, 0.15 },
				Mythical = { 1.6, 0.12 },
			}
			local previous: { number }? = nil
			for _, rarity in Catalog.rarityOrder do
				local row = rows[rarity]
				expect(Config.RescueBarSpeed[rarity]).to.be.near(row[1], 1e-9)
				expect(Config.RescueZoneWidth[rarity]).to.be.near(row[2], 1e-9)
				if previous ~= nil then
					expect(row[1] > previous[1]).to.equal(true)
					expect(row[2] < previous[2]).to.equal(true)
				end
				previous = row
			end
		end)

		it("bait bowl: the card reaches further than Use, and gold is a probability", function()
			expect(Config.BaitResolveRangeStuds >= Config.BaitBowlRangeStuds).to.equal(true)
			expect(Config.GoldChanceBait > 0 and Config.GoldChanceBait < 1).to.equal(true)
		end)

		it(
			"CharmStarOdds has five shares that sum to 100 (pinned to rollCharm in CatStats.spec)",
			function()
				expect(#Config.CharmStarOdds).to.equal(5)
				local total = 0
				for _, share in Config.CharmStarOdds do
					total += share
				end
				expect(total).to.be.near(100, 1e-6)
			end
		)

		it("customers never stay a negative or zero time", function()
			expect(Config.CustomerStayMin > 0).to.equal(true)
			expect(Config.CustomerStayMin <= Config.CustomerStayMax).to.equal(true)
		end)

		it("the grab remote limit matches the grab cooldown", function()
			expect(Config.GrabRateLimitSeconds).to.equal(Config.GrabCooldownSeconds)
		end)

		it("data store names are set and ids are bounded", function()
			expect(#Config.ProfileStoreName > 0).to.equal(true)
			expect(#Config.ProfileKeyPrefix > 0).to.equal(true)
			expect(Config.MaxIdLength >= 20).to.equal(true)
		end)
	end)
end
