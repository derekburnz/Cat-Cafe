--!strict
-- Where Catch v3's rings sit on screen (#2060, Derek2: "the circle bubbles that it closes in on move across the screen
-- so not only do you have to time it but find the next one each time"). Before this every ring sat on the cat's head.
-- Now each ring takes its own spot from the server's x, y (Circles.schedule rolls them, 0.25 to 0.75 by 0.3 to 0.7),
-- spread over a safe box and kept well away from the ring before it, so the eye has to move every time:
--   - the box is the middle of the screen, clear of the top header and the notch at either side in landscape, and of
--     the thumbstick (bottom left) and the jump button (bottom right) on a phone; the "Don't swing!" line under a paw
--     ring still fits under the box's bottom edge
--   - a ring nearer the last one than STEP_X across and STEP_Y down is mirrored to the other side of the box, or to
--     its far edge when the mirror lands close too
--   - a double ring's second half keeps the first half's spot, so the pair still reads as one ring tapped twice
--   spots(circles) -> { Vector2 }   fractions of the screen (0 to 1), one per circle, in the schedule's order
-- Pure, so the cloud spec runner checks it.

local Types = require(script.Parent.Parent.Types)

local CatchSpots = {}

CatchSpots.MIN_X, CatchSpots.MAX_X = 0.26, 0.74
CatchSpots.MIN_Y, CatchSpots.MAX_Y = 0.36, 0.64
CatchSpots.STEP_X = 0.16 -- of the screen's width
CatchSpots.STEP_Y = 0.12 -- of its height
-- the server's range for x and y (shared/Circles SCREEN_MIN_X and so on), stretched over the box
local SERVER_X0, SERVER_X1 = 0.25, 0.75
local SERVER_Y0, SERVER_Y1 = 0.3, 0.7

local function stretch(value: number, from: number, to: number, lo: number, hi: number): number
	local share = if value == value then math.clamp((value - from) / (to - from), 0, 1) else 0.5
	return lo + share * (hi - lo)
end

local function near(a: Vector2, b: Vector2): boolean
	return math.abs(a.X - b.X) < CatchSpots.STEP_X and math.abs(a.Y - b.Y) < CatchSpots.STEP_Y
end

function CatchSpots.spots(circles: { Types.CatchCircle }): { Vector2 }
	local minX, maxX = CatchSpots.MIN_X, CatchSpots.MAX_X
	local minY, maxY = CatchSpots.MIN_Y, CatchSpots.MAX_Y
	local list: { Vector2 } = {}
	local last: Vector2? = nil
	for _, circle in circles do
		local secondHalf = (circle :: any).kind == "double" and (circle :: any).half == 2
		if secondHalf and last then
			table.insert(list, last)
			continue
		end
		local spot = Vector2.new(
			stretch(circle.x, SERVER_X0, SERVER_X1, minX, maxX),
			stretch(circle.y, SERVER_Y0, SERVER_Y1, minY, maxY)
		)
		if last and near(spot, last) then
			local mirrored = Vector2.new(minX + maxX - spot.X, minY + maxY - spot.Y)
			if near(mirrored, last) then
				-- both sit near the middle: go to the far side, level with the middle
				mirrored =
					Vector2.new(if last.X < (minX + maxX) / 2 then maxX else minX, mirrored.Y)
			end
			spot = mirrored
		end
		table.insert(list, spot)
		last = spot
	end
	return list
end

return CatchSpots
