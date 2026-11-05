--!strict
-- Idea credits (#1083, idea-credits.md): the Thank You board's rows, pure. A credit is written by the lead's
-- idea-credits.yml (never by the game) into the IdeaCredits_v1 DataStore under a CREDIT_PREFIX key, only for an idea
-- report the player ticked "Feature my name". The game reads them, looks each player's display name up and shows the
-- newest first: our words for the idea, the version it shipped in and "Idea from <display name>". A player who turned
-- "Show my name on the Thank You board" off (a HIDE_PREFIX key, mirrored from profile.hideCredit) or whose name could
-- not be looked up shows as ANON. Nothing here ever shows a username or a user id.

local IdeaCredits = {}

IdeaCredits.STORE = "IdeaCredits_v1"
IdeaCredits.CREDIT_PREFIX = "credit/" -- credit/<report key>: { userId, idea, version, addedAt }
IdeaCredits.HIDE_PREFIX = "hide/" -- hide/<userId>: true while that player keeps their name off the board
IdeaCredits.REFRESH_SECONDS = 1800 -- the board is rebuilt at server start and this often
IdeaCredits.MAX_ROWS = 60 -- the newest this many credits; the board pages through them 12 at a time
IdeaCredits.IDEA_BYTES = 48
IdeaCredits.ANON = "a player"

-- creditId (#1216, idea-credits.md 7d): the credit's short id, c1, c2 and so on, which a WhatsNew row links by
export type Credit = {
	userId: number,
	idea: string,
	version: number,
	addedAt: number,
	creditId: string?,
}
export type Row = { idea: string, version: number, name: string, creditId: string? }

IdeaCredits.CREDIT_ID_BYTES = 12

local function whole(x: unknown, min: number, max: number): number?
	if type(x) ~= "number" or x ~= x or x < min or x > max then
		return nil
	end
	return math.floor(x)
end

-- A stored credit made safe to show, or nil when it is not one: a positive user id, an idea of 1 to IDEA_BYTES
-- bytes (cut at a whole character), a version and when it was added.
function IdeaCredits.sanitize(raw: unknown): Credit?
	if type(raw) ~= "table" then
		return nil
	end
	local value = raw :: any
	local userId = whole(value.userId, 1, 2 ^ 53)
	local version = whole(value.version, 0, 2 ^ 31)
	local addedAt = whole(value.addedAt, 0, 2 ^ 40)
	local idea = value.idea
	if userId == nil or version == nil or addedAt == nil or type(idea) ~= "string" then
		return nil
	end
	if utf8.len(idea) == nil then
		return nil
	end
	idea = string.gsub(idea, "%c", " ")
	-- trimmed in linear time, as BugReport trims (a long run of spaces must not backtrack)
	local first = string.find(idea, "%S")
	idea = if first ~= nil
		then string.sub(idea, first, string.find(idea, "%S%s*$") :: number)
		else ""
	if #idea > IdeaCredits.IDEA_BYTES then
		local cut = IdeaCredits.IDEA_BYTES
		while cut > 0 and utf8.len(string.sub(idea, 1, cut)) == nil do
			cut -= 1
		end
		idea = string.sub(idea, 1, cut)
	end
	if #idea == 0 then
		return nil
	end
	-- #1216: kept only as c followed by digits, so a WhatsNew row can link it; anything else is dropped
	local rawId = value.creditId
	local creditId = if type(rawId) == "string"
			and #rawId <= IdeaCredits.CREDIT_ID_BYTES
			and string.match(rawId, "^c%d+$") ~= nil
		then rawId
		else nil
	return {
		userId = userId,
		idea = idea,
		version = version,
		addedAt = addedAt,
		creditId = creditId,
	}
end

-- The board's rows, newest first and at most MAX_ROWS: each credit's idea and version with the player's display name
-- from `names`, or ANON when the player is in `hidden` or has no name there (a failed lookup).
function IdeaCredits.rows(
	credits: { Credit },
	names: { [number]: string },
	hidden: { [number]: boolean }
): { Row }
	local sorted = table.clone(credits)
	table.sort(sorted, function(a: Credit, b: Credit): boolean
		if a.addedAt ~= b.addedAt then
			return a.addedAt > b.addedAt
		end
		return a.idea < b.idea
	end)
	local rows: { Row } = {}
	for _, credit in sorted do
		if #rows >= IdeaCredits.MAX_ROWS then
			break
		end
		local name = names[credit.userId]
		local shown = if hidden[credit.userId]
				or name == nil
				or name == ""
			then IdeaCredits.ANON
			else name
		table.insert(
			rows,
			{
				idea = credit.idea,
				version = credit.version,
				name = shown,
				creditId = credit.creditId,
			}
		)
	end
	return rows
end

-- Whether `userId` has any credit (the Settings row "Show my name on the Thank You board" shows only then).
function IdeaCredits.has(credits: { Credit }, userId: number): boolean
	for _, credit in credits do
		if credit.userId == userId then
			return true
		end
	end
	return false
end

return IdeaCredits
