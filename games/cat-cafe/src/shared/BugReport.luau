--!strict
-- In-game bug reports for the friends alpha (docs/playtests/bug-reports.md; Derek 2026-10-27: "and bug reports").
-- Pure: what the server keeps of a ReportBug call, and the DataStore key a report is saved under. Only the team
-- reads a report; nothing a tester types is ever shown to another player.

local BugReport = {}

BugReport.MinBytes = 3
BugReport.MaxBytes = 500
BugReport.MaxErrors = 3
BugReport.ErrorBytes = 200
BugReport.Kinds = { "bug", "stuck", "idea" }
BugReport.StoreName = "BugReports_v1"

-- The toasts the server answers with.
BugReport.Messages = {
	sent = "Thanks! Your report was sent.",
	failed = "Couldn't send that, try again in a minute",
	short = "Write a few words about what happened",
	limited = "You just sent one, try again in a moment",
}

-- Control characters out: a newline stays when `keepNewlines`, a tab (and a dropped newline) becomes a space.
local function clean(s: string, keepNewlines: boolean): string
	return (
		s:gsub("%c", function(c: string): string
			if c == "\n" and keepNewlines then
				return c
			elseif c == "\t" or c == "\n" then
				return " "
			end
			return ""
		end)
	)
end

-- Leading and trailing whitespace off, in linear time (a 10,000 byte string of spaces must not backtrack).
local function trim(s: string): string
	local first = s:find("%S")
	if first == nil then
		return ""
	end
	local last = s:find("%S%s*$") :: number -- each run of spaces is scanned once
	return s:sub(first, last)
end

-- `s` (valid UTF-8) cut to at most `bytes` bytes without splitting a character.
function BugReport.cut(s: string, bytes: number): string
	if #s <= bytes then
		return s
	end
	local start = utf8.offset(s, 0, bytes + 1) :: number -- the first byte of the character holding byte bytes + 1
	return s:sub(1, start - 1)
end

-- The report's text, or nil when it is not a UTF-8 string with at least MinBytes left once control characters are
-- out (newlines kept) and it is trimmed. Past MaxBytes it is cut on a character boundary rather than refused, so a
-- tester who wrote a lot keeps the start of it.
function BugReport.text(raw: unknown): string?
	if type(raw) ~= "string" then
		return nil
	end
	if utf8.len(raw) == nil then
		return nil
	end
	local text = trim(BugReport.cut(trim(clean(raw, true)), BugReport.MaxBytes))
	return if #text >= BugReport.MinBytes then text else nil
end

-- "bug", "stuck" or "idea"; anything else is "bug".
function BugReport.kind(raw: unknown): string
	if type(raw) == "string" and table.find(BugReport.Kinds, raw) ~= nil then
		return raw
	end
	return "bug"
end

-- One error line: control characters out (newlines become spaces), trimmed, cut to ErrorBytes. Nil when it is not
-- a UTF-8 string or nothing is left.
function BugReport.errorLine(raw: unknown): string?
	if type(raw) ~= "string" then
		return nil
	end
	if utf8.len(raw) == nil then
		return nil
	end
	local line = trim(BugReport.cut(trim(clean(raw, false)), BugReport.ErrorBytes))
	return if line ~= "" then line else nil
end

-- The client's last error lines: entries 1 to MaxErrors of a table, the bad ones dropped; anything that is not a
-- table gives none. Never a reason to refuse the report.
function BugReport.clientErrors(raw: unknown): { string }
	local lines: { string } = {}
	if type(raw) ~= "table" then
		return lines
	end
	local list = raw :: { [any]: unknown }
	for i = 1, BugReport.MaxErrors do
		local line = BugReport.errorLine(list[i])
		if line ~= nil then
			table.insert(lines, line)
		end
	end
	return lines
end

-- The UTC day of `at`, "20261027", which every key of that day starts with after "r_".
function BugReport.day(at: number): string
	return os.date("!%Y%m%d", at)
end

-- r_<YYYYMMDD UTC>_<os.time()>_<userId>: a day's reports list by prefix, oldest first.
function BugReport.key(at: number, userId: number): string
	return string.format("r_%s_%d_%d", BugReport.day(at), at, userId)
end

return BugReport
