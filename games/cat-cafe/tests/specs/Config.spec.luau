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
		-- F95 (economy-ladder.md sections 5 and 7): half pay for up to 8 hours away, the Long Nap pass full pay for 16
		OfflineRate = 0.5,
		OfflineCapSeconds = 28800,
		OfflineRatePass = 1.0,
		OfflineCapPassSeconds = 57600,
		LongNapPassId = 2064345084, -- Tools-Agent made it 2026-11-02 (off sale until launch)
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
		StraySelfRetrySeconds = 3, -- v0.5.1 (S44); v0.8 F57: the first of the steps {3, 6, 10}
		StrayMissStreakResetSeconds = 60, -- v0.8 F57
		StartledWalkSpeed = 12, -- v0.8 F57
		StartledSeconds = 2, -- v0.8 F57
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
		LureWaitSecondsNight = 300, -- F60: night bait, half the wait
		BaitBowlRangeStuds = 12,
		GoldChanceBait = 0.05, -- v0.5 F42 (was 0.02)
		GoldChanceNet = 0.05, -- F30, v0.5 F42 (was 0.02)
		CarryWalkSpeed = 16, -- v0.4
		CatchBurstRadiusStuds = 10, -- v0.8 F55
		CatchBurstStuds = 8,
		CatchRushWalkSpeed = 24,
		CatchRushSeconds = 10, -- Derek's notes: longer for the bigger areas (was 5)
		CheckInRangeStuds = 10,
		CustomerSpawnSeconds = 6,
		CustomerStayMin = 20,
		CustomerStayMax = 40,
		RemoteRateLimitPerSecond = 10,
		AnnounceMinRarity = "Epic",
		GrabCooldownSeconds = 2,
		TravelCooldownSeconds = 3, -- v0.4 (F19)
		SyncIntervalSeconds = 10,
		NormalWalkSpeed = 20, -- v0.4
		CameraMaxZoomStuds = 60, -- Derek 2026-11-02, the zoom card
		StrayWanderRadius = 5,
		StrayWanderSpeed = 3,
		CustomerCoinPopSeconds = 3,
		CustomerWalkSpeed = 7,
		SeatsPerTable = 2,
		MaxIdLength = 40,
		TutorialGuaranteedStrayStep = 2,
		-- F87 (easy-start.md section 6); IntroAutoPlay is false, checked below
		TutorialShrinkSeconds = 1.6,
		TutorialWindowScale = 2,
		TutorialRetrySeconds = 1.0,
		StuckNudgeSeconds = 40,
		StuckHelpSeconds = 90,
		TipGapSeconds = 60,
		TipCutMaxSeconds = 4,
		FeedbackAskMinutes = 12,
		TipStartSeconds = 10,
		FeedbackSessionLimit = 5,
		-- cat stats (data-model section 4b)
		CatMaxLevel = 50, -- v0.12 (F75)
		CatLevelBonus = 0.02,
		CatXpBase = 120,
		CatXpPerSecondPlaced = 1,
		CatXpFavoriteMultiplier = 1.5,
		CatXpPerSecondResting = 0.25,
		CharmSpread = 0.20,
		GoldMultiplier = 1.5, -- v0.3 (F22)
		-- the night dealer (F32, section 8b)
		DealerRangeStuds = 12,
		FreshCatchWindowSeconds = 300, -- F94 (rewards-and-shops.md section 3): the Fresh Catch shelf rolls every 5 minutes
		-- night income and rich customers (F31, sections 11 and 12)
		NightIncomeMultiplier = 1, -- F60: full pay at night (0.6 until v0.8)
		RichCheckSeconds = 60,
		RichChance = 0.10, -- F61: was 0.15
		RichTipSeconds = 120, -- F61: was 45
		TipPileSeconds = 30, -- F61: tip piles (section 12)
		TipPileRateSeconds = 6,
		TipPilesMax = 6,
		TipPileShowSeconds = 90, -- F97 section 1: a paid pile shows this long
		RichTipStaySeconds = 90,
		-- the Mystery Visitor and potions (F64, section 12b)
		MysteryCheckSeconds = 120,
		MysteryChance = 0.08,
		MysteryStaySeconds = 120,
		MysteryGiftKeepSeconds = 600,
		PotionMaxMinutes = 1440, -- F95 (economy-ladder.md section 6b): potions stack to 24 hours
		-- quests and achievements and their potions (F73, quests.md section 6)
		TimedTipsMax = 1.0,
		QuestDailyCount = 5,
		QuestWeeklyCount = 3,
		QuestWeekOffsetSeconds = 345600,
		QuestRollCheckSeconds = 60,
		QuestClaimAll = true,
		IndexClaimAll = true,
		TipJarClaimAll = true,
		-- bedtime (F79, sections 12c and 17)
		CafeCatWalkSpeed = 6,
		BedtimeStaggerSeconds = 0.3,
		BedtimeStretchSeconds = 1,
		HopSeconds = 0.45,
		HopMaxRise = 2.6,
		BedtimeTimeoutSeconds = 15,
		-- the Cat Collector (F63, section 12b); CollectorValue is a table, checked in Collector.spec
		CollectorCheckSeconds = 120,
		CollectorChance = 0.12,
		CollectorStaySeconds = 180,
		CollectorGoldMultiplier = 3,
		CollectorRollMin = 0.8,
		CollectorRollMax = 1.5,
		-- the Spin Wheel station (F49, section 11c, design v0.6)
		SpinStationRange = 14,
		SpinCooldownSeconds = 4,
		SpinBankCap = 20,
		-- golden fish and crates (F52, F53, golden-fish.md section 8)
		CrateLuckyEvery = 20,
		CratePrice = 60,
		FishMarketRange = 14,
		CrateOpenCooldownSeconds = 2,
		DecorIndexBonus = 0.05,
		DecorEquipBest = true,
		ResetSaveGroupRank = 254, -- testers' Reset my save once the game is group-owned
		GoldenEspressoBonus = 0.05, -- section 3: +5% tips per Golden Espresso level
		BigBowlWaitCutSeconds = 120, -- F95 (economy-ladder.md section 6b): the Big Bowl takes 2 minutes off
		KeepUpStepsBehind = 1, -- section 17 (v0.13.16, F86): an older Legendary or Mythical earns one area behind
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
		StarterCatRangeStuds = 12, -- F96 (starter-cat.md section 4)
		StarterCatTutorialStep = 5,
		StarterCatCharm = 60,
		-- Luck and Lucky Days (F88, luck-and-rare-moments.md 1f)
		LuckPerStatueLevel = 0.1,
		LuckMax = 3,
		LuckyPotionLuck = 0.5,
		LuckyDayEvery = 4,
		LuckyDayWaveLuck = 2,
		LuckyDayPlayerLuck = 0.5,
		LuckyDayWarnSeconds = 15,
		-- Pals (F92, playing-together.md 6)
		PalTipBonus = 0.10,
		PalTipBonusMax = 0.15,
		TeamRescueRangeStuds = 10,
		TeamRescueExtraSeconds = 5,
		HelperTipSeconds = 60,
		TeamRescueTipCooldown = 120,
		-- Leaderboards (F98, leaderboards.md 5)
		LeaderboardWrites = true,
		LeaderboardWriteSeconds = 300,
		LeaderboardRefreshSeconds = 120,
		LeaderboardSize = 50,
		LeaderboardBoardRows = 10,
		LeaderboardRateMax = 10000000,
		LeaderboardCrownRank = 10,
		LeaderboardFaceSwapSeconds = 15,
		-- The crate reel (F103, crate-reel.md 4)
		CrateReelTiles = 40,
		CrateReelLandingTile = 34,
		CrateReelProtectFrom = 26,
		CrateReelProtectTo = 37,
		CrateReelTopSpeed = 15,
		CrateReelRampSeconds = 0.3,
		CrateReelStopSeconds = 0.8,
		CrateReelHoldSeconds = 0.25,
		RainbowChanceNet = 0.005, -- F99 (rainbow-coat.md section 5)
		RainbowChanceBait = 0.005,
		RainbowChanceRescue = 0.01,
		RainbowMultiplier = 3,
		RainbowLuckMax = 1.0,
		CollectorRainbowMultiplier = 10,
		RainbowAnimateMax = 10,
		RainbowSpawnToastSeconds = 60,
		FishFirstRainbowMultiplier = 5, -- F99 section 1: a first rainbow pays five first catches
		-- F102 (trading.md section 6)
		TradeMinTier = 3,
		TradeMaxCats = 9,
		TradeCountdownSeconds = 5,
		TradeLopsidedRatio = 3,
		TradeConfirmWaitSeconds = 2,
		TradeRequestSeconds = 20,
		TradeReaskSeconds = 60,
		TradeCooldownSeconds = 10,
		TradesPerDay = 50,
		TradeFlagCheckSeconds = 60,
		TradeLogMax = 20,
		TradeIdsMax = 100,
		PicnicEverySeconds = 21600, -- F100 (camp-extras.md section 4); LostFoundTable is checked in CampExtras.spec
		PicnicHold = 2,
		PicnicPotion = "tip_potion", -- Design-Agent 11-02: one 10 minute Money Potion a fill, not a 15 minute one
		YardSaleCratePrice = 40,
		PondFishPerStep = 2,
		PondStepSeconds = 1800,
		PondHold = 24,
		LostFoundHold = 3,
		CampExtraRangeStuds = 8,
		RallyStartWeekday = 6, -- F101 (rescue-rally.md section 5); RallyPoints is checked in Rally.spec
		RallyHours = 48,
		RallyPointsPerPlayer = 30,
		RallyMinPlayers = 3,
		RallyMinPoints = 3,
		RallyMaxLaps = 4,
		RallyStateSeconds = 0.5,
		-- Shove (F29 and v0.5 F41, section 10c; v0.5 same target cooldown 20, v0.5.1 target immunity S45; v0.8 F56)
		BumpEnabled = true,
		BumpChance = 1.0, -- v0.8 F56: a shove always drops the cat
		BumpGraceSeconds = 3,
		BumpSafeRadiusStuds = 15,
		BumpSameTargetSeconds = 20,
		ShoveKnockbackStuds = 10,
		ShoveTargetImmuneSeconds = 4,
		-- a dropped cat walks home (v0.10 F67, section 10c)
		DropReturnWalkSpeed = 8,
		DropHomeRadiusStuds = 2,
		DropReturnMaxSeconds = 60,
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
		-- the Cat Cannon (F84, section 17 v0.13.17)
		CannonLaunchSeconds = 4.0,
		CannonTeleportAtSeconds = 2.6,
		CannonCloudsAt = 2.0,
		CannonTouchdownAt = 3.5,
		CannonCooldownSeconds = 3,
		CloudHopSeconds = 1.6,
		CloudHopMoveAtSeconds = 0.6,
		-- naming cats (F33, section 4)
		CatNameMaxLength = 20,
		RenameCooldownSeconds = 5,
		-- the net swing and rescue rework (F93, catch-rework.md section 5)
		CircleJitter = 0.10,
		NetSwingCooldown = 0.8,
		NetSmackDelay = 0.22,
		NetReachStuds = 7,
		NetSlackStuds = 1.5,
		NetArcDegrees = 60,
		NetMissHopStuds = 12,
		NetMissHopShare = 0.25,
		RescueSpeedUpPerHit = 0.08,
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

		it("FoodTierPriceFactor = 1, 1, 4, 8, 16 by tier (F97, notes-10-28-to-10-30.md section 3)", function()
			expect(Config.FoodTierPriceFactor :: any).to.deepEqual({ 1, 1, 4, 8, 16 })
		end)

		it("IntroAutoPlay = false: the intro waits for the Tutorial tile (F87, easy-start.md section 2a)", function()
			expect(Config.IntroAutoPlay).to.equal(false)
		end)

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
				IntroAutoPlay = true, -- false, checked below
				RichTipRangeStuds = true, -- sections 12 and 15: ClaimRichTip within 12 studs of RichTipAnchor
				WaveMinRareRerollOdds = true, -- a table, checked in Catching.spec (F97 section 7)
				FoodTierPriceFactor = true, -- a table, checked below (F97 section 3)
				FishFirstCatch = true, -- a table, checked below
				FishRepeatCatch = true, -- a table, checked below
				FishRankUp = true, -- a table, checked below
				CratePieceBonus = true, -- a table, checked below
				FreshCatchAmountWeights = true, -- a table, checked in FreshCatch.spec
				CrateDuplicateRefund = true, -- a table, checked below
				DecorSpots = true, -- a table, checked below
				CodeWrongWindowSeconds = true, -- section 11d: "5 wrong codes in a minute"
				GroupCheckSeconds = true, -- section 11d: IsInGroup "cached per player for 60 s"
				StraySpawnSpacingStuds = true, -- Derek 22:38: strays spawn spread out; the designer logs it in section 17
				MysteryRangeStuds = true, -- sections 12b and 15: OpenMysteryGift "within 12 studs"
				CollectorValue = true, -- section 17's "1, 3, 8, 20, 50 by rarity", checked in Collector.spec
				CollectorRangeStuds = true, -- section 12b: his card opens "within 12 studs"
				TipPotionBonus = true, -- section 12b's potion table: "+25% tips"
				SwiftPotionSpeed = true, -- section 12b's potion table: "+4 walk and carry speed"
				LuckyPotionGoldScale = true, -- section 12b's potion table: "double the chance"
				StraySelfRetrySteps = true, -- section 17's StraySelfRetrySeconds {3, 6, 10}, checked below
				BowlWaitSeconds = true, -- a table, checked below (F82)
				BowlLuck = true, -- a table, checked below (F82)
				KeepUpRarities = true, -- F95: empty (was section 17's "Legendary, Mythical"), checked below
				MoneyPassIds = true, -- F95 (economy-ladder.md section 7): a table, checked below
				ExtraSlotPassIds = true, -- F95 (economy-ladder.md section 7): a table, checked below
				LostFoundTable = true, -- F100 (camp-extras.md section 2): a table, checked in CampExtras.spec
				RallyPoints = true, -- F101 (rescue-rally.md section 2): a table, checked in Rally.spec
				RallyForce = true, -- F101: false, checked in Rally.spec (a false value reads as missing above)
				RescueTreeCircle = true, -- Derek 2026-11-03: false, checked in Rescue.spec (a false value reads as missing)
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
			expect(Config.FishFirstCatch :: any).to.deepEqual({
				Common = 1,
				Rare = 3,
				Epic = 8,
				Legendary = 20,
				Mythical = 40,
			})
			expect(Config.FishRepeatCatch :: any).to.deepEqual({
				Epic = 1,
				Legendary = 3,
				Mythical = 8,
			})
			expect(Config.FishRankUp :: any).to.deepEqual({ 10, 25, 50, 100 })
		end)

		it(
			"crate bonuses, refunds and decor spots (F53, golden-fish.md sections 4 and 8)",
			function()
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
			end
		)

		it("F95's pass ids and keep up (economy-ladder.md section 7)", function()
			-- the ids Tools-Agent made on 2026-11-02 (tools/opencloud/passes.json); no extra slot pass yet, which keeps
			-- its effect off
			expect(Config.MoneyPassIds :: any).to.deepEqual({ [2] = 2064604577, [3] = 2064670602, [4] = 2064357148 })
			expect(Config.ExtraSlotPassIds :: any).to.deepEqual({})
			local ids: { [number]: boolean } = { [Config.LongNapPassId] = true }
			for _, id in Config.MoneyPassIds do
				expect(ids[id]).never.to.be.ok()
				ids[id] = true
			end
			-- keep up is off: the shop-only cats use areaMultiplier instead, and it can come back by config
			expect(next(Config.KeepUpRarities)).to.equal(nil)
		end)

		it(
			"bowl levels (F82, section 8 v0.13.15): waits from 10:00 to 8:00 and luck from 0 to 16%",
			function()
				expect(Config.BowlWaitSeconds :: any).to.deepEqual({ 600, 570, 540, 510, 480 })
				expect(Config.BowlLuck :: any).to.deepEqual({ 0, 0.04, 0.08, 0.12, 0.16 })
				expect(Config.BowlWaitSeconds[1]).to.equal(Config.LureWaitSeconds)
				-- section 3's Big Bowl wait of 8:00 on a level 1 bowl, 2 minutes off any bowl since F95
				expect(Config.BowlWaitSeconds[1] - Config.BigBowlWaitCutSeconds).to.equal(480)
				expect(#Config.BowlLuck).to.equal(Catalog.upgradesById.lure_bowl.maxLevel)
				expect(#Config.BowlWaitSeconds).to.equal(Catalog.upgradesById.lure_bowl.maxLevel)
			end
		)

		it("NetWindows matches the section 10 net table, levels 0 to 3, with no jitter column (F93)", function()
			local expectedWindows = {
				[0] = { perfect = 0.045, good = 0.11 },
				[1] = { perfect = 0.055, good = 0.13 },
				[2] = { perfect = 0.065, good = 0.155 },
				[3] = { perfect = 0.08, good = 0.18 },
			}
			local levels = 0
			for level, row in pairs(Config.NetWindows) do
				levels += 1
				local want = expectedWindows[level]
				expect(want).to.be.ok()
				assert(want)
				expect(row.perfect).to.be.near(want.perfect, 1e-9)
				expect(row.good).to.be.near(want.good, 1e-9)
				expect((row :: any).jitter).never.to.be.ok()
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
				end
			end
		end)

		it("S24: CircleGapMin is above the widest good window plus the latency cap", function()
			-- Otherwise a late press for one circle could land on the next. Widening good means raising the gap. Since
			-- F93 a Common's catchWindow (1.1) widens the net's Good, so the widest is the Master Net Common's.
			local widest = 0
			for _, row in pairs(Config.NetWindows) do
				for _, rarity in pairs(Catalog.rarities) do
					widest = math.max(widest, row.good * rarity.catchWindow)
				end
			end
			expect(Config.CircleGapMin > widest + Config.CatchLatencyCapSeconds).to.equal(true)
			expect(Config.CircleGapMin <= Config.CircleGapMax).to.equal(true)
		end)

		it("circle scores: Perfect beats Good beats a miss, and Perfect is a sure catch", function()
			expect(Config.CircleScorePerfect).to.equal(1)
			expect(Config.CircleScoreGood > 0 and Config.CircleScoreGood < 1).to.equal(true)
		end)

		it(
			"v0.5 chase: a missed stray outruns a walking player and the one who missed waits a little longer",
			function()
				expect(Config.StrayFleeSpeed > Config.NormalWalkSpeed).to.equal(true)
				expect(Config.StrayRestSeconds > 0).to.equal(true)
				expect(Config.StraySelfRetrySeconds > 0).to.equal(true)
			end
		)

		it(
			"v0.8 F57: the wait after a miss grows 3, 6, then 10 s, and a Startled player walks slower",
			function()
				expect(Config.StraySelfRetrySteps :: any).to.deepEqual({ 3, 6, 10 })
				expect(Config.StraySelfRetrySeconds).to.equal(Config.StraySelfRetrySteps[1])
				expect(Config.StartledWalkSpeed < Config.NormalWalkSpeed).to.equal(true)
			end
		)

		it("v0.5 chase: the v0.4 wary wait and jump back are gone (F40)", function()
			local config = Config :: any
			expect(config.StrayWarySeconds).never.to.be.ok()
			expect(config.StrayJumpBackMin).never.to.be.ok()
			expect(config.StrayJumpBackMax).never.to.be.ok()
		end)

		it("v0.5 night: the cafe closes, so the night owls' spawn time is gone (F44)", function()
			expect((Config :: any).CustomerSpawnSecondsNight).never.to.be.ok()
		end)

		it("v0.8 night (F60): full pay, and night bait waits half the day wait", function()
			expect(Config.NightIncomeMultiplier).to.equal(1)
			expect(Config.LureWaitSecondsNight * 2).to.equal(Config.LureWaitSeconds)
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
			expect(most).to.equal(56) -- F93: seven circles
			expect(most < 100).to.equal(true)
		end)

		it("carry speed is about 80% of normal walk speed (features F07)", function()
			expect(Config.CarryWalkSpeed / Config.NormalWalkSpeed).to.be.near(0.8, 0.02)
		end)

		it(
			"the Catch Rush outruns a walking player and the burst stays inside its own radius (F55)",
			function()
				expect(Config.CatchRushWalkSpeed > Config.NormalWalkSpeed).to.equal(true)
				expect(Config.CatchBurstStuds <= Config.CatchBurstRadiusStuds).to.equal(true)
			end
		)

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

		it(
			"the rescue bar matches the section 10b table: rarer is faster and narrower (v0.13.15 F83)",
			function()
				local rows = {
					Common = { 1.0, 0.26 },
					Rare = { 1.2, 0.20 },
					Epic = { 1.4, 0.15 },
					Legendary = { 1.6, 0.12 },
					Mythical = { 1.8, 0.10 },
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
			end
		)

		it("bait bowl: gold is a probability (Tame and Let go work from anywhere since 2026-10-28)", function()
			expect((Config :: any).BaitResolveRangeStuds).never.to.be.ok()
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

	describe("the rainbow coat (F99, rainbow-coat.md section 1)", function()
		it("is a tenth of gold everywhere and earns twice a gold cat", function()
			expect(Config.RainbowChanceNet).to.be.near(Config.GoldChanceNet / 10, 1e-9)
			expect(Config.RainbowChanceBait).to.be.near(Config.GoldChanceBait / 10, 1e-9)
			expect(Config.RainbowChanceRescue).to.be.near(Config.GoldChanceRescue / 10, 1e-9)
			expect(Config.RainbowMultiplier).to.equal(2 * Config.GoldMultiplier)
			expect(Config.CollectorRainbowMultiplier > Config.CollectorGoldMultiplier).to.equal(true)
		end)
	end)

	describe("the crate reel (F103, crate-reel.md section 4)", function()
		it("keeps the won tile inside the protected run and the stop's view on the strip", function()
			local landing = Config.CrateReelLandingTile
			expect(landing >= Config.CrateReelProtectFrom and landing <= Config.CrateReelProtectTo).to.equal(true)
			-- the seven tiles in view at the stop (three either side of the won one) are all on the strip
			expect(Config.CrateReelProtectTo <= Config.CrateReelTiles and landing + 3 <= Config.CrateReelTiles).to.equal(
				true
			)
		end)
	end)
end
