--!strict
-- #3053 (Design-Agent's pick, 2026-11-12): the chat's own "Rare Cats" tab, pure. Every Mythical or better line of
-- the rare-catch chat (shared/GlobalCatch), from this server and from the others, also goes into a read-only chat
-- channel called NAME, which the chat window shows as its own tab beside General. General keeps exactly what it
-- shows today. Roblox's own Global tab is its cross-server chat between players and a game cannot write to it, so
-- this tab is the closest thing a game can build, and it is not called "Global" so the two are never confused.
-- The live switch FLAG starts off (LiveFlags.OFF_BY_DEFAULT): off, no channel is made and the chat has no tab bar.
--   wants(rarity)                  whether a line of that rarity goes in the tab (FROM or rarer)
--   line(text, rarity, elsewhere)  the tab's rich text line: "🌍 " first from another server, "⭐ " from this one
--   queue() / push / pop           at most one line every GAP_SECONDS and at most KEEP waiting: when more arrive the
--                                  oldest waiting ones are dropped, so nothing shows minutes late
-- server/Services/RareCatsTabService makes the channel; client/Controllers/RareCatchChatController writes the lines.

local Catalog = require(script.Parent.Catalog)
local GlobalCatch = require(script.Parent.GlobalCatch)

local RareCatsTab = {}

RareCatsTab.NAME = "Rare Cats" -- the channel's Name, which is the tab's label
RareCatsTab.FLAG = "rareCatsTab" -- the LiveFlags key
RareCatsTab.FROM = "Mythical"
RareCatsTab.GAP_SECONDS = 3
RareCatsTab.KEEP = 30
RareCatsTab.ELSEWHERE = "🌍 "
RareCatsTab.HERE = "⭐ "

export type Queue = { waiting: { string }, last: number }

function RareCatsTab.wants(rarity: string): boolean
	local rank, from = Catalog.rarityRank[rarity], Catalog.rarityRank[RareCatsTab.FROM]
	return rank ~= nil and from ~= nil and rank >= from
end

function RareCatsTab.line(text: string, rarity: string, elsewhere: boolean): string
	local body = (if elsewhere then RareCatsTab.ELSEWHERE else RareCatsTab.HERE) .. text
	return string.format(
		'<font color="%s">%s</font>',
		GlobalCatch.color(rarity),
		GlobalCatch.escape(body)
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
