--!strict
-- Rules for the location markers and the safe zone toast (UI plan 2026-10-27; Derek: "symbols to locations also that
-- disappear when close enough so its not clutter", and "if you get back to the area with the cafes that can be
-- considered safe").
--   alpha(distance)  how visible a marker is at that many studs: 0 within NEAR, rising to 1 at FAR and beyond
--   lockedAlpha(distance)  the same for a locked area's marker, which shows only right by its gate (Derek
--                    2026-10-28: "hide the tiered map and distance ui bubbles until unlocked unless standing really
--                    close"): 1 within LOCKED_NEAR, gone from LOCKED_FAR out
--   scale(distance)  how big a marker draws: full size to SCALE_NEAR, shrinking to SCALE_MIN at SCALE_FAR and beyond
--                    ("further away the bubbles should be smaller")
--   isSafe(zone)     the World.Zones name the player stands in: nil (the street) or "Cafe" is safe from shoves,
--                    an area ("Alley", "Park") is not
--   areaOf(zone)     the area id for a zone name ("Alley" -> "alley"), nil when safe
--   pickBox(boxes, side)  which of a zone's boxes carries its marker: the biggest, and of the same size the one on
--                    the player's side of town (the Alleyway's two back alleys since v3.1, F77)
--   armArea(attribute, name)  the area a town signpost arm points at, from its Area attribute or its name
--   armLock(needs, tier)  a town signpost arm's lock line, "🔒 Tier 3", or nil when the player's tier opens it
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

Wayfinding.LOCKED_NEAR = 35 -- studs: a locked area's marker is fully shown this close to its gate
Wayfinding.LOCKED_FAR = 50 -- studs: and gone from here out, as the gate's own sign
Wayfinding.SCALE_NEAR = 60 -- studs: markers this close draw full size
Wayfinding.SCALE_FAR = 300 -- studs: about the width of the map
Wayfinding.SCALE_MIN = 0.55 -- the size a marker shrinks to from SCALE_FAR out

function Wayfinding.lockedAlpha(distance: number): number
	if distance ~= distance then
		return 0
	end
	local span = Wayfinding.LOCKED_FAR - Wayfinding.LOCKED_NEAR
	return math.clamp((Wayfinding.LOCKED_FAR - distance) / span, 0, 1)
end

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

function Wayfinding.areaOf(zone: string?): string?
	if Wayfinding.isSafe(zone) then
		return nil
	end
	local name = zone :: string
	return name:sub(1, 1):lower() .. name:sub(2)
end

-- Boxes within this share of the biggest count as the same size.
local SAME_SIZE = 0.99

-- `boxes` are a zone's floor areas and the X of their middles; `side` is -1 for the west of town (the default, as the
-- Alley travel arrival with no cafe) or 1 for the east. Returns the index of the box to use, nil for none.
function Wayfinding.pickBox(boxes: { { area: number, x: number } }, side: number?): number?
	local biggest = 0
	for _, box in boxes do
		biggest = math.max(biggest, box.area)
	end
	if biggest <= 0 then
		return nil
	end
	local want = if side and side > 0 then 1 else -1
	local best: number? = nil
	local bestScore = -math.huge
	for index, box in boxes do
		if box.area >= biggest * SAME_SIZE then
			local score = box.x * want -- further to the wanted side wins
			if score > bestScore then
				best, bestScore = index, score
			end
		end
	end
	return best
end

-- The `Area` attribute wins; else the end of the part's name after "Arm" ("Arm_Woods", "CatCafe_Square_Signpost_ArmWoods"
-- -> "woods"), so a model export with no attributes still works.
function Wayfinding.armArea(attribute: any, name: string): string?
	if type(attribute) == "string" and attribute ~= "" then
		return string.lower(attribute)
	end
	local tail = name:match("Arm_?(%a+)$")
	return if tail then tail:lower() else nil
end

function Wayfinding.armLock(needs: number, tier: number): string?
	if tier >= needs then
		return nil
	end
	return ("🔒 Tier %d"):format(needs)
end

return Wayfinding
