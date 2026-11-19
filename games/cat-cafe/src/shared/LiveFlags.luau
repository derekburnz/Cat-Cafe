--!strict
-- Live switches for features that may need to go off fast after a release (#2119), beside trading's own `trading`
-- and `tradeMinTier` (TradeVault). They live in the CatCafe_Flags DataStore (`_dev` in Studio), one boolean key
-- each, written by the flags workflow (tools/opencloud/flags.sh). LiveFlagService reads them every CHECK_SECONDS,
-- so a change reaches every running server within about a minute, with no publish and no restart.
-- - `codes`: false answers every RedeemCode with PAUSED and pays nothing (CodeService).
-- - `rally`: false stops a running Rescue Rally and keeps the next one from starting (RallyService). What was
--   already paid stays paid; turned on again mid-weekend, the bar starts again at lap 1 and the save's laps cap holds.
-- - `tradeCrates` (#2745, trading.md section 1c): false takes every crate off the open trades and refuses new crate
--   offers (TradeService); cat and decor trades go on.
-- - `tradeFish` (#2745, trading.md section 1d): golden fish in trades. It starts OFF (OFF_BY_DEFAULT) until QA and the
--   security review pass. Off takes every fish amount off the open trades, refuses new fish offers and lifts the
--   fish-spend freeze (TradeService).
-- - `awayNotes` (#2768): false stops the server noting who is due an away notification (AwayNotifyService). The
--   notes share MemoryStore's one quota with the pity cats' timers (64 KB plus 1 KB a player online), so this is
--   the way to stop them filling it without a publish. Notes already written expire by themselves.
-- - `nightCatch` (#3035): night catching for a Tier 1 player in their first session (shared/NightPass). It starts OFF
--   (OFF_BY_DEFAULT); true opens the Alleyway to them at night, and off again sends them home at the next night sweep.
-- - `swiftPaws` (#3063): false hides the Golden Fish Market's Swift Paws row, refuses a buy and drops its speed at
--   the next speed set (shared/SwiftPaws); saved levels are kept.
-- - `loadingScreen` (#3179, Derek2 2026-11-10: "remove the loading screen honestly I think that would make people
--   leave faster then before"): the loading screen before the opening scenes (#3105, #3109). It starts OFF
--   (OFF_BY_DEFAULT); true brings it back for players who join after, so the leave rates can be compared. Read by
--   the client alone (UI.intro.waiting), from the ReplicatedStorage attribute below.
-- - `alleyBin` (#3050): false hides the Rummage Bin's prompt at the Alleyway camp and refuses a rummage (BinService).
--   Saves keep their wait and wins.
-- - `goldenDrops` (#3222): the rare drop-only Golden lawn pieces from freed cats (Lawn.dropPick). It starts OFF
--   (OFF_BY_DEFAULT): switch it on only once no server older than the publish that added the pieces is running, since
--   an older server's save check drops a lawn id it does not know.
-- - `secretAreas` (#4221): one Secret per area (Catalog's `secretArea`). It starts OFF (OFF_BY_DEFAULT): off, a
--   Secret comes from any area as before; on, a wild stray's or trap's Mythical turns only into its area's Secret and
--   a bait bowl's into one of its open areas' Secrets, and an area with none keeps its Mythical. The Index's Secret
--   tab reads the same switch. Its own update day (Saturday 2026-11-21 20:00 UTC).
-- - `luckyCharm` (#3298): the Golden Fish Market's Lucky Charm perk (shared/LuckyCharm). It starts OFF
--   (OFF_BY_DEFAULT): off hides the row, refuses a buy and adds no Luck. Switch it on only once no server older than
--   the publish that added the row is running, since an older server's save check drops a perk id it does not know.
-- - `introSplit` (#3666): the intro scene plays itself for half of new players (shared/IntroSplit), so the two
--   halves' first minutes can be compared. It starts OFF (OFF_BY_DEFAULT); off, nobody new joins the test and no
--   intro plays itself.
-- - `parkGateTrail` (#3554): after Tier 2 the goal card reads "Visit the Park" and a trail of paw prints leads to the
--   nearest Cat Cannon, then to the first Park stray (UI/Components/ParkTrailLogic). It starts OFF (OFF_BY_DEFAULT);
--   off, nothing shows.
-- - `rareCustomers` (#3889): each customer walking into an open cafe has a chance to be a rich customer, a Mystery
--   Visitor or the Cat Collector (shared/RareCustomers, RareCustomerService), sitting at any open table, in place of
--   their three timers. It starts OFF (OFF_BY_DEFAULT); off, the timers run as before.
-- - `adminEvents` (#4195): admin events from the events schedule's `admin = true` records (shared/CafeEvents; Bowl
--   Frenzy's faster bait bowls, EventService.bowlSpeed). It starts OFF (OFF_BY_DEFAULT); off, EventService shows and
--   runs none, and one running ends at the next second.
-- - `mailbox` (#4249): the HUD's Mailbox tile in the Feedback tile's place, with letters from Derek to claim
--   (client/UI Screens/Mailbox; Feedback moves into the Menu list). It starts OFF (OFF_BY_DEFAULT); off, the
--   Feedback tile stays. The client reads it once at the HUD's build.
-- LiveFlagService also copies each switch to a ReplicatedStorage attribute (ATTRIBUTE_PREFIX .. key) for the client.
-- Only an explicit false turns a feature off: a missing key, a value of another type or a failed read leaves it on
-- (a failed read keeps what the server had), so a broken store can't switch the game off. A key in OFF_BY_DEFAULT is
-- the other way round: only an explicit true turns it on, so a missing key or a broken store never switches it on.

local LiveFlags = {}

LiveFlags.STORE = "CatCafe_Flags"
-- - `starterRefill` (#3049): false stops the starting areas' camp trap refilling during the day for players who have
--   never rescued (RescueService), back to one cat a day there.
LiveFlags.KEYS = {
	"codes",
	"areaCannonRings", -- #5416: with townRings, each area's cannon ring shows again (shared/WalkUp.ringLook); off by default
	"perfectFlagged", -- #5379: a Perfect catch marks the cat even while the profile's scripted-press flag is set (CatService); off by default
	"vipBoost", -- #4235: VIP pays +50% and shows a tag over the owner's head (Economy.vipBoost, Services/VipTagService)
	"walkUpCarry", -- #5415: with walkUpRetry, a ring stepped into during a carry opens once the carry clears (Controllers/WalkUpController); off by default
	"rally",
	"catchCurve", -- #5392: one smooth catch curve by net, area tier and coat, and a bigger net Perfect (shared/Circles); off by default
	"walkUpSettle", -- Sync 2026-11-18: a walk-up ring stepped into while busy (the intro, a flight) or in the 2 s after waits until the player steps out and back in (WalkUpController); on by default
	"lockedAreaQuiet", -- #5265: no rainbow, pity or Secret spawn beam, mark or toast from an area this player's tier has not opened (CatService RainbowSpawned, Effects Context.areaShut); on by default
	"stationTiers", -- #4539: Mystery Market, Cat Arcade and Mystic Pool open from Tiers 2, 3 and 4 (shared/StationTiers)
	"tradeCrates",
	"tradeFish",
	"awayNotes",
	"nightCatch",
	"starterRefill",
	"swiftPaws",
	"loadingScreen",
	"alleyBin",
	"arcade", -- #3062: false hides the Cat Arcade's prompt and menu tile; a game already running finishes and pays
	"goldenDrops",
	"luckyCharm",
	"introSplit",
	"parkGateTrail",
	"fishStore", -- #4055: Store passes for golden fish (shared/FishStore); on after the save version 49 restart
	"dragonKeep", -- #4062: the Dragon Keep (shared/DragonKeep); on after the version 49 restart
	"ticketBooth", -- #4061: the Ticket Booth's tickets and prizes (shared/TicketBooth); on after the version 49 restart
	"tier8", -- #3997: Tier 8 and the Snowy Mountain (shared/LateTiers); on once the area is built, after a restart
	"bowlCardHold", -- Derek 2026-11-18: a bowl cat's card never shows over the intro or another cutscene, it waits for calm (UI.bait.showReady); on by default
	"tier9", -- #4070: Tier 9 and the Water Park (shared/LateTiers); on once the area is built, after a restart, never before tier8
	"tier10", -- #4184: Tier 10 and the Medieval Castle (shared/LateTiers); on once the area is built, after a restart, never before tier9
	"rareCustomers", -- #3889: rare customers by a chance per arriving customer, at any table
	"upgradesWarm", -- Sync 2026-11-18: the Upgrades window lays out once off screen after its rows are built, so the first open has no long frame (Screens/UpgradeShop._warm); on by default
	"dailyDeal", -- #3996: Today's Deal on the Store's Featured tab (shared/DailyDeal)
	"starterSuggest", -- #4174: the Starter Bundle's one slide-in card a session after 10 to 15 minutes (shared/StarterSuggest)
	"updateFeature", -- #4175: the update's own item first on the Store's Featured tab on big update days (Config.UpdateFeature)
	"adminEvents", -- #4195: admin events (Bowl Frenzy, the Admin Wheel) from the events schedule (shared/CafeEvents)
	"secretAreas", -- #4221: one Secret per area; a rolled Mythical turns only into its own area's Secret (Catching.secret)
	"mailbox", -- #4249: the Mailbox tile and window (letters from Derek with a gift to claim), Feedback into the Menu list
	"autoBowl", -- #4266: the Auto Bowl pass's offer card, switches and Store card (Screens/BaitBowl)
	"uiStats", -- #5245 (Sync on v947): the play counters (baitsTamed, luresUsed) reach the UI state the tutorial reads (UIController); on by default
	"harvestHollow", -- #4251: Harvest Hollow (shared/HarvestSave); a kill switch, the area's dates open and close it
	"harvestPieLow", -- #4251: the Feast Pie's goal drops from 25,000 to 15,000 harvest cats (HarvestSave.pieGoal); off
	"padControls", -- #4224: B back one step, L1/R1 tabs and pop-ups taking focus on a gamepad (UI/Components/GamepadNav)
	"deviceFixes", -- the Tue 2026-11-17 phone and tablet first 5 minutes fixes (no Tackle before the first check-in, ...)
	"afkButton", -- #4346: the HUD's AFK tile and AfkMode (shared/AfkCafe): home, 2x rest at once, the rejoin keeps it
	"freeCatchPads", -- Derek 2026-11-14: phone, tablet and console catches below Tier 2 are the tutorial's (shared/FreeCatch)
	"newcomerQuiet", -- #4472: no pop-up bubbles in a new account's first 5 minutes (UI/Components/ToastRules.newcomer)
	"cannonReturnNow", -- #5417: with cannonReturn, the Cannon picker comes back the moment a Rummage started from it ends (UI.cannon.rummageBack); off by default
	"areasKept", -- #5381: with areaWhole on, every unlocked area loads once and stays on the device (shared/AreaWhole); off by default
	"firstFlightQuick", -- #4920: the walk-through's flights out take 2/3 of every beat (shared/Cannon.flightScale)
	"areasKeptRecent", -- Derek 2026-11-19: with areasKept and areasKeptBig, a phone or tablet keeps its 2 most recent areas, not one (shared/AreaWhole.keptLimit); off by default
	"moneyCard", -- #4437: the HUD Money button's first tap opens the boost card (UI/Screens/MoneyCard); false prompts at once
	"areasKeptBig", -- Sync 2026-11-19: with areasKept, only a PC or console keeps every area; a phone or tablet keeps one (shared/AreaWhole.keptFor); off by default
	"firstFlightDirect", -- #4920: the walk-through's first flight goes straight to the Alleyway (UI/Components/WalkRingLogic)
	"autoRankUp", -- #4924: the Rank Up window opens by itself once a tier when it is ready (UI/Components/AutoRankUp)
	"noIntro", -- #4929: no intro plays by itself on a first join (shared/IntroSplit.NO_INTRO); off unless switched on
	"autoFirstBait", -- #4452: the starter Kibble goes in bowl 1 by itself at the tutorial's bowl step (shared/SecondCatHelp)
	"tier2TopUp", -- #4453: the first tamed bait cat's welcome tops coins up to Tier 2's cost once (shared/SecondCatHelp)
	"stuckAfterSecond", -- #4473: the stuck cat goal, pointer and call wait until the second cat is caught (shared/StuckGoal)
	"settleCutFree", -- Review-QA 2026-11-18: a station's one-time cut no longer starts the walk-up settle, so its card shows on the first walk-up (WalkUpController); on by default
	"fusion", -- #4104: the Fusion Observatory (shared/Fusion); on after the save version 50 restart
	-- #4527 (Derek 2026-11-15: "too much popups on screen maybe remove popups from claiming stuff"): the Mystery gift's
	-- centre card; off (the default) the gift opens with its sound alone
	"giftCard",
	"catchFirst", -- #4518: on, today's walk-through order; false, bowl first (shared/TutorialOrder)
	"earlyKindBonus", -- #4624: kinds 2 to 5 pay 3x a Common's new-kind money in Tier 1 (shared/SecondCat); off until the Nov 16 read
	"returnHookEarly", -- #4626: the minute 6 "come back tomorrow" line for players before Tier 3 (shared/ReturnHook.early)
	"journeys", -- #4544: Roblox Journey events (shared/Journeys); on once the configs are published in Creator Hub
	"backdropsNear", -- #4857: far areas' backdrop rings leave this client's Workspace (shared/BackdropNear); off by default
	"palDay", -- #4913: the Pal Day gift, 30 golden fish and a spin for 5 minutes beside a pal, once a day (shared/Pals)
	"storeGuard", -- #1936: no price or pulse on the money badge under 30 minutes of play (UI/Components/StoreGuard); off for Derek
	"fxOneAdded", -- #5000: Effects' Workspace.DescendantAdded handlers share one connection (Effects/Context); off by default
	"areaOnly", -- #5026: the areas' night fences stream like the rest of their area (shared/AreaOnly); off by default
	"rankUpRightAway", -- #5031: Rank Up opens again until pressed, goal card ready and short lines, a stray waits (shared/RankUpRightAway); off by default
	"parkRingEarly", -- #5034: the nearest Park stray is ringed early after a landing (Motion-FX, PR #5035); off by default
	"parkTrailBack", -- #5045: the Park trail comes back 30 s into a rest even while walking (Motion-FX, PR #5047); off by default
	"tier3Path", -- #5038: at Tier 2 a new kind waits by the Park landing, one next goal, a Tier 3 welcome gift (shared/Tier3Path); off by default
	"landSafe", -- #5269: a cannon landing lets go at touchdown and the client waits for the pad floor (shared/Cannon.LAND_FLAG)
	"cafeGrows", -- #4543: the cafe's room grows every two tiers (shared/CafeRoom, Model-Agent's _WxD shells); off by default
	"fxAfterLoad", -- #5068: client Effects and Audio start-up waits until the loading screen ends (Effects/LoadGate); off by default
	"tomorrowCard", -- #3951: the come back tomorrow card on a new account's first day (UI/Components/TomorrowCard); off by default
	"cannonCue", -- the HUD Cannon button glows while Tier 2 is short of cats in the hometown (Effects/CannonCue, #5097); off by default
	"stationCut", -- #5112: a rank up to Tier 3, 4, 8, 9 or 10 cuts the camera to the station it unlocks, once (shared/StationCut); off by default
	"tablesSpread", -- #3867/#4763: one more table a tier, 3, 4 and 5 at Tiers 2 to 4 (shared/TablesSpread); off by default
	"strayWalkSlow", -- #4601: a server stray walk writes its model at 10 Hz, not 60, and the client eases between (shared/Mover); off by default
	"firstRankLock", -- Derek 2026-11-17: the first Rank Up window stays up while ready, dimmed, arrow on RANK UP (shared/RankUpRightAway.locked); off by default
	"rankSpotPlain", -- Derek 2026-11-18: the first Rank Up walk-through has no words, only the dim and arrow, the dim in the window too (UI.rankSpot.set); off by default
	"townRings", -- Derek 2026-11-18 (#5224): Town Square walk-up rings always show, smaller; none in the areas (shared/WalkUp.ringLook); off by default
	"likeAskEarly", -- #5152: the like ask on the first UTC day at the first Park or Rare catch, as a card (shared/Tips.likeEarly); off by default
	"nightSlice", -- #5164: the client's day and night change spreads its World walk and night look over frames (WorldController); off by default
	"spinCat", -- #5171: the Spin Wheel's ninth slice, a Secret cat at 0.25% (shared/SpinCat); off by default
	"nightSpread", -- #5164: dusk's strays leaving and sunrise's stuck cats spread over frames (shared/NightSpread); off by default
	"bowlTicks", -- #5263: the bowl's tick boxes, auto ones with the Second Bait Bowl pass (Screens/BaitBowl, BaitService); off by default
	"foodByRarity", -- #5264: food lists sort by rarity before the catalog's sortOrder (Components/FoodOrder); off by default
	"kingCatInfo", -- #5260: the Cat King Pack's gold chip and i sheet say how King Croissant earns (Components/StoreLogic); off by default
	"walkUpRetry", -- #5386: a ring stepped into while busy opens once the player is free (Controllers/WalkUpController); off by default
	"rankUpSteps", -- #5218: the Rank Up window's needs as numbered steps with a Go button (Screens/RankUp); off by default
	"secretDouble", -- #5418: twice the share of rolled Mythicals that turn Secret, everywhere, and on every odds card (shared/Catching.secretShare); off by default
	"goalNeedLine", -- #5331: the folded goal chip and a takeover goal show the biggest Rank Up need (Components/GoalNeed); off by default
	"noRankOpens", -- #5258: the Rank Up window has no "It opens" section and is one shorter column (Screens/RankUp); off by default
	"oneLadderRow", -- #5254: the Rewards list shows only the next gift ladder step, below Gifts and Daily treat (Screens/HUD); off by default
	"companionNudge", -- #5364: a red "!" on the Cats menu Companion button while none follows (Screens/CatRoom); off by default
	"plushSecret", -- #5414: the Booth Plush Cat earns like the Tier 9 Secret, on the Secret night tile (shared/CatStats, Screens/TicketBooth); off by default
	"keepLook", -- #5433 #5434 #5435: Dragon Keep family pictures on Binder cards, Sets rows and Slots, slot bonuses (Screens/DragonKeep); off by default
	"bowlLockBig", -- #5455: the Bowl Options' locked tick boxes show a big lock picture (Screens/BaitBowl); off by default
	"bowlOptionsList", -- #5472: a column too short for the Bowl Options card puts it atop the foods list (Screens/BaitBowl); off by default
	"companionBetter", -- #5457: the Companion "!" also for a better cat not yet seen in the picker (Screens/CatRoom); off by default
	"secretTraitTile", -- #5445: Secret trait cards in the Mystic Pool on the Secret night tile (Screens/MysticPool); off by default
	"tier4Easy", -- #5285 E: Tier 4 asks 250,000 and an Epic or better, on top of either Tier 4 row (shared/CheapTiers); off by default
	"tier3Easy", -- #5467: Tier 3 asks 10,000 and 4 kinds, on top of either Tier 3 row (shared/CheapTiers); off by default
	"cheapTiers", -- #5249: Tiers 3 to 8 ask far less (coins; kinds and Mythicals at 6 to 8) (shared/CheapTiers); off by default
	"nightLine", -- #5330: at night up to Tier 4 the strip says when the areas open, with an arrow to Upgrades (Components/NightLine); off by default
	"perfectCatch", -- #5300: every ring Perfect marks the cat Perfect, x1.5 pay with its coat, charm counts 1x (shared/PerfectCatch); off by default
	"easyKeep", -- #5311: the Dragon Keep's Warmth goals 50, 100, 250, 500, 1,000 and Rekindle 500 (shared/EasyKeep); off by default
	"netTiers", -- #5170: stronger nets cut hits, Net 4 at Tier 7 and Net 5 at Tier 9 (shared/NetTiers); off by default
	"tablesEight", -- #5441: Tables 7 and 8 at Tiers 9 and 10, in the back of the 60 x 46 room (shared/TablesEight); off by default
	"companionMenu", -- #5296: Cats window role symbols, the Companion button and picker, both boosts (shared/Follower); off by default
	"companionTraits", -- #5303: Mystic Pool traits that raise the Cat Companion boosts (shared/Traits, CompanionTraits); off by default
	"strayMeets", -- onboarding_v9: the Alleyway's waiting stray stands by the landing for a first catch by hand (shared/StrayMeets); off by default
	"afkStay", -- #5322: AFK mode is saved until turned off and hops through a restart (shared/AfkCafe.STAY_FLAG); off by default
	"afkQuick", -- #5310: AFK mode rests at once (2x within a second) and the cafe banner says Turn on AFK; off by default
	"cardFollow", -- #5296: Follow and the boost square on the cat card (Screens/CatRoom); off by default, Derek wants the old row
	"bigTreats", -- Derek 2026-11-18: the Daily Treat pays big prizes only, no food (shared/BigTreats); off by default
	"tomorrowBoard", -- #5449: the Daily Treat Board on the cafe wall, with Remind me (shared/TomorrowBoard); off by default
	"walkUpCardWait", -- Derek 2026-11-19: a walk-up ring waits for a new cat card to go before its window opens; off by default
	"bigNet", -- #5309: the net takes the whole half circle in front, further, and a miss scares no cat (shared/NetSwing); off by default
	"companionScene", -- #5284: after the Tier 2 rank up the best cat becomes the Cat Companion in a short scene, once (shared/CompanionScene); off by default
	"cannonReturn", -- #5304: Rummage from the Cannon menu goes back to it, Skip on the Lucky pick; off by default
	"catFollower", -- #5172: one of your cats follows you for Money or Luck (shared/Follower); off by default
	"parkRankPoint", -- #5163: after a Park cat checks in at Tier 2 the screen dims round the goal card, once a session (UI.parkRankPoint); off by default
	"parkFirstEasy", -- #5182: Park catches keep the Alleyway's 1.2 wider bands until the first Park catch (shared/ParkFirstEasy); off by default
	"areaWhole", -- Derek 2026-11-18: the area a player is in (or flying to) loads whole on their device (shared/AreaWhole); off by default
	"crateUnstick", -- #5394: a crate's "..." waits 3 s, not 6, and opening the Market clears it (UI/Screens/FishMarket); off by default
	"cannonAnywhere", -- #5382: a cannon launch is never refused for distance (shared/Cannon); off by default
	"nextGoalBeat", -- #5202: a "What next?" card once after the first Park catch (shared/NextGoal); off by default
	"milestoneFunnel", -- #5291: the milestones_v1 progression funnel for new accounts (shared/MilestoneFunnel); off by default
	"topTraitCompanion", -- #5445: Legendary and Mythic traits add to their cat's Cat Companion boosts (shared/Traits); off by default
	"topTraitsMore", -- #5445: three more Mythic and two more Secret traits in the Mystic Pool (shared/Traits); on only after a restart; off by default
	"tameCannonPoint", -- #5245: after the first bowl cat's card the Cannon button is dimmed and pointed at until pressed, and the picker's ringed Launch too (UI applyTutorial, Screens/Cannon); off by default
	"parkLead", -- #5248: after the Tier 2 rank up no Alleyway new kind line, the picker's Park Launch dimmed and pointed at until pressed, no marker in a flight (Screens/Cannon); off by default
	"promptsAfter5", -- #5251: no notify, favourite or event prompt before 6 minutes of account play and session (shared/Tips.promptOk, EventRsvp.window); off by default
	"upgradesInstant", -- #5253: an Upgrades buy shows in the window at once and the server syncs before the plot rebuild (Screens/UpgradeShop, CafeService); off by default
	"nightBright", -- #5240: a slightly lighter night sky and shade (shared/DayLight.BRIGHT_NIGHT); off by default
	"frontDoors", -- #5385: the cafe's own front doors stand open in the front doorway where no door set is in use (CafeService.refreshDoors); off by default
	"ringSolid", -- #5256: a double's second half and a paw catch ring drop the dark rim that read as a gap (UI CatchCircles); off by default
	"quickFirstRings", -- #5232: a player's held first-catch rings shrink in 0.7 s, not 1.6 (shared/Circles.tutorialSchedule); off by default
	"firstCatchWow", -- #5285 E2: the account's first net catch gets slow motion, a push in, a big pop, coins and a FIRST CATCH! banner (Effects/FirstCatchWow); off by default
	"gemsShrink", -- Derek 2026-11-18: a stray's rarity gem gets smaller with distance so it stops covering far cats (Effects/Rarity, Logic.gemPixels); off by default
	"christmasEvent", -- Snowglobe Village, Dec 1 2026 to Jan 3 2027: the globe in the Town Square and the village are built (Services/SnowglobeService); off by default
	"keepNoEvent", -- #5428: the Dragon Keep move in list leaves out event cats and the server refuses them (DragonKeep.eventCat); off by default
	"bangRelayout", -- #5261: a "!" bubble showing with words but laid out blank lays its text out again (UI/Components/MarketBang); on by default
	"phoneSmooth", -- #5285 A1: a new account on a touch screen starts in Smooth mode, no ask (shared/PerfSuggest.autoStart); off by default
	"bangFixedText", -- #5390: the "!" bubbles' words sized by hand, not TextScaled (UI/Components/MarketBang); off by default
	"leaveCleanup", -- server memory: old characters and Players who left are destroyed (shared/LeaveCleanup); on by default
	"townGround", -- #5357: the Town Square paving and paw paths are Persistent, never streamed out (shared/TownGround); off by default
	"tipPileOldest", -- #5422: a table's tip pile goes oldest first, as the server takes them, so none is left behind (Controllers/CustomerController); off by default
	"cannonCloudsEarly", -- #5370: a cannon flight's clouds cover the screen just after the boom, so the far, half streamed areas never show (Effects/Cannon); off by default
	"pawsInFloor", -- #5471: the Town Square's paw prints are drawn on the floor they lie on, so they stream with it (World/PawFloor); off by default
	"guideArrow", -- #5465: every tutorial trail is one arrow by the player in place of the paws (UI/Components/GuideTrail, Effects/GuideArrow); off by default
	"lockedRingsHidden", -- #5463: a station locked for this player keeps its walk-up ring and art hidden (StationLockController, Effects/StationCircles); off by default
	"nightLineNoArrow", -- #5459: the night line keeps its words but no ring or arrow on Upgrades (Components/NightLine); off by default
	"secretCompanionBig", -- #5431: a Secret companion gives +60% Money and +0.90 Luck, and every companion grows 10% per area (shared/Follower); off by default
	"decorChipIcons", -- #5366: the Decor menu chips draw art pictures in place of the tiny emoji (Screens/DecorShop); off by default
	"bowlHintRetry", -- #5438: the tutorial strip is worked out again when a new server's switches arrive, so bowl first shows its food ask (Controllers/UIController); off by default
	"chipPickedWord", -- #5406: with decorChipIcons, the picked Decor chip grows to keep its word on a phone (Screens/DecorShop); off by default
	"bowlWalkQuiet", -- #5436: with No new cat pop-ups ticked, the bowl walk-up ring no longer opens the waiting cat's card (Controllers/UIController); off by default
}
-- Switches that stay off until the store holds an explicit true.
LiveFlags.OFF_BY_DEFAULT = {
	tameCannonPoint = true, -- #5245
	bangFixedText = true, -- #5390
	parkLead = true, -- #5248
	promptsAfter5 = true, -- #5251
	upgradesInstant = true, -- #5253
	giftCard = true, -- #4527
	tradeFish = true,
	nightCatch = true,
	loadingScreen = true,
	goldenDrops = true,
	luckyCharm = true,
	introSplit = true,
	noIntro = true, -- #4929
	backdropsNear = true, -- #4857
	firstFlightQuick = true, -- #4920: on once the effects scale by CannonFlightScale
	parkGateTrail = true,
	fishStore = true,
	ticketBooth = true,
	dragonKeep = true,
	tier8 = true,
	harvestPieLow = true,
	tier9 = true,
	tier10 = true,
	rareCustomers = true,
	dailyDeal = true,
	perfectFlagged = true, -- #5379
	starterSuggest = true,
	cannonReturnNow = true, -- #5417
	areasKeptBig = true, -- Sync 2026-11-19
	updateFeature = true,
	areasKeptRecent = true, -- Derek 2026-11-19
	adminEvents = true,
	secretAreas = true,
	mailbox = true,
	autoBowl = true,
	padControls = true,
	deviceFixes = true,
	afkButton = true,
	fusion = true,
	earlyKindBonus = true,
	returnHookEarly = true,
	journeys = true,
	palDay = true, -- #4913: on after Growth's days-with-friends baseline and a restart (the save field has no bump)
	storeGuard = true, -- #4472: the 30 minute quiet came alive with playSeconds; Derek decides
	fxOneAdded = true, -- #5000: on once Sync's Studio read shows the shared connection is no slower
	areaOnly = true, -- #5026: on once Sync's before and after census shows the win
	rankUpRightAway = true, -- #5031: on after Review-QA and Sync's Studio pass
	parkRingEarly = true, -- #5034: on at least a UTC day apart from rankUpRightAway (Design)
	parkTrailBack = true, -- #5045: on after Sync's look at a Park rest
	areasKept = true, -- #5381
	tier3Path = true, -- #5038: on after Review-QA and Sync's Studio pass, a UTC day apart from the other funnel switches
	-- #4543: on after Model's wall fit, Review-QA and Sync's Studio look at all five rooms. Turning it off again
	-- shrinks every grown room at its next cafe refresh, and the cats, decor, tables and bait are built again in it.
	cafeGrows = true,
	areaCannonRings = true, -- #5416
	walkUpRetry = true, -- #5386
	fxAfterLoad = true, -- #5068: on after Review-QA and a phone read of client_load with it on
	walkUpCarry = true, -- #5415
	tomorrowCard = true, -- #3951: on after the Nov 16 and 17 day 1 read of the minute 6 line, a UTC day apart from the funnel switches
	cannonCue = true, -- #5097: on with Derek's Nov 17 15:00 UTC "all tutorial switches on now"
	stationCut = true, -- #5112: on after Review-QA and Sync's phone and PC rank up runs
	tablesSpread = true, -- #4763: on about 06:00 UTC Thu Nov 19, a UTC day apart from the funnel switches; Growth reads it
	strayWalkSlow = true, -- #4601: on once Effects/Pose eases between the writes and a Studio walk looks the same
	firstRankLock = true, -- Derek 2026-11-17 20:12 UTC: on after Review-QA and Sync's Studio pass
	rankSpotPlain = true, -- Derek 2026-11-18 13:37 UTC: on once Review-QA passes (tutorial switches on ASAP)
	townRings = true, -- Derek 2026-11-18: on once Review-QA passes
	likeAskEarly = true, -- #5152: on after Review-QA's QoL and phone sizing checks
	nightSlice = true, -- #5164: on after Review-QA and Sync's frame-time read across a phase change
	spinCat = true, -- #5171: on once the window's ninth wedge and the Odds list pass Review-QA and Sync's Studio look
	nightSpread = true, -- #5164: on after Review-QA and Sync's phase change timing
	bowlTicks = true, -- #5263: on once Gameplay-Engineer's BaitService side is merged and Review-QA has checked both
	foodByRarity = true, -- #5264: on after Review-QA's look at the bowl list
	kingCatInfo = true, -- #5260: on after Review-QA's phone check of the Store card
	rankUpSteps = true, -- #5218: first-session flow, on after Sync's phone look with the first Rank Up pointer
	goalNeedLine = true, -- #5331: first-session flow (stall fix), on at its own minute after Sync's phone look
	noRankOpens = true, -- #5258: first-session flow, on after Review-QA's phone check with the first Rank Up pointer
	catchCurve = true, -- #5392
	oneLadderRow = true, -- #5254: on after Review-QA's phone check of the Rewards list
	secretDouble = true, -- #5418
	companionNudge = true, -- #5364: on as soon as it publishes (Derek 2026-11-18)
	plushSecret = true, -- #5414: on as soon as it publishes (Derek 2026-11-19)
	keepLook = true, -- #5433: on as soon as it publishes (Derek 2026-11-19)
	bowlLockBig = true, -- #5455: on as soon as it publishes (Derek 2026-11-19)
	bowlOptionsList = true, -- #5472: on as soon as it publishes (Derek 2026-11-19)
	companionBetter = true, -- #5457: on as soon as it publishes (Derek 2026-11-19)
	tier3Easy = true, -- #5467: on as soon as it publishes (Derek 2026-11-19)
	secretTraitTile = true, -- #5445: on together with topTraitsMore
	tier4Easy = true, -- #5285 E: on at a clear minute, 2 h from other switches, for Growth's tier_3 to tier_4 read
	cheapTiers = true, -- #5249: on after Review-QA, at a clear minute for Growth's park_catch to tier_3 read
	nightLine = true, -- #5330: on after Review-QA and Sync's phone look, 2 h from other switches
	perfectCatch = true, -- #5300: on after Review-QA, Sync's phone look at the pills and a restart
	easyKeep = true, -- #5311: on after Review-QA, with a restart
	netTiers = true, -- #5170: on after Review-QA and the Pace test with it on
	tablesEight = true, -- #5441 (Derek 2026-11-19): on as soon as it publishes
	companionMenu = true, -- #5296: on after Review-QA, Sync's pictures and Derek's look
	companionTraits = true, -- #5303: a paid random item change, on after a restart publish and Review-QA's odds check
	afkStay = true, -- #5322: on after Review-QA and a real restart with an AFK player watched
	strayMeets = true, -- onboarding_v9 near_stray: on as soon as Review-QA passes (Derek's rule)
	afkQuick = true, -- #5310: on once Review-QA passes
	cardFollow = true, -- #5296: stays off; the Companion button replaces it
	bigTreats = true, -- Derek 2026-11-18: on once Review-QA passes, 2 h from any other switch
	tomorrowBoard = true, -- #5449 (Growth: its 2-day D1 read starts when it goes on)
	walkUpCardWait = true, -- Derek 2026-11-19 (the cannon after a check-in): on as soon as it publishes
	bigNet = true, -- #5309: on once Review-QA and Sync pass
	companionScene = true, -- #5284: on after Review-QA and Sync's phone pass of the scene
	cannonReturn = true, -- #5304: on once Review-QA and Sync pass
	catFollower = true, -- #5172: on after the walk and the Cats menu slot land, a Pace read and a restart (save field)
	parkRankPoint = true, -- #5163: on after Review-QA and Sync's Studio pass
	parkFirstEasy = true, -- #5182: on after Review-QA; Growth reads park_catch by device
	areaWhole = true, -- Derek 2026-11-18: on after Review-QA and Sync's tablet and phone memory read in a long area
	crateUnstick = true, -- #5394
	cannonAnywhere = true, -- #5382
	nightBright = true, -- #5240: on after Review-QA and a phone look at night
	frontDoors = true, -- #5385: on in the hour its PR publishes
	ringSolid = true, -- #5256: on after Review-QA and a Studio look at a double and a paw ring
	quickFirstRings = true, -- #5232: first-session change; on at a clear minute after Review-QA
	phoneSmooth = true, -- #5285 A1: on after Review-QA and a phone look at the first minute
	firstCatchWow = true, -- #5285 E2: first-session change; on after Review-QA and Sync's look at a first catch
	gemsShrink = true, -- Derek 2026-11-18: on after Review-QA and Sync's phone and PC look at far gems
	christmasEvent = true, -- snowglobe-village-spec: on Nov 29 after Sync's look; the event dates still hold the portal shut until Dec 1
	keepNoEvent = true, -- #5428
	nextGoalBeat = true, -- #5202: on after Review-QA and Sync's pass, at a minute with no other switch within 2 hours
	milestoneFunnel = true, -- #5291: analytics only; on after Review-QA, then Growth reads it from new accounts
	topTraitCompanion = true, -- #5445
	topTraitsMore = true, -- #5445: on only once every server runs the new ids (a restart)
	townGround = true, -- #5357: on after Review-QA, then Sync checks the Town instance count
	tipPileOldest = true, -- #5422
	cannonCloudsEarly = true, -- #5370: on as soon as it merges (Derek 2026-11-18: switches on right away)
	pawsInFloor = true, -- #5471: on as soon as it merges
	guideArrow = true, -- #5465: on as soon as it merges
	lockedRingsHidden = true, -- #5463: on as soon as it merges
	nightLineNoArrow = true, -- #5459: on as soon as it merges
	secretCompanionBig = true, -- #5431
	decorChipIcons = true, -- #5366: on after Review-QA, once the six pictures pass moderation
	bowlHintRetry = true, -- #5438
	chipPickedWord = true, -- #5406: on as soon as it merges, then Sync checks 360 px
	bowlWalkQuiet = true, -- #5436
} :: { [string]: boolean }
LiveFlags.CHECK_SECONDS = 60
LiveFlags.ATTRIBUTE_PREFIX = "LiveFlag_" -- #3063: the ReplicatedStorage attribute each switch is copied to
-- #4607, #4613: a fresh server copies the defaults out at once and the store's switches only after its first read, a
-- few seconds later. It sets this ReplicatedStorage attribute true once that first read has been tried (or at once
-- where nothing is read), and the client waits for it before it builds anything that takes a switch once (the menu
-- family look), so nobody who joins a new server keeps an old look.
LiveFlags.READY_ATTRIBUTE = "LiveFlagsReady"
LiveFlags.CLIENT_WAIT_SECONDS = 8 -- #4613: Main.client's wait, before any UI module latches a switch
LiveFlags.READY_WAIT = 6 -- #4607: UIController's own wait, which ends at once after Main.client's

export type Flags = { [string]: boolean }

-- What a client makes of a switch's ReplicatedStorage attribute: a key in OFF_BY_DEFAULT is on only at an explicit
-- true (so it is off before the attribute has arrived), any other key is on unless it reads false.
function LiveFlags.shown(key: string, attribute: unknown): boolean
	if LiveFlags.OFF_BY_DEFAULT[key] then
		return attribute == true
	end
	return attribute ~= false
end

-- Every feature on, but those in OFF_BY_DEFAULT.
function LiveFlags.defaults(): Flags
	local out: Flags = {}
	for _, key in LiveFlags.KEYS do
		out[key] = LiveFlags.OFF_BY_DEFAULT[key] ~= true
	end
	return out
end

-- The switches from `raw`, the values read by key (nil for a missing key); keys not in KEYS are ignored.
function LiveFlags.parse(raw: unknown): Flags
	local out = LiveFlags.defaults()
	if type(raw) ~= "table" then
		return out
	end
	local values = raw :: { [any]: any }
	for _, key in LiveFlags.KEYS do
		if LiveFlags.OFF_BY_DEFAULT[key] then
			if values[key] == true then
				out[key] = true
			end
		elseif values[key] == false then
			out[key] = false
		end
	end
	return out
end

-- #4613: waits until `holder` (ReplicatedStorage) carries READY_ATTRIBUTE true, at most `cap` seconds, checking every
-- `step` seconds through `sleep` (task.wait) against `clock` (os.clock). Returns whether it was ready and how long it
-- waited. Pure apart from the calls it is handed, so the spec runs it with a fake holder and clock.
function LiveFlags.awaitReady(
	holder: any,
	cap: number,
	clock: () -> number,
	sleep: (number) -> (),
	step: number?
): (boolean, number)
	local started = clock()
	local every = step or 0.1
	while holder:GetAttribute(LiveFlags.READY_ATTRIBUTE) ~= true do
		local waited = clock() - started
		if waited >= cap then
			return false, waited
		end
		sleep(every)
	end
	return true, clock() - started
end

-- The keys whose value differs between `old` and `new`, in KEYS order.
function LiveFlags.changed(old: Flags, new: Flags): { string }
	local out: { string } = {}
	for _, key in LiveFlags.KEYS do
		if old[key] ~= new[key] then
			table.insert(out, key)
		end
	end
	return out
end

return LiveFlags
