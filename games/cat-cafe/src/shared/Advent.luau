--!strict
-- #5502 the Christmas advent calendar (Design-Agent's advent-calendar-spec.md, Derek 2026-11-19 21:59 UTC: "make sure
-- it doesn't accidentally start until proper date"). 24 doors, opened one tap at a time in number order, each paying
-- a fixed prize shown before it opens; doors 6, 12, 18 and 24 give the four calendar cats (Catalog, source "advent").
-- Nothing is random and nothing is for Robux.
--
-- Two locks, both checked by the server on every open (AdventService), never the client's clock:
--   1. the dates: door 1 opens at FIRST_OPEN (Tue Dec 1 2026 20:00 UTC), door n (2 to 24) at 00:00 UTC on Dec n, and
--      nothing opens from CLOSES (Mon Jan 4 2027 00:00 UTC, the end of Jan 3) on;
--   2. the switches: FLAG `adventCalendar` (LiveFlags.OFF_BY_DEFAULT) and EVENT_FLAG `christmasEvent`, both on.
-- Missed doors are not lost: today's door (the newest one open, on its own UTC day) always opens, and a player who is
-- behind may open CATCH_UP_PER_DAY earlier doors a UTC day. The spec says one, but doors open in order, so a player
-- behind never reaches today's door and one a day would open only 15 of 24 for a Dec 20 start; two a day keeps
-- Design's promise that a Dec 20 start still opens all 24 by Jan 3 (15 days, 30 opens).
-- Saved as profile.advent = { year, opened, day, caught } (opened: doors opened, in order; day: the UTC day of the
-- last catch-up; caught: catch-ups used on that day). Optional, so no save version: an older server drops it, which
-- is why the switch goes on only after the Christmas restart. A year other than YEAR reads as a fresh calendar.
-- Pure.
--   doorAt(n) -> number                 when door n opens (os.time)
--   due(now) -> number                  doors open by the dates at `now` (0 before FIRST_OPEN and from CLOSES)
--   live(on, eventOn, now) -> boolean   both locks open and at least door 1 due
--   fresh(raw?) -> State                this year's state from a save's field
--   check(state, now, on, eventOn) -> (door?, kind?, reason)   the next door this player may open now, or why not
--   mark(state, door, kind, now)        records an open (call before paying)
--   view(state, now, on, eventOn) -> View   for the client's board, display only

local Types = require(script.Parent.Types)

local Advent = {}

Advent.FLAG = "adventCalendar"
Advent.EVENT_FLAG = "christmasEvent"
Advent.YEAR = 2026
Advent.DOORS = 24
Advent.DAY_SECONDS = 86400
Advent.FIRST_OPEN = 1796155200 -- 2026-12-01 20:00:00 UTC
Advent.DEC_2 = 1796169600 -- 2026-12-02 00:00:00 UTC
Advent.CLOSES = 1799020800 -- 2027-01-04 00:00:00 UTC (doors open until Jan 3 23:59:59)
Advent.CATCH_UP_PER_DAY = 2
Advent.EVENT = "advent_door" -- value the door; fields on_time or catch_up, device, account age bucket
-- advent_board report's values, each once a session: card (the calendar's card opened), board (the Town Square
-- board's prompt opened it)
Advent.BOARD_OUTCOMES = table.freeze({ "card", "board" }) :: { string }
Advent.SOURCE = "advent" -- the calendar cats' CatDef.source
Advent.REASON = "advent_calendar" -- Payout's sku

export type State = { year: number, opened: number, day: number, caught: number }
export type Door = { n: number, prize: Types.IndexPrize?, cat: string? }
export type Kind = "on_time" | "catch_up"
export type Reason = "ok" | "off" | "not_yet" | "closed" | "done" | "tomorrow"
export type View = {
	live: boolean, -- the board shows
	opened: number,
	due: number, -- doors open by the dates
	ready: boolean, -- a tap opens a door now (the chip's dot)
	reason: string,
}

-- Section 5 of the spec. Snowflakes are the Christmas event's currency (IndexPrize.snowflakes). "highest_golden" is
-- the golden crate of the player's newest area (Prizes.crateFor).
local DOORS: { Door } = {
	{ n = 1, prize = { snowflakes = 100, spins = 3 } },
	{ n = 2, prize = { fish = 150 } },
	{ n = 3, prize = { potions = { lucky_potion = 2 } } },
	{ n = 4, prize = { coinSeconds = 3600 } },
	{ n = 5, prize = { crates = { highest_golden = 2 } } },
	{ n = 6, cat = "peppermint_swirl" },
	{ n = 7, prize = { snowflakes = 150 } },
	{ n = 8, prize = { fish = 250 } },
	{ n = 9, prize = { traitTokens = 5 } },
	{ n = 10, prize = { spins = 10 } },
	{ n = 11, prize = { crates = { highest_golden = 3 } } },
	{ n = 12, cat = "nutcracker" },
	{ n = 13, prize = { fish = 400, snowflakes = 150 } },
	{ n = 14, prize = { coinSeconds = 7200 } },
	{ n = 15, prize = { potions = { lucky_potion = 2, swift_potion = 2 } } },
	{ n = 16, prize = { traitTokens = 10 } },
	{ n = 17, prize = { crates = { highest_golden = 4 } } },
	{ n = 18, cat = "northern_lights" },
	{ n = 19, prize = { fish = 500 } },
	{ n = 20, prize = { spins = 15, snowflakes = 200 } },
	{ n = 21, prize = { coinSeconds = 14400 } },
	{ n = 22, prize = { traitTokens = 15 } },
	{ n = 23, prize = { crates = { highest_golden = 5 }, fish = 500 } },
	{ n = 24, cat = "silent_night", prize = { fish = 1000 } },
}
for _, door in DOORS do
	if door.prize ~= nil then
		table.freeze(door.prize :: any)
	end
	table.freeze(door)
end
table.freeze(DOORS)
Advent.DOOR_LIST = DOORS

-- The four calendar cats, by id
local CATS: { [string]: boolean } = {}
for _, door in DOORS do
	if door.cat ~= nil then
		CATS[door.cat :: string] = true
	end
end
table.freeze(CATS)
Advent.CATS = CATS

function Advent.isCat(catId: string): boolean
	return CATS[catId] == true
end

function Advent.door(n: number): Door?
	return DOORS[n]
end

function Advent.doorAt(n: number): number
	if n <= 1 then
		return Advent.FIRST_OPEN
	end
	return Advent.DEC_2 + (n - 2) * Advent.DAY_SECONDS
end

function Advent.due(now: number): number
	if now < Advent.FIRST_OPEN or now >= Advent.CLOSES then
		return 0
	end
	local count = 0
	for n = 1, Advent.DOORS do
		if Advent.doorAt(n) <= now then
			count = n
		end
	end
	return count
end

function Advent.live(on: boolean, eventOn: boolean, now: number): boolean
	return on and eventOn and Advent.due(now) > 0
end

local function whole(raw: unknown, low: number, high: number): number
	if type(raw) == "number" and raw == raw and raw > -math.huge and raw < math.huge then
		return math.clamp(math.floor(raw), low, high)
	end
	return low
end

-- This year's calendar from a save's field (nil, junk or another year's: a fresh one).
function Advent.fresh(raw: unknown): State
	if type(raw) ~= "table" or (raw :: any).year ~= Advent.YEAR then
		return { year = Advent.YEAR, opened = 0, day = 0, caught = 0 }
	end
	return {
		year = Advent.YEAR,
		opened = whole((raw :: any).opened, 0, Advent.DOORS),
		day = whole((raw :: any).day, 0, 1000000),
		caught = whole((raw :: any).caught, 0, Advent.DOORS),
	}
end

-- A save's field made safe, or nil (ProfileSchema).
function Advent.sanitize(raw: unknown): State?
	if type(raw) ~= "table" then
		return nil
	end
	return Advent.fresh(raw)
end

function Advent.check(
	state: State,
	now: number,
	on: boolean,
	eventOn: boolean
): (number?, Kind?, Reason)
	if not on or not eventOn then
		return nil, nil, "off"
	end
	if now >= Advent.CLOSES then
		return nil, nil, "closed"
	end
	local due = Advent.due(now)
	if due == 0 then
		return nil, nil, "not_yet"
	end
	local opened = if state.year == Advent.YEAR then state.opened else 0
	if opened >= Advent.DOORS then
		return nil, nil, "done"
	end
	local door = opened + 1
	if door > due then
		return nil, nil, "tomorrow"
	end
	-- today's door is the newest one open, and only while the doors still open daily (Dec 1 to 24)
	local today = now // Advent.DAY_SECONDS
	if door == due and today == Advent.doorAt(due) // Advent.DAY_SECONDS then
		return door, "on_time" :: Kind, "ok" :: Reason
	end
	local used = if state.year == Advent.YEAR and state.day == today then state.caught else 0
	if used >= Advent.CATCH_UP_PER_DAY then
		return nil, nil, "tomorrow"
	end
	return door, "catch_up" :: Kind, "ok" :: Reason
end

function Advent.mark(state: State, door: number, kind: Kind, now: number)
	if state.year ~= Advent.YEAR then
		state.year = Advent.YEAR
		state.caught = 0
		state.day = 0
	end
	state.opened = math.max(state.opened, door)
	if kind == "catch_up" then
		local today = now // Advent.DAY_SECONDS
		if state.day ~= today then
			state.day = today
			state.caught = 0
		end
		state.caught += 1
	end
end

function Advent.view(state: State, now: number, on: boolean, eventOn: boolean): View
	local door, _, reason = Advent.check(state, now, on, eventOn)
	return {
		live = Advent.live(on, eventOn, now),
		opened = if state.year == Advent.YEAR then state.opened else 0,
		due = if on and eventOn then Advent.due(now) else 0,
		ready = door ~= nil,
		reason = reason,
	}
end

return Advent
