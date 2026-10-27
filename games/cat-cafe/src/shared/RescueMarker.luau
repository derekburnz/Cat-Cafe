--!strict
-- Where the rescue bar's marker is (data-model section 10b). The marker slides back and forth along the bar at
-- `speed` bar lengths per second, starting at server time `startsAt` at `phase` (0 to 2: 0 to 1 is the way out
-- from the left end, 1 to 2 the way back). Its position is a triangle wave from 0 (left) to 1 (right). The server
-- judges RescuePress with these two functions and the UI draws the bar with them, so both sides agree (reviewer
-- N74). Same API as the UI's first copy in Components/RescueMarker.

local RescueMarker = {}

-- The marker at server time t, from 0 (left end) to 1 (right end). Before startsAt it waits at its phase.
function RescueMarker.position(startsAt: number, phase: number, speed: number, t: number): number
	local travelled = phase + speed * math.max(0, t - startsAt)
	local u = travelled % 2
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

return RescueMarker
