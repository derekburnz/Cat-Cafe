--!strict
-- Shared types. Field names follow docs/design/cat-cafe/ui-contract.md and data-model.md.
-- Pure: no Roblox globals, so tests can require it.

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythical"
export type Area = "alley" | "park" | "neighbourhood" | "woods" | "sewer"
-- A cat's area: one of the five, the spare pool of cats an area-themed cat replaced (data-model 3d, F78), or
-- "exclusive" for a cat that never spawns and is only given or sold (F95, the free Bellhop Cat of F96).
export type CatArea = Area | "spare" | "exclusive"
-- How an exclusive cat is had (F96): "free" from its stand, "shop" for Robux, "pass" from the Cafe Pass paid track.
export type CatSource = "free" | "shop" | "pass"
export type Role = "barista" | "waiter" | "greeter" | "entertainer"
-- A role slot is still called a spot in code, so the save field (spotId) and the UI intents keep their names.
export type SpotType = Role
export type CatchMethod = "net" | "rescue" | "bait" | "starter" | "trade" -- "trade": F102, from another player
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
	catchWindow: number, -- times the net's Perfect and Good for a cat of this rarity (v0.13.15 F83)
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

-- Timing windows of a net level: half-widths in seconds either side of each target (F93: the shrink time's wobble
-- is Config.CircleJitter on every net).
export type NetWindows = { perfect: number, good: number }
export type CatchWindows = { perfect: number, good: number }

-- A rescue minigame as RescueChallenge sends it (data-model section 10b), times in server time. "bar": a marker
-- slides back and forth along a bar (shared/RescueMarker) and each press inside the zone is a hit; zones holds
-- the zone centre (0 to 1) for each hit in order. "shake_catch": the same bar on a tree, where each hit shakes
-- the branch; with Config.RescueTreeCircle the server then sends a second challenge of kind "circle", one catch
-- circle with its windows (off since Derek 2026-11-03: the last shake frees the cat).
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
	-- F93 (catch-rework.md section 4): `zone` is the index of the one to hit now. Every hit makes the marker
	-- speedUpPerHit faster; RescueResult's RescueBar says how it runs after that. Derek 2026-11-03: a zone stays until
	-- it is hit, so zoneEndsAt is the attempt's deadline and zonePasses is no longer sent.
	zone: number?,
	zoneEndsAt: number?,
	zonePasses: number?,
	speedUpPerHit: number?,
	circle: CatchCircle?, -- kind "circle"
	windows: CatchWindows?, -- kind "circle"
	-- F92 (playing-together.md section 3): a Team Rescue helper's copy of a running bar, from where it is now (startsAt,
	-- phase, speed, zone and zoneEndsAt as the marker runs, paws left, hits so far). A helper's miss costs no paw.
	helper: boolean?,
	hits: number?,
}

-- How the rescue bar runs now (F93), RescueResult's last argument: the marker from server time startsAt at phase
-- (0 to 2) and speed bar lengths per second (shared/RescueMarker.position), zones[zone] the one to hit and
-- zoneEndsAt the attempt's deadline (a zone stays until it is hit, Derek 2026-11-03).
export type RescueBar = {
	zone: number,
	startsAt: number,
	phase: number,
	speed: number,
	zoneEndsAt: number,
	endsAt: number?, -- F92: the attempt's deadline, TeamRescueExtraSeconds later once a helper joins
}

export type CatDef = {
	id: string,
	name: string,
	rarity: Rarity,
	incomePerSecond: number,
	area: CatArea, -- the one area it spawns in, or "spare" (data-model 3d: never spawns)
	incomeArea: Area?, -- a spare cat's old area, whose income multiplier it keeps
	-- F95: a shop-only cat (the starter, Royal, Grand and season cats): it earns at the owner's newest area's
	-- multiplier and counts toward no "different cats", Index page or Index milestone
	exclusive: boolean?,
	source: CatSource?, -- F96: how an exclusive cat is had
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
-- "gold": gold cats of the area; "decor": pieces of the Decor Index page's crate (area ids "decor_<pool>");
-- "rainbow" (F99, rainbow-coat.md section 4): different rainbow cats across every area, on the Rainbow page (area id
-- "rainbow").
export type IndexTrack = "normal" | "gold" | "decor" | "rainbow"

export type IndexMilestone = {
	id: string,
	track: IndexTrack,
	needs: number,
	-- F97: every piece of the Decor page, whatever its size (decor10: sixteen on the Classic page, twelve elsewhere);
	-- `needs` is then the least it asks
	whole: boolean?,
}

-- What one Index milestone pays (golden-fish.md section 8), any of it. `coins` is the minimum and `coinSeconds`
-- (when set) pays max(coins, floor(dayRate x coinSeconds)). `crates` maps a crate id, or "highest" (the plain crate
-- of the player's highest open zone), to a count. `bonus` (tips), `goldLuck`, `rainbowLuck` (F99) and `baitSpeed` are
-- permanent fractions from the claim on; a milestone has one kind. `tag` names a title the prize unlocks.
-- A developer product (#1182): sold for Robux in the Store, granted by ProductService's ProcessReceipt. `prize` is a
-- fixed bundle of Big Money, Swift and Steady Paw Potions only (monetization-policy, decision 2026-11-01 22:42): never
-- coins, golden fish, crates, spins or anything random. The price is read from Roblox at runtime, never stored here.
export type ProductDef = {
	id: string,
	name: string,
	-- `cats` (shop-only cat ids) and `signStyles` (shared/SignStyles ids) are the Starter Bundle's (#1625)
	prize: { potions: { [string]: number }, cats: { string }?, signStyles: { string }? },
	-- #1625: sold once per account; a second receipt pays only the potions (Products.prizeFor)
	oncePerAccount: boolean?,
	-- #1626: unlocks the running Cafe Pass season's paid track (CafePass.buyPaid); once per season
	seasonPass: boolean?,
}

-- Cat food (corner-shop-v2.md section 3, #1181): kept in the Bag (profile.catFood) and fed to one cat with FeedCat.
export type CatFoodDef = { id: string, name: string, xp: number }

export type IndexPrize = {
	coins: number?,
	coinSeconds: number?,
	lures: { [string]: number }?,
	fish: number?,
	spins: number?,
	crates: { [string]: number }?,
	potions: { [string]: number }?, -- F64: potionId -> count (Tip Jar step 12, codes)
	catFood: { [string]: number }?, -- #1181: food id -> count into the Bag (Daily Treat, the Collector, catches, rescues)
	bonus: number?,
	goldLuck: number?,
	rainbowLuck: number?, -- F99: on every rainbow roll, the Rainbow track's sum capped at RainbowLuckMax
	baitSpeed: number?,
	tag: string?,
	passXp: number?, -- #1645 (quests.md section 8): Cafe Pass XP for the running season (CafePass.addXp)
}

-- The Cafe Pass (#1645, cafe-pass.md). A paid track's named item, kept forever once claimed: a chat tag, an accessory,
-- a uniform colour, a looks-only decor piece, a sign frame or the season cat.
-- #1624 (store-pass-looks.md): the saved theme and uniform picks (shared/Looks ids), nil for Classic.
export type LookPicks = { theme: string?, uniform: string? }
-- What the Style tab reads: the picks (the shown look, nil for Classic) and every owned id of each kind.
export type LooksView = { theme: string?, uniform: string?, themes: { string }, uniforms: { string } }

export type PassItemKind = "tag" | "accessory" | "uniform" | "decor" | "frame" | "cat"
export type PassItem = { kind: PassItemKind, id: string, name: string }
-- One level's reward on a track: a prize Payout pays, a named item, or both.
export type PassReward = { prize: IndexPrize?, item: PassItem? }
-- One season's two tracks, by level (the free track has every second level, the paid track every level).
export type PassSeasonDef = {
	id: string,
	name: string,
	free: { [number]: PassReward },
	paid: { [number]: PassReward },
}
-- profile.pass (save version 36), see shared/CafePass.
export type PassState = {
	season: number,
	xp: number,
	paidSeason: number,
	claimedFree: { number },
	claimedPaid: { number },
	items: { [string]: boolean },
	tag: string?,
}
-- CafePassState: what the Pass screen draws (CafePass.view).
export type CafePassView = {
	season: number, -- 0 while no season runs
	startsAt: number,
	endsAt: number?, -- nil while no later season is set; the screen shows the end as a plain date
	level: number,
	xp: number,
	xpPerLevel: number,
	levels: number,
	paid: boolean,
	claimedFree: { number },
	claimedPaid: { number },
	claimable: number, -- how many rewards are ready, for the HUD's red dot
	items: { [string]: boolean },
	tag: string?, -- the saved chat tag pick: a ChatTags id, "off", or nil for the default
	tags: { string }?, -- #1626: the chat tags the player may pick now (ChatTags.choices), set by CafePassService
	tagShown: string?, -- #1626: the tag their name shows now (ChatTags.shown), nil for none
}

-- A potion (F64, data-model section 12b): drunk from the bag with UsePotion, it runs `minutes` of play time.
-- `effect` is one short line for the bag. Potions are earned only.
export type PotionDef = {
	id: string,
	-- corner-shop-v2.md section 4: a Small or Big size of another potion runs that potion's timer (`buff`), so one chip
	-- shows the summed minutes; `shopOnly` keeps a size or the Cat Whistle out of Mystery gifts.
	buff: string?,
	shopOnly: boolean?,
	name: string,
	minutes: number,
	effect: string,
	-- F73 (quests.md section 4): what it adds while it runs. `tips` goes on every tip (all running tip potions
	-- together at most TimedTipsMax), `goldLuck` on every gold roll on top of GoldLuckMax, `baitSpeed` on the bait
	-- speed of food set while it runs, inside BaitSpeedMax. `quest` marks the three quest potions, which only quests
	-- and achievements pay (never a Mystery gift).
	tips: number?,
	goldLuck: number?,
	baitSpeed: number?,
	quest: boolean?,
}

-- One thing a Mystery Visitor's gift can hold (F64): `chance` in percent, the rows summing to 100. A "potion" row
-- has no id: the potion is one of Catalog.potions at even odds.
export type MysteryGiftKind = "potion" | "lure" | "fish" | "spin"
export type MysteryGiftRow = {
	kind: MysteryGiftKind,
	id: string?,
	count: number,
	chance: number,
}

-- One row of Catalog.collectorOffers (F63, data-model section 12b): what the Cat Collector offers for a cat he values
-- at `value` or more. `crates.zone` counts the crate of the cat's own area and `crates.golden` its golden one.
export type CollectorOffer = {
	value: number,
	fish: number?,
	lures: { [string]: number }?,
	spins: number?,
	crates: { zone: number?, golden: number? }?,
	catFood: { [string]: number }?, -- #1181 (corner-shop-v2.md section 3): his "2 Big Snacks"
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
	-- F97 (notes-10-28-to-10-30.md section 3): `cost` is the base price at Tiers 1 and 2 (Economy.foodPrice), and
	-- every food list runs by sortOrder: Kibble, Tuna, Moonlit Sardines, Salmon, Caviar, Moon Milk, Star Treat
	sortOrder: number,
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
	area: string, -- its pool: a zone id, "classic" or "rally" (F101)
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
	crate: string?, -- F54: the crate id, "highest" or (#1500) "highest_golden"
	weight: number,
	jackpot: boolean?, -- #1500: one of the two 0.5% slices, with the big win effect and a toast
}

-- The player's spins (F49): `lastFreeDay` is the UTC day number (os.time() // 86400) of the last free spin, so the
-- free one is due on any later day; `banked` is 0 to SpinBankCap.
export type SpinState = {
	lastFreeDay: number,
	banked: number,
}

-- The Daily Treat card (F70, data-model 11e): `stamp` is the last day paid on the card (0 on a fresh card, 7 on a
-- full one) and `lastDay` the UTC day number (os.time() // 86400) of that claim, so a stamp is due on any later day.
export type DailyTreatState = {
	stamp: number,
	lastDay: number,
}

-- What ProfileSync sends for the Daily Treat window and its HUD dot (F70): the card, whether a stamp is due now and
-- the day it pays (1 after a full card).
export type DailyTreatView = {
	stamp: number,
	lastDay: number,
	due: boolean,
	nextDay: number,
}

-- One day of the Daily Treat card (F70, data-model 11e), its prize in the Index prize shape.
export type DailyTreatDay = {
	day: number,
	prize: IndexPrize,
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
	tier: number, -- opens at this tier; a pass-only slot (#1624) has a tier past the last, opened by Economy.extraSlots
	passOnly: boolean?, -- #1624: opened only by an extra slot (Grand Cafe, the Extra Slot pass), never by a tier
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
	-- highest shop level allowed at this tier (lucky_cat: F88, level n at Tier n)
	caps: { tables: number, espresso: number, net: number, lure_bowl: number, lucky_cat: number },
}

export type CatInstance = {
	uid: string,
	catId: string,
	variant: string, -- "base", "gold" or "rainbow" (F99)
	caughtAt: number,
	spotId: string?, -- the role slot it works, nil when resting in the cat room
	-- Stats (data-model section 4b). Readers go through CatStats, which defaults any missing field.
	level: number, -- 1 to Config.CatMaxLevel, rises with XP earned while the owner is in the game (v0.12 F75)
	xp: number, -- toward the next level, may hold a fraction; one XP a second working, a quarter resting
	charm: number, -- 0 to 100, rolled once when caught; 50 is a 1.0x rate
	rescued: boolean?, -- true when freed from a rescue spot (for the book and analytics); absent otherwise
	name: string?, -- the player's name for it as typed, filtered again for display; nil shows the catalog name
	method: CatchMethod?, -- how it was found
	-- F62 (section 4): true when the player locked it, so it cannot be sold or traded; nil is unlocked. Gold,
	-- Legendary and Mythical cats arrive locked.
	locked: boolean?,
}

export type PassBoostsView = { cafe: number, staff: number, rich: number, money: number }

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
	locked: boolean, -- F62: the lock icon on its card
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
	potionsUsed: number, -- F64: potions drunk with UsePotion
	mysteryGifts: number, -- F64: Mystery gifts opened
	collectorTrades: number, -- F63: cats traded to the Cat Collector
	-- F73 (quests.md section 6): Rare or better and gold cats added by net, rescue or bait, tip piles collected, and
	-- quests and full sets finished
	rareCatches: number,
	goldCatches: number,
	rainbowCatches: number, -- F99: rainbow cats added by net, rescue or bait
	tipPilesCollected: number,
	dailyQuestsDone: number,
	dailySetsDone: number,
	weeklyQuestsDone: number,
	weeklySetsDone: number,
	-- F98 (leaderboards.md section 5): the best money per second the cafe has reached (shared/Leaderboards.moneyRate),
	-- and this week's play time and best rate (the week is Quests.week's)
	bestRate: number,
	weekPlay: WeekPlay,
	weekBestRate: WeekRate,
	-- F102 (trading.md section 6): trades done, and today's count for TradesPerDay (the day is a global game day since #1629)
	trades: number,
	tradesToday: TradesToday,
}

export type WeekPlay = { week: number, seconds: number }
export type WeekRate = { week: number, rate: number }
export type TradesToday = { day: number, count: number }

-- F102 trading (trading.md; shapes agreed with the UI thread 2026-11-02). One cat as a trade's log and its done card
-- show it.
export type CatSummary = { catId: string, rarity: string, variant: string?, level: number }
-- #1574 (section 1b): one decor or lawn piece as the log and the done card show it; `kind` "decor" or "lawn".
export type DecorSummary = { id: string, kind: string, rarity: string }
-- One of the last TradeLogMax trades, newest first: its id, when (os.time()), the partner's display name then, and
-- both sides.
export type TradeLogEntry = {
	id: string,
	at: number,
	partnerName: string,
	gave: { CatSummary },
	got: { CatSummary },
	gaveDecor: { DecorSummary }?, -- #1574; nil in entries from before decor trading
	gotDecor: { DecorSummary }?,
}
-- One cat on offer, as TradeState shows it to one player: `rateForMe` is what it earns (or would earn) per second in
-- that player's cafe.
export type TradeTile = {
	uid: string,
	catId: string,
	rarity: string,
	variant: string?, -- "gold" or "rainbow"; nil for the base coat
	level: number,
	charm: number?,
	rateForMe: number,
}
-- #1574: one decor or lawn piece on offer: its id, name, `kind` ("decor" or "lawn"), rarity and the money bonus it
-- adds while placed (0.05 is +5%).
export type TradeDecorTile = { id: string, name: string, kind: string, rarity: string, bonus: number }
export type TradeSide = {
	userId: number,
	name: string, -- the display name
	ready: boolean,
	confirmed: boolean,
	cats: { TradeTile },
	decor: { TradeDecorTile }, -- #1574
}
-- The last change to an offer, for the yellow flash and "Changed!" (section 3): whose side, which cat uid or piece
-- id, when (server time).
export type TradeChange = { side: string, uid: string, at: number }
-- TradeState(state?) for one player: nil closes the window.
export type TradeStateView = {
	tradeId: string,
	version: number,
	phase: string, -- "offer", "countdown" or "confirm"
	countdownEndsAt: number?, -- server time, while counting down
	me: TradeSide,
	them: TradeSide,
	changed: TradeChange?,
	giveValue: number, -- the Collector's values (Trade.value) of my cats on offer
	getValue: number, -- and of theirs
	lopsided: boolean, -- I give at least TradeLopsidedRatio times what I get
	gift: boolean, -- I get nothing back
	myRateNow: number, -- what my cats on offer earn in my cafe now, per second
	theirRateForMe: number, -- what their cats would earn in my cafe, per second
	confirmAt: number?, -- server time from which my Confirm counts (TradeConfirmWaitSeconds after a lopsided or gift
	-- confirm screen opens); nil when there is no wait
	theyHave: { string }, -- #1574: my tradeable pieces the other player already owns (grey, "They already have this")
}

-- F98: one row of a leaderboard list as LeaderboardSync sends it: the player's display name, the list's whole-number
-- value (entries, minutes played, money per second) and whether they wear the crown (top 10 of any all-time board).
export type LeaderboardRow = {
	rank: number,
	userId: number,
	name: string,
	value: number,
	crown: boolean,
}

-- F98: LeaderboardSync's payload. boards[board].week only on playtime and money; me[board] is the receiving player's
-- own line: their all-time rank (nil off the top 50) and value, and on the weekly boards weekRank and weekValue.
export type LeaderboardSync = {
	boards: { [string]: { allTime: { LeaderboardRow }, week: { LeaderboardRow }? } },
	me: { [string]: { rank: number?, value: number, weekRank: number?, weekValue: number? } },
	week: number,
}

-- Quests and achievements (F73, quests.md section 6). A quest row in Catalog.quests: `stat` is the counter it
-- reads (a Stats key, "lifetimeCoins" or "distinctCats", the entries in collection), `needs` a fixed count or, for a
-- coins quest, `needsSeconds` of the day rate when it is picked and at least `needsMin`. `requires` skips it when
-- picking for a player who cannot do it yet: an upgrade's first level, a banked crate or a crate's golden fish
-- (`fishOrCrate`), or that many cats not yet found in the areas their tier has open (`uncaught`).
export type QuestKind = "daily" | "weekly"
export type QuestRequires = { upgrade: string?, fishOrCrate: boolean?, uncaught: number? }
export type QuestDef = {
	id: string,
	text: string,
	stat: string,
	needs: number?,
	needsSeconds: number?,
	needsMin: number?,
	requires: QuestRequires?,
}
-- A picked quest: its counter's value when picked (`base`) and how far past that it goes (`needs`, at least 1).
export type QuestEntry = { id: string, base: number, needs: number, claimed: boolean }
-- The player's quests: the UTC day and the Monday-start week they were rolled for, the slots in pool order, whether
-- the free reroll is spent and whether the full set's prize is paid.
export type QuestState = {
	day: number,
	daily: { QuestEntry },
	dailyReroll: boolean,
	dailySet: boolean,
	week: number,
	weekly: { QuestEntry },
	weeklyReroll: boolean,
	weeklySet: boolean,
}
export type AchievementSize = "S" | "M" | "L" | "XL"
-- `measure`: a Stats key, "lifetimeCoins", "tier", "distinctCats", "goldCats", "mythicalCats", "decorOwned",
-- "topCatLevel" or "upgrade:<upgradeId>".
export type AchievementDef = {
	id: string,
	name: string,
	text: string,
	measure: string,
	needs: number,
	size: AchievementSize,
}
-- ProfileSync's quests: each slot's text, progress and claim, the reset times (os.time()) and what is spent.
export type QuestView = {
	id: string,
	text: string,
	progress: number,
	needs: number,
	claimed: boolean,
}
export type QuestsView = {
	daily: { QuestView },
	weekly: { QuestView },
	dailyResetsAt: number,
	weeklyResetsAt: number,
	dailyRerollUsed: boolean,
	weeklyRerollUsed: boolean,
	dailySetClaimed: boolean,
	weeklySetClaimed: boolean,
}
-- ProfileSync's achievements: each one's progress (capped at its needs) and whether it is claimed.
export type AchievementView = { progress: number, claimed: boolean }

-- The cat on its way to the bait bowl, rolled when the food goes in so a rejoin cannot reroll it (section 8).
export type BaitState = {
	lureId: string,
	placedAt: number, -- os.time()
	-- os.time() the cat comes, fixed when the food goes in (F54: the wait less the Index's bait speed), so a later
	-- claim or perk never moves a filling bowl; nil on saves from before it, which wait LureWaitSeconds
	readyAt: number?,
	night: boolean?, -- F60: the food went in at night, so readyAt is the shorter night wait; nil by day
	catId: string,
	variant: string,
	charm: number,
}

-- The second bowl for a player (#1161, Bait.secondBowl): "on" with the pass, "offer" without it (the Store shows it).
export type SecondBowl = "on" | "offer"

-- The bowl as ProfileSync sends it: the food and when its cat arrives. `cat` is only there once it has arrived,
-- so the roll is not spoiled before then (reviewer N30).
export type BaitView = {
	lureId: string,
	placedAt: number, -- server os.time(); with readyAt, the fill bar's length (F54: the wait is fixed at placement)
	readyAt: number, -- server os.time()
	night: boolean?, -- F60: night bait (half the wait); the bowl countdown shows a moon
	cat: { catId: string, variant: string, charm: number, stars: number }?,
}

-- What the Fresh Catch shelf sold this player (F94, rewards-and-shops.md section 6; the shape the night dealer saved
-- before F94): how many of each row, by row id, in the window FreshCatch.window(os.time()) (a game day since #1437),
-- and the last window a ShopAlert went to them, so a rejoin in the same window never alerts twice.
export type FreshCatchState = {
	window: number,
	bought: { [string]: number },
	alerted: number,
}

-- The camp extras (F100, camp-extras.md): one at each camp from the Park on, opening with its area. `kind` "collect"
-- fills by itself and is taken with CollectCampExtra; "shop" (the Yard Sale) sells crates for golden fish.
export type CampExtraDef = {
	id: string, -- "picnic", "yardSale", "pond" or "lostFound"
	area: string,
	name: string,
	model: string, -- CatCafe_Camp_<Area>_<Name> (Model-Agent #750)
	kind: string, -- "collect" or "shop"
}

-- The front lawn (F91, front-lawn.md): a lawn spot's size, and the pieces and styles bought for it with coins
-- (Catalog.lawn, Catalog.lawnStyles). `tier` is the tier that sells it; `model` is Model-Agent's (#673, style guide
-- section 13): CatCafe_Lawn_<Piece>, CatCafe_Lawn_Path_<Style> or CatCafe_Lawn_Fence_<Style>.
export type LawnSize = "small" | "big"
-- lawn-nursery.md section 1 (#1200): Uncommon and Golden are lawn-only rungs
export type LawnRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythical" | "Golden"
export type LawnPieceDef = {
	id: string,
	name: string,
	spot: LawnSize,
	tier: number,
	rarity: LawnRarity,
	price: number,
	model: string,
}
export type LawnStyleKind = "path" | "fence"
export type LawnStyleDef = {
	id: string,
	name: string,
	kind: LawnStyleKind,
	tier: number,
	rarity: LawnRarity?, -- nil only for the free Grey Slabs
	price: number, -- 0: every cafe has it (Grey Slabs)
	model: string,
}
-- A lawn spot (shared/Lawn.SPOTS, Layout.plot.lawnSpots) in plot space: the base centre of its piece on the grass
-- top, front -Z to the street, and the tier that opens it.
export type LawnSpot = {
	id: string,
	size: LawnSize,
	tier: number,
	x: number,
	y: number,
	z: number,
	rotY: number,
}
-- The path and fence in use (save version 28): a path style id, and a fence style id or nil for no fence.
export type LawnStyles = { path: string, fence: string? }

-- What the camp extras hold (section 4, save version 25), all times server os.time(): the Picnic Basket's potions
-- and when the next started filling; the Yard Sale's last take (0 for never) and how many it has given (save version
-- 33, #1154; it picks the next crate); the Fish Pond's fill start (its fish follow from the time); the Lost and Found's last settled UTC day and its
-- prizes waiting. Settled on load and every few seconds (shared/CampExtras.settle).
export type CampExtrasSave = {
	picnic: { at: number, held: number },
	yardSale: { lastClaimAt: number, claims: number },
	pond: { at: number },
	lostFound: { day: number, held: number },
}

-- One of the Yard Sale's crates today: its crate id, its price in golden fish and whether this player bought it.
export type YardSaleCrate = { crateId: string, price: number, bought: boolean }

-- One extra as CampExtrasState sends it: `open` when the player's tier has its area; `held` what waits (potions,
-- golden fish, prizes; for the Yard Sale the crates left to buy today); `nextAt` (server time) the next fill or the
-- next day's stock, nil while full or shut; `stock` the Yard Sale's crates today.
export type CampExtraView = {
	open: boolean,
	held: number,
	nextAt: number?,
	stock: { YardSaleCrate }?,
	decor: { YardDecorRow }?, -- #1537: the Yard Sale's lawn rows today (shared/YardSale)
	decorAt: number?, -- #1537: when the Yard Sale's next lawn stock arrives (server time), the next sunrise
}

-- Saved (version 35, #1537): the global game day the Yard Sale rows were bought on, and those ids.
export type YardDecorState = { day: number, bought: { [string]: boolean } }
-- One Yard Sale lawn row as CampExtrasState sends it: a piece or style id, its name, rarity, fixed coin price and the
-- tier that opens it; `bought` today (or the server is behind the saved day), `owned` already.
export type YardDecorRow = {
	id: string,
	name: string,
	rarity: LawnRarity,
	price: number,
	tier: number,
	bought: boolean,
	owned: boolean,
}

-- CampExtrasState (server to client): every extra's view by id, and the UTC day it was worked out on.
export type CampExtrasState = {
	day: number,
	picnic: CampExtraView,
	yardSale: CampExtraView,
	pond: CampExtraView,
	lostFound: CampExtraView,
}

-- The Rescue Rally (F101, rescue-rally.md section 5). The save keeps the weekend number (Rally.weekend) and the laps
-- this player has been paid prizes from in it, at most RallyMaxLaps; the bar itself is the server's.
export type RallySave = {
	weekend: number,
	laps: number,
}

-- One step of the bar: at `share` of the goal (0.25, 0.5, 1) every player in the server who scored RallyMinPoints this
-- lap gets `prize` (the Index prize shape).
export type RallyStep = {
	share: number,
	prize: IndexPrize,
}

-- RallyState (server to client): `active` while a Rally runs, `endsAt` (os.time()) when it ends, 0 when not running;
-- `startsAt` when the next one starts (the running one's start while active); the server's `lap` (1 up), its `goal`
-- and `points`; this player's `myPoints` this lap, `lapsPaid` this weekend and `lapsDone`, true when they can earn
-- nothing more this lap ("You've done your laps this weekend").
export type RallyState = {
	active: boolean,
	endsAt: number,
	startsAt: number,
	lap: number,
	goal: number,
	points: number,
	myPoints: number,
	lapsPaid: number,
	lapsDone: boolean,
}

-- One row of the Fresh Catch shelf (F94, section 3): a potion, or now and then a cheaper Classic Crate, for golden
-- fish. `alert` rows send a ShopAlert when a window stocks them. The row's id is its potion's or crate's id.
-- One item on the cafe menu (F90, cats-make-orders.md section 1): opened at `tier`, made at its station ("espresso",
-- "oven" or "counter") in makeSeconds, shown as its model CatCafe_Menu_<model> on a plate and as `icon` (an
-- rbxassetid once the render is uploaded) or `glyph` until then. Client only: the server never sees an order.
export type MenuItem = {
	id: string,
	name: string,
	tier: number,
	station: string,
	makeSeconds: number,
	model: string,
	icon: string?,
	glyph: string,
}

export type FreshCatchRow = {
	id: string,
	kind: "potion" | "crate",
	potionId: string?,
	crateId: string?,
	fish: number,
	alert: boolean?,
}

-- One player's Fresh Catch stock as FreshCatchStock sends it (F94, section 6): every row in shelf order with the
-- window's amount and how many of it this player bought; `window` is what BuyFreshCatch sends back, restocksAt is
-- os.time().
export type FreshCatchItem = { itemId: string, fish: number, amount: number, bought: number }
export type FreshCatchStock = { window: number, restocksAt: number, stock: { FreshCatchItem } }

-- The Corner Shop (corner-shop.md, #1052): sold for coins only.
-- v2 (corner-shop-v2.md section 4, #1180): every row sold for coins at a fixed `price`, in a `family` (its daily limit
-- counts the family, Config.CornerDailyLimits) and a `size` (Big and Mega rows are tier gated). A
-- "potion" row gives `potionId` into the bag, a "food" row `foodId` into the Bag's cat food (its `xp` is that food's)
-- and a "show" row played `showId` over the buyer's cafe (retired with the Bubble Machine and Cafe Fireworks, #1381; the
-- kind and its fields go once Effects/CafeShow and CornerShopLogic stop reading them). `needsTier` hides and refuses
-- the row below that tier. #1281 (section 1b): a "bait" row sells the bowl food `lureId` into `lures` at its
-- tier-scaled price (CornerShop.priceOf, so `price` is only its Tier 1 price).
export type CornerShopSize = "small" | "regular" | "big" | "mega"
export type CornerShopRow = {
	id: string,
	name: string,
	family: string,
	size: CornerShopSize,
	kind: "potion" | "food" | "show" | "bait",
	price: number,
	potionId: string?,
	foodId: string?,
	lureId: string?, -- #1281: a "bait" row's bowl food
	xp: number?,
	showId: string?,
	showSeconds: number?,
	needsTier: number?,
}
-- Saved (version 32): the window the bought counts belong to, and on UTC day `day` each family's buys (`today`) and
-- the cat food XP bought (`foodXpToday`).
export type CornerShopState = {
	window: number,
	bought: { [string]: number },
	day: number,
	today: { [string]: number },
	foodXpToday: number,
}
-- One row as CornerShopStock sends it. The daily limits stay on the server and show only as a refusal toast (#1190).
export type CornerShopItem = {
	itemId: string,
	price: number,
	amount: number,
	bought: number,
	size: CornerShopSize,
	needsTier: number?,
	outToday: boolean?, -- #1435: true when the row's family has hit its daily limit today; nil otherwise
}
-- What CornerShopStock sends: the window, when it restocks, each row in Catalog order, and the cat food XP bought
-- today (`snackXp`, its v1 name, which the window reads).
export type CornerShopStock = {
	window: number,
	restocksAt: number,
	stock: { CornerShopItem },
	snackXp: number,
}

-- The onboarding funnel's place (data-model section 14, growth analytics-plan 3.2): the last step logged, and later
-- steps already done but held back until every step before them is logged. Keys are step numbers (JSON-shaped).
export type TelemetryState = {
	onboardingStep: number,
	achieved: { [string]: boolean },
	-- F87 (easy-start.md sections 5 and 6): the onboarding funnel's version (3 since #1273; Onboarding.fromOld moves a
	-- 1 or 2) and the UTC day number (os.time() // 86400) of the account's first join, 0 when it is not known (an
	-- account from before version 19), for new_player_left and the session time markers
	funnel: number,
	firstDay: number,
	-- #1273: the furthest step logged of the intro funnel (Onboarding.INTRO_STEPS), 0 before any. A field inside
	-- telemetry with a default, so it needs no save version
	introStep: number,
}

-- One player's dealer stock as DealerStock sends it: every dealer food in Dealer.FOODS order with tonight's amount
-- (0 shows "None this time") and how many of it this player bought tonight. F94 (rewards-and-shops.md section 4):
-- one stock per server per night; `night` is the server's night count, which BuyDealerFood sends back (was a 5
-- minute `window` and its `restocksAt`).
export type DealerFood = { lureId: string, cost: number, amount: number, bought: number }
export type DealerStock = { night: number, stock: { DealerFood } }

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
	shopAlerts: boolean, -- F94: the Fresh Catch's ShopAlert (FreshCatch.alertsOn)
	tradeRequests: string, -- F102: who may ask to trade, "everyone", "friends" or "off" (Settings.choices)
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
	-- #1574 (trading.md section 1b, no save version bump): the Legendary and up pieces (crate decor and lawn pieces) the
	-- player unlocked on their card to trade; every other such piece is locked (Trade.pieceLocked)
	decorUnlocked: { [string]: boolean },
	lures: { [string]: number },
	bait: BaitState?,
	bait2: BaitState?, -- #1161: the Second Bait Bowl's bait (save version 34), nil when that bowl is empty
	freshCatch: FreshCatchState, -- F94 (save version 18; the dealer's saved counts went with it)
	cats: { [string]: CatInstance },
	collection: { [string]: number },
	goldCollection: { [string]: number }, -- catId -> first gold caught at
	rainbowCollection: { [string]: number }, -- F99: catId -> first rainbow caught at (save version 24)
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
	potions: { [string]: number }, -- F64: potionId -> count in the bag
	-- F64: potionId -> seconds of play time left. The timers run only while the player is in the game, so settle
	-- counts them down with the elapsed time it pays (Economy.settle) and nothing runs them down offline.
	buffs: { [string]: number },
	quests: QuestState, -- F73
	achievements: { [string]: boolean }, -- F73: achievementId -> claimed
	dailyTreat: DailyTreatState, -- F70
	stats: Stats,
	tutorialStep: number,
	settings: Settings,
	flags: { autoPress: boolean }, -- for review only: set when the last 50 circles look scripted (section 10)
	telemetry: TelemetryState,
	-- F87 (easy-start.md section 6, save version 20): the context tips seen (tip id or an ask's id to true; ClearTips
	-- keeps only the asks), the one slide-in feedback ask, and the "Need a hand?" card's tutorial steps ("0" to "5")
	tipsSeen: { [string]: boolean },
	feedbackAsked: boolean,
	stuckHelpShown: { [string]: boolean },
	starterCatClaimed: boolean, -- F96 (starter-cat.md section 4, save version 21): the free Bellhop Cat taken home
	notifyAskAt: number, -- F96 (section 3, save version 22): os.time() the notification ask first showed, 0 before
	campExtras: CampExtrasSave, -- F100 (camp-extras.md section 4, save version 25)
	rally: RallySave, -- F101 (rescue-rally.md section 5, save version 26)
	-- F102 (trading.md sections 4 and 5, save version 27): the last TradeLogMax trades for the Trades page, and the ids
	-- of the last TradeIdsMax trades applied to this save, so a trade pending after a shutdown is applied only once
	tradeLog: { TradeLogEntry },
	tradeIds: { string },
	-- F91 (front-lawn.md section 5, save version 28): the lawn pieces and styles bought or given (id to true), the
	-- piece on each lawn spot (spot id to piece id) and the path and fence in use
	lawnOwned: { [string]: boolean },
	lawn: { [string]: string },
	lawnStyles: LawnStyles,
	cornerShop: CornerShopState, -- #1052 (corner-shop.md section 5, save version 29; v2 counters version 32)
	yardDecor: YardDecorState, -- #1537 (lawn-nursery.md section 7, save version 35): the Yard Sale rows bought today
	catFood: { [string]: number }, -- #1181 (corner-shop-v2.md section 3, save version 32): food id -> count in the Bag
	hideCredit: boolean?, -- #1083 (idea-credits.md section 4, save version 30): true keeps the name off the Thank You board
	receipts: { string }, -- #1182 (save version 31): the newest Products.RECEIPT_LIMIT developer product PurchaseIds granted
	-- #1625 (save version 35): the once-per-account products already bought (product id -> true), the saved sign
	-- styles owned (SignStyles id -> true; pass styles are not saved) and the sign's pick (nil: the plain sign)
	onceBought: { [string]: boolean },
	signStyles: { [string]: boolean },
	signStyle: string?,
	pass: PassState, -- #1645 (save version 36): the Cafe Pass
	looks: LookPicks, -- #1624 (save version 38): the cafe theme and uniform picks (shared/Looks)
}

-- What ProfileSync sends. Matches ui-contract PlayerState plus a few extras the controller uses.
-- F88 (luck-and-rare-moments.md 1d): a source of Luck for the chip's card: "statue", "potion" or "lucky_day", what it
-- adds, and when it ends (os.time()) for the potion and the Lucky Day.
export type LuckSource = { id: string, value: number, endsAt: number? }

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
	decorUnlocked: { [string]: boolean }, -- #1574: the Legendary and up pieces unlocked to trade
	lures: { [string]: number },
	bait: BaitView?, -- nil when the bowl is empty
	bait2: BaitView?, -- #1161: the second bowl's, nil when it is empty
	secondBowl: SecondBowl?, -- #1161: "on" (the pass: bowl 2 takes food) or "offer" (show the pass in the Store)
	-- extras (not in the UI contract, used by the client controller)
	cats: { [string]: CatView },
	collection: { [string]: number },
	goldCollection: { [string]: number },
	rainbowCollection: { [string]: number }, -- F99
	indexRewards: { [string]: { [string]: boolean } }, -- F48
	spin: SpinState, -- F49
	goldenFish: number, -- F52
	crates: { [string]: number }, -- F53
	crateLuck: { [string]: number },
	fishPerks: { [string]: number },
	goldLuck: number, -- F54: the Index gold track's summed luck, capped at GoldLuckMax
	rainbowLuck: number, -- F99: the Index Rainbow track's summed luck, capped at RainbowLuckMax
	baitSpeed: number, -- F54: the All Cats track's summed bait speed, capped at BaitSpeedMax
	plotIndex: number,
	carrying: string?, -- catId while carrying a caught stray home
	dataSaves: boolean,
	tutorialStep: number,
	introSeen: boolean, -- F72: false plays the intro cutscene once this session's first sync carries a plot
	potions: { [string]: number }, -- F64: potionId -> count in the bag
	catFood: { [string]: number }, -- #1181: food id -> count in the Bag
	hideCredit: boolean, -- #1083: true while the player keeps their name off the Thank You board (SetHideCredit)
	buffs: { [string]: number }, -- F64: each running potion's endsAt in server time (Workspace:GetServerTimeNow())
	settings: Settings, -- the Settings screen follows these; Audio mutes and sets its channels by them
	quests: QuestsView, -- F73: the Quests window's Daily and Weekly tabs and the HUD tracker
	achievements: { [string]: AchievementView }, -- F73: every Catalog.achievements id
	dailyTreat: DailyTreatView, -- F70: the Daily Treat window's card and the HUD button's dot
	stats: Stats, -- F73
	-- F87: the client skips a tip, the slide-in ask or the help card it finds here (section 3, 4 and 2g)
	tipsSeen: { [string]: boolean },
	feedbackAsked: boolean,
	stuckHelpShown: { [string]: boolean },
	starterCatClaimed: boolean, -- F96: the Bellhop Cat's stand card reads "Already home with you"
	starterBought: boolean, -- #1625: the Starter Bundle is bought, so its Store card hides
	codesRedeemed: { [string]: number }?, -- #1714: code id -> os.time() redeemed, for the Store's Codes tab
	signStyles: { string }, -- #1625: every sign style owned (SignStyles.owned), saved or through a pass
	signStyle: string?, -- #1625: the pick SetSignStyle saved, nil for the plain sign
	looks: LooksView, -- #1624: the Style tab's theme and uniform rows (shared/Looks), SetLook
	luck: number, -- F88: the player's Luck now (shared/Luck), x1 to LuckMax; the HUD chip shows it above 1
	luckSources: { LuckSource }, -- F88: what adds it, in order (statue, potion, lucky_day)
	-- F95 (economy-ladder.md section 5): the Long Nap pass is owned, so the welcome back card says full pay up to
	-- OfflineCapPassSeconds instead of half pay up to OfflineCapSeconds
	longNap: boolean,
	-- #1624: what the store passes give, for the money card's Boosts list: `cafe` added into the cafe bonus (VIP,
	-- Cafe Style, Grand Cafe), `staff` the working cats' multiplier (Accessories, Uniforms), `rich` how many times as
	-- often rich visitors come, `money` the Money pass multiplier
	passBoosts: PassBoostsView,
	extraSlots: number?, -- #1624: role slots past the tier's own (Catalog.slotIsOpen), from Grand Cafe and Extra Slot
	tradeLog: { TradeLogEntry }, -- F102: the Trades page, newest first
	-- F91: the Decor screen's Front lawn tab (what is owned, on each spot and in use); the street reads the plot's
	-- Lawn_<spotId>, LawnPath and LawnFence attributes instead
	lawnOwned: { [string]: boolean },
	lawn: { [string]: string },
	lawnStyles: LawnStyles,
	serverTime: number,
}

return {}
