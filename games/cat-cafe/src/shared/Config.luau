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

	-- Cat stats (data-model section 4b)
	CatMaxLevel = 10,
	CatLevelBonus = 0.05, -- rate bonus per level above 1, so level 10 is 1.45x
	CatXpBase = 60, -- XP (seconds placed) from level n to n + 1 is CatXpBase x n; level 10 after 45 min placed
	CatXpPerSecondPlaced = 1, -- XP a placed cat earns per second (Economy.settle grants it)
	CharmSpread = 0.20, -- charm 0 earns 1 - spread, charm 100 earns 1 + spread
	RenovateBonus = 0.25, -- permanent tips bonus per Renovate (rebirth); the seam exists, the feature does not yet

	-- The clock (data-model section 9): a server-wide loop of day then night
	DayLengthSeconds = 180,
	NightLengthSeconds = 120,
	ServerStartDaySeconds = 120, -- a new server starts in day with this long left, so the first night comes early

	-- Strays and catching (data-model sections 9 and 10). Wave sizes live per area in Catalog.areas.
	StrayDespawnSeconds = 120, -- lifetime of a Studio debug stray; wave strays stay until the next night
	GrabRangeStuds = 10,
	GrabHoldSeconds = 1.5,
	GrabLockSeconds = 3,
	GrabRetrySeconds = 2,
	GrabCooldownSeconds = 2, -- per player, between GrabBegin calls
	GrabMinHoldSeconds = 0.15, -- a GrabEnd sooner than this after GrabBegin is dropped and the lock continues
	NetBonus = 0.10, -- per net level (the upgrade was called gloves before v0.2)
	LureBonus = 0.20,
	RingBonusPerfect = 0.15,
	RingBonusGood = 0.05,
	RingPerfectWindow = 0.30, -- the last 0.30 s of the hold count as perfect (the server scores from the lock age)
	RingGoodWindow = 0.80, -- the last 0.80 s of the hold count as good
	RingLatencyGraceSeconds = 0.25, -- both windows run this long past the end of the hold; later is a miss
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

	-- Rescue (data-model section 10)
	RescueSpawnChance = 0.5, -- per rescue spot at each night start
	RescueHoldSeconds = 4,
	RescueLockSeconds = 6,
	RescuedTipsMultiplier = 1.10,

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
