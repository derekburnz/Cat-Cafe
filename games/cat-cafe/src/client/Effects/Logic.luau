--!strict
-- The rules Effects follows with no Roblox services in them, so they can be unit tested: the device tier, which
-- cats and sources get the budget, catch grades, what a plot change means, and the motion curves for cats,
-- confetti and butterflies. Angles are radians, distances studs, times seconds.

local Presets = require(script.Parent.Presets)

local Logic = {}

export type Style =
	"nap"
	| "loaf"
	| "doze"
	| "stuck"
	| "stray"
	| "barista"
	| "waiter"
	| "greeter"
	| "entertainer"
	| "sit"
	| "lick"

-- Which body a cat has (Pose finds it): "walk" and "sit" are the bodies with hinged pieces (PR #259: walking A,
-- sitting B), "parts" the placeholder and older Part cats, which lie down by folding their legs themselves.
export type Body = "parts" | "walk" | "sit"

-- Turns and lifts for one cat at one moment. Pitch lifts the nose (or the front of the body), yaw turns left
-- and right, roll tilts sideways. tailPitch lifts the tail, a paw value swings that leg forward from the hip.
export type Offsets = {
	bodyY: number,
	belly: number, -- studs the top of the body rises as the belly fills with a breath (Pose swells the body parts)
	bodyPitch: number,
	bodyRoll: number,
	headPitch: number,
	headYaw: number,
	headRoll: number,
	tailPitch: number,
	tailYaw: number,
	pawFL: number,
	pawFR: number,
	pawBL: number,
	pawBR: number,
	sink: number, -- 0 standing, 1 lying on its belly (Pose turns it into studs from the cat's leg length)
	yarn: number, -- the entertainer's yarn ball, -1 (left) to 1 (right) in front of the cat
	-- How far into each of Model-Agent's piece poses (Presets.catPoses) the cat is, 0 to 1, on the bodies with
	-- hinged pieces. The idle's own turns ride on top.
	sleep: number,
	loaf: number,
	lick: number,
	blink: number, -- 0 eyes open, 1 shut
	earL: number, -- how far each ear is flicked back, radians
	earR: number,
}

export type Candidate<K> = { key: K, distance: number }

export type PlotChange = "claim" | "release" | "rankUp"
export type AreasTurn = "dusk" | "sunrise"

-- A phone or tablet (touch with no keyboard) gets the low budget.
function Logic.tier(touch: boolean, keyboard: boolean): Presets.Tier
	if touch and not keyboard then
		return "low"
	end
	return "high"
end

-- The player's Settings switches that effects follow, from ProfileSync `settings`: screen shake is on and Low
-- performance off until the player flips them, so a missing key or no settings at all keeps those.
function Logic.readSettings(settings: { [string]: unknown }?): (boolean, boolean)
	if settings == nil then
		return true, false
	end
	return settings.screenShake ~= false, settings.lowPerformance == true
end

-- The tier and budget effects run at: the device's own, or the Low performance budget on any device while that
-- setting is on. The tier reads "low" then, so what else scales by Effects.tier() (the street's customers)
-- comes down too.
function Logic.budgetFor(
	device: Presets.Tier,
	lowPerformance: boolean
): (Presets.Tier, Presets.Budget)
	if lowPerformance then
		return "low", Presets.budget.lowPerformance
	end
	return device, Presets.budget[device]
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

-- A timed state on a character, such as F55's `RushUntil` or F57's `StartledUntil` (the server time it ends), read
-- at server time `now` just after it changed from `previous`: the seconds it has left, never more than `longest`,
-- and whether it is a new one, so its start (the getaway ring, the startled bump) plays once. A change that only
-- moves the end of one still running is not new; anything but a number ahead of `now` has nothing left.
function Logic.timedState(
	ends: unknown,
	previous: unknown,
	now: number,
	longest: number
): (number, boolean)
	if type(ends) ~= "number" or ends <= now then
		return 0, false
	end
	local running = type(previous) == "number" and previous > now
	return math.min(ends - now, longest), not running
end

-- What a change of the Clock's `AreasOpen` (F66) means: "dusk" when the areas close, "sunrise" when they open,
-- nil when it is the first value this client sees or not a real true or false.
function Logic.areasTurn(previous: unknown, open: unknown): AreasTurn?
	if type(previous) ~= "boolean" or type(open) ~= "boolean" or previous == open then
		return nil
	end
	if open then
		return "sunrise"
	end
	return "dusk"
end

local function wave(t: number, seconds: number): number
	return math.sin(t * 2 * math.pi / seconds)
end

-- One breath every `seconds`, 0 (out) to 1 (in): a slow fill, a longer let-out, then a short rest before the next
-- (motion.breath), the way a sleeping cat's belly rises and falls rather than a plain sine.
function Logic.breath(t: number, seconds: number): number
	local b = Presets.motion.breath
	local into = (t / seconds) % 1
	if into < b.inhale then
		local k = into / b.inhale
		return k * k * (3 - 2 * k)
	elseif into < b.inhale + b.exhale then
		local k = (into - b.inhale) / b.exhale
		return 1 - k * k * (3 - 2 * k)
	end
	return 0
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
		belly = 0,
		bodyPitch = 0,
		bodyRoll = 0,
		headPitch = 0,
		headYaw = 0,
		headRoll = 0,
		tailPitch = 0,
		tailYaw = 0,
		pawFL = 0,
		pawFR = 0,
		pawBL = 0,
		pawBR = 0,
		sink = 0,
		yarn = 0,
		sleep = 0,
		loaf = 0,
		lick = 0,
		blink = 0,
		earL = 0,
		earR = 0,
	}
end

-- Blends two sets of offsets, k = 0 giving a and 1 giving b: a cat settling from one style into the next.
function Logic.mix(a: Offsets, b: Offsets, k: number): Offsets
	local out = Logic.blank()
	for key, value in a :: any do
		(out :: any)[key] = value + ((b :: any)[key] - value) * k
	end
	return out
end

-- Eyes and ears for a style at time t: blinks now and then, eyes shut asleep, and an ear flick now and then.
local function face(o: Offsets, style: Style, t: number)
	local m = Presets.motion
	local b = m.blink
	local asleep = style == "nap" or style == "doze"
	if asleep then
		o.blink = 1
	elseif style == "loaf" then
		-- half shut and content, with a slow blink
		o.blink = b.sleepy + (1 - b.sleepy) * Logic.pulse(t, b.every * 2, b.slowSeconds)
	elseif style == "lick" then
		o.blink = m.lick.eyes
	else
		o.blink = Logic.pulse(t, b.every, b.seconds)
	end
	local e = m.ears
	local pace = if asleep then 0.5 else 1
	o.earL = math.rad(e.twitch) * Logic.pulse(t * pace, e.everyL, e.seconds)
	o.earR = math.rad(e.twitch) * Logic.pulse(t * pace + 2.3, e.everyR, e.seconds)
end

-- The idle for a style at time t on a body (Logic.Body; none means "parts"). Every cat breathes, swishes its tail,
-- blinks and flicks its ears; the style adds the rest. On the bodies with hinged pieces a nap, loaf and paw lick
-- are Model-Agent's piece poses (sleep, loaf, lick) with the idle on top; the "parts" cats fold their own legs.
function Logic.idle(style: Style, t: number, body: Body?): Offsets
	local m = Presets.motion
	local o = Logic.blank()
	local pieces = body == "walk" or body == "sit"
	o.bodyY = (wave(t, m.breathe.seconds) * 0.5 + 0.5) * m.breathe.studs
	o.tailYaw = math.rad(m.tailSwish.degrees) * wave(t, m.tailSwish.seconds)
	face(o, style, t)
	if style == "nap" and pieces then
		-- Curled up asleep (manifest sleep): the pose lays it down and turns its head and tail; only the belly
		-- rising and falling with each slow breath and the tip of the tail move.
		o.sleep = 1
		o.bodyY = 0
		o.belly = Logic.breath(t, m.nap.seconds) * m.nap.breathe
		o.tailYaw *= 0.1
	elseif style == "loaf" and pieces then
		-- Tucked in and awake (manifest loaf): a slow breath and a slow look to one side and back now and then.
		local l = m.loaf
		o.loaf = 1
		o.bodyY = 0
		o.belly = Logic.breath(t, l.seconds) * l.breathe
		local side = if math.floor(t / l.lookEvery) % 2 == 0 then 1 else -1
		o.headYaw = math.rad(l.look) * side * Logic.pulse(t, l.lookEvery, l.lookSeconds)
		o.tailYaw *= 0.1
	elseif style == "lick" then
		-- Washing a paw (manifest lick): the paw is up at the mouth; in bursts the head bobs to it and the paw rubs.
		local k = m.lick
		o.lick = 1
		local cycle = k.strokes + k.pause
		local stroking = if t % cycle < k.strokes then 1 else 0
		local lap = math.sin(t * k.hz * 2 * math.pi) * stroking
		o.headPitch = -math.rad(k.bob) * (0.5 + 0.5 * lap)
		o.pawFL = math.rad(k.paw) * lap
		o.tailYaw *= 0.5
	elseif style == "nap" then
		-- Curled up: down on its belly, front paws out in front, back legs folded under, head tucked round to the
		-- left and the tail wrapped along the left side to meet it.
		o.sink = m.nap.sink
		o.bodyY = 0
		o.belly = Logic.breath(t, m.nap.seconds) * m.nap.breathe
		o.headPitch = -math.rad(m.nap.headDroop)
		o.headYaw = math.rad(m.nap.headTuck)
		o.tailYaw = -math.rad(m.nap.tailWrap) + o.tailYaw * 0.1
		o.pawFL = math.rad(90)
		o.pawFR = math.rad(90)
		o.pawBL = math.rad(90)
		o.pawBR = math.rad(90)
	elseif style == "loaf" then
		-- Tucked in and awake (Derek 2026-10-27, from draft E): down on its belly with every leg folded under and the
		-- front paws peeking out, head up and level, the tail laid along the right side. Very still: a slow breath,
		-- a slow look to one side and back every so often, and a quick flick of the head like an ear.
		local l = m.loaf
		o.sink = 1
		o.bodyY = 0
		o.belly = Logic.breath(t, l.seconds) * l.breathe
		local side = if math.floor(t / l.lookEvery) % 2 == 0 then 1 else -1
		o.headYaw = math.rad(l.look) * side * Logic.pulse(t, l.lookEvery, l.lookSeconds)
		o.headPitch = -math.rad(l.headDroop)
		o.headRoll = math.rad(l.flick) * Logic.pulse(t + 2, l.flickEvery, 0.2)
		o.tailYaw = math.rad(l.tailWrap) + o.tailYaw * 0.1
		o.pawFL = math.rad(90)
		o.pawFR = math.rad(90)
		o.pawBL = math.rad(90)
		o.pawBR = math.rad(90)
	elseif style == "doze" then
		-- Asleep where it sits or stands at its station at night (F25, F44, PR #262). The belly fills with each
		-- slow breath and the head lifts a little with it, the body sways a little and the tail hangs; no sink and
		-- no folded legs.
		local breath = Logic.breath(t, m.doze.seconds)
		o.bodyY = 0
		o.belly = breath * m.doze.breathe
		o.bodyRoll = math.rad(m.doze.sway) * wave(t, m.doze.seconds * 2.3)
		o.headPitch = -math.rad(m.doze.headDroop + m.doze.nod * (1 - 2 * breath))
		o.headRoll = -o.bodyRoll * 0.5
		o.tailYaw *= m.doze.tail
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

-- A steady number from 0 to 1 for a text key (a cat's Uid), so every player sees the same cat do the same thing
-- at the same moment without the server saying so.
function Logic.phaseOf(key: string): number
	local h = 0
	for i = 1, #key do
		h = (h * 31 + string.byte(key, i)) % 16777216
	end
	-- times the golden ratio, so keys a letter apart ("cat_1", "cat_2") still land far apart
	local spread = h * 0.6180339887498949
	return spread - math.floor(spread)
end

-- Whether a resting cafe cat is up in a loaf at server time `t`: for `hold` seconds out of every `every`, starting
-- at its own `phase` (0 to 1), so the cats in a cafe take turns rather than all sitting up at once.
function Logic.loafing(t: number, phase: number): boolean
	local l = Presets.motion.loaf
	return (t + phase * l.every) % l.every < l.hold
end

-- Whether a resting cat on the sitting body is washing a paw at server time `t`, the way Logic.loafing takes turns:
-- `hold` seconds out of every `every` (motion.lick), from its own `phase`.
function Logic.licking(t: number, phase: number): boolean
	local k = Presets.motion.lick
	return (t + phase * k.every) % k.every < k.hold
end

-- How long one breath takes in a style: slow asleep, a little slower again dozing or in a loaf.
function Logic.breathSeconds(style: Style): number
	local m = Presets.motion
	if style == "nap" then
		return m.nap.seconds
	elseif style == "doze" then
		return m.doze.seconds
	elseif style == "loaf" then
		return m.loaf.seconds
	end
	return m.breathe.seconds
end

-- One of the floating z's over a sleeping cat at time `t` (the same t as its idle, so the z's keep time with its
-- breath, every `seconds`): z number `index` of `count` takes every `count`th breath. It pops up small as the cat
-- breathes out, rises, grows and drifts to the right with a little sway over nap.life breaths, fades out at the
-- top and waits for its next turn, where it starts again from the bottom. Returns where it is in the z's box (0 to
-- 1 across from the left, 0 to 1 down from the top), its size (1 a full z), how see-through it is (1 hidden) and
-- its tilt in degrees.
function Logic.napZ(
	index: number,
	count: number,
	t: number,
	seconds: number
): (number, number, number, number, number)
	local z = Presets.nap
	local breaths = t / seconds - Presets.motion.breath.inhale -- counted from the first breath out
	local along = ((breaths - (index - 1)) % count) / z.life
	if along >= 1 then
		return z.x, z.y, z.size, 1, 0
	end
	local x = z.x + z.drift * along + z.sway * math.sin(along * 2 * math.pi)
	local y = z.y - z.rise * along
	local size = z.size + (1 - z.size) * along
	local fade = 0
	if along < z.fadeIn then
		fade = 1 - along / z.fadeIn
	elseif along > 1 - z.fadeOut then
		fade = (along - (1 - z.fadeOut)) / z.fadeOut
	end
	local tilt = z.tilt * math.sin(along * 2 * math.pi + 0.6)
	return x, y, size, fade, tilt
end

-- How far round a spin of the world wheel is after `k` (0 to 1) of its time: fast at first, easing to a stop.
function Logic.wheelEase(k: number): number
	local left = 1 - math.clamp(k, 0, 1)
	return 1 - left * left * left
end

-- Where the world wheel comes to rest after a spin at server time `at`, in radians from where the server placed
-- it: on the won slice when the station says which (`slice`, 1 to `slices`, slice 1 under the pointer at rest and
-- the rest counted round the way the wheel turns), somewhere inside it rather than dead centre, never near an
-- edge, so it can never seem to just miss a better prize. With no slice, anywhere. Every client works out the
-- same angle, so everyone sees the wheel stop in the same place.
function Logic.wheelRest(at: number, slice: number?, slices: number): number
	local jitter = Logic.phaseOf(string.format("%.3f", at))
	if slice == nil or slice ~= math.floor(slice) or slice < 1 or slice > slices then
		return jitter * 2 * math.pi
	end
	local inside = (jitter - 0.5) * Presets.wheel.landWithin
	return -((slice - 1) + inside) * 2 * math.pi / slices
end

-- The angle a spin turns to from `from`: `turns` whole turns, then on to `rest`, always forward.
function Logic.wheelTarget(from: number, rest: number, turns: number): number
	local tau = 2 * math.pi
	return from + turns * tau + (rest - from) % tau
end

-- How far the pointer is knocked aside, in degrees, at a wheel angle: `tilt` just as a slice edge passes it, back
-- to nothing `share` of a slice later.
function Logic.pointerTilt(angle: number, slices: number, tilt: number, share: number): number
	local into = (angle / (2 * math.pi / slices)) % 1
	return tilt * math.max(0, 1 - into / share)
end

-- Whether rim light `index` is on `t` seconds into a spin: every other one, stepping round each `step` seconds.
function Logic.chaseOn(index: number, t: number, step: number): boolean
	return (index + math.floor(t / step)) % 2 == 0
end

-- The leg a part of the body is ("pawFL", "pawFR", "pawBL" or "pawBR"), or nil. `at` is the part's centre in
-- the body part's own axes (the cat faces -Z, +X is its right), so a cat stood upright reads like one on all
-- fours. The exported cats name every body part like the body, legs included, so a leg is told by shape and place:
-- taller than it is wide, its top at or below the underside of the body, off the middle line.
function Logic.legOf(at: Vector3, size: Vector3, bodySize: Vector3): string?
	if size.Y < 1.2 * math.min(size.X, size.Z) then
		return nil
	end
	if at.Y + size.Y / 2 > 0.1 - bodySize.Y / 2 or math.abs(at.X) < 0.05 then
		return nil
	end
	local front = at.Z < 0
	if at.X > 0 then
		return if front then "pawFR" else "pawBR"
	end
	return if front then "pawFL" else "pawBL"
end

-- How far into a run a cat moving at `speed` studs a second is: 0 at a walk or standing, 1 at a full gallop.
function Logic.runFactor(speed: number): number
	local g = Presets.motion.gait
	return math.clamp((speed - g.runFrom) / (g.runFull - g.runFrom), 0, 1)
end

-- Studs a cat covers in one leg cycle at this speed; Pose counts cycles from the distance the server moves it.
function Logic.strideLength(speed: number): number
	local g = Presets.motion.gait
	return g.walkStride + (g.runStride - g.walkStride) * Logic.runFactor(speed)
end

-- Legs, bob and lean for a cat on the move, layered on the idle. `stride` counts leg cycles covered. Slow, it walks
-- the way cats do, one leg at a time (back left, front left, back right, front right, a quarter cycle apart), its
-- body swaying a little side to side, its head nodding with each step and its tail held up and swaying; from
-- gait.trotFrom it blends into a trot (diagonal legs together) and from gait.runFrom into a gallop (front legs
-- together, back legs half a cycle behind) with the body rocking, the head stretched forward and down and the tail
-- out straight behind.
function Logic.gait(o: Offsets, speed: number, stride: number)
	local g = Presets.motion.gait
	if speed < g.moveFrom then
		return
	end
	local start = math.clamp((speed - g.moveFrom) / g.moveFrom, 0, 1) -- eases in from a standstill
	local run = Logic.runFactor(speed)
	local trot = math.clamp((speed - g.trotFrom) / (g.trotFull - g.trotFrom), 0, 1)
	local walk = 1 - trot -- the one-leg-at-a-time walk
	trot *= 1 - run
	local phase = stride * 2 * math.pi
	local s = math.sin(phase)
	local quarter = math.pi / 2
	local swing = math.rad(g.walkSwing + (g.runSwing - g.walkSwing) * run) * start
	o.pawFL += swing * (walk * math.sin(phase - quarter) + trot * s + run * s)
	o.pawFR += swing * (walk * math.sin(phase - 3 * quarter) - trot * s + run * math.sin(
		phase + 0.3
	))
	o.pawBL += swing * (walk * s - trot * s + run * math.sin(phase + math.pi))
	o.pawBR += swing * (walk * math.sin(phase - math.pi) + trot * s + run * math.sin(
		phase + math.pi + 0.3
	))
	local stepBob = g.walkBob * (0.5 - 0.5 * math.cos(2 * phase)) -- two steps a cycle
	local gallopBob = g.runBob * (0.5 + 0.5 * math.cos(phase))
	o.bodyY += ((1 - run) * stepBob + run * gallopBob) * start
	local rock = math.rad(g.runRock) * s * run
	o.bodyPitch += rock
	o.bodyRoll += math.rad(g.walkRoll) * s * walk * start
	local steady = (1 - run) * start
	o.headPitch += -rock * 0.6 - math.rad(g.runHead) * run + math.rad(g.walkNod) * math.sin(
		2 * phase
	) * steady
	o.headRoll -= math.rad(g.walkRoll) * s * walk * start * 0.6 -- the head stays level as the body sways
	o.headYaw *= 1 - g.lookAhead * start -- on the move it mostly looks where it is going
	o.tailPitch += math.rad(8) * run + math.rad(g.walkTail) * steady
	o.tailYaw = o.tailYaw * (1 - 0.8 * run) + math.rad(g.tailSway) * math.sin(phase + 1) * steady
end

-- An action's weight at `alpha` (0 to 1 of the action): 0 until `start`, easing up to 1 by `full`, holding to
-- `hold`, easing back to 0 by `stop`.
function Logic.envelope(
	alpha: number,
	start: number,
	full: number,
	hold: number,
	stop: number
): number
	if alpha <= start or alpha >= stop then
		return 0
	elseif alpha < full then
		local k = (alpha - start) / (full - start)
		return k * k * (3 - 2 * k)
	elseif alpha <= hold then
		return 1
	end
	local k = (stop - alpha) / (stop - hold)
	return k * k * (3 - 2 * k)
end

-- How long a cat takes to settle from one style into the next: lying down is slow, getting up a little quicker,
-- anything else motion.settle.
function Logic.settleSeconds(from: Style?, to: Style): number
	local m = Presets.motion
	local down = to == "nap" or to == "loaf"
	local wasDown = from == "nap" or from == "loaf"
	if down and not wasDown then
		return m.settleDown
	elseif wasDown and not down then
		return m.settleUp
	end
	return m.settle
end

-- A stretch, layered on the idle while `alpha` runs from 0 to 1 (motion.stretch; Cats plays one as a stray gets up
-- from a nap to walk off, and now and then while a stray stands still). On all fours (the walking body and the older
-- Part cats) the cat gets up from wherever it lay, bows with its front legs out ahead, chest low, rear up and tail
-- up, lifting its head in a yawn with its eyes shut, then rocks forward and stretches each back leg out behind in
-- turn, and settles back. A seated cat is not going anywhere, so it does not stretch (Derek 2026-10-27). `weight`
-- (1 if not given) scales it all, so a stray that sets off mid-stretch can let it go smoothly.
function Logic.stretch(o: Offsets, alpha: number, body: Body?, weight: number?)
	if alpha < 0 or alpha >= 1 or body == "sit" then
		return
	end
	local s = Presets.motion.stretch
	local w = math.clamp(weight or 1, 0, 1)
	local up = Logic.envelope(alpha, 0, s.rise, 1 - s.rise, 1) * w
	o.sleep *= 1 - up
	o.loaf *= 1 - up
	o.lick *= 1 - up
	o.sink *= 1 - up
	o.belly *= 1 - up
	local bow = Logic.envelope(alpha, 0.08, 0.3, 0.48, 0.62) * w
	local rearL = Logic.envelope(alpha, 0.5, 0.6, 0.68, 0.78) * w
	local rearR = Logic.envelope(alpha, 0.66, 0.76, 0.84, 0.94) * w
	local rock = math.max(rearL, rearR)
	local pitch = -math.rad(s.bow) * bow + math.rad(s.rock) * rock
	o.bodyPitch += pitch
	o.bodyY -= s.drop * bow -- the body turns about its middle, so drop it to keep the back feet down
	-- front legs reach out ahead in the bow, then stand straight under the chest
	o.pawFL += math.rad(s.reach) * bow - math.rad(s.rock) * rock
	o.pawFR += math.rad(s.reach) * bow - math.rad(s.rock) * rock
	-- back legs stay upright under the raised rear, then each stretches out behind
	o.pawBL += -pitch - math.rad(s.rear) * rearL
	o.pawBR += -pitch - math.rad(s.rear) * rearR
	o.headPitch += -pitch * s.headLevel + math.rad(s.yawn) * bow
	o.tailPitch += math.rad(s.tail) * math.max(bow, rock * 0.5)
	o.tailYaw *= 1 - bow
	o.blink = math.max(o.blink, bow)
	o.earL = math.max(o.earL, math.rad(s.ears) * bow)
	o.earR = math.max(o.earR, math.rad(s.ears) * bow)
end

-- Catching its breath after a sprint: quick shallow breaths, head low, tail down. Replaces the idle's breathing.
function Logic.pant(o: Offsets, t: number)
	local p = Presets.motion.pant
	o.bodyY = (wave(t, p.seconds) * 0.5 + 0.5) * p.studs
	o.headPitch = -math.rad(p.headDown)
	o.headYaw *= 0.3
	o.tailPitch = -math.rad(p.tailDown)
	o.tailYaw *= 0.4
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
