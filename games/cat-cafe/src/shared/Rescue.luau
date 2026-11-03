--!strict
-- The rescue minigames (data-model section 10b). Pure: times are numbers in server time
-- (Workspace:GetServerTimeNow()) and random rolls come from a passed function, so the specs are deterministic.
--
-- RescueBegin builds a challenge. Kind "bar" (trash bins, garbage bags, trash cans and the provisional traps): a
-- marker slides back and forth along a bar at RescueBarSpeed[rarity] bar lengths per second, and each press while
-- it is inside the zone (RescueZoneWidth[rarity] wide, plus RescueTolerance either side) is a hit that moves the
-- zone to its next spot. rescueHits[rarity] hits free the cat; each miss costs one of RescuePatience paws, and out
-- of paws ends the attempt. Kind "shake_catch" (a tree): the same bar, each hit shaking the branch; the last one frees
-- the cat. With Config.RescueTreeCircle on (off since Derek 2026-11-03), rescueHits - 1 hits shake the branch, then
-- the cat drops and one catch circle (Common shrink time, the Pro Net's windows times the stuck cat's catchWindow,
-- v0.13.15 F83) must be Good or Perfect. The server stamps each press on arrival and takes off half the player's
-- ping, as for a catch circle.
--
-- F93 (catch-rework.md section 4): every hit makes the marker RescueSpeedUpPerHit faster from where it is, and a press
-- in the zone is always a hit. RescueResult carries the RescueBar (barState) so the client draws the same. Derek
-- 2026-11-03 ("bars going in circles and stuff is a little confusing"): a zone stays where it is until it is hit, so
-- only a miss costs a paw; the RescueBar's zoneEndsAt is the attempt's deadline (the zone's draining edge is its
-- timer).
--
-- F92 (playing-together.md section 3): Team Rescue. One helper can join a running bar (addHelper): the attempt gets
-- TeamRescueExtraSeconds on its deadline, the helper's hits count like the rescuer's and a helper's miss costs no paw
-- (pressBar's `helper`), so a helper can never make a rescue fail. The helper's tip is helperTip, once per
-- TeamRescueTipCooldown (helperTipReady).

local Catalog = require(script.Parent.Catalog)
local Circles = require(script.Parent.Circles)
local Config = require(script.Parent.Config)
local RescueMarker = require(script.Parent.RescueMarker)
local Types = require(script.Parent.Types)

local Rescue = {}

Rescue.CIRCLE_NET_LEVEL = 2 -- the falling cat's circle uses the Pro Net's windows whatever net the player owns
Rescue.MIN_ZONE_STEP = 0.25 -- each zone sits at least this far from the one before, so a hit visibly moves it

-- "bar" until the hits are in; "falling" between a tree's last shake and its circle; "circle" while the falling
-- cat's circle runs; "done" once the attempt is over, with `success` saying how.
export type Stage = "bar" | "falling" | "circle" | "done"
export type Press = "hit" | "miss" | "ignored"

export type Attempt = {
	challenge: Types.RescueChallenge, -- the bar
	rarity: Types.Rarity, -- the stuck cat's, for the falling cat's circle (F83)
	hits: number,
	paws: number,
	stage: Stage,
	success: boolean,
	circle: Circles.Attempt?, -- the tree's falling cat, once the shakes are done
	-- F93: the marker runs from markerAt (server time) at markerPhase and `speed`; each hit starts it again from
	-- where it is, faster. zones[zone] is the one to hit. lastPressAt keeps presses in order.
	markerAt: number,
	markerPhase: number,
	speed: number,
	zone: number,
	lastPressAt: number,
	helped: boolean?, -- F92: a helper has joined (one an attempt, even after they left)
}

-- A tree shakes on every hit (and, with RescueTreeCircle, ends with a catch); every other trap is a plain bar.
function Rescue.kind(trap: string): Types.RescueKind
	local kind: Types.RescueKind = if trap == "tree" then "shake_catch" else "bar"
	return kind
end

-- Bar hits the attempt needs: rescueHits, or one fewer on a tree while RescueTreeCircle makes its catch circle the
-- last step.
function Rescue.hitsNeeded(rarity: Types.Rarity, kind: Types.RescueKind): number
	local hits = Catalog.rarities[rarity].rescueHits
	return math.max(1, if kind == "shake_catch" and Config.RescueTreeCircle then hits - 1 else hits)
end

-- Zone centres for `count` hits, each inside the bar and at least MIN_ZONE_STEP from the one before.
function Rescue.zones(count: number, width: number, roll: () -> number): { number }
	local low, high = width / 2, 1 - width / 2
	local zones: { number } = {}
	local previous: number? = nil
	for _ = 1, count do
		local centre = low + roll() * (high - low)
		if previous ~= nil then
			-- uniform over what is left of the bar either side of the last zone
			local left = math.max(0, previous - Rescue.MIN_ZONE_STEP - low)
			local right = math.max(0, high - previous - Rescue.MIN_ZONE_STEP)
			if left + right > 0 then
				local r = roll() * (left + right)
				centre = if r < left then low + r else previous + Rescue.MIN_ZONE_STEP + (r - left)
			end
		end
		table.insert(zones, centre)
		previous = centre
	end
	return zones
end

-- The marker of a fresh challenge at server time t, before any hit.
function Rescue.markerAt(challenge: Types.RescueChallenge, t: number): number
	return RescueMarker.position(challenge.startsAt, challenge.phase or 0, challenge.speed or 1, t)
end

-- The marker of a running attempt at server time t, after its hits so far.
function Rescue.marker(attempt: Attempt, t: number): number
	return RescueMarker.position(attempt.markerAt, attempt.markerPhase, attempt.speed, t)
end

-- The zone the attempt waits on now (its centre on the bar), or nil once there is none left.
function Rescue.currentZone(attempt: Attempt): number?
	return (attempt.challenge.zones or {})[attempt.zone]
end

-- The attempt's deadline in server time (later once a helper joins): when its zone's time runs out too.
function Rescue.endsAt(attempt: Attempt): number
	return attempt.challenge.endsAt or (attempt.challenge.startsAt + Config.RescueAttemptMaxSeconds)
end

-- What RescueResult sends (F93): how the marker runs now and which zone to hit (zoneEndsAt is the deadline).
function Rescue.barState(attempt: Attempt): Types.RescueBar
	return {
		zone = attempt.zone,
		startsAt = attempt.markerAt,
		phase = attempt.markerPhase,
		speed = attempt.speed,
		zoneEndsAt = Rescue.endsAt(attempt),
		endsAt = attempt.challenge.endsAt, -- F92: later once a helper joins
	}
end

-- A new bar for a cat of `rarity` at a trap of type `trap`, from server time `now`. The marker waits at its phase
-- for CircleLeadInSeconds, and never waits inside the first zone, where a press at the start would be free.
function Rescue.newChallenge(
	rarity: Types.Rarity,
	trap: string,
	now: number,
	roll: () -> number
): Types.RescueChallenge
	local kind: Types.RescueKind = Rescue.kind(trap)
	local width = Config.RescueZoneWidth[rarity]
	local hitsNeeded = Rescue.hitsNeeded(rarity, kind)
	local zones = Rescue.zones(hitsNeeded, width, roll) -- one per hit: a zone stays until it is hit
	local endsAt = now + Config.RescueAttemptMaxSeconds
	local phase = roll() * 2
	local waiting = RescueMarker.position(0, phase, 0, 0)
	if RescueMarker.inZone(waiting, zones[1], width, Config.RescueTolerance) then
		phase = if zones[1] > 0.5 then 0 else 1 -- the far end of the bar
	end
	local startsAt = now + Config.CircleLeadInSeconds
	local speed = Config.RescueBarSpeed[rarity]
	return {
		kind = kind,
		startsAt = startsAt,
		phase = phase,
		speed = speed,
		zoneWidth = width,
		zones = zones,
		hitsNeeded = hitsNeeded,
		paws = Config.RescuePatience,
		endsAt = endsAt,
		zone = 1,
		zoneEndsAt = endsAt,
		speedUpPerHit = Config.RescueSpeedUpPerHit,
	}
end

function Rescue.newAttempt(challenge: Types.RescueChallenge, rarity: Types.Rarity): Attempt
	local speed = challenge.speed or 1
	return {
		challenge = challenge,
		rarity = rarity,
		hits = 0,
		paws = challenge.paws or Config.RescuePatience,
		stage = "bar",
		success = false,
		circle = nil,
		markerAt = challenge.startsAt,
		markerPhase = challenge.phase or 0,
		speed = speed,
		zone = 1,
		lastPressAt = challenge.startsAt,
	}
end

-- Judges a bar press at `pressTime` (latency corrected). Ignored before the marker moves, after the deadline and
-- outside the bar stage. A hit restarts the marker from where it is RescueSpeedUpPerHit faster and moves to the next
-- zone; the last hit frees the cat, or with RescueTreeCircle completes a tree's shakes and moves the attempt to
-- "falling": the caller then starts the circle with Rescue.startCircle. A miss costs a paw and leaves the zone where
-- it is, unless the press is a Team Rescue helper's (F92): theirs costs nothing.
function Rescue.pressBar(attempt: Attempt, pressTime: number, helper: boolean?): Press
	local challenge = attempt.challenge
	if attempt.stage ~= "bar" or pressTime < challenge.startsAt then
		return "ignored"
	end
	if challenge.endsAt ~= nil and pressTime > challenge.endsAt then
		return "ignored"
	end
	-- a press never lands before one already judged (a ping that dropped between them)
	local at = math.max(pressTime, attempt.lastPressAt)
	local centre = Rescue.currentZone(attempt)
	if centre == nil then
		return "ignored"
	end
	attempt.lastPressAt = at
	local position = Rescue.marker(attempt, at)
	if RescueMarker.inZone(position, centre, challenge.zoneWidth or 0, Config.RescueTolerance) then
		attempt.hits += 1
		attempt.markerPhase =
			RescueMarker.phaseAt(attempt.markerAt, attempt.markerPhase, attempt.speed, at)
		attempt.markerAt = at
		attempt.speed *= 1 + Config.RescueSpeedUpPerHit
		attempt.zone += 1
		if attempt.hits >= (challenge.hitsNeeded or #(challenge.zones or {})) then
			if challenge.kind == "shake_catch" and Config.RescueTreeCircle then
				attempt.stage = "falling"
			else
				attempt.stage = "done"
				attempt.success = true
			end
		end
		return "hit"
	end
	if helper == true then
		return "miss"
	end
	attempt.paws = math.max(0, attempt.paws - 1)
	if attempt.paws == 0 then
		attempt.stage = "done"
	end
	return "miss"
end

-- F92: a helper joins the running bar. Refused (false) once the attempt has had a helper, or past the bar stage (a
-- tree's falling cat is the rescuer's to catch). The deadline moves TeamRescueExtraSeconds later.
function Rescue.addHelper(attempt: Attempt): boolean
	if attempt.helped == true or attempt.stage ~= "bar" then
		return false
	end
	attempt.helped = true
	local challenge = attempt.challenge
	if challenge.endsAt ~= nil then
		challenge.endsAt = (challenge.endsAt :: number) + Config.TeamRescueExtraSeconds
		challenge.zoneEndsAt = challenge.endsAt
	end
	return true
end

-- F92: what RescueChallenge sends a helper: the same bar as it runs now (the marker from its last restart, the zone
-- to hit, paws left, hits so far, the later deadline), marked `helper`.
function Rescue.helperChallenge(attempt: Attempt): Types.RescueChallenge
	local challenge = attempt.challenge
	return {
		kind = challenge.kind,
		startsAt = attempt.markerAt,
		phase = attempt.markerPhase,
		speed = attempt.speed,
		zoneWidth = challenge.zoneWidth,
		zones = challenge.zones,
		hitsNeeded = challenge.hitsNeeded,
		paws = attempt.paws,
		endsAt = challenge.endsAt,
		zone = attempt.zone,
		zoneEndsAt = Rescue.endsAt(attempt),
		speedUpPerHit = challenge.speedUpPerHit,
		helper = true,
		hits = attempt.hits,
	}
end

-- F92: the helper's tip for a freed cat, HelperTipSeconds of the helper's own day rate, twice that between pals.
function Rescue.helperTip(dayRate: number, pals: boolean): number
	local seconds = Config.HelperTipSeconds * (if pals then 2 else 1)
	return math.floor(math.max(dayRate, 0) * seconds)
end

-- F92: whether a helper's tip may pay at `now`, TeamRescueTipCooldown after the last one (nil: never paid).
function Rescue.helperTipReady(lastTipAt: number?, now: number): boolean
	return lastTipAt == nil or now - lastTipAt >= Config.TeamRescueTipCooldown
end

-- The tree's cat drops: one Common circle with the Pro Net's windows times the stuck cat's catchWindow (F83; since
-- F93 0.17 Good for a Common down to 0.093 for a Mythical), from server time `now`. Returns what the second
-- RescueChallenge sends.
function Rescue.startCircle(
	attempt: Attempt,
	now: number,
	roll: () -> number
): Types.RescueChallenge
	assert(attempt.stage == "falling", "the shakes are not done")
	local windows = Circles.windowsFor(Rescue.CIRCLE_NET_LEVEL, attempt.rarity)
	local circle = Circles.schedule("Common", Rescue.CIRCLE_NET_LEVEL, now, roll)[1]
	local circleAttempt = Circles.newAttempt({ circle }, windows)
	attempt.circle = circleAttempt
	attempt.stage = "circle"
	return {
		kind = "circle",
		startsAt = circle.startsAt,
		circle = circle,
		windows = Circles.publicWindows(windows),
		endsAt = Circles.deadline(circle, windows),
	}
end

-- Judges a press on the falling cat's circle. Returns the grade, or nil when the press is ignored (too early, or
-- the circle is over). Good or Perfect frees the cat; a Miss ends the attempt and the cat climbs back up.
function Rescue.pressCircle(attempt: Attempt, pressTime: number, now: number): Types.CircleGrade?
	local circle = attempt.circle
	if attempt.stage ~= "circle" or circle == nil then
		return nil
	end
	local grade: Types.CircleGrade? = Circles.press(circle, 1, pressTime, now)
	if Circles.isDone(circle) then -- judged, or expired before this press arrived
		attempt.stage = "done"
		attempt.success = Circles.succeeded(circle)
	end
	return grade
end

-- The next server time the attempt can run out on its own: the bar's deadline plus the latency allowance, or the
-- circle's deadline. nil while falling (the caller starts the circle at once) or when done.
function Rescue.deadline(attempt: Attempt): number?
	if attempt.stage == "bar" then
		local endsAt = attempt.challenge.endsAt
		return if endsAt ~= nil then endsAt + Config.CatchLatencyCapSeconds else nil
	elseif attempt.stage == "circle" and attempt.circle ~= nil then
		return Circles.nextDeadline(attempt.circle)
	end
	return nil
end

-- Ends the attempt as a fail once its deadline has passed by `now`. Returns true when it ended here.
function Rescue.expire(attempt: Attempt, now: number): boolean
	local deadline = Rescue.deadline(attempt)
	if deadline == nil or now <= deadline then
		return false
	end
	if attempt.stage == "circle" and attempt.circle ~= nil then
		Circles.expire(attempt.circle, now)
	end
	attempt.stage = "done"
	attempt.success = false
	return true
end

-- Ends the attempt as a fail now (Give up, walking away, dying, leaving).
function Rescue.abandon(attempt: Attempt)
	attempt.stage = "done"
	attempt.success = false
end

return Rescue
