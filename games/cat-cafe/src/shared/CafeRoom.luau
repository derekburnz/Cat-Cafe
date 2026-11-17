--!strict
-- #4543 (Derek 2026-11-15: "make the tiers increase slightly with every rank up or every couple and make a new bigger
-- cafe cap"; Design-Agent's ladder): the cafe's room grows every two tiers, from 44 x 34 at Tiers 1 and 2 to 60 x 46
-- at Tiers 9 and 10 (Config.World.CafeRoomByTier), behind the `cafeGrows` switch (off by default: every room stays
-- 44 x 34). The front wall and door stay where they are; the room grows back and to both sides, so its middle moves
-- back by half the extra depth. Model-Agent's shells at the bigger sizes are the base asset's name plus "_WxD"
-- (#4598), each centred on its own room. Pure, so the specs check it.
--   size(tier, on) -> (width, depth)        the room for a cafe of `tier` (tier 0, an empty plot, is the base room)
--   suffix(width, depth) -> string           "" for the base room, else "_48x37" and so on
--   centre(depth) -> number                  how far back of the plot's pivot the room's middle stands
--   backShift(depth) -> number               how far the back wall (and the back door, yard and patio) moves back
--   point(p, width, depth) -> Point          a plot-local point of the 44 x 34 room in a room of width x depth
--   offset(local, width, depth) -> CFrame    the same for a plot-local CFrame, its turn kept
--   inside(offset, width, depth, margin?) -> boolean   a plot-local offset within the room's floor

local Config = require(script.Parent.Config)

local CafeRoom = {}

CafeRoom.FLAG = "cafeGrows"
CafeRoom.BASE_WIDTH = Config.World.PlotWidth -- 44
CafeRoom.BASE_DEPTH = Config.World.PlotDepth -- 34
-- Model-Agent's wall rules for the bigger shells (plot.py, #4543, 2026-11-17):
-- * A point this close to a side wall (|x| at least BASE_WIDTH / 2 - SIDE_BAND) stays on its wall: x moves out by
--   half the extra width, and z keeps its share of the room from the front wall, as the shell's side windows and
--   pictures do (z' = (z + 17) * D / 34 - 17).
-- * A point this close to the back wall (or behind it: the back door, the step, the yard and the patio) moves back
--   with the wall by the extra depth, keeping its x (the back door and the plant shelf keep theirs). A back corner
--   piece takes both shifts.
-- * A point by the front wall under a front window (|x| at least FRONT_WINDOW_X) follows the window out, as the
--   windows stand at +-(W / 2 - 7); the pieces by the door keep their x.
CafeRoom.SIDE_BAND = 2.5
CafeRoom.BACK_BAND = 7
CafeRoom.FRONT_BAND = 4
CafeRoom.FRONT_WINDOW_X = 10.5

export type Point = { x: number, y: number, z: number, rotY: number? }

function CafeRoom.size(tier: number, on: boolean): (number, number)
	local width, depth = CafeRoom.BASE_WIDTH, CafeRoom.BASE_DEPTH
	if not on then
		return width, depth
	end
	for _, row in Config.World.CafeRoomByTier do
		if tier >= row.tier then
			width, depth = row.width, row.depth
		end
	end
	return width, depth
end

function CafeRoom.suffix(width: number, depth: number): string
	if width == CafeRoom.BASE_WIDTH and depth == CafeRoom.BASE_DEPTH then
		return ""
	end
	return string.format("_%dx%d", width, depth)
end

function CafeRoom.centre(depth: number): number
	return (depth - CafeRoom.BASE_DEPTH) / 2
end

function CafeRoom.backShift(depth: number): number
	return depth - CafeRoom.BASE_DEPTH
end

-- Which walls a point of the base room belongs to (Model-Agent's rules above).
function CafeRoom.atBack(z: number): boolean
	return z >= CafeRoom.BASE_DEPTH / 2 - CafeRoom.BACK_BAND
end

function CafeRoom.atSide(x: number): boolean
	return math.abs(x) >= CafeRoom.BASE_WIDTH / 2 - CafeRoom.SIDE_BAND
end

function CafeRoom.atFrontWindow(x: number, z: number): boolean
	return z <= -CafeRoom.BASE_DEPTH / 2 + CafeRoom.FRONT_BAND
		and math.abs(x) >= CafeRoom.FRONT_WINDOW_X
end

function CafeRoom.point(p: Point, width: number, depth: number): Point
	-- the street side of the front wall (the front garden, the Lucky Cat, the lawn) never moves
	if
		(width == CafeRoom.BASE_WIDTH and depth == CafeRoom.BASE_DEPTH)
		or p.z < -CafeRoom.BASE_DEPTH / 2
	then
		return p
	end
	local x, z = p.x, p.z
	local out = (width - CafeRoom.BASE_WIDTH) / 2
	local side = CafeRoom.atSide(p.x)
	if side or CafeRoom.atFrontWindow(p.x, p.z) then
		x = p.x + (if p.x < 0 then -out else out)
	end
	local front = CafeRoom.BASE_DEPTH / 2
	if CafeRoom.atBack(p.z) then
		z = p.z + CafeRoom.backShift(depth)
	elseif side then
		z = (p.z + front) * depth / CafeRoom.BASE_DEPTH - front
	end
	return { x = x, y = p.y, z = z, rotY = p.rotY }
end

-- The same move for a plot-local position (an anchor's or a model's pivot), keeping its turn.
function CafeRoom.offset(local0: CFrame, width: number, depth: number): CFrame
	local at = local0.Position
	local moved = CafeRoom.point({ x = at.X, y = at.Y, z = at.Z }, width, depth)
	return CFrame.new(moved.x, moved.y, moved.z) * local0.Rotation
end

function CafeRoom.inside(offset: Vector3, width: number, depth: number, margin: number?): boolean
	local m = margin or 0
	local front = -CafeRoom.BASE_DEPTH / 2
	return math.abs(offset.X) <= width / 2 + m
		and offset.Z >= front - m
		and offset.Z <= front + depth + m
end

return CafeRoom
