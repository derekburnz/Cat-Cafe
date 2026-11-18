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
	"vipBoost", -- #4235: VIP pays +50% and shows a tag over the owner's head (Economy.vipBoost, Services/VipTagService)
	"rally",
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
	"tier9", -- #4070: Tier 9 and the Water Park (shared/LateTiers); on once the area is built, after a restart, never before tier8
	"tier10", -- #4184: Tier 10 and the Medieval Castle (shared/LateTiers); on once the area is built, after a restart, never before tier9
	"rareCustomers", -- #3889: rare customers by a chance per arriving customer, at any table
	"dailyDeal", -- #3996: Today's Deal on the Store's Featured tab (shared/DailyDeal)
	"starterSuggest", -- #4174: the Starter Bundle's one slide-in card a session after 10 to 15 minutes (shared/StarterSuggest)
	"updateFeature", -- #4175: the update's own item first on the Store's Featured tab on big update days (Config.UpdateFeature)
	"adminEvents", -- #4195: admin events (Bowl Frenzy, the Admin Wheel) from the events schedule (shared/CafeEvents)
	"secretAreas", -- #4221: one Secret per area; a rolled Mythical turns only into its own area's Secret (Catching.secret)
	"mailbox", -- #4249: the Mailbox tile and window (letters from Derek with a gift to claim), Feedback into the Menu list
	"autoBowl", -- #4266: the Auto Bowl pass's offer card, switches and Store card (Screens/BaitBowl)
	"harvestHollow", -- #4251: Harvest Hollow (shared/HarvestSave); a kill switch, the area's dates open and close it
	"harvestPieLow", -- #4251: the Feast Pie's goal drops from 25,000 to 15,000 harvest cats (HarvestSave.pieGoal); off
	"padControls", -- #4224: B back one step, L1/R1 tabs and pop-ups taking focus on a gamepad (UI/Components/GamepadNav)
	"deviceFixes", -- the Tue 2026-11-17 phone and tablet first 5 minutes fixes (no Tackle before the first check-in, ...)
	"afkButton", -- #4346: the HUD's AFK tile and AfkMode (shared/AfkCafe): home, 2x rest at once, the rejoin keeps it
	"freeCatchPads", -- Derek 2026-11-14: phone, tablet and console catches below Tier 2 are the tutorial's (shared/FreeCatch)
	"newcomerQuiet", -- #4472: no pop-up bubbles in a new account's first 5 minutes (UI/Components/ToastRules.newcomer)
	"firstFlightQuick", -- #4920: the walk-through's flights out take 2/3 of every beat (shared/Cannon.flightScale)
	"moneyCard", -- #4437: the HUD Money button's first tap opens the boost card (UI/Screens/MoneyCard); false prompts at once
	"firstFlightDirect", -- #4920: the walk-through's first flight goes straight to the Alleyway (UI/Components/WalkRingLogic)
	"autoRankUp", -- #4924: the Rank Up window opens by itself once a tier when it is ready (UI/Components/AutoRankUp)
	"noIntro", -- #4929: no intro plays by itself on a first join (shared/IntroSplit.NO_INTRO); off unless switched on
	"autoFirstBait", -- #4452: the starter Kibble goes in bowl 1 by itself at the tutorial's bowl step (shared/SecondCatHelp)
	"tier2TopUp", -- #4453: the first tamed bait cat's welcome tops coins up to Tier 2's cost once (shared/SecondCatHelp)
	"stuckAfterSecond", -- #4473: the stuck cat goal, pointer and call wait until the second cat is caught (shared/StuckGoal)
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
	"cafeGrows", -- #4543: the cafe's room grows every two tiers (shared/CafeRoom, Model-Agent's _WxD shells); off by default
	"fxAfterLoad", -- #5068: client Effects and Audio start-up waits until the loading screen ends (Effects/LoadGate); off by default
	"tomorrowCard", -- #3951: the come back tomorrow card on a new account's first day (UI/Components/TomorrowCard); off by default
	"cannonCue", -- the HUD Cannon button glows while Tier 2 is short of cats in the hometown (Effects/CannonCue, #5097); off by default
	"stationCut", -- #5112: a rank up to Tier 3, 4, 8, 9 or 10 cuts the camera to the station it unlocks, once (shared/StationCut); off by default
	"tablesSpread", -- #3867/#4763: one more table a tier, 3, 4 and 5 at Tiers 2 to 4 (shared/TablesSpread); off by default
	"strayWalkSlow", -- #4601: a server stray walk writes its model at 10 Hz, not 60, and the client eases between (shared/Mover); off by default
	"firstRankLock", -- Derek 2026-11-17: the first Rank Up window stays up while ready, dimmed, arrow on RANK UP (shared/RankUpRightAway.locked); off by default
	"likeAskEarly", -- #5152: the like ask on the first UTC day at the first Park or Rare catch, as a card (shared/Tips.likeEarly); off by default
	"nightSlice", -- #5164: the client's day and night change spreads its World walk and night look over frames (WorldController); off by default
	"spinCat", -- #5171: the Spin Wheel's ninth slice, a Secret cat at 0.25% (shared/SpinCat); off by default
	"nightSpread", -- #5164: dusk's strays leaving and sunrise's stuck cats spread over frames (shared/NightSpread); off by default
	"netTiers", -- #5170: stronger nets cut hits, Net 4 at Tier 7 and Net 5 at Tier 9 (shared/NetTiers); off by default
	"catFollower", -- #5172: one of your cats follows you for Money or Luck (shared/Follower); off by default
	"parkRankPoint", -- #5163: after a Park cat checks in at Tier 2 the screen dims round the goal card, once a session (UI.parkRankPoint); off by default
	"parkFirstEasy", -- #5182: Park catches keep the Alleyway's 1.2 wider bands until the first Park catch (shared/ParkFirstEasy); off by default
	"areaWhole", -- Derek 2026-11-18: the area a player is in (or flying to) loads whole on their device (shared/AreaWhole); off by default
	"nextGoalBeat", -- #5202: a "What next?" card once after the first Park catch (shared/NextGoal); off by default
	"leaveCleanup", -- server memory: old characters and Players who left are destroyed (shared/LeaveCleanup); on by default
}
-- Switches that stay off until the store holds an explicit true.
LiveFlags.OFF_BY_DEFAULT = {
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
	starterSuggest = true,
	updateFeature = true,
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
	tier3Path = true, -- #5038: on after Review-QA and Sync's Studio pass, a UTC day apart from the other funnel switches
	-- #4543: on after Model's wall fit, Review-QA and Sync's Studio look at all five rooms. Turning it off again
	-- shrinks every grown room at its next cafe refresh, and the cats, decor, tables and bait are built again in it.
	cafeGrows = true,
	fxAfterLoad = true, -- #5068: on after Review-QA and a phone read of client_load with it on
	tomorrowCard = true, -- #3951: on after the Nov 16 and 17 day 1 read of the minute 6 line, a UTC day apart from the funnel switches
	cannonCue = true, -- #5097: on with Derek's Nov 17 15:00 UTC "all tutorial switches on now"
	stationCut = true, -- #5112: on after Review-QA and Sync's phone and PC rank up runs
	tablesSpread = true, -- #4763: on about 06:00 UTC Thu Nov 19, a UTC day apart from the funnel switches; Growth reads it
	strayWalkSlow = true, -- #4601: on once Effects/Pose eases between the writes and a Studio walk looks the same
	firstRankLock = true, -- Derek 2026-11-17 20:12 UTC: on after Review-QA and Sync's Studio pass
	likeAskEarly = true, -- #5152: on after Review-QA's QoL and phone sizing checks
	nightSlice = true, -- #5164: on after Review-QA and Sync's frame-time read across a phase change
	spinCat = true, -- #5171: on once the window's ninth wedge and the Odds list pass Review-QA and Sync's Studio look
	nightSpread = true, -- #5164: on after Review-QA and Sync's phase change timing
	netTiers = true, -- #5170: on after Review-QA and the Pace test with it on
	catFollower = true, -- #5172: on after the walk and the Cats menu slot land, a Pace read and a restart (save field)
	parkRankPoint = true, -- #5163: on after Review-QA and Sync's Studio pass
	parkFirstEasy = true, -- #5182: on after Review-QA; Growth reads park_catch by device
	areaWhole = true, -- Derek 2026-11-18: on after Review-QA and Sync's tablet and phone memory read in a long area
	nextGoalBeat = true, -- #5202: on after Review-QA and Sync's pass, at a minute with no other switch within 2 hours
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
