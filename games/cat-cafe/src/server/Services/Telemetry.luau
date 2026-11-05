--!strict
-- Analytics (feature F16, growth analytics-plan.md): the onboarding funnel, the catch_attempt and bait_cycle funnels,
-- coin sources and sinks, tier and area Index progression and the custom events, sent through AnalyticsService.
-- Server only; Roblox records nothing from Studio or a client. What only the client knows (its device, a screen it
-- opened, a tutorial card or an intro shot it showed) arrives through TelemetryReport, allowlisted and limited to 40 a
-- minute; nothing it sends pays anything.
-- Every Log call is wrapped in pcall: telemetry must never throw into gameplay. In Studio the last LOG_SIZE events
-- are also kept in memory for QA (`recent`, Debug.telemetry).
-- Custom fields are positional (CustomField01 to 03); the plan names each position. Values are short enum-like
-- strings, never a player's name, a cat's given name or chat, because Roblox folds a field past 8,000 distinct
-- values into "Other".
-- Tips are never an event per second: the cafe's income is counted from lifetimeCoins (CafeService settles it on
-- every sync) and logged as one Source at least once a minute, before every Sink and when the player leaves.

local AnalyticsService = game:GetService("AnalyticsService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
local Intro = require(ReplicatedStorage.Shared.Intro)
local Layout = require(script.Parent.Parent.World.Layout)
local Net = require(script.Parent.Net)
local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Types = require(ReplicatedStorage.Shared.Types)

type Profile = Types.PlayerProfile

-- analytics-plan section 5: Roblox's transaction type names where they fit, plus Promo for codes
export type TransactionType = "Gameplay" | "Onboarding" | "Shop" | "TimedReward" | "Promo"

-- analytics-plan section 6 with data-model section 16's v0.4 and v0.5 renames (shove for bump). Names never change
-- once shipped; the launch-phase events (codes, Daily Treat, requests) come with their features.
export type CustomEvent =
	"rank_up"
	| "session_end"
	| "offline_claim"
	| "dealer_buy"
	-- F94 (rewards-and-shops.md section 6): a Fresh Catch buy, value the golden fish spent; the row id, tier
	| "fresh_catch_buy"
	-- #1052 (corner-shop.md section 4): a Corner Shop buy, value the coins spent; the row id, tier
	| "corner_shop_buy"
	-- #1181 (corner-shop-v2.md section 4): a food fed from the Bag, value its XP; the food id
	| "cat_fed"
	| "rich_tip"
	| "cat_sold"
	| "cat_renamed"
	| "autopress_flag"
	| "cat_caught"
	| "catch_circles"
	| "rescue_attempt"
	| "bait_rolled"
	| "bait_resolved"
	| "gold_found"
	| "rainbow_found" -- F99 (rainbow-coat.md section 5): rarity, net, bait or rescue, first of the cat yes or no
	| "rally_step" -- F101 (rescue-rally.md section 5): value the players in the server; the step (25, 50, 100), lap, paid
	| "rally_points" -- F101: value a player's points this Rally on this server, at its end or their leave; laps paid
	| "camp_extra" -- F100 (camp-extras.md section 4): value the fills taken or 1; the extra, what was taken, tier
	| "shove"
	| "drop_outcome"
	| "left_after_shove"
	| "slots_full"
	| "role_favorite"
	| "travel"
	| "tutorial_step"
	| "ui_opened"
	| "tip_jar"
	| "index_reward"
	| "spin"
	| "crate_opened"
	| "code_redeemed"
	| "intro_cutscene" -- F72: "finished" or "skipped", version:shot ("2:4"), "first" or "replay"
	| "potion_used" -- F64: potion id, tier
	| "mystery_gift" -- F64: "opened" or "missed", kind:id ("potion:tip_potion", "spin"), tier; the value is the count
	| "collector_visit" -- F63: "arrived", "traded", "declined", "timeout" or "withdrawn", catId:variant, offer value
	| "quest_claimed" -- F73: kind ("daily" or "weekly"), quest id, slot ("<slot> auto" when a reset paid it)
	| "quest_set" -- F73: kind, when the last quest of a full set is claimed and the set prize paid
	| "achievement_claimed" -- F73: achievement id, size
	| "daily_treat" -- F70: the day stamped (1 to 7)
	-- Derek's 10-31 research notes: where early players stop. On leaving before Tier 2: the furthest onboarding step,
	-- the tutorial step ("intro" while the intro has never finished) and where they were; the value is the session's
	-- seconds
	| "quit_point"
	-- F84 (hometown-cannon.md section 7): a Cat Cannon flight, from cannon id to destination; a carried cat checked
	-- in at a camp, the value its seconds carried, with area, rarity and times knocked loose
	| "cannon_launch"
	| "camp_checkin"
	-- F95 (economy-ladder.md section 7): on a returning join, the value the minutes away; tier, the minutes offline
	-- pays for (inside the cap) and "long_nap" or "free"
	| "offline_return"
	-- F93 (catch-rework.md section 5): net swings rolled up per player (review S99), value the swings since the last
	-- roll up; "hit", "miss_near" or "miss_empty", net level, device
	| "net_swing"
	-- F97 (notes-10-28-to-10-30.md section 7): a sunrise wave with no Epic or rarer stray rerolled its last one; area,
	-- the rarity it got. A server event, logged under the first loaded player
	| "wave_rare"
	-- F87 (easy-start.md section 5): a new player leaving (their first UTC day of play, or tutorialStep below 5), value
	-- the session's seconds; the furthest onboarding step, the session's bounce window, device. From the client: a
	-- stuck nudge (tutorialStep, kind: pulse, help_shown or show_me) and where the intro was played from (tile, help)
	| "new_player_left"
	| "stuck_nudge"
	| "intro_choice"
	-- F87 (TipService): a context tip shown (tip id, skipped yes or no), once per id until ClearTips;
	-- a feedback face (love, ok or no; the chip or none; tier), FeedbackSessionLimit a session
	| "tip_shown"
	| "ask_shown" -- F96: value 1; kind (notify, favorite, like or F92's invite), the session number
	| "feedback"
	-- F96 (starter-cat.md section 4): the free Bellhop Cat taken home; the gate it passed, "task" or "group"
	| "starter_cat"
	| "shop_cat" -- #1447: a shop-only cat given on its pass (catId)
	-- F91 (front-lawn.md section 5): a lawn piece or path or fence style bought, value 1, once per id ever (moves log
	-- nothing, review S119); its id, tier. The coins it cost are the economy sink "lawn"
	| "lawn_placed"
	-- F92 (playing-together.md 6): on leave, the minutes with at least one pal on the server (how the first pal was
	-- linked: friend, invite, follow or private; tier)
	| "pal_time"
	-- F92 (playing-together.md 6): a rescue attempt a helper joined, as it ends (rarity, freed yes or no, pals yes or
	-- no); the helper's tip is the economy source helper_tip
	| "team_rescue"
	-- F88 (luck-and-rare-moments.md 1f): a bait or crate roll with Luck above x1 (value the Luck; roll kind, rarity
	-- won, tier) and a Lucky Day's sunrise (value the players in the server; the area of a Mythical, or none)
	| "luck_used"
	| "lucky_day"
	-- F89 (luck-and-rare-moments.md 2d): a big pull; rarity, gold yes or no, catch, bait or rescue
	| "rare_secured"
	-- F102 (trading.md section 6): a trade swapped, for each player in it; value the cats that moved, fields the cats
	-- given, the cats got and the best rarity got. Never who
	| "trade_done"
	-- #1273 (easy-start.md section 5): for a new player, a mark at 30 s, 60 s, 2, 5 and 10 minutes into the session,
	-- value the seconds; the furthest onboarding step, the screen open, device
	| "session_30s"
	| "session_60s"
	| "session_2m"
	| "session_5m"
	| "session_10m"
	-- #1273: the first catch, value the catch attempts it took (one is a first try); how it came (net or rescue)
	| "first_catch_tries"
	-- #1273: the first window a player opens (first_window_opened), value 1; the screen
	| "first_window"
	-- #1273: the Tutorial tile's red X, value 1, once a session; tutorialStep
	| "tutorial_closed"

-- One catch_attempt funnel (analytics-plan 4.1): a GUID per attempt and its fields rarity, method, area. The caller
-- keeps it with the stray, the rescue attempt and then the carry.
export type CatchFunnel = { id: string, values: { string } }

export type LogEntry = {
	at: number,
	userId: number,
	kind: string,
	name: string,
	value: number,
	fields: { string },
}

local Telemetry = {}

local CURRENCY = "coins"
local FISH_CURRENCY = "golden_fish" -- F52
local FLUSH_SECONDS = 60
-- Net swings are counted and logged as one net_swing event per result, net level and device this often and on leave:
-- one event per swing would spend the server's analytics budget (120 + 20 per player a minute) at 75 a minute per
-- hunter (review S99).
local SWING_FLUSH_SECONDS = 300
local LOG_SIZE = 200
local DAY_SECONDS = 86400
local LEFT_AFTER_SHOVE_SECONDS = 120
local REPORTS = {
	"device",
	"ui_opened",
	"intro_choice",
	"stuck_nudge",
	"step",
	"intro",
	"screen",
	"tutorial_closed",
}
local DEVICES = { "phone", "tablet", "pc", "console" }
-- F87 (easy-start.md section 5): the client's reports with fixed values. A stuck nudge logs once per tutorialStep and
-- kind a session (the hint pulses every 40 s while it waits); an intro choice at most INTRO_CHOICES times a session.
local INTRO_FROM = { "tile", "help" }
local NUDGE_KINDS = { "pulse", "help_shown", "show_me" }
local INTRO_CHOICES = 5
local FIRST_MOVE_STUDS = 8 -- first_move: this far across the ground from where the character was first seen
local WATCH_SECONDS = 1 -- how often first_move and rank_up_ready are looked for
local SCREEN_NAME_MAX = 32 -- a screen report longer than this is dropped; one not in SCREENS reads "other"
-- the UI's ScreenName (screenOpened) to the ui_opened field value
local SCREENS: { [string]: string } = {
	Upgrades = "upgrades",
	Decor = "decor",
	Collection = "collection",
	RankUp = "rank_up",
	Areas = "areas",
	Bait = "bait",
	Dealer = "dealer",
}
-- progressionPathName "tier", levelName by tier (analytics-plan section 7)
local TIER_NAMES = { "corner", "cozy", "busy", "famous", "grand" }
local FIELD_KEYS = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField03.Name,
}

type Session = {
	accounted: number, -- lifetimeCoins already logged, as tips or as a Source of its own
	joinedAt: number,
	caughtAtJoin: number,
	device: string?, -- from the client's one device report
	joinLogged: boolean,
	returnedNextDay: boolean,
	waitingForRole: { [string]: CatchFunnel }, -- checked-in cats whose funnel waits for step 4 (uid -> funnel)
	knockedAt: number?, -- os.clock() of the last shove that knocked this player's cat loose
	knockedRarity: string?,
	swings: { [string]: { count: number, values: { string } } }, -- net swings not logged yet, by their fields
	origin: Vector3?, -- F87: where the character's root was first seen this session, for first_move
	nudges: { [string]: boolean }, -- F87: stuck_nudge already logged this session, by "<tutorialStep>:<kind>"
	introChoices: number, -- F87: intro_choice events logged this session
	screen: string, -- #1273: the screen open as last reported (a SCREENS value, "other" or "none")
	uiOpened: { [string]: boolean }, -- ui_opened logged this session, by screen, so a flood logs each once (review)
	tutorialClosed: boolean, -- #1273: tutorial_closed logged this session
}

local sessions: { [Player]: Session } = {}
local studio = RunService:IsStudio()
local log: { LogEntry } = {}

-- Bucket helpers: the plan's ranges as short strings ------------------------------------------------------

local function bucket(n: number, edges: { number }, labels: { string }): string
	for i, edge in edges do
		if n <= edge then
			return labels[i]
		end
	end
	return labels[#labels]
end

local function catsWorking(profile: Profile): string
	local n = 0
	for _, instance in profile.cats do
		if instance.spotId ~= nil then
			n += 1
		end
	end
	return bucket(n, { 0, 1, 3, 6 }, { "0", "1", "2-3", "4-6", "7+" })
end

local function catsDistinct(profile: Profile): string
	return bucket(
		ProfileSchema.collectionCount(profile),
		{ 4, 11, 19, 29 },
		{ "1-4", "5-11", "12-19", "20-29", "30+" }
	)
end

local function tierText(profile: Profile): string
	return tostring(Economy.tier(profile))
end

-- Sending ----------------------------------------------------------------------------------------------------

local function customFields(values: { string }): { [string]: any }?
	if #values == 0 then
		return nil
	end
	local fields: { [string]: any } = {}
	for i, value in values do
		if i > #FIELD_KEYS then
			break
		end
		fields[FIELD_KEYS[i]] = value
	end
	return fields
end

local function remember(
	player: Player,
	kind: string,
	name: string,
	value: number,
	values: { string }
)
	if not studio then
		return
	end
	table.insert(log, {
		at = os.time(),
		userId = player.UserId,
		kind = kind,
		name = name,
		value = value,
		fields = values,
	})
	if #log > LOG_SIZE then
		table.remove(log, 1)
	end
end

local function send(kind: string, fn: () -> ())
	local ok, err = pcall(function()
		fn()
		return nil :: any
	end)
	if not ok then
		warn(string.format("[Telemetry] %s not logged: %s", kind, tostring(err)))
	end
end

local function logEconomy(
	player: Player,
	profile: Profile,
	isSource: boolean,
	amount: number,
	balance: number,
	transactionType: TransactionType,
	sku: string,
	currency: string?
)
	if amount <= 0 then
		return
	end
	local flow = if isSource
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	local values = { tierText(profile), ClockService.phase(), catsWorking(profile) }
	local ending = math.max(0, math.floor(balance))
	local kind = if isSource then "source" else "sink"
	remember(player, if currency ~= nil then kind .. " " .. currency else kind, sku, amount, values)
	send("economy " .. sku, function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			currency or CURRENCY,
			amount,
			ending,
			transactionType,
			sku,
			customFields(values)
		)
	end)
end

-- Logs the tips settled since the last log as one Source. `pending` is a credit (negative) or spend (positive)
-- already applied to the wallet whose own event comes next, so the tips event's endingBalance is the wallet
-- before it.
local function flushTips(player: Player, profile: Profile, pending: number)
	local session = sessions[player]
	if session == nil then
		return
	end
	local tips = math.floor(profile.lifetimeCoins - session.accounted)
	if tips < 1 then
		return
	end
	session.accounted += tips
	-- #1273: the cafe's first tips (a cat in a role serving customers), when the watch missed them between syncs
	if Onboarding.reached(profile.telemetry, "first_role_assigned") then
		Telemetry.onboarding(player, profile, "first_customer_served")
	end
	-- F92: the pal bonus's share of it goes out as its own source, pal_bonus
	local pal = math.clamp(math.floor(Economy.takePalEarned(profile)), 0, tips)
	if tips - pal >= 1 then
		logEconomy(
			player,
			profile,
			true,
			tips - pal,
			profile.coins + pending - pal,
			"Gameplay",
			"tips"
		)
	end
	if pal >= 1 then
		logEconomy(player, profile, true, pal, profile.coins + pending, "Gameplay", "pal_bonus")
	end
end

-- Public API ---------------------------------------------------------------------------------------------------

-- One onboarding step (analytics-plan section 3). Logged at once when it is the next step, along with any later
-- steps already reached; held in profile.telemetry otherwise (Onboarding.reach). `values` go with this step only.
-- #1273 (easy-start.md section 5): the 37 step funnel v3 goes out as the funnel Onboarding.FUNNEL ("onboarding_v3")
-- with the player's user id as its one funnel session, since LogOnboardingFunnelStepEvent has no name to keep it
-- apart from the earlier funnels. It replaced onboarding_v2 outright (Derek 2026-11-04).
function Telemetry.onboarding(
	player: Player,
	profile: Profile,
	stepName: Onboarding.StepName,
	values: { string }?
)
	for _, name in Onboarding.reach(profile.telemetry, stepName) do
		local step = Onboarding.index(name)
		local fields = if name == stepName and values ~= nil then values else {}
		remember(player, "onboarding", name, step, fields)
		send("onboarding " .. name, function()
			AnalyticsService:LogFunnelStepEvent(
				player,
				Onboarding.FUNNEL,
				tostring(player.UserId),
				step,
				name,
				customFields(fields)
			)
		end)
	end
end

-- One step of the intro funnel (#1273, Onboarding.INTRO_FUNNEL): logged when it is past the furthest intro step
-- logged, once per player.
function Telemetry.intro(player: Player, profile: Profile, stepName: Onboarding.IntroStepName)
	if not Onboarding.reachIntro(profile.telemetry, stepName) then
		return
	end
	local step = Onboarding.introIndex(stepName)
	remember(player, "onboarding intro", stepName, step, {})
	send("onboarding " .. stepName, function()
		AnalyticsService:LogFunnelStepEvent(
			player,
			Onboarding.INTRO_FUNNEL,
			tostring(player.UserId),
			step,
			stepName,
			nil
		)
	end)
end

-- Call right after Economy.credit(profile, amount) for anything that is not cafe income (section 5).
function Telemetry.source(
	player: Player,
	profile: Profile,
	amount: number,
	transactionType: TransactionType,
	sku: string
)
	local session = sessions[player]
	if session ~= nil then
		session.accounted += amount -- the credit raised lifetimeCoins; it is not tips
	end
	flushTips(player, profile, -amount)
	logEconomy(player, profile, true, amount, profile.coins, transactionType, sku)
end

-- Call right after a successful Economy.trySpend(profile, amount).
function Telemetry.sink(
	player: Player,
	profile: Profile,
	amount: number,
	transactionType: TransactionType,
	sku: string
)
	flushTips(player, profile, amount)
	logEconomy(player, profile, false, amount, profile.coins, transactionType, sku)
end

-- Golden fish (F52): their own currency, golden_fish, never mixed into the coin flush. Call right after
-- GoldenFish.credit. Sources: first_catch, repeat_catch, rank_up, index_reward, spin_wheel, tip_jar, code.
function Telemetry.fishSource(
	player: Player,
	profile: Profile,
	amount: number,
	transactionType: TransactionType,
	sku: string
)
	logEconomy(
		player,
		profile,
		true,
		amount,
		profile.goldenFish,
		transactionType,
		sku,
		FISH_CURRENCY
	)
end

-- Call right after a successful GoldenFish.trySpend. Sinks: crate, lure, perk.
function Telemetry.fishSink(
	player: Player,
	profile: Profile,
	amount: number,
	transactionType: TransactionType,
	sku: string
)
	logEconomy(
		player,
		profile,
		false,
		amount,
		profile.goldenFish,
		transactionType,
		sku,
		FISH_CURRENCY
	)
end

function Telemetry.custom(player: Player, name: CustomEvent, value: number, values: { string }?)
	local fields = values or {}
	remember(player, "custom", name, value, fields)
	send("custom " .. name, function()
		AnalyticsService:LogCustomEvent(player, name, value, customFields(fields))
	end)
end

-- Logs the net swings counted since the last roll up, one net_swing event per result, net level and device.
local function flushSwings(player: Player)
	local session = sessions[player]
	if session == nil or next(session.swings) == nil then
		return
	end
	local swings = session.swings
	session.swings = {}
	for _, entry in swings do
		Telemetry.custom(player, "net_swing", entry.count, entry.values)
	end
end

-- Counts one net swing (F93): `result` is NetSwing.result's "hit", "miss_near" or "miss_empty". Logged rolled up
-- every SWING_FLUSH_SECONDS and on leave (review S99).
function Telemetry.netSwing(player: Player, result: string, netLevel: number)
	local session = sessions[player]
	if session == nil then
		return
	end
	local values = { result, tostring(netLevel), session.device or "unknown" }
	local key = table.concat(values, "|")
	local entry = session.swings[key]
	if entry == nil then
		session.swings[key] = { count = 1, values = values }
	else
		entry.count += 1
	end
end

local function funnelStep(
	player: Player,
	funnel: string,
	sessionId: string,
	step: number,
	stepName: string,
	values: { string }
)
	remember(player, "funnel", funnel .. " " .. stepName, step, values)
	send("funnel " .. funnel, function()
		AnalyticsService:LogFunnelStepEvent(
			player,
			funnel,
			sessionId,
			step,
			stepName,
			customFields(values)
		)
	end)
end

-- catch_attempt step 1 (F93, catch-rework.md section 5): a net swing landed on a stray. `method` is net, rescue or
-- net_dropped (a knocked-loose cat).
function Telemetry.swingHit(
	player: Player,
	rarity: string,
	method: string,
	area: string
): CatchFunnel
	local funnel = { id = HttpService:GenerateGUID(false), values = { rarity, method, area } }
	funnelStep(player, "catch_attempt", funnel.id, 1, "swing_hit", funnel.values)
	return funnel
end

-- Step 2: the circles went out after that swing, or RescueBegin sent the challenge. A rescue has no swing, so with no
-- `funnel` this opens one and logs step 1 with it: the hold on the trap is where a rescue reaches its cat.
function Telemetry.catchEngaged(
	player: Player,
	rarity: string,
	method: string,
	area: string,
	funnel: CatchFunnel?
): CatchFunnel
	local current = funnel or Telemetry.swingHit(player, rarity, method, area)
	funnelStep(player, "catch_attempt", current.id, 2, "engaged", current.values)
	return current
end

-- Step 3: the cat is in the player's arms.
function Telemetry.catchCaught(player: Player, funnel: CatchFunnel)
	funnelStep(player, "catch_attempt", funnel.id, 3, "caught", funnel.values)
end

-- Step 4, and step 5 at once when the cat went straight to a role; otherwise step 5 waits for PlaceCat or Equip
-- best to give that uid a role (`catWorking`).
function Telemetry.catchCheckedIn(
	player: Player,
	funnel: CatchFunnel,
	uid: string,
	working: boolean
)
	funnelStep(player, "catch_attempt", funnel.id, 4, "checked_in", funnel.values)
	if working then
		funnelStep(player, "catch_attempt", funnel.id, 5, "working", funnel.values)
		return
	end
	local session = sessions[player]
	if session ~= nil then
		session.waitingForRole[uid] = funnel
	end
end

function Telemetry.catWorking(player: Player, uid: string)
	local session = sessions[player]
	local funnel = if session ~= nil then session.waitingForRole[uid] else nil
	if session == nil or funnel == nil then
		return
	end
	session.waitingForRole[uid] = nil
	funnelStep(player, "catch_attempt", funnel.id, 5, "working", funnel.values)
end

-- bait_cycle (analytics-plan 4.2): one persistent session id per bowl of food, because the timer runs offline.
-- `step` is 1 set (UseLure), 2 seen (the owner is shown the arrived cat) or 3 tamed.
function Telemetry.baitStep(player: Player, bait: Types.BaitState, step: number)
	local def = Catalog.getCat(bait.catId)
	local lure = Catalog.getLure(bait.lureId)
	local values = {
		bait.lureId,
		if lure ~= nil then lure.source else "unknown",
		if def ~= nil then def.rarity :: string else "unknown",
	}
	local names = { "set", "seen", "tamed" }
	funnelStep(
		player,
		"bait_cycle",
		string.format("%d-%d", player.UserId, bait.placedAt),
		step,
		names[step],
		values
	)
end

-- A shove knocked this player's cat loose: if they leave within LEFT_AFTER_SHOVE_SECONDS, left_after_shove fires.
function Telemetry.knockedLoose(player: Player, rarity: string)
	local session = sessions[player]
	if session ~= nil then
		session.knockedAt = os.clock()
		session.knockedRarity = rarity
	end
end

local function areaIndex(player: Player, profile: Profile, complete: boolean, areaId: string)
	local area = Catalog.getArea(areaId)
	if area == nil then
		return
	end
	local values = { catsDistinct(profile) }
	remember(
		player,
		if complete then "progress_complete" else "progress_start",
		"area_index",
		area.tier,
		values
	)
	send("progression area_index", function()
		if complete then
			AnalyticsService:LogProgressionCompleteEvent(
				player,
				"area_index",
				area.tier,
				areaId,
				customFields(values)
			)
		else
			AnalyticsService:LogProgressionStartEvent(
				player,
				"area_index",
				area.tier,
				areaId,
				customFields(values)
			)
		end
	end)
end

-- After a new cat joins the collection: area_index completes when every catalog cat of its area is in the Index. A
-- spare cat (data-model 3d) has no area page.
function Telemetry.collected(player: Player, profile: Profile, def: Types.CatDef)
	if def.area == "spare" then
		return
	end
	for _, other in Catalog.cats do
		if other.area == def.area and profile.collection[other.id] == nil then
			return
		end
	end
	areaIndex(player, profile, true, def.area)
end

local function progression(player: Player, profile: Profile, complete: boolean, tier: number)
	local values = { catsDistinct(profile) }
	local levelName = TIER_NAMES[tier] or tostring(tier)
	remember(
		player,
		if complete then "progress_complete" else "progress_start",
		"tier",
		tier,
		values
	)
	send("progression tier", function()
		if complete then
			AnalyticsService:LogProgressionCompleteEvent(
				player,
				"tier",
				tier,
				levelName,
				customFields(values)
			)
		else
			AnalyticsService:LogProgressionStartEvent(
				player,
				"tier",
				tier,
				levelName,
				customFields(values)
			)
		end
	end)
end

-- After RankUp has set profile.tier (and logged its Sink): the progression pair, rank_up with lifetime minutes
-- played, and the tier onboarding steps.
function Telemetry.rankedUp(player: Player, profile: Profile)
	local tier = Economy.tier(profile)
	progression(player, profile, true, tier - 1)
	progression(player, profile, false, tier)
	local tierDef = Catalog.getTier(tier)
	if tierDef ~= nil then
		areaIndex(player, profile, false, tierDef.area)
	end
	local session = sessions[player]
	local seconds = profile.stats.playtimeSeconds
		+ (if session ~= nil then math.max(0, os.time() - session.joinedAt) else 0)
	Telemetry.custom(player, "rank_up", math.floor(seconds / 60), { tostring(tier) })
	if tier == 2 then
		-- RankUp is pressed on the Rank Up card with the needs met: tier_2 implies both steps before it (F87)
		Telemetry.onboarding(player, profile, "tier_2")
	elseif tier == 3 then
		Telemetry.onboarding(player, profile, "tier_3")
	end
end

-- The device this player's client reported this session ("phone", "tablet", "pc" or "console"), or nil before it
-- has (bug reports carry it).
function Telemetry.device(player: Player): string?
	local session = sessions[player]
	return if session ~= nil then session.device else nil
end

-- The last LOG_SIZE events, oldest first (Studio only; empty on a live server).
function Telemetry.recent(count: number?): { LogEntry }
	local first = math.max(1, #log - (count or #log) + 1)
	local out: { LogEntry } = {}
	for i = first, #log do
		table.insert(out, log[i])
	end
	return out
end

-- Join and leave --------------------------------------------------------------------------------------------------

-- joined goes out as the profile loads (#1273: loaded carries the device now), then returned_next_day and the
-- steps the save already shows, so a save is never stuck behind a step it passed silently (QA S72).
local function logJoined(player: Player)
	local session = sessions[player]
	local profile = DataService.get(player)
	if session == nil or profile == nil or session.joinLogged then
		return
	end
	session.joinLogged = true
	Telemetry.onboarding(player, profile, "joined")
	if session.returnedNextDay then
		Telemetry.onboarding(player, profile, "returned_next_day")
	end
	local parkCats = 0
	for catId in profile.collection do
		local def = Catalog.getCat(catId)
		if def ~= nil and (def.area == "park" or def.incomeArea == "park") then
			parkCats += 1
		end
	end
	local shown = Onboarding.fromSave({
		catsCaught = profile.stats.catsCaught,
		distinctCats = Economy.distinctCats(profile),
		tables = Economy.level(profile, "tables"),
		bowl = Economy.level(profile, "lure_bowl"),
		tier = Economy.tier(profile),
		parkCats = parkCats,
		starterCat = profile.starterCatClaimed,
	})
	for _, name in shown do
		Telemetry.onboarding(player, profile, name :: Onboarding.StepName)
	end
end

-- A new player (#1273, F87): their first UTC day of play, or still in the first loop (Onboarding.isNewPlayer).
local function isNewPlayer(profile: Profile, now: number): boolean
	return Onboarding.isNewPlayer(profile.tutorialStep, profile.telemetry.firstDay, now)
end

-- The three fields of the time markers and the leave events: the furthest step logged, the screen open, and `third`.
local function whereInFunnel(profile: Profile, session: Session, third: string): { string }
	return { Onboarding.furthest(profile.telemetry), session.screen, third }
end

-- What the client reports (TelemetryReport), analytics only: every name and value is allowlisted or range checked,
-- the remote is limited to 40 a minute (Net), and nothing here pays, unlocks or saves anything but telemetry. A
-- funnel step a client sends is reached by itself (Onboarding.CLIENT_STEPS) and logs once per player.
local function onReport(player: Player, rawName: unknown, rawValue: unknown)
	local name = Guard.oneOf(rawName, REPORTS)
	local session = sessions[player]
	local profile = DataService.get(player)
	if name == nil or session == nil or profile == nil then
		return
	end
	if name == "device" then
		local device = Guard.oneOf(rawValue, DEVICES)
		if device ~= nil and session.device == nil then
			session.device = device
			Telemetry.onboarding(player, profile, "loaded", { device })
		end
	elseif name == "intro_choice" then
		local from = Guard.oneOf(rawValue, INTRO_FROM)
		if from ~= nil and session.introChoices < INTRO_CHOICES then
			session.introChoices += 1
			Telemetry.custom(player, "intro_choice", 1, { from })
			Telemetry.intro(player, profile, "intro_choice_made")
		end
	elseif name == "stuck_nudge" then
		local kind = Guard.oneOf(rawValue, NUDGE_KINDS)
		if kind ~= nil then
			local step = tostring(profile.tutorialStep)
			local key = step .. ":" .. kind
			if not session.nudges[key] then
				session.nudges[key] = true
				Telemetry.custom(player, "stuck_nudge", 1, { step, kind })
			end
		end
	elseif name == "step" then
		-- a tutorial card or the catch card on screen (Onboarding.REPORTABLE)
		local step = Guard.oneOf(rawValue, Onboarding.REPORTABLE)
		if step ~= nil then
			Telemetry.onboarding(player, profile, step :: Onboarding.StepName)
		end
	elseif name == "intro" then
		-- 0 as the intro starts, then each shot as it shows
		local shot = Guard.int(rawValue, 0, Intro.SHOTS)
		if shot ~= nil then
			local step = if shot == 0 then "intro_started" else "intro_shot_" .. tostring(shot)
			Telemetry.intro(player, profile, step :: Onboarding.IntroStepName)
		end
	elseif name == "screen" then
		-- the screen open now, "none" when it closed; kept for the time markers and the leave events
		if type(rawValue) == "string" and #(rawValue :: string) <= SCREEN_NAME_MAX then
			local raw = rawValue :: string
			session.screen = if raw == "none" then "none" else SCREENS[raw] or "other"
		end
	elseif name == "tutorial_closed" then
		if not session.tutorialClosed then
			session.tutorialClosed = true
			Telemetry.custom(player, "tutorial_closed", 1, { tostring(profile.tutorialStep) })
		end
	else
		local screen = if type(rawValue) == "string" then SCREENS[rawValue] else nil
		if screen ~= nil and not session.uiOpened[screen] then
			session.uiOpened[screen] = true
			Telemetry.custom(player, "ui_opened", 1, { screen })
			if not Onboarding.reached(profile.telemetry, "first_window_opened") then
				Telemetry.custom(player, "first_window", 1, { screen })
				Telemetry.onboarding(player, profile, "first_window_opened", { screen })
			end
			if screen == "rank_up" and Economy.tier(profile) == 1 then
				Telemetry.onboarding(player, profile, "rank_up_card_seen") -- Tier 2's needs showing (F87)
			end
		end
	end
end

-- #1273: a new player's time markers (Onboarding.MARKERS), each logged if this session is still the one that
-- started them.
local function startMarkers(player: Player, session: Session)
	for _, marker in Onboarding.MARKERS do
		task.delay(marker.seconds, function()
			local profile = DataService.get(player)
			if sessions[player] ~= session or profile == nil then
				return
			end
			Telemetry.custom(
				player,
				marker.name :: CustomEvent,
				marker.seconds,
				whereInFunnel(profile, session, session.device or "unknown")
			)
		end)
	end
end

local function onLoaded(player: Player, profile: Profile)
	local now = os.time()
	local firstSession = profile.stats.sessions <= 1
	local session: Session = {
		accounted = profile.lifetimeCoins,
		joinedAt = now,
		caughtAtJoin = profile.stats.catsCaught,
		device = nil,
		joinLogged = false,
		-- lastSeen is still the end of the previous session here (DataService sets it on leave)
		returnedNextDay = not firstSession
			and math.floor(profile.lastSeen / DAY_SECONDS) < math.floor(now / DAY_SECONDS),
		waitingForRole = {},
		knockedAt = nil,
		knockedRarity = nil,
		swings = {},
		origin = nil,
		nudges = {},
		introChoices = 0,
		screen = "none",
		uiOpened = {},
		tutorialClosed = false,
	}
	sessions[player] = session
	if firstSession then
		-- the template's coins never pass through Economy.credit, so they are not in lifetimeCoins
		logEconomy(
			player,
			profile,
			true,
			Config.StartCoins,
			profile.coins,
			"Onboarding",
			"start_coins"
		)
		progression(player, profile, false, Economy.tier(profile))
		areaIndex(player, profile, false, "alley")
	else
		local _, paidSeconds = DataService.peekPendingOffline(player)
		Telemetry.custom(
			player,
			"offline_return",
			math.floor(math.max(0, now - profile.lastSeen) / 60),
			{
				tostring(Economy.tier(profile)),
				tostring(math.floor(paidSeconds / 60)),
				if Economy.passes(profile).longNap then "long_nap" else "free",
			}
		)
	end
	logJoined(player)
	if isNewPlayer(profile, now) then
		startMarkers(player, session)
	end
end

local CAFE_REACH = 32 -- studs from the player's own plot's pivot that count as at the cafe for quit_point

-- Where the player's character stands as they leave, for quit_point: "cafe" by their own cafe, an area id on an
-- area's floor, "town" anywhere else, "none" with no character.
local function whereOf(player: Player): string
	local character = player.Character
	local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return "none"
	end
	local at = (root :: BasePart).Position
	for _, plot in CollectionService:GetTagged("Plot") do
		if plot:IsA("Model") and plot:GetAttribute("OwnerUserId") == player.UserId then
			local pivot = (plot :: Model):GetPivot().Position
			if Vector3.new(at.X - pivot.X, 0, at.Z - pivot.Z).Magnitude <= CAFE_REACH then
				return "cafe"
			end
		end
	end
	for id, spec in Layout.areas do
		local rects = spec.rects
		if rects ~= nil then
			-- a rects area's bounding box takes in the town between its floors, so test the floors themselves
			for _, r in rects do
				if
					at.X >= math.min(r.x1, r.x2)
					and at.X <= math.max(r.x1, r.x2)
					and at.Z >= math.min(r.z1, r.z2)
					and at.Z <= math.max(r.z1, r.z2)
				then
					return id
				end
			end
		else
			local c = spec.center
			if
				math.abs(at.X - c.x) <= spec.halfWidth
				and math.abs(at.Z - c.z) <= spec.halfDepth
			then
				return id
			end
		end
	end
	return "town"
end

-- Runs after the other services' leave work (Telemetry starts last), so a carried cat saved on leave or a rich tip
-- paid on leave has logged its own Source first.
local function onRelease(player: Player, profile: Profile)
	local session = sessions[player]
	if session == nil then
		return
	end
	logJoined(player) -- a player who leaves within DEVICE_WAIT_SECONDS still joined
	local now = os.time()
	Economy.settle(profile, now, ClockService.epoch())
	flushTips(player, profile, 0)
	-- unclaimed offline earnings are credited as the profile saves (DataService.finalize)
	local unclaimed = DataService.peekPendingOffline(player)
	if unclaimed > 0 then
		logEconomy(
			player,
			profile,
			true,
			unclaimed,
			profile.coins + unclaimed,
			"TimedReward",
			"offline"
		)
	end
	local knockedAt = session.knockedAt
	if knockedAt ~= nil and os.clock() - knockedAt <= LEFT_AFTER_SHOVE_SECONDS then
		Telemetry.custom(player, "left_after_shove", 1, {
			session.knockedRarity or "unknown",
			if os.clock() - knockedAt < 30 then "under_30" else "30-120",
		})
	end
	flushSwings(player)
	local caught = profile.stats.catsCaught - session.caughtAtJoin
	Telemetry.custom(player, "session_end", math.max(0, now - session.joinedAt), {
		bucket(caught, { 0, 2, 5 }, { "0", "1-2", "3-5", "6+" }),
		tierText(profile),
		session.device or "unknown",
	})
	-- F87: a new player leaving, in Roblox's bounce windows (easy-start.md section 5); #1273: with the furthest step
	-- logged and the screen open as they left, the value the seconds in game
	local played = math.max(0, now - session.joinedAt)
	if isNewPlayer(profile, now) then
		Telemetry.custom(
			player,
			"new_player_left",
			played,
			whereInFunnel(
				profile,
				session,
				bucket(played, { 60, 180, 600 }, { "0-60s", "61-180s", "3-10m", "10m+" })
			)
		)
	end
	if Economy.tier(profile) < 2 then
		Telemetry.custom(
			player,
			"quit_point",
			played,
			whereInFunnel(profile, session, whereOf(player))
		)
	end
	sessions[player] = nil
end

-- F87: the onboarding steps nothing else announces. first_move once the character has gone FIRST_MOVE_STUDS across
-- the ground from where it was first seen this session; first_customer_served (#1273) once a cafe with a cat in a role
-- has earned its first tips; rank_up_ready once a Tier 1 cafe meets Tier 2's needs (Economy.rankUpBlocker), which
-- coins earned in the background can do between syncs.
local function watchOnboarding(player: Player, session: Session)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	if not Onboarding.reached(profile.telemetry, "first_move") then
		local character = player.Character
		local root = if character ~= nil then character:FindFirstChild("HumanoidRootPart") else nil
		if root ~= nil and root:IsA("BasePart") then
			local at = (root :: BasePart).Position
			local origin = session.origin
			if origin == nil then
				session.origin = at
			elseif
				Vector3.new(at.X - origin.X, 0, at.Z - origin.Z).Magnitude >= FIRST_MOVE_STUDS
			then
				Telemetry.onboarding(player, profile, "first_move")
			end
		end
	end
	-- #1273: the cafe's first tips, settled into lifetimeCoins by CafeService's sync and not logged as a Source yet
	if
		not Onboarding.reached(profile.telemetry, "first_customer_served")
		and Onboarding.reached(profile.telemetry, "first_role_assigned")
		and profile.lifetimeCoins - session.accounted >= 1
	then
		Telemetry.onboarding(player, profile, "first_customer_served")
	end
	if
		Economy.tier(profile) == 1
		and not Onboarding.reached(profile.telemetry, "rank_up_ready")
		and Economy.rankUpBlocker(profile) == nil
	then
		Telemetry.onboarding(player, profile, "rank_up_ready")
	end
end

function Telemetry.start()
	DataService.onLoaded:Connect(onLoaded)
	DataService.beforeRelease(onRelease)
	Net.on("TelemetryReport", onReport)
	task.spawn(function()
		while true do
			task.wait(FLUSH_SECONDS)
			for player in sessions do
				local profile = DataService.get(player)
				if profile ~= nil then
					flushTips(player, profile, 0)
				end
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SWING_FLUSH_SECONDS)
			for player in sessions do
				flushSwings(player)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(WATCH_SECONDS)
			for player, session in sessions do
				watchOnboarding(player, session)
			end
		end
	end)
end

return Telemetry
