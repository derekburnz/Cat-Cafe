--!strict
-- The pure half of Components/TutorialArrow (#2314): which side of its target the big arrow sits on, where, which
-- way it turns, and when it shows. No instances here, so the spec can check it.

local TutorialArrowLogic = {}

TutorialArrowLogic.GAP = 6 -- px between the arrow's tip and the target's edge
TutorialArrowLogic.SHOW_SECONDS = 6 -- on screen this long once a step's glow starts
TutorialArrowLogic.AGAIN_SECONDS = 15 -- then away this long, and back while the step still waits

export type Side = string -- "top", "left", "right" or "bottom"

export type Placement = {
	side: Side,
	x: number, -- the arrow's centre, in the target's ScreenGui pixels
	y: number,
	rotation: number, -- the arrow is drawn pointing down; this turns it toward the target
}

export type Rect = { min: Vector2, max: Vector2 }

-- the arrow comes from above when it can, then from the left, the right, and below
local ORDER: { Side } = { "top", "left", "right", "bottom" }
local ROTATION: { [Side]: number } = { top = 0, left = -90, right = 90, bottom = 180 }

local function overlap(a: Rect, b: Rect): number
	local w = math.min(a.max.X, b.max.X) - math.max(a.min.X, b.min.X)
	local h = math.min(a.max.Y, b.max.Y) - math.max(a.min.Y, b.min.Y)
	return if w > 0 and h > 0 then w * h else 0
end

-- The arrow's centre on `side` of the target, kept whole on the screen.
local function centreOn(
	side: Side,
	position: Vector2,
	size: Vector2,
	screen: Vector2,
	arrow: number
): Vector2
	local half = arrow / 2
	local x = position.X + size.X / 2
	local y = position.Y + size.Y / 2
	if side == "top" then
		y = position.Y - TutorialArrowLogic.GAP - half
	elseif side == "bottom" then
		y = position.Y + size.Y + TutorialArrowLogic.GAP + half
	elseif side == "left" then
		x = position.X - TutorialArrowLogic.GAP - half
	else
		x = position.X + size.X + TutorialArrowLogic.GAP + half
	end
	return Vector2.new(
		math.clamp(x, half, math.max(half, screen.X - half)),
		math.clamp(y, half, math.max(half, screen.Y - half))
	)
end

-- Where an arrow `arrow` px square points at the target box (position and size in px) on a `screen` px area. Of
-- the sides with room for it, the one that covers the least of `others` (the other buttons on screen, so it doesn't
-- sit on the Store tile), in ORDER on a tie; with room nowhere, the side with the most.
function TutorialArrowLogic.place(
	position: Vector2,
	size: Vector2,
	screen: Vector2,
	arrow: number,
	others: { Rect }?
): Placement
	local need = arrow + TutorialArrowLogic.GAP
	local room: { [Side]: number } = {
		top = position.Y,
		bottom = screen.Y - (position.Y + size.Y),
		left = position.X,
		right = screen.X - (position.X + size.X),
	}
	local blockers: { Rect } = others or {}
	local side: Side? = nil
	local least = math.huge
	for _, candidate in ORDER do
		if room[candidate] >= need then
			local centre = centreOn(candidate, position, size, screen, arrow)
			local box = {
				min = centre - Vector2.new(arrow, arrow) / 2,
				max = centre + Vector2.new(arrow, arrow) / 2,
			}
			local covered = 0
			for _, other in blockers do
				covered += overlap(box, other)
			end
			if covered < least then
				least = covered
				side = candidate
			end
		end
	end
	local chosen: Side = "top"
	if side ~= nil then
		chosen = side
	else
		local best = -math.huge
		for _, candidate in ORDER do
			if room[candidate] > best then
				best = room[candidate]
				chosen = candidate
			end
		end
	end
	local centre = centreOn(chosen, position, size, screen, arrow)
	return { side = chosen, x = centre.X, y = centre.Y, rotation = ROTATION[chosen] }
end

-- True while the arrow shows, `elapsed` seconds after its target started to glow: SHOW_SECONDS on, AGAIN_SECONDS
-- off, and round again while the step still waits.
function TutorialArrowLogic.showing(elapsed: number): boolean
	if elapsed < 0 then
		return false
	end
	local cycle = TutorialArrowLogic.SHOW_SECONDS + TutorialArrowLogic.AGAIN_SECONDS
	return elapsed % cycle < TutorialArrowLogic.SHOW_SECONDS
end

return TutorialArrowLogic
