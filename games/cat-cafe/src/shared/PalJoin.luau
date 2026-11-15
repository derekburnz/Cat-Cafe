--!strict
-- #3995 (Design-Agent's friend-join-3995.md, from Growth-Agent's issue): a player who joins through a friend
-- (PalService.joinedVia: an invite, or Roblox's Join button that follows them) stays with that friend. Behind the
-- `palJoin` switch (LiveFlags, off by default):
--   1. their cafe is the free plot whose door is nearest the friend's door (PalJoin.nearest), else the first free one;
--   2. the intro scene does not play itself this session, and the save stays out of the intro test (no introGroup);
--   3. Telemetry logs pal_join once (PalJoin.fields: how they were linked, new or returning, next door or not);
--   4. the joiner's Player gets the attribute PalNextDoor (true or false) for the UI's "Your cafe is next door." line.
-- Pure.

local PalJoin = {}

PalJoin.FLAG = "palJoin"
PalJoin.EVENT = "pal_join" -- Telemetry.custom, value 1
PalJoin.ATTRIBUTE = "PalNextDoor" -- on the joiner's Player: whether their cafe is next to the friend's
-- A plot counts as next door when its door is at most this far from the friend's door, in studs. Neighbouring plots
-- on one side of the street are 52 studs apart door to door (PlotWidth 44 + PlotRowGap 8) and the plot across the
-- street is nearer still, so this takes the plots beside and opposite and not the ones past them (104 studs).
PalJoin.NEXT_DOOR_STUDS = 90

export type Spot = { index: number, x: number, z: number }

-- The index of the spot in `free` nearest (x, z), or nil when `free` is empty. Ties go to the lower index, so two
-- servers place the same way.
function PalJoin.nearest(free: { Spot }, x: number, z: number): number?
	local best: number? = nil
	local bestDist = math.huge
	for _, spot in free do
		local dx, dz = spot.x - x, spot.z - z
		local dist = dx * dx + dz * dz
		if dist < bestDist or (dist == bestDist and best ~= nil and spot.index < best) then
			best, bestDist = spot.index, dist
		end
	end
	return best
end

-- Whether two doors at (ax, az) and (bx, bz) are next door.
function PalJoin.nextDoor(ax: number, az: number, bx: number, bz: number): boolean
	local dx, dz = ax - bx, az - bz
	return dx * dx + dz * dz <= PalJoin.NEXT_DOOR_STUDS * PalJoin.NEXT_DOOR_STUDS
end

-- pal_join's fields: the link ("invite" or "follow"), "new" or "returning", next door "yes" or "no".
function PalJoin.fields(how: string, isNew: boolean, nextDoor: boolean): { string }
	return {
		if how == "invite" then "invite" else "follow",
		if isNew then "new" else "returning",
		if nextDoor then "yes" else "no",
	}
end

return PalJoin
