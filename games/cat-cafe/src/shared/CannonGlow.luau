--!strict
-- #5533 v2 cannonGlow (Design-Agent's new-start-v2-spec.md): after a Rank Up that opens an area, the Player attribute
-- ATTR holds that area's id until the player's first flight there. Effects/WorldGlow (Motion-FX) lights the Town
-- Square cannon with the area's sign while it is set, and the first walk into the cannon flies straight there with no
-- picker (UI.cannon.open); the picker is back from the next flight. A landing there by any route ends it too. Read as the replicated LiveFlag_cannonGlow
-- attribute (true only, so an older place that lacks the key reads it off). Pure but for the attribute reads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CannonGlow = {}

CannonGlow.FLAG = "cannonGlow" -- in LiveFlags with Motion-FX's WorldGlow (#5535)
CannonGlow.ATTR = "CannonGlowArea"
CannonGlow.TOWN = "town" -- the Town Square cannon's id (shared/Cannon.TOWN)

function CannonGlow.on(): boolean
	return ReplicatedStorage:GetAttribute("LiveFlag_" .. CannonGlow.FLAG) == true
end

-- The area a rank up to `tier` opens: the first in `areas` whose tier is `tier`, else nil. Nil too when `been` says
-- the save already has a cat from it (a night pass trip, a gift), so it never arms for an area already visited.
function CannonGlow.opened(
	tier: number,
	areas: { { id: string, tier: number } },
	been: { [string]: boolean }?
): string?
	for _, area in areas do
		if area.tier == tier then
			if been ~= nil and been[area.id] then
				return nil
			end
			return area.id
		end
	end
	return nil
end

-- Whether a launch to, or a landing in, `destination` with `glowing` set (the attribute) ends the glow.
function CannonGlow.clears(glowing: unknown, destination: string): boolean
	return type(glowing) == "string" and glowing == destination
end

-- The straight flight for a walk into cannon `cannonId`: the glowing area while the switch is on, else nil. Only the
-- Town Square cannon, the one Effects/WorldGlow lights with the sign, so a straight trip never starts from an unlit
-- cannon (Design 2026-11-20); the camps keep their picker.
function CannonGlow.direct(on: boolean, glowing: unknown, cannonId: string?): string?
	if on and cannonId == CannonGlow.TOWN and type(glowing) == "string" and glowing ~= "" then
		return glowing
	end
	return nil
end

return CannonGlow
