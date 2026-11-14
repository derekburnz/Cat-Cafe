--!strict
-- The pure half of Components/StepTarget (#2697): where the big arrow sits at the screen's edge for a tutorial target
-- off screen, and which way it turns. No instances here, so the spec can check it.
--   edge(point, screen, arrow, margin) -> Placement?   `point` is the camera's WorldToViewportPoint of the target
--                                                      (x, y in px, Z its depth, below 0 behind the camera); nil while
--                                                      the target is on screen, else the arrow's centre kept whole
--                                                      inside the screen and its rotation toward the target
--   clear(place, arrow, boxes, screen, margin?, reach?) -> Placement   #4152: the edge arrow slid along its edge until
--                                                      what it draws (`reach` px from its centre each way, half its size
--                                                      when not given) keeps clear of `boxes` (the HUD, screen px)
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

StepTargetLogic.CLEAR = 4 -- #4152: px kept between the edge arrow and a HUD piece

export type Box = { x0: number, y0: number, x1: number, y1: number }

-- #4152 (Review-QA, 667x375: the arrow sat on the money pill's coin): the arrow keeps to its edge and its rotation, and
-- slides along that edge (up or down on a side, left or right on the top or bottom) to the nearer spot clear of any
-- box it lies over, inside the screen: clear of its whole reach, else of its square, else nil.
function StepTargetLogic.clear(
	place: Placement,
	arrow: number,
	boxes: { Box },
	screen: Vector2,
	margin: number?,
	reach: number?
): (Placement?, string)
	local gap = margin or StepTargetLogic.MARGIN
	local pad = StepTargetLogic.CLEAR
	local onSide = math.min(place.x, screen.X - place.x) <= math.min(place.y, screen.Y - place.y)
	local lo = gap + arrow / 2
	local hi = (if onSide then screen.Y else screen.X) - gap - arrow / 2
	-- the spot clear of every box for an arrow that reaches `half` from its centre, or nil
	local function slide(half: number): Placement?
		local x, y = place.x, place.y
		local function over(px: number, py: number): Box?
			for _, box in boxes do
				if
					px + half + pad > box.x0
					and px - half - pad < box.x1
					and py + half + pad > box.y0
					and py - half - pad < box.y1
				then
					return box
				end
			end
			return nil
		end
		for _ = 1, #boxes + 1 do
			local box = over(x, y)
			if box == nil then
				return { x = x, y = y, rotation = place.rotation }
			end
			local at = if onSide then y else x
			local before = (if onSide then box.y0 else box.x0) - half - pad
			local after = (if onSide then box.y1 else box.x1) + half + pad
			local best: number? = nil
			for _, spot in { before, after } do
				if
					spot >= lo
					and spot <= hi
					and (best == nil or math.abs(spot - at) < math.abs(best - at))
				then
					best = spot
				end
			end
			if best == nil then
				return nil
			end
			if onSide then
				y = best
			else
				x = best
			end
		end
		return if over(x, y) == nil then { x = x, y = y, rotation = place.rotation } else nil
	end
	-- the drawn arrow's whole reach first, then its own square (a PC's left edge has room only for that). Review-QA on
	-- #4158 (667x375): where neither is clear there is no arrow at all (nil): the strip's words and the stray's ring
	-- still lead the way, and an arrow over the money is worse than none
	local whole = slide(reach or arrow / 2)
	if whole ~= nil then
		return whole, "reach"
	end
	if reach == nil then
		return nil, "none"
	end
	local square = slide(arrow / 2)
	return square, if square ~= nil then "square" else "none"
end

function StepTargetLogic.small(size: Vector3): boolean
	return math.max(size.X, size.Y, size.Z) <= StepTargetLogic.SMALL
end

return StepTargetLogic
