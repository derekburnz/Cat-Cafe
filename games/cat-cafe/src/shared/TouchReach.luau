--!strict
-- #3556: a touch player's Net button reaches further. The server's swing reach stays as it is for everyone (a wider
-- reach would hand a mouse player the Long Net for free, and the server never trusts a "this is a phone" claim), so
-- on a touch screen the client shows the glow and the Net button from SHARE times the swing's reach, and a press
-- there walks the character the last steps and swings once the stray is truly in reach. Pure rules, no instances:
-- Controllers/NetSwingController drives them, behind the live switch `touchCatchReach` (off by default).
--   FLAG, SHARE, WALK_SECONDS, FOLLOW_SECONDS, TELEMETRY
--   reach(extra?)                     how far the touch glow and button reach, in studs
--   pick(origin, targets, extra?)     the nearest target inside that reach, or nil
--   walking(elapsed, canSwing)        whether a walk goes on

local Config = require(script.Parent.Config)
local NetSwing = require(script.Parent.NetSwing)

local TouchReach = {}

TouchReach.FLAG = "touchCatchReach"
TouchReach.SHARE = 1.5 -- of NetSwing.reach
TouchReach.WALK_SECONDS = 2.5 -- a walk that has not reached the stray by now ends without a swing
-- #4041: after the walk's swing the character keeps walking at the stray this long, so the root is where
-- NetSwing.landingOrigin said it would be when the net lands (stopping at the press left it short and missed)
TouchReach.FOLLOW_SECONDS = Config.NetSmackDelay + 0.15
TouchReach.TELEMETRY = "catch_reach" -- TelemetryReport name; values "near" and "shown"
TouchReach.NEAR_STUDS = 20 -- "near": this close to any free stray, on any device

function TouchReach.reach(extra: number?): number
	return NetSwing.reach(extra) * TouchReach.SHARE
end

-- The nearest of `targets` within the touch reach on the ground plane, whichever way the player faces, and within
-- NetSwing.BEGINNER_RISE up or down, so a cat up on a perch never starts a walk into a wall.
function TouchReach.pick(
	origin: Vector3,
	targets: { NetSwing.Target },
	extra: number?
): NetSwing.Target?
	local reach = TouchReach.reach(extra)
	local best: NetSwing.Target? = nil
	local bestDistance = math.huge
	for _, target in targets do
		local offset = target.position - origin
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if
			flat <= reach
			and math.abs(offset.Y) <= NetSwing.BEGINNER_RISE
			and flat < bestDistance
		then
			best = target
			bestDistance = flat
		end
	end
	return best
end

-- True when any of `targets` is within NEAR_STUDS on the ground plane.
function TouchReach.near(origin: Vector3, targets: { NetSwing.Target }): boolean
	for _, target in targets do
		local offset = target.position - origin
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= TouchReach.NEAR_STUDS then
			return true
		end
	end
	return false
end

-- Whether a walk that began `elapsed` seconds ago goes on: only while a swing could still go and inside
-- WALK_SECONDS.
function TouchReach.walking(elapsed: number, canSwing: boolean): boolean
	return canSwing and elapsed >= 0 and elapsed < TouchReach.WALK_SECONDS
end

return TouchReach
