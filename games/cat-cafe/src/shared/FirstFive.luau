--!strict
-- #3098 (Derek2 2026-11-10: "a detailed funnel for things in the 2-5 minute range"): the "why" events beside the
-- onboarding funnel, for accounts below Tier 2 (Telemetry logs them; Monetization-Agent's plan,
-- first-five-minutes-funnel-plan-2026-11-10.md). Pure: the buckets, the step a player waits on and the field values.
-- - step_ready: when a step became possible (value the account's seconds of play), once a session per step:
--   table_afford (coins for the first table), bowl_afford (coins for the bait bowl), second_stray_up (a free stray
--   within STRAY_NEAR studs while the second cat is due). Fields: step, kind (coins or stray), device.
-- - step_stall: seconds since the furthest onboarding step with no new one, at each of STALL_BUCKETS, once per bucket
--   per awaited step a session, in the first STALL_WINDOW seconds of account play. Fields: the awaited step (the one
--   after the furthest), the bucket, and the last stuck nudge the client showed for it (HINTS).
-- - quit_snapshot: on leaving, value the session's seconds. Fields: the furthest step (as quit_state), the idle bucket
--   (no movement or report) and the screen open (SNAP_SCREENS) joined as one, e.g. "5-15 upgrades", and whether the
--   coins cover the next onboarding buy (yes, no, na).
-- P2:
-- - health_check: once a session at HEALTH_AT seconds in, value the client's frames a second; ping bucket (the
--   server's GetNetworkPing), memory bucket (the client's total MB), device.
-- - quick_return: on a join within QUICK_RETURN_SECONDS of the last leave, value the whole minutes away; the furthest
--   step, the minutes bucket (0-10, 10-30, 30-60), the session number bucket (2, 3, 4+).
-- - quit_cafe: beside quit_snapshot, value the session's seconds; cats working (0, 1, 2, 3+), table level (0, 1,
--   2+), cats owned (1, 2, 3, 4+).
-- P1b (Derek2 20:09: "track what exact step of tutorial scenes people leave on"):
-- - quit_scene: on leaving, value the session's seconds; the scene (SCENES, picked by `scene`), device, seconds
--   bucket (0-30, 30-60, 60-120, 120-300, 300+).

local Onboarding = require(script.Parent.Onboarding)
local Types = require(script.Parent.Types)

local FirstFive = {}

FirstFive.STALL_BUCKETS = { 30, 60, 120 }
FirstFive.STALL_WINDOW = 600 -- account seconds of play
FirstFive.STRAY_NEAR = 120 -- studs: a stray this close counts as "up" for the second cat
FirstFive.MOVE_STUDS = 2 -- moving this far between watch ticks counts as active
FirstFive.HINTS = { "pulse", "help_shown", "show_me", "none" } -- the stuck nudge kinds, or none
FirstFive.IDLE_LABELS = { "0-5", "5-15", "15-60", "60+" }
-- the UI's ScreenName to quit_snapshot's screen; any other open screen is "other"
FirstFive.SNAP_SCREENS = table.freeze({
	Store = "store",
	Upgrades = "upgrades",
	Collection = "index",
	Settings = "settings",
}) :: { [string]: string }

FirstFive.HEALTH_AT = 150 -- session seconds before the client measures
FirstFive.HEALTH_SAMPLE = 2 -- seconds of frames counted
FirstFive.FPS_MAX = 240
FirstFive.MEMORY_MAX = 65536 -- MB; a report above it is dropped
FirstFive.QUICK_RETURN_SECONDS = 3600

-- health_check's ping field for a round trip of `ms` milliseconds.
function FirstFive.pingBucket(ms: number): string
	if ms < 100 then
		return "lt100"
	elseif ms < 250 then
		return "100-250"
	end
	return "250+"
end

-- health_check's memory field for the client's `mb` in use.
function FirstFive.memoryBucket(mb: number): string
	if mb < 800 then
		return "lt800"
	elseif mb < 1500 then
		return "800-1500"
	end
	return "1500+"
end

-- quick_return's fields after the step: the minutes away bucket and the session number bucket.
function FirstFive.awayBucket(minutes: number): string
	if minutes < 10 then
		return "0-10"
	elseif minutes < 30 then
		return "10-30"
	end
	return "30-60"
end

function FirstFive.sessionBucket(sessions: number): string
	return if sessions <= 2 then "2" elseif sessions == 3 then "3" else "4+"
end

-- quit_cafe's counts: cats working, table level and cats owned, as their buckets.
function FirstFive.cafeFields(working: number, tables: number, owned: number): { string }
	return {
		if working >= 3 then "3+" else tostring(math.max(0, working)),
		if tables >= 2 then "2+" else tostring(math.max(0, tables)),
		if owned >= 4 then "4+" else tostring(math.max(1, owned)),
	}
end

-- quit_scene's scenes: where a beginner was when they left
FirstFive.SCENES = {
	"loading",
	"intro_start",
	"intro_shot_1",
	"intro_shot_2",
	"intro_shot_3",
	"intro_shot_4",
	"intro_shot_5",
	"intro_shot_6",
	"intro_shot_7",
	"intro_shot_8",
	"intro_shot_9",
	"intro_shot_10",
	"tut_0",
	"tut_1",
	"tut_3",
	"tut_4",
	"cannon_flight",
	"carry",
	"circle_open",
	"catch_prompt",
	"alley",
	"cafe",
	"other",
}

export type SceneFacts = {
	loaded: boolean, -- the onboarding step "loaded" is reached
	introSeen: boolean, -- the intro has played out or been skipped (profile.introSeen)
	introStep: string?, -- the intro funnel's furthest step name (Onboarding.INTRO_STEPS), nil before it started
	launching: boolean, -- in a cannon flight (the character's Launching)
	carrying: boolean, -- carrying a cat (the character's CarryingCatId)
	furthest: string, -- the furthest onboarding step (Onboarding.furthest)
	where: string, -- quit_state's where: "cafe", an area id or "none"
}

-- The scene a leaver was in, most specific first: loading, an intro shot while the intro runs, a cannon flight, a
-- carry, the catch circles or the catch prompt (the furthest step), a tutorial card still the furthest step, then
-- where they stood (the Alleyway, their cafe) or other.
function FirstFive.scene(facts: SceneFacts): string
	if not facts.loaded then
		return "loading"
	end
	local intro = facts.introStep
	if
		not facts.introSeen
		and intro ~= nil
		and intro ~= "intro_choice_made"
		and intro ~= "intro_done"
	then
		return if string.sub(intro, 1, 11) == "intro_shot_" then intro else "intro_start"
	end
	if facts.launching then
		return "cannon_flight"
	end
	if facts.carrying then
		return "carry"
	end
	local furthest = facts.furthest
	if furthest == "catch_started" or furthest == "first_circle_hit" then
		return "circle_open"
	elseif furthest == "near_stray" or furthest == "catch_card_opened" then
		return "catch_prompt"
	elseif furthest == "tut_0_shown" then
		return "tut_0"
	elseif furthest == "tut_1_shown" then
		return "tut_1"
	elseif furthest == "tut_3_shown" then
		return "tut_3"
	elseif furthest == "tut_4_shown" then
		return "tut_4"
	end
	if facts.where == "alley" then
		return "alley"
	elseif facts.where == "cafe" then
		return "cafe"
	end
	return "other"
end

-- quit_scene's seconds bucket.
function FirstFive.secondsBucket(seconds: number): string
	if seconds < 30 then
		return "0-30"
	elseif seconds < 60 then
		return "30-60"
	elseif seconds < 120 then
		return "60-120"
	elseif seconds < 300 then
		return "120-300"
	end
	return "300+"
end

-- quit_snapshot's idle field for `seconds` with no movement or report.
function FirstFive.idleBucket(seconds: number): string
	if seconds < 5 then
		return "0-5"
	elseif seconds < 15 then
		return "5-15"
	elseif seconds < 60 then
		return "15-60"
	end
	return "60+"
end

-- quit_snapshot's screen field for a screen report (`raw` as the client sent it, "none" when it closed).
function FirstFive.snapScreen(raw: string): string
	if raw == "none" then
		return "none"
	end
	return FirstFive.SNAP_SCREENS[raw] or "other"
end

-- The onboarding step after the furthest one (`furthest` an Onboarding.STEPS index), or nil past the last.
function FirstFive.awaited(furthest: number): string?
	return Onboarding.STEPS[furthest + 1]
end

-- The stall buckets `stalled` seconds has reached that `logged` hasn't, in order.
function FirstFive.newStalls(stalled: number, logged: { [number]: boolean }): { number }
	local out: { number } = {}
	for _, edge in FirstFive.STALL_BUCKETS do
		if stalled >= edge and not logged[edge] then
			table.insert(out, edge)
		end
	end
	return out
end

-- Which onboarding buy comes next for `state` ("tables", "lure_bowl", or nil when none is due): the first table once
-- the first customer is served and it isn't bought, then the bait bowl until it is.
function FirstFive.nextBuy(state: Types.TelemetryState): string?
	if not Onboarding.reached(state, "first_customer_served") then
		return nil
	end
	if not Onboarding.reached(state, "first_table") then
		return "tables"
	end
	if not Onboarding.reached(state, "bowl_bought") then
		return "lure_bowl"
	end
	return nil
end

-- quit_snapshot's afford field: na with no buy due, else yes or no for `coins` against its `cost` (nil when maxed).
function FirstFive.afford(buy: string?, coins: number, cost: number?): string
	if buy == nil or cost == nil then
		return "na"
	end
	return if coins >= cost then "yes" else "no"
end

-- Whether the second cat is the step due: the first cat is checked in and no second cat yet.
function FirstFive.secondCatDue(state: Types.TelemetryState): boolean
	return Onboarding.reached(state, "first_checkin")
		and not Onboarding.reached(state, "second_cat")
end

return FirstFive
