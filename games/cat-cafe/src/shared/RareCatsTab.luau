--!strict
-- #3053 (Design-Agent's pick, 2026-11-12): the chat's own "Rare Cats" tab, pure. Every cat line of the rare-catch
-- chat (shared/GlobalCatch: Mythical or better, or a gold or rainbow coat from Legendary up; Derek 2026-11-12), from
-- this server and from the others, also goes into a read-only chat
-- channel called NAME, which the chat window shows as its own tab beside General. General keeps exactly what it
-- shows today. Roblox's own Global tab is its cross-server chat between players and a game cannot write to it, so
-- this tab is the closest thing a game can build, and it is not called "Global" so the two are never confused.
-- The live switch FLAG starts off (LiveFlags.OFF_BY_DEFAULT): off, no channel is made and the chat has no tab bar.
--   wants(rarity, text)            whether a line goes in the tab: FROM or rarer, or a gold or rainbow cat from
--                                  COAT_FROM up (a Legendary crate piece's line stays in General alone)
--   line(text, rarity, elsewhere)  the tab's rich text line: "🌍 " first from another server, "⭐ " from this one
--   queue() / push / pop           at most one line every GAP_SECONDS and at most KEEP waiting: when more arrive the
--                                  oldest waiting ones are dropped, so nothing shows minutes late
-- server/Services/RareCatsTabService makes the channel; client/Controllers/RareCatchChatController writes the lines.

local Catalog = require(script.Parent.Catalog)
local CoatWords = require(script.Parent.CoatWords)
local GlobalCatch = require(script.Parent.GlobalCatch)

local RareCatsTab = {}

-- #3673 (Derek 2026-11-12: "moving all the global messages to the global chat tab", with another game's own
-- "Global" tab with a globe as the example): the tab is called "🌍 Global" and takes every line of the rare-catch
-- chat while it is there; the Here tab then keeps only this server's lines (RareCatsTab.route).
RareCatsTab.NAME = "🌍 Global" -- the channel's Name, which is the tab's label
RareCatsTab.FLAG = "rareCatsTab" -- the LiveFlags key
RareCatsTab.FROM = "Mythical"
RareCatsTab.COAT_FROM = "Legendary" -- Catching.COAT_SHOUT_FROM: a gold or rainbow coat's line from here up
RareCatsTab.COATS = { " a gold ", " a rainbow " } -- how Catching.shoutOut words a coat
RareCatsTab.GAP_SECONDS = 3
RareCatsTab.KEEP = 30
RareCatsTab.ELSEWHERE = "🌍 "
RareCatsTab.HERE = "⭐ "

export type Queue = { waiting: { string }, last: number }

function RareCatsTab.wants(rarity: string, text: string?): boolean
	local rank, from = Catalog.rarityRank[rarity], Catalog.rarityRank[RareCatsTab.FROM]
	if rank == nil or from == nil then
		return false
	elseif rank >= from then
		return true
	end
	local coatFrom = Catalog.rarityRank[RareCatsTab.COAT_FROM]
	if text == nil or coatFrom == nil or rank < coatFrom then
		return false
	end
	for _, coat in RareCatsTab.COATS do
		if text:find(coat, 1, true) ~= nil then
			return true
		end
	end
	return false
end

-- #3673: where a line goes. `tab` is whether this player has the tab (the switch on, the channel made and the player
-- a reader of it). With the tab: every line goes in it, and one from another server goes nowhere else. Without it:
-- everything is in the normal chat, as before.
function RareCatsTab.route(tab: boolean, elsewhere: boolean): (boolean, boolean)
	if not tab then
		return false, true
	end
	return true, not elsewhere
end

function RareCatsTab.line(text: string, rarity: string, elsewhere: boolean): string
	local body = (if elsewhere then RareCatsTab.ELSEWHERE else RareCatsTab.HERE) .. text
	return string.format(
		'<font color="%s">%s</font>',
		GlobalCatch.color(rarity),
		(CoatWords.rich(body, GlobalCatch.escape)) -- #3692
	)
end

function RareCatsTab.queue(): Queue
	return { waiting = {}, last = -math.huge }
end

-- Adds a line to the end; past KEEP waiting, the oldest goes.
function RareCatsTab.push(queue: Queue, line: string)
	table.insert(queue.waiting, line)
	while #queue.waiting > RareCatsTab.KEEP do
		table.remove(queue.waiting, 1)
	end
end

-- The next line to show at `now` (any clock, in seconds), or nil while none waits or the last one was shown less
-- than GAP_SECONDS ago.
function RareCatsTab.pop(queue: Queue, now: number): string?
	if #queue.waiting == 0 or now - queue.last < RareCatsTab.GAP_SECONDS then
		return nil
	end
	queue.last = now
	return table.remove(queue.waiting, 1)
end

return RareCatsTab
