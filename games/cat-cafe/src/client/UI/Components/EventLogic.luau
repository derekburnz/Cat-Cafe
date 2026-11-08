--!strict
-- Cafe Events on the UI (#2487; design: docs/design/cat-cafe/live-events.md section 3), pure so the cloud spec runner
-- checks it. EventService (#2486) puts the running event, or between events the next one, on ReplicatedStorage as
-- attributes (shared/CafeEvents.ATTRIBUTES): EventId ("" for none), EventTitle, EventStartsAt and EventEndsAt (unix
-- seconds, compared with Workspace:GetServerTimeNow), EventRunning and EventEffects (JSON:
-- {"days":["lucky",...],"money":2,"luck":0.5,"showers":{"count":8,"gapSeconds":900,"firstAfter":600},
-- "reward":{"cosmeticId":"Decor_PartyBunting"}}).
--   read(get, decode) -> View?        the attributes as a View; get reads one attribute, decode parses the JSON
--   follow(seen, view, now)           what this client has watched: (Seen?, started) where started is true the first
--                                     time it sees an event running (the start banner)
--   chip(view, seen, now)             the HUD line under the day clock: ({ string }?, kind) where kind is "soon"
--                                     ("⏳ Cafe Party in 2:59" from T-3h), "running" (gold, "⏳ Cafe Party · ends in
--                                     1:59:40" and "next shower 9:12" on a second line) or "ended" ("Cafe Party ended
--                                     early")
--   banner(view, endsAt)              "Cafe Party! x2 cafe earnings and rare cat showers until 17:00"
--   board(view, seen, now, at)        the Town Square board's heading, its second line and the effect lines
--   lines(effects)                    one line per effect: "x2 cafe earnings", "8 rare cat showers", "Lucky, Golden
--                                     and Rainbow Day", "+0.5 Luck", "Free Party Bunting"
--   nextShower(view, now) -> number?  seconds to the next shower cat while the event runs
--   clock(seconds)                    "1:59:40", "9:12"; short(seconds) "2:59" (h:mm) from an hour, else "m:ss"
-- `at(unix, pattern)` is os.date on the client (the player's local time); the spec passes its own. The words stay calm
-- (section 6): no passes, no stacks past the event's own numbers, no buying.

local EventLogic = {}

EventLogic.ICON = "⏳"
EventLogic.COUNTDOWN_SECONDS = 10800 -- Config.EventCountdownSeconds: the chip and the board count down from T-3h
EventLogic.AFTER_SECONDS = 3600 -- the board thanks players for an hour after an event this client watched
EventLogic.EARLY_SLACK = 30 -- an end more than this before EventEndsAt is an early end
EventLogic.IDLE = "Watch this board for the next party!"
EventLogic.ATTRIBUTES = {
	id = "EventId",
	title = "EventTitle",
	startsAt = "EventStartsAt",
	endsAt = "EventEndsAt",
	effects = "EventEffects",
	running = "EventRunning",
}

local DAY_NAMES: { [string]: string } = { lucky = "Lucky", golden = "Golden", rainbow = "Rainbow" }
local DAY_ORDER = { "lucky", "golden", "rainbow" }
local TITLE_MAX = 24

export type Showers = { count: number, gapSeconds: number, firstAfter: number }
export type Effects = {
	days: { string }, -- in DAY_ORDER
	money: number, -- 1 when none
	luck: number, -- 0 when none
	showers: Showers?,
	reward: string?, -- the cosmetic id
}
export type View = {
	id: string,
	title: string,
	startsAt: number,
	endsAt: number,
	running: boolean,
	effects: Effects,
}
export type Seen = {
	id: string,
	title: string,
	endsAt: number,
	endedAt: number?,
	early: boolean,
}
export type ChipKind = "soon" | "running" | "ended"
export type Board = {
	heading: string,
	sub: string?,
	lines: { string },
	kind: "soon" | "running" | "after" | "idle",
}

local function finite(value: unknown): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

-- 2 -> "2", 1.5 -> "1.5", 0.25 -> "0.25"
local function number(value: number): string
	if value == math.floor(value) then
		return tostring(math.floor(value))
	end
	return (string.format("%.2f", value):gsub("0+$", ""))
end

local function effects(raw: unknown): Effects
	local out: Effects = { days = {}, money = 1, luck = 0, showers = nil, reward = nil }
	if type(raw) ~= "table" then
		return out
	end
	local data = raw :: { [string]: any }
	if type(data.days) == "table" then
		local has: { [string]: boolean } = {}
		for _, kind in data.days do
			if type(kind) == "string" then
				has[kind] = true
			end
		end
		for _, kind in DAY_ORDER do
			if has[kind] then
				table.insert(out.days, kind)
			end
		end
	end
	local money = finite(data.money)
	if money ~= nil and money > 1 then
		out.money = money
	end
	local luck = finite(data.luck)
	if luck ~= nil and luck > 0 then
		out.luck = luck
	end
	local showers = data.showers
	if type(showers) == "table" then
		local count = finite(showers.count)
		local gap = finite(showers.gapSeconds)
		local first = finite(showers.firstAfter)
		if count ~= nil and count >= 1 then
			out.showers = {
				count = math.floor(count),
				gapSeconds = math.max(gap or 0, 0),
				firstAfter = math.max(first or 0, 0),
			}
		end
	end
	local reward = data.reward
	if
		type(reward) == "table"
		and type(reward.cosmeticId) == "string"
		and reward.cosmeticId ~= ""
	then
		out.reward = reward.cosmeticId
	elseif type(reward) == "string" and reward ~= "" then
		out.reward = reward
	end
	return out
end

function EventLogic.read(get: (name: string) -> any, decode: (json: string) -> any): View?
	local names = EventLogic.ATTRIBUTES
	local id = get(names.id)
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local startsAt = finite(get(names.startsAt))
	local endsAt = finite(get(names.endsAt))
	if startsAt == nil or endsAt == nil or endsAt <= startsAt then
		return nil
	end
	local title = get(names.title)
	if type(title) ~= "string" or title == "" then
		title = "Cafe Event"
	end
	local raw = get(names.effects)
	local data = if type(raw) == "string" and raw ~= "" then decode(raw) else nil
	return {
		id = id,
		title = string.sub(title :: string, 1, TITLE_MAX),
		startsAt = startsAt,
		endsAt = endsAt,
		running = get(names.running) == true,
		effects = effects(data),
	}
end

-- "Decor_PartyBunting" -> "Party Bunting"
function EventLogic.cosmeticName(id: string): string
	local name = id:match("^[^_]+_(.+)$") or id
	name = name:gsub("_", " ")
	name = name:gsub("(%l)(%u)", "%1 %2")
	return name
end

function EventLogic.dayLine(days: { string }): string?
	local names: { string } = {}
	for _, kind in days do
		local name = DAY_NAMES[kind]
		if name then
			table.insert(names, name)
		end
	end
	if #names == 0 then
		return nil
	end
	if #names == 1 then
		return names[1] .. " Day"
	end
	local last = table.remove(names) :: string
	return table.concat(names, ", ") .. " and " .. last .. " Day"
end

function EventLogic.lines(fx: Effects): { string }
	local out = {}
	if fx.money > 1 then
		table.insert(out, "x" .. number(fx.money) .. " cafe earnings")
	end
	local showers = fx.showers
	if showers ~= nil then
		table.insert(
			out,
			string.format(
				"%d rare cat shower%s",
				showers.count,
				if showers.count == 1 then "" else "s"
			)
		)
	end
	local days = EventLogic.dayLine(fx.days)
	if days then
		table.insert(out, days)
	end
	if fx.luck > 0 then
		table.insert(out, "+" .. number(fx.luck) .. " Luck")
	end
	if fx.reward ~= nil then
		table.insert(out, "Free " .. EventLogic.cosmeticName(fx.reward))
	end
	return out
end

-- 7180 -> "1:59:40", 552 -> "9:12"
function EventLogic.clock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

-- the chip's countdown: "2:59" (hours and minutes) from an hour out, then "59:59" (minutes and seconds)
function EventLogic.short(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	if total >= 3600 then
		return string.format("%d:%02d", total // 3600, (total % 3600) // 60)
	end
	return string.format("%d:%02d", total // 60, total % 60)
end

local function running(view: View?, now: number): boolean
	return view ~= nil and view.running and now < view.endsAt
end

function EventLogic.nextShower(view: View?, now: number): number?
	if view == nil or not running(view, now) then
		return nil
	end
	local showers = view.effects.showers
	if showers == nil then
		return nil
	end
	for index = 1, showers.count do
		local due = view.startsAt + showers.firstAfter + (index - 1) * showers.gapSeconds
		if due >= view.endsAt then
			return nil
		end
		if due > now then
			return due - now
		end
	end
	return nil
end

function EventLogic.follow(seen: Seen?, view: View?, now: number): (Seen?, boolean)
	if view ~= nil and running(view, now) then
		if seen == nil or seen.id ~= view.id or seen.endedAt ~= nil then
			return {
				id = view.id,
				title = view.title,
				endsAt = view.endsAt,
				endedAt = nil,
				early = false,
			},
				true
		end
		seen.endsAt = view.endsAt
		return seen, false
	end
	if seen == nil then
		return nil, false
	end
	local endedAt = seen.endedAt
	if endedAt == nil then
		seen.endedAt = now
		seen.early = now < seen.endsAt - EventLogic.EARLY_SLACK
		return seen, false
	end
	if now - endedAt > EventLogic.AFTER_SECONDS then
		return nil, false
	end
	return seen, false
end

function EventLogic.chip(view: View?, seen: Seen?, now: number): ({ string }?, ChipKind?)
	if view ~= nil and running(view, now) then
		local first = string.format(
			"%s %s · ends in %s",
			EventLogic.ICON,
			view.title,
			EventLogic.clock(view.endsAt - now)
		)
		local shower = EventLogic.nextShower(view, now)
		if shower ~= nil then
			return { first, "next shower " .. EventLogic.clock(shower) }, "running"
		end
		return { first }, "running"
	end
	if seen ~= nil and seen.endedAt ~= nil and seen.early and now < seen.endsAt then
		return { seen.title .. " ended early" }, "ended"
	end
	if view ~= nil and not view.running then
		local wait = view.startsAt - now
		if wait > 0 and wait <= EventLogic.COUNTDOWN_SECONDS then
			return {
				string.format("%s %s in %s", EventLogic.ICON, view.title, EventLogic.short(wait)),
			},
				"soon"
		end
	end
	return nil, nil
end

-- the start banner's headline: the event's two biggest effects
local function headline(fx: Effects): string?
	local parts = {}
	if fx.money > 1 then
		table.insert(parts, "x" .. number(fx.money) .. " cafe earnings")
	end
	if fx.showers ~= nil then
		table.insert(parts, "rare cat showers")
	end
	if #parts < 2 then
		local days = EventLogic.dayLine(fx.days)
		if days then
			table.insert(parts, days)
		end
	end
	if #parts < 2 and fx.luck > 0 then
		table.insert(parts, "+" .. number(fx.luck) .. " Luck")
	end
	if #parts == 0 then
		return nil
	end
	return table.concat(parts, " and ", 1, math.min(#parts, 2))
end

-- endsAt is the end time in the player's local time ("17:00")
function EventLogic.banner(view: View, endsAt: string): string
	local words = headline(view.effects)
	if words == nil then
		return string.format("%s! On until %s", view.title, endsAt)
	end
	return string.format("%s! %s until %s", view.title, words, endsAt)
end

function EventLogic.board(
	view: View?,
	seen: Seen?,
	now: number,
	at: (unix: number, pattern: string) -> string
): Board
	if view ~= nil and running(view, now) then
		return {
			heading = view.title .. "!",
			sub = string.format(
				"Ends at %s · %s left",
				at(view.endsAt, "%H:%M"),
				EventLogic.clock(view.endsAt - now)
			),
			lines = EventLogic.lines(view.effects),
			kind = "running",
		}
	end
	if seen ~= nil and seen.endedAt ~= nil then
		local again = if view ~= nil
				and not view.running
				and view.startsAt > now
			then "See you next " .. at(view.startsAt, "%A")
			else nil
		return { heading = "Thanks for coming!", sub = again, lines = {}, kind = "after" }
	end
	if view ~= nil and not view.running and view.startsAt > now then
		local wait = view.startsAt - now
		local window =
			string.format("%s to %s", at(view.startsAt, "%H:%M"), at(view.endsAt, "%H:%M"))
		if wait <= EventLogic.COUNTDOWN_SECONDS then
			return {
				heading = string.format("%s in %s", view.title, EventLogic.clock(wait)),
				sub = window,
				lines = EventLogic.lines(view.effects),
				kind = "soon",
			}
		end
		return {
			heading = "Next " .. view.title,
			sub = at(view.startsAt, "%A") .. " " .. window,
			lines = EventLogic.lines(view.effects),
			kind = "idle",
		}
	end
	return { heading = "Cafe Party", sub = EventLogic.IDLE, lines = {}, kind = "idle" }
end

return EventLogic
