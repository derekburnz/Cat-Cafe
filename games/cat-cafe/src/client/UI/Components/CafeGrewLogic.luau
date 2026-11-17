--!strict
-- #4543 (Design-Agent's spec, Derek: no perk pop-up bloat): a rank up that grows your cafe's room shows one short gold
-- line on the Rank Up card, "Your cafe grew!", and no pop-up of its own. The server (cafeGrows switch) sets RoomWidth
-- and RoomDepth on your plot Model; missing means the old 44 x 34 room. Controllers/CafeGrewController watches them
-- and Screens/RankUp shows the line while the card is on the tier the room grew at. Pure, so the specs test it.
--   size(width, depth) -> (number, number)        the room's size from the two attributes, 44 x 34 when missing
--   grew(beforeW, beforeD, nowW, nowD) -> boolean  the room got bigger (either side)
--   shows(grewTier, tier) -> boolean              the line shows on the card for this tier

local CafeGrewLogic = {}

CafeGrewLogic.LINE = "Your cafe grew!"
CafeGrewLogic.WIDTH = 44 -- Config.World.PlotWidth: the room before it grows
CafeGrewLogic.DEPTH = 34 -- Config.World.PlotDepth
CafeGrewLogic.WIDTH_ATTRIBUTE = "RoomWidth"
CafeGrewLogic.DEPTH_ATTRIBUTE = "RoomDepth"

local function side(value: unknown, fallback: number): number
	return if type(value) == "number" and value > 0 then value else fallback
end

function CafeGrewLogic.size(width: unknown, depth: unknown): (number, number)
	return side(width, CafeGrewLogic.WIDTH), side(depth, CafeGrewLogic.DEPTH)
end

function CafeGrewLogic.grew(beforeW: number, beforeD: number, nowW: number, nowD: number): boolean
	return (nowW > beforeW and nowD >= beforeD) or (nowD > beforeD and nowW >= beforeW)
end

function CafeGrewLogic.shows(grewTier: number?, tier: number?): boolean
	return grewTier ~= nil and tier ~= nil and grewTier == tier
end

return CafeGrewLogic
