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
-- - `swiftPaws5` (#3317): Swift Paws levels 3 to 5 in the Golden Fish Market (shared/SwiftPaws). It starts OFF
--   (OFF_BY_DEFAULT): switch it on only once no server older than the publish that added them is running, since an
--   older server keeps a saved level only up to 2.
-- - `swiftPaws10` (#4705): Swift Paws levels 6 to 10. It starts OFF (OFF_BY_DEFAULT): switch it on only once no server
--   older than the publish that added them is running, since an older server keeps a saved level only up to 5.
-- - `mouseDash` (#3296): the Cat Arcade's second game, Mouse Dash (shared/MouseDash). It starts OFF (OFF_BY_DEFAULT)
--   until QA passes: off refuses a start; a game already running finishes and pays. On, it is the game the
--   cabinet and the Menu row open (Derek 2026-11-11: "Swap this in for the current arcade game and vault the other
--   one").
-- - `cartTier6` (#3462): the Day Cart's Tier 6 shelf, its own two baits and three potions (shared/CornerShop's top
--   shelf). It starts OFF (OFF_BY_DEFAULT): switch it on only once no server older than the publish that added the
--   items is running, since an older server's save check drops a food or potion id it does not know.
-- - `secretCats` (#3470): Secret cats, the rarity above Mythical. It starts OFF (OFF_BY_DEFAULT): off, nothing rolls
--   Secret anywhere. Switch it on only once no server older than the publish that added them is running, since an
--   older server's save check drops a cat id it does not know.
-- - `secretAreas` (#4221): one Secret per area (Catalog's `secretArea`). It starts OFF (OFF_BY_DEFAULT): off, a
--   Secret comes from any area as before; on, a wild stray's or trap's Mythical turns only into its area's Secret and
--   a bait bowl's into one of its open areas' Secrets, and an area with none keeps its Mythical. The Index's Secret
--   tab reads the same switch. Its own update day (Saturday 2026-11-21 20:00 UTC).
-- - `luckyCharm` (#3298): the Golden Fish Market's Lucky Charm perk (shared/LuckyCharm). It starts OFF
--   (OFF_BY_DEFAULT): off hides the row, refuses a buy and adds no Luck. Switch it on only once no server older than
--   the publish that added the row is running, since an older server's save check drops a perk id it does not know.
-- - `rareCatsTab` (#3053): the chat's own "Rare Cats" tab with every Mythical or better line from every server
--   (shared/RareCatsTab). It starts OFF (OFF_BY_DEFAULT): off, no channel is made and the chat has no tab bar. Derek
--   said on 2026-11-10 he did not want a tab of our own, so it goes on only after he has seen the pictures.
-- - `afkCafe` (#3573): resting in your own cafe pays the cats' cafe pay double (shared/AfkCafe). It starts OFF
--   (OFF_BY_DEFAULT); off, nobody rests, a rest under way ends at the next check and the lines do not show.
-- - `autoRejoin` (#3602): a player resting in their cafe with no input for Config.AutoRejoinSeconds is teleported back into
--   the game before Roblox's 20 minute idle disconnect (shared/AfkCafe). It starts OFF (OFF_BY_DEFAULT) and does
--   nothing while `afkCafe` is off.
-- - `binRoll` (#3608): the Rummage Bin rolls its prize before the bar, from Config.BinRollTable, and keeps it for the
--   player until they win it (shared/RummageBin); the board, the roll and the pad come with it. It starts OFF
--   (OFF_BY_DEFAULT); off, the bin is as it was.
-- - `introSplit` (#3666): the intro scene plays itself for half of new players (shared/IntroSplit), so the two
--   halves' first minutes can be compared. It starts OFF (OFF_BY_DEFAULT); off, nobody new joins the test and no
--   intro plays itself.
-- - `parkGateTrail` (#3554): after Tier 2 the goal card reads "Visit the Park" and a trail of paw prints leads to the
--   nearest Cat Cannon, then to the first Park stray (UI/Components/ParkTrailLogic). It starts OFF (OFF_BY_DEFAULT);
--   off, nothing shows.
-- - `rankUpSpotlight` (#3555): the first rank up's walk-through, the tutorial's dim and pointer on the goal card and
--   then on the rank up button, once the server says the rank up is possible and the player is in the safe area
--   (shared/RankSpot). It starts OFF (OFF_BY_DEFAULT).
-- - `bagColours` (#3699): the Backpack's owner picks its two colours at the Featured Shop (shared/BagColours); off,
--   SetBagColours is refused, the card has no Colours button and every bag wears the built colours. It starts OFF
--   (OFF_BY_DEFAULT) and goes on only after a restart, so every server keeps the saved picks.
-- - `speedShoes` (#3535): the Mystery Market's Speed Shoes (shared/SpeedShoes). It starts OFF (OFF_BY_DEFAULT): off
--   hides the shelf row, refuses a buy and adds no carry speed. Switch it on only once no server older than the
--   publish that added the row is running, since an older server's save check drops an item id it does not know.
-- - `storeRework` (#3572): the Store as in Model-Agent's OK'd mock: Cats above Passes on the rail, each tab cheapest
--   first, two columns of cards with the picture at the left and the price button under the words
--   (client/UI/Screens/Store). It starts OFF (OFF_BY_DEFAULT); read by the client alone, once when the Store is built.
-- - `quietAway` (#4035): while a player's net is out in a catching area, the food bowl cards wait until they are
--   back (town, a cafe or a camp; client/UI UI.bait.busy). Client only. It starts OFF (OFF_BY_DEFAULT).
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
	"swiftPaws5",
	"swiftPaws10", -- #4705
	"mouseDash",
	"cartTier6",
	"secretCats",
	"luckyCharm",
	"rareCatsTab",
	"afkCafe",
	"autoRejoin",
	"binRoll",
	"introSplit",
	"parkGateTrail",
	"nearLights", -- #4311: at night only the nearest Light objects are on (shared/NightLights); on by default
	"rankUpSpotlight",
	"rankFirst", -- #4383: a Tier 1 cafe that can rank up is sent to the rank up before the stuck cat, and a stray press no longer closes the walk-through for good (shared/RankFirst)
	"bagColours",
	"speedShoes",
	"stuckCall", -- #2912: the stuck cat's call for help (pillar, Help! bubble, wiggle, meows) while a save waits for its first rescue; false hides it
	"fxLite", -- #3794: phones and graphics quality 1 to 3 run the lighter effects budget; false goes back to today's
	"storeRework", -- #3572: the reworked Store layout
	"quietAway", -- #4035: food bowl cards wait while the player is out catching
	"fishStore", -- #4055: Store passes for golden fish (shared/FishStore); on after the save version 49 restart
	"dragonKeep", -- #4062: the Dragon Keep (shared/DragonKeep); on after the version 49 restart
	"ticketBooth", -- #4061: the Ticket Booth's tickets and prizes (shared/TicketBooth); on after the version 49 restart
	"riftRun", -- Derek 2026-11-13: a Mythic or Secret trait roll's Rift Run cutscene (client/Effects/RiftRun); client only
	"tier8", -- #3997: Tier 8 and the Snowy Mountain (shared/LateTiers); on once the area is built, after a restart
	"tier9", -- #4070: Tier 9 and the Water Park (shared/LateTiers); on once the area is built, after a restart, never before tier8
	"tier10", -- #4184: Tier 10 and the Medieval Castle (shared/LateTiers); on once the area is built, after a restart, never before tier9
	"rareCustomers", -- #3889: rare customers by a chance per arriving customer, at any table
	"goldTone", -- #4133: gold cats are their base model toned gold (shared/GoldTone), not the _Gold models
	"palJoin", -- #3995: a player who joins through a friend gets the cafe next door and no intro by itself (shared/PalJoin)
	"dailyDeal", -- #3996: Today's Deal on the Store's Featured tab (shared/DailyDeal)
	"starterSuggest", -- #4174: the Starter Bundle's one slide-in card a session after 10 to 15 minutes (shared/StarterSuggest)
	"updateFeature", -- #4175: the update's own item first on the Store's Featured tab on big update days (Config.UpdateFeature)
	"adminEvents", -- #4195: admin events (Bowl Frenzy, the Admin Wheel) from the events schedule (shared/CafeEvents)
	"secretAreas", -- #4221: one Secret per area; a rolled Mythical turns only into its own area's Secret (Catching.secret)
	"mailbox", -- #4249: the Mailbox tile and window (letters from Derek with a gift to claim), Feedback into the Menu list
	"autoBowl", -- #4266: the Auto Bowl pass's offer card, switches and Store card (Screens/BaitBowl)
	"spawnQueue", -- #4227: spawn pop-ups one at a time (UI/Components/SpawnQueue); false shows them as they come
	"checkInCalm", -- #4384: one ask at a time at the first check-in (one toast, the waiting stray's call holds); false goes back
	"padControls", -- #4224: B back one step, L1/R1 tabs and pop-ups taking focus on a gamepad (UI/Components/GamepadNav)
	"deviceFixes", -- the Wed 2026-11-18 phone and tablet first 5 minutes fixes (no Tackle before the first check-in, ...)
	"afkButton", -- #4346: the HUD's AFK tile and AfkMode (shared/AfkCafe): home, 2x rest at once, the rejoin keeps it
	"freeCatchPads", -- Derek 2026-11-14: phone, tablet and console catches below Tier 2 are the tutorial's (shared/FreeCatch)
	"newcomerQuiet", -- #4472: no pop-up bubbles in a new account's first 5 minutes (UI/Components/ToastRules.newcomer)
	"moneyCard", -- #4437: the HUD Money button's first tap opens the boost card (UI/Screens/MoneyCard); false prompts at once
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
	"toys", -- #4061: the Ticket Booth's two held toys (shared/Toys); on only after a restart and once the hold and use
	-- buttons have shipped (their prize ids are new saved ids)
	"journeys", -- #4544: Roblox Journey events (shared/Journeys); on once the configs are published in Creator Hub
	"storeGuard", -- #1936: no price or pulse on the money badge under 30 minutes of play (UI/Components/StoreGuard); off for Derek
}
-- Switches that stay off until the store holds an explicit true.
LiveFlags.OFF_BY_DEFAULT = {
	giftCard = true, -- #4527
	tradeFish = true,
	nightCatch = true,
	loadingScreen = true,
	goldenDrops = true,
	swiftPaws5 = true,
	swiftPaws10 = true, -- #4705
	mouseDash = true,
	cartTier6 = true,
	secretCats = true,
	luckyCharm = true,
	rareCatsTab = true,
	afkCafe = true,
	autoRejoin = true,
	binRoll = true,
	introSplit = true,
	parkGateTrail = true,
	rankUpSpotlight = true,
	bagColours = true,
	speedShoes = true,
	storeRework = true,
	quietAway = true,
	fishStore = true,
	ticketBooth = true,
	dragonKeep = true,
	riftRun = true,
	tier8 = true,
	tier9 = true,
	tier10 = true,
	rareCustomers = true,
	goldTone = true,
	palJoin = true,
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
	toys = true,
	storeGuard = true, -- #4472: the 30 minute quiet came alive with playSeconds; Derek decides
} :: { [string]: boolean }
LiveFlags.CHECK_SECONDS = 60
LiveFlags.ATTRIBUTE_PREFIX = "LiveFlag_" -- #3063: the ReplicatedStorage attribute each switch is copied to
-- #4607, #4613: a fresh server copies the defaults out at once and the store's switches only after its first read, a
-- few seconds later. It sets this ReplicatedStorage attribute true once that first read has been tried (or at once
-- where nothing is read), and the client waits for it before it builds anything that takes a switch once (the menu
-- family look, the Store's rework), so nobody who joins a new server keeps an old look.
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
