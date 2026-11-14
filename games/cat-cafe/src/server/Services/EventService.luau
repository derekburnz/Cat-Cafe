--!strict
-- Cafe Events on the server (#2486; docs/design/cat-cafe/live-events.md; shared/CafeEvents for the record and its
-- caps). Reads the schedule from the CatCafe_Events DataStore (`_dev` in Studio) every Config.EventPollSeconds and,
-- once a second, works out which event runs now on Workspace:GetServerTimeNow(), the clock the day cycle and the pity
-- cat share, so every server starts and ends one within a second of the others. A server that starts during an event
-- joins it under way. While one runs:
-- - its forced day kinds go to ClockService (ClockService.setEventDays), on top of the day's own roll (2a);
-- - its money multiplier goes to Economy.settle (Economy.setEventMoney), on every player's cafe income (2b);
-- - its Luck is `EventService.luck()`, which every Luck.of caller passes (CafeService, BaitService, FishMarket) (2d).
-- Section 1: ReplicatedStorage carries the running event, or between events the next one, as the attributes
-- EventId, EventTitle, EventStartsAt, EventEndsAt, EventEffects (CafeEvents.effectsJson) and EventRunning; EventId
-- is "" with none. Clients only read them.
-- Without "Enable Studio Access to API Services" (DataService.saves() false) Studio reads nothing. A read that fails
-- keeps the schedule this server had and is warned once until reads work again. The parse's notes (a clamp, a record
-- ignored) are logged when they change. `startTest` (Studio, and OwnerTest's `event <preset> <minutes>`) runs a test
-- event in this server only and writes nothing to the store.
--
-- Section 7's analytics (not for test events): event_join once per player in a running event (joined during it, or in
-- the server as it started), and event_money, the coins its multiplier added for each player (Economy.noteEventExtra),
-- at its end or their leave.
--
-- #4195, admin events (shared/CafeEvents, the `admin = true` records): a second lane beside the normal event, behind
-- the LiveFlags switch `adminEvents` (off: none shows or runs). ReplicatedStorage carries the one running, or from
-- CafeEvents.ADMIN.warnSeconds before its start the one coming, as AdminEventId, AdminEventTitle, AdminEventStartsAt,
-- AdminEventEndsAt, AdminEventEffects and AdminEventRunning (CafeEvents.ADMIN_ATTRIBUTES; the client's warning
-- banner, start banner and timer). `EventService.admin()` is the running one, `adminChanged` fires when it changes,
-- and `EventService.bowlSpeed()` is Bowl Frenzy's factor for BaitService (1 with none). `/admin bowl [minutes] [now]`
-- from an owner writes one for every server (ownerAdmin), or in Studio and a private server runs it there
-- (startAdminTest); `/admin stop` ends the owner's (ownerAdminStop).
--
-- Roblox terms: a DataStore keeps values by key across servers; GetAsync with UseCache false skips the 4 second
-- read cache, so a new schedule is seen at the next check.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeEvents = require(ReplicatedStorage.Shared.CafeEvents)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local LiveFlagService = require(script.Parent.LiveFlagService)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Telemetry = require(script.Parent.Telemetry)

local EventService = {}

-- Fires (event or nil) when the running event changes, after its effects are set.
EventService.changed = Signal.new() :: Signal.Signal<CafeEvents.Event?>
-- Fires just before the effects change, so CafeService settles every cafe at the old rate.
EventService.changing = Signal.new() :: Signal.Signal<nil>
-- #4195: fires (admin event or nil) when the running admin event changes.
EventService.adminChanged = Signal.new() :: Signal.Signal<CafeEvents.AdminEvent?>

local SUFFIX = if RunService:IsStudio() then "_dev" else ""

local schedule: { CafeEvents.Event } = {}
local test: CafeEvents.Event? = nil -- startTest's, in this server only
local running: CafeEvents.Event? = nil
local failing = false
local lastNotes = ""
local joined: { [Player]: boolean } = {} -- event_join logged for the running event
local ended: CafeEvents.Event? = nil -- the last event that ended here, and when (server time), for recent()
local endedAt = 0
local adminSchedule: { CafeEvents.AdminEvent } = {} -- #4195
local adminTest: CafeEvents.AdminEvent? = nil -- startTest's, in this server only
local adminRunning: CafeEvents.AdminEvent? = nil
local adminPublished = "" -- what the Admin* attributes carry now, as one string
local RECENT_SECONDS = 300 -- a shower due by its end at night still spawns at the next sunrise (nights are 45 s)

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- The event running now: the test one first, then the schedule's.
local function pick(at: number): CafeEvents.Event?
	local own = test
	if own ~= nil then
		if at < own.endsAt then
			return own
		end
		test = nil
	end
	return CafeEvents.current(schedule, at)
end

-- The running event's Luck for everyone, 0 without one (Luck.of's `event`).
function EventService.luck(): number
	local event = running
	return if event ~= nil then event.effects.luck else 0
end

-- The running event's money multiplier, 1 without one.
function EventService.money(): number
	local event = running
	return if event ~= nil then event.effects.money else 1
end

-- The running event, or nil.
function EventService.current(): CafeEvents.Event?
	return running
end

-- The running event, else the one that ended in the last RECENT_SECONDS (PityService's showers), else nil.
function EventService.recent(): CafeEvents.Event?
	local event = running
	if event ~= nil then
		return event
	end
	return if ended ~= nil and now() - endedAt < RECENT_SECONDS then ended else nil
end

-- When the running event ends (unix seconds, the os.time() of the Luck chip's timers), or nil.
function EventService.endsAt(): number?
	local event = running
	return if event ~= nil then event.endsAt else nil
end

-- #4195: the running admin event, or nil.
function EventService.admin(): CafeEvents.AdminEvent?
	return adminRunning
end

-- #4195 (Bowl Frenzy): how many times sooner food put in a bait bowl now brings its cat, 1 with no admin event.
function EventService.bowlSpeed(): number
	local event = adminRunning
	return if event ~= nil then event.effects.bowlSpeed else 1
end

local function daysText(event: CafeEvents.Event): string
	local out: { string } = {}
	for _, kind in CafeEvents.DAY_KINDS do
		if (event.effects.days :: any)[kind] then
			table.insert(out, kind)
		end
	end
	return table.concat(out, ",")
end

-- The running event, or between events the next one, on ReplicatedStorage (section 1).
local function publish(at: number)
	local event = running
	local shown = event or CafeEvents.upcoming(schedule, at)
	local names = CafeEvents.ATTRIBUTES
	ReplicatedStorage:SetAttribute(names.id, if shown ~= nil then shown.id else "")
	ReplicatedStorage:SetAttribute(names.title, if shown ~= nil then shown.title else "")
	ReplicatedStorage:SetAttribute(names.startsAt, if shown ~= nil then shown.startsAt else 0)
	ReplicatedStorage:SetAttribute(names.endsAt, if shown ~= nil then shown.endsAt else 0)
	ReplicatedStorage:SetAttribute(
		names.effects,
		if shown ~= nil then CafeEvents.effectsJson(shown) else ""
	)
	ReplicatedStorage:SetAttribute(names.running, event ~= nil)
end

-- #4195: the admin events this server may show at `at`: its own test first, then the schedule's; none with the
-- switch off.
local function adminList(at: number): { CafeEvents.AdminEvent }
	if not LiveFlagService.on(CafeEvents.ADMIN.flag) then
		return {}
	end
	local own = adminTest
	if own ~= nil then
		if at < own.endsAt then
			return { own }
		end
		adminTest = nil
	end
	return adminSchedule
end

-- #4195: the admin lane's second: which one runs, which one shows (the warning before a start), the attributes when
-- either changed, and adminChanged when the running one did.
local function applyAdmin(at: number)
	local list = adminList(at)
	local event = CafeEvents.adminCurrent(list, at)
	local shown = event or CafeEvents.adminShown(list, at)
	local text = if shown ~= nil
		then string.format(
			"%s|%s|%d|%d|%s|%s",
			shown.id,
			shown.title,
			shown.startsAt,
			shown.endsAt,
			CafeEvents.adminEffectsJson(shown),
			tostring(event ~= nil)
		)
		else ""
	if text ~= adminPublished then
		adminPublished = text
		local names = CafeEvents.ADMIN_ATTRIBUTES
		ReplicatedStorage:SetAttribute(names.id, if shown ~= nil then shown.id else "")
		ReplicatedStorage:SetAttribute(names.title, if shown ~= nil then shown.title else "")
		ReplicatedStorage:SetAttribute(names.startsAt, if shown ~= nil then shown.startsAt else 0)
		ReplicatedStorage:SetAttribute(names.endsAt, if shown ~= nil then shown.endsAt else 0)
		ReplicatedStorage:SetAttribute(
			names.effects,
			if shown ~= nil then CafeEvents.adminEffectsJson(shown) else ""
		)
		ReplicatedStorage:SetAttribute(names.running, event ~= nil)
	end
	local was = adminRunning
	local same = (was == nil and event == nil)
		or (
			was ~= nil
			and event ~= nil
			and was.id == event.id
			and was.endsAt == event.endsAt
			and CafeEvents.adminEffectsJson(was) == CafeEvents.adminEffectsJson(event)
		)
	adminRunning = event
	if same then
		return
	end
	if event ~= nil then
		print(
			string.format(
				"[EventService] admin event %s running until %d%s: %s",
				event.id,
				event.endsAt,
				if event.test then " (test, this server only)" else "",
				CafeEvents.adminEffectsJson(event)
			)
		)
	elseif was ~= nil then
		print(string.format("[EventService] admin event %s ended", was.id))
	end
	EventService.adminChanged:Fire(event)
end

-- event_money for one player: what the running event's money added for them since the last take.
local function logMoney(player: Player, event: CafeEvents.Event)
	local profile = DataService.get(player)
	if profile == nil then
		return
	end
	local extra = math.floor(Economy.takeEventExtra(profile))
	if extra > 0 and not event.test then
		Telemetry.custom(player, "event_money", extra, { event.id, tostring(profile.tier) })
	end
end

-- event_join for every loaded player not logged yet in the running event.
local function logJoins(event: CafeEvents.Event)
	if event.test then
		return
	end
	for _, player in DataService.loadedPlayers() do
		if not joined[player] then
			joined[player] = true
			local source, joinEvent = Telemetry.joinOf(player)
			Telemetry.custom(player, "event_join", 1, { event.id, joinEvent, source })
		end
	end
end

-- Sets the running event's effects when it changes (a new id, or its record edited while it runs).
local function apply(at: number)
	local event = pick(at)
	local was = running
	if was ~= nil and (event == nil or event.id ~= was.id) then
		-- the end (or the next event): each player's boost coins under the event that paid them
		for _, player in DataService.loadedPlayers() do
			logMoney(player, was)
		end
		table.clear(joined)
		ended, endedAt = was, at
	end
	if event ~= nil then
		logJoins(event)
	end
	local same = was ~= nil
		and event ~= nil
		and was.id == event.id
		and CafeEvents.effectsJson(was) == CafeEvents.effectsJson(event)
		and was.endsAt == event.endsAt
	if same or (was == nil and event == nil) then
		running = event
		return
	end
	EventService.changing:Fire(nil)
	running = event
	ClockService.setEventDays(if event ~= nil then event.effects.days else nil)
	Economy.setEventMoney(if event ~= nil then event.effects.money else 1)
	if event ~= nil then
		print(
			string.format(
				"[EventService] %s running until %d%s: money x%g, luck +%g, days %s",
				event.id,
				event.endsAt,
				if event.test then " (test, this server only)" else "",
				event.effects.money,
				event.effects.luck,
				daysText(event)
			)
		)
	elseif was ~= nil then
		print(string.format("[EventService] %s ended", was.id))
	end
	publish(at)
	EventService.changed:Fire(event)
end

local function live(): boolean
	return not RunService:IsStudio() or DataService.saves()
end

local function read()
	if not live() then
		return
	end
	local ok, raw = pcall(function()
		local store = DataStoreService:GetDataStore(CafeEvents.STORE .. SUFFIX)
		local options = Instance.new("DataStoreGetOptions")
		options.UseCache = false
		return store:GetAsync(CafeEvents.KEY, options)
	end)
	if not ok then
		if not failing then
			failing = true
			-- only the message's start: DataStore errors can carry ids, and logs are public
			warn("[EventService] reading CatCafe_Events failed, keeping the schedule as it was")
		end
		return
	end
	failing = false
	local notes: { string }
	schedule, notes, adminSchedule = CafeEvents.parse(raw, now())
	local text = table.concat(notes, "; ")
	if text ~= lastNotes then
		lastNotes = text
		if text ~= "" then
			warn("[EventService] " .. text)
		end
	end
	publish(now())
end

function EventService.start()
	Players.PlayerRemoving:Connect(function(player)
		local event = running
		if event ~= nil then
			logMoney(player, event)
		end
		joined[player] = nil
	end)
	publish(now())
	applyAdmin(now()) -- the Admin* attributes exist from the start
	task.spawn(function()
		while true do
			read()
			task.wait(Config.EventPollSeconds)
		end
	end)
	task.spawn(function()
		while true do
			apply(now())
			applyAdmin(now())
			task.wait(1)
		end
	end)
end

-- Studio, and OwnerTest's `event <preset> <minutes>` in a private server (section 8): a test event (CafeEvents.test)
-- in this server only, from now; "stop" ends it. The caller checks the place. Returns its line for the log.
function EventService.startTest(preset: string, minutes: number): string
	if preset == "stop" then
		test = nil
		apply(now())
		return "test event ended"
	end
	local event = CafeEvents.test(preset, now(), minutes)
	if event == nil then
		return "no such preset: " .. table.concat(CafeEvents.PRESETS, ", ") .. ", or stop"
	end
	test = event
	apply(now())
	return string.format("%s until %d", event.id, math.floor(event.endsAt))
end

-- #3212: reads the schedule now, not at the next poll (another server's owner changed it, OwnerTestService).
function EventService.refresh()
	read()
	apply(now())
	applyAdmin(now())
end

-- The schedule in the store, changed by `change` (pure; nil keeps it as it is). False when the store did not answer.
local function rewrite(change: (raw: unknown) -> { any }?): boolean
	local ok = pcall(function()
		local store = DataStoreService:GetDataStore(CafeEvents.STORE .. SUFFIX)
		store:UpdateAsync(CafeEvents.KEY, function(raw: unknown)
			return change(raw)
		end)
	end)
	return ok
end

-- #3212 (Derek2 2026-11-11: "/event 10 for 10 min evfent" from a live server): the owner's event for every server.
-- A real record goes into the schedule (CafeEvents.ownerRecord, starting now), so each server runs it by the shared
-- clock within its next read, as it would one from the events workflow. The caller (OwnerTestService) has checked
-- the owner. Returns the line for the owner's toast and whether the schedule changed.
function EventService.ownerStart(preset: string, minutes: number): (string, boolean)
	local record = CafeEvents.ownerRecord(preset, now(), minutes)
	if record == nil then
		return "no such preset: " .. table.concat(CafeEvents.PRESETS, ", ") .. ", or stop", false
	end
	if not live() then
		return "the events store is off in this place", false
	end
	local why: string? = nil
	local ok = rewrite(function(raw: unknown): { any }?
		local list, refusal = CafeEvents.ownerAdd(raw, record, now())
		why = refusal
		return list
	end)
	if not ok then
		return "the events store did not answer; nothing started", false
	end
	if why ~= nil then
		return why, false
	end
	EventService.refresh()
	print(string.format("[EventService] owner event %s written to the schedule", record.id))
	return string.format(
		"%s started on all servers for %d minutes",
		record.title,
		(record.endsAt - record.startsAt) // 60
	),
		true
end

-- #3212: `/event stop` in a live server: the owner's own records come out of the schedule, running or coming.
function EventService.ownerStop(): (string, boolean)
	if not live() then
		return "the events store is off in this place", false
	end
	local removed = 0
	local ok = rewrite(function(raw: unknown): { any }?
		local list, count = CafeEvents.ownerRemove(raw, now(), false)
		removed = count
		return if count > 0 then list else nil
	end)
	if not ok then
		return "the events store did not answer; nothing changed", false
	end
	if removed == 0 then
		return "no event of yours is running or coming (one from the events workflow ends there)",
			false
	end
	EventService.refresh()
	return "your event ended on all servers", true
end

local function adminKinds(): string
	local kinds: { string } = {}
	for kind in CafeEvents.ADMIN_KINDS do
		table.insert(kinds, kind)
	end
	table.sort(kinds)
	return table.concat(kinds, ", ")
end

local function adminOff(): string?
	return if LiveFlagService.on(CafeEvents.ADMIN.flag)
		then nil
		else "admin events are switched off (the adminEvents switch)"
end

-- #4195: `/admin <kind> [minutes] [now]` in Studio or a private server: the admin event in this server only, after
-- a short warning (none with `skipWarning`); "stop" ends it. Writes nothing to the store. Returns its line.
function EventService.startAdminTest(kind: string, minutes: number?, skipWarning: boolean?): string
	if kind == "stop" then
		adminTest = nil
		applyAdmin(now())
		return "test admin event ended"
	end
	local off = adminOff()
	if off ~= nil then
		return off
	end
	local event = CafeEvents.adminTest(kind, now(), minutes, skipWarning)
	if event == nil then
		return "no such admin event: " .. adminKinds() .. ", or stop"
	end
	adminTest = event
	applyAdmin(now())
	return string.format(
		"%s from %d until %d",
		event.id,
		math.floor(event.startsAt),
		math.floor(event.endsAt)
	)
end

-- #4195 (Derek 2026-11-14: owner chat commands to start each admin event himself): `/admin <kind> [minutes] [now]`
-- in a live server writes an admin record into the schedule, so every server shows the 2 minute warning and then
-- runs it by the shared clock, beside a Cafe Party if one runs. The caller (OwnerTestService) has checked the owner.
-- Returns the line for the owner's toast and whether the schedule changed.
function EventService.ownerAdmin(
	kind: string,
	minutes: number?,
	skipWarning: boolean?
): (string, boolean)
	local off = adminOff()
	if off ~= nil then
		return off, false
	end
	local record = CafeEvents.adminRecord(kind, now(), minutes, skipWarning)
	if record == nil then
		return "no such admin event: " .. adminKinds() .. ", or stop", false
	end
	if not live() then
		return "the events store is off in this place", false
	end
	local why: string? = nil
	local ok = rewrite(function(raw: unknown): { any }?
		local list, refusal = CafeEvents.ownerAdd(raw, record, now())
		why = refusal
		return list
	end)
	if not ok then
		return "the events store did not answer; nothing started", false
	end
	if why ~= nil then
		return why, false
	end
	EventService.refresh()
	print(string.format("[EventService] owner admin event %s written to the schedule", record.id))
	local length = (record.endsAt - record.startsAt) // 60
	if skipWarning then
		return string.format("%s started on all servers for %d minutes", record.title, length), true
	end
	return string.format(
		"%s starts on all servers in %d minutes, for %d minutes",
		record.title,
		CafeEvents.ADMIN.warnSeconds // 60,
		length
	),
		true
end

-- #4195: `/admin stop` in a live server: the owner's admin records come out of the schedule, running or coming.
function EventService.ownerAdminStop(): (string, boolean)
	if not live() then
		return "the events store is off in this place", false
	end
	local removed = 0
	local ok = rewrite(function(raw: unknown): { any }?
		local list, count = CafeEvents.ownerRemove(raw, now(), true)
		removed = count
		return if count > 0 then list else nil
	end)
	if not ok then
		return "the events store did not answer; nothing changed", false
	end
	if removed == 0 then
		return "no admin event of yours is running or coming", false
	end
	EventService.refresh()
	return "your admin event ended on all servers", true
end

return EventService
