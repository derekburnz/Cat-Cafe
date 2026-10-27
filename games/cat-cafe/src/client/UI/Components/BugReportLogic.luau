--!strict
-- The Report a bug window's rules (docs/playtests/bug-reports.md section 1, QA 2026-10-27, for the friends alpha):
-- the box's 500-byte cap and its "123 / 500" counter, when Send lights up, the three kinds, and the client error
-- lines that ride along. Pure, so the cloud spec runner can load it. The server checks every one of these again
-- (section 2); this only keeps the window from offering what the server would refuse.
--
-- Lengths are bytes, as the server counts them, so the counter can never show room the server would refuse. A
-- letter is one byte; an emoji is four.

local BugReportLogic = {}

export type Kind = { id: string, label: string, icon: string }

BugReportLogic.MAX_BYTES = 500
BugReportLogic.MIN_BYTES = 3 -- after trimming
BugReportLogic.ERROR_LINES = 3
BugReportLogic.ERROR_BYTES = 200

-- the chips, left to right; the first is the default
BugReportLogic.KINDS = {
	{ id = "bug", label = "Bug", icon = "🐞" },
	{ id = "stuck", label = "Stuck", icon = "🧱" },
	{ id = "idea", label = "Idea", icon = "💡" },
} :: { Kind }

-- At most maxBytes bytes of valid UTF-8: a cut through a letter of several bytes drops that letter, and so does
-- anything from the first broken byte on.
function BugReportLogic.cut(text: string, maxBytes: number): string
	local cut = string.sub(text, 1, maxBytes)
	local length, bad = utf8.len(cut)
	if length == nil and bad then
		cut = string.sub(cut, 1, bad - 1)
	end
	return cut
end

function BugReportLogic.trim(text: string): string
	return string.match(text, "^%s*(.-)%s*$") or ""
end

-- Send lights up for at least 3 bytes after trimming (the server's "Write a few words" refusal otherwise).
function BugReportLogic.canSend(text: string): boolean
	local trimmed = BugReportLogic.trim(text)
	return #trimmed >= BugReportLogic.MIN_BYTES
		and #trimmed <= BugReportLogic.MAX_BYTES
		and utf8.len(trimmed) ~= nil
end

function BugReportLogic.counter(text: string): string
	return ("%d / %d"):format(#text, BugReportLogic.MAX_BYTES)
end

-- A chip's id, or "bug" for anything else (the server does the same).
function BugReportLogic.kindOf(id: string?): string
	for _, kind in BugReportLogic.KINDS do
		if kind.id == id then
			return kind.id
		end
	end
	return BugReportLogic.KINDS[1].id
end

-- Adds an error line to `lines`, cut to 200 bytes, keeping only the newest 3.
function BugReportLogic.pushError(lines: { string }, line: string)
	table.insert(lines, BugReportLogic.cut(line, BugReportLogic.ERROR_BYTES))
	while #lines > BugReportLogic.ERROR_LINES do
		table.remove(lines, 1)
	end
end

return BugReportLogic
