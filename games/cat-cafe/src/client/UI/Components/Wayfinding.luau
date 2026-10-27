--!strict
-- Rules for the location markers and the zone chip (UI plan 2026-10-27; Derek: "symbols to locations also that
-- disappear when close enough so its not clutter", and "if you get back to the area with the cafes that can be
-- considered safe").
--   alpha(distance)  how visible a marker is at that many studs: 0 within NEAR, rising to 1 at FAR and beyond
--   isSafe(zone)     the World.Zones name the player stands in: nil (the street) or "Cafe" is safe from shoves,
--                    an area ("Alley", "Park") is not
--   areaOf(zone)     the area id for a zone name ("Alley" -> "alley"), nil when safe
-- Pure, no Theme, so the cloud spec runner can load it.

local Wayfinding = {}

Wayfinding.NEAR = 30 -- studs: closer than this the marker is gone, the place itself is in view
Wayfinding.FAR = 60 -- studs: from here out the marker is fully shown

function Wayfinding.alpha(distance: number): number
	if distance ~= distance then -- NaN
		return 0
	end
	return math.clamp((distance - Wayfinding.NEAR) / (Wayfinding.FAR - Wayfinding.NEAR), 0, 1)
end

function Wayfinding.isSafe(zone: string?): boolean
	return zone == nil or zone == "Cafe"
end

function Wayfinding.areaOf(zone: string?): string?
	if Wayfinding.isSafe(zone) then
		return nil
	end
	local name = zone :: string
	return name:sub(1, 1):lower() .. name:sub(2)
end

return Wayfinding
