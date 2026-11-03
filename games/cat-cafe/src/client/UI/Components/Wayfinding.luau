--!strict
-- Rules for the My Cafe marker and the safe zone toast (UI plan 2026-10-27; Derek: "symbols to
-- locations also that disappear when close enough so its not clutter", and "if you get back to the area with the cafes
-- that can be considered safe"). The other places lost their markers on 2026-10-28, so the locked-area fade and the
-- zone box pick went with them.
--   alpha(distance)  how visible a marker is at that many studs: 0 within NEAR, rising to 1 at FAR and beyond
--   scale(distance)  how big a marker draws: full size to SCALE_NEAR, shrinking to SCALE_MIN at SCALE_FAR and beyond
--                    ("further away the bubbles should be smaller")
--   isSafe(zone)     the World.Zones name the player stands in: nil (the street) or "Cafe" is safe from shoves,
--                    an area ("Alley", "Park") is not
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

Wayfinding.SCALE_NEAR = 60 -- studs: markers this close draw full size
Wayfinding.SCALE_FAR = 300 -- studs: about the width of the map
Wayfinding.SCALE_MIN = 0.55 -- the size a marker shrinks to from SCALE_FAR out

function Wayfinding.scale(distance: number): number
	if distance ~= distance then
		return 1
	end
	local span = Wayfinding.SCALE_FAR - Wayfinding.SCALE_NEAR
	local far = math.clamp((distance - Wayfinding.SCALE_NEAR) / span, 0, 1)
	return 1 - far * (1 - Wayfinding.SCALE_MIN)
end

function Wayfinding.isSafe(zone: string?): boolean
	return zone == nil or zone == "Cafe"
end

return Wayfinding
