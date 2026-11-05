--!strict
-- The Thank You board's words and paging (#1083, idea-credits.md section 3), kept pure for the cloud tests.
--
--   creditLine(row)          "v190 · Idea from MochiPie", or "v190 · Idea from a player" for a hidden name
--   page(rows, page)         the cards on one page: { rows, page, pages }, the page clamped into range
--   EMPTY                    the line on a board with no credits yet

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
