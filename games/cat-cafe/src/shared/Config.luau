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
	GrabRetrySeconds = 2, -- after a miss nobody can start a catch on that stray for at least this long
	-- v0.5 (F40): a miss makes the stray hiss and sprint its rarity's fleeStuds away at this speed (studs per second,
	-- faster than NormalWalkSpeed), then catch its breath this long; tries are unlimited
	StrayFleeSpeed = 26,
	StrayRestSeconds = 1.5,
	StraySelfRetrySeconds = 1, -- the player who missed waits this much longer than everyone else (v0.5.1, S44)
	GrabCooldownSeconds = 2, -- per player, between two catches started
	TravelCooldownSeconds = 3, -- per player, between two fast travels (features F19)

	-- The net: closing circles judged on the server (data-model section 10)
	CircleLeadInSeconds = 0.6, -- from GrabBegin to the first circle starting to shrink
	-- From one circle's target to the next one's start. CircleGapMin must stay above the widest good window plus
	-- CatchLatencyCapSeconds, so a late press for one circle can never land on the next (reviewer S24).
	CircleGapMin = 0.40,
	CircleGapMax = 0.75,
	CircleScorePerfect = 1.0, -- v0.4: grades decide the catch; the scores stay for tests and analytics only
	CircleScoreGood = 0.5,
	PerfectCharmBonus = 4, -- charm added to a caught cat per Perfect circle, capped at 100 (section 10 step 5)
	PurrfectCharmMultiplier = 2, -- the bonus is doubled when every circle is Perfect
	-- The scripted-press flag (reviewer S23): set above this Perfect rate over the last 50 circles, cleared at or
	-- below AutoPressClearRate. While set the profile gets no Perfect charm bonus (v0.4).
	AutoPressFlagRate = 0.95,
	AutoPressClearRate = 0.85,
	CatchLatencyCapSeconds = 0.15, -- most of a player's ping taken off a press (half the round trip, capped)
	-- Per net level (0 Basic, 1 Sturdy, 2 Pro, 3 Master): perfect and good are half-widths in seconds either side of
	-- the target; jitter spreads each circle's shrink time by up to that fraction either way.
	NetWindows = {
		[0] = { perfect = 0.045, good = 0.11, jitter = 0.30 },
		[1] = { perfect = 0.055, good = 0.13, jitter = 0.20 },
		[2] = { perfect = 0.065, good = 0.155, jitter = 0.10 },
		[3] = { perfect = 0.08, good = 0.18, jitter = 0 },
	} :: { [number]: { perfect: number, good: number, jitter: number } },
	-- The bait bowl (data-model section 8): a cat comes LureWaitSeconds after the food goes in, online or not.
	LureWaitSeconds = 600,
	BaitBowlRangeStuds = 12, -- UseLure from this close to your own bowl
	BaitResolveRangeStuds = 20, -- Tame or Let go from this close
	ShinyChanceBait = 0.02, -- rolled when the food goes in, revealed when the cat arrives
	ShinyChanceNet = 0.02, -- rolled when a stray spawns and shown as its sparkle
	-- The chance of 1 to 5 charm stars from CatStats.rollCharm and CatStats.stars, in percent, shown on every food
	-- card: 2s^2 and 1 - 2(1 - s)^2 at the band edges 20, 40, 60 and 80 out of 101 (reviewer N70).
	CharmStarOdds = { 7.84, 23.53, 35.67, 24.31, 8.65 } :: { number },
	CarryWalkSpeed = 16,
	NormalWalkSpeed = 20,
	CheckInRangeStuds = 8,
	StrayWanderRadius = 5,
	StrayWanderSpeed = 3,
	AnnounceMinRarity = "Epic",
	-- The night dealer (data-model section 8b): buy from this close to the cart; the stock rerolls every window.
	DealerRangeStuds = 12,
	DealerWindowSeconds = 600,

	-- Rescue minigames (data-model section 10b)
	RescueSpawnChance = 0.6, -- per trap at each night start
	RescueMinStuck = 1, -- stuck cats every area gets at night start even when no trap rolled one
	-- The bar per rarity: the marker's speed in bar lengths per second, the zone's width as a fraction of the bar
	RescueBarSpeed = {
		Common = 0.8,
		Rare = 1.0,
		Epic = 1.2,
		Legendary = 1.4,
		Mythical = 1.6,
	} :: { [string]: number },
	RescueZoneWidth = {
		Common = 0.30,
		Rare = 0.24,
		Epic = 0.19,
		Legendary = 0.15,
		Mythical = 0.12,
	} :: { [string]: number },
	RescueTolerance = 0.03, -- of the bar, either side of the zone
	RescuePatience = 3, -- misses one attempt can take
	RescueRetrySeconds = 3, -- after a failed attempt, before anyone else can try that trap
	RescueSelfRetrySeconds = 6, -- and before the player who failed can try it again
	RescueAttemptMaxSeconds = 15,
	ShinyChanceRescue = 0.10, -- rolled at night start, hidden until the rescue succeeds
	RescuedTipsMultiplier = 1.0, -- v0.3: a rescue pays no more; its reward is the higher shiny chance

	TutorialGuaranteedStrayStep = 2, -- players below this tutorialStep always find a Common stray at alley point 1

	-- Night income and rich customers (F31, data-model sections 11 and 12)
	NightIncomeMultiplier = 0.6, -- tips pay this share of the day rate at night; offline pay keeps the day rate
	RichCheckSeconds = 60, -- by day, how often each earning cafe rolls for a rich customer
	RichChance = 0.15,
	RichTipSeconds = 45, -- a rich tip is this many seconds of the day rate (at least $50)
	RichTipStaySeconds = 90, -- unclaimed, it pays itself into the till after this
	RichTipRangeStuds = 12, -- ClaimRichTip from this close to the plot's RichTipAnchor

	-- Shove (F29 bump rules, v0.5 F41, data-model section 10c); the code keeps the Bump names. Pure rules in Shove.
	BumpEnabled = true, -- false turns the Bump remote off and hides the Shove button
	BumpRangeStuds = 6,
	BumpChance = 0.5, -- a shove on a carrier knocks the cat loose this often
	BumpGraceSeconds = 3, -- a fresh carry cannot be knocked loose for this long
	BumpSafeRadiusStuds = 15, -- round both doors of the target's own cafe, as well as its plot
	BumpCooldownSeconds = 8, -- per shover
	BumpSameTargetSeconds = 20, -- per shover and target
	ShoveKnockbackStuds = 10, -- the target's client pushes its own character this far
	ShoveTargetImmuneSeconds = 4, -- after a shove lands, nobody can shove that player again for this long (S45)
	DropOwnerPrioritySeconds = 8, -- only the old carrier can catch a knocked-loose cat for this long
	DroppedMinStaySeconds = 120, -- a knocked-loose cat survives a night wave that starts this soon after the drop

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
		-- Cafe life (world-and-feel.md section 4, F37): each client walks customers into every running cafe within
		-- this range of its camera, up to CustomersMax at once across the street.
		CafeLifeRangeStuds = 80,
		CustomersMax = 24,
		CustomersMaxLow = 12, -- on a phone or tablet (Effects.tier() "low"): each walker moves every frame
		CustomerOrderSeconds = 2, -- standing at the counter before taking a seat
	},
}

return Config
