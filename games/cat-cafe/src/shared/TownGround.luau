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

-- Pure: where a point `x`, `z` studs off a part's middle (its own frame) lies on that part's top face canvas, in
-- pixels from the canvas's top left, for a part `sizeX` by `sizeZ` studs. A Top SurfaceGui runs its X along the
-- part's +X and its Y along the part's +Z.
function TownGround.pixel(
	x: number,
	z: number,
	sizeX: number,
	sizeZ: number,
	pixels: number
): (number, number)
	return (x + sizeX / 2) * pixels, (z + sizeZ / 2) * pixels
end

-- Pure: a print's turn about Y (degrees, its front -Z turned toward its way) as a Top canvas rotation, which turns
-- the other way (clockwise as seen from above).
function TownGround.canvasTurn(rotY: number): number
	return -rotY
end

-- Pure: the turn about Y (degrees) of a frame whose LookVector is (`lookX`, `lookZ`) flat.
function TownGround.turnOf(lookX: number, lookZ: number): number
	return math.deg(math.atan2(-lookX, -lookZ))
end

return TownGround
