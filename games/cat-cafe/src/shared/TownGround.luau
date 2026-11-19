--!strict
-- #5357 (Derek 2026-11-18: "things in town like the paw print path dont fully render and should always"). With
-- streaming on (#4788) the Town Square's paving (CatCafe_Square_Paving: its slab, the lighter cross and the darker
-- tiles round the walk-up rings) and the paw print paths (WorldBuilder.buildPawPaths) stream out part by part at a
-- distance, so the ground shows with gaps. With the townGround switch on, each of those models (tagged TAG) is
-- Persistent: sent to every device whole and never streamed out. About 420 flat parts of paving and 5 per paw print,
-- none colliding with anything but the slab. Off, they stream as built (Default).
--
-- Roblox terms: a Model's ModelStreamingMode says how streaming treats it. Default streams each part on its own by
-- distance; Persistent sends the whole model to every client when it joins and keeps it there.

local TownGround = {}

TownGround.FLAG = "townGround"
TownGround.TAG = "TownGround"
TownGround.STEP = 5 -- seconds between reads of the switch

function TownGround.mode(on: boolean): Enum.ModelStreamingMode
	return if on then Enum.ModelStreamingMode.Persistent else Enum.ModelStreamingMode.Default
end

-- #5471 (Derek 2026-11-19: "the paws should just be built into the floor so it doesn't render seprate period"), switch
-- `pawsInFloor` (World/PawFloor): each paw print is drawn on the top face of the floor part it lies on (the square's
-- lane strip, the street), in a SurfaceGui named FLOOR_GUI at PIXELS a stud, and the separate PawPaths parts go
-- see-through. A print then streams in, and out, with its floor.
TownGround.FLOOR_FLAG = "pawsInFloor"
TownGround.FLOOR_GUI = "PawPrints"
TownGround.PATHS_NAME = "PawPaths" -- WorldBuilder.buildPawPaths' model
TownGround.PIXELS = 20
TownGround.PAD = 0.95 -- studs across: the pad, and each toe at TOES (x, z off the middle, -Z the front)
TownGround.TOE = 0.38
TownGround.TOES = { { -0.55, -0.5 }, { -0.2, -0.78 }, { 0.2, -0.78 }, { 0.55, -0.5 } }
TownGround.BOX = 2 -- studs: the square each print is drawn in, round its middle

-- How a Top face SurfaceGui lies on its part, in the part's own frame (#5471 playtest, Sync 2026-11-19: the canvas
-- is 2950 x 640 px on a 32 x 147.5 stud street half, so its X runs along the part's Z, not its X): canvas X runs
-- along part axis `xAxis` with sign `xSign`, canvas Y (down) along `yAxis` with `ySign`. Probed in Studio the same
-- day: the canvas's top left is the part's (-X, +Z) corner, its +X the part's -Z, its +Y the part's +X.
TownGround.CANVAS = { xAxis = "Z", xSign = -1, yAxis = "X", ySign = 1 }

local function along(axis: string, x: number, z: number): number
	return if axis == "X" then x else z
end

-- Pure: where a point `x`, `z` studs off a part's middle (its own frame) lies on that part's top face canvas, in
-- pixels from the canvas's top left, for a part `sizeX` by `sizeZ` studs.
function TownGround.pixel(
	x: number,
	z: number,
	sizeX: number,
	sizeZ: number,
	pixels: number
): (number, number)
	local c = TownGround.CANVAS
	local u = c.xSign * along(c.xAxis, x, z) + along(c.xAxis, sizeX, sizeZ) / 2
	local v = c.ySign * along(c.yAxis, x, z) + along(c.yAxis, sizeX, sizeZ) / 2
	return u * pixels, v * pixels
end

-- Pure: the canvas Rotation (degrees, clockwise on the canvas) that points a print drawn toes up (canvas -Y) along
-- (`lookX`, `lookZ`), a flat way in the part's own frame.
function TownGround.facing(lookX: number, lookZ: number): number
	local c = TownGround.CANVAS
	local u = c.xSign * along(c.xAxis, lookX, lookZ)
	local v = c.ySign * along(c.yAxis, lookX, lookZ)
	return math.deg(math.atan2(u, -v))
end

return TownGround
