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

local Catalog = require(script.Parent.Catalog)
local TutorialOrder = require(script.Parent.TutorialOrder)
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
-- #3660: the steps a new save has met before it starts: with `tables` of 1 or more, first_table and the tutorial's
-- table step (tut_3_shown), which such a save never sees. Both are logged in their places as the funnel reaches them
-- (it needs every step in order), so the steps after them are not held back. #4097: with `bowls` of 1 or more,
-- bowl_bought too (a new save starts with its Bait bowl).
function Onboarding.startAchieved(tables: number, bowls: number?): { [string]: boolean }
	local achieved: { [string]: boolean } = {}
	if tables >= 1 then
		achieved[tostring(indexOf.tut_3_shown)] = true
		achieved[tostring(indexOf.first_table)] = true
	end
	if (bowls or 0) >= 1 then
		achieved[tostring(indexOf.bowl_bought)] = true
	end
	return achieved
end

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

-- Marks `stepName` reached. `log`: the steps to log now, in order: the steps it implies that were not reached yet,
-- this step and every held step right after, or nothing when it is already logged or an earlier step is missing (it
-- is held). #3530: `held` names the steps this call put on hold (reached now, logged later) and `released` the logged
-- ones that had been on hold, so a caller can time a step when it happens and not when the funnel catches up.
-- Mutates `state`.
export type Reach = { log: { StepName }, held: { StepName }, released: { [string]: boolean } }
function Onboarding.reachDetail(state: Types.TelemetryState, stepName: StepName): Reach
	local toLog: { StepName } = {}
	local held: { StepName } = {}
	local released: { [string]: boolean } = {}
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
			table.insert(held, Onboarding.STEPS[step])
			return
		end
		state.onboardingStep = step
		table.insert(toLog, Onboarding.STEPS[step])
		while state.achieved[tostring(state.onboardingStep + 1)] do
			state.onboardingStep += 1
			state.achieved[tostring(state.onboardingStep)] = nil
			table.insert(toLog, Onboarding.STEPS[state.onboardingStep])
			released[Onboarding.STEPS[state.onboardingStep]] = true
		end
	end
	go(stepName)
	-- a step held and let go inside this one call was never waiting: it is timed once, as logged
	for index = #held, 1, -1 do
		if released[held[index]] then
			released[held[index]] = nil
			table.remove(held, index)
		end
	end
	return { log = toLog, held = held, released = released }
end

-- The steps to log now, in order (reachDetail's `log`). Mutates `state`.
function Onboarding.reach(state: Types.TelemetryState, stepName: StepName): { StepName }
	return Onboarding.reachDetail(state, stepName).log
end

-- Version 7 (#3695; Derek 2026-11-13: "make a new onboarding with the exact steps a player would have to take to
-- progress and keep it clean joined, loaded, all tutorial steps 1 by 1, then tiers and catching cats in next area"):
-- `onboarding_v7`, the clean funnel. STEPS above stays as the ledger other code reads through `reached` (StuckGoal,
-- FirstFive, StepGaps, the second cat's stray), and is no longer sent to Roblox as a funnel. The clean funnel is a
-- second, shorter list read off the ledger, the cafe's tier and the areas the player has caught in: only what every
-- player must do, in the order the game asks for it. Out of it on purpose: the optional rescue, the cards and windows
-- a client reports, coming back the next day, the Store, the Cafe Pass and Robux. Its place is its own telemetry
-- field (cleanStep), so a server still on v6 during a rollout never reads it.
Onboarding.CLEAN_FUNNEL = "onboarding_v9"
Onboarding.V8_CLEAN_COUNT = 43 -- onboarding_v8's steps, for the field a save still carries (cleanV8Step)

-- v7's 27 steps in v7's order, kept for the report's labels of onboarding_v7 and for the v7 field (cleanStep) a save
-- still carries for a server on v7 during the rollout (#4504).
Onboarding.V7_CLEAN_FUNNEL = "onboarding_v7"
Onboarding.V7_CLEAN_STEPS = {
	"joined",
	"loaded",
	"first_move",
	"first_cannon",
	"entered_alley",
	"near_stray",
	"catch_started",
	"first_catch",
	"first_checkin",
	"first_role_assigned",
	"second_cat",
	"first_table",
	"bowl_bought",
	"first_bait",
	"first_bait_resolved",
	"tier_2",
	"park_catch",
	"tier_3",
	"neighbourhood_catch",
	"tier_4",
	"woods_catch",
	"tier_5",
	"sewer_catch",
	"tier_6",
	"desert_catch",
	"tier_7",
	"ruins_catch",
} :: { string }
Onboarding.V7_CLEAN_COUNT = #Onboarding.V7_CLEAN_STEPS
Onboarding.V7_CLEAN_TUTORIAL = 15 -- first_bait_resolved, v7's last tutorial step

-- v7's step numbers to log now (its rules from #3695: the first 15 are ledger steps, then tier_N the cafe at that
-- tier, <area>_catch a cat caught there), for a player whose furthest logged v7 step is `logged`: every step past it
-- that is done, stopping at the first that is not. Pure, mutates nothing.
function Onboarding.v7Due(
	state: Types.TelemetryState,
	logged: number,
	facts: { tier: number, areas: { [string]: boolean } }
): { number }
	local out: { number } = {}
	for step = math.max(0, logged) + 1, Onboarding.V7_CLEAN_COUNT do
		local name = Onboarding.V7_CLEAN_STEPS[step]
		local done
		if step <= Onboarding.V7_CLEAN_TUTORIAL then
			done = Onboarding.reached(state, name :: StepName)
		elseif string.sub(name, 1, 5) == "tier_" then
			done = facts.tier >= (tonumber(string.sub(name, 6)) or math.huge)
		else
			done = facts.areas[string.sub(name, 1, #name - #"_catch")] == true
		end
		if not done then
			break
		end
		table.insert(out, step)
	end
	return out
end

-- Where a save that never had v7 starts it: out of it once the ledger shows a first catch, else 0.
function Onboarding.v7Start(state: Types.TelemetryState): number
	return if Onboarding.reached(state, "first_catch") then Onboarding.V7_CLEAN_COUNT else 0
end

-- v7's furthest step logged, as cleanFurthest.
local function v7Furthest(state: Types.TelemetryState): string
	local step = state.cleanStep or 0
	if step >= Onboarding.V7_CLEAN_COUNT then
		return "done"
	end
	return Onboarding.V7_CLEAN_STEPS[step] or "none"
end

-- Version 8 (#4504; Derek 2026-11-15 14:07 UTC: a funnel with the exact steps a new player takes, so the daily read
-- shows where they leave): `onboarding_v8`, the walk-through bowl first (#4518, Derek 15:24 UTC; Growth-Agent's step
-- list): the food in the bowl, the cannon to the Alleyway, two catches by hand saved at camp, the Rank Up shown and
-- pressed, the camp cannon to the Park (the walk-through's end), then per area: a cat caught there, the next tier,
-- arrived in the next area. It is logged while the walk-through runs bowl first (TutorialOrder.bowlFirst), and v7
-- while it runs today's order, so each funnel only ever sees the order it was made for. The bowl cat's claim is a
-- step too (Derek 16:14 UTC: "capture the steps properly in order and detail"): bowl window, food in, bowl cat here,
-- tamed, cannon, launch, landed in the Alleyway, each catch's start and win, check-ins, Rank Up, Park cannon, launch,
-- landing.
-- Some steps are moments the save does not keep (a window open, the bowl cat here, in the cannon, near the cat, a
-- catch started, the net catch, the Rank Up shown and pressed, a launch, landed in an area): those are `event` steps,
-- logged as the event comes. As in Roblox's own funnels, a step
-- that is done proves every step before it, so a player who left between two moments (or a client too old to
-- report one) never holds the funnel.
-- One clean step: `ledger` a step of STEPS reached, `tier` the cafe at that tier or over, `area` a cat caught there
-- (with the cafe at its `tier`),
-- `tutorialStep` the walk-through at that step or past it, `handCats` that many cats caught by hand and checked in
-- (SecondCat.caught), `event` the moment Telemetry.cleanEvent names.
type CleanRule = {
	name: string,
	ledger: StepName?,
	tier: number?,
	area: string?,
	tutorialStep: number?,
	handCats: number?,
	event: string?,
	-- onboarding_v9: `tamed` that many bowl cats tamed (stats.baitsTamed), `ownedCats` that many cats owned (with
	-- `tamed`, both), `readyTier` that tier reached or its rank up ready from the tier below (Economy.rankUpBlocker)
	tamed: number?,
	ownedCats: number?,
	readyTier: number?,
}

-- The moments an event step listens for (Telemetry.cleanEvent's `event`).
Onboarding.CLEAN_EVENTS = {
	bowlArrived = "bowl_arrived", -- the account's first bowl cat arrived (BaitService, Telemetry.firstBaitArrived)
	bowlOpen = "bowl_open", -- the Bait bowl window opened (the client's screen report)
	cannonOpen = "cannon_open", -- the Cat Cannon window opened (the client's screen report)
	catchStart = "catch_start", -- a net catch started (CatService)
	launch = "launch", -- a cannon launch (CannonService)
	nearStray = "near_stray", -- came near the cat that waits for the second catch (CatService)
	netCatch = "net_catch", -- a cat caught with the net (CatService)
	rankUpPressed = "rank_up_pressed", -- RankUp pressed at Tier 1, met or not (CafeService)
	rankUpShown = "rank_up_shown", -- the Rank Up card opened at Tier 1 (the client's screen report)
	-- onboarding_v9 (Derek 2026-11-17 15:18 UTC: "even more in depth especially for first 5 minutes tutorial steps
	-- and tier1/2"; Growth-Agent's list funnel-v9-2026-11-17/onboarding-v9-steps.md): moments already logged as
	-- custom events, read off them as they are sent (Onboarding.cleanFromCustom)
	worldReady = "world_ready", -- client_load: the world ready on the client
	introStart = "intro_start", -- first_scene: the intro's first shot
	introDone = "intro_done", -- intro_cutscene, first play: finished or skipped
	bowlHint = "bowl_hint", -- step_time tut_bowl_food: the strip asks for food in the bowl
	tameAsk = "tame_ask", -- step_time tut_bowl_arrived: the cat is at the bowl and the strip asks for Tame
	strayMarked = "stray_marked", -- step_time second_cat_trail_shown: the stray that waits is marked
	catchPrompt = "catch_prompt", -- catch_prompt_shown_first: the catch card on screen
	rankReady = "rank_ready", -- rank_up_ready_first: Tier 2's every need met
	rankCue = "rank_cue", -- step_time tut_rank_cue: the strip and the ring point at YOUR GOAL (#5108)
	parkRing = "park_ring", -- park_first_hint ring: the Park's first ring shown
}

-- The v9 moment a custom event carries (Telemetry.custom calls this for every event it sends), nil for none. Pure.
local FROM_CUSTOM: { [string]: string } = {
	client_load = Onboarding.CLEAN_EVENTS.worldReady,
	first_scene = Onboarding.CLEAN_EVENTS.introStart,
	catch_prompt_shown_first = Onboarding.CLEAN_EVENTS.catchPrompt,
	rank_up_ready_first = Onboarding.CLEAN_EVENTS.rankReady,
}
local FROM_STEP_TIME: { [string]: string } = {
	tut_bowl_food = Onboarding.CLEAN_EVENTS.bowlHint,
	tut_bowl_arrived = Onboarding.CLEAN_EVENTS.tameAsk,
	second_cat_trail_shown = Onboarding.CLEAN_EVENTS.strayMarked,
	tut_rank_cue = Onboarding.CLEAN_EVENTS.rankCue,
}
function Onboarding.cleanFromCustom(name: string, fields: { string }): string?
	if name == "step_time" then
		return FROM_STEP_TIME[fields[1] or ""]
	elseif name == "intro_cutscene" then
		return if fields[3] == "first" then Onboarding.CLEAN_EVENTS.introDone else nil
	elseif name == "park_first_hint" then
		return if fields[1] == "ring" then Onboarding.CLEAN_EVENTS.parkRing else nil
	end
	return FROM_CUSTOM[name]
end
-- The landing in `area` by cannon (CannonService).
function Onboarding.arrivedEvent(area: string): string
	return "arrived_" .. area
end

local EV = Onboarding.CLEAN_EVENTS
-- The areas after the Alleyway, in tier order (Tier 2 to 10).
local LATER_AREAS =
	{ "park", "neighbourhood", "woods", "sewer", "desert", "ruins", "snowy", "waterpark", "castle" }
local CLEAN_RULES: { CleanRule } = {
	-- join and intro
	{ name = "joined", ledger = "joined" },
	{ name = "loaded", ledger = "loaded" },
	{ name = "world_ready", event = EV.worldReady },
	{ name = "intro_started", event = EV.introStart },
	{ name = "intro_done", event = EV.introDone },
	{ name = "first_move", ledger = "first_move" }, -- the intro scene over, the character walks
	-- the bowl cat
	{ name = "bowl_hint_seen", event = EV.bowlHint },
	{ name = "bowl_opened", event = EV.bowlOpen }, -- the Bait bowl window open
	{ name = "first_bowl", ledger = "first_bait" }, -- food in the bowl
	{ name = "bowl_cat_here", event = EV.bowlArrived }, -- the bowl cat arrived
	{ name = "tame_ask_shown", event = EV.tameAsk },
	{ name = "bowl_cat_tamed", tamed = 1 }, -- tamed, never let go
	{ name = "starter_cats_2", ownedCats = 2, tamed = 1 }, -- the starter Tabby and the bowl cat: proves the starter
	-- to the Alleyway
	{ name = "in_cannon", event = EV.cannonOpen },
	{ name = "alley_picked", event = EV.launch }, -- the first launch, to the Alleyway
	{ name = "alley_arrived", event = Onboarding.arrivedEvent("alley") }, -- landed in the Alleyway
	-- the first hand catch
	{ name = "stray_marked", event = EV.strayMarked },
	{ name = "near_stray", event = EV.nearStray }, -- came near the stray that waits for them
	{ name = "catch_prompt_shown", event = EV.catchPrompt },
	{ name = "catch_started", event = EV.catchStart }, -- the net swung
	{ name = "first_catch", event = EV.netCatch }, -- won: the cat is in hand ("Carry it to camp")
	{ name = "first_checkin", handCats = 1 }, -- a cat caught by hand saved at camp (the bowl cat does not count)
	-- the Rank Up
	{ name = "rank_up_ready", event = EV.rankReady },
	{ name = "rank_up_cue_seen", event = EV.rankCue },
	{ name = "rank_up_ready_shown", event = EV.rankUpShown },
	{ name = "rank_up_pressed", event = EV.rankUpPressed },
	{ name = "tier_2", tier = 2 },
	-- the Park
	{ name = "park_arrived", event = Onboarding.arrivedEvent("park") }, -- the Rank Up moves the player in (#4674): the walk-through's end
	{ name = "park_ring_seen", event = EV.parkRing },
	{ name = "park_catch_started", event = EV.catchStart },
	{ name = "park_catch", area = "park", tier = 2 },
	{ name = "tier_3_ready", readyTier = 3 },
}
for index, area in LATER_AREAS do
	if index > 1 then
		table.insert(CLEAN_RULES, { name = "tier_" .. (index + 1), tier = index + 1 })
		table.insert(
			CLEAN_RULES,
			{ name = area .. "_arrived", event = Onboarding.arrivedEvent(area) }
		)
		table.insert(CLEAN_RULES, { name = area .. "_catch", area = area, tier = index + 1 })
	end
end

-- The names in order; the step number is the index (tools/opencloud/analytics.sh reads this literal list, and a spec
-- checks it against the rules).
Onboarding.CLEAN_STEPS = {
	"joined",
	"loaded",
	"world_ready",
	"intro_started",
	"intro_done",
	"first_move",
	"bowl_hint_seen",
	"bowl_opened",
	"first_bowl",
	"bowl_cat_here",
	"tame_ask_shown",
	"bowl_cat_tamed",
	"starter_cats_2",
	"in_cannon",
	"alley_picked",
	"alley_arrived",
	"stray_marked",
	"near_stray",
	"catch_prompt_shown",
	"catch_started",
	"first_catch",
	"first_checkin",
	"rank_up_ready",
	"rank_up_cue_seen",
	"rank_up_ready_shown",
	"rank_up_pressed",
	"tier_2",
	"park_arrived",
	"park_ring_seen",
	"park_catch_started",
	"park_catch",
	"tier_3_ready",
	"tier_3",
	"neighbourhood_arrived",
	"neighbourhood_catch",
	"tier_4",
	"woods_arrived",
	"woods_catch",
	"tier_5",
	"sewer_arrived",
	"sewer_catch",
	"tier_6",
	"desert_arrived",
	"desert_catch",
	"tier_7",
	"ruins_arrived",
	"ruins_catch",
	"tier_8",
	"snowy_arrived",
	"snowy_catch",
	"tier_9",
	"waterpark_arrived",
	"waterpark_catch",
	"tier_10",
	"castle_arrived",
	"castle_catch",
} :: { string }
Onboarding.CLEAN_COUNT = #Onboarding.CLEAN_STEPS
Onboarding.CLEAN_TUTORIAL = 28 -- park_arrived, the walk-through's end: the areas come after
Onboarding.CLEAN_RULE_NAMES = table.create(#CLEAN_RULES) :: { string } -- for the spec
for index, rule in CLEAN_RULES do
	Onboarding.CLEAN_RULE_NAMES[index] = rule.name
end

-- The areas the clean funnel asks about, for a caller that gathers CleanFacts.
Onboarding.CLEAN_AREAS = table.clone(LATER_AREAS) :: { string }

-- What the clean funnel needs beside the ledger: the cafe's tier, the areas with a catch, and (when known) the
-- walk-through's step and the cats caught by hand. Missing ones read as 0.
export type CleanFacts = {
	tier: number,
	areas: { [string]: boolean },
	tutorialStep: number?,
	handCats: number?,
	tamed: number?, -- onboarding_v9: stats.baitsTamed
	ownedCats: number?, -- the cats owned now
	nextReady: boolean?, -- the next tier's rank up is ready now (Economy.rankUpBlocker nil)
}

-- Whether a rule that is not an event step is done.
local function cleanDone(state: Types.TelemetryState, rule: CleanRule, facts: CleanFacts): boolean
	if rule.ledger ~= nil then
		return Onboarding.reached(state, rule.ledger)
	elseif rule.area ~= nil then
		-- with the area's tier too, so a cat given early (a code, a gift) never passes the rank ups before it
		return facts.areas[rule.area] == true and facts.tier >= (rule.tier or 0)
	elseif rule.tier ~= nil then
		return facts.tier >= rule.tier
	elseif rule.tutorialStep ~= nil then
		return (facts.tutorialStep or 0) >= rule.tutorialStep
	elseif rule.handCats ~= nil then
		return (facts.handCats or 0) >= rule.handCats
	elseif rule.ownedCats ~= nil then
		return (facts.ownedCats or 0) >= rule.ownedCats and (facts.tamed or 0) >= (rule.tamed or 0)
	elseif rule.tamed ~= nil then
		return (facts.tamed or 0) >= rule.tamed
	elseif rule.readyTier ~= nil then
		return facts.tier >= rule.readyTier
			or (facts.tier == rule.readyTier - 1 and facts.nextReady == true)
	end
	return false
end

-- The event step `event` counts at, past `base`: the first step after base with that event and only event steps
-- between them (a moment counts only where the save already stands, so a launch at the first trip never passes the
-- second trip's launch). Nil when none.
local function eventStep(base: number, event: string): number?
	for step = math.max(0, base) + 1, Onboarding.CLEAN_COUNT do
		local rule = CLEAN_RULES[step]
		if rule.event == nil then
			return nil
		elseif rule.event == event then
			return step
		end
	end
	return nil
end

-- The clean step numbers to log now, in order, for a player whose furthest logged clean step is `logged` (0 before
-- joined), with `event` the moment happening now (nil for none): up to the furthest step that is done, since a done
-- step proves those before it. Pure, mutates nothing.
function Onboarding.cleanDue(
	state: Types.TelemetryState,
	logged: number,
	facts: CleanFacts,
	event: string?
): { number }
	local base = math.max(0, logged)
	for step = Onboarding.CLEAN_COUNT, base + 1, -1 do
		local rule = CLEAN_RULES[step]
		if rule.event == nil and cleanDone(state, rule, facts) then
			base = step
			break
		end
	end
	if event ~= nil then
		base = eventStep(base, event) or base
	end
	local out: { number } = {}
	for step = math.max(0, logged) + 1, base do
		table.insert(out, step)
	end
	return out
end

-- Whether `event` would log a step for a save at `logged`, its stored facts aside: for a caller that checks a
-- moment often (the near check runs every tick) and only wants the work when it can count.
function Onboarding.cleanWants(logged: number, event: string): boolean
	return logged < Onboarding.CLEAN_COUNT and eventStep(logged, event) ~= nil
end

-- The furthest clean step logged, for the events that say where a player was: "none" before joined and "done" for a
-- player through it or out of it (a veteran who never started it).
-- Whether onboarding_v8 is the funnel logged now: the walk-through runs bowl first (#4518); v7 otherwise.
function Onboarding.v8On(): boolean
	return TutorialOrder.bowlFirst()
end

-- `v8` says which funnel runs (Onboarding.v8On; nil reads it): v7's names for today's order.
function Onboarding.cleanFurthest(state: Types.TelemetryState, v8: boolean?): string
	if not (if v8 == nil then TutorialOrder.bowlFirst() else v8) then
		return v7Furthest(state)
	end
	local step = state.cleanV9Step or 0
	if step >= Onboarding.CLEAN_COUNT then
		return "done"
	end
	return Onboarding.CLEAN_STEPS[step] or "none"
end

-- Where a save that never had the clean funnel starts it: out of it (CLEAN_COUNT) once the ledger shows a first
-- catch, since the funnel counts only players who start on it; else 0, from joined.
function Onboarding.cleanStart(state: Types.TelemetryState): number
	return if Onboarding.reached(state, "first_catch") then Onboarding.CLEAN_COUNT else 0
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

-- #3695 (Derek 2026-11-13: "a funnel for more in depth minutes, moved, 30 seconds, 1 min, 2,3,4,5,10,15,30,1h,2h,3h,
-- 6h,12h"): `playtime_v1`, one run per player like first_hour, which it replaces (first_hour_v3 is no longer sent;
-- its names above stay for the report's older rows and for saves). joined, then moved (the ledger's first_move), then
-- each PLAYTIME_SECONDS mark of account play time. A player who never moves stays at joined, as the order says. Its
-- place is its own telemetry field (playtimeStep); a save that logged any of first_hour_v3 leaves it.
Onboarding.PLAYTIME_FUNNEL = "playtime_v1"
Onboarding.PLAYTIME_STEPS = {
	"joined",
	"moved",
	"played_30s",
	"played_1m",
	"played_2m",
	"played_3m",
	"played_4m",
	"played_5m",
	"played_10m",
	"played_15m",
	"played_30m",
	"played_1h",
	"played_2h",
	"played_3h",
	"played_6h",
	"played_12h",
} :: { string }
Onboarding.PLAYTIME_COUNT = #Onboarding.PLAYTIME_STEPS
Onboarding.PLAYTIME_MOVED = 2 -- the step that needs the first move and no play time
-- the play time each step needs, by index (joined and moved need none)
Onboarding.PLAYTIME_SECONDS = {
	0,
	0,
	30,
	60,
	120,
	180,
	240,
	300,
	600,
	900,
	1800,
	3600,
	7200,
	10800,
	21600,
	43200,
} :: { number }

-- The playtime_v1 step numbers to log now, in order, for a player at `playSeconds` of account play whose furthest
-- logged step is `logged` (0 before joined) and who has `moved` or not: every step past `logged` that is reached.
function Onboarding.playtimeDue(logged: number, playSeconds: number, moved: boolean): { number }
	local out: { number } = {}
	local seconds = if playSeconds ~= playSeconds then 0 else playSeconds
	for step = math.max(0, logged) + 1, Onboarding.PLAYTIME_COUNT do
		if step >= Onboarding.PLAYTIME_MOVED and not moved then
			break
		end
		if seconds < Onboarding.PLAYTIME_SECONDS[step] then
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
	-- #4098: Tier 2's need (4 from 2026-11-14, 5 before); the id stays five_cats so the funnel keeps its step
	if facts.distinctCats >= Catalog.tiers[2].distinctCats then
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
