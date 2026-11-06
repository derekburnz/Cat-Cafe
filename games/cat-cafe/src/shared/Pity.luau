--!strict
-- #1572 (luck-and-rare-moments.md 1h): the global pity cat's clock and pick, pure. `t` is seconds since
-- Config.ClockEpoch, as in shared/Clock (a client: Workspace:GetServerTimeNow() - Config.ClockEpoch), so every
-- server and client counts the same slots with no shared store.
-- - Slot n (n >= 1) is due at n * PityLegendarySeconds. Every PityMythicalEvery-th slot is a Mythical one, the rest
--   Legendary. A slot due at night spawns at the next sunrise (`spawnAt`), and its cat stays until night (`live`).
-- - `pick(n)` is the slot's area (PityAreaWeights over Catalog.areas, so the higher areas come up more, the
--   Alleyway still possible) and a cat of that rarity from that area (Catching.pickCat), the same in every server.
-- - PityService spawns it in every server, claims `claimKey(n)` in MemoryStore on the first catch anywhere and tells
--   the other servers on MessagingService topic TOPIC, whose copies puff away. The stray carries ATTRIBUTE (its kind,
--   for the gold beam) and SLOT_ATTRIBUTE. ReplicatedStorage[FOLDER] carries the state for the Town Square sign and
--   the day clock's card: Slot, Kind, Area and State ("out", "caught" or "" when none is out), and Winner.

local Catalog = require(script.Parent.Catalog)
local Catching = require(script.Parent.Catching)
local Clock = require(script.Parent.Clock)
local Config = require(script.Parent.Config)

local Pity = {}

export type Kind = "Legendary" | "Mythical"
export type State = "out" | "caught" | ""
export type Pick = {
	slot: number,
	kind: Kind,
	areaId: string,
	catId: string,
}

Pity.ATTRIBUTE = "PityCat"
Pity.SLOT_ATTRIBUTE = "PitySlot"
Pity.FOLDER = "Pity"
Pity.TOPIC = "Pity"

-- The last slot due at or before t; 0 before the first.
function Pity.slot(t: number): number
	return math.max(0, math.floor(t / Config.PityLegendarySeconds))
end

-- When slot `slot` is due (seconds since ClockEpoch).
function Pity.dueAt(slot: number): number
	return math.floor(slot) * Config.PityLegendarySeconds
end

function Pity.kindOf(slot: number): Kind
	local kind: Kind = if math.floor(slot) % Config.PityMythicalEvery == 0
		then "Mythical"
		else "Legendary"
	return kind
end

-- When slot `slot`'s cat spawns: when it is due, or at the next sunrise if that falls at night.
function Pity.spawnAt(slot: number): number
	local due = Pity.dueAt(slot)
	local phase, left = Clock.phaseAt(due)
	return if phase == "night" then due + left else due
end

-- The next pity cat of `kind` (either kind when nil) to spawn after t: when, and its slot.
function Pity.nextAt(t: number, kind: Kind?): (number, number)
	local slot = math.max(1, Pity.slot(t))
	while Pity.spawnAt(slot) <= t or (kind ~= nil and Pity.kindOf(slot) ~= kind) do
		slot += 1
	end
	return Pity.spawnAt(slot), slot
end

-- The slot whose cat is out at t (spawned, and no night since), or nil.
function Pity.live(t: number): number?
	local slot = Pity.slot(t)
	if slot >= 1 and Pity.spawnAt(slot) > t then
		slot -= 1 -- due at night: not out until sunrise
	end
	if slot < 1 then
		return nil
	end
	local phase = Clock.phaseAt(t)
	if phase ~= "day" or Clock.nightSecondsBetween(Pity.spawnAt(slot), t) > 0 then
		return nil
	end
	return slot
end

-- A number in [0, 1) for `slot` and `salt`, the same everywhere: the Park-Miller fold of Clock's day rolls with one
-- more round, so slots in a row spread evenly over the area weights (QA 3).
local MODULUS = 2147483647
local MULTIPLIER = 48271
local SALT_AREA = 0x70697479 -- "pity"
local SALT_CAT = 0x63617473 -- "cats"

local function roll(slot: number, salt: number): number
	local hash = (salt + math.floor(slot) % MODULUS) % MODULUS
	for _ = 1, 4 do
		hash = (hash * MULTIPLIER) % MODULUS
		hash = bit32.bxor(hash, bit32.rshift(hash, 13))
	end
	hash = (hash * MULTIPLIER) % MODULUS
	return hash / MODULUS
end

-- The area a roll in [0, 1) lands on, by PityAreaWeights in Catalog.areas order (an area with no weight never).
function Pity.areaFor(r: number): string
	local total = 0
	for _, area in Catalog.areas do
		total += Config.PityAreaWeights[area.id] or 0
	end
	local point = math.clamp(r, 0, 1) * total
	local last = Catalog.areas[1].id
	for _, area in Catalog.areas do
		local weight = Config.PityAreaWeights[area.id] or 0
		if weight > 0 then
			last = area.id
			if point < weight then
				return area.id
			end
			point -= weight
		end
	end
	return last
end

-- Slot `slot`'s pity cat: its kind, area and cat.
function Pity.pick(slot: number): Pick
	local kind: Kind = if Pity.kindOf(slot) == "Mythical" then "Mythical" else "Legendary"
	local areaId = Pity.areaFor(roll(slot, SALT_AREA))
	local def = Catching.pickCat(kind, areaId, roll(slot, SALT_CAT))
	return { slot = math.floor(slot), kind = kind, areaId = areaId, catId = def.id }
end

-- The MemoryStore key the first catch of slot `slot` claims.
function Pity.claimKey(slot: number): string
	return "pity:" .. tostring(math.floor(slot))
end

-- The spawn banner, "A Legendary pity cat appeared in the Woods!", with "(opens at Tier 4)" for a player whose tier
-- has not opened the area (`opensAtTier`), so it never points at a door they can't use.
function Pity.spawnText(kind: Kind, areaId: string, opensAtTier: number?): string
	local area = Catalog.getArea(areaId)
	local name = if area ~= nil then area.name else areaId
	local text = string.format("A %s pity cat appeared in the %s!", kind, name)
	if opensAtTier ~= nil then
		text ..= string.format(" (opens at Tier %d)", opensAtTier)
	end
	return text
end

function Pity.caughtText(winnerName: string): string
	return string.format("%s caught the pity cat!", winnerName)
end

-- A countdown for the sign: "12:30" under an hour, "1:42:10" from an hour.
function Pity.countdownText(seconds: number): string
	local left = math.max(0, math.ceil(seconds))
	local hours = left // 3600
	local minutes = (left % 3600) // 60
	local secs = left % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

return Pity
