--!strict
-- #2912 (Nov 11 read: 140 of 582 new players never start a stuck cat rescue after their first bait cat, the largest
-- stall of any step, and 127 leavers had first bait as their furthest step). From the first bait cat tamed or let go
-- until the account's first rescue starts:
--   the goal card reads "Free a stuck cat" (TITLE; NIGHT under it while the areas are shut),
--   the tutorial's marker and trail lead to the Alleyway's starter trap, the one nearest the camp, which keeps a cat
--     every day (#2794, #3049); in town they lead to the Cat Cannon first,
--   two step_time events say how far the player got (STEPS).
-- The pointer goes TRAIL_SECONDS after it first showed in a session, counted again once from the arrival in the
-- Alleyway (the client's clock, UIController). It reads only what the save already holds, so
-- it needs no save field: a player who has not rescued by Tier 2 never sees it again.
-- Pure.

local Onboarding = require(script.Parent.Onboarding)
local Types = require(script.Parent.Types)

local StuckGoal = {}

StuckGoal.AREA = "alley" -- where the starter trap is
StuckGoal.TITLE = "Free a stuck cat 🐾"
StuckGoal.NIGHT = "Stuck cats return at sunrise 🌅"
StuckGoal.NIGHT_NARROW = "Back at sunrise 🌅" -- on the phone's narrower card
StuckGoal.TOWN_LINE = "A cat is stuck in the Alleyway! Hop in the cannon"
StuckGoal.LINE = "A cat is stuck near the camp! Free it"
StuckGoal.LABEL = "Stuck cat"
StuckGoal.TRAIL_SECONDS = 120 -- the pointer goes this long after it first showed
StuckGoal.FOLLOWED_STUDS = 25 -- the player came this near the stuck cat: rescue_trail_followed
-- The step_time names (Telemetry.custom "step_time", field 1), each once a session.
StuckGoal.SHOWN = "rescue_trail_shown"
StuckGoal.FOLLOWED = "rescue_trail_followed"
StuckGoal.STEPS = { StuckGoal.SHOWN, StuckGoal.FOLLOWED }

-- Whether the save is between its first bait cat resolved and its first rescue started (and below Tier 2).
function StuckGoal.waiting(profile: Types.PlayerProfile): boolean
	local telemetry = profile.telemetry
	return profile.stats.rescues <= 0
		and Onboarding.reached(telemetry, "first_bait_resolved")
		and not Onboarding.reached(telemetry, "first_rescue_started")
		and not Onboarding.reached(telemetry, "tier_2")
end

-- Whether the pointer shows now: the server says the save waits, the player is not on a rescue bar or carrying, and
-- it first showed less than TRAIL_SECONDS ago (`shownFor` nil before it has).
function StuckGoal.active(waiting: boolean?, shownFor: number?, busy: boolean): boolean
	return waiting == true and not busy and (shownFor == nil or shownFor < StuckGoal.TRAIL_SECONDS)
end

export type Where = "none" | "cannon" | "cat"

-- What the pointer aims at for a player in wild area `area` (nil in town): nothing at night (the goal card says
-- why), the cannon from town or another area's camp, else the stuck cat.
function StuckGoal.where(area: string?, areasOpen: boolean): Where
	if not areasOpen then
		return "none"
	end
	return if area == StuckGoal.AREA then "cat" else "cannon"
end

-- Whether a player at `player` has come to the stuck cat at `cat` (flat distance).
function StuckGoal.followed(player: Vector3, cat: Vector3): boolean
	local dx, dz = player.X - cat.X, player.Z - cat.Z
	return math.sqrt(dx * dx + dz * dz) <= StuckGoal.FOLLOWED_STUDS
end

return StuckGoal
