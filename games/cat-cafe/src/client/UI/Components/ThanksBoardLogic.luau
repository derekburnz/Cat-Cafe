--!strict
-- The Thank You board's words and paging (#1083, idea-credits.md section 3), kept pure for the cloud tests.
--
--   creditLine(row)          "v190 · Idea from MochiPie", or "v190 · Idea from a player" for a hidden name
--   page(rows, page)         the cards on one page: { rows, page, pages }, the page clamped into range
--   EMPTY                    the line on a board with no credits yet
--   whatsNew(updates, rows)  the What's new panel's lines (#1216): { glyph, text, date, credit? } from shared/WhatsNew
--                            rows, each linked credit named from the board's rows by creditId

local ThanksBoardLogic = {}

ThanksBoardLogic.PER_PAGE = 6
ThanksBoardLogic.ANON = "a player" -- IdeaCredits.ANON: the server's name for a hidden or unknown player
ThanksBoardLogic.EMPTY =
	'Send an idea with 💡 Feedback and tick "Feature my name": if we build it, your name goes here.'

export type Row = { idea: string, version: number?, name: string?, creditId: string? }
export type Page = { rows: { Row }, page: number, pages: number }

function ThanksBoardLogic.creditLine(row: Row): string
	local name = row.name
	local who = if type(name) == "string" and name ~= "" then name else ThanksBoardLogic.ANON
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

export type Update = { id: string, date: string, icon: string, text: string, creditId: string? }
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
-- hidden, unknown or the credit is not on the board.
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

return ThanksBoardLogic
