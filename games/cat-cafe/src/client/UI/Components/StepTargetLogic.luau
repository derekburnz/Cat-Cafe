--!strict
-- The pure half of Components/StepTarget (#2697): where the big arrow sits at the screen's edge for a tutorial target
-- off screen, and which way it turns. No instances here, so the spec can check it.
--   edge(point, screen, arrow, margin) -> Placement?   `point` is the camera's WorldToViewportPoint of the target
--                                                      (x, y in px, Z its depth, below 0 behind the camera); nil while
--                                                      the target is on screen, else the arrow's centre kept whole
--                                                      inside the screen and its rotation toward the target
--   rotation(direction) -> number                      the arrow is drawn pointing down; this turns it to `direction`
--   small(size) -> boolean                             a model this size is one thing (a bowl, a cannon), not a whole
--                                                      cafe or area, so the Highlight goes round all of it

local StepTargetLogic = {}

StepTargetLogic.MARGIN = 12 -- px between the arrow and the screen's edge
StepTargetLogic.SMALL = 40 -- studs: the longest side of a model the Highlight takes whole

export type Placement = { x: number, y: number, rotation: number }

function StepTargetLogic.rotation(direction: Vector2): number
	local turn = math.deg(math.atan2(direction.Y, direction.X)) - 90
	-- kept in -180 to 180 (atan2 of a -0 gives -180, which is 180)
	if turn <= -180 then
		turn += 360
	end
	return turn
end

function StepTargetLogic.edge(
	point: Vector3,
	screen: Vector2,
	arrow: number,
	margin: number?
): Placement?
	local gap = margin or StepTargetLogic.MARGIN
	if
		point.Z > 0
		and point.X >= gap
		and point.X <= screen.X - gap
		and point.Y >= gap
		and point.Y <= screen.Y - gap
	then
		return nil
	end
	local centre = screen / 2
	local direction = Vector2.new(point.X, point.Y) - centre
	if point.Z <= 0 then
		-- behind the camera the projection comes out mirrored
		direction = -direction
	end
	if direction.Magnitude < 1e-3 then
		direction = Vector2.new(0, 1) -- straight behind: point down, toward the player's back
	end
	local halfX = math.max(centre.X - gap - arrow / 2, 0)
	local halfY = math.max(centre.Y - gap - arrow / 2, 0)
	local stretch = math.huge
	if math.abs(direction.X) > 1e-6 then
		stretch = math.min(stretch, halfX / math.abs(direction.X))
	end
	if math.abs(direction.Y) > 1e-6 then
		stretch = math.min(stretch, halfY / math.abs(direction.Y))
	end
	local at = centre + direction * stretch
	return { x = at.X, y = at.Y, rotation = StepTargetLogic.rotation(direction) }
end

function StepTargetLogic.small(size: Vector3): boolean
	return math.max(size.X, size.Y, size.Z) <= StepTargetLogic.SMALL
end

return StepTargetLogic
