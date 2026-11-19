--!strict
-- Derek 2026-11-18 10:00 UTC ("make it load the whole area people are in on tablet at least probably all devices ...
-- in longer maps it should load the whole map"). With streaming on (#4788) a device only holds what is within
-- StreamingTargetRadius (384 studs) of its character, so the far end of a long area (the Park, the Castle, the Snowy
-- Mountain) pops in late. With the areaWhole switch on, the server keeps the area a player stands in (or flies to)
-- whole on that player's device: one area at a time, so a phone never holds two. Off (the default) the areas stream
-- as before. Services/AreaWholeService does the work. Pure.
--
-- Sync's test of the first build (2026-11-18 10:33 UTC): making the whole area Model PersistentPerPlayer sent it in
-- one client frame (303 to 741 ms, 7.7k to 11.5k instances) and stalled the server as long. So the area's Set and
-- Backdrop are cut into chunks by ground cell (CELL studs), each its own PersistentPerPlayer Model, and a device gets
-- them a few at a time (at most BUDGET instances every SPREAD seconds), nearest to where they will stand first, and
-- loses a let-go area's chunks the same way. The first build also kept the last area held on the street for good, so
-- the Alleyway stayed whole all session: now an area is let go RELEASE_AFTER seconds after they left it for the
-- street or a cafe. A chunk is cut by each piece's bounding-box middle, as a kit set's pieces all pivot at its centre.
--
-- Roblox terms: a PersistentPerPlayer model is Persistent (sent whole, never streamed out) for the players added with
-- Model:AddPersistentPlayer and Atomic (sent whole, but streams as usual) for everyone else. A Default model is only
-- a group: its parts stream one by one.

local AreaWhole = {}

AreaWhole.FLAG = "areaWhole" -- shared/LiveFlags, off by default
-- #5381 (Derek 2026-11-19: "it might be better to just have them render all areas they have unlocked that way it
-- doesn't need to spike each time they visit them"): with areaWhole on too, every area a player has unlocked loads
-- onto their device once, the one they are in (or flying to) first, the rest after, and nothing is let go again.
AreaWhole.KEPT_FLAG = "areasKept" -- shared/LiveFlags, off by default
-- Sync 2026-11-19 (Tier 10, all areas): areasKept held about 4x the parts of areaWhole alone (88k against 21k) and
-- about +300 MB, too much for a low-memory phone. With areasKeptBig on, only a PC or console keeps every area; a
-- phone, a tablet and a device not reported yet keep one area whole, as areaWhole alone does.
AreaWhole.KEPT_BIG_FLAG = "areasKeptBig" -- shared/LiveFlags, off by default
AreaWhole.KEPT_DEVICES = { pc = true, console = true } :: { [string]: boolean }
-- Derek 2026-11-19 ("phone and tablet might also need to load all unlocked to stop spikes"): with areasKeptRecent on
-- too, a device areasKeptBig leaves out keeps its KEPT_RECENT most recent areas instead of one, so a trip back to
-- the area it just left (the usual back and forth) never loads it again. The oldest comes off when one more is added.
AreaWhole.RECENT_FLAG = "areasKeptRecent" -- shared/LiveFlags, off by default
AreaWhole.KEPT_RECENT = 2
AreaWhole.STEP = 1 -- seconds between the service's checks of where each player stands
-- A cannon flight's destination is held this long at most (the longest flight is about 6 s), so a flight cut short
-- (a respawn, a leave) never pins an area.
AreaWhole.FLIGHT_HOLD = 20
AreaWhole.RELEASE_AFTER = 30 -- seconds on the street or in a cafe before the area they left is let go
AreaWhole.CELL = 128 -- studs: the side of a chunk's ground cell
-- At most this many instances are added for one player every SPREAD seconds (always at least one chunk). Sync's
-- measure is about 65 microseconds of client apply per instance, so 400 is about 26 ms, and a big area comes in
-- over about two seconds: a cannon flight lands at 2.2 s.
AreaWhole.BUDGET = 400
AreaWhole.SPREAD = 0.15 -- seconds; NightSpread's step, far enough apart to land in different network sends
-- Sync's round 4: fed every SPREAD, a flight got too little of its area before the 2.2 s teleport, and the streaming
-- radius round the landed character pulled the rest in one frame (Atomic chunks). On a flight the feed runs every
-- FLIGHT_SPREAD seconds instead (a few frames apart, each step about 26 ms), so most of the area is in by touchdown.
AreaWhole.FLIGHT_SPREAD = 0.05
AreaWhole.CHUNK = "Chunk" -- the name of the Models AreaWholeService cuts a Set or Backdrop into

export type Flight = { area: string, untilAt: number }

-- The streaming mode for an area's chunks with the switch on or off.
function AreaWhole.mode(on: boolean): Enum.ModelStreamingMode
	return if on
		then Enum.ModelStreamingMode.PersistentPerPlayer
		else Enum.ModelStreamingMode.Default
end

-- The ground cell a piece at `position` belongs to, as a key.
function AreaWhole.cell(position: Vector3, size: number?): string
	local side = size or AreaWhole.CELL
	return string.format("%d,%d", math.floor(position.X / side), math.floor(position.Z / side))
end

-- The area a player's device should hold whole, and whether the flight still stands: a flight under way (`flight`,
-- not past its untilAt at `now`) holds its destination until the player stands in it. A camp cannon launches from
-- inside its own area and the arc crosses others, so standing in any other area never ends the flight early. With
-- no flight, where they stand; out of every area (the street, a cafe) the one they held, until they have been out
-- RELEASE_AFTER seconds (`outSince` is when they left it). nil until they have been in one.
function AreaWhole.pick(
	flight: Flight?,
	now: number,
	standingIn: string?,
	held: string?,
	outSince: number?
): (string?, boolean)
	if flight ~= nil and now < flight.untilAt then
		return flight.area, standingIn ~= flight.area
	end
	if standingIn ~= nil then
		return standingIn, false
	end
	if held ~= nil and outSince ~= nil and now - outSince < AreaWhole.RELEASE_AFTER then
		return held, false
	end
	return nil, false
end

-- How many of the waiting chunks (their instance counts in order, `sizes`) go in one SPREAD step: as many as fit
-- in `budget`, and at least one while any wait unless `atLeastOne` is false (what is left of a step's budget after
-- the adds, for the chunks coming off).
function AreaWhole.take(sizes: { number }, budget: number?, atLeastOne: boolean?): number
	local limit = budget or AreaWhole.BUDGET
	local floor = if atLeastOne == false then 0 else 1
	local count, total = 0, 0
	for _, size in sizes do
		if count >= floor and total + size > limit then
			break
		end
		count += 1
		total += size
	end
	return count
end

-- Whether a device keeps every unlocked area (areasKept): any device, or with `bigOnly` (areasKeptBig) only a PC or
-- console. `device` is what the client reported (Telemetry.device), nil before it has.
function AreaWhole.keptFor(device: string?, bigOnly: boolean): boolean
	if not bigOnly then
		return true
	end
	return device ~= nil and AreaWhole.KEPT_DEVICES[device] == true
end

-- How many areas a device keeps with areasKept on: nil for every unlocked area, a count for only that many of the
-- most recent (areasKeptRecent), 0 for none (areaWhole's one-area hold).
function AreaWhole.keptLimit(device: string?, bigOnly: boolean, recentOn: boolean): number?
	if AreaWhole.keptFor(device, bigOnly) then
		return nil
	end
	return if recentOn then AreaWhole.KEPT_RECENT else 0
end

-- `list` (most recent first) with `areaId` moved to the front, cut to `limit`, and the areas cut off it, oldest last.
function AreaWhole.recent(list: { string }, areaId: string, limit: number): ({ string }, { string })
	local out: { string } = { areaId }
	for _, id in list do
		if id ~= areaId then
			table.insert(out, id)
		end
	end
	local gone: { string } = {}
	while #out > math.max(1, limit) do
		table.insert(gone, table.remove(out) :: string)
	end
	return out, gone
end

return AreaWhole
