--!strict
-- Where the rescue bar's marker is (data-model section 10b). The marker slides back and forth along the bar at
-- `speed` bar lengths per second, starting at server time `startsAt` at `phase` (0 to 2: 0 to 1 is the way out
-- from the left end, 1 to 2 the way back). Its position is a triangle wave from 0 (left) to 1 (right). The server
-- judges RescuePress with these two functions and the UI draws the bar with them, so both sides agree (reviewer
-- N74).

local RescueMarker = {}

-- Where on the back-and-forth (0 to 2) the marker is at server time t: the phase a faster marker starts again from
-- after a rescue hit (F93), so it carries on from the same spot in the same direction.
function RescueMarker.phaseAt(startsAt: number, phase: number, speed: number, t: number): number
	return (phase + speed * math.max(0, t - startsAt)) % 2
end

-- The marker at server time t, from 0 (left end) to 1 (right end). Before startsAt it waits at its phase.
function RescueMarker.position(startsAt: number, phase: number, speed: number, t: number): number
	local u = RescueMarker.phaseAt(startsAt, phase, speed, t)
	return if u <= 1 then u else 2 - u
end

-- True when a marker at `position` is inside a zone of `width` centred on `centre`, allowing `tolerance` of the
-- bar either side (data-model RescueTolerance, 0.03).
function RescueMarker.inZone(
	position: number,
	centre: number,
	width: number,
	tolerance: number?
): boolean
	local half = width / 2 + (tolerance or 0)
	return math.abs(position - centre) <= half
end

-- #2318 (Derek2: "sometimes rescue's say miss even if you hit it properly"): how long before a press's time the
-- marker may have been in the zone and still count. The player taps on the frame they saw, which is a frame or two
-- (drawing, the screen, the touch) older than the moment the tap is stamped, so a fast marker leaving the zone had
-- already left it when the press was timed.
RescueMarker.SEEN_LAG = 0.05

-- True when a press at server time t is a hit: the marker (from `startsAt` at `phase`, `speed` bar lengths a second)
-- is inside the zone at t, or was at any time in the SEEN_LAG before it, though never before `since` (the last
-- judged press, so a press right after a hit is not judged on where the marker stood for the one before it). The
-- marker moves in a straight line inside that short a lag unless it turns at an end, so both ends and a turn are
-- checked.
function RescueMarker.hitAt(
	startsAt: number,
	phase: number,
	speed: number,
	t: number,
	centre: number,
	width: number,
	tolerance: number?,
	since: number?
): boolean
	local function inside(at: number): boolean
		return RescueMarker.inZone(
			RescueMarker.position(startsAt, phase, speed, at),
			centre,
			width,
			tolerance
		)
	end
	if inside(t) then
		return true
	end
	local from = math.max(t - RescueMarker.SEEN_LAG, since or -math.huge)
	if from >= t then
		return false
	end
	if inside(from) then
		return true
	end
	-- the segment from..t, a straight line unless it passes an end of the bar: the zone is an interval, so a line
	-- between two points outside it on the same side misses it, and on opposite sides crosses it
	local a = RescueMarker.position(startsAt, phase, speed, from)
	local b = RescueMarker.position(startsAt, phase, speed, t)
	local half = width / 2 + (tolerance or 0)
	local low, high = centre - half, centre + half
	local u0 = RescueMarker.phaseAt(startsAt, phase, speed, from)
	local u1 = u0 + speed * (t - math.max(from, startsAt))
	local turns = math.floor(u1) > math.floor(u0) -- passes 1 (the right end) or 2 (back at the left)
	if turns then
		-- it reached an end in between: the right end if it was heading out, the left end otherwise
		local endAt = if u0 % 2 < 1 then 1 else 0
		return (endAt >= low and endAt <= high)
			or (math.min(a, endAt) <= high and math.max(a, endAt) >= low)
	end
	return math.min(a, b) <= high and math.max(a, b) >= low
end

return RescueMarker
