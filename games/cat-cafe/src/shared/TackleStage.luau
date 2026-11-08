--!strict
-- The tackling lesson's staged scene (#2312, Derek2: "the cut scene for explaining tackling doesn't actually take
-- control of your camera like tutorial so it doesn't show you it properly"). Pure: where the two stand-ins walk and
-- lunge and where the camera looks in each of the lesson's four shots, worked out from a viewpoint on the ground and
-- the flat way it faces. IntroController.stageTackle plays it in the Alleyway, just past its way in (#2446), not at
-- the player's feet.
--   shot 1  a carrier (a copy of you with a cat in its arms) walks across; another copy waits off to one side
--   shot 2  the other copy lunges (from LUNGE_AT for LUNGE_SECONDS) and knocks the carrier back; the cat drops
--   shot 3  over the shoulder of the tackler, the carrier walking by with its cat again: "this is you tackling"
--   shot 4  the camera pulls up over the scene
-- Studs and seconds, y up.

local TackleStage = {}

TackleStage.SHOTS = 4
TackleStage.AHEAD = 14 -- the scene's centre, this far in front of the player
TackleStage.WALK_FROM = -7 -- the carrier's walk across, along the player's right, from and to (studs from the centre)
TackleStage.WALK_TO = 3
TackleStage.WALK_SPEED = 5 -- studs a second
TackleStage.TACKLER_AT = Vector3.new(5, 0, 6) -- the tackler's spot: right, up and ahead of the centre (local studs)
TackleStage.LUNGE_AT = 0.6 -- shot 2: when the lunge starts
TackleStage.LUNGE_SECONDS = 0.45
TackleStage.KNOCK_STUDS = 4 -- how far the hit pushes the carrier
TackleStage.DROP_SIDE = 2.5 -- the dropped cat lands this far to the carrier's side

export type Key = { position: Vector3, look: Vector3 }
export type Scene = {
	centre: Vector3,
	right: Vector3, -- flat unit vectors
	forward: Vector3,
	walkFrom: Vector3, -- ground points
	walkTo: Vector3,
	tackler: Vector3,
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
	return {
		centre = centre,
		right = right,
		forward = forward,
		walkFrom = walkFrom,
		walkTo = walkTo,
		tackler = tackler,
		cameras = {
			-- 1: from where the player stands, a little up, over the walk
			{ position = ground + UP * 7 - forward * 2, look = mid + UP * 2 },
			-- 2: closer, side on to the lunge
			{ position = hit - right * 9 - forward * 6 + UP * 5, look = hit + UP * 2 },
			-- 3: over the tackler's shoulder toward the walk
			{
				position = tackler + (tackler - mid).Unit * 5 + right * 1.5 + UP * 6,
				look = mid + UP * 2,
			},
			-- 4: up and back over the whole scene
			{ position = centre - forward * 12 + UP * 16, look = centre },
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
	local hit = TackleStage.hitPoint(scene.walkFrom, scene.walkTo)
	-- it stops a stud short, facing the carrier
	local stop = hit + (scene.tackler - hit).Unit * 1
	local k = math.clamp((t - TackleStage.LUNGE_AT) / TackleStage.LUNGE_SECONDS, 0, 1)
	return scene.tackler:Lerp(stop, k)
end

return TackleStage
