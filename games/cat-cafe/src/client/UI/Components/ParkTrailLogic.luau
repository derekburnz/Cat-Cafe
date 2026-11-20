--!strict
-- #3554 (Nov 11 read: 1 in 5 players who reach Tier 2 never make a first Park catch): after Tier 2 the goal card
-- reads "Visit the Park 🐾" and a trail of paw prints (Effects/PawTrail over the tutorial's GuideTrail) runs from
-- the player to the nearest Cat Cannon, the way to the Park. #3893: reaching the Park ends it (it went on to "Catch a
-- Park cat 🐾" and a trail to the nearest free stray before). Paw prints only: no arrow, no timer, no
-- words about missing out. Left alone for REST_AFTER seconds the trail rests; it comes back once the player has
-- stood still for IDLE_BACK seconds. The first Park cat ends it for good (the collection says so: no save change).
-- Behind the `parkGateTrail` switch, off by default. Pure, so the specs test it; Controllers/ParkTrailController
-- runs it.
--   due(on, tier, caught, visited) -> boolean whether the goal and trail apply to this player now
--   reached(caught, visited) -> boolean       the first steps are done, up to the Park (#3893)
--   phase(area) -> "visit" | "catch"          by where the player is
--   goal(phase) -> string                     the goal card's line
--   rest() -> Rest, step(rest, dt, moving, back?) -> boolean   the trail's rest and return; true while it may show
--   restart(rest)                              the phase changed: the trail gets its full time again

local ParkTrailLogic = {}

ParkTrailLogic.FLAG = "parkGateTrail" -- shared/LiveFlags
ParkTrailLogic.AREA = "park"
ParkTrailLogic.TIER = 2 -- the Park opens at Tier 2
ParkTrailLogic.VISIT = "Visit the Park 🐾"
ParkTrailLogic.CATCH = "Catch a Park cat 🐾"
ParkTrailLogic.REST_AFTER = 120
ParkTrailLogic.IDLE_BACK = 20
-- #5045 (v8 read Nov 17: 12% of Tier 2 players never reach the Park, and most who do take 3 to 10 minutes): a player
-- who keeps walking never stands still for IDLE_BACK seconds, so after REST_AFTER the trail was gone for good. Behind
-- the `parkTrailBack` switch (off by default) a rest also ends after BACK_AFTER seconds, walking or not.
ParkTrailLogic.BACK_FLAG = "parkTrailBack"
ParkTrailLogic.BACK_AFTER = 30
ParkTrailLogic.BACK = "back" -- TelemetryReport park_trail value: the trail came back after a rest, once a session
ParkTrailLogic.STRAY_RANGE = 400 -- studs: any free stray in the Park, the nearest first
ParkTrailLogic.TELEMETRY = "park_trail" -- TelemetryReport values: SHOWN, ENTERED, CAUGHT, each once a session
ParkTrailLogic.SHOWN = "shown"
ParkTrailLogic.ENTERED = "entered"
ParkTrailLogic.CAUGHT = "caught"

-- #5517 (Design's fix spec, switch `hoodTrail`, off by default): the same walk again at Tier 3 for the Neighbourhood.
-- Only at Tier 3 exactly, until the first Neighbourhood landing (the server's HoodLanded attribute, or this join) or
-- a Neighbourhood cat. The trail leads to the nearest cannon, the picker lists the Neighbourhood first with its ring,
-- and at night the goal line says when it opens. Same rest rules, with parkTrailBack's return always on.
--   hoodDue(on, tier, owns, landed) -> boolean   hoodGoal(shut, narrow) -> string
ParkTrailLogic.HOOD_FLAG = "hoodTrail"
ParkTrailLogic.HOOD_AREA = "neighbourhood"
ParkTrailLogic.HOOD_TIER = 3
ParkTrailLogic.HOOD_VISIT = "Visit the Neighbourhood 🐾"
ParkTrailLogic.HOOD_VISIT_NARROW = "Visit Neighbourhood 🐾"
ParkTrailLogic.HOOD_NIGHT = "Neighbourhood opens at sunrise"
ParkTrailLogic.HOOD_LANDED_ATTR = "HoodLanded" -- the Player's attribute (server, from shared/Tier3Trip's mask)
ParkTrailLogic.HOOD_TELEMETRY = "hood_trail" -- TelemetryReport values: SHOWN, ENTERED, each once a session

function ParkTrailLogic.hoodDue(on: boolean, tier: number?, owns: boolean, landed: boolean): boolean
	return on and not owns and not landed and tier == ParkTrailLogic.HOOD_TIER
end

function ParkTrailLogic.hoodGoal(shut: boolean, narrow: boolean): string
	if shut then
		return ParkTrailLogic.HOOD_NIGHT
	end
	return if narrow then ParkTrailLogic.HOOD_VISIT_NARROW else ParkTrailLogic.HOOD_VISIT
end

export type Phase = "visit" | "catch"
export type Rest = { active: number, idle: number, resting: boolean, off: number }

-- `on` is the switch, `tier` the cafe's tier, `caught` whether a Park cat is in the collection, `visited` whether the
-- player has been in the Park this join. #3893 (Derek 2026-11-13: "remove the getting first cat at park have that just
-- end tutorial there when park has been visited"): the walk ends on reaching the Park, with no "Catch a Park cat"
-- phase after it.
function ParkTrailLogic.due(on: boolean, tier: number?, caught: boolean, visited: boolean?): boolean
	return on
		and not caught
		and visited ~= true
		and type(tier) == "number"
		and tier >= ParkTrailLogic.TIER
end

-- #3893: whether the player's first steps are done, up to reaching the Park: the tutorial's X hides the strip only
-- after this.
function ParkTrailLogic.reached(caught: boolean, visited: boolean): boolean
	return caught or visited
end

function ParkTrailLogic.phase(area: string?): Phase
	return if area == ParkTrailLogic.AREA then "catch" else "visit"
end

function ParkTrailLogic.goal(phase: Phase): string
	return if phase == "catch" then ParkTrailLogic.CATCH else ParkTrailLogic.VISIT
end

function ParkTrailLogic.rest(): Rest
	return { active = 0, idle = 0, resting = false, off = 0 }
end

function ParkTrailLogic.restart(rest: Rest)
	rest.active, rest.idle, rest.resting, rest.off = 0, 0, false, 0
end

-- `dt` seconds on, `moving` whether the character is walking, `back` the parkTrailBack switch. Returns whether the
-- trail may show.
function ParkTrailLogic.step(rest: Rest, dt: number, moving: boolean, back: boolean?): boolean
	if rest.resting then
		rest.idle = if moving then 0 else rest.idle + dt
		rest.off += dt
		if
			rest.idle >= ParkTrailLogic.IDLE_BACK
			or (back == true and rest.off >= ParkTrailLogic.BACK_AFTER)
		then
			ParkTrailLogic.restart(rest)
		end
	else
		rest.active += dt
		if rest.active >= ParkTrailLogic.REST_AFTER then
			rest.resting = true
			rest.idle = 0
			rest.off = 0
		end
	end
	return not rest.resting
end

return ParkTrailLogic
