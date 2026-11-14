--!strict
-- Admin events on the client (#4195), pure so the cloud spec runner checks it. EventService puts the admin event
-- that runs, or from two minutes before its start the one coming, on ReplicatedStorage as attributes
-- (shared/CafeEvents.ADMIN_ATTRIBUTES): AdminEventId ("" for none), AdminEventTitle, AdminEventStartsAt and
-- AdminEventEndsAt (unix seconds, compared with Workspace:GetServerTimeNow), AdminEventRunning and AdminEventEffects
-- (JSON: {"bowlSpeed":4}).
--   read(get, decode) -> View?          the attributes as a View; get reads one attribute, decode parses the JSON
--   follow(seen, view, now)             what this client has watched: (Seen?, "soon" | "start" | nil), each once an
--                                       event: "soon" the first time it sees one coming (the warning banner),
--                                       "start" the first time it sees it running (the wide start banner; also for
--                                       a player who joins while it runs)
--   effectLines(view)                   one calm line per effect: "Bait bowls lure cats 4x faster"
--   soonBanner(view, now)               Effects/EventBanner's "adminSoon" card: "Bowl Frenzy soon!", "Starts in 2:00"
--   startBanner(view, now)              its "admin" card: "Bowl Frenzy!", the effect, "Ends in 15:00"
--   chatLine(banner)                    the same words as one system chat line, in the cards' rose, rich text safe:
--                                       "⚡ Bowl Frenzy soon! Starts in 2:00. Bait bowls lure cats 4x faster."
--   stripLine(view, now)                the HUD's timer words: "⚡ Bowl Frenzy in 1:59", then "⚡ Bowl Frenzy 14:59"
--   merge(lines, kind, strip, admin)    the Cafe Event chip's lines, kind and strip with the admin line put first
--   clock(seconds)                      "14:59", "1:02:05"
-- The words sell nothing and count nothing down but the event's own start and end.

local AdminEventLogic = {}

export type View = {
	id: string,
	title: string,
	startsAt: number,
	endsAt: number,
	running: boolean,
	bowlSpeed: number, -- 1 for none
}
export type Seen = { id: string, warned: boolean, started: boolean }
export type Banner = { kind: string, title: string, lines: { string }, badge: string }

local function finite(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return value
end

function AdminEventLogic.read(get: (name: string) -> any, decode: (json: string) -> any): View?
	local id = get("AdminEventId")
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local title = get("AdminEventTitle")
	local startsAt, endsAt = finite(get("AdminEventStartsAt")), finite(get("AdminEventEndsAt"))
	if type(title) ~= "string" or title == "" or startsAt == nil or endsAt == nil then
		return nil
	end
	if endsAt <= startsAt then
		return nil
	end
	local effects: any = nil
	local json = get("AdminEventEffects")
	if type(json) == "string" and json ~= "" then
		local ok, value = pcall(decode, json)
		if ok and type(value) == "table" then
			effects = value
		end
	end
	local bowlSpeed = if effects ~= nil then finite(effects.bowlSpeed) else nil
	return {
		id = id,
		title = title,
		startsAt = startsAt,
		endsAt = endsAt,
		running = get("AdminEventRunning") == true,
		bowlSpeed = if bowlSpeed ~= nil and bowlSpeed > 1 then bowlSpeed else 1,
	}
end

-- Whether `view` runs at `now`: the server says so and its window holds on the shared clock.
function AdminEventLogic.runs(view: View?, now: number): boolean
	return view ~= nil and view.running and now < view.endsAt
end

function AdminEventLogic.follow(seen: Seen?, view: View?, now: number): (Seen?, string?)
	if view == nil or now >= view.endsAt then
		return nil, nil
	end
	local mine: Seen = if seen ~= nil and seen.id == view.id
		then seen
		else { id = view.id, warned = false, started = false }
	if AdminEventLogic.runs(view, now) then
		if mine.started then
			return mine, nil
		end
		return { id = view.id, warned = true, started = true }, "start"
	end
	if not mine.warned and not mine.started and now < view.startsAt then
		return { id = view.id, warned = true, started = false }, "soon"
	end
	return mine, nil
end

-- 899 -> "14:59", 3725 -> "1:02:05", never under "0:00"
function AdminEventLogic.clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	local hours = whole // 3600
	local minutes = whole % 3600 // 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, whole % 60)
	end
	return string.format("%d:%02d", minutes, whole % 60)
end

-- 4 -> "4", 1.5 -> "1.5"
local function times(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

function AdminEventLogic.effectLines(view: View): { string }
	local out: { string } = {}
	if view.bowlSpeed > 1 then
		table.insert(out, string.format("Bait bowls lure cats %sx faster", times(view.bowlSpeed)))
	end
	return out
end

-- The round badge's few characters: the event's biggest number, else "!".
function AdminEventLogic.badge(view: View): string
	if view.bowlSpeed > 1 then
		return times(view.bowlSpeed) .. "x"
	end
	return "!"
end

function AdminEventLogic.soonBanner(view: View, now: number): Banner
	local lines = { "Starts in " .. AdminEventLogic.clock(view.startsAt - now) }
	for _, line in AdminEventLogic.effectLines(view) do
		table.insert(lines, line)
	end
	return { kind = "adminSoon", title = view.title .. " soon!", lines = lines, badge = "!" }
end

function AdminEventLogic.startBanner(view: View, now: number): Banner
	local lines = AdminEventLogic.effectLines(view)
	table.insert(lines, "Ends in " .. AdminEventLogic.clock(view.endsAt - now))
	return {
		kind = "admin",
		title = view.title .. "!",
		lines = lines,
		badge = AdminEventLogic.badge(view),
	}
end

AdminEventLogic.CHAT_COLOUR = "#FF6B81" -- the cards' rose (Presets.palette.neonPink)

-- Rich text shows these three as themselves only when escaped; an event's title comes from the schedule.
local function plain(text: string): string
	local out = string.gsub(text, "&", "&amp;")
	out = string.gsub(out, "<", "&lt;")
	out = string.gsub(out, ">", "&gt;")
	return out
end

function AdminEventLogic.chatLine(banner: Banner): string
	local parts = { banner.title }
	for _, line in banner.lines do
		table.insert(parts, line .. ".")
	end
	return string.format(
		'<font color="%s"><b>⚡ %s</b></font>',
		AdminEventLogic.CHAT_COLOUR,
		plain(table.concat(parts, " "))
	)
end

function AdminEventLogic.stripLine(view: View?, now: number): string?
	if view == nil or now >= view.endsAt then
		return nil
	end
	if AdminEventLogic.runs(view, now) then
		return string.format("⚡ %s %s", view.title, AdminEventLogic.clock(view.endsAt - now))
	end
	if now < view.startsAt then
		return string.format("⚡ %s in %s", view.title, AdminEventLogic.clock(view.startsAt - now))
	end
	return nil -- the second between its start on the clock and the server saying it runs
end

-- The HUD's Cafe Event chip with the admin line first: the card's lines, its kind (gold while anything admin shows)
-- and the strip's two short lines (the admin one, then the Cafe Event's first).
function AdminEventLogic.merge(
	lines: { string }?,
	kind: string?,
	strip: { string }?,
	admin: string?
): ({ string }?, string?, { string }?)
	if admin == nil then
		return lines, kind, strip
	end
	local card = { admin }
	if lines ~= nil then
		for _, line in lines do
			table.insert(card, line)
		end
	end
	local short = { admin }
	local first = if strip ~= nil and strip[1] ~= nil
		then strip[1]
		elseif lines ~= nil then lines[1]
		else nil
	if first ~= nil then
		table.insert(short, first)
	end
	return card, "running", short
end

return AdminEventLogic
