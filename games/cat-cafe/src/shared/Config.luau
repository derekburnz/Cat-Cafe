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
	ShinyMultiplier = 1.5, -- a shiny cat's rating (data-model section 4)

	-- The clock (data-model section 9): a server-wide loop of day then night
	DayLengthSeconds = 300,
	NightLengthSeconds = 300,
	ServerStartDaySeconds = 120, -- a new server starts in day with this long left, so the first night comes early

	-- Strays and catching (data-model sections 9 and 10). Wave sizes live per area in Catalog.areas.
	StrayDespawnSeconds = 120, -- lifetime of a Studio debug stray; wave strays stay until the next night
	GrabRangeStuds = 10,
	GrabRetrySeconds = 2, -- after a failed catch the stray stays (Common, lured), this player waits before trying it again
	GrabCooldownSeconds = 2, -- per player, between two catches started
	TravelCooldownSeconds = 3, -- per player, between two fast travels (features F19)

	-- The net: closing circles judged on the server (data-model section 10)
	CircleLeadInSeconds = 0.6, -- from GrabBegin to the first circle starting to shrink
	-- From one circle's target to the next one's start. CircleGapMin must stay above the widest good window plus
	-- CatchLatencyCapSeconds, so a late press for one circle can never land on the next (reviewer S24).
	CircleGapMin = 0.40,
	CircleGapMax = 0.75,
	CircleScorePerfect = 1.0,
	CircleScoreGood = 0.5,
	CatchLatencyCapSeconds = 0.15, -- most of a player's ping taken off a press (half the round trip, capped)
	-- Per net level (0 Basic, 1 Sturdy, 2 Pro, 3 Master): perfect and good are half-widths in seconds either side of
	-- the target; jitter spreads each circle's shrink time by up to that fraction either way.
	NetWindows = {
		[0] = { perfect = 0.045, good = 0.11, jitter = 0.30 },
		[1] = { perfect = 0.055, good = 0.13, jitter = 0.20 },
		[2] = { perfect = 0.065, good = 0.155, jitter = 0.10 },
		[3] = { perfect = 0.08, good = 0.18, jitter = 0 },
	} :: { [number]: { perfect: number, good: number, jitter: number } },
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
	RingLatencyGraceSeconds = 0.25, -- the v0.2 rescue hold's latency allowance, until the rescue minigames
	RescuedTipsMultiplier = 1.0, -- v0.3: a rescue pays no more; its reward is the higher shiny chance

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

	-- World layout v2 (engineer, 2026-10-26; data-model section 9, world-and-feel.md section 2). The street runs
	-- along Z at X = 0. Cafes line both sides, each with a front garden on the street and a patio yard out back;
	-- the Alleyway is a back alley behind each row that meets the other in the Alley Square at the street's north
	-- end. The Park, Woods and Sewer gates are at the south end, the Neighbourhood's through the Square's north wall.
	World = {
		PlotCount = 8,
		PlotWidth = 36, -- along the street (Z)
		PlotDepth = 28, -- away from the street (X)
		PlotRowGap = 8, -- a side passage from the street to the back alley between neighbouring cafes
		FrontGardenDepth = 5, -- path, bench and chalkboard between the sidewalk and the front wall
		YardDepth = 10, -- the patio yard between the back wall and the back alley
		StreetHalfWidth = 12,
		StreetSouthZ = -100,
		StreetNorthZ = 88, -- the street runs into the Alley Square here
		GroundSize = 560,
		WallHeight = 9,
		DoorWidth = 7,
		-- The Alleyway: back alleys at |x| AlleyInnerX..AlleyOuterX from AlleySouthZ to SquareSouthZ, and the
		-- Square across the whole width from SquareSouthZ to SquareNorthZ.
		AlleyInnerX = 59,
		AlleyOuterX = 89,
		AlleySouthZ = -101.5,
		SquareSouthZ = 88,
		SquareNorthZ = 152,
		ParkCenterZ = -130,
		ParkWidth = 80,
		ParkDepth = 56,
		ParkGateZ = -101,
		-- The Woods and the Sewer sit either side of the Park, their openings at the south end of the west and east
		-- back alleys; the Neighbourhood sits north of the Square.
		WoodsCenterX = -74,
		WoodsCenterZ = -134,
		WoodsWidth = 66,
		WoodsDepth = 64,
		WoodsGateZ = -101,
		SewerCenterX = 74,
		SewerCenterZ = -134,
		SewerWidth = 66,
		SewerDepth = 64,
		SewerGateZ = -101,
		NeighbourhoodCenterX = 0,
		NeighbourhoodCenterZ = 180.5,
		NeighbourhoodWidth = 90,
		NeighbourhoodDepth = 56,
		NeighbourhoodGateZ = 151.5,
	},
}

return Config
