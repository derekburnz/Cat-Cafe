--!strict
-- The cat follower's walk sums (#5172, cat-follower-spec.md "How it moves"), pure so the specs can run them; the
-- client's FollowerController draws with them.

local FollowLogic = {}

FollowLogic.SIDE = 2.5 -- studs to the player's right
FollowLogic.BEHIND = 4 -- studs behind the player
FollowLogic.STOP = 0.6 -- closer than this to its spot it stands still
FollowLogic.SNAP = 40 -- farther than this it pops to its spot
FollowLogic.CATCH_UP = 1 -- up to this much faster than the player while it is behind
FollowLogic.IDLE = 3 -- seconds standing still before it sits and grooms
FollowLogic.HOP_SECONDS = 0.45
FollowLogic.HOP_HEIGHT = 1.6

FollowLogic.ASIDE = 2.4 -- during a net catch the spot is this many times farther out, clear of the rings
FollowLogic.CATCH_HOLD = 8 -- seconds a catch counts as running with no result heard

-- Where the cat walks to: behind and to the side of the player's root at `position` facing `look`, at the height
-- `floorY` of their feet; `aside` (a net catch) puts it ASIDE times farther out, where it sits and watches.
function FollowLogic.spot(
	position: Vector3,
	look: Vector3,
	floorY: number,
	aside: boolean?
): Vector3
	local flat = Vector3.new(look.X, 0, look.Z)
	local forward = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local far = if aside then FollowLogic.ASIDE else 1
	local p = position + right * FollowLogic.SIDE * far - forward * FollowLogic.BEHIND * far
	return Vector3.new(p.X, floorY, p.Z)
end

-- The player's feet under a root part of height `rootHeight` with Humanoid.HipHeight `hip`.
function FollowLogic.feet(rootY: number, rootHeight: number, hip: number): number
	return rootY - rootHeight / 2 - hip
end

export type Move = {
	position: Vector3,
	facing: Vector3, -- the flat way it walked (unit), or forward (0, 0, -1) when it did not
	moved: number, -- studs walked this frame
	snapped: boolean, -- it popped to the spot
}

-- One frame of `dt` seconds from `from` toward `to` at the player's `speed`: a pop past SNAP, standing still within
-- STOP, else a walk on the flat (faster by up to CATCH_UP the farther behind) that never overshoots the STOP ring.
-- Its height follows the floor at once.
function FollowLogic.move(from: Vector3, to: Vector3, speed: number, dt: number): Move
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local distance = flat.Magnitude
	local forward = Vector3.new(0, 0, -1)
	if (to - from).Magnitude > FollowLogic.SNAP then
		return {
			position = to,
			facing = if distance > 1e-3 then flat.Unit else forward,
			moved = 0,
			snapped = true,
		}
	end
	if distance <= FollowLogic.STOP then
		return {
			position = Vector3.new(from.X, to.Y, from.Z),
			facing = forward,
			moved = 0,
			snapped = false,
		}
	end
	local behind = math.clamp((distance - 2) / 8, 0, 1)
	local pace = math.max(speed, 0) * (1 + FollowLogic.CATCH_UP * behind)
	local walk = math.min(distance - FollowLogic.STOP, pace * math.max(dt, 0))
	local direction = flat.Unit
	local at = from + direction * walk
	return {
		position = Vector3.new(at.X, to.Y, at.Z),
		facing = direction,
		moved = walk,
		snapped = false,
	}
end

-- How high a hop is `t` seconds in (0 before it starts and after HOP_SECONDS).
function FollowLogic.hop(t: number): number
	if t <= 0 or t >= FollowLogic.HOP_SECONDS then
		return 0
	end
	return FollowLogic.HOP_HEIGHT * math.sin(math.pi * t / FollowLogic.HOP_SECONDS)
end

return FollowLogic
