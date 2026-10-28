--!strict
-- The cafe back door's swing (Model-Agent #509; Derek 2026-10-28 01:28: players walk through the door, cats use the
-- flap), pure: when the leaf stands open and how the leaf and the cat flap move. Client/DoorController moves the art.
-- Angles are degrees: the leaf turns about its hinge's Y, OPEN_DEGREES out into the yard; the flap turns about its
-- top hinge's X, negative out into the yard and positive into the cafe. An F80 door set's back leaf swings the same
-- way, and its two front leaves stand open into the cafe by day (Model-Agent, F80).

local BackDoor = {}

BackDoor.OPEN_DEGREES = -90 -- wide open, flat beside the jamb in the yard
BackDoor.OPEN_RANGE = 7 -- studs from the doorway at which a player opens it
BackDoor.LEAF_RATE = 7 -- the leaf closes this share of the gap a second, so it eases to a stop
BackDoor.FLAP_RANGE = 2.5 -- studs from the flap at which a cat pushes it
BackDoor.FLAP_PUSH = 50 -- degrees a cat going through holds it at
BackDoor.FLAP_MAX = 60 -- the most the flap turns either way
BackDoor.FLAP_RATE = 12 -- how fast a pushing cat swings it, as LEAF_RATE
BackDoor.FLAP_SPRING = 140 -- degrees a second squared per degree off rest, once the cat is through
BackDoor.FLAP_DAMPING = 5 -- per second, so it rocks a few times and settles
BackDoor.FRONT_OPEN_DEGREES = 90 -- a door set's front leaves by day, each flat against the wall inside

-- Whether the leaf stands open: while the areas are open (by day), on an owned cafe, with a player's character
-- `nearest` studs from the doorway, within OPEN_RANGE. The leaf is the cafe's own or an F80 door set's.
function BackDoor.wantsOpen(areasOpen: boolean, owned: boolean, nearest: number?): boolean
	return areasOpen and owned and nearest ~= nil and nearest <= BackDoor.OPEN_RANGE
end

-- Which way a door set's front leaf named `name` turns to open (Model-Agent, F80: `_LeafL` -90 about its hinge's Y
-- and `_LeafR` +90, both into the cafe), or nil for any other part of the model.
function BackDoor.frontTurn(name: string): number?
	if name:sub(-6) == "_LeafL" then
		return -1
	elseif name:sub(-6) == "_LeafR" then
		return 1
	end
	return nil
end

-- The leaf's angle `dt` seconds on from `angle`, easing toward `target`; it lands on the target within half a degree.
function BackDoor.stepLeaf(angle: number, target: number, dt: number): number
	local nextAngle = angle + (target - angle) * math.min(1, math.max(dt, 0) * BackDoor.LEAF_RATE)
	if math.abs(target - nextAngle) < 0.5 then
		return target
	end
	return nextAngle
end

-- Which way a cat at `yardDepth` studs into the yard from the doorway (negative inside the cafe) pushes the flap:
-- a cat in the yard on its way in pushes it in (1), a cat inside on its way out pushes it out (-1).
function BackDoor.pushFrom(yardDepth: number): number
	return if yardDepth >= 0 then 1 else -1
end

-- The flap `dt` seconds on: with `push` (1 or -1, pushFrom) a cat holds it toward FLAP_PUSH that way; with none it
-- swings back on a damped spring from where it was, keeping its speed, and comes to rest at 0. Returns the angle and
-- its speed in degrees a second.
function BackDoor.stepFlap(
	angle: number,
	speed: number,
	push: number?,
	dt: number
): (number, number)
	if dt <= 0 then
		return angle, speed
	end
	dt = math.min(dt, 0.1) -- a long frame would throw the spring out of step
	if push ~= nil then
		local target = math.sign(push) * BackDoor.FLAP_PUSH
		local nextAngle = angle + (target - angle) * math.min(1, dt * BackDoor.FLAP_RATE)
		return nextAngle, (nextAngle - angle) / dt
	end
	local nextSpeed = speed + (-BackDoor.FLAP_SPRING * angle - BackDoor.FLAP_DAMPING * speed) * dt
	local nextAngle = math.clamp(angle + nextSpeed * dt, -BackDoor.FLAP_MAX, BackDoor.FLAP_MAX)
	if math.abs(nextAngle) < 0.2 and math.abs(nextSpeed) < 2 then
		return 0, 0
	end
	return nextAngle, nextSpeed
end

return BackDoor
