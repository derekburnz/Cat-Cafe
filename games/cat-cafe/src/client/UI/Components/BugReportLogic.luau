--!strict
-- The Report a bug window's rules (docs/playtests/bug-reports.md section 1, QA 2026-10-27, for the friends alpha):
-- the box's 500-byte cap and its "123 / 500" counter, when Send lights up, the three kinds, the client error lines
-- that ride along and which toasts answer a report. Pure, so the cloud spec runner can load it. Every rule comes
-- from Shared.BugReport, the module the server checks ReportBug with (#265), so the window can never offer what
-- the server would refuse (review N151, QA 2026-10-27).
--
-- Lengths are bytes, as the server counts them. A letter is one byte; an emoji is four.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BugReport = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BugReport"))

local BugReportLogic = {}

export type Kind = { id: string, label: string, icon: string }

BugReportLogic.MAX_BYTES = BugReport.MaxBytes
BugReportLogic.ERROR_LINES = BugReport.MaxErrors

-- each kind's chip; a kind the server adds later shows its id until it gets one
local LOOKS: { [string]: { label: string, icon: string } } = {
	bug = { label = "Bug", icon = "🐞" },
	stuck = { label = "Stuck", icon = "🧱" },
	idea = { label = "Idea", icon = "💡" },
}

-- the chips, left to right in the server's order; the first is the default
BugReportLogic.KINDS = {} :: { Kind }
for _, id in BugReport.Kinds do
	local look = LOOKS[id]
	table.insert(BugReportLogic.KINDS, {
		id = id,
		label = if look then look.label else id,
		icon = if look then look.icon else "📝",
	})
end

-- At most maxBytes bytes, never ending in half a letter.
function BugReportLogic.cut(text: string, maxBytes: number): string
	return BugReport.cut(text, maxBytes)
end

-- What the server would keep of the box's text (control characters out, newlines kept, trimmed), or nil when it
-- would answer "Write a few words about what happened". Send sends this.
function BugReportLogic.text(raw: string): string?
	return BugReport.text(raw)
end

function BugReportLogic.canSend(raw: string): boolean
	return BugReport.text(raw) ~= nil
end

function BugReportLogic.counter(text: string): string
	return ("%d / %d"):format(#text, BugReportLogic.MAX_BYTES)
end

-- A chip's id, or "bug" for anything else (the server's rule).
function BugReportLogic.kindOf(id: string?): string
	return BugReport.kind(id)
end

-- Adds an error line to `lines` as the server would keep it (cleaned, cut to 200 bytes), keeping only the newest
-- 3. A line the server would drop is skipped.
function BugReportLogic.pushError(lines: { string }, line: string)
	local kept = BugReport.errorLine(line)
	if kept == nil then
		return
	end
	table.insert(lines, kept)
	while #lines > BugReport.MaxErrors do
		table.remove(lines, 1)
	end
end

-- What a toast says about a report waiting on the server: true for the server's "Thanks!", false for one of its
-- refusals, nil for any other toast (a shove or a Tip Jar refusal in that second must not touch the report).
function BugReportLogic.answer(text: string): boolean?
	local messages = BugReport.Messages
	if text == messages.sent then
		return true
	elseif text == messages.failed or text == messages.short or text == messages.limited then
		return false
	end
	return nil
end

return BugReportLogic
