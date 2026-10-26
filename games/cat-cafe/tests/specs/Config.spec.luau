--!strict
-- Config.luau against the tuning table in data-model.md section 17 (DesignParity).
-- World layout numbers in Config.World are the engineer's and are not checked here.
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
		SpawnIntervalSeconds = 20,
		MaxStraysPerArea = 6,
		StrayDespawnSeconds = 120,
		GrabRangeStuds = 10,
		GrabHoldSeconds = 1.5,
		GrabLockSeconds = 3,
		GrabRetrySeconds = 2,
		GlovesBonus = 0.10,
		LureBonus = 0.20,
		RingBonusPerfect = 0.15,
		RingBonusGood = 0.05,
		CatchChanceMin = 0.05,
		CatchChanceMax = 0.95,
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
		RingPerfectWindow = 0.30,
		RingGoodWindow = 0.80,
		SyncIntervalSeconds = 10,
		NormalWalkSpeed = 16,
		StrayWanderRadius = 5,
		StrayWanderSpeed = 3,
		CustomerCoinPopSeconds = 3,
		CustomerWalkSpeed = 7,
		SeatsPerTable = 2,
		MaxIdLength = 40,
		TutorialGuaranteedStrayStep = 2,
		GrabMinHoldSeconds = 0.15,
		RingLatencyGraceSeconds = 0.25,
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

		it("has no extra top level tuning numbers the doc does not know about", function()
			-- LureReserveSeconds: the doc now says a lured stray is reserved until despawn, so the constant is optional.
			local known = { World = true, ProfileStoreName = true, ProfileKeyPrefix = true, GrabRateLimitSeconds = true, LureReserveSeconds = true }
			for name, value in pairs(Config :: any) do
				if expected[name] == nil and not known[name] then
					error(string.format("Config.%s = %s is not in data-model section 17; add it to the doc or remove it", name, tostring(value)))
				end
			end
		end)
	end)

	describe("internal consistency", function()
		it("ring windows are ordered and the hold is longer than the perfect window", function()
			expect(Config.RingPerfectWindow < Config.RingGoodWindow).to.equal(true)
			expect(Config.GrabHoldSeconds > Config.RingPerfectWindow).to.equal(true)
		end)

		it("carry speed is about 80% of normal walk speed (features F07)", function()
			expect(Config.CarryWalkSpeed / Config.NormalWalkSpeed).to.be.near(0.8, 0.02)
		end)

		it("the grab lock outlives the hold so a second player cannot steal the stray mid-grab", function()
			expect(Config.GrabLockSeconds > Config.GrabHoldSeconds).to.equal(true)
		end)

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
