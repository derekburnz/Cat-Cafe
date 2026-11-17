--!strict
-- #5050 (Sync's timed new-player run, Nov 17): the Alleyway title came a second time at 124.6 s, over the catch rings.
-- The landing showed it, the player stepped out of the Alley's zone box (the camp's edge) and back in, and the card's
-- own 4 s repeat gap had run out. An area's title card now shows once a trip: the same area again only after the
-- player was out of it for GAP seconds, and never while a catch is on. Pure, so the cloud specs check it.
--   AreaTrip.new() -> Trip
--   AreaTrip.zone(trip, area, now)               the player now stands in `area` (an AreaId; nil for the street and
--                                                the cafes)
--   AreaTrip.due(trip, areaId, catching, now)    whether the title card for `areaId` may show now
--   AreaTrip.shown(trip, areaId, inside, now)    it showed; `inside` whether the player already stands in it

local AreaTrip = {}

AreaTrip.GAP = 30 -- seconds out of an area before its title shows again

export type Trip = {
	shown: string?, -- the area whose title showed last
	outSince: number?, -- when the player left it (nil while inside it, or before it was entered)
	fresh: boolean, -- the player just came back into it after GAP or more outside
}

function AreaTrip.new(): Trip
	return { shown = nil, outSince = nil, fresh = false }
end

function AreaTrip.zone(trip: Trip, area: string?, now: number)
	if trip.shown == nil then
		return
	end
	if area == trip.shown then
		if trip.outSince ~= nil then
			trip.fresh = now - (trip.outSince :: number) >= AreaTrip.GAP
			trip.outSince = nil
		end
	elseif trip.outSince == nil then
		trip.outSince = now
		trip.fresh = false
	end
end

function AreaTrip.due(trip: Trip, areaId: string, catching: boolean, now: number): boolean
	if catching then
		return false
	end
	if areaId ~= trip.shown or trip.fresh then
		return true
	end
	return trip.outSince ~= nil and now - (trip.outSince :: number) >= AreaTrip.GAP
end

function AreaTrip.shown(trip: Trip, areaId: string, inside: boolean, now: number)
	trip.shown = areaId
	trip.fresh = false
	trip.outSince = if inside then nil else now
end

return AreaTrip
