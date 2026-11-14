--!strict
-- Tuning constants for Cat Cafe (docs/design/cat-cafe/data-model.md section 17 plus world layout).
-- Pure data: no Roblox services, so tests can require it. Nothing numeric lives in a Service.
-- Distances are studs, times are seconds, money is coins.

local Config = {
	ServerPlayers = 8,
	-- #1796 (Derek2 11-06: the tutorial asks for a table and then the Bait bowl, and $50 covered neither): the first
	-- table, the Bait bowl and its Kibble ($150 + $600 + $100), so tutorial steps 3 and 4 never wait on coins. #4097:
	-- 850 to 250 now the table (#3660), the bowl and its Kibble are given: what a new player had left after buying the
	-- bowl, so the money after the tutorial is as before
	StartCoins = 250,
	-- #3660 (Derek 2026-11-12: "make the players start with one table upgrade done and remove it from tutorial
	-- steps"): the Tables level a new save starts at. Saves made before keep what they have
	StartTables = 1,
	-- #4097 (Derek 2026-11-14: "just have them click use the kibble show the cutscene, then claim the cat"): the Bait
	-- bowl level a new save starts at, with one Kibble in the Bag, so the tutorial goes from the first job straight to
	-- putting the Kibble in. Saves made before keep what they have
	StartBowls = 1,

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
	-- The away notification (#2768, Derek2 2026-11-10: "Yes, once a day, 12 h after leaving"; shared/AwayNotify): a
	-- player who turned Roblox notifications on for the game gets "Your cats earned $X while you were away!" this long
	-- after leaving, unless they came back first. The sender runs hourly, so a message up to the grace late still goes
	-- out; later than that it is dropped. No message for less than the minimum (a cafe with no cat at work).
	AwayNotifyOn = true,
	AwayNotifySeconds = 43200,
	AwayNotifyGraceSeconds = 21600,
	AwayNotifyMinCoins = 1000,
	-- Game pass ids for F95's hooks (section 6); 0 until Tools-Agent makes the pass, which turns its effect off. The
	-- Money passes by the income they multiply by (the highest owned counts); each extra slot pass adds a role slot.
	-- Tools-Agent made the four in tools/opencloud/passes.json on 2026-11-02 (off sale until launch), and the rest on
	-- 2026-11-04 as off-sale placeholders (#1197). Each stays off sale until the code that grants it is merged; the
	-- Store cards (#1240) read the ids. Each extra slot (Economy.extraSlots, #1624) opens the next role slot early.
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
	KingCatPassId = 2074682301, -- #1822: the King Cat alone (R$799); the pass is made off sale and goes on sale after this is live
	JukeboxPassId = 2075072428, -- #1168 row 2: off sale; the songs are free since #1875, kept so earlier buyers see no errors
	SignStylePackPassId = 2075396351, -- #1168 row 1: three sign styles (R$79); made off sale by Tools-Agent 2026-11-06
	GardenDecorPackPassId = 2075342357, -- #1168 row 3: six looks-only decor pieces (R$149); made off sale by Tools-Agent 2026-11-06
	GoldenPondPassId = 2071704337, -- #1232
	SecondBowlPassId = 2072132265, -- #1161
	-- #4026: the four outfit packs (R$99 each); made off sale with game-passes.yml 2026-11-13, on sale with this
	StylishPackPassId = 2087936654,
	WinterPackPassId = 2089766669,
	ChefPackPassId = 2089430670,
	SpacePackPassId = 2088794660,
	-- #1624 (economy-ladder.md section 6a v2.4): what the five store passes give. VIP, Cafe Style and Grand Cafe add
	-- into cafeMultiplier like tables and decor; Cat Accessories and Uniform Styles each multiply every working cat's
	-- rate; Cafe Style and Grand Cafe add to how often rich visitors come (x(1 + 0.25 + 1.0) with both).
	VipCafeBonus = 0.10,
	CafeStyleCafeBonus = 0.50,
	GrandCafeBonus = 1.50,
	AccessoriesStaffMultiplier = 1.15,
	UniformsStaffMultiplier = 1.15,
	CafeStyleRichRate = 0.25,
	GrandRichRate = 1.0,
	GrandExtraSlots = 1, -- #1624: Grand Cafe's +1 job slot at every tier, adding to each Extra Slot pass's 1
	-- #1955 (auto-equip.md): Auto Equip (settings.autoEquip) runs Equip Best by itself at most once every
	-- AutoEquipEverySeconds a player (runs asked for in between are merged), never moving a cat placed or rested by hand
	-- in the last AutoEquipHoldSeconds
	AutoEquipEverySeconds = 3,
	AutoEquipHoldSeconds = 600,
	-- Developer product ids (#1182) by Catalog.products id; a 0 is never granted. ProductService's ProcessReceipt reads
	-- them. Tools-Agent made these with dev-products.yml on 2026-11-04 (tools/opencloud/products.json), off sale until
	-- launch. The Starter Bundle (3728336166) and Cafe Pass (3728336202) products were made the same way.
	ProductIds = {
		potion_pack_xs = 3728336174,
		potion_pack_s = 3728336184,
		potion_pack_m = 3728336191,
		potion_pack_l = 3728336197,
		steady_paw_pack = 3728717974, -- #1168 row 8: made by Tools-Agent (dev-products.yml), off sale until live
		thank_you_badge = 3728719483, -- #1168 row 4: once per account (Tools-Agent, 2026-11-06), off sale until live
		starter_bundle = 3728336166, -- #1625: once per account (Catalog.products oncePerAccount)
		cafe_pass = 3728336202, -- #1626: the running season's paid track, once per season (Catalog.products seasonPass)
		trait_tokens_20 = 3730879829, -- #3864: 20 Trait Tokens, R$99; made with dev-products.yml, then its id goes here
		trait_tokens_50 = 3730879833, -- #3864: 50 Trait Tokens, R$199
		-- #3996: Today's Deal, R$25 each, regional pricing off; made with dev-products.yml 2026-11-14 (products.json)
		deal_1 = 3731165229, -- Big Money
		deal_2 = 3731165237, -- Trait Tokens
		deal_3 = 3731165246, -- Steady Paw
		deal_4 = 3731165258, -- Potion Mix
	} :: { [string]: number },
	-- #1934 (release.md section 1): the Roblox badge id of each badge in shared/Badges, by key; a 0 is not made yet
	-- and is never awarded. Made 5 a day in Creator Hub, in Badges.LIST order, by Tools-Agent or Derek.
	Badges = {
		welcome = 3335628834714920,
		firstCatch = 965821038770402,
		cozyCafe = 3159884753679593,
		grandOpening = 1259873901887390,
		purrfect = 1317002089922327,
		baitCat = 2110748625065463,
		rareFind = 3754290961752885,
		legendaryFind = 844098523406849,
		mythicalFind = 1340070473383505,
		busyCafe = 406929438300162,
		famousCafe = 439452364883354,
		grandCafe = 243520303449399,
		catCollector = 3402890419919405,
		catExpert = 2697213476077024,
		goldenCoat = 3791415425175040,
		rainbowCoat = 531093117966608,
		pageComplete = 268713651554121,
		helpingPaw = 905647581887639,
		firstTrade = 428728625137987,
		purrfectStreak = 4111238237174459,
		partyGuest = 4328065554528969, -- #2486: "Cafe Party Guest", the Cafe Event reward badge (live-events.md section 2e); made 2026-11-11 (#1957)
		metOwner = 1802984077324671, -- #3324: "Met the Owner", for being in a server with the owner; made 2026-11-11 (badges.yml)
		-- #3618 (badges-order.md): the six new badges, 0 until badges.yml makes them (5 a day, free only)
		firstHome = 3818992250915779, -- Home Sweet Home (made 2026-11-13)
		firstUpgrade = 708647132528539, -- Fixing Up
		firstFlight = 771736196964132, -- Liftoff
		cornerCafe = 4089080696855068, -- Corner Cafe
		sunstoneCafe = 3966771842573409, -- Sunstone Cafe
		wonderCafe = 383838983462242, -- Wonder Cafe (made 2026-11-14, free)
	} :: { [string]: number },
	-- #1770 owner test mode (Monetization-Agent's policy): the Roblox user ids whose every made pass counts as owned
	-- and who may grant themselves a product with OwnerGrant, with no receipt record and no Robux (OwnerTestService).
	-- Only the server reads it. Derek2's account, named "2573351", is user id 140223517 (user id 2573351 is someone
	-- else). Nobody else is ever listed.
	OwnerTestUserIds = { 140223517 } :: { number },
	-- #3324: the game owner's account (Derek2), for the [Owner] chat tag and the Met the Owner badge. Only the server
	-- acts on it. Kept apart from OwnerTestUserIds so a tester added there never shows as the owner.
	OwnerUserIds = { 140223517 } :: { number },
	-- The Cafe Pass (#1645, cafe-pass.md section 1): each season's first day as a UTC date, oldest first. With no date
	-- the pass is closed outside Studio, where a preview season 1 runs for playtests (shared/CafePass).
	-- 2026-11-05 is a test start so Derek2 can try the pass live; Derek2 resets it to the launch day. Keep one date:
	-- moving it later only moves the season's end.
	SeasonStarts = { "2026-11-05" } :: { string },
	PassLevels = 34, -- #1883 part C: 30 until the four Maple showpieces (levels 31 to 34)
	PassXpPerLevel = 800,
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
	-- short reset between hunts; the catching areas close at dusk and a fresh wave spawns at sunrise. #2192 (Dread via
	-- Derek2, 2026-11-07: "make the days a bit longer and maybe night a tiny bit shorter"): 320 and 70 (were 300 and
	-- 90). The day takes the night's 20 s, so a game day is still 390 s: every sunrise, restock window, day number and
	-- pity timer falls where it did, and only dusk moves 20 s later. ServerStartDaySeconds stays equal to the day.
	-- #3195 (Derek2 2026-11-10: "make the night times faster to stop being leaving during night"): 345 and 45 (were
	-- 320 and 70), the same way: still 390 s a game day, every sunrise where it was, dusk 25 s later. So old and new
	-- servers agree on the day number and every sunrise, and no restart is needed.
	DayLengthSeconds = 345,
	NightLengthSeconds = 45,
	ServerStartDaySeconds = 345, -- the clock's first day, from ClockEpoch (was each server's start, before #1437)
	-- #1437 (Derek 2026-11-05: "restock once per in game day and make it global"): every server reads the clock from
	-- this os.time() (2026-11-01 00:00 UTC) on Workspace:GetServerTimeNow(), so sunrise and dusk fall at the same
	-- moment in every server; a new server joins the day already under way. Day 1 starts here.
	ClockEpoch = 1793491200,
	DuskWarningSeconds = 15, -- players in a catching area get the "Night falls" banner this long before night
	NightSweepSeconds = 2, -- during night, anyone found in a catching area is sent home this often

	-- Strays and catching (data-model sections 9 and 10). Wave sizes live per area in Catalog.areas.
	StrayDespawnSeconds = 120, -- lifetime of a Studio debug stray; wave strays stay until the next night
	GrabRangeStuds = 10,
	-- Derek 2026-10-27: hold E this long on a stray to start the minigame, so walking past one with a tap of E never
	-- starts a catch by accident. #2335: a stuck cat's rescue starts on one press (RescueService.PROMPT_HOLD_SECONDS)
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
	-- feet touch the pad at CannonTouchdownAt, both from CannonLaunchAt, for the sounds (Sound-Agent). #2690 (Derek2
	-- 2026-11-09: movement and camera "locked too long" after landing): let go 0.25 after the touch, was 4.0. #3292
	-- (Derek2 2026-11-11: flights "changing course slightly mid air"): the move at 2.2 (was 2.6), so it reaches every
	-- client well before the body comes back down at 3.0, drawn from wherever the root is by then.
	CannonLaunchSeconds = 3.75,
	CannonTeleportAtSeconds = 2.2,
	CannonCloudsAt = 2.0,
	CannonTouchdownAt = 3.5,
	CannonCooldownSeconds = 3,
	CloudHopSeconds = 1.6,
	CloudHopMoveAtSeconds = 0.6,

	-- The net: closing circles judged on the server (data-model section 10)
	CircleLeadInSeconds = 0.6, -- from GrabBegin to the first circle starting to shrink
	-- From one circle's target to the next one's start. CircleGapMin must stay above the widest good window plus
	-- CatchLatencyCapSeconds, so a late press for one circle can never land on the next (reviewer S24). #2060 (Derek2:
	-- the rings move to a new spot each time): 0.55 (was 0.40), the UI's lead-in, so the next ring's outline shows as
	-- the last one is tapped and the player has the whole gap to find it before it starts closing.
	CircleGapMin = 0.55,
	CircleGapMax = 0.75,
	-- #1884 (catch-rework.md 7b): the trust bar. A net catch starts at TrustStart and each ring adds TrustPerfect,
	-- TrustGood or TrustMiss; it is caught at the rarity's trustNeed and bolts below 0. Rings come on a steady beat
	-- (CircleGapMin apart), up to the all-Good count plus CatchSpareRings (#2332, below).
	-- #2005 (Derek2 2026-11-07: "getting excellents/good increase hp more"): Perfect +3 and Good +2 (were +2 and +1),
	-- with each rarity's trustNeed at TrustStart + 3 x its circles so an all-Perfect run is the same length.
	TrustStart = 2,
	TrustPerfect = 3,
	TrustGood = 2,
	TrustMiss = -2,
	-- #2317 and #2332 (Derek2: "it should fully be only failing if the heart bar hits 0"): the rings past the all-Good
	-- count (Circles.ringCap), was 2 past the all-Perfect count. Each Miss takes one more Good to win back, so 16
	-- spare rings run out only after eight Misses the bar survived: in play the bar emptying ends a catch, not the
	-- rings.
	CatchSpareRings = 16,
	-- #1884 (catch-rework.md 7c): the rarity twists. A double ring is two halves DoubleRingGap apart, each graded as
	-- its own press and each using one of the rings above; a paw ring (red, don't tap) adds TrustPawLeft when left
	-- alone and is a Miss when tapped, and uses none of them, so it never shortens a run.
	DoubleRingChance = 0.25,
	DoubleRingGap = 0.35, -- #2005 (Derek2: "too fast right after eachother"), was 0.18
	PawRingChance = 1 / 6,
	TrustPawLeft = 1,
	-- #1884 (7a): moods. A Curious stray walks CuriousWalkStuds toward the first player within CuriousRangeStuds, and
	-- a swing landing within CuriousBonusSeconds of that starts with CuriousTrustBonus more trust. A Skittish one hops
	-- SkittishHopStuds away from a player within SkittishRangeStuds inside its SkittishArcDegrees front arc, at most
	-- once every SkittishCooldown seconds. The client shows the mood icon within MoodIconStuds.
	CuriousTrustBonus = 1,
	CuriousRangeStuds = 12,
	CuriousWalkStuds = 4,
	CuriousBonusSeconds = 2,
	SkittishRangeStuds = 10,
	SkittishArcDegrees = 90,
	SkittishHopStuds = 6,
	SkittishCooldown = 8,
	MoodIconStuds = 20,
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
	-- #2913 follow-up (Nov 10 read: after the sure first catch, phones still miss more, 37 of 186 new players missed
	-- at least once and 48 saw a cat bolt): a player's catches by hand before EarlyCatchCount (SecondCat.caught) are
	-- judged with bands EarlyCatchWindowScale times as wide. By the player's save, not their device, which the server
	-- never trusts; the widest band stays under CircleGapMin (Config.spec S24).
	EarlyCatchCount = 5,
	EarlyCatchWindowScale = 1.3,
	-- The net swing (F93, catch-rework.md section 1): one SwingNet per NetSwingCooldown. NetSmackDelay after it
	-- arrives, when the net lands, the server looks for the nearest free stray within NetReachStuds plus
	-- NetSlackStuds of the root and within NetArcDegrees either side of its facing. A swing that hits nothing makes
	-- every free stray within NetMissHopStuds hop NetMissHopShare of its rarity's fleeStuds away.
	NetSwingCooldown = 0.8,
	NetSmackDelay = 0.22, -- Derek 2026-11-03 OK'd the smoother swing landing at 0.22 s (was 0.15)
	NetReachStuds = 7,
	NetSlackStuds = 1.5,
	NetArcDegrees = 60,
	-- #2693 (Derek2 2026-11-09: easier to hit on mobile): within NetNearStuds of the feet the arc is NetNearArcDegrees
	-- either side, and within NetFrontArcDegrees of straight ahead the reach is NetFrontExtraStuds longer
	NetNearStuds = 4,
	NetNearArcDegrees = 80,
	NetFrontArcDegrees = 25,
	NetFrontExtraStuds = 0.5,
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
	-- #1895 (Design-Agent, first-hour.md): the account's first bait waits at most this long; later ones as usual.
	-- #2774 (Derek2 2026-11-09, the 2 to 5 minute drop: 12 set a first bait, 7 saw it land): was 120
	-- #2946 (Derek2 2026-11-10: "a cut scene ... then the food timer left gets set to 0"): 1, so the first bait cat
	-- arrives (BaitService checks every second) inside the 2.5 s the client's cutscene waits on the bowl (was 45, #2774)
	FirstBaitWaitSeconds = 5,
	-- #3161 (Derek2 2026-11-10: "set food bowl to like 5 seconds so the cutscene lines up with it"): 1 before (#2946).
	-- The first bait's cat stands at the bowl this long before its timer ends (never sooner than a second after the
	-- food), so the cutscene (camera over 0.5 s, the walk 1.6 s, the eat 1 s, camera back 0.5 s) plays while the
	-- timer runs down and the Tame card comes up as it ends.
	FirstBaitCatLeadSeconds = 4,
	-- #1920 (Design-Agent, first-hour.md 6): seconds of play in one session before the recap card (SessionRecap)
	RecapAfterSeconds = 2400,
	-- #2123 (first-hour.md 6a): the account's first session shows it sooner, as most first sessions end before 40 minutes.
	-- #3772 (come-back-tomorrow.md 2b): 8 minutes, was 15, as many first sessions end before 15 minutes
	RecapFirstSessionSeconds = 480,
	-- #3772 (shared/ReturnGift): the welcome back gift is for accounts whose first UTC day (os.time() // 86400) is this
	-- day or later; 20770 is 2026-11-13, the day it shipped
	ReturnGiftFromDay = 20770,
	-- #1947 (like-prompts.md section 3, Set 10 Q3): the like card's gift at LikeGiftMinutes of play on the account, of
	-- LikeGiftIncomeMinutes of income and a Tip Potion; the favourite card's at FavGiftMinutes, of FavGiftIncomeMinutes
	-- of income and a small potion pack (shared/PlaytimeGifts). The card waits for GiftIdleSeconds of calm (client).
	LikeGiftMinutes = 10,
	LikeGiftIncomeMinutes = 15,
	FavGiftMinutes = 30,
	FavGiftIncomeMinutes = 30,
	-- #2798 (retention-ideas.md idea 10, shared/CozyCafe): Cozy Cafe. After CozyStartSeconds in your own cafe a cat
	-- curls up on the counter; every CozyBagSeconds more it leaves a bag of CozyCoinSeconds of income, CozyLureChance
	-- of one CozyLure and CozyFishChance of CozyFishMin to CozyFishMax golden fish; CozyBagsPerDay a UTC day
	CozyStartSeconds = 60,
	CozyBagSeconds = 180,
	CozyBagsPerDay = 8,
	CozyCoinSeconds = 60,
	CozyLure = "tuna",
	CozyLureChance = 0.25,
	CozyFishChance = 0.05,
	CozyFishMin = 1,
	CozyFishMax = 3,
	-- #2791 (retention-ideas.md 5a): the small steps on the same track, paid with a toast (shared/PlaytimeGifts)
	PlaytimeGiftSteps = {
		{ id = "m2", minutes = 2, prize = { coinSeconds = 60 } },
		{ id = "m4", minutes = 4, prize = { lures = { tuna = 1 } } },
		{ id = "m6", minutes = 6, prize = { spins = 1 } },
		{ id = "m15", minutes = 15, prize = { fish = 5 } },
		{ id = "m20", minutes = 20, prize = { potions = { swift_potion = 1 } } },
	} :: {
		{
			id: string,
			minutes: number,
			prize: {
				coinSeconds: number?,
				lures: { [string]: number }?,
				spins: number?,
				fish: number?,
				potions: { [string]: number }?,
			},
		}
	},
	GiftIdleSeconds = 3,
	-- F88 Luck (luck-and-rare-moments.md section 1): one number from x1.0 that multiplies the Epic, Legendary and
	-- Mythical chances of your bait and crate rolls (shared/Luck), at most LuckMax. The Lucky Cat statue adds
	-- LuckPerStatueLevel a level, a Lucky Potion LuckyPotionLuck while it runs, a Lucky Day LuckyDayPlayerLuck to
	-- everyone in the server until dusk. A Lucky Day's sunrise wave and traps roll at LuckyDayWaveLuck, and
	-- LuckyDayWarnSeconds before its sunrise the players still in are told.
	-- #1572 (luck-and-rare-moments.md 1g, day rolls v2): each global day (Clock.dayAt, from ClockEpoch) rolls its kinds
	-- on its own seed (Clock.dayKinds), so every server has the same day: Lucky LuckyDayChance, Golden GoldenDayChance
	-- (every gold roll x GoldenDayGoldMultiplier) and Rainbow RainbowDayChance (every rainbow roll x RainbowDayMultiplier),
	-- from sunrise to night, any of them on the same day. LuckyDayEvery (every 4th day) is gone.
	LuckPerStatueLevel = 0.1,
	LuckMax = 3,
	LuckyPotionLuck = 0.5,
	LuckyDayChance = 0.33,
	GoldenDayChance = 0.2,
	RainbowDayChance = 0.1,
	GoldenDayGoldMultiplier = 3, -- #1954 (Set 11 Q1): x3, to match Rainbow Day (was 2)
	RainbowDayMultiplier = 3,
	LuckyDayWaveLuck = 2,
	LuckyDayPlayerLuck = 0.5,
	LuckyDayWarnSeconds = 15,
	-- #1974 (release.md section 4, the Saturday drops): a Lucky, Golden or Rainbow Day forced on for every global day
	-- whose sunrise falls in [from, to), UTC unix seconds, on every server; the random roll still runs for the other
	-- kinds, and the day after rolls as usual. Empty until a drop: each week's PR adds its row, e.g.
	-- { kind = "lucky", from = 1795219200, to = 1795305600 } for Sat 2026-11-21 UTC.
	ForcedDays = {} :: { { kind: string, from: number, to: number } },
	-- #2486 Cafe Events (docs/design/cat-cafe/live-events.md section 4; shared/CafeEvents, EventService): each server
	-- reads CatCafe_Events every EventPollSeconds. An event runs EventMinSeconds to EventMaxSeconds (a record outside
	-- is ignored); its money multiplier on cafe income is at most EventMoneyMax, its Luck at most EventLuckMax (total
	-- Luck still at most LuckMax), its showers at most EventShowerMax, at least EventShowerGapMinSeconds apart (a value
	-- past a cap is clamped). EventShowerDefaults is the 2-hour preset; EventShowerAreaWeights picks a shower's area,
	-- equal over the five. The countdown shows from EventCountdownSeconds before the start. A player who already owns
	-- the event's cosmetic gets EventRepeatGiftIncomeMinutes of income instead. The workflow keeps big events
	-- EventBigMinGapSeconds apart. At most EventScheduleMax records are read.
	EventPollSeconds = 60,
	-- #3572 (Derek 2026-11-12: "make the prizes of anything not being bought yet half'd", "put a sale badge on it"): the
	-- Store's Sale badge, by Store card key. `was` is the real Robux price the item had on 2026-11-12 and `now` the
	-- half price Derek OK'd. Roblox only tells the game today's price, so the card shows the badge and the struck old
	-- price while Roblox's price is `now` or lower (#3594 follow up, 2026-11-13: unsold items go a little below half),
	-- and only before StoreSaleEnds (os.time: 2026-12-13 00:00 UTC, 30 days on; never shown to players, no countdown).
	-- After that the half price is simply the price. Every key is a Store card (StoreLogic.spec checks); the Golden
	-- Pond pass (99 to 49) is sold at the camp pond, not on a Store card, so it is not here.
	StoreWasPrice = {
		extraSlot = { was = 149, now = 75 },
		uniforms = { was = 149, now = 75 },
		cafeStyle = { was = 249, now = 125 },
		royalCat = { was = 599, now = 299 },
		kingCat = { was = 799, now = 399 },
		grandTheme = { was = 799, now = 399 },
		kingPack = { was = 999, now = 499 },
		thankYou = { was = 25, now = 13 },
		cafePass = { was = 299, now = 149 },
	} :: { [string]: { was: number, now: number } },
	StoreSaleEnds = 1797120000,
	-- #4175 (Derek 2026-11-14: an occasional push on big update days, at most once a week): the update's own item
	-- leads the Store's Featured tab with the plain line "New today" from `starts` up to `ends` (os.time, UTC),
	-- behind the updateFeature switch. `keys` are Store card keys, first one the player can still buy. `saleEnds` is
	-- the real last day of a real sale on that item ("Sunday"), shown as "Sale ends Sunday" only while the card has
	-- its Sale badge. No countdown, no stock counts. Nothing shows outside the window or with the switch off.
	-- First use: the outfit packs, 2026-11-14 22:00 UTC for a day.
	UpdateFeature = {
		keys = { "packStylish", "packChef", "packSpace", "packWinter" },
		starts = 1794693600,
		ends = 1794780000,
	} :: { keys: { string }, starts: number, ends: number, saleEnds: string? },
	EventMinSeconds = 300,
	EventMaxSeconds = 7200,
	EventMoneyMax = 2,
	-- #3651 (shared/Pet, switch `petCats`; Derek 2026-11-12: "increase how much money they make by 2x ... make it 1
	-- hour long", one cat at a time): the happy cat's own pay is times PetMoneyBoost for PetSeconds after a pet, in
	-- online cafe pay only and never above EventMoneyMax together with the event money slot above. A pet is taken
	-- from within PetRangeStuds of the cat, PetCooldownSeconds apart.
	PetMoneyBoost = 2,
	PetSeconds = 3600,
	PetCooldownSeconds = 3,
	PetRangeStuds = 10,
	-- #3573: resting in your own cafe (shared/AfkCafe). No input and no movement for AfkCafeSeconds in the cafe or on
	-- its doorstep doubles the cats' cafe pay, in the event money slot above (so never more than EventMoneyMax).
	AfkCafeSeconds = 120,
	AfkCafeMoney = 2,
	-- #3602: a resting player who has had no input this long is sent back into the game (shared/AfkCafe, switch
	-- `autoRejoin`). Roblox disconnects at 20 minutes without input, so this leaves two minutes for the teleport
	-- and its retries.
	AutoRejoinSeconds = 18 * 60,
	EventLuckMax = 1.0,
	EventShowerMax = 12,
	EventShowerGapMinSeconds = 300,
	EventShowerDefaults = { count = 8, gapSeconds = 900, firstAfter = 600 },
	EventShowerAreaWeights = {
		alley = 20,
		park = 20,
		neighbourhood = 20,
		woods = 20,
		sewer = 20,
		desert = 20, -- #2651 (tier6-7-areas.md section 7): the same as every area
		ruins = 20,
	} :: { [string]: number },
	EventCountdownSeconds = 10800,
	EventRepeatGiftIncomeMinutes = 10,
	EventBigMinGapSeconds = 518400,
	EventScheduleMax = 10,
	-- #1572 (luck-and-rare-moments.md 1h): the global pity cat (shared/Pity). A slot every PityLegendarySeconds from
	-- ClockEpoch, every PityMythicalEvery-th a Mythical one; its area by PityAreaWeights (by area id), and the first
	-- catch anywhere claims it in MemoryStore, tried PityClaimRetries times before the catcher keeps it anyway.
	-- #2796 (Derek2 2026-11-09: "for pity timers we can temporarily half them for more testing and add them to a
	-- funnel"): TEMPORARY, review 2026-11-16; put back 1800 and 7200.
	PityLegendarySeconds = 900,
	PityMythicalEvery = 4,
	-- #1946 (1i): the restarting timers. The next Legendary is due PityLegendarySeconds after the last Legendary pity
	-- cat was caught or left at night, the next Mythical this long after the last Mythical (PityMythicalEvery is
	-- then only the fallback slots' rule).
	PityMythicalSeconds = 3600, -- #2796: TEMPORARY, was 7200
	PityAreaWeights = {
		alley = 10,
		park = 15,
		neighbourhood = 20,
		woods = 25,
		sewer = 30,
		desert = 35, -- #2651 (tier6-7-areas.md section 7)
		ruins = 40,
	} :: { [string]: number },
	PityClaimRetries = 3,
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
	TownWalkSpeedBonus = 4, -- #2706 (Derek2 2026-11-09: "increase walking/running speed in spawn by a bit"): no cat, on the Town Square
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
	-- #1159 (shared/StrayTopUp): by day an area under its floor of live strays gets one more every 30 to 60 s, at a
	-- far point first. The floor is StrayFloorBase for one player plus StrayFloorPerPlayer for each more who has the
	-- area open, never above StrayLiveMax live cats in the area (the 10-28 "way too many" line is a live cap).
	-- #2557 (Derek2, 2026-11-09: "increase cat spawns by about 33% per area sometimes they run out"): about a third
	-- more on the floor, the cap, the gate floor and each wave, and top-ups a quarter sooner
	StrayFloorBase = 12, -- #2557 (was 9; #1452 5, more strays near the gates 7)
	StrayFloorPerPlayer = 1,
	StrayLiveMax = 21, -- #2557 (was 16; #1452 12, more strays near the gates 14)
	-- Derek2 2026-11-05, "no cats start of sewer": a gated area keeps StrayEntryFloor live strays within
	-- StrayEntryStuds of its gate by day. The commonest of each sunrise wave land there, and while it is short one more
	-- arrives at an entry point every StrayEntryTopUpSeconds, still under StrayLiveMax (shared/StrayTopUp).
	StrayEntryFloor = 4, -- #2557 (was 3)
	StrayEntryStuds = 120,
	StrayEntryTopUpSeconds = 15, -- #2557 (was 20)
	StrayTopUpMinSeconds = 30, -- #2557: 30 to 60 s (#1452 40 to 80, before it 60 to 120)
	StrayTopUpMaxSeconds = 60,
	-- #3661: a sunrise wave is rolled at once but placed over time, so no client gets every area's cats in one burst.
	-- The rarest WaveAtOnce of each area are there at sunrise; the rest follow within WaveSpreadSeconds.
	WaveAtOnce = 2,
	WaveSpreadSeconds = 30,
	StrayWanderSpeed = 3,
	-- #3545 (Derek 2026-11-12 12:33 UTC: "have them be walking around much faster in the area"): a wild Secret stray
	-- walks three times as fast over three times the reach, with half the pause between walks and no naps. It still
	-- stays in its area, stops at the first solid thing (clearPath) and keeps a perch as any stray does; a player
	-- walks at 20, so it can always be reached.
	SecretWanderSpeed = 9,
	SecretWanderRadius = 15,
	SecretWanderPauseScale = 0.5,
	-- #2205 (Derek2, 2026-11-07: "just legendary or better or gold/rainbow"): the catch pop-up's floor (was Epic).
	-- Derek 2026-11-12 ("make rainbow/gold finds also changed to only legendary + and make normals only mythic+ it
	-- has a bit of clutter right now"): Mythical for a plain coat (was Legendary); a gold or rainbow coat from
	-- Catching.COAT_SHOUT_FROM
	AnnounceMinRarity = "Mythical",
	-- The night dealer (data-model section 8b): buy from this close to the cart. F94 (rewards-and-shops.md section 4):
	-- each server rolls its stock once at dusk and it holds all night.
	DealerRangeStuds = 20, -- #3448: 16 until the rings grew to radius 8; #3112: 12 until the walk-up rings grew to radius 6
	-- #3011 (Derek2 2026-11-10: "buff how often night market stocks good items"): no long dry spells. After this
	-- many nights in a row on one server with none of the food, the next night stocks at least 1 (shared/Dealer).
	DealerDryNights = { star_treat = 4, moon_milk = 3 } :: { [string]: number },
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
	-- CornerDailyLimits of a family, counted for each row on its own (#1712; a family not listed has none). Cat
	-- food has no daily XP cap (#1255).
	CornerShopWindowSeconds = 390, -- #1437: one game day from ClockEpoch, a restock at every sunrise (was 300)
	CornerShopRange = 22, -- #3448: 18 until the rings grew to radius 8; #3112: 14 until the walk-up rings grew to radius 6
	-- lawn-nursery.md section 7 (#1537): lawn pieces and styles are sold only at the Yard Sale (the Garden Nursery is
	-- retired). Each global game day rolls YardDecorRows rows, each a different piece or style: first a rarity by
	-- these weights (in percent), then a piece of it; a rarity with none left moves the roll one rarity down.
	YardDecorRows = 6,
	YardDecorRarityWeights = {
		Common = 28,
		Uncommon = 25,
		Rare = 20,
		Epic = 14,
		Legendary = 8,
		Mythical = 4,
		Golden = 1,
	},
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
	-- #1740 (Derek2, 2026-11-06): more of the cart in stock, about 14 of the 19 rows a day (was about 10)
	DayCartTopChance = 1,
	DayCartStep = 0.03,
	DayCartFloor = 0.25,
	DayCartQtyOdds = { 50, 30, 20 } :: { number },
	CornerDailyLimits = {
		steady = 4,
		quick_bait = 2,
		whistle = 4,
		lucky = 2,
		money = 3,
		big_money = 2,
		gold_rush = 2,
		-- #3462: the Tier 6 potions, one of each a game day
		big_lucky = 1,
		big_gold_rush = 1,
		mega_money = 1,
	} :: { [string]: number },
	CatFoodMax = 999, -- the most of one food the Bag holds
	-- corner-shop-v2.md section 3 (#1181): a net catch of a stray drops a Small Snack 1 time in 10 (free, from play,
	-- and its chance shows in the catch help), and every cat rescued from a trap gives one
	CatchSnackChance = 0.10,
	RescueSnack = "small_cat_snack",

	-- Rescue minigames (data-model section 10b)
	RescueSpawnChance = 0.6, -- per trap at each night start
	RescueMinStuck = 1, -- stuck cats every area gets at night start even when no trap rolled one
	-- #2240: the least distance between two of a day's traps picked from an area's rescue pool (RescuePick)
	RescueSpotSpacingStuds = 25,
	-- The bar per rarity: the marker's speed in bar lengths per second, the zone's width as a fraction of the bar.
	-- v0.13.15 F83 (harder rescues): 0.2 a second faster and narrower zones for every rarity.
	-- #2320 (Derek2: "lower the difficulty for rescue missions rare and lower"): Common 1.0 -> 0.85 and Rare 1.2 -> 1.05;
	-- Epic and up as they were. #2566 (Derek2 2026-11-09: "nerf the rare + rescue missions 30% slower"): Rare and up
	-- x0.7 (1.05, 1.4, 1.6 and 1.8 before), so the Rare's marker is now slower than the Common's; its narrower zone
	-- still leaves it less time inside.
	-- #3223 (Derek2 2026-11-11: "rescues are wayyy to easy making bar too big and speed to slow"): the zones were cut
	-- in #3120 the day before; this is the speed. Common 0.85 and Rare 0.735 before, so 18% and 22% faster, and the
	-- Rare is no longer far slower than the Common. Epic and up keep their speeds until Derek has played #3120's
	-- zones (Review-Agent: sped up as well, a phone player would free an Epic 36% of the time and a Mythical 8%).
	-- The Alleyway and Park ease and an account's first rescues (RescueFirstSpeed) still slow it.
	RescueBarSpeed = {
		Common = 1.00,
		Rare = 0.90,
		Epic = 0.98,
		Legendary = 1.12,
		Mythical = 1.26,
		Secret = 1.40, -- #3470 (assumed with Derek away): a step past the Mythical's, as its 8 hits are
	} :: { [string]: number },
	-- #2219: a miss now sends the bar back to the start, so the Mythical's zone went 0.10 -> 0.14 to keep its rescue
	-- near the old 11% at 50 ms (Design-Agent). Its faster marker still gives it the shortest time in the zone.
	-- #2320: Common 0.26 -> 0.30 and Rare 0.20 -> 0.23.
	-- #3120 (Derek2 2026-11-10: "make the rescue area about 10->50% smaller especially for the common->epic rescues are
	-- too easy now"): 0.30, 0.23, 0.15, 0.12 and 0.14 before, so 43%, 41%, 30%, 12% and 11% narrower. Speeds, hits and
	-- the area ease are as they were.
	RescueZoneWidth = {
		Common = 0.17,
		Rare = 0.135,
		Epic = 0.105,
		Legendary = 0.105,
		Mythical = 0.125,
		Secret = 0.115, -- #3470 (assumed)
	} :: { [string]: number },
	-- #3120: an account's first RescueFirstUses rescues (stats.rescues below it) have zones RescueFirstZone times as
	-- wide, about the widths before the cut (Common 0.29, Rare 0.23), so a new player's first rescues are no harder.
	-- #3180 (Derek2 2026-11-10: "make the starting rescue's easier and slightly smaller bars"): 3 rescues at 1.7
	-- before. The first five now, 1.85 times as wide (a first Common in the Alleyway has 0.44 of the bar, 0.42 before
	-- #3120), and the marker runs at RescueFirstSpeed of its speed on them (Rescue.speedScale).
	RescueFirstUses = 5,
	RescueFirstZone = 1.85,
	RescueFirstSpeed = 0.85,
	-- #3135 (Derek2 2026-11-10: "check if mutated cats gold/rainbow increase difficulty of catch and if thats not
	-- added add it"): it was not. A gold or rainbow cat's catch bands (Circles.windowsFor) and rescue zone
	-- (Rescue.zoneScale) are this times as wide. Not on the tutorial stray or an account's first rescues.
	CoatDifficulty = { gold = 0.90, rainbow = 0.80 } :: { [string]: number },
	-- #3140 (Derek2 2026-11-10: "speed up commons/rare in further maps slightly like tier 5+ it becomes to boring to
	-- wait", "speed up the circles"): in an area of QuickRingTier or later (the Sewer, Desert and Ruins) a Common or
	-- Rare cat's catch rings close in this times the rarity's shrink time: Common 1.20 s to 0.96 s, Rare 1.00 s to
	-- 0.85 s, which keeps Rare slower than Epic's 0.82 s. The bands stay the same seconds wide, so a ring is no harder
	-- to hit, only quicker to come; the ring count, the gaps and the rarer cats are unchanged.
	QuickRingTier = 5,
	QuickRingScale = { Common = 0.80, Rare = 0.85 } :: { [string]: number },
	RescueTolerance = 0.03, -- of the bar, either side of the zone
	-- #2786 (Derek2 2026-11-09: "nerf beginning area 1-2 rescue missions difficulty"; no tablet got past the first
	-- rescue): the first two areas' bars for every rarity. `zone` times RescueZoneWidth, `speed` times RescueBarSpeed
	-- and `fewerHits` off rescueHits (never below 2). Other areas are as above; Warm Paws multiplies on top.
	RescueAreaEase = {
		alley = { zone = 1.4, speed = 0.75, fewerHits = 1 },
		park = { zone = 1.2, speed = 0.85, fewerHits = 0 },
	} :: { [string]: { zone: number, speed: number, fewerHits: number } },
	-- F93 (catch-rework.md section 4): the marker gets RescueSpeedUpPerHit faster after every hit. Derek 2026-11-03
	-- ("a little confusing"): the zone stays where it is until it is hit (no more running out after two sweeps), and
	-- RescueTreeCircle false ends a tree on its last shake like any bar, with no falling cat's catch circle after it.
	RescueTreeCircle = false,
	RescueSpeedUpPerHit = 0.08,
	RescuePatience = 3, -- misses one attempt can take
	RescueRetrySeconds = 3, -- after a failed attempt, before anyone else can try that trap
	-- #3049: a starting area's trap by the camp, emptied during the day, gets a new cat this long after while a player
	-- who has never rescued is in the server with that area open (RescueService; Rescue.starterRefill)
	StarterRescueRefillSeconds = 30,
	-- at most this many refills an area a day, so a veteran cannot farm the trap beside a waiting first-timer
	StarterRescueRefillsPerDay = 4,
	RescueSelfRetrySeconds = 6, -- and before the player who failed can try it again
	-- #2566: 15 before; the slower Rare-and-up bar (x0.7) takes about 1/0.7 as long, so a steady player still fits
	RescueAttemptMaxSeconds = 22,
	GoldChanceRescue = 0.12, -- rolled at night start, hidden until the rescue succeeds (#2240: was 0.10)
	RescuedTipsMultiplier = 1.0, -- v0.3: a rescue pays no more; its reward is the higher gold chance

	TutorialGuaranteedStrayStep = 2, -- players below this tutorialStep always find a Common stray at alley point 1
	-- F87 (easy-start.md section 2): the intro waits for the Tutorial tile instead of playing by itself (true restores
	-- the F72 behaviour), and a player below TutorialGuaranteedStrayStep catches their own tutorial stray on one slow
	-- circle with bands TutorialWindowScale times as wide; a Miss brings the circle back after TutorialRetrySeconds
	-- with no sprint (#3181: anyone else may catch it too, and a new one comes). Below TutorialGuaranteedStrayStep
	-- nobody can tackle them either.
	-- #1575 (Derek, 2026-11-05) had the intro play on a first join. #3162 (2026-11-12): off again on the numbers
	-- (loaded to first move took 27 s and lost 9% of new players): a new player gets control at once, the ? tile
	-- glows and replays the intro. Back to true restores the first join play.
	IntroAutoPlay = false,
	-- #2766 (Derek2 2026-11-09, audience 16+ and past 100 visits): the next update's Roblox Event (Creator Hub,
	-- Events), its id and when it starts (os.time(), UTC). Until then a player past the tutorial gets one slide-in ask
	-- a session to tap Remind me, which opens Roblox's own Notify Me prompt; nil (or a past time) asks nothing. Add
	-- each new Event here. #3450 (Derek 2026-11-12): the ask comes 3 to 10 minutes into the session.
	-- Since 2026-11-13 (Derek: "make sure for the next event its prompting people in game to mark interested") this is
	-- a list, and the ask is for the first Event on it that has not started, so two listed Events need one change.
	UpdateEvents = {
		{ id = "4470282858327573133", startsAt = 1794583800 }, -- "New Station Menus", 2026-11-13 15:30 UTC
		{ id = "5904084271926215257", startsAt = 1794607200 }, -- "Speed Shoes + Secrets", 2026-11-13 22:00 UTC
		-- #4026 (Derek 2026-11-13 23:12 UTC: "yes to update everything"): "Cat Outfit Packs!", 2026-11-14 22:00 UTC,
		-- with its own words on the ask
		{
			id = "4733999329807827538",
			startsAt = 1794693600,
			title = "🔔 Next update Saturday: Cat Outfit Packs! Want a reminder when it lands?",
		},
	} :: { { id: string, startsAt: number, title: string? } },
	TutorialShrinkSeconds = 1.6,
	TutorialWindowScale = 2,
	TutorialRetrySeconds = 1.0,
	-- #2920 (Derek2 2026-11-10: "on first catch stop the minigame first circle when its over the circle and prompt them
	-- ... not even let the player click before its in the circle so you cant miss first one"): a player's very first
	-- catch (the tutorial stray, no cat caught yet) holds its ring on the target for up to FirstRingHoldSeconds (sent
	-- on the circle as holdSeconds); on since the Catch screen draws the hold (UI-Engineer, #2922). Not
	-- CatchHoldSeconds, the catch prompt's hold-to-start time
	CatchHoldFirstRing = true,
	FirstRingHoldSeconds = 60,
	-- F87 (easy-start.md sections 2g, 3 and 4): the hint pulses after StuckNudgeSeconds on one tutorial step and the
	-- "Need a hand?" card shows after StuckHelpSeconds (once per step per account); a context tip shows at most once
	-- every TipGapSeconds, a camera cut lasts at most TipCutMaxSeconds, and the one slide-in feedback ask waits for
	-- FeedbackAskMinutes of play in a session. The client times all of these. The server sends a tip that follows
	-- from the save TipStartSeconds after a join at the earliest, and takes FeedbackSessionLimit SendFeedback calls a
	-- session.
	StuckNudgeSeconds = 40,
	StuckHelpSeconds = 90,
	TipGapSeconds = 150, -- #2407 (Derek2: "tips pop up a little to often"): was 60
	TipCutMaxSeconds = 4,
	FeedbackAskMinutes = 12,
	TipStartSeconds = 10,
	FeedbackSessionLimit = 5,

	-- Night income and rich customers (F31, data-model sections 11 and 12)
	-- tips pay this share of the day rate at night; offline pay keeps the day rate. F60 (round 3 Q6): full pay, the
	-- cafe still closed with its cats asleep (v0.5 to v0.8 paid 0.6)
	NightIncomeMultiplier = 1,
	-- #1135: a rich customer comes when the cafe's timer, drawn from RichEveryMin to RichEveryMax seconds of open day,
	-- runs out (shared/VisitTimer); 480 on average since #2107 (Derek2: "slightly more often"; was 300 to 900, 600)
	RichEveryMin = 240,
	RichEveryMax = 720,
	RichTipSeconds = 120, -- a rich tip is this many seconds of the day rate (at least $50; F61: was 45)
	-- #3360 (rich-money-bags.md): the rich customer leaves a money bag on table 1 that waits RichBagSeconds from the
	-- drop, with no dusk clamp (RichTipStaySeconds 90, cut short at dusk, before). Unclaimed, it is gone (Derek
	-- 2026-10-28: "if you miss it you miss it"). Up to RichBagsMax wait at once; the customer sits
	-- RichCustomerSitSeconds for show.
	RichBagSeconds = 180,
	RichBagsMax = 3,
	RichCustomerSitSeconds = 20,
	RichBagFadeSeconds = 5, -- a bag fades out over its last seconds (display only)
	RichTipRangeStuds = 12, -- ClaimRichTip from this close to the bag (#3360; the plot's RichTipAnchor before)
	-- Tip piles (F61, data-model section 12, round 3 Q6): by day, every TipPileSeconds each earning cafe with a table
	-- gets a pile worth TipPileRateSeconds of the day rate (at least $5). Since F97 (notes-10-28-to-10-30.md section 1)
	-- a pile pays its owner the moment it appears, wherever they are; it shows on a table for TipPileShowSeconds and
	-- at most TipPilesMax show at once (in your own cafe F90's Waiter sweeps them to the till).
	TipPileSeconds = 30,
	TipPileRateSeconds = 6,
	TipPilesMax = 6,
	TipPileShowSeconds = 90,

	-- The Mystery Visitor and potions (F64, data-model section 12b). Potions are earned only, never sold.
	-- #1135: on a timer from MysteryEveryMin to MysteryEveryMax seconds of open day; 1250 on average, a fifth more
	-- often than the first 1500 (Derek2 2026-11-05: "up the rates of people leaving them slightly")
	MysteryEveryMin = 750,
	MysteryEveryMax = 1750,
	MysteryStaySeconds = 120, -- the hooded visitor sits this long; dusk or a plot release sends it home sooner
	MysteryGiftKeepSeconds = 900, -- an unopened gift is gone after this, or when its owner leaves (#2614: was 600)
	MysteryRareStreak = 4, -- #2614: after this many Common gifts in a row in a session, the next is Rare or better
	MysteryRangeStuds = 12, -- OpenMysteryGift from this close to the gift
	-- The Cat Collector (F63, data-model section 12b, round 3 Q6): by day, each earning cafe with a table and a
	-- resting, unlocked cat has him when its timer runs out (#1135: CollectorEveryMin to CollectorEveryMax seconds of
	-- open day, 300 on average since #2272, Derek2: "make it more common"; 360 to 840 since #2107, was 600 to 1400); he waits at the counter for CollectorStaySeconds. He values the cat he asks for at CollectorValue by its rarity, times
	-- CollectorGoldMultiplier for a gold cat, times a roll from CollectorRollMin to CollectorRollMax, and offers the
	-- best Catalog.collectorOffers row that value reaches.
	CollectorEveryMin = 200, -- #2272: was 360 (stays past CollectorStaySeconds)
	CollectorEveryMax = 400, -- #2272: was 840
	CollectorStaySeconds = 180,
	VisitRetrySeconds = 15, -- #1135: a visitor whose timer ran out while the cafe was not ready tries again this often
	-- #3889 (Derek 2026-11-13: "make it a % chance per customer walking in instead of it being a set time"): with
	-- the rareCustomers switch on, each open cafe gets a customer every RareCustomerSeconds (the street's own pace,
	-- World.CustomerSpawnSeconds) and each one is a rare customer at RareChance (shared/RareCustomers), in place of
	-- the three timers above. The chances keep today's averages: 6 / 480 rich, 6 / 1250 Mystery, 6 / 300 Collector.
	RareCustomerSeconds = 6,
	RareChance = { rich = 0.0125, mystery = 0.005, collector = 0.02 },
	-- #3470: a Secret is worth four Mythicals in a trade's value check (as its income); the Collector never asks for one
	CollectorValue = {
		Common = 1,
		Rare = 3,
		Epic = 8,
		Legendary = 20,
		Mythical = 50,
		Secret = 200,
	} :: { [string]: number },
	-- #1144: how much more often he asks for each askable catId by its rarity (Collector.pickCat), so a player's few
	-- rarer resting cats come up often for the bigger offers, not one time in many among their commons
	CollectorAskWeight = { Common = 1, Rare = 3, Epic = 5, Legendary = 6, Mythical = 6 } :: { [string]: number },
	CollectorGoldMultiplier = 3,
	CollectorRollMin = 0.8,
	CollectorRollMax = 1.5,
	-- #2792 (retention-ideas.md section 2, shared/FirstVisits): a new account's first rich customer, Mystery Visitor
	-- and Cat Collector come at these seconds of play on the account (about 3, 6 and 9 minutes), each once, and stay
	-- FirstVisitStaySeconds so a player out catching can still get back for it. Past FirstVisitWindowSeconds of play
	-- only the normal timers run.
	FirstVisitAt = { rich = 180, mystery = 360, collector = 540 },
	FirstVisitStaySeconds = 300,
	FirstVisitWindowSeconds = 1800,
	-- #2797 (retention-ideas.md 5d, shared/Invites): the invite reward. A new player who joined through an invite gets
	-- InviteRewardFish on their first catch; the inviter gets InviteRewardFish once that joiner has played
	-- InviteQualifySeconds or caught a cat, for at most InviteDailyMax joiners a UTC day and once per joiner (the last
	-- InviteRewardedMax remembered). The invite card shows once, between InviteCardFromSeconds and
	-- InviteCardBySeconds of play on the account; InvitePendingCheckSeconds is how often an online inviter's
	-- cross-server rewards are picked up.
	InviteRewardFish = 20,
	InviteQualifySeconds = 300,
	InviteDailyMax = 5,
	InviteRewardedMax = 50,
	InviteCardFromSeconds = 300,
	InviteCardBySeconds = 900,
	InvitePendingCheckSeconds = 60,
	CollectorRangeStuds = 12, -- his card opens this close to him (#3216: AnswerCollector works from anywhere)
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
	-- #3688: the money boards' safety net against a bad number. It was 10,000,000, which top cafes passed, so they
	-- all read $10M a second; now far above anything a cafe can reach, and still a whole number the store holds exactly
	LeaderboardRateMax = 1000000000000000,
	LeaderboardCrownRank = 10,
	LeaderboardFaceSwapSeconds = 15,
	-- #3466 (a player's idea): one gold system line in chat for everyone here when a player in the top
	-- LeaderboardJoinNoticeRank of an all-time board joins, LeaderboardJoinNoticeDelay seconds after their save loads
	-- (so their own chat window has it too), from the lists the server already holds. Not again for the same player
	-- within LeaderboardJoinNoticeRejoinSeconds on this server. LeaderboardJoinNotice false turns it off.
	LeaderboardJoinNotice = true,
	LeaderboardJoinNoticeRank = 10,
	LeaderboardJoinNoticeDelay = 5,
	LeaderboardJoinNoticeRejoinSeconds = 600,

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
	SpinStationRange = 22, -- #3448: 18 until the rings grew to radius 8; #3112: 14 before the radius 6 rings; SpinWheel from this close to a station tagged SpinWheel
	SpinCooldownSeconds = 4, -- the spin animation; a player's next spin waits this long
	SpinAllMax = 51, -- #1078: Use all spends at most this many spins in one press (SpinBankCap and today's free one fit)
	SpinBankCap = 50, -- banked spins stop here (#1414: 20 to 50, so two Tip Jar sessions a day keep every spin)

	-- Golden fish (F52, golden-fish.md sections 1 and 2): the rare currency, earned only, never sold or given for
	-- Robux. Pure rules in GoldenFish.
	-- a cat new to the Index, any way it was found; its first gold pays twice this
	-- #2237 (Derek2 2026-11-07: "decrease the amount of gold fish received"): every free source about 60%, the Index half
	-- #3470 (assumed with Derek away): a Secret pays four times a Mythical here and in FishRepeatCatch
	FishFirstCatch = {
		Common = 1,
		Rare = 2,
		Epic = 5,
		Legendary = 12,
		Mythical = 25,
		Secret = 100,
	} :: { [string]: number }, -- was 1/3/8/20/40
	-- a cat already in the Index, by net or rescue (never bait, so food bought with coins never turns into fish)
	FishRepeatCatch = { Epic = 1, Legendary = 2, Mythical = 5, Secret = 20 } :: { [string]: number }, -- #2237: was 1/3/8
	-- reaching Tier 2 to 7 (#2237: was 10/25/50/100); #2651: Tier 6 and 7 carry the climb on, 100 and 150
	FishRankUp = { 5, 15, 30, 60, 100, 150 } :: { number },
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
	FishMarketRange = 22, -- #3448: 18 until the rings grew to radius 8; #3112: 14 before the radius 6 rings; OpenCrate and BuyFishItem from this close to a FishMarket station
	-- #2565 (mystery-market.md section 2): Juniper's Mystery Market. Every item is on the shelf all the time; one a week
	-- is on sale at MysterySaleShare of its price. The week starts at MysteryEpoch, Saturday 2026-11-07 00:00 UTC, so
	-- the launch week's sale is the Backpack (Catalog.mysteryItems' first row). MysteryOpen false refuses BuyMystery
	-- outside Studio: the owned items are new save fields an older server would drop, so the shelf opens with the
	-- ProfileSchema.VERSION bump in a publish that restarts the servers (Derek2's call).
	MysteryEpoch = 1794009600,
	MysteryRotateSeconds = 604800, -- one week
	MysterySaleShare = 0.75,
	-- #3535: featured weeks set by date, which win over the weekly rotation (shared/MysteryMarket.featuredAt). `from`
	-- and `to` are os.time() seconds; outside them the rotation runs. Friday 2026-11-13 22:00 UTC, the update: the
	-- Speed Shoes for a week (so the Backpack is back at its full price from that moment), then the Long Net until
	-- Saturday 2026-11-28 00:00 UTC, where the rotation's own week starts and carries on with the Backpack.
	MysteryFeatured = {
		{ from = 1794607200, to = 1795212000, id = "speed_shoes" },
		{ from = 1795212000, to = 1795824000, id = "long_net" },
	} :: { { from: number, to: number, id: string } },
	SpeedShoesCarryBonus = 3, -- #3535: walk speed the Speed Shoes add while carrying a cat (16 to 19), never up to the walk speed with no cat
	MysteryOpen = true, -- version 44 (#2565): buying opens with the save bump
	MysteryMarketRange = 22, -- #3448: 18 until the rings grew to radius 8; #3112: 14 before the radius 6 rings; BuyMystery from this close to the MysteryMarket cart, like the Fish Market
	LongNetReachStuds = 8, -- #2565: the Long Net's reach, for NetReachStuds (mystery-market.md section 4)
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
	DecorIndexHalfFish = 15, -- #2237: was 25; golden fish: a Decor Index page's decor5 prize (five of ten, F54)
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
	-- Rainbow v2 (rainbow-coat.md section 4b, Derek 2026-11-05): three times v1 (0.005, 0.005, 0.01), so 3 in 10 of
	-- gold's chance; no paint.
	RainbowChanceNet = 0.015,
	RainbowChanceBait = 0.015,
	RainbowChanceRescue = 0.036, -- #2240 (Derek2 2026-11-07: rescues get better coat odds): was 0.03
	RainbowMultiplier = 2, -- Derek2 2026-11-07: "turn rainbow down to 2x" (was 3)
	RainbowLuckMax = 0.4, -- #2269 (Derek2 2026-11-07: nerf the Index's rainbow luck): was 1.0
	CollectorRainbowMultiplier = 10,
	RainbowAnimateMax = 10,
	RainbowSpawnToastSeconds = 60,
	-- golden fish for each cat's first rainbow coat: this times the rarity's FishFirstCatch (Common 3 to Mythical
	-- 75 since #2237), any way it was found, on top of a new cat's fish (section 1, added after the #795 review)
	FishFirstRainbowMultiplier = 3, -- #2237: was 5

	-- Trading (F102, trading.md section 6; Derek 2026-10-30: from Tier 3, secure, nothing to scam). Up to TradeMaxCats
	-- cats (and since #1574 TradeMaxDecor pieces) a side, both players at TradeMinTier or higher (CatCafeDebug
	-- tradeMinTier lowers it in one server).
	-- A request waits TradeRequestSeconds; declined or timed out, the asker waits TradeReaskSeconds to ask that player
	-- again. TradeCountdownSeconds after both press Ready the confirm screen opens; a lopsided trade (one side gives at
	-- least TradeLopsidedRatio times the Collector value it gets) or a gift holds that side's Confirm for
	-- TradeConfirmWaitSeconds. TradeCooldownSeconds between a player's trades, TradesPerDay a game day (#1629, was a
	-- UTC day). The Trades page keeps TradeLogMax trades, the save TradeIdsMax applied trade ids. Every server reads the
	-- CatCafe_Flags kill switch every TradeFlagCheckSeconds.
	TradeMinTier = 3,
	TradeMaxCats = 9,
	TradeMaxDecor = 9, -- #1574 (section 1b): decor and lawn pieces a side, beside the cats
	-- #2745 (section 1c): banked crates a side, at most TradeMaxCrateKinds kinds and TradeMaxCrates crates in all
	TradeMaxCrateKinds = 6,
	TradeMaxCrates = 20,
	-- #2745 (section 1d): golden fish a side (whole fish, at most the giver's wallet), the most one player may receive
	-- in trades in a game day, and one fish's Collector value for the lopsided warning (40 fish count as one Rare, 3)
	TradeMaxFish = 200,
	TradeFishPerDay = 250, -- Derek2 2026-11-10: "250 golden fish limit lowered is fine" (400 before; less room for alt farming)
	TradeFishValue = 0.075,
	TradeCountdownSeconds = 5,
	TradeLopsidedRatio = 3,
	TradeConfirmWaitSeconds = 2,
	TradeRequestSeconds = 20,
	TradeReaskSeconds = 3, -- #2550 (Derek2): was 60; a declined or lapsed ask can be sent again a moment later
	-- #2550 review (young audience): after this many declines in a row from one player, the asker can't ask them again
	-- until that player asks back or either leaves the server (TradeBook.declinedOut)
	TradeDeclinesToStop = 2,
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
	-- the Lost and Found (Sewer) keeps one find every LostFoundEverySeconds up to LostFoundHold, each a roll of
	-- LostFoundTable (#1732, camp-stations.md section 4b; chances add to 1, shown on its card; a lostCat row is an Epic
	-- from the player's open areas). Each is collected within CampExtraRangeStuds of its PromptAnchor.
	PicnicEverySeconds = 21600,
	PicnicHold = 2,
	-- Picnic Treats (#3715, behind the `picnicTreats` switch): one pick every PicnicTreatSeconds, holding
	-- PicnicTreatHold. At most 6 potions a day for a player who comes back every 4 hours.
	PicnicTreatSeconds = 14400,
	PicnicTreatHold = 1,
	PicnicPotion = "tip_potion",
	YardSaleClaimHours = 4,
	-- #3609 (Derek 2026-11-12, table OK'd 15:09 UTC; camp-stations.md section 3a), behind the `yardSaleRoll` switch: a
	-- free lucky pick every YardSaleRollHours that always wins a crate (shared/YardPick). The four groups' chances add
	-- to 1; `area` and `goldenArea` are split evenly over the player's open areas. Never sold, and nothing changes it.
	YardSaleRollHours = 2,
	YardSaleTable = { classic = 0.38, area = 0.50, goldenClassic = 0.08, goldenArea = 0.04 },
	PondFishPerStep = 1,
	PondStepSeconds = 900, -- #2237: 4 an hour, was 600
	PondHold = 24, -- #2237: still 6 hours' worth, was 36
	LostFoundEverySeconds = 7200,
	LostFoundHold = 3,
	LostFoundTable = {
		{ chance = 0.30, fish = 25 }, -- #2237: was 40
		{ chance = 0.22, potions = { lucky_potion = 1, gold_rush_potion = 1 } },
		{ chance = 0.15, spins = 2 },
		{ chance = 0.18, crate = "sewer_crate" },
		{ chance = 0.10, crate = "classic_golden_crate" },
		{ chance = 0.03, crate = "sewer_golden_crate" },
		{ chance = 0.02, lostCat = "Epic" },
	} :: {
		{
			chance: number,
			fish: number?,
			potions: { [string]: number }?,
			spins: number?,
			crate: string?,
			lostCat: string?,
		}
	},
	-- #3050 (the Rummage Bin at the Alleyway camp, shared/RummageBin): one press plays a short rescue bar and a win
	-- pulls one BinTable prize out (chances add to 1, shown on its prompt). The account's first BinFirstUses rummages
	-- are easier (BinFirstEase on top of BinZoneWidth and BinBarSpeed) and BinFirstRepeatSeconds apart; after that
	-- the bin fills every BinCooldownSeconds. A miss costs nothing and waits BinMissRetrySeconds. The first win is
	-- always BinFirstPrizes[1], the second BinFirstPrizes[2] and so on (#3460: their own rows, below). #3680: not with
	-- `binRoll` on (live since 2026-11-12), where every rummage rolls BinRollTable ("no scripted starting rewards").
	BinFirstUses = 3,
	BinFirstRepeatSeconds = 180,
	BinCooldownSeconds = 900,
	BinMissRetrySeconds = 10,
	-- Design-Agent on #3050 after #3120 and #3223: the bin's bar is set in absolute numbers and never follows the
	-- rescue bars' RescueZoneWidth or RescueBarSpeed, so a rescue change never makes the bin harder: the old Common
	-- zone with the Alleyway's ease (0.30 x 1.4), and 0.85 x 0.75 bar lengths a second.
	-- #3458 (Derek 2026-11-12: "make the game require 5 hits and medium bit faster and a lot smaller area"): the
	-- bin's own hit count (BinHits, never the rescue's), its zone 0.42 to 0.22 and its marker 0.64 to 0.80. The
	-- first BinFirstUses rummages keep BinFirstEase's wider zone (0.35) and need the 5 hits too. Their marker runs
	-- at the full BinBarSpeed since 2026-11-12 (Derek on the live game: "the moving marker is too slow not the same
	-- speed as the studio version"): a new account saw 0.48 where his practised Studio save saw 0.80.
	BinHits = 5,
	BinZoneWidth = 0.22,
	BinBarSpeed = 0.80,
	BinFirstEase = { zone = 1.6, speed = 1 },
	-- #3460 (Derek 2026-11-12: "make the rummage bin rewards a bit better so people get a good starting boost
	-- also"): an account's first three wins are these fixed prizes in order, their own rows apart from BinTable, so
	-- they never change the rolled chances. A row may hold more than one thing; `count` is how many of its lure,
	-- crate or potion (1 when left out).
	BinFirstPrizes = {
		{ id = "first_tuna", lure = "tuna", count = 2, fish = 10 },
		{ id = "first_crate", crate = "alley_crate", potion = "lucky_potion" },
		{ id = "first_salmon", lure = "salmon", fish = 10 },
	} :: {
		{
			id: string,
			chance: number?,
			count: number?,
			lure: string?,
			fish: number?,
			crate: string?,
			potion: string?,
		}
	},
	-- #3608 (Derek 2026-11-12: "ticks through the options a couple times before landing on one ... then you play the
	-- minigame for that reward and make the rewards decent"; table OK'd 15:09 UTC with 2 Salmon and 8 golden fish):
	-- behind the `binRoll` switch the prize is rolled from BinRollTable BEFORE the bar and kept for the player until
	-- they win it (shared/RummageBin). Rows are in the board's order, most common on top; chances add to 1; `tier`
	-- (1 to 3) sets how big the effects are. Nothing here is sold. The pad in front of the bin starts a rummage for
	-- a player who has stood on it BinPadDwellSeconds; the roll shows for BinRollSeconds (a tap skips it) and a
	-- fixed first prize, which is not rolled, for BinRevealSeconds.
	BinRollTable = {
		{ id = "tuna", chance = 0.28, lure = "tuna", count = 2, fish = 3, tier = 1 },
		{ id = "fish", chance = 0.22, fish = 10, tier = 1 },
		{ id = "salmon", chance = 0.15, lure = "salmon", count = 2, fish = 8, tier = 1 },
		{ id = "crate", chance = 0.15, crate = "alley_crate", tier = 2 },
		{ id = "potion", chance = 0.12, potion = "lucky_potion", tier = 2 },
		{ id = "golden", chance = 0.05, crate = "alley_golden_crate", tier = 3 },
		{ id = "bigmoney", chance = 0.03, potion = "big_tip_potion", tier = 3 },
	} :: {
		{
			id: string,
			chance: number?,
			count: number?,
			lure: string?,
			fish: number?,
			crate: string?,
			potion: string?,
			tier: number?,
		}
	},
	BinPadRadius = 4,
	BinPadDwellSeconds = 0.5,
	BinRollSeconds = 2.5,
	BinRevealSeconds = 1,
	BinTable = {
		{ id = "tuna", chance = 0.34, lure = "tuna", count = 2 },
		{ id = "fish", chance = 0.25, fish = 8 },
		{ id = "salmon", chance = 0.15, lure = "salmon" },
		{ id = "potion", chance = 0.12, potion = "lucky_potion" },
		{ id = "crate", chance = 0.12, crate = "alley_crate" },
		{ id = "golden", chance = 0.02, crate = "alley_golden_crate" },
	} :: {
		{
			id: string,
			chance: number?,
			count: number?,
			lure: string?,
			fish: number?,
			crate: string?,
			potion: string?,
		}
	},
	-- #2651 part 4 (late-stations.md): the Oasis Spa (Desert camp, Tier 6) gives a cat +1 level after SpaSeconds of
	-- real time (offline too), one slot free and two more bought once with golden fish at SpaSlotPrices; each Relic
	-- Museum (Ruins camp, Tier 7) room filled adds MuseumRoomTipBonus to the tips-forever total. LateStationsOpen
	-- places them and opens their remotes once the UI's cards are in (UI-Engineer).
	-- #2904 (Derek2 2026-11-10: "+1 level an hour and caps at 24h ... doesn't go past the lvl 50 cap"): a soaking
	-- cat earns a level every SpaSeconds, up to SpaMaxHours of them, never past CatMaxLevel
	SpaSeconds = 3600,
	SpaMaxHours = 24,
	SpaSlotPrices = { 0, 100, 250 },
	MuseumRoomTipBonus = 0.05, -- #2908 (Derek2 2026-11-10: "up the tips bonus to be 5% per room filled"; was 0.02)
	LateStationsOpen = true, -- on since the Spa and Museum cards are in (#2931)
	CampExtraRangeStuds = 18, -- #3448: 14 until the rings grew to radius 8; #3113: 8 until the camp stations got radius 6 rings; from the PromptAnchor at the front

	-- The Rescue Rally weekend (F101, rescue-rally.md; shared/Rally, Catalog.rallySteps). From RallyStartWeekday (0 is
	-- Sunday) 00:00 UTC for RallyHours, or at any time with RallyForce, each server fills one bar together. The goal is
	-- RallyPointsPerPlayer times the players (never fewer than RallyMinPlayers' worth), fixed when the lap starts; a
	-- step pays everyone in the server who scored RallyMinPoints this lap, from at most RallyMaxLaps laps a weekend.
	RallyStartWeekday = 6,
	RallyHours = 48,
	-- #2227 (Derek2 2026-11-07: "extend how long rally lasts", "1 week extend is fine"): a Rally that starts at or after
	-- RallyExtendFrom runs on until RallyExtendUntil (UTC seconds), joining the next weekend's. Equal values turn it off.
	RallyExtendFrom = 1794009600, -- Saturday 2026-11-07 00:00 UTC
	RallyExtendUntil = 1794787200, -- Monday 2026-11-16 00:00 UTC, the end of the 11-14 weekend
	RallyPointsPerPlayer = 22, -- #2018: was 30, so a lap fills about a third sooner
	RallyMinPlayers = 3,
	RallyMinPoints = 3,
	RallyMaxLaps = 10, -- #2608 (Derek2 2026-11-09: "change 4 paid to 10"): was 4
	-- #2608 (Design-Agent's curve): each lap of a server's Rally pays RallyLapFishStep more step fish than lap 1, up to
	-- lap RallyLapCap (x1.3), each step rounded up; Rally.prizeFor also upgrades two potions from laps 3 and 4
	RallyLapFishStep = 0.10,
	RallyLapCap = 4,
	RallyPoints = { checkIn = 1, tame = 1, rescue = 3, teamRescue = 3 } :: { [string]: number },
	RallyForce = false,
	RallyStateSeconds = 0.5, -- RallyState goes out at most this often while points come in (steps go at once)

	-- Codes and the Codes Cat (F65, data-model section 11d). Codes are letters, digits and Codes.SYMBOLS, in any case.
	CodesCatRange = 20, -- #3448: 16 until the rings grew to radius 8; #3112: 12 before the radius 6 circle; the Codes Cat's box opens this close to a CodesCat station's pivot (RedeemCode works anywhere, #1747)
	CodesCircleRadius = 8, -- #3448: 6 until the rings grew to radius 8; #3112 (Derek2: "make the circles infront of the stations bigger"): 4 to 6; the code box opens within this flat distance of the CodesCircle, closes past it + 1
	-- #3062 (Circle Streak, shared/Arcade): one run costs ArcadeCostFish golden fish; Perfect +2, Good +1, to
	-- ArcadeMaxPoints. Every ArcadeStepEvery points the circles shrink ArcadeShrinkStep quicker and the windows narrow
	-- by ArcadeWindowStep, the wobble rising toward ArcadeJitterMax. ArcadeStartShrinkSeconds is a Common stray's
	-- shrink time (circles 1 to 10 easy for anyone who has caught a cat). ArcadeBlockLeadIn is the breath before each
	-- block of 10 circles. Each milestone pays once per UTC day (Derek2 2026-11-10: 5 fish at 10 "so people who are
	-- bad get some more to attempt early on"; the fish prizes stay 5, 8, 15 and 30). Nothing here is sold.
	-- #3359 (Derek2 2026-11-11: "put starting speed at 2x scaling up much faster game is too easy"; numbers from
	-- Design-Agent): the start is twice a Common's pace (1.20 to 0.60 s), a step every 5 points (was 10) up to
	-- Arcade.MAX_STEP 20 (was 10), so it keeps getting harder to 100: about 0.47 s at 30, 0.40 at 50, 0.27 at 100.
	-- ArcadeShrinkFloorSeconds keeps the wobble from pushing a circle under reaction time.
	ArcadeCostFish = 1,
	ArcadeMaxPoints = 100,
	ArcadeStepEvery = 5,
	ArcadeShrinkStep = 0.96,
	ArcadeWindowStep = 0.97,
	ArcadeJitterMax = 0.20,
	ArcadeStartShrinkSeconds = 0.60,
	ArcadeShrinkFloorSeconds = 0.30,
	ArcadeBlockLeadIn = 0.9,
	ArcadeMilestones = {
		-- Derek 2026-11-13 ("make the overall rewards inside the cat arcade game way better so people actually come
		-- back to do them daily"): every milestone pays about three times what it did (#3869). Fish stay under
		-- TradeFishPerDay in all (240); the rest is foods, potions and crates, which cannot be traded for fish.
		{ at = 10, prize = { fish = 15, lures = { salmon = 1 } }, name = "15 fish + Salmon" },
		{
			at = 20,
			prize = { fish = 15, potions = { lucky_potion = 1 } },
			name = "15 fish + Lucky Potion",
		},
		{
			at = 30,
			prize = { crates = { classic_golden_crate = 1 }, lures = { caviar = 1 } },
			name = "Golden Crate + Caviar",
		},
		{
			at = 40,
			prize = { fish = 20, potions = { big_lucky_potion = 1 } },
			name = "20 fish + Big Lucky Potion",
		},
		{
			at = 50,
			prize = { fish = 25, crates = { classic_golden_crate = 2 } },
			name = "2 Golden Crates + 25 fish",
		},
		{
			at = 60,
			prize = { fish = 25, crates = { alley_golden_crate = 1 }, lures = { moon_milk = 1 } },
			name = "Alley Crate + Moon Milk + 25 fish",
		},
		{
			at = 70,
			prize = { fish = 30, lures = { caviar = 3 }, potions = { gold_rush_potion = 1 } },
			name = "3 Caviar + Gold Rush + 30 fish",
		},
		{
			at = 80,
			prize = { fish = 35, crates = { alley_golden_crate = 2 } },
			name = "2 Alley Crates + 35 fish",
		},
		{
			at = 90,
			prize = { fish = 25, lures = { moon_milk = 3 }, crates = { classic_golden_crate = 2 } },
			name = "3 Moon Milk + 2 Golden Crates",
		},
		{
			at = 100,
			prize = { fish = 50, lures = { star_treat = 3 }, crates = { alley_golden_crate = 2 } },
			name = "3 Star Treats + 2 Alley Crates + 50 fish",
		},
	} :: { { at: number, prize: { [string]: any }, name: string } },
	-- #3296 (Mouse Dash, shared/MouseDash, mouse-dash.md section 6): the arcade's second game. Three hearts; every
	-- MouseDashStepEvery points the mouse's window is x MouseDashWindowStep (never under the floor: a phone's tap
	-- plus the trip to the server needs 0.40 s) and the gap before the next x MouseDashGapStep. Golden mice from
	-- 10 points, napping kittens from 20, two at once from 30 (one of them may be a kitten from 40). It shares
	-- ArcadeMaxPoints, ArcadeCostFish and ArcadeMilestones with Circle Streak.
	MouseDashHearts = 3,
	MouseDashStepEvery = 5,
	MouseDashWindowStart = 1.10,
	-- Derek 2026-11-13 ("scale up the time so that people can actually get 100"): the window shrinks x 0.96 a step (was
	-- 0.93) to a 0.45 s floor (was 0.40), so it is 0.73 s at 50 points (was 0.53) and 0.49 s at 100 (was 0.40 from 65)
	MouseDashWindowStep = 0.96,
	MouseDashWindowFloor = 0.45,
	MouseDashGapStart = 0.50,
	MouseDashGapStep = 0.95,
	MouseDashGapFloor = 0.25,
	MouseDashGoldenFrom = 10,
	MouseDashGoldenChance = 1 / 12,
	MouseDashGoldenPoints = 3,
	MouseDashGoldenWindowScale = 0.75,
	MouseDashKittenFrom = 20,
	MouseDashKittenChance = 0.125,
	MouseDashPairFrom = 30,
	MouseDashPairChance = 0.20,
	MouseDashPairKittenFrom = 40,
	MouseDashHeartBackEvery = 10, -- catches in a row for a heart back
	MouseDashDizzySeconds = 0.40, -- after a tap on an empty hole (which costs a heart since 2026-11-12)
	-- Derek 2026-11-12, on the live game: "make a timer for how long left in the minigame". A run has this long from
	-- its first mouse; a perfect 100 point win takes up to about 110 s, so the clock ends only a slow run. 240 s (was
	-- 180) since the slower windows of 2026-11-13, so a careful run to 100 never meets the clock.
	MouseDashRunSeconds = 240,
	MouseDashFirstRunMice = 3, -- a first ever run opens with this many slow mice that cannot cost a heart
	MouseDashFirstRunWindow = 2.0,
	MouseDashMouserAt = 50, -- points for the Mouser title
	-- #2997 (shared/UpdateGift): the gift each Saturday content update carries, paid once per id from `from` (os.time())
	-- on. Change `id` and `from` with each Saturday update (17:00 UTC); nil turns it off.
	-- #3535 (Derek 2026-11-12: Friday's update, "instead of golden fish giveaway 3 different golden crates"): Friday
	-- 2026-11-13 from 22:03 UTC, three minutes after that update's restart. A Classic and an Alleyway Golden Crate
	-- and the golden crate of the best area the player has opened (a second Classic for a player whose best is the
	-- Alleyway; shared/UpdateGift.prize).
	-- #3779 (Derek 2026-11-13: "its just giving 100 gold fish per person that logs in now and its not turned off"):
	-- `to` ends a gift, and every gift carries one. The launch gift (id "2026-11-12", 100 fish) ended at 02:00 UTC
	-- on 2026-11-13; what was paid stays paid. Friday's ends when Saturday's starts.
	UpdateGift = {
		id = "2026-11-13",
		from = 1794607380,
		fish = 0,
		spins = 0,
		crates = { classic_golden_crate = 1, alley_golden_crate = 1, highest_golden = 1 },
		to = 1794675600,
	} :: {
		id: string,
		from: number,
		fish: number,
		spins: number,
		crates: { [string]: number }?,
		to: number?,
		traitTokens: number?,
	}?,
	-- Derek 2026-11-13 14:24 UTC, the 15:30 UTC station menus update: "run a couple giveaways of first 10 trait
	-- rerolls for everyone online (2-3 minutes after server restart) then 100 gold fish 4-5 minutes after server
	-- restart". Each pays once per account, to everyone in game from `from` and to anyone who joins before `to` (the
	-- Update Party's end), beside the update gift (PlaytimeGiftService). Same fields as UpdateGift, plus traitTokens.
	Giveaways = {
		{
			id = "2026-11-13-tokens",
			from = 1794583980,
			to = 1794587400,
			fish = 0,
			spins = 0,
			traitTokens = 10,
		},
		{ id = "2026-11-13-fish", from = 1794584100, to = 1794587400, fish = 100, spins = 0 },
		-- Growth's weekend plan (Derek yes 2026-11-13 23:49 UTC): 10 free trait rerolls for everyone who plays on
		-- Sunday 2026-11-15 from the Rift Run update, 3 minutes after its 20:00 UTC restart, to midnight Toronto time
		{
			id = "2026-11-15-tokens",
			from = 1794772980,
			to = 1794805200,
			fish = 0,
			spins = 0,
			traitTokens = 10,
		},
	} :: {
		{
			id: string,
			from: number,
			to: number?,
			fish: number,
			spins: number,
			crates: { [string]: number }?,
			traitTokens: number?,
		}
	},
	-- The gift after UpdateGift, which takes over at its own `from` (shared/UpdateGift.pick).
	-- #3497: the weekly gift again, Saturday 2026-11-14 17:00 UTC for one week. It is set here ahead of time so the
	-- servers started by Friday's restart already carry it: a later publish reaches new servers only.
	UpdateGiftNext = {
		id = "2026-11-14",
		from = 1794675600,
		fish = 15,
		spins = 1,
		to = 1795280400,
	} :: {
		id: string,
		from: number,
		fish: number,
		spins: number,
		crates: { [string]: number }?,
		to: number?,
		traitTokens: number?,
	}?,
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
	-- a fresh carry cannot be knocked loose for this long. #2193 (Derek2, 2026-11-07: "make it guaranteed"): 0, so a
	-- tackle that lands always drops the cat (was 3)
	BumpGraceSeconds = 0,
	BumpSafeRadiusStuds = 15, -- round both doors of the target's own cafe, as well as its plot
	-- #2193 (Derek2, 2026-11-07: "everyone should always be able to be tackled unless they are mid minigame"): no
	-- timed immunity. The same tackler on the same target (was 20 s) and anyone on a player just hit (was 4 s, S45)
	-- are both 0; each tackler still waits their own TackleCooldownSeconds.
	BumpSameTargetSeconds = 0, -- per tackler and target
	ShoveKnockbackStuds = 10, -- the target's client pushes its own character this far
	ShoveTargetImmuneSeconds = 0, -- after a hit lands, nobody can hit that player again for this long (S45)
	-- #3342 (Derek2 2026-11-11: "tackling immunity for the first 5 minutes"): nobody can tackle a player for this long
	-- after they join a server, each session. Their own tackle press (one the server takes) ends it early.
	-- #3475 (Derek 2026-11-12: "make the tackle immunity up to 15 mins instead of 5"): 300 to 900.
	TackleShieldSeconds = 900,
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
		StreetSouthZ = -178, -- #3070: -163 before the 120 x 140 square (#3001: -152, #2707: -140 before that)
		StreetNorthZ = 178, -- #3070: 163 before; the street ends at the hometown's north welcome arch (v4)
		-- v4 (F84, hometown-cannon.md section 2): the hometown's own ground round the town, and each wild area its own
		-- CatCafe_Town_Backdrop (Model-Agent #733) is built against 272 by 332 (#917): tell Model-Agent when these change
		TownGroundWidth = 272,
		TownGroundDepth = 408, -- #3070: 378 before (#3001: 356, #2707: 332 before that)
		WallHeight = 9,
		DoorWidth = 7,
		-- The Town Square: paved, centred on the origin across the street, with the stations round the Cat Cannon (the
		-- fountain until v4) and a cross of open paving (the street's line and an east to west lane, which led to the
		-- side arches into the back alleys until v4 closed them). Its gardens fill the rest of the width out to the yards.
		-- #3001 (Derek2 2026-11-10: "expand the town square"): 120 x 110, a quarter more each way. The width grows
		-- inside the town edge (TownEdgeX stays), so the side gardens are 9 deep; the depth moves the cafes back 11.
		TownSquareHalfWidth = 60, -- 48 before
		-- #3070 (Derek2 2026-11-10: "expand the town square again"): 120 x 140. Only the depth grows (the town edge
		-- holds the width), which moves the cafes back another 15.
		TownSquareHalfDepth = 70, -- #3070: 55 before (#3001: 44, #2707: 32 before that)
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
		-- The Desert and the Ruins (Tier 6 and 7, tier6-7-areas.md sections 2, 4 and 5; #2651): on the two free
		-- diagonals on the town's east side, about 1980 out, both long along world Z with the camp on the town end, the
		-- Desert's north and the Ruins' south. Built by WorldBuilder from Catalog.areas since version 462.
		DesertCenterX = 1400,
		DesertCenterZ = -1400,
		DesertWidth = 150,
		DesertDepth = 560,
		RuinsCenterX = 1400,
		RuinsCenterZ = 1400,
		RuinsWidth = 140,
		RuinsDepth = 600,
		-- The Snowy Mountain (Tier 8, the next-areas plan Derek OK'd 2026-11-13; #3997): on the last free diagonal, the
		-- town's north west, long along world Z with its camp on the south (town) end like the Ruins. Model-Agent's
		-- CatCafe_Snowy_Set has its walls at x +-75 and z +-280. Layout.snowy only: nothing builds it until
		-- Catalog.areas lists it.
		SnowyCenterX = -1400,
		SnowyCenterZ = 1400,
		SnowyWidth = 150,
		SnowyDepth = 560,
		-- Camps (section 4): CampDepth deep across the area's whole width; the landing pad in its middle with
		-- seventeen spots inside LandingPadRadius, a spot free with no character within LandingClearStuds; the cannon
		-- prompt's reach. A dropped cat within CampDropMarginStuds of a camp moves out to CampDropOutStuds past its
		-- edge. CampOpeningWidth is the F85 fence's opening (F84 camps keep their gates' widths).
		CampDepth = 30,
		CampOpeningWidth = 24,
		LandingPadRadius = 8,
		LandingClearStuds = 3,
		CannonRangeStuds = 10,
		-- #3671 (Derek 2026-11-12: "expand the town square cannon circle a bit"): the Town Square cannon's own reach;
		-- its ring fills it (WalkUp.EDGE_SLACK inside), radius 9.5 (about 7.3 before), where the camps' stay as they
		-- were. The spawn is 14 studs from the cannon and the nearest landing spot 11, both outside the ring, and the
		-- landing circle's edge (10 studs out) stays half a stud clear of it
		TownCannonRangeStuds = 11.5,
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
