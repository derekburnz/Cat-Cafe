--!strict
-- Owner test mode (#1770, Monetization-Agent's policy): lets the game's owner test passes and products in the live game
-- without spending Robux. Only the server decides who is an owner (Config.OwnerTestUserIds, by user id); the client
-- reads the player attribute ATTRIBUTE, set by OwnerTestService, to show LABEL to that player and to send OwnerGrant
-- in place of Roblox's purchase prompt. A grant writes no receipt record and pays through the normal grant path, and
-- everything a product holds is untradeable (`tradeableIn` lists anything that is not; OwnerTest.spec keeps it empty).

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local OwnerTest = {}

OwnerTest.ATTRIBUTE = "OwnerTest"
OwnerTest.LABEL = "Owner test mode"
OwnerTest.SKU_PREFIX = "owner_test_" -- Payout's sku for a grant, kept apart from "product_" sales

-- Whether `userId` is in owner test mode. Server only decides with it.
function OwnerTest.isOwner(userId: unknown): boolean
	if type(userId) ~= "number" or userId <= 0 then
		return false
	end
	return table.find(Config.OwnerTestUserIds, userId) ~= nil
end

-- What `product` gives that a trade could move: its cats that are not exclusive. Sign styles and potions never
-- trade, and the Cafe Pass's paid track pays only what CafePass's own rewards give.
function OwnerTest.tradeableIn(product: Types.ProductDef): { string }
	local out: { string } = {}
	local cats: { string } = product.prize.cats or {}
	for _, catId in cats do
		local def = Catalog.getCat(catId)
		if def == nil or def.exclusive ~= true then
			table.insert(out, catId)
		end
	end
	return out
end

-- #2754: whether a chat line is the owner's `/event` test command ("/event" alone or "/event ..."), any case. Read by
-- both chat paths in OwnerTestService.
function OwnerTest.isEventCommand(text: unknown): boolean
	if type(text) ~= "string" then
		return false
	end
	local lower = string.lower(text)
	return lower == "/event" or string.sub(lower, 1, 7) == "/event "
end

-- #3212 (Derek2 2026-11-11: "I want to run it in a live game with a command from owner mode ... like /event 10 for
-- 10 min evfent", then "add a command to /shout "msg" across all servers so I can tell people in all servers
-- things"). Both run from a live public server for an owner only; OwnerTestService checks the user id.
--   isShoutCommand(text), isCommand(text)   the chat line is `/shout ...`, or either command
--   eventAsk(text) -> EventAsk              `/event 10` is the full party for 10 minutes, `/event <preset> <minutes>`
--                                           keeps the presets (EVENT_MINUTES with none), `/event stop` ends it
--   shoutText(text) -> string?              the message of a `/shout` line: one pair of quotes off, one line, at
--                                           most SHOUT_MAX characters; nil for none
--   shoutReady(lastAt, now) -> boolean      one shout every SHOUT_GAP_SECONDS a server
--   shoutMessage / eventMessage / parseMessage   what goes over MessagingService topic TOPIC to the other servers:
--                                           a shout's filtered text, or "the schedule changed, read it now"
OwnerTest.TOPIC = "CatCafeOwner"
OwnerTest.EVENT_MINUTES = 10
OwnerTest.SHOUT_MAX = 120
OwnerTest.SHOUT_GAP_SECONDS = 20
OwnerTest.SHOUT_PREFIX = "📣 "

function OwnerTest.isShoutCommand(text: unknown): boolean
	if type(text) ~= "string" then
		return false
	end
	local lower = string.lower(text)
	return lower == "/shout" or string.sub(lower, 1, 7) == "/shout "
end

function OwnerTest.isCommand(text: unknown): boolean
	return OwnerTest.isEventCommand(text) or OwnerTest.isShoutCommand(text)
end

export type EventAsk = { stop: boolean, preset: string, minutes: number }

function OwnerTest.eventAsk(text: string): EventAsk
	local words: { string } = {}
	for word in string.gmatch(string.lower(text), "%S+") do
		table.insert(words, word)
	end
	local second, third = words[2] or "", words[3] or ""
	if second == "stop" then
		return { stop = true, preset = "stop", minutes = 0 }
	end
	local function minutesOf(word: string): number?
		local value = tonumber(word)
		return if value ~= nil and value == value then value else nil
	end
	local alone = minutesOf(second)
	if alone ~= nil then
		return { stop = false, preset = "full", minutes = alone } -- "/event 10"
	end
	return {
		stop = false,
		preset = second, -- "" for a bare /event: no such preset, so the reply lists them
		minutes = minutesOf(third) or OwnerTest.EVENT_MINUTES,
	}
end

local QUOTES: { { string } } =
	{ { '"', '"' }, { "'", "'" }, { utf8.char(0x201C), utf8.char(0x201D) } }

function OwnerTest.shoutText(text: string): string?
	if not OwnerTest.isShoutCommand(text) then
		return nil
	end
	local body = string.sub(text, 7)
	body = string.gsub(body, "%c+", " ")
	body = string.gsub(body, "%s+", " ")
	body = string.match(body, "^%s*(.-)%s*$") or ""
	for _, pair in QUOTES do
		local open, close = pair[1], pair[2]
		if
			#body >= #open + #close
			and string.sub(body, 1, #open) == open
			and string.sub(body, -#close) == close
		then
			body = string.sub(body, #open + 1, -#close - 1)
			body = string.match(body, "^%s*(.-)%s*$") or ""
			break
		end
	end
	local length = utf8.len(body)
	if body == "" or length == nil then
		return nil
	end
	if length > OwnerTest.SHOUT_MAX then
		local cut = utf8.offset(body, OwnerTest.SHOUT_MAX + 1)
		body = if cut ~= nil then string.sub(body, 1, cut - 1) else body
	end
	return body
end

function OwnerTest.shoutReady(lastAt: number?, now: number): boolean
	return lastAt == nil or now - lastAt >= OwnerTest.SHOUT_GAP_SECONDS
end

export type Message = { k: string, t: string?, j: string } -- the kind, a shout's text, the sender's JobId

function OwnerTest.shoutMessage(text: string, jobId: string): Message
	return { k = "shout", t = text, j = jobId }
end

function OwnerTest.eventMessage(jobId: string): Message
	return { k = "event", j = jobId }
end

-- The kind ("shout" or "event") and a shout's text in a MessagingService message's Data, or nil for anything else, for
-- this server's own message (`ownJobId`), or for a shout with no text or more than SHOUT_MAX characters.
function OwnerTest.parseMessage(data: unknown, ownJobId: string): (string?, string?)
	if type(data) ~= "table" then
		return nil, nil
	end
	local message = data :: { [string]: unknown }
	local kind, text, job = message.k, message.t, message.j
	if type(job) ~= "string" or job == ownJobId then
		return nil, nil
	end
	if kind == "event" then
		return "event", nil
	end
	if kind ~= "shout" or type(text) ~= "string" or text == "" then
		return nil, nil
	end
	local length = utf8.len(text)
	if length == nil or length > OwnerTest.SHOUT_MAX then
		return nil, nil
	end
	return "shout", text
end

-- #2754: whether a command from `userId` with `text` at `now` repeats `last` (the one answered before) within
-- `window` seconds, so a line two chat paths both deliver is answered once.
function OwnerTest.isRepeat(
	last: { userId: number, text: string, at: number }?,
	userId: number,
	text: string,
	now: number,
	window: number
): boolean
	return last ~= nil and last.userId == userId and last.text == text and now - last.at < window
end

return OwnerTest
