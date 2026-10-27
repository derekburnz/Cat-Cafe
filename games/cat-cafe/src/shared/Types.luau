--!strict
-- Shared types. Field names follow docs/design/cat-cafe/ui-contract.md and data-model.md.
-- Pure: no Roblox globals, so tests can require it.

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythical"
export type Area = "alley" | "park" | "neighbourhood" | "woods" | "sewer"
export type Role = "barista" | "waiter" | "greeter" | "entertainer"
-- A role slot is still called a spot in code, so the save field (spotId) and the UI intents keep their names.
export type SpotType = Role
export type CatchMethod = "net" | "rescue" | "bait" | "starter"
export type LureSource = "shop" | "dealer"
-- How one closing circle was judged (data-model section 10).
export type CircleGrade = "perfect" | "good" | "miss"
export type RingResult = CircleGrade -- the v0.2 ring's name, kept while the UI still uses it
export type ClockPhase = "day" | "night" -- ReplicatedStorage.Clock attribute Phase (data-model section 9)
export type ToastKind = "info" | "good" | "warn"

export type RarityDef = {
	incomePerSecond: number,
	circles: number, -- closing circles in a net catch (data-model section 10)
	shrinkSeconds: number, -- base shrink time of each circle
	fleeStuds: number, -- how far a stray sprints after a missed catch (v0.5, data-model section 10 step 5)
	rescueHits: number, -- bar hits that free a stuck cat (section 10b)
	sellValue: number,
	firstCatchReward: number,
	color: string, -- hex like "#8E97B2"
}

-- One closing circle as CatchSchedule sends it: it starts shrinking at startsAt (Workspace:GetServerTimeNow()
-- time) and reaches its ring at startsAt + shrinkSeconds, the target. x and y place it on screen, 0 to 1.
export type CatchCircle = {
	startsAt: number,
	shrinkSeconds: number,
	x: number,
	y: number,
}

-- Timing windows of a net level: half-widths in seconds either side of each target; jitter spreads each circle's
-- shrink time by up to that fraction. CatchSchedule sends only perfect and good.
export type NetWindows = { perfect: number, good: number, jitter: number }
export type CatchWindows = { perfect: number, good: number }

-- A rescue minigame as RescueChallenge sends it (data-model section 10b), times in server time. "bar": a marker
-- slides back and forth along a bar (shared/RescueMarker) and each press inside the zone is a hit; zones holds
-- the zone centre (0 to 1) for each hit in order. "shake_catch": the same bar on a tree, where each hit shakes
-- the branch; the server then sends a second challenge of kind "circle", one catch circle with its windows.
export type RescueKind = "bar" | "shake_catch" | "circle"
export type RescueChallenge = {
	kind: RescueKind,
	startsAt: number,
	phase: number?, -- 0 to 2, where on the back-and-forth the marker starts
	speed: number?, -- bar lengths per second (RescueBarSpeed)
	zoneWidth: number?, -- fraction of the bar (RescueZoneWidth)
	zones: { number }?,
	hitsNeeded: number?,
	paws: number?, -- misses the attempt can take (RescuePatience)
	endsAt: number?, -- the attempt's deadline
	circle: CatchCircle?, -- kind "circle"
	windows: CatchWindows?, -- kind "circle"
}

export type CatDef = {
	id: string,
	name: string,
	rarity: Rarity,
	incomePerSecond: number,
	area: Area, -- the one area it spawns in
	favoriteRole: Role, -- earns FavoriteMultiplier in a slot of this role
	description: string,
	pattern: string,
	color: { number }, -- {r, g, b} 0..255 for the placeholder body
}

export type UpgradeDef = {
	id: string,
	name: string,
	description: string,
	maxLevel: number,
	costs: { number }, -- costs[n] = cost of level n
	startLevel: number, -- 0 for most, 1 for espresso
	requiresTier: number?, -- tier needed to buy level 1
	requiresTierAtLevel: { [number]: number }?, -- e.g. espresso level 3 needs Tier 2 (the tier caps, section 5b)
}

export type DecorDef = {
	id: string,
	name: string,
	cost: number,
	category: string,
	effect: string,
	description: string,
	requiresTier: number?,
	bonus: number, -- added to the cafe multiplier while placed
	asset: string, -- model name in ReplicatedStorage.Assets
}

export type LureOdds = {
	Common: number,
	Rare: number,
	Epic: number,
	Legendary: number,
	Mythical: number,
}

export type LureDef = {
	id: string,
	name: string,
	cost: number,
	attracts: Rarity, -- the rarity it is known for (the dealer foods: their likeliest rarity)
	source: LureSource, -- "shop" foods are bought with BuyLure, "dealer" foods only from the night dealer
	description: string,
	odds: LureOdds, -- percentages summing to 100, shown before purchase
	asset: string, -- food model shown in the bowl while the lure is active
}

export type AreaDef = {
	id: string,
	name: string,
	tier: number, -- the tier that opens it (data-model section 5b)
	spawnPoints: number,
	waveSize: number, -- strays spawned at once at each night start
	rescueSpots: number,
	odds: LureOdds,
}

export type SpotDef = {
	id: string, -- "barista_1"
	spotType: SpotType, -- the role
	tier: number, -- opens at this tier
}

-- One cafe tier (data-model section 5b). RankUp raises the tier when every requirement is met.
export type TierDef = {
	tier: number,
	name: string,
	cost: number, -- coins spent on rank up; 0 for Tier 1
	distinctCats: number, -- entries in the collection
	needsRarity: Rarity?, -- and this many different cats of this rarity in the collection
	needsRarityCount: number?,
	slots: number, -- role slots open at this tier
	multiplier: number, -- tierMultiplier in the income formula
	area: Area, -- the area this tier opens
	caps: { tables: number, espresso: number, net: number }, -- highest shop level allowed at this tier
}

export type CatInstance = {
	uid: string,
	catId: string,
	variant: string, -- "base" or "gold"
	caughtAt: number,
	spotId: string?, -- the role slot it works, nil when resting in the cat room
	-- Stats (data-model section 4b). Readers go through CatStats, which defaults any missing field.
	level: number, -- 1 to Config.CatMaxLevel, rises with XP earned while placed
	xp: number, -- toward the next level; one XP per second placed
	charm: number, -- 0 to 100, rolled once when caught; 50 is a 1.0x rate
	rescued: boolean?, -- true when freed from a rescue spot (for the book and analytics); absent otherwise
	name: string?, -- the player's name for it as typed, filtered again for display; nil shows the catalog name
	method: CatchMethod?, -- how it was found
}

-- One cat as ProfileSync sends it: the saved fields plus the derived numbers the UI shows.
export type CatView = {
	uid: string,
	catId: string,
	variant: string,
	caughtAt: number,
	spotId: string?,
	rescued: boolean?,
	name: string?,
	method: CatchMethod?,
	level: number,
	xp: number,
	xpToNext: number, -- 0 at the level cap
	charm: number,
	stars: number, -- 1 to 5, from charm
	rating: number, -- coins per second before the spot and cafe multipliers
}

export type Stats = {
	catsCaught: number,
	catsSold: number,
	grabsAttempted: number,
	grabsSucceeded: number,
	perfectCircles: number,
	circlesTotal: number,
	rescues: number,
	rescueAttempts: number,
	baitsTamed: number,
	baitsLetGo: number,
	bumpsGiven: number,
	bumpsLanded: number,
	bumpsTaken: number,
	luresUsed: number,
	playtimeSeconds: number,
	sessions: number,
}

-- The cat on its way to the bait bowl, rolled when the food goes in so a rejoin cannot reroll it (section 8).
export type BaitState = {
	lureId: string,
	placedAt: number, -- os.time(); ready at placedAt + LureWaitSeconds
	catId: string,
	variant: string,
	charm: number,
}

-- The bowl as ProfileSync sends it: the food and when its cat arrives. `cat` is only there once it has arrived,
-- so the roll is not spoiled before then (reviewer N30).
export type BaitView = {
	lureId: string,
	readyAt: number, -- server os.time()
	cat: { catId: string, variant: string, charm: number, stars: number }?,
}

-- What the night dealer sold this player (section 8b): stock and bought marks are keyed on the dealer window
-- floor(os.time() / 600). Slot numbers are string keys ("1" to "3") because a DataStore cannot hold a sparse array.
export type DealerState = {
	window: number,
	bought: { [string]: boolean },
}

-- The onboarding funnel's place (data-model section 14, growth analytics-plan 3.2): the last step logged, and later
-- steps already done but held back until every step before them is logged. Keys are "1" to "12" (JSON-shaped).
export type TelemetryState = {
	onboardingStep: number,
	achieved: { [string]: boolean },
}

-- One player's dealer stock as DealerStock sends it: the slot number is the index, restocksAt is os.time().
export type DealerSlot = { lureId: string, cost: number, bought: boolean }
export type DealerStock = { slots: { DealerSlot }, restocksAt: number }

-- Saved per player (data-model section 14). JSON-safe values only.
-- The player's settings (data-model section 14; shared/Settings validates them). Volumes run from 0 to 1.
export type Settings = {
	music: boolean,
	sfx: boolean,
	musicVolume: number,
	sfxVolume: number,
	screenShake: boolean,
	lowPerformance: boolean,
	showOtherCats: boolean,
	markers: boolean, -- the location markers (Place icons)
}

export type PlayerProfile = {
	version: number,
	coins: number,
	lifetimeCoins: number,
	lastTick: number,
	lastSeen: number,
	rateAtLogout: number, -- the day rate
	tier: number, -- 1 to 5 (section 5b)
	upgradeLevels: { [string]: number },
	decorOwned: { [string]: boolean },
	decorPlaced: { [string]: boolean },
	lures: { [string]: number },
	bait: BaitState?,
	dealer: DealerState,
	cats: { [string]: CatInstance },
	collection: { [string]: number },
	goldCollection: { [string]: number }, -- catId -> first gold caught at
	stats: Stats,
	tutorialStep: number,
	settings: Settings,
	flags: { autoPress: boolean }, -- for review only: set when the last 50 circles look scripted (section 10)
	telemetry: TelemetryState,
}

-- What ProfileSync sends. Matches ui-contract PlayerState plus a few extras the controller uses.
export type PlayerState = {
	money: number,
	incomePerSecond: number,
	tier: number,
	cafeProgress: number?,
	cafeProgressText: string?,
	tables: number,
	customers: number?, -- not sent; customers are simulated on the client
	catsOwned: { [string]: { count: number } },
	upgradeLevels: { [string]: number },
	decorOwned: { [string]: boolean },
	decorPlaced: { [string]: boolean },
	lures: { [string]: number },
	bait: BaitView?, -- nil when the bowl is empty
	-- extras (not in the UI contract, used by the client controller)
	cats: { [string]: CatView },
	collection: { [string]: number },
	goldCollection: { [string]: number },
	plotIndex: number,
	carrying: string?, -- catId while carrying a caught stray home
	dataSaves: boolean,
	tutorialStep: number,
	settings: Settings, -- the Settings screen follows these; Audio mutes and sets its channels by them
	serverTime: number,
}

return {}
