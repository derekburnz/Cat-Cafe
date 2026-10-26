--!strict
-- Config.luau against the tuning table in data-model.md section 17 (DesignParity), design v0.3.1.
-- `expected` holds what is built: v0.2 values the code still uses plus the v0.3 changes whose feature has landed.
-- `pending` lists the v0.3 values still to come, by feature; move a row into `expected` when its feature lands
-- (and delete the v0.2 row it replaces). World layout numbers in Config.World are the engineer's.
return function()
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
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
		NightLengthSeconds = 300,
		ServerStartDaySeconds = 120,
		StrayDespawnSeconds = 120,
		-- v0.2 rescue (section 10)
		RescueSpawnChance = 0.5,
		RescueHoldSeconds = 4,
		RescueLockSeconds = 6,
		RescuedTipsMultiplier = 1.0, -- v0.3 (F22): a rescue pays no more; its reward is the shiny chance
		GrabRangeStuds = 10,
		GrabRetrySeconds = 2,
		LureWaitSeconds = 45,
		LureDespawnSeconds = 90,
		CarryWalkSpeed = 13,
		CheckInRangeStuds = 8,
		CustomerSpawnSeconds = 6,
		CustomerStayMin = 20,
		CustomerStayMax = 40,
		RemoteRateLimitPerSecond = 10,
		AnnounceMinRarity = "Epic",
		GrabCooldownSeconds = 2,
		SyncIntervalSeconds = 10,
		NormalWalkSpeed = 16,
		StrayWanderRadius = 5,
		StrayWanderSpeed = 3,
		CustomerCoinPopSeconds = 3,
		CustomerWalkSpeed = 7,
		SeatsPerTable = 2,
		MaxIdLength = 40,
		TutorialGuaranteedStrayStep = 2,
		RingLatencyGraceSeconds = 0.25,
		-- cat stats (data-model section 4b)
		CatMaxLevel = 10,
		CatLevelBonus = 0.05,
		CatXpBase = 60,
		CatXpPerSecondPlaced = 1,
		CharmSpread = 0.20,
		ShinyMultiplier = 1.5, -- v0.3 (F22)
		-- the net as closing circles (section 10, F26)
		CircleLeadInSeconds = 0.6,
		CircleGapMin = 0.40,
		CircleGapMax = 0.75,
		CircleScorePerfect = 1.0,
		CircleScoreGood = 0.5,
		CatchLatencyCapSeconds = 0.15,
	}

	-- v0.3 section 17 values not built yet: name -> { value, feature }
	local pending: { [string]: { any } } = {
		RescueSpawnChance = { 0.6, "F27" },
		RescueMinStuck = { 1, "F27" },
		RescueTolerance = { 0.03, "F27" },
		RescuePatience = { 3, "F27" },
		RescueRetrySeconds = { 3, "F27" },
		RescueSelfRetrySeconds = { 6, "F27" },
		RescueAttemptMaxSeconds = { 15, "F27" },
		LureWaitSeconds = { 600, "F28" },
		BaitBowlRangeStuds = { 12, "F28" },
		BumpEnabled = { true, "F29" },
		BumpRangeStuds = { 6, "F29" },
		BumpChance = { 0.5, "F29" },
		BumpGraceSeconds = { 3, "F29" },
		BumpSafeRadiusStuds = { 15, "F29" },
		BumpCooldownSeconds = { 12, "F29" },
		BumpSameTargetSeconds = { 60, "F29" },
		DropOwnerPrioritySeconds = { 8, "F29" },
		DroppedMinStaySeconds = { 120, "F29" },
		ShinyChanceNet = { 0.02, "F30" },
		ShinyChanceBait = { 0.02, "F30" },
		ShinyChanceRescue = { 0.10, "F30" },
		NightIncomeMultiplier = { 0.6, "F31" },
		CustomerSpawnSecondsNight = { 12, "F31" },
		RichCheckSeconds = { 60, "F31" },
		RichChance = { 0.15, "F31" },
		RichTipSeconds = { 45, "F31" },
		RichTipStaySeconds = { 90, "F31" },
		DealerRangeStuds = { 12, "F32" },
		DealerWindowSeconds = { 600, "F32" },
		CatNameMaxLength = { 20, "F33" },
		RenameCooldownSeconds = { 5, "F33" },
	}

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
				NetWindows = true, -- a table per net level, checked below
				ProfileStoreName = true,
				ProfileKeyPrefix = true,
				GrabRateLimitSeconds = true,
				LureReserveSeconds = true,
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
		it("NetWindows follow the section 10 table for net levels 0 to 3", function()
			local want = {
				[0] = { 0.045, 0.11, 0.30 },
				[1] = { 0.055, 0.13, 0.20 },
				[2] = { 0.065, 0.155, 0.10 },
				[3] = { 0.08, 0.18, 0 },
			}
			for level, row in want do
				local windows = Config.NetWindows[level]
				expect(windows).to.be.ok()
				expect(windows.perfect).to.be.near(row[1], 1e-9)
				expect(windows.good).to.be.near(row[2], 1e-9)
				expect(windows.jitter).to.be.near(row[3], 1e-9)
			end
		end)

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

		it("S24: the shortest gap outlasts the widest Good window plus the latency cap", function()
			-- so a circle's deadline always passes before the next one starts
			for level = 0, 3 do
				local windows = Config.NetWindows[level]
				expect(Config.CircleGapMin > windows.good + Config.CatchLatencyCapSeconds).to.equal(
					true
				)
			end
			expect(Config.CircleGapMin <= Config.CircleGapMax).to.equal(true)
		end)

		it("carry speed is about 80% of normal walk speed (features F07)", function()
			expect(Config.CarryWalkSpeed / Config.NormalWalkSpeed).to.be.near(0.8, 0.02)
		end)

		it("the v0.2 hold ring and flat chance are gone (F26)", function()
			local config = Config :: any
			for _, name in
				{
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
				}
			do
				expect(config[name]).never.to.be.ok()
			end
		end)

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
			"clock: the first night comes by minute two and the whole first night fits in the ten minute loop",
			function()
				expect(Config.ServerStartDaySeconds > 0).to.equal(true)
				expect(Config.ServerStartDaySeconds <= 120).to.equal(true)
				expect(Config.ServerStartDaySeconds <= Config.DayLengthSeconds).to.equal(true)
				expect(Config.NightLengthSeconds > 0).to.equal(true)
				-- v0.3 (Gavin, Q1) runs 5 minute days and nights, so the loop test sees one full night
				expect(Config.ServerStartDaySeconds + Config.NightLengthSeconds <= 600).to.equal(
					true
				)
			end
		)

		it(
			"rescue: the lock outlives the hold, the chance is a probability, a rescue pays no more (v0.3)",
			function()
				expect(Config.RescueLockSeconds > Config.RescueHoldSeconds).to.equal(true)
				expect(Config.RescueSpawnChance > 0 and Config.RescueSpawnChance <= 1).to.equal(
					true
				)
				expect(Config.RescuedTipsMultiplier).to.equal(1)
			end
		)

		it("lures: the wait is shorter than the lured stray's lifetime", function()
			expect(Config.LureWaitSeconds < Config.LureDespawnSeconds).to.equal(true)
		end)

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
