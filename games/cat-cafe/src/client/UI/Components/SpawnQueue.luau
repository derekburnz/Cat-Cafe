--!strict
-- #4227 (Derek 2026-11-14, from a player's suggestion: when a lot spawns at once the spawn pop-ups stack and hide
-- behind each other): the spawn shout-outs ("A Mythical cat appeared in the Park!") wait in a line and show one at a
-- time for SHOW seconds. Two or more waiting of the same rarity in the same area merge into one ("2 Mythical cats are
-- out in the Park!"), one older than MAX_AGE is dropped (the cat may be gone) and at most CAP wait, the oldest going
-- first. Pure, so the specs load it; UI.announce feeds it and shows what take hands back.
--   isSpawn(text) -> boolean              a spawn line (the other shout-outs keep their own way)
--   new() -> Queue
--   push(queue, text, rarity, now)
--   take(queue, now) -> (text?, rarity?)   the next line to show, merged words for a merged one
--   waiting(queue, now) -> number          how many still wait after the one just taken
local SpawnQueue = {}

SpawnQueue.FLAG = "spawnQueue" -- on unless switched off: off, spawn lines show as they come, as before
SpawnQueue.SHOW = 4
SpawnQueue.MAX_AGE = 30
SpawnQueue.CAP = 6

export type Item = {
	text: string,
	rarity: string?,
	kind: string?, -- the rarity, or "Rainbow" for a rainbow stray's line
	key: string,
	area: string?,
	count: number,
	at: number,
}
export type Queue = { items: { Item } }

local SPAWN_WORDS = { " appeared in the ", " is somewhere in the ", " is out in the " }

function SpawnQueue.isSpawn(text: string): boolean
	for _, words in SPAWN_WORDS do
		if string.find(text, words, 1, true) ~= nil then
			return true
		end
	end
	return false
end

-- The area's name in a spawn line, or nil: what follows "in the " up to the "!", less " on a Lucky Day"
function SpawnQueue.area(text: string): string?
	local name = string.match(text, " in the (.-)!")
	if name == nil then
		return nil
	end
	name = string.gsub(name, " on a Lucky Day$", "")
	return if name ~= "" then name else nil
end

function SpawnQueue.new(): Queue
	return { items = {} }
end

local function drop(queue: Queue, now: number)
	for index = #queue.items, 1, -1 do
		if now - queue.items[index].at > SpawnQueue.MAX_AGE then
			table.remove(queue.items, index)
		end
	end
end

function SpawnQueue.push(queue: Queue, text: string, rarity: string?, now: number)
	drop(queue, now)
	local area = SpawnQueue.area(text)
	-- a rainbow stray's line names the cat, so rainbow ones merge among themselves ("2 Rainbow cats ...")
	local kind = if string.find(text, "A Rainbow ", 1, true) == 1 then "Rainbow" else rarity
	local key = if area ~= nil and kind ~= nil then kind .. "|" .. area else text
	for _, item in queue.items do
		if item.key == key then
			if area ~= nil and kind ~= nil then
				item.count += 1
				item.at = now
			end
			return -- the same words again (or one more of the same) never queue twice
		end
	end
	table.insert(
		queue.items,
		{ text = text, rarity = rarity, kind = kind, key = key, area = area, count = 1, at = now }
	)
	while #queue.items > SpawnQueue.CAP do
		table.remove(queue.items, 1)
	end
end

-- The words for an item: its own line, or for two or more "2 Mythical cats are out in the Park!" ("... are somewhere
-- in the Park!" for Secrets, which never say where)
function SpawnQueue.words(item: Item): string
	if item.count < 2 or item.area == nil or item.kind == nil then
		return item.text
	end
	if item.kind == "Secret" then
		return string.format("%d Secret cats are somewhere in the %s!", item.count, item.area)
	end
	return string.format("%d %s cats are out in the %s!", item.count, item.kind, item.area)
end

function SpawnQueue.take(queue: Queue, now: number): (string?, string?)
	drop(queue, now)
	local item = table.remove(queue.items, 1)
	if item == nil then
		return nil, nil
	end
	return SpawnQueue.words(item), item.rarity
end

function SpawnQueue.waiting(queue: Queue, now: number): number
	drop(queue, now)
	return #queue.items
end

return SpawnQueue
