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
-- by itself and can never move a server step. A save from funnel v1, v2 or v3 that is past its first catch leaves the
-- funnel (fromOld): the funnel is for new players, and a veteran would log the first minutes it never replays.
--
-- Version 4 (#1888, Derek2 2026-11-06: good funnels for the release tests once ads run): `onboarding_v4` keeps v3's 37
-- steps as they were and adds eight for what came out since (the Store, the Cafe Pass, the camp stations, Equip best,
-- Tier 4 and the first Robux spend). The intro funnel moves with it, `onboarding_v4_intro`. A v3 save past its first
-- catch leaves the funnel like the older ones, so the funnel counts only players who start on v4.
--
-- Version 5 (#2391, Research-Agent's funnels-and-audience-2026-11-08.md section 3): `onboarding_v5`. v4 had no players
-- in Roblox's reports yet, so it is reordered for free: v4's 46 steps keep their names (V4_STEPS keeps v4's order for
-- the report) and four come in where they happen in play: the tackling lesson after the first check-in (shown, a
-- client step, and done, when the lesson's tip is saved as seen), the first Grand Opening milestone after the first
-- bait cat, and the whole Grand Opening after Tier 3. The intro funnel keeps its name and steps (onboarding_v4_intro):
-- nothing in it changed, and Roblox drops every funnel past ten a day. A v4 save past its first catch leaves the
-- funnel like the older ones. `first_hour` (FIRST_HOUR_STEPS) is a funnel of its own, one run per player, of account
-- play time only, so it can never hold an order step.
--
-- Version 6 (#2636, with #2626's shorter tutorial): `onboarding_v6`. The tackling lesson left the tutorial (#2626),
-- so its two steps go and `next_goal_shown` (a client step: the next instruction on screen after the first check-in)
-- comes in right after `first_checkin`. `first_role_assigned` implies it, so the funnel never waits on a client that
-- does not report it. V5_STEPS keeps v5's order for the report; a v5 save past its first catch leaves the funnel like
-- the older ones. The intro funnel keeps its name (onboarding_v4_intro). `first_hour_v2` adds `played_30s` and
-- `played_60s` in front of `played_2m`; a save that logged any of `first_hour` leaves `first_hour_v2`, so both
-- funnels count only players who started on them.

local Types = require(script.Parent.Types)

local Onboarding = {}

-- GrandOpening.COUNT, kept here so this module needs no Catalog (Onboarding.spec checks the two agree)
local GRAND_OPENING_COUNT = 8
Onboarding.GRAND_OPENING_COUNT = GRAND_OPENING_COUNT

Onboarding.VERSION = 6
Onboarding.FUNNEL = "onboarding_v6"
Onboarding.INTRO_FUNNEL = "onboarding_v4_intro" -- unchanged in v5 and v6 (see above)

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
	-- v6 (#2636): the next instruction on screen after the first check-in (a client step)
	| "next_goal_shown"
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
	| "first_goal_done" -- v5 (#2391): the first Grand Opening milestone paid (#1893)
	-- later, as in v2
	| "five_cats"
	| "rank_up_card_seen"
	| "rank_up_ready"
	| "tier_2"
	| "first_park_catch"
	| "returned_next_day"
	| "first_offline_claim"
	| "tier_3"
	| "grand_opening_done" -- v5 (#2391): all eight Grand Opening milestones (the last is Tier 3)
	| "starter_cat"
	-- v4 (#1888): what came out since v3
	| "first_store_open"
	| "first_pass_xp"
	| "first_pass_claim"
	| "first_camp_collect"
	| "first_equip_best"
	| "pass_level_5"
	| "tier_4"
	| "first_robux_purchase"
	| "first_wow_cat" -- #1897: the guaranteed Rare-or-better bait cat arrived (field rarity)

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
	"next_goal_shown", -- v6 (#2636): the next instruction on screen after the first check-in (a client step)
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
	"first_goal_done", -- v5: the first Grand Opening milestone paid
	"five_cats",
	"rank_up_card_seen",
	"rank_up_ready",
	"tier_2",
	"first_park_catch",
	"returned_next_day",
	"first_offline_claim",
	"tier_3",
	"grand_opening_done", -- v5: the eighth milestone (Tier 3) paid
	"starter_cat",
	"first_store_open", -- the Store opened (a client step)
	"first_pass_xp", -- the first Cafe Pass XP (a quest's prize)
	"first_pass_claim", -- a Cafe Pass reward claimed
	"first_camp_collect", -- a camp station collected (CampExtras.COLLECT)
	"first_equip_best", -- the Equip best button pressed
	"pass_level_5", -- Cafe Pass level 5
	"tier_4",
	"first_robux_purchase", -- the account's first pass or product bought (robux_purchase tells it apart in time)
	"first_wow_cat", -- #1897 (first-hour.md 2): the guaranteed Rare-or-better bait cat arrived, field rarity
} :: { StepName }

Onboarding.COUNT = #Onboarding.STEPS

-- v5's 50 steps in v5's order (fromOld, and the report's labels for onboarding_v5, #2636).
Onboarding.V5_STEPS = {
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
	"tackle_lesson_shown", -- v5: the tackling lesson's first shot on screen (a client step)
	"tackle_lesson_done", -- v5: the lesson played out (its tip saved as seen)
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
	"first_goal_done", -- v5: the first Grand Opening milestone paid
	"five_cats",
	"rank_up_card_seen",
	"rank_up_ready",
	"tier_2",
	"first_park_catch",
	"returned_next_day",
	"first_offline_claim",
	"tier_3",
	"grand_opening_done", -- v5: the eighth milestone (Tier 3) paid
	"starter_cat",
	"first_store_open", -- the Store opened (a client step)
	"first_pass_xp", -- the first Cafe Pass XP (a quest's prize)
	"first_pass_claim", -- a Cafe Pass reward claimed
	"first_camp_collect", -- a camp station collected (CampExtras.COLLECT)
	"first_equip_best", -- the Equip best button pressed
	"pass_level_5", -- Cafe Pass level 5
	"tier_4",
	"first_robux_purchase", -- the account's first pass or product bought (robux_purchase tells it apart in time)
	"first_wow_cat", -- #1897 (first-hour.md 2): the guaranteed Rare-or-better bait cat arrived, field rarity
} :: { string }

-- v4's 46 steps in v4's order (fromOld, and the report's labels for onboarding_v4, #2391).
Onboarding.V4_STEPS = {
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
	"first_store_open", -- the Store opened (a client step)
	"first_pass_xp", -- the first Cafe Pass XP (a quest's prize)
	"first_pass_claim", -- a Cafe Pass reward claimed
	"first_camp_collect", -- a camp station collected (CampExtras.COLLECT)
	"first_equip_best", -- the Equip best button pressed
	"pass_level_5", -- Cafe Pass level 5
	"tier_4",
	"first_robux_purchase", -- the account's first pass or product bought (robux_purchase tells it apart in time)
	"first_wow_cat", -- #1897 (first-hour.md 2): the guaranteed Rare-or-better bait cat arrived, field rarity
} :: { string }

-- v3's steps, the first V3_COUNT of v4's (fromOld, and the report's labels for onboarding_v3).
Onboarding.V3_COUNT = 37
Onboarding.V3_STEPS = table.move(Onboarding.V4_STEPS, 1, Onboarding.V3_COUNT, 1, {}) :: { string }

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
	first_store_open = true, -- store_opened (#1888)
	next_goal_shown = true, -- v6 (#2636): the UI, as the next instruction shows after the first check-in
} :: { [string]: boolean }

-- The client steps TelemetryReport("step", name) may send; the others come with their own reports.
Onboarding.REPORTABLE = {
	"tut_0_shown",
	"tut_1_shown",
	"catch_card_opened",
	"tut_3_shown",
	"tut_4_shown",
	"next_goal_shown", -- v6 (#2636)
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
	-- v6 (#2636): a role proves the next instruction was passed, so a client that never reports it holds nothing
	first_role_assigned = { "first_checkin", "next_goal_shown" },
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
	grand_opening_done = { "tier_3", "first_goal_done" }, -- its last milestone is Tier 3
	first_pass_claim = { "first_pass_xp" }, -- a reward needs a level, and a level needs XP
	pass_level_5 = { "first_pass_xp" },
	tier_4 = { "tier_3" },
	first_wow_cat = { "first_bait" }, -- the first bait since #2793 (was the second)
} :: { [string]: { string } }

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

-- The v6 step for a state saved by funnel `funnel` (1 to 5, nil before F87) at `step`: COUNT (out of the funnel)
-- once that funnel had logged its first catch, else 0 (a new player, who starts v6 from joined).
function Onboarding.fromOld(funnel: number?, step: number): number
	local list = if funnel == 5
		then Onboarding.V5_STEPS
		elseif funnel == 4 then Onboarding.V4_STEPS
		elseif funnel == 3 then Onboarding.V3_STEPS
		elseif funnel == 2 then Onboarding.V2_STEPS
		else Onboarding.V1_STEPS
	local caught = table.find(list, "first_catch") :: number
	return if step >= caught then Onboarding.COUNT else 0
end

-- Marks `stepName` reached and returns the steps to log now, in order: the steps it implies that were not reached
-- yet, this step and every held step right after, or nothing when it is already logged or an earlier step is missing
-- (it is held). Mutates `state`.
function Onboarding.reach(state: Types.TelemetryState, stepName: StepName): { StepName }
	local toLog: { StepName } = {}
	-- names are plain strings here (IMPLIES' lists read back as strings); what is logged is STEPS', typed
	local function go(name: string)
		local step = indexOf[name]
		if
			step == nil
			or step <= state.onboardingStep
			or state.achieved[tostring(step)] == true
		then
			return
		end
		local implied: { string }? = Onboarding.IMPLIES[name]
		if implied ~= nil then
			for _, earlier in implied do
				go(earlier)
			end
		end
		if step > state.onboardingStep + 1 then
			state.achieved[tostring(step)] = true
			return
		end
		state.onboardingStep = step
		table.insert(toLog, Onboarding.STEPS[step])
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

-- #2391 (Derek's 10 minute to 1 hour goal): the first_hour funnel, one run per player (the user id as its session),
-- logged by account play time (PlayTime.seconds) only: joined, then each FIRST_HOUR_SECONDS mark as it is passed.
-- tools/opencloud/analytics.sh reads FIRST_HOUR_FUNNEL and FIRST_HOUR_STEPS.
-- v2 (#2636): played_30s and played_60s in front of played_2m, as first_hour_v2 (the step numbers moved).
-- v3 (#3308, Derek 2026-11-11: "the start is the most important part"): played_3m and played_4m between played_2m and
-- played_5m, as first_hour_v3. Its step sits in its own telemetry field (firstHourV3Step), not firstHourStep, so a
-- server still on v2 during a rollout never reads v3's numbers as v2's; a save that logged any of v2 leaves v3.
Onboarding.FIRST_HOUR_FUNNEL = "first_hour_v3"
Onboarding.FIRST_HOUR_STEPS = {
	"joined",
	"played_30s",
	"played_60s",
	"played_2m",
	"played_3m",
	"played_4m",
	"played_5m",
	"played_10m",
	"played_20m",
	"played_30m",
	"played_45m",
	"played_60m",
} :: { string }
Onboarding.FIRST_HOUR_COUNT = #Onboarding.FIRST_HOUR_STEPS
-- first_hour_v2's steps, for the report (analytics.sh labels the v2 rows still in a window with them)
Onboarding.FIRST_HOUR_V2_STEPS = {
	"joined",
	"played_30s",
	"played_60s",
	"played_2m",
	"played_5m",
	"played_10m",
	"played_20m",
	"played_30m",
	"played_45m",
	"played_60m",
} :: { string }
Onboarding.FIRST_HOUR_V2_COUNT = #Onboarding.FIRST_HOUR_V2_STEPS
-- the play time each step needs, by index (joined needs none)
Onboarding.FIRST_HOUR_SECONDS =
	{ 0, 30, 60, 120, 180, 240, 300, 600, 1200, 1800, 2700, 3600 } :: { number }

-- The first_hour step numbers to log now, in order, for a player at `playSeconds` of account play whose furthest
-- logged step is `logged` (0 before joined): every step past `logged` that the play time has reached.
function Onboarding.firstHourDue(logged: number, playSeconds: number): { number }
	local out: { number } = {}
	local seconds = if playSeconds ~= playSeconds then 0 else playSeconds
	for step = math.max(0, logged) + 1, Onboarding.FIRST_HOUR_COUNT do
		if seconds < Onboarding.FIRST_HOUR_SECONDS[step] then
			break
		end
		table.insert(out, step)
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
	-- #1888: the Cafe Pass this season (its XP and the rewards claimed) and whether the account has spent Robux here
	passXp: number?,
	passClaims: number?,
	passLevel: number?,
	spent: boolean?,
	-- #2391 (v5): the Grand Opening milestones done
	goalsDone: number?,
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
	if (facts.goalsDone or 0) >= 1 then
		add("first_goal_done")
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
	if (facts.goalsDone or 0) >= GRAND_OPENING_COUNT then
		add("grand_opening_done")
	end
	if facts.starterCat == true then
		add("starter_cat")
	end
	if (facts.passXp or 0) > 0 then
		add("first_pass_xp")
	end
	if (facts.passClaims or 0) > 0 then
		add("first_pass_claim")
	end
	if (facts.passLevel or 0) >= 5 then
		add("pass_level_5")
	end
	if facts.tier >= 4 then
		add("tier_4")
	end
	if facts.spent == true then
		add("first_robux_purchase")
	end
	return out
end

return Onboarding
