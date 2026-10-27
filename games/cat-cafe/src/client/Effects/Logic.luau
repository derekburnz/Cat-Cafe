--!strict
-- The rules Effects follows with no Roblox services in them, so they can be unit tested: the device tier, which
-- cats and sources get the budget, catch grades, what a plot change means, and the motion curves for cats,
-- confetti and butterflies. Angles are radians, distances studs, times seconds.

local Presets = require(script.Parent.Presets)

local Logic = {}

export type Style =
	"nap"
	| "stuck"
	| "stray"
	| "barista"
	| "waiter"
	| "greeter"
	| "entertainer"
	| "sit"

-- Turns and lifts for one cat at one moment. Pitch lifts the nose (or the front of the body), yaw turns left
-- and right, roll tilts sideways. tailPitch lifts the tail, a paw value swings that front paw forward.
export type Offsets = {
	bodyY: number,
	bodyPitch: number,
	bodyRoll: number,
	headPitch: number,
	headYaw: number,
	headRoll: number,
	tailPitch: number,
	tailYaw: number,
	pawFL: number,
	pawFR: number,
	yarn: number, -- the entertainer's yarn ball, -1 (left) to 1 (right) in front of the cat
}

export type Candidate<K> = { key: K, distance: number }

export type PlotChange = "claim" | "release" | "rankUp"

-- A phone or tablet (touch with no keyboard) gets the low budget.
function Logic.tier(touch: boolean, keyboard: boolean): Presets.Tier
	if touch and not keyboard then
		return "low"
	end
	return "high"
end

-- One circle from CatchResult: "perfect", "good" or "miss" (catching v0.4), or the v0.3 score 1, 0.5 or 0.
export type Grade = string | number

-- CatchResult's success flag. v0.4 sends (strayId, grades, success, pawsLeft, charmGain); v0.3 sent (strayId,
-- scores, chance, success, stayed). Both are read until catching v0.4 (engineer PR #71) is on main.
function Logic.catchSucceeded(third: any, fourth: any): boolean
	if type(third) == "boolean" then
		return third
	end
	return fourth == true
end

-- A Purrfect: every circle Perfect.
function Logic.isPurrfect(grades: { Grade }): boolean
	if #grades == 0 then
		return false
	end
	for _, grade in grades do
		if grade ~= "perfect" and grade ~= 1 then
			return false
		end
	end
	return true
end

-- The keys of the nearest `limit` candidates within `radius`, nearest first.
function Logic.nearest<K>(candidates: { Candidate<K> }, radius: number, limit: number): { K }
	local inRange: { Candidate<K> } = {}
	for _, candidate in candidates do
		if candidate.distance <= radius then
			table.insert(inRange, candidate)
		end
	end
	table.sort(inRange, function(a: Candidate<K>, b: Candidate<K>): boolean
		return a.distance < b.distance
	end)
	local keys: { K } = {}
	for i = 1, math.min(limit, #inRange) do
		keys[i] = inRange[i].key
	end
	return keys
end

-- What a change of a plot's OwnerUserId or Tier means. `sinceOwnerChange` is how long ago the owner last
-- changed: a claim sets OwnerUserId and Tier in the same server step but they can replicate a frame apart, so a
-- Tier rise right after a claim is the new owner's saved tier, not a rank up.
function Logic.plotChange(
	prevOwner: number,
	prevTier: number,
	owner: number,
	tier: number,
	sinceOwnerChange: number
): PlotChange?
	if owner ~= prevOwner then
		if owner == 0 then
			return "release"
		end
		return "claim"
	end
	if
		owner ~= 0
		and prevTier >= 1
		and tier > prevTier
		and sinceOwnerChange >= Presets.rankUp.claimGrace
	then
		return "rankUp"
	end
	return nil
end

-- The gates that open when this player's cafe goes from prevTier to tier.
function Logic.newlyOpen<K>(requires: { [K]: number }, prevTier: number, tier: number): { K }
	local opened: { K } = {}
	for key, needed in requires do
		if prevTier < needed and tier >= needed then
			table.insert(opened, key)
		end
	end
	return opened
end

local function wave(t: number, seconds: number): number
	return math.sin(t * 2 * math.pi / seconds)
end

-- 0 most of the time; once every `every` seconds it rises to 1 and back over `length` seconds.
function Logic.pulse(t: number, every: number, length: number): number
	local into = t % every
	if into >= length then
		return 0
	end
	return math.sin(into / length * math.pi)
end

function Logic.blank(): Offsets
	return {
		bodyY = 0,
		bodyPitch = 0,
		bodyRoll = 0,
		headPitch = 0,
		headYaw = 0,
		headRoll = 0,
		tailPitch = 0,
		tailYaw = 0,
		pawFL = 0,
		pawFR = 0,
		yarn = 0,
	}
end

-- The idle for a style at time t. Every cat breathes and swishes its tail; the style adds the rest.
function Logic.idle(style: Style, t: number): Offsets
	local m = Presets.motion
	local o = Logic.blank()
	o.bodyY = (wave(t, m.breathe.seconds) * 0.5 + 0.5) * m.breathe.studs
	o.tailYaw = math.rad(m.tailSwish.degrees) * wave(t, m.tailSwish.seconds)
	if style == "nap" then
		o.bodyY = (wave(t, m.nap.seconds) * 0.5 + 0.5) * m.nap.breathe
		o.headPitch = -math.rad(m.nap.headDroop)
		o.tailYaw *= 0.2
	elseif style == "stuck" then
		local struggle = Logic.pulse(t, m.stuck.every, m.stuck.seconds)
		o.headYaw = math.rad(m.stuck.shake) * math.sin(t * 40) * struggle
		o.bodyRoll = math.rad(m.stuck.shake * 0.4) * math.sin(t * 30) * struggle
		o.tailYaw *= 1.6
	elseif style == "stray" then
		o.headYaw = math.rad(m.headLook.degrees) * wave(t, m.headLook.seconds)
		o.headPitch = math.rad(m.headLook.degrees * 0.3) * wave(t, m.headLook.seconds * 0.7)
	elseif style == "barista" then
		local tap = Logic.pulse(t, m.barista.tapEvery, 0.4)
		o.headPitch = -math.rad(m.barista.headDip) * tap
		o.pawFL = math.rad(m.barista.paw) * tap
	elseif style == "waiter" then
		local sway = wave(t, m.waiter.swaySeconds)
		o.bodyRoll = math.rad(m.waiter.sway) * sway
		o.bodyY += math.abs(sway) * m.waiter.step
		o.headRoll = -o.bodyRoll * 0.6
	elseif style == "greeter" then
		local greet = Logic.pulse(t, m.greeter.waveEvery, 1.2)
		o.pawFR = math.rad(m.greeter.wave) * greet * (0.75 + 0.25 * math.sin(t * 16))
		o.headRoll = math.rad(m.greeter.tilt) * greet
	elseif style == "entertainer" then
		o.pawFL = math.rad(m.entertainer.swat) * Logic.pulse(t, m.entertainer.swatEvery, 0.35)
		o.yarn = wave(t, m.entertainer.swatEvery * 2)
		o.headYaw = math.rad(18) * o.yarn
	else
		o.headYaw = math.rad(m.headLook.degrees * 0.6) * wave(t, m.headLook.seconds)
	end
	return o
end

-- The hiss on a missed catch, layered on the idle while `alpha` runs from 0 to 1: the cat rears and hops back
-- with its head pulled back and its tail straight up.
function Logic.hiss(o: Offsets, alpha: number)
	if alpha < 0 or alpha >= 1 then
		return
	end
	local h = Presets.motion.hiss
	local arc = math.sin(alpha * math.pi)
	o.bodyY += h.hop * arc
	o.bodyPitch += math.rad(12) * arc
	o.headPitch += math.rad(h.headBack) * arc
	o.tailPitch += math.rad(h.tailUp) * arc
	o.tailYaw *= 1 - arc
end

-- How much of a server jump is still drawn as distance left to travel: 1 at the jump, 0 on landing.
function Logic.landing(alpha: number): number
	local a = math.clamp(alpha, 0, 1)
	return 1 - a * a * (3 - 2 * a)
end

-- Where a confetti piece is `t` seconds after launch, relative to where it started. Linear drag with gravity:
-- it shoots up, slows, then drifts down near its terminal speed (gravity / drag) with a little sway.
function Logic.confettiOffset(velocity: Vector3, t: number, phase: number): Vector3
	local c = Presets.confetti
	local k = c.drag
	local slow = 1 - math.exp(-k * t)
	local terminal = c.gravity / k
	local y = (velocity.Y + terminal) / k * slow - terminal * t
	local sway = math.sin(t * 6 + phase) * c.flutter * math.min(1, t)
	return Vector3.new(velocity.X / k * slow + sway, y, velocity.Z / k * slow)
end

-- A butterfly's loop around its flowers: its offset at time t and its wing angle.
function Logic.butterfly(t: number, phase: number): (Vector3, number)
	local b = Presets.butterfly
	local roam = b.roam
	local offset = Vector3.new(
		math.sin(t * 0.7 + phase) * roam.X,
		b.height + math.sin(t * 1.3 + phase * 2) * roam.Y,
		math.sin(t * 0.9 + phase * 3) * roam.Z
	)
	local flap = math.rad(b.flapDegrees) * math.sin(t * b.flapHz * 2 * math.pi + phase)
	return offset, flap
end

return Logic
