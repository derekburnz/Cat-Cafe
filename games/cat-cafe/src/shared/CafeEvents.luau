--!strict
-- Cafe Events (#2486; design: docs/design/cat-cafe/live-events.md, #2485), pure. A schedule, not a live button: the
-- events workflow (Tools-Agent, tools/opencloud/events.sh, #2488) writes a list of records under KEY in the STORE
-- DataStore (`_dev` in Studio), EventService reads it every Config.EventPollSeconds, and the shared clock
-- (Workspace:GetServerTimeNow) decides, so every server starts and ends an event together with no publish.
--
-- The value under KEY is a list of records (JSON; times are unix seconds, UTC):
--   { id = "party-1121", title = "Cafe Party", startsAt = 1795273200, endsAt = 1795280400, big = true,
--     effects = { days = { "lucky", "golden", "rainbow" }, money = 2, luck = 0.5,
--                 showers = { count = 8, gapSeconds = 900, firstAfter = 600 },
--                 reward = { cosmeticId = "Decor_PartyBunting" } } }
-- - `id`: 1 to ID_MAX of a-z, 0-9, "-" and "_" (the analytics key); `title`: 1 to TITLE_MAX characters, shown to
--   players; `big`: the weekly event (the workflow keeps big ones EventBigMinGapSeconds apart).
-- - `days` (section 2a): Lucky, Golden and Rainbow forced on for the window, on top of the day's own roll.
-- - `money` (2b): a multiplier on cafe income for everyone, after passes, 1 to EventMoneyMax.
-- - `luck` (2d): Luck added for everyone, 0 to EventLuckMax; total Luck stays inside LuckMax.
-- - `showers` (2c): `count` shower cats (at most EventShowerMax), the first `firstAfter` into the window, then one
--   every `gapSeconds` (at least EventShowerGapMinSeconds); odd ones a rainbow Legendary, even ones a Mythical.
-- - `reward` (2e): the free cosmetic a player gets for securing a cat in the window.
-- A value past its cap is clamped to it, with a note. A record that breaks a hard rule is dropped whole, with a
-- note: not a table, a bad id or title, no end, shorter than EventMinSeconds or longer than EventMaxSeconds, already
-- over, a bad effect, the same id twice, or overlapping an earlier-starting event. At most EventScheduleMax records
-- are read.
--   parse(raw, now) -> ({ Event }, { string })   the valid events by startsAt, and the notes for the log
--   current(list, now) -> Event?                  the event running at `now` (startsAt <= now < endsAt)
--   upcoming(list, now) -> Event?                 the next one to start after `now`
--   showerTimes(event) -> { number }              when each shower cat is due, unix seconds
--   showerKind(n) -> ShowerKind                   the n-th shower's cat (1 is a rainbow Legendary)
--   showerKey(event, n, job) -> string            the MemoryStore claim key of the n-th shower (2c)
--   showerPick(event, n) -> ShowerPick            its kind, coat, area (EventShowerAreaWeights) and cat, the same
--                                                 in every server
--   showerText(pick, opensAtTier?) / showerCaughtText(winner)   the banner lines
--   effectsData(event) -> table                   the effects as EventEffects carries them
--   effectsJson(event) -> string                  effectsData as JSON, the EventEffects attribute
--   test(preset, now, minutes) -> Event?          OwnerTest's and Studio's event in one server

local HttpService = game:GetService("HttpService")

local Catalog = require(script.Parent.Catalog)
local Catching = require(script.Parent.Catching)
local Config = require(script.Parent.Config)

local CafeEvents = {}

CafeEvents.STORE = "CatCafe_Events"
CafeEvents.KEY = "schedule"
CafeEvents.DAY_KINDS = { "lucky", "golden", "rainbow" }
CafeEvents.ID_MAX = 32
CafeEvents.TITLE_MAX = 24
-- section 1: the running event (or, between events, the next one) as ReplicatedStorage attributes, read by the HUD
CafeEvents.ATTRIBUTES = {
	id = "EventId",
	title = "EventTitle",
	startsAt = "EventStartsAt",
	endsAt = "EventEndsAt",
	effects = "EventEffects",
	running = "EventRunning",
}
-- OwnerTest's presets (section 8): "full" every effect, with test showers a minute apart; "days" the stacked days
-- only; "money" x2 only; "luck" +0.5 only; "showers" test showers only.
CafeEvents.PRESETS = { "full", "days", "money", "luck", "showers" }
CafeEvents.TEST_MINUTES_MIN = 5
CafeEvents.TEST_MINUTES_MAX = 120
CafeEvents.TEST_SHOWER_GAP = 60
CafeEvents.TEST_SHOWER_FIRST = 30
CafeEvents.TEST_SHOWERS_MAX = 3

export type DayKinds = { lucky: boolean, golden: boolean, rainbow: boolean }
export type ShowerKind = "rainbow_legendary" | "mythical"
export type ShowerPick = {
	n: number,
	kind: "Legendary" | "Mythical",
	coat: string?, -- "rainbow" for the odd ones; nil rolls the coat as a normal stray's
	areaId: string,
	catId: string,
}
export type Showers = { count: number, gapSeconds: number, firstAfter: number }
export type Effects = {
	days: DayKinds,
	money: number, -- 1 when the record has none
	luck: number, -- 0 when the record has none
	showers: Showers?,
	reward: string?, -- the cosmetic id
}
export type Event = {
	id: string,
	title: string,
	startsAt: number,
	endsAt: number,
	big: boolean,
	test: boolean, -- OwnerTest's, in one server only (its showers claim under test: keys)
	effects: Effects,
}

local function finite(value: unknown): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

local function whole(value: unknown): number?
	local number = finite(value)
	return if number ~= nil then math.floor(number) else nil
end

local function days(raw: unknown): DayKinds?
	local out: DayKinds = { lucky = false, golden = false, rainbow = false }
	if raw == nil then
		return out
	end
	if type(raw) ~= "table" then
		return nil
	end
	for _, kind in raw :: { any } do
		if kind == "lucky" then
			out.lucky = true
		elseif kind == "golden" then
			out.golden = true
		elseif kind == "rainbow" then
			out.rainbow = true
		else
			return nil
		end
	end
	return out
end

-- One record against the rules, or nil and why; `notes` takes the clamps.
local function record(raw: unknown, now: number, notes: { string }): (Event?, string?)
	if type(raw) ~= "table" then
		return nil, "not a record"
	end
	local values = raw :: { [string]: any }
	local id, title = values.id, values.title
	if
		type(id) ~= "string"
		or #id < 1
		or #id > CafeEvents.ID_MAX
		or string.find(id, "[^a-z0-9_%-]") ~= nil
	then
		return nil, "a bad id"
	end
	local length = if type(title) == "string" then utf8.len(title) else nil
	if length == nil or length < 1 or length > CafeEvents.TITLE_MAX then
		return nil, id .. ": a bad title"
	end
	local startsAt, endsAt = whole(values.startsAt), whole(values.endsAt)
	if startsAt == nil or endsAt == nil then
		return nil, id .. ": no start or no end"
	end
	local seconds = endsAt - startsAt
	if seconds < Config.EventMinSeconds or seconds > Config.EventMaxSeconds then
		return nil, id .. ": shorter or longer than an event may be"
	end
	if endsAt <= now then
		return nil, id .. ": already over"
	end
	local big = values.big
	if big ~= nil and type(big) ~= "boolean" then
		return nil, id .. ": a bad big"
	end
	local rawEffects = values.effects
	if type(rawEffects) ~= "table" then
		return nil, id .. ": no effects"
	end
	local effects = rawEffects :: { [string]: any }
	local forced = days(effects.days)
	local money = if effects.money == nil then 1 else finite(effects.money)
	local luck = if effects.luck == nil then 0 else finite(effects.luck)
	if forced == nil or money == nil or luck == nil then
		return nil, id .. ": a bad days, money or luck"
	end
	local function clamp(name: string, value: number, low: number, high: number): number
		local out = math.clamp(value, low, high)
		if out ~= value then
			table.insert(notes, `{id :: string}: {name} {value} clamped to {out}`)
		end
		return out
	end
	local showers: Showers? = nil
	local rawShowers = effects.showers
	if rawShowers ~= nil then
		if type(rawShowers) ~= "table" then
			return nil, id .. ": a bad showers"
		end
		local shower = rawShowers :: { [string]: any }
		local count = whole(shower.count)
		local gap = whole(shower.gapSeconds)
		local first = whole(shower.firstAfter)
		if count == nil or gap == nil or first == nil or first < 0 then
			return nil, id .. ": a bad showers"
		end
		if count > 0 then
			showers = {
				count = clamp("shower count", count, 0, Config.EventShowerMax),
				gapSeconds = clamp("shower gap", gap, Config.EventShowerGapMinSeconds, math.huge),
				firstAfter = first,
			}
		end
	end
	local reward: string? = nil
	local rawReward = effects.reward
	if rawReward ~= nil then
		local cosmetic = if type(rawReward) == "table"
			then (rawReward :: { [string]: any }).cosmeticId
			else nil
		if type(cosmetic) ~= "string" or #cosmetic < 1 or #cosmetic > 64 then
			return nil, id .. ": a bad reward"
		end
		reward = cosmetic
	end
	local event: Event = {
		id = id,
		title = title :: string,
		startsAt = startsAt,
		endsAt = endsAt,
		big = big == true,
		test = false,
		effects = {
			days = forced,
			money = clamp("money", money, 1, Config.EventMoneyMax),
			luck = clamp("luck", luck, 0, Config.EventLuckMax),
			showers = showers,
			reward = reward,
		},
	}
	return event, nil
end

function CafeEvents.parse(raw: unknown, now: number): ({ Event }, { string })
	local notes: { string } = {}
	local found: { Event } = {}
	if raw == nil then
		return found, notes
	end
	if type(raw) ~= "table" then
		table.insert(notes, "the schedule is not a list")
		return found, notes
	end
	local seen: { [string]: boolean } = {}
	for index, item in raw :: { any } do
		if type(index) ~= "number" then
			continue
		end
		if index > Config.EventScheduleMax then
			table.insert(notes, string.format("record %d: past EventScheduleMax", index))
			continue
		end
		local event, why = record(item, now, notes)
		if event == nil then
			table.insert(notes, string.format("record %d ignored: %s", index, why or "?"))
		elseif seen[event.id] then
			table.insert(
				notes,
				string.format("record %d ignored: %s is there twice", index, event.id)
			)
		else
			seen[event.id] = true
			table.insert(found, event)
		end
	end
	table.sort(found, function(a: Event, b: Event): boolean
		if a.startsAt ~= b.startsAt then
			return a.startsAt < b.startsAt
		end
		return a.id < b.id
	end)
	local out: { Event } = {}
	local lastEnd = -math.huge
	for _, event in found do
		if event.startsAt < lastEnd then
			table.insert(notes, string.format("%s ignored: it overlaps an earlier event", event.id))
		else
			table.insert(out, event)
			lastEnd = event.endsAt
		end
	end
	return out, notes
end

function CafeEvents.current(list: { Event }, now: number): Event?
	for _, event in list do
		if event.startsAt <= now and now < event.endsAt then
			return event
		end
	end
	return nil
end

function CafeEvents.upcoming(list: { Event }, now: number): Event?
	for _, event in list do
		if event.startsAt > now then
			return event
		end
	end
	return nil
end

-- When each shower cat is due: firstAfter into the window, then every gapSeconds, only those before the end.
function CafeEvents.showerTimes(event: Event): { number }
	local out: { number } = {}
	local shower = event.effects.showers
	if shower == nil then
		return out
	end
	for index = 0, shower.count - 1 do
		local at = event.startsAt + shower.firstAfter + index * shower.gapSeconds
		if at >= event.endsAt then
			break
		end
		table.insert(out, at)
	end
	return out
end

-- Section 2c: the odd showers are a rainbow Legendary, the even ones a Mythical.
function CafeEvents.showerKind(n: number): ShowerKind
	return if n % 2 == 1 then "rainbow_legendary" else "mythical"
end

-- Section 2c: the n-th shower's claim key, "event:<id>:<n>", one catch game-wide; a test event's, "test:<job>:<id>:<n>",
-- claims under its own server's job id, so it never touches live servers or another test.
function CafeEvents.showerKey(event: Event, n: number, job: string): string
	if event.test then
		return string.format("test:%s:%s:%d", job, event.id, n)
	end
	return string.format("event:%s:%d", event.id, n)
end

-- A number in [0, 1) for `text` and `salt`, the same everywhere (a Park-Miller fold of its bytes).
local MODULUS = 2147483647
local MULTIPLIER = 48271
local function roll(text: string, salt: number): number
	local hash = salt % MODULUS
	for index = 1, #text do
		hash = ((hash + string.byte(text, index)) * MULTIPLIER) % MODULUS
	end
	for _ = 1, 4 do
		hash = (hash * MULTIPLIER) % MODULUS
		hash = bit32.bxor(hash, bit32.rshift(hash, 13))
	end
	hash = (hash * MULTIPLIER) % MODULUS
	return hash / MODULUS
end

-- The area a roll in [0, 1) lands on, by EventShowerAreaWeights in Catalog.areas order (equal: 20 each).
function CafeEvents.showerAreaFor(r: number): string
	local weights = Config.EventShowerAreaWeights
	local total = 0
	for _, area in Catalog.areas do
		total += weights[area.id] or 0
	end
	local point = math.clamp(r, 0, 1) * total
	local last = Catalog.areas[1].id
	for _, area in Catalog.areas do
		local weight = weights[area.id] or 0
		if weight > 0 then
			last = area.id
			if point < weight then
				return area.id
			end
			point -= weight
		end
	end
	return last
end

-- The n-th shower's cat: odd ones a Legendary in a rainbow coat, even ones a Mythical whose coat rolls as a stray's;
-- the area and the cat from the event id and n, so every server spawns the same one.
function CafeEvents.showerPick(event: Event, n: number): ShowerPick
	local seed = event.id .. ":" .. tostring(n)
	local rainbow = CafeEvents.showerKind(n) == "rainbow_legendary"
	local kind: "Legendary" | "Mythical" = if rainbow then "Legendary" else "Mythical"
	local areaId = CafeEvents.showerAreaFor(roll(seed, 0x61726561)) -- "area"
	local def = Catching.pickCat(kind, areaId, roll(seed, 0x63617473)) -- "cats"
	return {
		n = n,
		kind = kind,
		coat = if rainbow then "rainbow" else nil,
		areaId = areaId,
		catId = def.id,
	}
end

-- "Event cat! A Mythical appeared in the Woods!", with "(opens at Tier 4)" for a player whose tier has not opened
-- the area, as the pity banner does.
function CafeEvents.showerText(pick: ShowerPick, opensAtTier: number?): string
	local area = Catalog.getArea(pick.areaId)
	local name = if area ~= nil then area.name else pick.areaId
	local what = if pick.coat == "rainbow" then "Rainbow " .. pick.kind else pick.kind
	local text = string.format("Event cat! A %s appeared in the %s!", what, name)
	if opensAtTier ~= nil then
		text ..= string.format(" (opens at Tier %d)", opensAtTier)
	end
	return text
end

function CafeEvents.showerCaughtText(winnerName: string): string
	return string.format("Event cat caught by %s!", winnerName)
end

-- The effects as the EventEffects attribute's short JSON: days (a list), money, luck, showers and reward.
function CafeEvents.effectsData(event: Event): { [string]: any }
	local effects = event.effects
	local list: { string } = {}
	for _, kind in CafeEvents.DAY_KINDS do
		if (effects.days :: any)[kind] then
			table.insert(list, kind)
		end
	end
	local out: { [string]: any } = { days = list, money = effects.money, luck = effects.luck }
	local shower = effects.showers
	if shower ~= nil then
		out.showers = {
			count = shower.count,
			gapSeconds = shower.gapSeconds,
			firstAfter = shower.firstAfter,
		}
	end
	if effects.reward ~= nil then
		out.reward = { cosmeticId = effects.reward }
	end
	return out
end

function CafeEvents.effectsJson(event: Event): string
	return HttpService:JSONEncode(CafeEvents.effectsData(event))
end

-- OwnerTest's and Studio's event in this server only (section 8): `preset` from PRESETS, from `now` for `minutes`
-- (TEST_MINUTES_MIN to TEST_MINUTES_MAX), nil for an unknown preset. Its showers come TEST_SHOWER_FIRST in, then
-- TEST_SHOWER_GAP apart (under the live gap's floor, as section 8 asks), at most TEST_SHOWERS_MAX.
function CafeEvents.test(preset: string, now: number, minutes: number): Event?
	if table.find(CafeEvents.PRESETS, preset) == nil then
		return nil
	end
	local seconds = math.clamp(
		math.floor(minutes),
		CafeEvents.TEST_MINUTES_MIN,
		CafeEvents.TEST_MINUTES_MAX
	) * 60
	local all = preset == "full"
	local count = math.min(
		CafeEvents.TEST_SHOWERS_MAX,
		(seconds - CafeEvents.TEST_SHOWER_FIRST) // CafeEvents.TEST_SHOWER_GAP + 1
	)
	local event: Event = {
		id = "test-" .. preset,
		title = "Test event",
		startsAt = now,
		endsAt = now + seconds,
		big = false,
		test = true,
		effects = {
			days = if all or preset == "days"
				then { lucky = true, golden = true, rainbow = true }
				else { lucky = false, golden = false, rainbow = false },
			money = if all or preset == "money" then Config.EventMoneyMax else 1,
			luck = if all or preset == "luck" then 0.5 else 0,
			showers = if all or preset == "showers"
				then {
					count = count,
					gapSeconds = CafeEvents.TEST_SHOWER_GAP,
					firstAfter = CafeEvents.TEST_SHOWER_FIRST,
				}
				else nil,
			reward = nil,
		},
	}
	return event
end

return CafeEvents
