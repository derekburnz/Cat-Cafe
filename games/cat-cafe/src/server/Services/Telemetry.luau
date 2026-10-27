--!strict
-- Analytics (feature F16, growth analytics-plan.md): the onboarding funnel, coin sources and sinks, tier progression
-- and a few custom events, sent through AnalyticsService. Server only; Roblox records nothing from Studio or a client.
-- Every Log call is wrapped in pcall: telemetry must never throw into gameplay. In Studio the last LOG_SIZE events
-- are also kept in memory for QA (`recent`, Debug.telemetry).
-- Custom fields are positional (CustomField01 to 03); the plan names each position. Values are short enum-like
-- strings, never a player's name, a cat's given name or chat, because Roblox folds a field past 8,000 distinct
-- values into "Other".
-- Tips are never an event per second: the cafe's income is counted from lifetimeCoins (CafeService settles it on
-- every sync) and logged as one Source at least once a minute, before every Sink and when the player leaves.

local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Onboarding = require(ReplicatedStorage.Shared.Onboarding)
local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
local Types = require(ReplicatedStorage.Shared.Types)

type Profile = Types.PlayerProfile

-- analytics-plan section 5: Roblox's transaction type names where they fit, plus Promo for codes
export type TransactionType = "Gameplay" | "Onboarding" | "Shop" | "TimedReward" | "Promo"

-- analytics-plan section 6. Names never change once shipped; the rest of the plan's events come with their features.
export type CustomEvent =
	"rank_up"
	| "session_end"
	| "offline_claim"
	| "dealer_buy"
	| "rich_tip"
	| "cat_sold"
	| "cat_renamed"
	| "autopress_flag"

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
-- steps already reached; held in profile.telemetry otherwise (Onboarding.reach).
function Telemetry.onboarding(player: Player, profile: Profile, stepName: Onboarding.StepName)
	for _, name in Onboarding.reach(profile.telemetry, stepName) do
		local step = Onboarding.index(name)
		remember(player, "onboarding", name, step, {})
		send("onboarding " .. name, function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
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

local function onLoaded(player: Player, profile: Profile)
	local now = os.time()
	sessions[player] = {
		accounted = profile.lifetimeCoins,
		joinedAt = now,
		caughtAtJoin = profile.stats.catsCaught,
	}
	local firstSession = profile.stats.sessions <= 1
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
	end
	Telemetry.onboarding(player, profile, "joined")
	-- lastSeen is still the end of the previous session here (DataService sets it on leave)
	if
		not firstSession
		and math.floor(profile.lastSeen / DAY_SECONDS) < math.floor(now / DAY_SECONDS)
	then
		Telemetry.onboarding(player, profile, "returned_next_day")
	end
end

-- Runs after the other services' leave work (Telemetry starts last), so a carried cat saved on leave or a rich tip
-- paid on leave has logged its own Source first.
local function onRelease(player: Player, profile: Profile)
	local session = sessions[player]
	if session == nil then
		return
	end
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
	local caught = profile.stats.catsCaught - session.caughtAtJoin
	Telemetry.custom(player, "session_end", math.max(0, now - session.joinedAt), {
		bucket(caught, { 0, 2, 5 }, { "0", "1-2", "3-5", "6+" }),
		tierText(profile),
	})
	sessions[player] = nil
end

function Telemetry.start()
	DataService.onLoaded:Connect(onLoaded)
	DataService.beforeRelease(onRelease)
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
