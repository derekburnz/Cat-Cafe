--!strict
-- Analytics (feature F16, growth analytics-plan.md): the onboarding funnel, the catch_attempt and bait_cycle funnels,
-- coin sources and sinks, tier and area Index progression and the custom events, sent through AnalyticsService.
-- Server only; Roblox records nothing from Studio or a client. What only the client knows (its device, a screen it
-- opened) arrives through TelemetryReport, allowlisted and limited to 10 a minute.
-- Every Log call is wrapped in pcall: telemetry must never throw into gameplay. In Studio the last LOG_SIZE events
-- are also kept in memory for QA (`recent`, Debug.telemetry).
-- Custom fields are positional (CustomField01 to 03); the plan names each position. Values are short enum-like
-- strings, never a player's name, a cat's given name or chat, because Roblox folds a field past 8,000 distinct
-- values into "Other".
-- Tips are never an event per second: the cafe's income is counted from lifetimeCoins (CafeService settles it on
-- every sync) and logged as one Source at least once a minute, before every Sink and when the player leaves.

local AnalyticsService = game:GetService("AnalyticsService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Catalog)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Guard = require(script.Parent.Parent.Util.Guard)
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
local FLUSH_SECONDS = 60
local LOG_SIZE = 200
local DAY_SECONDS = 86400
local DEVICE_WAIT_SECONDS = 10 -- the joined step waits this long for the client's device report
local LEFT_AFTER_SHOVE_SECONDS = 120
local REPORTS = { "device", "ui_opened" }
local DEVICES = { "phone", "tablet", "pc", "console" }
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
	sku: string
)
	if amount <= 0 then
		return
	end
	local flow = if isSource
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	local values = { tierText(profile), ClockService.phase(), catsWorking(profile) }
	local ending = math.max(0, math.floor(balance))
	remember(player, if isSource then "source" else "sink", sku, amount, values)
	send("economy " .. sku, function()
		AnalyticsService:LogEconomyEvent(
			player,
			flow,
			CURRENCY,
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
	logEconomy(player, profile, true, tips, profile.coins + pending, "Gameplay", "tips")
end

-- Public API ---------------------------------------------------------------------------------------------------

-- One onboarding step (analytics-plan section 3). Logged at once when it is the next step, along with any later
-- steps already reached; held in profile.telemetry otherwise (Onboarding.reach). `values` go with this step only.
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
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name, customFields(fields))
		end)
	end
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

function Telemetry.custom(player: Player, name: CustomEvent, value: number, values: { string }?)
	local fields = values or {}
	remember(player, "custom", name, value, fields)
	send("custom " .. name, function()
		AnalyticsService:LogCustomEvent(player, name, value, customFields(fields))
	end)
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

-- catch_attempt step 1: GrabBegin sent the circles, or RescueBegin sent the challenge. `method` is net, rescue or
-- net_dropped (a knocked-loose cat).
function Telemetry.catchEngaged(
	player: Player,
	rarity: string,
	method: string,
	area: string
): CatchFunnel
	local funnel = { id = HttpService:GenerateGUID(false), values = { rarity, method, area } }
	funnelStep(player, "catch_attempt", funnel.id, 1, "engaged", funnel.values)
	return funnel
end

-- Step 2: the cat is in the player's arms.
function Telemetry.catchCaught(player: Player, funnel: CatchFunnel)
	funnelStep(player, "catch_attempt", funnel.id, 2, "caught", funnel.values)
end

-- Step 3, and step 4 at once when the cat went straight to a role; otherwise step 4 waits for PlaceCat or Equip
-- best to give that uid a role (`catWorking`).
function Telemetry.catchCheckedIn(
	player: Player,
	funnel: CatchFunnel,
	uid: string,
	working: boolean
)
	funnelStep(player, "catch_attempt", funnel.id, 3, "checked_in", funnel.values)
	if working then
		funnelStep(player, "catch_attempt", funnel.id, 4, "working", funnel.values)
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
	funnelStep(player, "catch_attempt", funnel.id, 4, "working", funnel.values)
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

-- After a new cat joins the collection: area_index completes when every catalog cat of its area is in the Index.
function Telemetry.collected(player: Player, profile: Profile, def: Types.CatDef)
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
		Telemetry.onboarding(player, profile, "tier_2")
	elseif tier == 3 then
		Telemetry.onboarding(player, profile, "tier_3")
	end
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

-- The joined step carries the device, so it waits for the client's report or DEVICE_WAIT_SECONDS, whichever is
-- first. Steps reached meanwhile are held behind it as usual.
local function logJoined(player: Player)
	local session = sessions[player]
	local profile = DataService.get(player)
	if session == nil or profile == nil or session.joinLogged then
		return
	end
	session.joinLogged = true
	Telemetry.onboarding(player, profile, "joined", { session.device or "unknown" })
	if session.returnedNextDay then
		Telemetry.onboarding(player, profile, "returned_next_day")
	end
end

local function onReport(player: Player, rawName: unknown, rawValue: unknown)
	local name = Guard.oneOf(rawName, REPORTS)
	local session = sessions[player]
	if name == nil or session == nil then
		return
	end
	if name == "device" then
		local device = Guard.oneOf(rawValue, DEVICES)
		if device ~= nil and session.device == nil then
			session.device = device
			logJoined(player)
		end
	else
		local screen = if type(rawValue) == "string" then SCREENS[rawValue] else nil
		if screen ~= nil then
			Telemetry.custom(player, "ui_opened", 1, { screen })
		end
	end
end

local function onLoaded(player: Player, profile: Profile)
	local now = os.time()
	local firstSession = profile.stats.sessions <= 1
	sessions[player] = {
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
	}
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
	end
	task.delay(DEVICE_WAIT_SECONDS, logJoined, player)
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
	local caught = profile.stats.catsCaught - session.caughtAtJoin
	Telemetry.custom(player, "session_end", math.max(0, now - session.joinedAt), {
		bucket(caught, { 0, 2, 5 }, { "0", "1-2", "3-5", "6+" }),
		tierText(profile),
		session.device or "unknown",
	})
	sessions[player] = nil
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
end

return Telemetry
