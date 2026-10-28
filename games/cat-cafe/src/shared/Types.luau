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

-- "shop" decor is bought with BuyDecor; "crate" decor (F53) only comes out of a Cafe Crate. The F48 Index pieces
-- became their zones' Epic crate pieces in F54, and the gold Index pieces were retired before anyone earned one.
export type DecorSource = "shop" | "crate"

-- What a crate piece is (F53, golden-fish.md section 4). The cafe has one wallpaper, one floor and one paint in use
-- at a time, and since F80 (section 4b) one door set (front and back door together) and one cat flap; furniture and
-- decorations stand on decor spots.
export type DecorKind =
	"wallpaper"
	| "floor"
	| "paint"
	| "door"
	| "catflap"
	| "furniture"
	| "decoration"

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
	source: DecorSource?, -- missing means "shop"
	replaces: string?, -- a piece this one stands in for while both are placed (N114; no piece has one since F54)
	-- a crate piece (F53): its pool (a zone id or "classic"), rarity and kind; a wallpaper, floor or paint also has
	-- its colour and material, which the client puts on the cafe's tagged shell parts
	crate: string?,
	rarity: Rarity?,
	kind: DecorKind?,
	color: Color3?,
	material: Enum.Material?,
}

-- Data-model section 11b and golden-fish.md sections 5 and 5b (F54): a milestone on an Index page, `needs` of what
-- its track counts. "normal": different cats of the page's area (every area on the All Cats page, area id "all");
-- "gold": gold cats of the area; "decor": pieces of the Decor Index page's crate (area ids "decor_<pool>").
export type IndexTrack = "normal" | "gold" | "decor"

export type IndexMilestone = {
	id: string,
	track: IndexTrack,
	needs: number,
}

-- What one Index milestone pays (golden-fish.md section 8), any of it. `coins` is the minimum and `coinSeconds`
-- (when set) pays max(coins, floor(dayRate x coinSeconds)). `crates` maps a crate id, or "highest" (the plain crate
-- of the player's highest open zone), to a count. `bonus` (tips), `goldLuck` and `baitSpeed` are permanent fractions
-- from the claim on; a milestone has one kind. `tag` names a title the prize unlocks.
export type IndexPrize = {
	coins: number?,
	coinSeconds: number?,
	lures: { [string]: number }?,
	fish: number?,
	spins: number?,
	crates: { [string]: number }?,
	bonus: number?,
	goldLuck: number?,
	baitSpeed: number?,
	tag: string?,
}

-- A code (F65, data-model section 11d), keyed in Catalog.codes by its lowercased text. Its prize uses the Index
-- prize shape. An inactive or ended code has expired; a requiresGroup code needs membership of Config.GroupId.
export type CodeDef = {
	id: string,
	prize: IndexPrize,
	active: boolean,
	endsAt: number?, -- os.time()
	requiresGroup: boolean?,
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
	rarity: Rarity, -- v0.10 (F69): how good the food is, shown as a badge and border in the cat rarity colours
	source: LureSource, -- "shop" foods are bought with BuyLure, "dealer" foods only from the night dealer
	description: string,
	odds: LureOdds, -- percentages summing to 100, shown before purchase
	asset: string, -- food model shown in the bowl while the lure is active
}

-- A Cafe Crate (F53, golden-fish.md section 4): ten cosmetics of one pool, opened at the Golden Fish Market. The
-- zone crates open with their zone; the Classic Crate (area "classic") is open from Tier 1. A golden crate has the
-- same pieces at Epic or better odds and is never sold.
export type CrateDef = {
	id: string,
	name: string,
	area: string, -- its pool: a zone id or "classic"
	golden: boolean,
	price: number?, -- golden fish at the Market; nil for a golden crate
	odds: { [string]: number }, -- percent by rarity, adding up to 100; a piece's chance is its rarity's share
	pieces: { string }, -- decor ids
}

-- One row of the Golden Fish Market (F53, golden-fish.md section 3). A crate or a food has one `cost`; a perk has a
-- cost per level in `costs` and stops at `maxLevel`.
export type FishShopRow = {
	id: string, -- the crate id, the lure id or the perk id
	kind: "crate" | "lure" | "perk",
	cost: number?,
	costs: { number }?,
	maxLevel: number?,
}

-- Data-model section 11b (F47): one Tip Jar gift, unlocked `minutes` into a session. A "coins" step pays
-- max(minCoins, floor(day rate x seconds)) at claim time; a "lure" step adds `count` of the food `lureId`.
export type TipJarStep = {
	step: number,
	minutes: number,
	prize: IndexPrize, -- F68 (data-model 11b v0.10): the Index prize shape, so one step can pay several things
}

-- One slice of the Spin Wheel (F49, data-model section 11c): the Tip Jar's prize shape plus its weight. The weights
-- add up to 100, so each is the slice's chance in percent.
export type SpinSlice = {
	slice: number,
	kind: "coins" | "lure" | "fish" | "crate", -- F54: golden fish and a crate
	seconds: number?,
	minCoins: number?,
	lureId: string?,
	count: number?, -- foods, golden fish or crates
	crate: string?, -- F54: the crate id, or "highest"
	weight: number,
}

-- The player's spins (F49): `lastFreeDay` is the UTC day number (os.time() // 86400) of the last free spin, so the
-- free one is due on any later day; `banked` is 0 to SpinBankCap.
export type SpinState = {
	lastFreeDay: number,
	banked: number,
}

-- TipJarState (server to client): when this session's jar started (workspace:GetServerTimeNow(), the clock the
-- client counts down against) and one claimed flag per step in order. A dense array, because a sparse table of
-- step numbers would lose entries past its first gap on the way through a remote.
export type TipJarState = {
	sessionStartedAt: number,
	claimed: { boolean },
}

export type AreaDef = {
	id: string,
	name: string,
	tier: number, -- the tier that opens it (data-model section 5b)
	spawnPoints: number,
	waveSize: number, -- strays spawned at once at each night start
	rescueSpots: number,
	odds: LureOdds,
	incomeMultiplier: number, -- a cat from here earns its rarity's income times this (data-model v0.13.7)
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
	level: number, -- 1 to Config.CatMaxLevel, rises with XP earned while the owner is in the game (v0.12 F75)
	xp: number, -- toward the next level, may hold a fraction; one XP a second working, a quarter resting
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
	tipJarClaims: number, -- F47
	spins: number, -- F49
	cratesOpened: number, -- F53
	fishEarned: number, -- F52: golden fish earned, every source
	pickups: number, -- v0.8 F56: Dropped cats picked up with PickUpCat
	catLevelUps: number, -- v0.12 F75: every level any of the player's cats gained
}

-- The cat on its way to the bait bowl, rolled when the food goes in so a rejoin cannot reroll it (section 8).
export type BaitState = {
	lureId: string,
	placedAt: number, -- os.time()
	-- os.time() the cat comes, fixed when the food goes in (F54: the wait less the Index's bait speed), so a later
	-- claim or perk never moves a filling bowl; nil on saves from before it, which wait LureWaitSeconds
	readyAt: number?,
	catId: string,
	variant: string,
	charm: number,
}

-- The bowl as ProfileSync sends it: the food and when its cat arrives. `cat` is only there once it has arrived,
-- so the roll is not spoiled before then (reviewer N30).
export type BaitView = {
	lureId: string,
	placedAt: number, -- server os.time(); with readyAt, the fill bar's length (F54: the wait is fixed at placement)
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
	tutorialButton: boolean, -- the HUD's Tutorial tile (F72)
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
	indexRewards: { [string]: { [string]: boolean } }, -- areaId -> milestoneId -> claimed (F48)
	spin: SpinState, -- F49
	-- Golden fish (F52, golden-fish.md): the rare currency, earned only. Crates, their luck and the Market's perks
	-- (F53) came in the same save version 7.
	goldenFish: number,
	lifetimeGoldenFish: number,
	crates: { [string]: number }, -- crateId -> unopened count
	crateLuck: { [string]: number }, -- crate pool (zone id or "classic") -> opens since its last Epic or better
	fishPerks: { [string]: number }, -- perkId -> level bought
	codesRedeemed: { [string]: number }, -- code id -> os.time() it was redeemed (F65)
	introSeen: boolean, -- the intro cutscene has played to the end or been skipped once (F72)
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
	indexRewards: { [string]: { [string]: boolean } }, -- F48
	spin: SpinState, -- F49
	goldenFish: number, -- F52
	crates: { [string]: number }, -- F53
	crateLuck: { [string]: number },
	fishPerks: { [string]: number },
	goldLuck: number, -- F54: the Index gold track's summed luck, capped at GoldLuckMax
	baitSpeed: number, -- F54: the All Cats track's summed bait speed, capped at BaitSpeedMax
	plotIndex: number,
	carrying: string?, -- catId while carrying a caught stray home
	dataSaves: boolean,
	tutorialStep: number,
	introSeen: boolean, -- F72: false plays the intro cutscene once this session's first sync carries a plot
	settings: Settings, -- the Settings screen follows these; Audio mutes and sets its channels by them
	serverTime: number,
}

return {}
