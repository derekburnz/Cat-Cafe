--!strict
-- The net swing (F93, catch-rework.md section 1). Every character carries its net; a click, R2 or the Net button
-- sends SwingNet with no arguments, and NetSmackDelay after it arrives, when the net lands, the server judges where
-- the character stands and faces. Pure: positions, times and the stray list are passed in, so the server's judge,
-- this client's in-reach glow and the specs all use the same rule.

local Catalog = require(script.Parent.Catalog)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local NetSwing = {}

-- A cat closer than this on the ground plane is at the swinger's feet: in reach whichever way they face. #2693: was 1.
NetSwing.FEET_STUDS = 1.5
-- A swing may arrive this much sooner than NetSwingCooldown after the last one, for the ping wobble between two
-- presses the client spaced a full cooldown apart.
NetSwing.COOLDOWN_SLACK = 0.1

-- One stray the swing could land on: its id and where its body is.
export type Target = { id: string, position: Vector3 }

-- What the server knows when a SwingNet arrives or lands.
export type SwingCheck = {
	carrying: boolean, -- the net is away while a cat is in the arms
	busy: boolean, -- in a catch or a rescue
	inFlight: boolean, -- a Cat Cannon flight or a cloud hop (F84)
	inCamp: boolean, -- a camp is a safe zone (F84)
	inTown: boolean?, -- on the Town Square, where the net is put away (Derek 2026-11-03)
	sinceSwing: number?, -- seconds since this player's last swing, nil for the first
}

-- How far a swing reaches from the root: NetReachStuds plus NetSlackStuds for the latency, plus `extra` studs (#2565:
-- the Long Net's, NetSwing.extraFor).
function NetSwing.reach(extra: number?): number
	return Config.NetReachStuds + Config.NetSlackStuds + (extra or 0)
end

-- #2565: the extra reach a player's Mystery Market items give: the Long Net's LongNetReachStuds over NetReachStuds.
function NetSwing.extraFor(owned: { [string]: boolean }?): number
	if owned ~= nil and owned.long_net == true then
		return math.max(0, Config.LongNetReachStuds - Config.NetReachStuds)
	end
	return 0
end

-- True when `point` is in the swing from a root at `origin` facing `look`: within reach in 3D, so a cat up on a perch
-- stays out of reach from the ground, and within NetArcDegrees either side of the facing on the ground plane.
-- #2693 (Derek2: easier to hit on mobile): within NetNearStuds of the feet the arc is NetNearArcDegrees, and within
-- NetFrontArcDegrees of straight ahead the reach is NetFrontExtraStuds longer. The client's glow reads this too.
function NetSwing.inReach(origin: Vector3, look: Vector3, point: Vector3, extra: number?): boolean
	local offset = point - origin
	local reach = NetSwing.reach(extra)
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude < NetSwing.FEET_STUDS then
		return offset.Magnitude <= reach
	end
	local facing = Vector3.new(look.X, 0, look.Z)
	if facing.Magnitude < 1e-3 then
		return false
	end
	local cos = flat.Unit:Dot(facing.Unit)
	if cos >= math.cos(math.rad(Config.NetFrontArcDegrees)) - 1e-9 then
		reach += Config.NetFrontExtraStuds
	end
	if offset.Magnitude > reach then
		return false
	end
	local arc = if flat.Magnitude <= Config.NetNearStuds
		then Config.NetNearArcDegrees
		else Config.NetArcDegrees
	return cos >= math.cos(math.rad(arc)) - 1e-9
end

-- Where the server will judge a swing pressed now from a root at `position` moving at `velocity`: the root carried
-- on along the ground for NetSmackDelay, as the net lands that long after the press (the press's trip to the server
-- and the character's trip back cancel out). The client's glow and landing marker swing from here.
function NetSwing.landingOrigin(position: Vector3, velocity: Vector3): Vector3
	return position + Vector3.new(velocity.X, 0, velocity.Z) * Config.NetSmackDelay
end

-- The landing marker's outer edge (Derek 2026-11-03): `slices` + 1 points on the ground plane round a root at the
-- origin facing -Z (the root's flat space, +X to its right), from NetArcDegrees to its left to NetArcDegrees to its
-- right, NetReachStuds out. NetSlackStuds stays off the marker, so everything it covers lands even on a slow
-- connection.
function NetSwing.fanPoints(slices: number): { Vector3 }
	local arc = math.rad(Config.NetArcDegrees)
	local points: { Vector3 } = {}
	for index = 0, slices do
		local angle = -arc + 2 * arc * index / slices
		table.insert(
			points,
			Vector3.new(
				Config.NetReachStuds * math.sin(angle),
				0,
				-Config.NetReachStuds * math.cos(angle)
			)
		)
	end
	return points
end

-- The nearest of `targets` the swing lands on, or nil. The caller leaves out strays that are sprinting, catching
-- their breath or locked by another player.
function NetSwing.pick(origin: Vector3, look: Vector3, targets: { Target }, extra: number?): Target?
	local best: Target? = nil
	local bestDistance = math.huge
	for _, target in targets do
		if NetSwing.inReach(origin, look, target.position, extra) then
			local distance = (target.position - origin).Magnitude
			if distance < bestDistance then
				best = target
				bestDistance = distance
			end
		end
	end
	return best
end

-- True when a free stray at `point` is near enough a swing that hit nothing to hop away: within NetMissHopStuds of
-- the root on the ground plane, whichever way the player faces.
function NetSwing.nearMiss(origin: Vector3, point: Vector3): boolean
	local flat = Vector3.new(point.X - origin.X, 0, point.Z - origin.Z)
	return flat.Magnitude <= Config.NetMissHopStuds
end

-- How far a stray of `rarity` hops after a near miss: NetMissHopShare of its fleeStuds (6 studs for a Common up to
-- 16 for a Mythical).
function NetSwing.hopStuds(rarity: Types.Rarity): number
	return Catalog.rarities[rarity].fleeStuds * Config.NetMissHopShare
end

-- Whether a miss makes nearby cats hop for a player at `tutorialStep`: a player who has not caught a cat yet never
-- does, so the first catch stays easy (easy-start.md section 2b; the step the tutorial stray waits for).
function NetSwing.missHops(tutorialStep: number): boolean
	return tutorialStep >= Config.TutorialGuaranteedStrayStep
end

-- Why this swing does nothing, as a short reason (for the specs and the Studio log), or nil when it swings. The
-- client checks the same before it plays the smack, so a refused swing is rare and gets no answer.
function NetSwing.refusal(check: SwingCheck): string?
	if check.carrying then
		return "carrying"
	end
	if check.busy then
		return "busy"
	end
	if check.inFlight then
		return "flight"
	end
	if check.inCamp then
		return "camp"
	end
	if check.inTown == true then
		return "town"
	end
	if
		check.sinceSwing ~= nil
		and check.sinceSwing < Config.NetSwingCooldown - NetSwing.COOLDOWN_SLACK
	then
		return "cooldown"
	end
	return nil
end

-- The net_swing analytics result (catch-rework.md section 5): "hit", or a miss with ("miss_near") or without
-- ("miss_empty") a free stray within NetMissHopStuds.
function NetSwing.result(hit: boolean, nearCats: number): string
	if hit then
		return "hit"
	end
	return if nearCats > 0 then "miss_near" else "miss_empty"
end

return NetSwing
