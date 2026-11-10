--!strict
-- The rare-catch chat line (#2203, Dread via Derek2 2026-11-07: "a global caught rare cats message in chat"), pure.
-- Every catch shout-out (Catching.shoutOut: Legendary and up, or a gold or rainbow coat, #2205) also goes in the chat
-- of its own server, and on MessagingService topic TOPIC to every other server, where it shows as a chat line only
-- ("From another cafe: Sam caught a Legendary Maine Coon!"), no toast. server/Services/GlobalCatchService sends and
-- reads it; client/Controllers/RareCatchChatController writes the line. #2429: Legendary and Mythical crate pieces
-- too (crateLine).
--
-- Rate limits (a gate each): a server publishes at most one line every PUBLISH_GAP_SECONDS and shows at most one
-- line from other servers every SHOW_GAP_SECONDS; a Mythical always goes through both. MessagingService allows a
-- server 150 + 60 per player publishes a minute, so one every 5 s is far inside it.

local Catalog = require(script.Parent.Catalog)

local GlobalCatch = {}

GlobalCatch.TOPIC = "CatCafeRareCatch" -- not RestartNotice.TOPIC, which the Open Cloud countdown owns
GlobalCatch.MAX_TEXT = 120 -- longer text in a message is ignored
GlobalCatch.PUBLISH_GAP_SECONDS = 5
GlobalCatch.SHOW_GAP_SECONDS = 3
-- #3033 (Derek2 2026-11-10: "the chat works now but only server the global one doesn't work"): the chat window's
-- Global tab is Roblox's own cross-server chat between players (on for every game since May 2026), and a game has no
-- way to write a line into it, only the on/off switch in the Creator Dashboard. A system line always lands in the
-- Here tab. For a few hours the line from another server said "🌍 Global: " itself; #3116 (Derek2 2026-11-10: "the
-- leftovers globe from global chat attempt in the local server chat is still there so get rid of that") put the
-- wording from before the attempt back: no globe, no "Global".
GlobalCatch.ELSEWHERE = "From another cafe: "

-- The chat colour of each rarity, the hex of Catalog.rarities' swatches (the same as Effects' Presets.rarity).
GlobalCatch.COLORS = {
	Common = "#8E97B2",
	Rare = "#5FA8FF",
	Epic = "#C07CFF",
	Legendary = "#FFC94D",
	Mythical = "#FF5E7E",
} :: { [string]: string }

export type Message = { t: string, r: string, j: string } -- the text, the cat's rarity, the sender's JobId
export type Gate = { gap: number, last: number }

-- A gate that lets one line through every `gap` seconds.
function GlobalCatch.gate(gap: number): Gate
	return { gap = gap, last = -math.huge }
end

-- Whether a line of `rarity` may go through `gate` at `now` (any clock, in seconds); one that may is counted. A
-- Mythical always may, and counts too.
function GlobalCatch.take(gate: Gate, now: number, rarity: string): boolean
	if rarity ~= "Mythical" and now - gate.last < gate.gap then
		return false
	end
	gate.last = now
	return true
end

-- What a server publishes for a shout-out `text` of a `rarity` cat, from the server `jobId`.
function GlobalCatch.encode(text: string, rarity: string, jobId: string): Message
	return { t = text, r = rarity, j = jobId }
end

-- The text and rarity in a MessagingService message's Data, or nil when it is not a rare-catch line from another
-- server: a table with a string t of 1 to MAX_TEXT characters, a known rarity r and a JobId j that is not `ownJobId`.
function GlobalCatch.parse(data: unknown, ownJobId: string): (string?, string?)
	if type(data) ~= "table" then
		return nil, nil
	end
	local message = data :: { [string]: unknown }
	local text, rarity, job = message.t, message.r, message.j
	if type(text) ~= "string" or #text == 0 or #text > GlobalCatch.MAX_TEXT then
		return nil, nil
	end
	if type(rarity) ~= "string" or Catalog.rarityRank[rarity] == nil then
		return nil, nil
	end
	if type(job) ~= "string" or job == ownJobId then
		return nil, nil
	end
	return text, rarity
end

-- #2429 (Derek2 2026-11-08: "make rare pulls show up in global chat ... inside the actual chat"): a crate piece of
-- CRATE_FROM or rarer is a chat line too, as a rare catch is. The player's display name, the piece's rarity and name.
GlobalCatch.CRATE_FROM = "Legendary"

-- The chat text for `who` pulling a `rarity` piece called `piece` from a crate, or nil below CRATE_FROM.
function GlobalCatch.crateLine(who: string, rarity: string, piece: string): string?
	local rank, from = Catalog.rarityRank[rarity], Catalog.rarityRank[GlobalCatch.CRATE_FROM]
	if rank == nil or from == nil or rank < from then
		return nil
	end
	return string.format("%s pulled a %s %s from a crate!", who, rarity, piece)
end

-- `text` safe inside a rich text chat line: the five characters rich text reads are escaped.
function GlobalCatch.escape(text: string): string
	return (
		text:gsub("&", "&amp;")
			:gsub("<", "&lt;")
			:gsub(">", "&gt;")
			:gsub('"', "&quot;")
			:gsub("'", "&apos;")
	)
end

-- #2902: the line as plain text, for the legacy chat window, which shows rich text tags as they are; the client
-- colours it with Color3.fromHex(GlobalCatch.color(rarity)).
function GlobalCatch.plainLine(text: string, elsewhere: boolean): string
	return (if elsewhere then GlobalCatch.ELSEWHERE else "") .. text
end

-- The hex colour of a `rarity`'s chat line (Common's for an unknown one).
function GlobalCatch.color(rarity: string): string
	return GlobalCatch.COLORS[rarity] or GlobalCatch.COLORS.Common
end

-- The chat line for a shout-out `text` of a `rarity` cat, in the rarity's colour; `elsewhere` when it came from
-- another server.
function GlobalCatch.chatLine(text: string, rarity: string, elsewhere: boolean): string
	local color = GlobalCatch.COLORS[rarity] or GlobalCatch.COLORS.Common
	local body = (if elsewhere then GlobalCatch.ELSEWHERE else "") .. text
	return string.format('<font color="%s">%s</font>', color, GlobalCatch.escape(body))
end

return GlobalCatch
