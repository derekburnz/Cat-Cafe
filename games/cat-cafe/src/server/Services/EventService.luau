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
-- Roblox terms: a DataStore keeps values by key across servers; GetAsync with UseCache false skips the 4 second
-- read cache, so a new schedule is seen at the next check.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CafeEvents = require(ReplicatedStorage.Shared.CafeEvents)
local ClockService = require(script.Parent.ClockService)
local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Signal = require(ReplicatedStorage.Shared.Signal)

local EventService = {}

-- Fires (event or nil) when the running event changes, after its effects are set.
EventService.changed = Signal.new() :: Signal.Signal<CafeEvents.Event?>
-- Fires just before the effects change, so CafeService settles every cafe at the old rate.
EventService.changing = Signal.new() :: Signal.Signal<nil>

local SUFFIX = if RunService:IsStudio() then "_dev" else ""

local schedule: { CafeEvents.Event } = {}
local test: CafeEvents.Event? = nil -- startTest's, in this server only
local running: CafeEvents.Event? = nil
local failing = false
local lastNotes = ""

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

-- When the running event ends (unix seconds, the os.time() of the Luck chip's timers), or nil.
function EventService.endsAt(): number?
	local event = running
	return if event ~= nil then event.endsAt else nil
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

-- Sets the running event's effects when it changes (a new id, or its record edited while it runs).
local function apply(at: number)
	local event = pick(at)
	local was = running
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
	schedule, notes = CafeEvents.parse(raw, now())
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
	publish(now())
	task.spawn(function()
		while true do
			read()
			task.wait(Config.EventPollSeconds)
		end
	end)
	task.spawn(function()
		while true do
			apply(now())
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

return EventService
