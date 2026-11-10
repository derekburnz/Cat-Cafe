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
-- #1946 (1i): the fixed slots above are now only the fallback. Two timers restart with each pity cat: the next
-- Legendary is due PityLegendarySeconds after the last one spawned (#2003; it was after its catch or night), the next
-- Mythical PityMythicalSeconds after the last Mythical spawned. Each is a Timer (when due, and that kind's cat number `seq`) kept in
-- MemoryStore by PityService, which sets the folder's NextLegendary and NextMythical (when the next one spawns) and
-- LiveLegendary and LiveMythical (the area of the cat out now, or ""). The sign and the day card read those, and the
-- fixed slots only while the folder has none.
--   spawnTime(due)                when a timer due then spawns: then, or the next sunrise if that is at night
--   first(t, kind) / restart(t, kind, seq)   the timer a first boot starts, and the one after cat `seq` spawns at t
--   previous(timer, kind)         the timer of the cat before it (#2003), for a server that starts while it is out
--   keepStored(stored, endedSeq)  true when the stored timer has already moved past the cat that ended
--   fixedTimer(t, kind)           the 1h slot as a Timer (seq negative), while no stored timer is known
--   number(seq, kind)             the stray's SLOT_ATTRIBUTE: one number per cat across both kinds
--   timerLine(t, kind, at, live)  "Legendary cat in 12:30", "Legendary cat out now!", or "Legendary cat: any moment
--                                 now!" once a due time is OVERDUE_SECONDS past with no cat; never a negative time

local Catalog = require(script.Parent.Catalog)
local Catching = require(script.Parent.Catching)
local Clock = require(script.Parent.Clock)
local Config = require(script.Parent.Config)

local Pity = {}

export type Kind = "Legendary" | "Mythical"
export type State = "out" | "caught" | ""
export type Timer = {
	at: number, -- when due, seconds since ClockEpoch
	seq: number, -- that kind's cat number (1, 2, ...), negative for a fixed 1h slot
}
-- What the folder says about a kind: when its next cat spawns and whether one is out now.
export type Known = { at: number, live: boolean }
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
local KINDS: { Kind } = { "Legendary", "Mythical" }
table.freeze(KINDS)
Pity.KINDS = KINDS
Pity.NEXT_ATTRIBUTE =
	table.freeze({ Legendary = "NextLegendary", Mythical = "NextMythical" }) :: { [string]: string }
Pity.LIVE_ATTRIBUTE =
	table.freeze({ Legendary = "LiveLegendary", Mythical = "LiveMythical" }) :: { [string]: string }
Pity.OVERDUE_SECONDS = 60

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

-- When a cat due at `due` spawns: then, or at the next sunrise if that falls at night.
function Pity.spawnTime(due: number): number
	local phase, left = Clock.phaseAt(due)
	return if phase == "night" then due + left else due
end

-- When slot `slot`'s cat spawns: when it is due, or at the next sunrise if that falls at night.
function Pity.spawnAt(slot: number): number
	return Pity.spawnTime(Pity.dueAt(slot))
end

-- The next fixed slot of `kind` (either kind when nil) to spawn after t: when, and its slot.
local function fixedNextAt(t: number, kind: Kind?): (number, number)
	local slot = math.max(1, Pity.slot(t))
	while Pity.spawnAt(slot) <= t or (kind ~= nil and Pity.kindOf(slot) ~= kind) do
		slot += 1
	end
	return Pity.spawnAt(slot), slot
end

-- What ReplicatedStorage[FOLDER] says about `kind` (PityService's NextLegendary and LiveLegendary, and the
-- Mythical pair), or nil while it holds no timer for it.
function Pity.known(kind: Kind): Known?
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild(Pity.FOLDER)
	if folder == nil then
		return nil
	end
	local at = folder:GetAttribute(Pity.NEXT_ATTRIBUTE[kind])
	if type(at) ~= "number" then
		return nil
	end
	local live = folder:GetAttribute(Pity.LIVE_ATTRIBUTE[kind])
	return { at = at, live = type(live) == "string" and live ~= "" }
end

-- The next pity cat of `kind` (either kind when nil) to spawn after t: when, and its fixed slot (0 when the time
-- comes from the folder's restarting timers, 1i).
function Pity.nextAt(t: number, kind: Kind?): (number, number)
	if kind == nil then
		local legendary = Pity.known("Legendary")
		local mythical = Pity.known("Mythical")
		if legendary ~= nil and mythical ~= nil then
			return math.min(legendary.at, mythical.at), 0
		end
		return fixedNextAt(t, nil)
	end
	local known = Pity.known(kind)
	if known ~= nil then
		return known.at, 0
	end
	return fixedNextAt(t, kind)
end

function Pity.period(kind: Kind): number
	return if kind == "Mythical" then Config.PityMythicalSeconds else Config.PityLegendarySeconds
end

-- With no stored timers yet, the first server's boot at t starts both: 30 minutes and 2 hours.
function Pity.first(t: number, kind: Kind): Timer
	return { at = t + Pity.period(kind), seq = 1 }
end

-- The timer after `kind`'s cat number `endedSeq` spawned at t (#2003, Derek2 2026-11-07: "pity timers should
-- instantly restart after they spawned"; before, a catch or the night restarted it).
function Pity.restart(t: number, kind: Kind, endedSeq: number): Timer
	return { at = t + Pity.period(kind), seq = math.max(0, math.floor(endedSeq)) + 1 }
end

-- #2003: the timer of the cat before `timer` (it spawned at `timer.at` less a period), so a server that starts while
-- that cat is out still spawns its copy; nil for a first timer or a fixed slot.
function Pity.previous(timer: Timer, kind: Kind): Timer?
	if timer.seq <= 1 then
		return nil
	end
	return { at = timer.at - Pity.period(kind), seq = timer.seq - 1 }
end

-- A stored value read as a Timer, or nil.
function Pity.readTimer(raw: unknown): Timer?
	if type(raw) ~= "table" then
		return nil
	end
	local value = raw :: { [string]: unknown }
	local at, seq = value.at, value.seq
	if type(at) ~= "number" or type(seq) ~= "number" or at ~= at or seq < 1 or seq % 1 ~= 0 then
		return nil
	end
	return { at = at, seq = seq }
end

-- True when the stored timer has already moved past cat `endedSeq`, so a second server ending the same cat leaves
-- it as it is and the timer moves once.
function Pity.keepStored(stored: Timer?, endedSeq: number): boolean
	return stored ~= nil and stored.seq > endedSeq
end

-- The 1h fixed slot of `kind` as a Timer (its seq the slot, negative): the one out at t, else the next.
function Pity.fixedTimer(t: number, kind: Kind): Timer
	local live = Pity.live(t)
	if live ~= nil and Pity.kindOf(live) == kind then
		return { at = Pity.dueAt(live), seq = -live }
	end
	local _, slot = fixedNextAt(t, kind)
	return { at = Pity.dueAt(slot), seq = -slot }
end

-- The fixed slot of `kind` after fixed timer `timer`'s slot, as a Timer: what the sign counts down to once that
-- slot's cat has spawned here, so it never sits at 0:00 for the rest of the day.
function Pity.fixedNext(timer: Timer, kind: Kind): Timer
	local slot = math.max(1, -math.floor(timer.seq) + 1)
	while Pity.kindOf(slot) ~= kind do
		slot += 1
	end
	return { at = Pity.dueAt(slot), seq = -slot }
end

-- True while it is still the day something came out at `spawnedAt`: it is day at t and no night has come since. A
-- Cafe Event's shower cat is out this long, and so is the word that a pity cat was caught.
function Pity.sameDay(spawnedAt: number, t: number): boolean
	return t >= spawnedAt
		and (Clock.phaseAt(t)) == "day"
		and Clock.nightSecondsBetween(spawnedAt, t) <= 0
end

-- #3077 (Derek2 2026-11-10: "sometimes pity spawns right before night, make pity not cleared by one night before
-- disappearing"): the nights an uncaught pity cat waits through before it goes.
Pity.NIGHTS_KEPT = 1

-- True while an uncaught pity cat that spawned at `spawnedAt` is still out at t: through the rest of its day, the
-- whole night after it and the day after that; the second nightfall takes it. (Until #3077 the first nightfall did,
-- so a cat that came out a moment before dusk was gone before anyone reached it.)
function Pity.stillOut(spawnedAt: number, t: number): boolean
	return t >= spawnedAt
		and Clock.nightSecondsBetween(spawnedAt, t)
			<= Pity.NIGHTS_KEPT * Config.NightLengthSeconds
end

-- One number per cat across both kinds and the fixed slots (the stray's SLOT_ATTRIBUTE): Legendary cats even,
-- Mythical cats odd.
function Pity.number(seq: number, kind: Kind): number
	return math.floor(seq) * 2 + (if kind == "Mythical" then 1 else 0)
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

-- Slot `slot`'s pity cat: its kind, area and cat. With `kind` (1i), the restarting timer's cat number `slot` of
-- that kind instead, a Mythical rolled apart from the Legendary of the same number.
function Pity.pick(slot: number, kind: Kind?): Pick
	local picked: Kind = if kind ~= nil
		then kind
		elseif Pity.kindOf(slot) == "Mythical" then "Mythical"
		else "Legendary"
	local salt = if kind == "Mythical" then 1 else 0
	local areaId = Pity.areaFor(roll(slot, SALT_AREA + salt))
	local def = Catching.pickCat(picked, areaId, roll(slot, SALT_CAT + salt))
	return { slot = math.floor(slot), kind = picked, areaId = areaId, catId = def.id }
end

-- The cat a timer spawns: a fixed slot's own pick, or the restarting timer's.
function Pity.pickTimer(timer: Timer, kind: Kind): Pick
	return if timer.seq < 0 then Pity.pick(-timer.seq) else Pity.pick(timer.seq, kind)
end

-- The MemoryStore key the first catch of slot `slot` claims; with `kind`, of that kind's cat number `slot` (1i).
function Pity.claimKey(slot: number, kind: Kind?): string
	if kind ~= nil then
		return "pity:" .. kind .. ":" .. tostring(math.floor(slot))
	end
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

-- #2567: the catch banner in a server, from the winner's name when the catch was there, else nil: a pity cat caught
-- in another server shows no banner, name or chat line (its copy here still puffs away).
function Pity.caughtBanner(winnerName: string?): string?
	if winnerName == nil or winnerName == "" then
		return nil
	end
	return Pity.caughtText(winnerName)
end

-- #2567: the toast for a catch here that another server's catch beat (a pity or Cafe Event shower cat).
Pity.LOST_TEXT = "A player in another server caught it first, so it puffed out of your net."

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

-- One kind's countdown line at t: "Legendary cat in 12:30" to `at` (when it spawns), "Legendary cat out now!" while
-- one is out, and "Legendary cat: any moment now!" once `at` is OVERDUE_SECONDS past with none out (1i).
function Pity.timerLine(t: number, kind: Kind, at: number, live: boolean): string
	if live then
		return kind .. " cat out now!"
	end
	if t - at > Pity.OVERDUE_SECONDS then
		return kind .. " cat: any moment now!"
	end
	return kind .. " cat in " .. Pity.countdownText(at - t)
end

-- #1753: the Town Square sign's three lines at t (and the day clock card's first two): "Legendary cat in 12:30",
-- "Mythical cat in 1:42:10", and "Now in the Woods!" while a pity cat is out, "Caught by Sam" after its catch, else "".
-- `state`, `areaId` and `winner` are ReplicatedStorage[FOLDER]'s State, Area and Winner. The countdowns come from
-- the folder's timers (1i), or `known` when given, else the fixed slots.
function Pity.signLines(
	t: number,
	state: string?,
	areaId: string?,
	winner: string?,
	known: { [string]: Known }?
): { string }
	local function line(kind: Kind): string
		local timer = if known ~= nil then known[kind] else Pity.known(kind)
		if timer ~= nil then
			return Pity.timerLine(t, kind, timer.at, timer.live)
		end
		return Pity.timerLine(t, kind, (fixedNextAt(t, kind)), false)
	end
	local status = ""
	if state == "out" and type(areaId) == "string" and areaId ~= "" then
		local area = Catalog.getArea(areaId)
		status = string.format("Now in the %s!", if area ~= nil then area.name else areaId)
	elseif state == "caught" and type(winner) == "string" and winner ~= "" then
		status = "Caught by " .. winner
	end
	return { line("Legendary"), line("Mythical"), status }
end

return Pity
