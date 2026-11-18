--!strict
-- The Thank You board's words and paging (#1083, idea-credits.md section 3), kept pure for the cloud tests.
--
--   creditLine(row)          "v190 · Idea from MochiPie", or "v190 · Idea from a player" for a hidden name
--   page(rows, page)         the cards on one page: { rows, page, pages }, the page clamped into range
--   EMPTY                    the line on a board with no credits yet
--   whatsNew(updates, rows)  the What's new panel's lines (#1216): { glyph, text, date, credit? } from shared/WhatsNew
--                            rows, each linked credit named from the board's rows by creditId
--   nextUpdate(list, now)    the panel's NEXT row from Config.UpdateEvents: { text, when } for the first update not
--                            started yet, nil when none is left or one went out under QUIET_SECONDS ago

local ThanksBoardLogic = {}

ThanksBoardLogic.PER_PAGE = 4 -- #5228: two by two at the bigger size (was 6)
ThanksBoardLogic.ANON = "a player" -- IdeaCredits.ANON: the server's name for a hidden or unknown player
ThanksBoardLogic.EMPTY = "Send an idea with 💡 Feedback: if we build it, your name goes here."

export type Row = {
	idea: string,
	version: number?,
	name: string?,
	creditId: string?,
	supporter: boolean?,
}
export type Page = { rows: { Row }, page: number, pages: number }

function ThanksBoardLogic.creditLine(row: Row): string
	local name = row.name
	local who = if type(name) == "string" and name ~= "" then name else ThanksBoardLogic.ANON
	-- #1168 row 4: a gold heart by a Thank You Badge buyer's name, never on "a player"
	if row.supporter == true and who ~= ThanksBoardLogic.ANON then
		who ..= " 💛"
	end
	local version = row.version
	if type(version) == "number" and version > 0 then
		return ("v%d · Idea from %s"):format(math.floor(version), who)
	end
	return "Idea from " .. who
end

-- the icon kinds of idea-credits.md section 7b, as glyphs (IconArt draws a clean picture where one exists)
ThanksBoardLogic.ICONS = table.freeze({
	new = "✨",
	cat = "🐱",
	look = "🎨",
	faster = "⚡",
	fix = "🔧",
} :: { [string]: string })

export type Update = {
	id: string,
	date: string,
	icon: string,
	text: string,
	creditId: string?,
	thanks: string?,
}
export type Line = { id: string, glyph: string, text: string, date: string, credit: string? }

local MONTHS =
	{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local function shortDate(date: string): string
	local month, day = string.match(date, "^%d%d%d%d%-(%d%d)%-(%d%d)$")
	local m, d = tonumber(month), tonumber(day)
	if m == nil or d == nil or MONTHS[m] == nil then
		return ""
	end
	return ("%s %d"):format(MONTHS[m], d)
end

-- Section 7a: "💡 Idea from MochiPie" under an update from a player's idea, "💡 A player's idea" when the name is
-- hidden, unknown or the credit is not on the board. Derek2 11-07: "💡 Thanks to bgdevila" under an update a named
-- playtester's report or suggestion led to (WhatsNew's `thanks`).
function ThanksBoardLogic.whatsNew(updates: { Update }, rows: { Row }?): { Line }
	local names: { [string]: string } = {}
	local board: { Row } = rows or {}
	for _, row in board do
		local id = row.creditId
		if type(id) == "string" and type(row.name) == "string" then
			names[id] = row.name
		end
	end
	local out: { Line } = {}
	for _, update in updates do
		local credit: string? = nil
		local id = update.creditId
		if type(id) == "string" then
			local name = names[id]
			credit = if name
					and name ~= ""
					and name ~= ThanksBoardLogic.ANON
				then "💡 Idea from " .. name
				else "💡 A player's idea"
		elseif type(update.thanks) == "string" and update.thanks ~= "" then
			credit = "💡 Thanks to " .. update.thanks
		end
		table.insert(out, {
			id = update.id,
			glyph = ThanksBoardLogic.ICONS[update.icon] or ThanksBoardLogic.ICONS.new,
			text = update.text,
			date = shortDate(update.date),
			credit = credit,
		})
	end
	return out
end

function ThanksBoardLogic.page(rows: { Row }, page: number): Page
	local per = ThanksBoardLogic.PER_PAGE
	local pages = math.max(1, math.ceil(#rows / per))
	local at = math.clamp(math.floor(page), 1, pages)
	local out: { Row } = {}
	for index = (at - 1) * per + 1, math.min(#rows, at * per) do
		table.insert(out, rows[index])
	end
	return { rows = out, page = at, pages = pages }
end

-- Derek 2026-11-14 16:23 UTC (every update teases the next one, from 10 minutes after one goes out until the next
-- begins; Growth 2026-11-15): the What's new panel's NEXT row. It reads Config.UpdateEvents, the list the in-game
-- Notify Me ask reads, so it moves on to the next update by itself.
ThanksBoardLogic.QUIET_SECONDS = 600 -- EventRsvp.QUIET_AFTER_SECONDS
ThanksBoardLogic.ET_OFFSET = -5 * 3600 -- Eastern Standard Time (no daylight saving from 2026-11-01 to 2027-03-14)
ThanksBoardLogic.NEXT_CALL = "tap Notify Me for a reminder"

local DAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }

export type NextUpdate = { text: string, when: string }

-- "Sunday 3 PM ET", "Monday 10:30 PM ET"
function ThanksBoardLogic.etTime(at: number): string
	local t = os.date("!*t", at + ThanksBoardLogic.ET_OFFSET) :: any
	local hour: number = t.hour
	local minute: number = t.min
	local wday: number = t.wday
	local twelve = if hour % 12 == 0 then 12 else hour % 12
	local clock = if minute == 0 then tostring(twelve) else ("%d:%02d"):format(twelve, minute)
	return ("%s %s %s ET"):format(DAYS[wday], clock, if hour >= 12 then "PM" else "AM")
end

-- an entry's short name: its `name`, else the words between ": " and "!" of its ask ("🔔 Next update Sunday: 3 NEW
-- WORLDS! Want a reminder ...?" gives "3 NEW WORLDS"), a leading "the " dropped and the first letter raised
function ThanksBoardLogic.updateName(entry: any): string
	local name: string? = if type(entry.name) == "string" and entry.name ~= ""
		then entry.name
		else nil
	if name == nil and type(entry.title) == "string" then
		name = string.match(entry.title, ":%s*([^!?]+)[!?]")
	end
	if name == nil or name == "" then
		return "A new update"
	end
	local words: string = name
	words = string.gsub(words, "^%s*[Tt]he%s+", "")
	words = string.gsub(words, "%s+$", "")
	return string.upper(string.sub(words, 1, 1)) .. string.sub(words, 2)
end

function ThanksBoardLogic.nextUpdate(list: unknown, now: number): NextUpdate?
	if type(list) ~= "table" then
		return nil
	end
	local soonest: any = nil
	for _, entry in list :: { any } do
		if type(entry) == "table" and type(entry.startsAt) == "number" then
			if now >= entry.startsAt and now < entry.startsAt + ThanksBoardLogic.QUIET_SECONDS then
				return nil -- an update just went out: its own moment first
			end
			if now < entry.startsAt and (soonest == nil or entry.startsAt < soonest.startsAt) then
				soonest = entry
			end
		end
	end
	if soonest == nil then
		return nil
	end
	return {
		text = "Next: " .. ThanksBoardLogic.updateName(soonest),
		when = ThanksBoardLogic.etTime(soonest.startsAt) .. " · " .. ThanksBoardLogic.NEXT_CALL,
	}
end

return ThanksBoardLogic
