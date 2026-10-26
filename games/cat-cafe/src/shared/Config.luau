--!strict
-- Tuning constants for Purr Pot (docs/design/cat-cafe/data-model.md section 17 plus world layout).
-- Pure data: no Roblox services, so tests can require it. Nothing numeric lives in a Service.
-- Distances are studs, times are seconds, money is coins.

local Config = {
	ServerPlayers = 8,
	StartCoins = 50,

	-- Income (data-model section 11)
	FavoriteMultiplier = 1.5,
	TableBonus = 0.10,
	EspressoBonus = 0.15,
	OfflineRate = 0.25,
	OfflineCapSeconds = 3600,
	AutosaveSeconds = 60,
	SyncIntervalSeconds = 10, -- periodic ProfileSync even when nothing changed (the client predicts in between)

	-- Strays and catching (data-model sections 9 and 10)
	SpawnIntervalSeconds = 20,
	MaxStraysPerArea = 6,
	StrayDespawnSeconds = 120,
	GrabRangeStuds = 10,
	GrabHoldSeconds = 1.5,
	GrabLockSeconds = 3,
	GrabRetrySeconds = 2,
	GrabCooldownSeconds = 2, -- per player, between GrabBegin calls
	GrabMinHoldSeconds = 0.15, -- a GrabEnd faster than this after GrabBegin counts as a miss
	GlovesBonus = 0.10,
	LureBonus = 0.20,
	RingBonusPerfect = 0.15,
	RingBonusGood = 0.05,
	RingPerfectWindow = 0.30, -- seconds after the hold completes that count as perfect
	RingGoodWindow = 0.80, -- seconds after the hold completes that count as good
	CatchChanceMin = 0.05,
	CatchChanceMax = 0.95,
	LureWaitSeconds = 45,
	LureDespawnSeconds = 90,
	CarryWalkSpeed = 13,
	NormalWalkSpeed = 16,
	CheckInRangeStuds = 8,
	StrayWanderRadius = 5,
	StrayWanderSpeed = 3,
	AnnounceMinRarity = "Epic",
	TutorialGuaranteedStrayStep = 2, -- players below this tutorialStep always find a Common stray at alley point 1

	-- Cosmetic customers (client side)
	CustomerSpawnSeconds = 6,
	CustomerStayMin = 20,
	CustomerStayMax = 40,
	CustomerCoinPopSeconds = 3,
	CustomerWalkSpeed = 7,
	SeatsPerTable = 2,

	-- Remotes
	RemoteRateLimitPerSecond = 10,
	GrabRateLimitSeconds = 2,
	MaxIdLength = 40,

	-- Data
	ProfileStoreName = "PurrPotProfiles",
	ProfileKeyPrefix = "p_",

	-- World layout. The street runs along Z at X = 0. Plots line both sides, the alley is at +Z, the park at -Z.
	World = {
		PlotCount = 8,
		PlotWidth = 36, -- along the street (Z)
		PlotDepth = 28, -- away from the street (X)
		PlotRowGap = 8,
		StreetHalfWidth = 12,
		StreetLength = 200,
		GroundSize = 400,
		WallHeight = 9,
		DoorWidth = 7,
		AlleyCenterZ = 125, -- alley area center (north end of the street)
		AlleyWidth = 60, -- along X
		AlleyDepth = 44, -- along Z
		ParkCenterZ = -130,
		ParkWidth = 80,
		ParkDepth = 56,
		ParkGateZ = -101,
	},
}

return Config
