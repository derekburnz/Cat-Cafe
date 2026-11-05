--!strict
-- Tuning constants for Cat Cafe (docs/design/cat-cafe/data-model.md section 17 plus world layout).
-- Pure data: no Roblox services, so tests can require it. Nothing numeric lives in a Service.
-- Distances are studs, times are seconds, money is coins.

local Config = {
	ServerPlayers = 8,
	StartCoins = 50,

	-- Income (data-model section 11)
	FavoriteMultiplier = 1.5,
	TableBonus = 0.10,
	EspressoBonus = 0.15,
	-- Coming back (F95, economy-ladder.md section 5; Derek 2026-11-01 22:32: "do 50% offline and pass makes it 100% and
	-- up to 16h"): half the day rate for up to 8 hours away, the full rate for up to 16 with the Long Nap pass.
	OfflineRate = 0.5,
	OfflineCapSeconds = 28800,
	OfflineRatePass = 1.0,
	OfflineCapPassSeconds = 57600,
	-- Game pass ids for F95's hooks (section 6); 0 until Tools-Agent makes the pass, which turns its effect off. The
	-- Money passes by the income they multiply by (the highest owned counts); each extra slot pass adds a role slot.
	-- Tools-Agent made the four in tools/opencloud/passes.json on 2026-11-02 (off sale until launch), and the rest on
	-- 2026-11-04 as off-sale placeholders (#1197). Each stays off sale until the code that grants it is merged; the
	-- Store cards (#1240) read the ids, and PassService already grants the extra slot to an owner.
	LongNapPassId = 2064345084,
	MoneyPassIds = { [2] = 2064604577, [3] = 2064670602, [4] = 2064357148 } :: { [number]: number },
	ExtraSlotPassIds = { 2066816325 } :: { number },
	VipPassId = 2072030274,
	CatAccessoriesPassId = 2068634239,
	UniformStylesPassId = 2071522382,
	CafeStylePassId = 2070044168,
	GrandThemePassId = 2071158673,
	RoyalCatPassId = 2066438426,
	KingPackPassId = 2071368679,
	GoldenPondPassId = 2071704337, -- #1232
	SecondBowlPassId = 2072132265, -- #1161
	-- Developer product ids (#1182) by Catalog.products id; a 0 is never granted. ProductService's ProcessReceipt reads
	-- them. Tools-Agent made these with dev-products.yml on 2026-11-04 (tools/opencloud/products.json), off sale until
	-- launch. The Starter Bundle (3728336166) and Cafe Pass (3728336202) products exist too, off sale, and join this
	-- table with their Catalog.products entries.
	ProductIds = {
		potion_pack_xs = 3728336174,
		potion_pack_s = 3728336184,
		potion_pack_m = 3728336191,
		potion_pack_l = 3728336197,
	} :: { [string]: number },
	AutosaveSeconds = 60,
	SyncIntervalSeconds = 10, -- periodic ProfileSync even when nothing changed (the client predicts in between)

	-- Cat stats (data-model section 4b; v0.12 F75 makes levels a long, slow climb)
	CatMaxLevel = 50,
	CatLevelBonus = 0.02, -- rate bonus per level above 1, so level 50 is 1.98x
	CatXpBase = 120, -- XP from level n to n + 1 is CatXpBase x n; level 10 after 90 min working, 50 after about 41 h
	CatXpPerSecondPlaced = 1, -- XP a working cat earns per second while its owner is in the game (Economy.settle)
	CatXpFavoriteMultiplier = 1.5, -- a working cat in its favorite role earns this many times as much XP
	CatXpPerSecondResting = 0.25, -- XP a resting cat earns per second while its owner is in the game
	CharmSpread = 0.20, -- charm 0 earns 1 - spread, charm 100 earns 1 + spread
	GoldMultiplier = 1.5, -- a gold cat's rating (data-model section 4)
	-- Keep up (v0.13.16, F86, data-model 4b): a cat of these rarities from an older area earns with the incomeMultiplier
	-- of the area opened KeepUpStepsBehind tiers before the owner's newest, never below its own area's. F95
	-- (economy-ladder.md section 2): none, since the area ladder itself makes an older Mythical worth a newer Legendary;
	-- the code stays for the shop-only cats and for config.
	KeepUpRarities = {} :: { [string]: boolean },
	KeepUpStepsBehind = 1,

	-- The clock (data-model section 9): a server-wide loop of day then night. v0.9 (F66, Derek 2026-10-27): night is a
	-- short reset between hunts; the catching areas close at dusk and a fresh wave spawns at sunrise.
	DayLengthSeconds = 300,
	NightLengthSeconds = 90,
	ServerStartDaySeconds = 300, -- the clock's first day, from ClockEpoch (was each server's start, before #1437)
	-- #1437 (Derek 2026-11-05: "restock once per in game day and make it global"): every server reads the clock from
	-- this os.time() (2026-11-01 00:00 UTC) on Workspace:GetServerTimeNow(), so sunrise and dusk fall at the same
	-- moment in every server; a new server joins the day already under way. Day 1 starts here.
	ClockEpoch = 1793491200,
	DuskWarningSeconds = 15, -- players in a catching area get the "Night falls" banner this long before night
	NightSweepSeconds = 2, -- during night, anyone found in a catching area is sent home this often

	-- Strays and catching (data-model sections 9 and 10). Wave sizes live per area in Catalog.areas.
	StrayDespawnSeconds = 120, -- lifetime of a Studio debug stray; wave strays stay until the next night
	GrabRangeStuds = 10,
	-- Derek 2026-10-27: hold E this long on a stray or a stuck cat to start the minigame, so walking past one with a
	-- tap of E never starts a catch by accident
	CatchHoldSeconds = 0.5,
	GrabRetrySeconds = 2, -- after a miss nobody can start a catch on that stray for at least this long
	-- v0.5 (F40): a miss makes the stray hiss and sprint its rarity's fleeStuds away at this speed (studs per second,
	-- faster than NormalWalkSpeed), then catch its breath this long; tries are unlimited
	StrayFleeSpeed = 26,
	StrayRestSeconds = 1.5,
	-- v0.8 F57 (data-model 10 step 5, Gavin round 3 Q3): the player who missed waits this much longer than everyone
	-- else after the stray stops, by their misses in a row on it (the last step for every miss after), the streak
	-- starting again after StrayMissStreakResetSeconds without a miss; and walks at StartledWalkSpeed for
	-- StartledSeconds. StraySelfRetrySeconds is the first step, which the UI's countdown reads.
	StraySelfRetrySteps = { 3, 6, 10 },
	StraySelfRetrySeconds = 3,
	StrayMissStreakResetSeconds = 60,
	StartledWalkSpeed = 12,
	StartledSeconds = 2,
	GrabCooldownSeconds = 2, -- per player, between two catches started
	-- per player, between two fast travels (features F19); #1434 (Derek 2026-11-05): 1 (was 3), a quick anti-spam
	-- cooldown rather than a wait. A trip still never starts while a cloud hop home is under way (TravelService).
	TravelCooldownSeconds = 1,
	-- The Cat Cannon (F84, hometown-cannon.md section 3b): a flight takes CannonLaunchSeconds from LaunchCannon to
	-- control, the server moving the anchored character onto the landing pad at CannonTeleportAtSeconds, inside the
	-- clouds; then CannonCooldownSeconds from landing before the next launch. Home from a wild area is a cloud hop
	-- (section 5): CloudHopSeconds long, the move at CloudHopMoveAtSeconds. Derek 2026-11-03 ("should be much further
	-- with less summer salting"): the longer flight with Animation-Engineer's arc, 4.0 s with the move at 2.6, while
	-- the body is out of sight in the clouds (2.0 to 3.0). The flyer goes into the clouds at CannonCloudsAt and the
	-- feet touch the pad at CannonTouchdownAt, both from CannonLaunchAt, for the sounds (Sound-Agent).
	CannonLaunchSeconds = 4.0,
	CannonTeleportAtSeconds = 2.6,
	CannonCloudsAt = 2.0,
	CannonTouchdownAt = 3.5,
	CannonCooldownSeconds = 3,
	CloudHopSeconds = 1.6,
	CloudHopMoveAtSeconds = 0.6,

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
	-- the target. F93 (catch-rework.md section 2): a net only widens the bands; the number and speed of the circles
	-- come from the stray's rarity, and every circle's shrink time wobbles by up to CircleJitter either way.
	NetWindows = {
		[0] = { perfect = 0.045, good = 0.11 },
		[1] = { perfect = 0.055, good = 0.13 },
		[2] = { perfect = 0.065, good = 0.155 },
		[3] = { perfect = 0.08, good = 0.18 },
	} :: { [number]: { perfect: number, good: number } },
	CircleJitter = 0.10,
	-- The net swing (F93, catch-rework.md section 1): one SwingNet per NetSwingCooldown. NetSmackDelay after it
	-- arrives, when the net lands, the server looks for the nearest free stray within NetReachStuds plus
	-- NetSlackStuds of the root and within NetArcDegrees either side of its facing. A swing that hits nothing makes
	-- every free stray within NetMissHopStuds hop NetMissHopShare of its rarity's fleeStuds away.
	NetSwingCooldown = 0.8,
	NetSmackDelay = 0.22, -- Derek 2026-11-03 OK'd the smoother swing landing at 0.22 s (was 0.15)
	NetReachStuds = 7,
	NetSlackStuds = 1.5,
	NetArcDegrees = 60,
	NetMissHopStuds = 12,
	NetMissHopShare = 0.25,
	-- The bait bowl (data-model section 8): a cat comes LureWaitSeconds after the food goes in, online or not.
	LureWaitSeconds = 600,
	-- F60 (round 3 Q6): food that goes in while the server is in night waits this instead, the Big Bowl's in the same
	-- share (half: 240 s), fixed in bait.readyAt at placement
	LureWaitSecondsNight = 300,
	-- F82 bowl levels (v0.13.15): the day wait and the bowl luck by lure_bowl level, read by shared/Bait. Luck is the
	-- share of each rarity's chance moved up one rarity before the roll. The Big Bowl perk takes BigBowlWaitCutSeconds
	-- off any level's day wait, before night halves it (F95 section 6b, Derek 2026-10-28 17:39: "lower it by 2 min perma").
	BowlWaitSeconds = { 600, 570, 540, 510, 480 } :: { number },
	BowlLuck = { 0, 0.04, 0.08, 0.12, 0.16 } :: { number },
	BigBowlWaitCutSeconds = 120,
	-- F88 Luck (luck-and-rare-moments.md section 1): one number from x1.0 that multiplies the Epic, Legendary and
	-- Mythical chances of your bait and crate rolls (shared/Luck), at most LuckMax. The Lucky Cat statue adds
	-- LuckPerStatueLevel a level, a Lucky Potion LuckyPotionLuck while it runs, a Lucky Day LuckyDayPlayerLuck to
	-- everyone in the server until dusk. Every LuckyDayEvery-th day of a server is a Lucky Day: its sunrise wave and
	-- traps roll at LuckyDayWaveLuck, and LuckyDayWarnSeconds before its sunrise the players still in are told.
	LuckPerStatueLevel = 0.1,
	LuckMax = 3,
	LuckyPotionLuck = 0.5,
	LuckyDayEvery = 4,
	LuckyDayWaveLuck = 2,
	LuckyDayPlayerLuck = 0.5,
	LuckyDayWarnSeconds = 15,
	BaitBowlRangeStuds = 12, -- the bowl's own prompt shows from this close (UseLure works from anywhere since 2026-10-28)
	-- F97 (notes-10-28-to-10-30.md section 3): a food's price is its Catalog base times this factor at the buyer's
	-- tier (Economy.foodPrice), the same growth as the later shop items (economy-ladder.md section 4)
	FoodTierPriceFactor = { 1, 1, 4, 8, 16 } :: { number },
	-- F97 section 7: a sunrise wave with no Epic or rarer stray rerolls its last one from these odds (Catching.waveRare)
	WaveMinRareRerollOdds = { Common = 0, Rare = 0, Epic = 83, Legendary = 15, Mythical = 2 },
	GoldChanceBait = 0.05, -- v0.5 F42 (was 0.02): rolled when the food goes in, revealed when the cat arrives
	GoldChanceNet = 0.05, -- v0.5 F42 (was 0.02): rolled when a stray spawns, shown as its gold coat and sparkle
	-- The chance of 1 to 5 charm stars from CatStats.rollCharm and CatStats.stars, in percent, shown on every food
	-- card: 2s^2 and 1 - 2(1 - s)^2 at the band edges 20, 40, 60 and 80 out of 101 (reviewer N70).
	CharmStarOdds = { 7.84, 23.53, 35.67, 24.31, 8.65 } :: { number },
	CarryWalkSpeed = 16,
	NormalWalkSpeed = 20,
	-- How far the camera zooms out (Derek 2026-11-02, the zoom card: "Cap it closer (60 studs)"; Roblox's default is
	-- 128): it stays near the player, and the edges of the long areas and the backdrops stay out of view.
	CameraMaxZoomStuds = 60,
	-- The getaway after a net catch or a rescue (v0.8 F55, section 10c): every other player this close to the catcher
	-- is pushed this far away (not a shove: no drop, no cooldown, never someone in a catch or rescue), and the catcher
	-- walks at CatchRushWalkSpeed for CatchRushSeconds before carry speed. A picked-up cat gives neither.
	-- CatchRushSeconds was 5; Derek's 10-28 to 10-30 notes asked for a longer boost now the areas are bigger (F85's
	-- Park and Neighbourhood run 430 studs deep), so 10 s takes a carrier 240 studs before carry speed.
	CatchBurstRadiusStuds = 10,
	CatchBurstStuds = 8,
	CatchRushWalkSpeed = 24,
	CatchRushSeconds = 10,
	-- A carrier this near either own door, or whose path passes this near it, checks the cat in (Derek 01:22: was 8)
	CheckInRangeStuds = 10,
	StrayWanderRadius = 5,
	-- Derek 22:38: a wave is scattered, not clumped. A new stray takes a free spawn point at least this far from every
	-- stray already in its area when one is left (farther ones likelier), else the free point farthest from them all.
	StraySpawnSpacingStuds = 12,
	-- #1159 (shared/StrayTopUp): by day an area under its floor of live strays gets one more every 40 to 80 s, at a
	-- far point first. The floor is StrayFloorBase for one player plus StrayFloorPerPlayer for each more who has the
	-- area open, never above StrayLiveMax live cats in the area (the 10-28 "way too many" line is a live cap).
	StrayFloorBase = 7, -- #1452 (was 5)
	StrayFloorPerPlayer = 1,
	StrayLiveMax = 14, -- #1452 (was 12)
	StrayTopUpMinSeconds = 40, -- #1452: 40 to 80 s (was 60 to 120)
	StrayTopUpMaxSeconds = 80,
	StrayWanderSpeed = 3,
	AnnounceMinRarity = "Epic",
	-- The night dealer (data-model section 8b): buy from this close to the cart. F94 (rewards-and-shops.md section 4):
	-- each server rolls its stock once at dusk and it holds all night.
	DealerRangeStuds = 12,
	-- F94 (rewards-and-shops.md section 3): the Fresh Catch shelf at the Golden Fish Market, by day. Every window of
	-- this many seconds rolls an amount of each Catalog.freshCatch row, the same on every server. #1437: one game day
	-- (DayLengthSeconds + NightLengthSeconds) from ClockEpoch, so the shelf restocks at every sunrise (was 300).
	FreshCatchWindowSeconds = 390,
	-- The chance in percent that a window stocks 0, 1, 2 or 3 of each Fresh Catch row, by the row's id.
	FreshCatchAmountWeights = {
		tip_potion = { 10, 30, 40, 20 },
		swift_potion = { 10, 30, 40, 20 },
		steady_potion = { 30, 45, 25, 0 },
		quick_bait_potion = { 40, 45, 15, 0 },
		big_tip_potion = { 60, 35, 5, 0 },
		lucky_potion = { 60, 35, 5, 0 },
		gold_rush_potion = { 75, 25, 0, 0 },
	} :: { [string]: { number } },

	-- The Corner Shop (corner-shop.md, #1052; v2 corner-shop-v2.md, #1180; shared/CornerShop): a coins-only stall in
	-- the Town Square, open day and night. Every CornerShopWindowSeconds window rolls an amount of each
	-- Catalog.cornerShop row from its size's chance in percent of 0, 1, 2 and 3, the same on every server and apart
	-- from the Fresh Catch roll. Bought within CornerShopRange of a CornerShop stall. A UTC day allows at most
	-- CornerDailyLimits of a family (any size; a family not listed has none). Cat food has no daily XP cap (#1255).
	CornerShopWindowSeconds = 390, -- #1437: one game day from ClockEpoch, a restock at every sunrise (was 300)
	CornerShopRange = 14,
	-- lawn-nursery.md section 2 (#1200): BuyLawn from within this many studs of a LawnStall-tagged Garden Nursery
	LawnStallRange = 14,
	-- lawn-nursery.md section 6a (#1283): the money bonus of each lawn piece and style out on the lawn, by its rarity,
	-- added in Economy.cafeMultiplier beside decor. The server picks the best lawn by itself (Lawn.best).
	LawnRarityBonus = {
		Common = 0.01,
		Uncommon = 0.015,
		Rare = 0.02,
		Epic = 0.03,
		Legendary = 0.05,
		Mythical = 0.08,
		Golden = 0.12,
	} :: { [string]: number },
	-- #1577 (day-cart.md section 2): the Day Cart's roll, which replaces the size table. Row i of the list by Tier 1
	-- price (cheapest first) is in stock with max(DayCartFloor, DayCartTopChance - DayCartStep x (i - 1)), and a row
	-- in stock has 1, 2 or 3 by DayCartQtyOdds.
	DayCartTopChance = 0.95,
	DayCartStep = 0.045,
	DayCartFloor = 0.05,
	DayCartQtyOdds = { 50, 30, 20 } :: { number },
	CornerDailyLimits = { steady = 4, quick_bait = 2, whistle = 4 } :: { [string]: number },
	CatFoodMax = 999, -- the most of one food the Bag holds
	-- corner-shop-v2.md section 3 (#1181): a net catch of a stray drops a Small Snack 1 time in 10 (free, from play,
	-- and its chance shows in the catch help), and every cat rescued from a trap gives one
	CatchSnackChance = 0.10,
	RescueSnack = "small_cat_snack",

	-- Rescue minigames (data-model section 10b)
	RescueSpawnChance = 0.6, -- per trap at each night start
	RescueMinStuck = 1, -- stuck cats every area gets at night start even when no trap rolled one
	-- The bar per rarity: the marker's speed in bar lengths per second, the zone's width as a fraction of the bar.
	-- v0.13.15 F83 (harder rescues): 0.2 a second faster and narrower zones for every rarity.
	RescueBarSpeed = {
		Common = 1.0,
		Rare = 1.2,
		Epic = 1.4,
		Legendary = 1.6,
		Mythical = 1.8,
	} :: { [string]: number },
	RescueZoneWidth = {
		Common = 0.26,
		Rare = 0.20,
		Epic = 0.15,
		Legendary = 0.12,
		Mythical = 0.10,
	} :: { [string]: number },
	RescueTolerance = 0.03, -- of the bar, either side of the zone
	-- F93 (catch-rework.md section 4): the marker gets RescueSpeedUpPerHit faster after every hit. Derek 2026-11-03
	-- ("a little confusing"): the zone stays where it is until it is hit (no more running out after two sweeps), and
	-- RescueTreeCircle false ends a tree on its last shake like any bar, with no falling cat's catch circle after it.
	RescueTreeCircle = false,
	RescueSpeedUpPerHit = 0.08,
	RescuePatience = 3, -- misses one attempt can take
	RescueRetrySeconds = 3, -- after a failed attempt, before anyone else can try that trap
	RescueSelfRetrySeconds = 6, -- and before the player who failed can try it again
	RescueAttemptMaxSeconds = 15,
	GoldChanceRescue = 0.10, -- rolled at night start, hidden until the rescue succeeds
	RescuedTipsMultiplier = 1.0, -- v0.3: a rescue pays no more; its reward is the higher gold chance

	TutorialGuaranteedStrayStep = 2, -- players below this tutorialStep always find a Common stray at alley point 1
	-- F87 (easy-start.md section 2): the intro waits for the Tutorial tile instead of playing by itself (true restores
	-- the F72 behaviour), and a player below TutorialGuaranteedStrayStep catches their own tutorial stray on one slow
	-- circle with bands TutorialWindowScale times as wide; a Miss brings the circle back after TutorialRetrySeconds
	-- with no sprint, and nobody else can catch it. Below TutorialGuaranteedStrayStep nobody can tackle them either.
	IntroAutoPlay = false,
	TutorialShrinkSeconds = 1.6,
	TutorialWindowScale = 2,
	TutorialRetrySeconds = 1.0,
	-- F87 (easy-start.md sections 2g, 3 and 4): the hint pulses after StuckNudgeSeconds on one tutorial step and the
	-- "Need a hand?" card shows after StuckHelpSeconds (once per step per account); a context tip shows at most once
	-- every TipGapSeconds, a camera cut lasts at most TipCutMaxSeconds, and the one slide-in feedback ask waits for
	-- FeedbackAskMinutes of play in a session. The client times all of these. The server sends a tip that follows
	-- from the save TipStartSeconds after a join at the earliest, and takes FeedbackSessionLimit SendFeedback calls a
	-- session.
	StuckNudgeSeconds = 40,
	StuckHelpSeconds = 90,
	TipGapSeconds = 60,
	TipCutMaxSeconds = 4,
	FeedbackAskMinutes = 12,
	TipStartSeconds = 10,
	FeedbackSessionLimit = 5,

	-- Night income and rich customers (F31, data-model sections 11 and 12)
	-- tips pay this share of the day rate at night; offline pay keeps the day rate. F60 (round 3 Q6): full pay, the
	-- cafe still closed with its cats asleep (v0.5 to v0.8 paid 0.6)
	NightIncomeMultiplier = 1,
	-- #1135: a rich customer comes when the cafe's timer, drawn from RichEveryMin to RichEveryMax seconds of open day,
	-- runs out (shared/VisitTimer); 600 on average, as the old 60 s check at 10% gave
	RichEveryMin = 300,
	RichEveryMax = 900,
	RichTipSeconds = 120, -- a rich tip is this many seconds of the day rate (at least $50; F61: was 45)
	RichTipStaySeconds = 90, -- unclaimed, it is gone after this (Derek 2026-10-28: "if you miss it you miss it")
	RichTipRangeStuds = 12, -- ClaimRichTip from this close to the plot's RichTipAnchor
	-- Tip piles (F61, data-model section 12, round 3 Q6): by day, every TipPileSeconds each earning cafe with a table
	-- gets a pile worth TipPileRateSeconds of the day rate (at least $5). Since F97 (notes-10-28-to-10-30.md section 1)
	-- a pile pays its owner the moment it appears, wherever they are; it shows on a table for TipPileShowSeconds and
	-- at most TipPilesMax show at once (in your own cafe F90's Waiter sweeps them to the till).
	TipPileSeconds = 30,
	TipPileRateSeconds = 6,
	TipPilesMax = 6,
	TipPileShowSeconds = 90,

	-- The Mystery Visitor and potions (F64, data-model section 12b). Potions are earned only, never sold.
	-- #1135: on a timer from MysteryEveryMin to MysteryEveryMax seconds of open day (1500 on average, as 120 s at 8%)
	MysteryEveryMin = 900,
	MysteryEveryMax = 2100,
	MysteryStaySeconds = 120, -- the hooded visitor sits this long; dusk or a plot release sends it home sooner
	MysteryGiftKeepSeconds = 600, -- an unopened gift is gone after this, or when its owner leaves (Derek 01:32)
	MysteryRangeStuds = 12, -- OpenMysteryGift from this close to the gift
	-- The Cat Collector (F63, data-model section 12b, round 3 Q6): by day, each earning cafe with a table and a
	-- resting, unlocked cat has him when its timer runs out (#1135: CollectorEveryMin to CollectorEveryMax seconds of
	-- open day, 1000 on average as the old 120 s check at 12% gave); he waits at the counter for CollectorStaySeconds. He values the cat he asks for at CollectorValue by its rarity, times
	-- CollectorGoldMultiplier for a gold cat, times a roll from CollectorRollMin to CollectorRollMax, and offers the
	-- best Catalog.collectorOffers row that value reaches.
	CollectorEveryMin = 600,
	CollectorEveryMax = 1400,
	CollectorStaySeconds = 180,
	VisitRetrySeconds = 15, -- #1135: a visitor whose timer ran out while the cafe was not ready tries again this often
	CollectorValue = { Common = 1, Rare = 3, Epic = 8, Legendary = 20, Mythical = 50 } :: { [string]: number },
	-- #1144: how much more often he asks for each askable catId by its rarity (Collector.pickCat), so a player's few
	-- rarer resting cats come up often for the bigger offers, not one time in many among their commons
	CollectorAskWeight = { Common = 1, Rare = 3, Epic = 5, Legendary = 6, Mythical = 6 } :: { [string]: number },
	CollectorGoldMultiplier = 3,
	CollectorRollMin = 0.8,
	CollectorRollMax = 1.5,
	CollectorRangeStuds = 12, -- AnswerCollector from this close to him (his card opens there)
	PotionMaxMinutes = 1440, -- one kind's time left never goes over this; a drink that would is refused (v0.13.8; F95: 24 h, Derek 2026-10-28 17:36)
	TipPotionBonus = 0.25, -- tip_potion: +25% on income, the tip piles and rich visitors
	SwiftPotionSpeed = 4, -- swift_potion: added to walk and carry speed
	LuckyPotionGoldScale = 2, -- lucky_potion: food set in the bowl rolls gold at this times the chance
	TimedTipsMax = 1.0, -- F73: every running tip potion together adds at most +100% (a Tip and a Big Tip: +75%)
	-- Pals (F92, playing-together.md section 2): tips (the money per second, piles and rich visitors) earn PalTipBonus
	-- more with one pal on the server and PalTipBonusStep more for each more, at most PalTipBonusMax (#1165: +10%, +15%,
	-- +20% from three, #1347), on top of the potions; never offline pay
	PalTipBonus = 0.10,
	PalTipBonusStep = 0.05,
	PalTipBonusMax = 0.20,
	-- Team Rescue (F92, playing-together.md section 3): one helper an attempt, within TeamRescueRangeStuds of the trap; a
	-- helped attempt runs TeamRescueExtraSeconds longer, and the helper's tip is HelperTipSeconds of their own day rate
	-- (twice that between pals), at most once per TeamRescueTipCooldown seconds a player
	TeamRescueRangeStuds = 10,
	TeamRescueExtraSeconds = 5,
	HelperTipSeconds = 60,
	TeamRescueTipCooldown = 120,

	-- Leaderboards (F98, leaderboards.md section 5): each player's values written every LeaderboardWriteSeconds (and on
	-- join, rank up and leave, when changed), never in Studio or with LeaderboardWrites off; every list's top
	-- LeaderboardSize read every LeaderboardRefreshSeconds; the town boards show LeaderboardBoardRows and swap to the
	-- week every LeaderboardFaceSwapSeconds; the top LeaderboardCrownRank of an all-time board wear the crown
	LeaderboardWrites = true,
	LeaderboardWriteSeconds = 300,
	LeaderboardRefreshSeconds = 120,
	LeaderboardSize = 50,
	LeaderboardBoardRows = 10,
	LeaderboardRateMax = 10000000,
	LeaderboardCrownRank = 10,
	LeaderboardFaceSwapSeconds = 15,

	-- Quests and achievements (F73, quests.md section 6). Pure rules in Quests. A day starts at 00:00 UTC; a week
	-- at Monday 00:00 UTC, QuestWeekOffsetSeconds after the epoch's Thursday. Players in the game are checked for a
	-- new day or week every QuestRollCheckSeconds.
	QuestDailyCount = 5,
	QuestWeeklyCount = 3,
	QuestWeekOffsetSeconds = 345600,
	QuestRollCheckSeconds = 60,
	-- Claim all (Derek 2026-10-28 and 10-29): the server has ClaimAll (ClaimAllService), so the UI shows its Claim all
	-- buttons in the Quests window, the Index and the Tip Jar
	QuestClaimAll = true,
	IndexClaimAll = true,
	TipJarClaimAll = true,

	-- Bedtime (F79, data-model sections 12c and 17): at night the working cats walk from their stations to the cat
	-- trees and beds and sleep, and walk back at sunrise. Pure rules in Bedtime, the walk in BedtimeService.
	CafeCatWalkSpeed = 6, -- studs per second
	BedtimeStaggerSeconds = 0.3, -- the wait per place in the sleep order, at the night start and at sunrise
	BedtimeStretchSeconds = 1, -- from the get-up stretch (StretchAt) to the first step
	HopSeconds = 0.45, -- one hop onto or off a pedestal, a bed or the counter
	HopMaxRise = 2.6, -- the most a hop climbs, so the top perch takes two
	BedtimeTimeoutSeconds = 15, -- a cat still on its way after this is placed on its spot or station

	-- The Spin Wheel station (F49, data-model section 11c). Pure rules in Spin.
	SpinStationRange = 14, -- SpinWheel from this close to a station tagged SpinWheel
	SpinCooldownSeconds = 4, -- the spin animation; a player's next spin waits this long
	SpinAllMax = 51, -- #1078: Use all spends at most this many spins in one press (SpinBankCap and today's free one fit)
	SpinBankCap = 50, -- banked spins stop here (#1414: 20 to 50, so two Tip Jar sessions a day keep every spin)

	-- Golden fish (F52, golden-fish.md sections 1 and 2): the rare currency, earned only, never sold or given for
	-- Robux. Pure rules in GoldenFish.
	-- a cat new to the Index, any way it was found; its first gold pays twice this
	FishFirstCatch = { Common = 1, Rare = 3, Epic = 8, Legendary = 20, Mythical = 40 } :: { [string]: number },
	-- a cat already in the Index, by net or rescue (never bait, so food bought with coins never turns into fish)
	FishRepeatCatch = { Epic = 1, Legendary = 3, Mythical = 8 } :: { [string]: number },
	FishRankUp = { 10, 25, 50, 100 } :: { number }, -- reaching Tier 2, 3, 4 and 5
	CrateLuckyEvery = 20, -- F53: after 19 opens of one pool with nothing Epic or better, the next opens on golden odds

	-- Cafe Crates and the Golden Fish Market (F53, golden-fish.md sections 3 and 4). Pure rules in Crates.
	CratePrice = 40, -- golden fish for a zone or Classic Crate at the Market (crate-prices.md, #1051: one price)
	CrateBundleCount = 5, -- Buy 5 at the Market banks this many crates of one kind, opened one by one
	CrateBundlePrice = 180, -- golden fish for the bundle (36 a crate)
	-- every tip in the cafe while the piece is in use
	CratePieceBonus = { Common = 0.02, Rare = 0.04, Epic = 0.08, Legendary = 0.15, Mythical = 0.25 } :: {
		[string]: number,
	},
	-- golden fish back for a piece already owned
	CrateDuplicateRefund = { Common = 10, Rare = 20, Epic = 40, Legendary = 80, Mythical = 150 } :: {
		[string]: number,
	},
	FishMarketRange = 14, -- OpenCrate and BuyFishItem from this close to a FishMarket station
	-- #1146: a spam limit between OpenCrate starts, not a wait for the reveal; overlapping opens are refused by the
	-- in-flight check (Crates.openRefusal) instead. Was 2 s, which refused a Quick open's next crate. The
	-- Market window waits 0.2 s longer (its GATE_SLACK), so network jitter never lands a real press inside it.
	CrateOpenCooldownSeconds = 0.3,
	-- The crate reel (F103, crate-reel.md section 4), shared so the UI's reel and VFX's counter crate time to the same
	-- numbers: CrateReelTiles tiles slide under the marker and the won piece is tile CrateReelLandingTile; tiles
	-- CrateReelProtectFrom to CrateReelProtectTo are never rarer than the prize; the reel eases in over
	-- CrateReelRampSeconds to CrateReelTopSpeed tiles a second, slows over the last CrateReelStopSeconds and the marker
	-- pulses CrateReelHoldSeconds at the stop (about 2.9 s to the stop). Display only: the server's CrateResult decides.
	CrateReelTiles = 40,
	CrateReelLandingTile = 34,
	CrateReelProtectFrom = 26,
	CrateReelProtectTo = 37,
	CrateReelTopSpeed = 15,
	CrateReelRampSeconds = 0.3,
	CrateReelStopSeconds = 0.8,
	CrateReelHoldSeconds = 0.25,
	DecorSpots = { 2, 3, 4, 5, 6 } :: { number }, -- furniture and decorations in use, by tier
	DecorEquipBest = true, -- the server has EquipBestDecor (Derek 2026-10-28), so the Decor page shows Equip Best
	-- Reset my save for testers (ResetSaveService): once the game is group-owned, this group rank and up may use it
	ResetSaveGroupRank = 254,
	DecorIndexBonus = 0.05, -- every tip forever: a Decor Index page's decor10 prize (all twelve pieces since F80, F54)
	DecorIndexHalfFish = 25, -- golden fish: a Decor Index page's decor5 prize (five of ten, F54)
	GoldenEspressoBonus = 0.05, -- every tip, per Golden Espresso level

	-- Index rewards (F54, golden-fish.md sections 5 and 5b): the permanent bonuses the gold and All Cats tracks add
	-- up to. Gold rolls use chance x (1 + goldLuck); a bait wait is the wait x (1 - baitSpeed).
	GoldLuckMax = 1.5,
	BaitSpeedMax = 0.5,

	-- The Rainbow coat (F99, rainbow-coat.md sections 1, 2 and 5): rolled before gold at the same moments (a net stray
	-- at spawn, bait as the food goes in, a rescue at night start), so gold keeps its chance. Rainbow luck from the
	-- Index's Rainbow track multiplies the chance by (1 + luck), the luck at most RainbowLuckMax; gold luck, Gold Rush
	-- and Lucky Potions never touch it. A rainbow cat earns RainbowMultiplier (gold 1.5) and the Cat Collector values
	-- it at CollectorRainbowMultiplier (gold 3). Clients animate the bands on at most RainbowAnimateMax rainbow cats
	-- near the camera; a rainbow stray's server toast goes out at most once every RainbowSpawnToastSeconds.
	RainbowChanceNet = 0.005,
	RainbowChanceBait = 0.005,
	RainbowChanceRescue = 0.01,
	RainbowMultiplier = 3,
	RainbowLuckMax = 1.0,
	CollectorRainbowMultiplier = 10,
	RainbowAnimateMax = 10,
	RainbowSpawnToastSeconds = 60,
	-- golden fish for each cat's first rainbow coat: this times the rarity's FishFirstCatch (Common 5 to Mythical
	-- 200), any way it was found, on top of a new cat's fish (section 1, added after the #795 review)
	FishFirstRainbowMultiplier = 5,

	-- Trading (F102, trading.md section 6; Derek 2026-10-30: from Tier 3, secure, nothing to scam). Cats only, up to
	-- TradeMaxCats a side, both players at TradeMinTier or higher (CatCafeDebug tradeMinTier lowers it in one server).
	-- A request waits TradeRequestSeconds; declined or timed out, the asker waits TradeReaskSeconds to ask that player
	-- again. TradeCountdownSeconds after both press Ready the confirm screen opens; a lopsided trade (one side gives at
	-- least TradeLopsidedRatio times the Collector value it gets) or a gift holds that side's Confirm for
	-- TradeConfirmWaitSeconds. TradeCooldownSeconds between a player's trades, TradesPerDay a UTC day. The Trades page
	-- keeps TradeLogMax trades, the save TradeIdsMax applied trade ids. Every server reads the CatCafe_Flags kill switch
	-- every TradeFlagCheckSeconds.
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

	-- The camp extras (F100, camp-extras.md sections 2 and 4), each filling while the player is away up to its hold.
	-- The Picnic Basket (Park) bags one PicnicPotion (Design-Agent 11-02: the 10 minute Money Potion) every
	-- PicnicEverySeconds; the Yard Sale (Neighbourhood) gives one zone crate every YardSaleClaimHours from the last
	-- take, free (crate-prices.md section 5; camp-stations.md section 3, #1154), banked for the Market; the Fish Pond
	-- (Woods) lands PondFishPerStep golden fish every PondStepSeconds up to PondHold (#1232: 6 an hour, 6 hours' worth);
	-- the Lost and Found (Sewer) keeps one prize a UTC day from LostFoundTable (chances add
	-- to 1, shown on its card). Each is collected within CampExtraRangeStuds of its PromptAnchor.
	PicnicEverySeconds = 21600,
	PicnicHold = 2,
	PicnicPotion = "tip_potion",
	YardSaleClaimHours = 4,
	PondFishPerStep = 1,
	PondStepSeconds = 600,
	PondHold = 36,
	LostFoundHold = 3,
	LostFoundTable = {
		{ chance = 0.40, fish = 10 },
		{ chance = 0.30, potion = "lucky_potion" },
		{ chance = 0.20, potion = "gold_rush_potion" },
		{ chance = 0.09, crate = "classic_crate" },
		{ chance = 0.01, crate = "classic_golden_crate" },
	} :: { { chance: number, fish: number?, potion: string?, crate: string? } },
	CampExtraRangeStuds = 8,

	-- The Rescue Rally weekend (F101, rescue-rally.md; shared/Rally, Catalog.rallySteps). From RallyStartWeekday (0 is
	-- Sunday) 00:00 UTC for RallyHours, or at any time with RallyForce, each server fills one bar together. The goal is
	-- RallyPointsPerPlayer times the players (never fewer than RallyMinPlayers' worth), fixed when the lap starts; a
	-- step pays everyone in the server who scored RallyMinPoints this lap, from at most RallyMaxLaps laps a weekend.
	RallyStartWeekday = 6,
	RallyHours = 48,
	RallyPointsPerPlayer = 30,
	RallyMinPlayers = 3,
	RallyMinPoints = 3,
	RallyMaxLaps = 4,
	RallyPoints = { checkIn = 1, tame = 1, rescue = 3, teamRescue = 3 } :: { [string]: number },
	RallyForce = false,
	RallyStateSeconds = 0.5, -- RallyState goes out at most this often while points come in (steps go at once)

	-- Codes and the Codes Cat (F65, data-model section 11d). Codes are letters, digits and Codes.SYMBOLS, in any case.
	CodesCatRange = 12, -- RedeemCode from this close to a CodesCat station's pivot
	CodesCircleRadius = 4, -- the code box opens within this flat distance of the CodesCircle, closes past it + 1
	CodeMaxLength = 20,
	CodeWrongLimit = 5, -- this many wrong codes within CodeWrongWindowSeconds lock the box
	CodeWrongWindowSeconds = 60,
	CodeLockSeconds = 60,
	GroupId = 107520049, -- Creampuff Games, the community group (since 2026-11-03, #999): the starter cat's gate and
	-- requiresGroup codes. 0 turns both off (the starter cat back on the first goals)
	GroupCheckSeconds = 60, -- how long a player's group membership answer is kept

	-- The free Bellhop Cat (F96, starter-cat.md sections 2 and 4). Its stand's card opens and ClaimStarterCat is taken
	-- within StarterCatRangeStuds (flat) of a BellhopStand's pivot. While GroupId is 0 a claim needs the first goals
	-- (tutorialStep StarterCatTutorialStep: a cat home, a table bought and food in the bowl); once it is set, membership
	-- of GroupId (IsInGroupAsync in a pcall, kept GroupCheckSeconds). The cat arrives with StarterCatCharm.
	StarterCatRangeStuds = 12,
	StarterCatTutorialStep = 5,
	StarterCatCharm = 60,

	-- Shove, a Tackle since v0.11 (F29 bump rules, v0.5 F41, v0.11 F74, data-model section 10c); the code keeps the
	-- Bump and Shove names. Pure rules in Shove.
	BumpEnabled = true, -- false turns the Tackle remote off and hides the button
	BumpChance = 1.0, -- a shove on a carrier knocks the cat loose this often (v0.8 F56: always; kept to tune)
	BumpGraceSeconds = 3, -- a fresh carry cannot be knocked loose for this long
	BumpSafeRadiusStuds = 15, -- round both doors of the target's own cafe, as well as its plot
	BumpSameTargetSeconds = 20, -- per tackler and target
	ShoveKnockbackStuds = 10, -- the target's client pushes its own character this far
	ShoveTargetImmuneSeconds = 4, -- after a hit lands, nobody can hit that player again for this long (S45)
	-- A dropped cat walks home (v0.10 F67, round 4 Q4): let go with the Drop button (or a carrier's death), it walks
	-- back to where it was caught at this speed, anyone can pick it up on the way, and within DropHomeRadiusStuds of
	-- the spot it is a normal stray again. A blocked walk ends with it appearing there after DropReturnMaxSeconds.
	DropReturnWalkSpeed = 8,
	DropHomeRadiusStuds = 2,
	DropReturnMaxSeconds = 60,
	-- The Tackle (v0.11 F74, Derek 22:31): a lunge straight ahead that can miss.
	TackleLungeStuds = 12, -- the tackler's client lunges this far; the server's reach cap
	TackleLungeSeconds = 0.35,
	TackleHitGraceSeconds = 0.25, -- the server keeps checking for a hit this long after the lunge, for lag
	TackleHitRadiusStuds = 3, -- root to root
	TackleHitSlackStuds = 1.5, -- on top of the radius and the reach, for client-owned positions
	TackleCooldownSeconds = 5, -- Derek 2026-11-04 (#1134), was 8; from the press, hit or miss, never refunded; a refused press spends nothing
	TackleHitRecoverSeconds = 0.4, -- the tackler's client holds still after a hit
	TackleMissRecoverSeconds = 1.2, -- the tackler's client is down after a miss: no moving or jumping
	TackledDownSeconds = 0.8, -- the target's client is down after the knockback

	-- Naming cats (F33, data-model section 4): pure checks in CatName, the filter in NameService.
	CatNameMaxLength = 20, -- characters (utf8.len) after trimming
	RenameCooldownSeconds = 5, -- between one player's renames, each of which costs a TextService filter

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
	ProfileStoreName = "CatCafeProfiles",
	ProfileKeyPrefix = "p_",

	-- World layout (engineer; data-model section 9, town-layout-v3.md). The street runs along Z at X = 0. Cafes line
	-- both sides, each with a front garden on the street and a patio yard out back; the Alleyway is a back alley
	-- behind each row. v3.1 (F77, Derek 2026-10-27 23:56) is a compass round the Town Square: the Park gate at the
	-- street's south end, the Neighbourhood's at its north end, the Woods and the Sewer through the back alleys'
	-- outer walls straight across from the square's side arches.
	World = {
		PlotCount = 8,
		-- Bigger cafes (Derek 2026-11-02 21:52, Model-Agent #917): 44 x 34 inside, from 36 x 28, so decor fits and the
		-- room reads less cluttered; the town grows round them (TownEdgeX, the street's ends, the town ground)
		PlotWidth = 44, -- along the street (Z)
		PlotDepth = 34, -- away from the street (X)
		PlotRowGap = 8, -- a side passage from the street to the back alley between neighbouring cafes
		FrontGardenDepth = 5, -- path, bench and chalkboard between the sidewalk and the front wall
		YardDepth = 10, -- the patio yard between the back wall and the back alley
		-- Town layout v3 (F76, town-layout-v3.md, Derek 2026-10-27: "the main town should be wider so that it can have
		-- a central middle area"): a 32 wide street with the Town Square in its middle, two rows of cafes either side.
		StreetHalfWidth = 16,
		StreetSouthZ = -140,
		StreetNorthZ = 140, -- the street ends at the hometown's north welcome arch (v4)
		-- v4 (F84, hometown-cannon.md section 2): the hometown's own ground round the town, and each wild area its own
		-- CatCafe_Town_Backdrop (Model-Agent #733) is built against 272 by 332 (#917): tell Model-Agent when these change
		TownGroundWidth = 272,
		TownGroundDepth = 332,
		WallHeight = 9,
		DoorWidth = 7,
		-- The Town Square: paved, centred on the origin across the street, with the stations round the Cat Cannon (the
		-- fountain until v4) and a cross of open paving (the street's line and an east to west lane, which led to the
		-- side arches into the back alleys until v4 closed them). Its gardens fill the rest of the width out to the yards.
		TownSquareHalfWidth = 48,
		TownSquareHalfDepth = 32,
		TownSquareLaneHalfWidth = 8, -- the street's line through the square
		TownSquareCrossHalfWidth = 6, -- the east to west lane
		-- The hometown's back edge (v4, F84, hometown-cannon.md section 2): a fence at |x| TownEdgeX behind each row of
		-- cafes' yards, where the back alleys began until v4.
		TownEdgeX = 69,
		-- The Alleyway's set (v4, F84, section 6a): laid out in lane space, the v3.2 back alleys' numbers (|x|
		-- AlleyInnerX..AlleyOuterX from AlleySouthZ to AlleyNorthZ), and stood in the wild with its middle at
		-- (AlleyCenterX, AlleyCenterZ), everything AlleyLaneShift nearer the middle than in lane space. Since F85
		-- (Derek 2026-11-02: one big lane, not two) the block of building backs between the old lanes is gone, so the
		-- Alleyway is one lane 2 * (AlleyOuterX - AlleyLaneShift) = 90 wide, its camp across the north end with one way
		-- in, AlleyWayHalfWidth either side of the middle, under the street arch.
		AlleyInnerX = 63,
		AlleyOuterX = 93,
		AlleySouthZ = -125.5,
		AlleyNorthZ = 125.5,
		AlleyCenterX = -1400,
		AlleyCenterZ = -1400,
		AlleyLaneShift = 48,
		AlleyWayHalfWidth = 20.3,
		-- The wild areas (v4, F84, hometown-cannon.md section 6a): each v3.2 set moved WildAreaDistance out from the
		-- Town Square in the same place, the Park south, the Neighbourhood north, the Woods west and the Sewer east, so
		-- none is in view of the town or of another. Only the Cat Cannon reaches them. Each keeps its gate on its town
		-- side as its camp's way out, with the camp (CampDepth deep, across the area's whole width) in front of it.
		WildAreaDistance = 2000,
		-- The Park (F85, hometown-cannon.md section 6b): long, 120 wide and 310 deep, its camp on its north side.
		ParkCenterZ = -2000,
		ParkWidth = 120,
		ParkDepth = 310,
		-- The Woods and the Sewer (F85, hometown-cannon.md section 6b): long, the Woods 160 wide and 490 deep with its
		-- camp on its east side, the Sewer 120 wide and 570 deep with its camp on its west, so their depth runs along
		-- world X. Their gates keep the 24 wide openings they had in the back alleys' outer walls (SideGateHalfWidth
		-- either side).
		WoodsCenterX = -2000,
		WoodsCenterZ = 0,
		WoodsWidth = 160,
		WoodsDepth = 490,
		SewerCenterX = 2000,
		SewerCenterZ = 0,
		SewerWidth = 120,
		SewerDepth = 570,
		SideGateHalfWidth = 12,
		-- The Neighbourhood (F85, hometown-cannon.md section 6b): long, 180 wide and 430 deep, its camp on its south side.
		NeighbourhoodCenterX = 0,
		NeighbourhoodCenterZ = 2000,
		NeighbourhoodWidth = 180,
		NeighbourhoodDepth = 430,
		-- Camps (section 4): CampDepth deep across the area's whole width; the landing pad in its middle with
		-- seventeen spots inside LandingPadRadius, a spot free with no character within LandingClearStuds; the cannon
		-- prompt's reach. A dropped cat within CampDropMarginStuds of a camp moves out to CampDropOutStuds past its
		-- edge. CampOpeningWidth is the F85 fence's opening (F84 camps keep their gates' widths).
		CampDepth = 30,
		CampOpeningWidth = 24,
		LandingPadRadius = 8,
		LandingClearStuds = 3,
		CannonRangeStuds = 10,
		CampDropMarginStuds = 2,
		CampDropOutStuds = 3,
		-- Cafe life (world-and-feel.md section 4, F37): each client walks customers into every running cafe within
		-- this range of its camera, up to CustomersMax at once across the street.
		CafeLifeRangeStuds = 80,
		CustomersMax = 24,
		CustomersMaxLow = 12, -- on a phone or tablet (Effects.tier() "low"): each walker moves every frame
		CustomerOrderSeconds = 2, -- standing at the counter before taking a seat
		-- Cats make the orders (F90, cats-make-orders.md section 2), client only: at most OrderQueueMax orders wait or
		-- are being made per cafe (a customer past that finds its dish on the table as it sits); with no Waiter in
		-- your own cafe a customer waits up to OrderHandOverSeconds at the counter for the Barista to hand it over;
		-- a Waiter trots at OrderWaiterSpeed; a left plate stays OrderPlateSeconds, then fades over
		-- OrderPlateFadeSeconds; an idle Waiter or Greeter sweeps a tip pile TipSweepAfterSeconds after it appears.
		OrderQueueMax = 3,
		OrderHandOverSeconds = 8,
		OrderWaiterSpeed = 5,
		OrderPlateSeconds = 5,
		OrderPlateFadeSeconds = 1,
		TipSweepAfterSeconds = 6,
	},
}

return Config
