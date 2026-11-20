--!strict
-- #5533 v2 cannonGlow (Design-Agent's new-start-v2-spec.md): after a Rank Up that opens an area, the Player attribute
-- ATTR holds that area's id until the player's first flight there. Effects/WorldGlow (Motion-FX) lights the Town
-- Square cannon with the area's sign while it is set, and the first walk into the cannon flies straight there with no
-- picker (UI.cannon.open); the picker is back from the next flight. Read as the replicated LiveFlag_cannonGlow
-- attribute (true only, so an older place that lacks the key reads it off). Pure but for the attribute reads.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CannonGlow = {}

CannonGlow.FLAG = "cannonGlow" -- in LiveFlags with Motion-FX's WorldGlow (#5535)
CannonGlow.ATTR = "CannonGlowArea"

function CannonGlow.on(): boolean
	return ReplicatedStorage:GetAttribute("LiveFlag_" .. CannonGlow.FLAG) == true
end

-- The area a rank up to `tier` opens: the first in `areas` whose tier is `tier`, else nil.
function CannonGlow.opened(tier: number, areas: { { id: string, tier: number } }): string?
	for _, area in areas do
		if area.tier == tier then
			return area.id
		end
	end
	return nil
end

-- Whether a launch to `destination` with `glowing` set (the attribute) is the first flight there, which clears it.
function CannonGlow.clears(glowing: unknown, destination: string): boolean
	return type(glowing) == "string" and glowing == destination
end

-- The straight flight for a walk into a cannon: the glowing area while the switch is on, else nil.
function CannonGlow.direct(on: boolean, glowing: unknown): string?
	if on and type(glowing) == "string" and glowing ~= "" then
		return glowing
	end
	return nil
end

return CannonGlow
