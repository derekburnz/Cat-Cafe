--!strict
-- #4543 (Design-Agent's spec, Derek: no perk pop-up bloat): a rank up that grows your cafe's room shows one short gold
-- line on the Rank Up card, "Your cafe grew!", and no pop-up of its own. The server (cafeGrows switch) sets RoomWidth
-- and RoomDepth on your plot Model; missing means the old 44 x 34 room. Controllers/CafeGrewController watches them
-- and Screens/RankUp shows the line while the card is on the tier the room grew at. Pure, so the specs test it.
--   size(width, depth) -> (number, number)        the room's size from the two attributes, 44 x 34 when missing
--   grew(beforeW, beforeD, nowW, nowD) -> boolean  the room got bigger (either side)
--   shows(grewTier, tier) -> boolean              the line shows on the card for this tier
--   fromRankUp(grewAt, rankUpAt) -> boolean       the growth came with a rank up this session (within RANK_WINDOW)

local CafeGrewLogic = {}

CafeGrewLogic.LINE = "Your cafe grew!"
CafeGrewLogic.WIDTH = 44 -- Config.World.PlotWidth: the room before it grows
CafeGrewLogic.DEPTH = 34 -- Config.World.PlotDepth
CafeGrewLogic.WIDTH_ATTRIBUTE = "RoomWidth"
CafeGrewLogic.DEPTH_ATTRIBUTE = "RoomDepth"
-- A plot is claimed at 44 x 34 on join and grows to the player's tier on the cafe's first refresh a moment later, so
-- only a growth within this many seconds of a tier rise this session counts (Gameplay-Engineer, #5062).
CafeGrewLogic.RANK_WINDOW = 10

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

-- The room grew at `grewAt` and the tier rose at `rankUpAt` (os.clock(), nil: not this session), in either order:
-- the plot's size and the player's tier reach the client separately (Review-QA, #5062).
function CafeGrewLogic.fromRankUp(grewAt: number?, rankUpAt: number?): boolean
	return grewAt ~= nil
		and rankUpAt ~= nil
		and math.abs(grewAt - rankUpAt) <= CafeGrewLogic.RANK_WINDOW
end

return CafeGrewLogic
