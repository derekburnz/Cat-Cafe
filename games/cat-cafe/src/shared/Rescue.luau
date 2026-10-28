--!strict
-- The rescue minigames (data-model section 10b). Pure: times are numbers in server time
-- (Workspace:GetServerTimeNow()) and random rolls come from a passed function, so the specs are deterministic.
--
-- RescueBegin builds a challenge. Kind "bar" (trash bins, garbage bags, trash cans and the provisional traps): a
-- marker slides back and forth along a bar at RescueBarSpeed[rarity] bar lengths per second, and each press while
-- it is inside the zone (RescueZoneWidth[rarity] wide, plus RescueTolerance either side) is a hit that moves the
-- zone to its next spot. rescueHits[rarity] hits free the cat; each miss costs one of RescuePatience paws, and out
-- of paws ends the attempt. Kind "shake_catch" (a tree): rescueHits - 1 hits shake the branch, then the cat drops
-- and one catch circle (Common shrink time, the Pro Net's windows times the stuck cat's catchWindow, v0.13.15 F83)
-- must be Good or Perfect. The server stamps each press on arrival and takes off half the player's ping, as for a
-- catch circle.

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
}

-- A tree is shaken then caught; every other trap is a plain bar.
function Rescue.kind(trap: string): Types.RescueKind
	local kind: Types.RescueKind = if trap == "tree" then "shake_catch" else "bar"
	return kind
end

-- Bar hits the attempt needs: rescueHits on a bar, one fewer on a tree, whose catch circle is the last step.
function Rescue.hitsNeeded(rarity: Types.Rarity, kind: Types.RescueKind): number
	local hits = Catalog.rarities[rarity].rescueHits
	return math.max(1, if kind == "shake_catch" then hits - 1 else hits)
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

-- The marker at server time t.
function Rescue.markerAt(challenge: Types.RescueChallenge, t: number): number
	return RescueMarker.position(challenge.startsAt, challenge.phase or 0, challenge.speed or 1, t)
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
	local zones = Rescue.zones(hitsNeeded, width, roll)
	local phase = roll() * 2
	local waiting = RescueMarker.position(0, phase, 0, 0)
	if RescueMarker.inZone(waiting, zones[1], width, Config.RescueTolerance) then
		phase = if zones[1] > 0.5 then 0 else 1 -- the far end of the bar
	end
	return {
		kind = kind,
		startsAt = now + Config.CircleLeadInSeconds,
		phase = phase,
		speed = Config.RescueBarSpeed[rarity],
		zoneWidth = width,
		zones = zones,
		hitsNeeded = hitsNeeded,
		paws = Config.RescuePatience,
		endsAt = now + Config.RescueAttemptMaxSeconds,
	}
end

function Rescue.newAttempt(challenge: Types.RescueChallenge, rarity: Types.Rarity): Attempt
	return {
		challenge = challenge,
		rarity = rarity,
		hits = 0,
		paws = challenge.paws or Config.RescuePatience,
		stage = "bar",
		success = false,
		circle = nil,
	}
end

-- Judges a bar press at `pressTime` (latency corrected). Ignored before the marker moves, after the deadline and
-- outside the bar stage. A hit that completes a tree's shakes moves the attempt to "falling": the caller then
-- starts the circle with Rescue.startCircle.
function Rescue.pressBar(attempt: Attempt, pressTime: number): Press
	local challenge = attempt.challenge
	if attempt.stage ~= "bar" or pressTime < challenge.startsAt then
		return "ignored"
	end
	if challenge.endsAt ~= nil and pressTime > challenge.endsAt then
		return "ignored"
	end
	local zones = challenge.zones or {}
	local centre = zones[attempt.hits + 1]
	if centre == nil then
		return "ignored"
	end
	local position = Rescue.markerAt(challenge, pressTime)
	if RescueMarker.inZone(position, centre, challenge.zoneWidth or 0, Config.RescueTolerance) then
		attempt.hits += 1
		if attempt.hits >= (challenge.hitsNeeded or #zones) then
			if challenge.kind == "shake_catch" then
				attempt.stage = "falling"
			else
				attempt.stage = "done"
				attempt.success = true
			end
		end
		return "hit"
	end
	attempt.paws = math.max(0, attempt.paws - 1)
	if attempt.paws == 0 then
		attempt.stage = "done"
	end
	return "miss"
end

-- The tree's cat drops: one Common circle with the Pro Net's windows times the stuck cat's catchWindow (F83: 0.14
-- Good for a Common down to 0.078 for a Mythical), from server time `now`. Returns what the second RescueChallenge
-- sends.
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
