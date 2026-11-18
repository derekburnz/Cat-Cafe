--!strict
-- Derek 2026-11-18 10:00 UTC ("make it load the whole area people are in on tablet at least probably all devices ...
-- in longer maps it should load the whole map"). With streaming on (#4788) a device only holds what is within
-- StreamingTargetRadius (384 studs) of its character, so the far end of a long area (the Park, the Castle, the Snowy
-- Mountain) pops in late. With the areaWhole switch on, each catching area's Model turns PersistentPerPlayer, and the
-- server keeps it whole on the devices of the players standing in it (or flying to it): one area at a time, so a
-- phone never holds two. Off (the default) the areas stream as before. Services/AreaWholeService does the work. Pure.
--
-- Roblox terms: a PersistentPerPlayer model is Persistent (sent whole, never streamed out) for the players added with
-- Model:AddPersistentPlayer and streams as usual for everyone else.

local AreaWhole = {}

AreaWhole.FLAG = "areaWhole" -- shared/LiveFlags, off by default
AreaWhole.STEP = 1 -- seconds between the service's checks of where each player stands
-- A cannon flight's destination is held this long at most (the longest flight is about 6 s), so a flight cut short
-- (a respawn, a leave) never pins an area.
AreaWhole.FLIGHT_HOLD = 20

export type Flight = { area: string, untilAt: number }

-- The streaming mode for an area's Model with the switch on or off.
function AreaWhole.mode(on: boolean): Enum.ModelStreamingMode
	return if on
		then Enum.ModelStreamingMode.PersistentPerPlayer
		else Enum.ModelStreamingMode.Default
end

-- The area a player's device should hold whole, and whether the flight still stands: a flight under way (`flight`,
-- not past its untilAt at `now`) holds its destination until the player stands in it. A camp cannon launches from
-- inside its own area and the arc crosses others, so standing in any other area never ends the flight early. With
-- no flight, where they stand, else the one they held (the street and their cafe keep the last area, so a walk out
-- and back does not send it twice). nil until they have been in one.
function AreaWhole.pick(
	flight: Flight?,
	now: number,
	standingIn: string?,
	held: string?
): (string?, boolean)
	if flight ~= nil and now < flight.untilAt then
		return flight.area, standingIn ~= flight.area
	end
	return standingIn or held, false
end

return AreaWhole
