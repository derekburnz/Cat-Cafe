--!strict
-- The onboarding funnels, each step logged once per player and only in order. Pure. Roblox marks every earlier step
-- complete when a later one is logged, so a player who ranks up before setting bait would fake the bait steps. A step
-- reached early is held in `achieved` until every step before it is logged (analytics-plan 3.2, data-model section 14
-- `telemetry`).
--
-- Version 3 (#1273, easy-start.md section 5): `onboarding_v3`, 37 steps that split the first ten minutes finely
-- (loading, each tutorial card, the first catch in eleven steps, the first cafe loop) and keep v2's later steps. It
-- replaces `onboarding_v2` outright (Derek 2026-11-04); v2's data stays in Creator Hub under its own name. The intro
-- cutscene is optional since F87 (Config.IntroAutoPlay off), so its steps are a funnel of their own,
-- `onboarding_v3_intro`: in the main funnel a player who never plays it would hold every later step.
--
-- IMPLIES: a step the server sees proves the steps it lists were passed (a catch is started in reach of a stray), so
-- reaching it reaches them first. Only server steps imply anything: a step a client reports (CLIENT_STEPS) is reached
-- by itself and can never move a server step. A save from funnel v1 or v2 that is past its first catch leaves the
-- funnel (fromOld): the funnel is for new players, and a veteran would log the first minutes it never replays.

local Types = require(script.Parent.Types)

local Onboarding = {}

Onboarding.VERSION = 3
Onboarding.FUNNEL = "onboarding_v3"
Onboarding.INTRO_FUNNEL = "onboarding_v3_intro"

export type StepName =
	-- loading and the first catch
	"joined"
	| "loaded"
	| "tut_0_shown"
	| "first_move"
	| "first_cannon"
	| "entered_alley"
	| "tut_1_shown"
	| "first_stray_in_view"
	| "near_stray"
	| "catch_card_opened"
	| "catch_started"
	| "first_circle_hit"
	| "first_catch"
	| "carrying_first_cat"
	| "first_checkin"
	-- the first cafe loop
	| "first_role_assigned"
	| "tut_3_shown"
	| "first_customer_served"
	| "second_cat"
	| "first_window_opened"
	| "first_table"
	| "first_tip_collected"
	| "tut_4_shown"
	| "bowl_bought"
	| "first_bait"
	| "first_rescue_started"
	| "first_rescue_done"
	| "first_bait_resolved"
	-- later, as in v2
	| "five_cats"
	| "rank_up_card_seen"
	| "rank_up_ready"
	| "tier_2"
	| "first_park_catch"
	| "returned_next_day"
	| "first_offline_claim"
	| "tier_3"
	| "starter_cat"

export type IntroStepName =
	"intro_choice_made"
	| "intro_started"
	| "intro_shot_1"
	| "intro_shot_2"
	| "intro_shot_3"
	| "intro_shot_4"
	| "intro_shot_5"
	| "intro_shot_6"
	| "intro_shot_7"
	| "intro_shot_8"
	| "intro_shot_9"
	| "intro_shot_10"
	| "intro_done"

-- The step number is the index. Names never change once shipped (tools/opencloud/analytics.sh reads this list).
Onboarding.STEPS = {
	"joined",
	"loaded",
	"tut_0_shown",
	"first_move",
	"first_cannon",
	"entered_alley",
	"tut_1_shown",
	"first_stray_in_view",
	"near_stray",
	"catch_card_opened",
	"catch_started",
	"first_circle_hit",
	"first_catch",
	"carrying_first_cat",
	"first_checkin",
	"first_role_assigned",
	"tut_3_shown",
	"first_customer_served",
	"second_cat",
	"first_window_opened",
	"first_table",
	"first_tip_collected",
	"tut_4_shown",
	"bowl_bought",
	"first_bait",
	"first_rescue_started",
	"first_rescue_done",
	"first_bait_resolved",
	"five_cats",
	"rank_up_card_seen",
	"rank_up_ready",
	"tier_2",
	"first_park_catch",
	"returned_next_day",
	"first_offline_claim",
	"tier_3",
	"starter_cat",
} :: { StepName }

Onboarding.COUNT = #Onboarding.STEPS

-- The intro funnel: picked from the tile or the help card, started, each of Intro.SHOTS shots shown, played out. A
-- shot left out (its camp did not stream in) or a choice the Settings row skipped is never logged; Roblox counts it
-- passed once a later step logs.
Onboarding.INTRO_STEPS = {
	"intro_choice_made",
	"intro_started",
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
	"intro_done",
} :: { IntroStepName }

Onboarding.INTRO_COUNT = #Onboarding.INTRO_STEPS

-- Steps only a client knows: reached alone, never through IMPLIES of their own (a client cannot fake a server step).
Onboarding.CLIENT_STEPS = {
	loaded = true, -- its first ProfileSync handled (the device report)
	tut_0_shown = true,
	tut_1_shown = true,
	catch_card_opened = true,
	tut_3_shown = true,
	first_window_opened = true, -- ui_opened
	tut_4_shown = true,
	rank_up_card_seen = true, -- ui_opened RankUp at Tier 1
} :: { [string]: boolean }

-- The client steps TelemetryReport("step", name) may send; the others come with their own reports.
Onboarding.REPORTABLE = {
	"tut_0_shown",
	"tut_1_shown",
	"catch_card_opened",
	"tut_3_shown",
	"tut_4_shown",
}

-- A server step and the earlier steps it proves were passed. Reaching it reaches these first (recursively).
Onboarding.IMPLIES = {
	first_move = { "joined", "loaded", "tut_0_shown" }, -- a character walking means the client loaded
	first_cannon = { "first_move" },
	entered_alley = { "first_cannon" }, -- the cannon is the way to the Alleyway
	first_stray_in_view = { "entered_alley", "tut_1_shown" },
	near_stray = { "first_stray_in_view" },
	catch_started = { "near_stray", "catch_card_opened" },
	first_circle_hit = { "catch_started" },
	first_catch = { "first_circle_hit" },
	carrying_first_cat = { "first_catch" },
	first_checkin = { "carrying_first_cat" },
	first_role_assigned = { "first_checkin" },
	first_customer_served = { "first_role_assigned" },
	second_cat = { "first_checkin" },
	first_table = { "first_window_opened" }, -- bought in Upgrades
	first_tip_collected = { "first_table" }, -- a pile needs a table
	bowl_bought = { "first_window_opened" },
	first_bait = { "bowl_bought" },
	first_rescue_done = { "first_rescue_started" },
	first_bait_resolved = { "first_bait" },
	five_cats = { "second_cat" },
	tier_2 = { "rank_up_card_seen", "rank_up_ready" }, -- RankUp is pressed on the card with the needs met
	first_park_catch = { "tier_2" }, -- the Park opens at Tier 2
	tier_3 = { "tier_2" },
} :: { [string]: { StepName } }

-- The v2 funnel's 25 steps (F87 to #1273), for a save from it (fromOld) and the report's labels for onboarding_v2.
Onboarding.V2_STEPS = {
	"joined",
	"first_move",
	"saw_alley",
	"near_stray",
	"catch_started",
	"first_circle_hit",
	"first_catch",
	"first_checkin",
	"first_role",
	"second_cat",
	"first_table",
	"bowl_bought",
	"first_bait",
	"first_rescue_started",
	"first_rescue_done",
	"first_bait_resolved",
	"five_cats",
	"rank_up_card_seen",
	"rank_up_ready",
	"tier_2",
	"first_park_catch",
	"returned_next_day",
	"first_offline_claim",
	"tier_3",
	"starter_cat",
}

-- The alpha's twelve step funnel, before F87 (the report's labels for it, and fromOld).
Onboarding.V1_STEPS = {
	"joined",
	"saw_alley",
	"first_catch",
	"first_checkin",
	"first_role",
	"first_table",
	"first_bait",
	"first_bait_resolved",
	"tier_2",
	"returned_next_day",
	"first_offline_claim",
	"tier_3",
}

local indexOf: { [string]: number } = {}
for index, name in Onboarding.STEPS do
	indexOf[name] = index
end
local introIndexOf: { [string]: number } = {}
for index, name in Onboarding.INTRO_STEPS do
	introIndexOf[name] = index
end

-- The step number, 0 for a name that is not a step. Takes any string: a StepName read back out of `reach`'s result
-- in another module is only a string to the type checker.
function Onboarding.index(stepName: string): number
	return indexOf[stepName] or 0
end

function Onboarding.introIndex(stepName: string): number
	return introIndexOf[stepName] or 0
end

-- Whether `stepName` is logged or held already, so a caller can skip work to find out whether it happened.
function Onboarding.reached(state: Types.TelemetryState, stepName: StepName): boolean
	local step = indexOf[stepName]
	return step ~= nil and (step <= state.onboardingStep or state.achieved[tostring(step)] == true)
end

-- The furthest step logged, in order: what the funnel shows of this player ("none" before joined).
function Onboarding.furthest(state: Types.TelemetryState): string
	return Onboarding.STEPS[state.onboardingStep] or "none"
end

-- The v3 step for a state saved by funnel `funnel` (1 or 2, nil before F87) at `step`: COUNT (out of the funnel)
-- once that funnel had logged its first catch, else 0 (a new player, who starts v3 from joined).
function Onboarding.fromOld(funnel: number?, step: number): number
	local list = if funnel == 2 then Onboarding.V2_STEPS else Onboarding.V1_STEPS
	local caught = table.find(list, "first_catch") :: number
	return if step >= caught then Onboarding.COUNT else 0
end

-- Marks `stepName` reached and returns the steps to log now, in order: the steps it implies that were not reached
-- yet, this step and every held step right after, or nothing when it is already logged or an earlier step is missing
-- (it is held). Mutates `state`.
function Onboarding.reach(state: Types.TelemetryState, stepName: StepName): { StepName }
	local toLog: { StepName } = {}
	local function go(name: StepName)
		local step = indexOf[name]
		if step == nil or Onboarding.reached(state, name) then
			return
		end
		for _, earlier in Onboarding.IMPLIES[name] or {} do
			go(earlier)
		end
		if step > state.onboardingStep + 1 then
			state.achieved[tostring(step)] = true
			return
		end
		state.onboardingStep = step
		table.insert(toLog, name)
		while state.achieved[tostring(state.onboardingStep + 1)] do
			state.onboardingStep += 1
			state.achieved[tostring(state.onboardingStep)] = nil
			table.insert(toLog, Onboarding.STEPS[state.onboardingStep])
		end
	end
	go(stepName)
	return toLog
end

-- The intro funnel: logs `stepName` when it is past the furthest intro step logged, and returns whether it did. A
-- step behind it (a replay, a shot reported twice) logs nothing. Mutates `state`.
function Onboarding.reachIntro(state: Types.TelemetryState, stepName: IntroStepName): boolean
	local step = introIndexOf[stepName]
	if step == nil or step <= state.introStep then
		return false
	end
	state.introStep = step
	return true
end

-- Session time markers (#1273): custom events at these seconds into a new player's session, so a drop-off can be read
-- against time as well as against steps ("left at 40 s in the intro" apart from "left at 4 minutes on the catch").
Onboarding.MARKERS = {
	{ seconds = 30, name = "session_30s" },
	{ seconds = 60, name = "session_60s" },
	{ seconds = 120, name = "session_2m" },
	{ seconds = 300, name = "session_5m" },
	{ seconds = 600, name = "session_10m" },
}

Onboarding.NEW_PLAYER_STEP = 5 -- the first loop (TutorialHints.DONE)
local DAY_SECONDS = 86400

-- A new player for the time markers and new_player_left (F87): still in the first loop, or on the UTC day of their
-- first join (`firstDay`, 0 when unknown).
function Onboarding.isNewPlayer(tutorialStep: number, firstDay: number, now: number): boolean
	return tutorialStep < Onboarding.NEW_PLAYER_STEP or firstDay == now // DAY_SECONDS
end

-- The markers due by `seconds` into the session, in order: what a session that lasted that long logs.
function Onboarding.markersBy(seconds: number): { string }
	local out: { string } = {}
	for _, marker in Onboarding.MARKERS do
		if marker.seconds <= seconds then
			table.insert(out, marker.name)
		end
	end
	return out
end

-- What a save shows it has done, for fromSave.
export type SaveFacts = {
	catsCaught: number,
	distinctCats: number,
	tables: number, -- shop levels
	bowl: number,
	tier: number,
	parkCats: number, -- cats owned from the Park (a spare cat counts by its old area)
	starterCat: boolean?, -- F96: the Bellhop Cat claimed
}

-- The steps a save already shows, in step order (QA S72). Logged on every join, so a step the save passed without
-- its event is reached anyway. Steps already reached log nothing and steps ahead are held as usual.
function Onboarding.fromSave(facts: SaveFacts): { StepName }
	local out: { StepName } = {}
	local function add(name: StepName)
		table.insert(out, name)
	end
	if facts.catsCaught >= 2 then
		add("second_cat")
	end
	if facts.tables >= 1 then
		add("first_table")
	end
	if facts.bowl >= 1 then
		add("bowl_bought")
	end
	if facts.distinctCats >= 5 then
		add("five_cats")
	end
	if facts.tier >= 2 then
		add("tier_2") -- implies rank_up_card_seen and rank_up_ready
	end
	if facts.parkCats >= 1 then
		add("first_park_catch")
	end
	if facts.tier >= 3 then
		add("tier_3")
	end
	if facts.starterCat == true then
		add("starter_cat")
	end
	return out
end

return Onboarding
