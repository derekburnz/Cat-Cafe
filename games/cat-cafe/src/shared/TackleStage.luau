--!strict
-- The tackling lesson's staged scene (#2312, Derek2: "the cut scene for explaining tackling doesn't actually take
-- control of your camera like tutorial so it doesn't show you it properly"). Pure: where the two stand-ins walk and
-- lunge and where the camera looks in each of the lesson's four shots, worked out from a viewpoint on the ground and
-- the flat way it faces. IntroController.stageTackle plays it in the Alleyway, just past its way in (#2446), not at
-- the player's feet.
--   shot 1  a carrier (a copy of you with a cat in its arms) walks across; another copy waits off to one side
--   shot 2  the other copy lunges (from LUNGE_AT for LUNGE_SECONDS) and knocks the carrier back; the cat drops
--   shot 3  over the shoulder of the tackler, the carrier walking by with its cat again: the tackler (you) lunges,
--           knocks it, walks to the dropped cat and picks it up (#2469)
--   shot 4  the knocked copy swings its net at a new cat beside it; the net pins the cat with its "!" (StagedStray,
--           NetDown) while the tackler stands by holding its cat: you are safe while catching (#2469)
-- Studs and seconds, y up.

local TackleStage = {}

TackleStage.SHOTS = 4
TackleStage.AHEAD = 14 -- the scene's centre, this far in front of the player
TackleStage.WALK_FROM = -7 -- the carrier's walk across, along the player's right, from and to (studs from the centre)
TackleStage.WALK_TO = 3
TackleStage.WALK_SPEED = 5 -- studs a second
TackleStage.TACKLER_AT = Vector3.new(5, 0, 6) -- the tackler's spot: right, up and ahead of the centre (local studs)
TackleStage.LUNGE_AT = 0.9 -- shot 2: when the lunge starts (#2468: after the 0.6 s camera glide has settled)
TackleStage.LUNGE_SECONDS = 0.45
TackleStage.KNOCK_STUDS = 4 -- how far the hit pushes the carrier
TackleStage.DROP_SIDE = 2.5 -- the dropped cat lands this far to the carrier's side
-- #2468 (Derek2: "make the tackle scene from the right angle so you can see them being hit and dropping cat"): shot
-- 2 looks side on at the hit, square to the knock, from the player's side of the walk, this far out and up from the
-- middle of the lunge, the hit, the knocked carrier and the dropped cat. It used to sit along the knock, so the
-- carrier flew at the camera and hid the cat.
TackleStage.HIT_SHOT_OUT = 13
TackleStage.HIT_SHOT_UP = 5
-- #2469 (Derek2: "show ... your character actually tackling them, also show them taking the cat"): shot 3's tackler
-- waits PICKUP_PAUSE after the knock, then walks at PICKUP_SPEED to a stud short of the dropped cat and takes it.
TackleStage.PICKUP_PAUSE = 0.3
TackleStage.PICKUP_SPEED = 8
-- #2469 (Derek2: "for the 'your safe while catching a cat' a scene with someone using their net with the
-- exclamation mark"): shot 4's new cat sits CATCH_STUDS to the knocked copy's left; the copy swings at SWING_AT and
-- the net is down on the cat (its "!" up) from PIN_AT, seconds into the shot.
TackleStage.CATCH_STUDS = 3
TackleStage.SWING_AT = 0.7
TackleStage.PIN_AT = 1.05
TackleStage.STRAY_TAG = "StagedStray" -- on shot 4's cat: Effects/NetPin and UI's CatchMark treat it as a stray
TackleStage.SWING_ATTRIBUTE = "SmackAt" -- server time on the staged copy: Effects swings its net from then

export type Key = { position: Vector3, look: Vector3 }
export type Scene = {
	centre: Vector3,
	right: Vector3, -- flat unit vectors
	forward: Vector3,
	walkFrom: Vector3, -- ground points
	walkTo: Vector3,
	tackler: Vector3,
	hit: Vector3, -- where the lunge meets the carrier
	knock: Vector3, -- flat unit: the way the hit pushes the carrier
	knocked: Vector3, -- where the carrier ends up
	drop: Vector3, -- where its cat lands
	stop: Vector3, -- where the lunge ends
	pickup: Vector3, -- where the tackler stands to take the cat (shot 3)
	catchAt: Vector3, -- shot 4's new cat
	cameras: { Key }, -- one per shot
}

local UP = Vector3.new(0, 1, 0)

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 1e-6 then f.Unit else Vector3.new(0, 0, -1)
end

-- The scene in front of a player standing on `ground`, facing `facing`.
function TackleStage.scene(ground: Vector3, facing: Vector3): Scene
	local forward = flat(facing)
	local right = Vector3.new(-forward.Z, 0, forward.X) -- forward x up, flat and unit
	local centre = ground + forward * TackleStage.AHEAD
	local function at(x: number, z: number): Vector3
		return centre + right * x + forward * z
	end
	local walkFrom = at(TackleStage.WALK_FROM, 0)
	local walkTo = at(TackleStage.WALK_TO, 0)
	local tackler = at(TackleStage.TACKLER_AT.X, TackleStage.TACKLER_AT.Z)
	local mid = (walkFrom + walkTo) / 2
	local hit = TackleStage.hitPoint(walkFrom, walkTo)
	-- shot 2's side-on view (#2468): square to the knock, on the player's side, over the whole moment
	local knock = flat(hit - tackler)
	local side = Vector3.new(-knock.Z, 0, knock.X)
	if side:Dot(forward) > 0 then
		side = -side
	end
	local knocked = hit + knock * TackleStage.KNOCK_STUDS
	local drop = hit - forward * TackleStage.DROP_SIDE
	local moment = (tackler + hit + knocked + drop) / 4
	local stop = hit + flat(tackler - hit) * 1
	local pickup = drop + flat(stop - drop) * 1
	local catchAt = knocked - right * TackleStage.CATCH_STUDS
	local catchMid = (knocked + catchAt) / 2
	return {
		centre = centre,
		right = right,
		forward = forward,
		walkFrom = walkFrom,
		walkTo = walkTo,
		tackler = tackler,
		hit = hit,
		knock = knock,
		knocked = knocked,
		drop = drop,
		stop = stop,
		pickup = pickup,
		catchAt = catchAt,
		cameras = {
			-- 1: from where the player stands, a little up, over the walk
			{ position = ground + UP * 7 - forward * 2, look = mid + UP * 2 },
			-- 2: side on to the hit, so the lunge, the knock and the cat dropping all cross the screen
			{
				position = moment + side * TackleStage.HIT_SHOT_OUT + UP * TackleStage.HIT_SHOT_UP,
				look = moment + UP * 1.5,
			},
			-- 3: over the tackler's shoulder toward the walk, the lunge, the drop and the pick-up ahead of it
			{
				position = tackler + (tackler - mid).Unit * 5 + right * 1.5 + UP * 6,
				look = mid + UP * 2,
			},
			-- 4: from the player's side, low, on the catch, with the tackler and its cat in the same frame
			{
				position = catchMid - forward * 11 + right * 2 + UP * 5,
				look = (catchMid * 2 + pickup) / 3 + UP * 1,
			},
		},
	}
end

-- Where the carrier is `t` seconds into its walk (it stops at walkTo).
function TackleStage.walkAt(from: Vector3, to: Vector3, t: number): Vector3
	local length = (to - from).Magnitude
	if length < 1e-6 then
		return to
	end
	local k = math.clamp(t * TackleStage.WALK_SPEED / length, 0, 1)
	return from:Lerp(to, k)
end

-- Where the lunge meets the carrier: on its walk when the lunge lands, given shot 2 restarts the walk.
function TackleStage.hitPoint(from: Vector3, to: Vector3): Vector3
	return TackleStage.walkAt(from, to, TackleStage.LUNGE_AT + TackleStage.LUNGE_SECONDS)
end

-- The tackler's ground point `t` seconds into shot 2: waiting, then lunging to the hit point, then on the ground there.
function TackleStage.lungeAt(scene: Scene, t: number): Vector3
	-- it stops a stud short, facing the carrier
	local k = math.clamp((t - TackleStage.LUNGE_AT) / TackleStage.LUNGE_SECONDS, 0, 1)
	return scene.tackler:Lerp(scene.stop, k)
end

-- When shot 3's tackler starts its walk to the dropped cat, and when it gets there and takes it, in seconds.
function TackleStage.pickupTimes(scene: Scene): (number, number)
	local from = TackleStage.LUNGE_AT + TackleStage.LUNGE_SECONDS + TackleStage.PICKUP_PAUSE
	return from, from + (scene.pickup - scene.stop).Magnitude / TackleStage.PICKUP_SPEED
end

-- The tackler's ground point `t` seconds into shot 3, and whether it has the cat: the lunge as in shot 2, then the walk
-- to the cat.
function TackleStage.pickupAt(scene: Scene, t: number): (Vector3, boolean)
	local from, taken = TackleStage.pickupTimes(scene)
	if t < from then
		return TackleStage.lungeAt(scene, t), false
	end
	local k = if taken > from then math.clamp((t - from) / (taken - from), 0, 1) else 1
	return scene.stop:Lerp(scene.pickup, k), t >= taken
end

return TackleStage
