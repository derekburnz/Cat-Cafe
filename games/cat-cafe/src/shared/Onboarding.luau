--!strict
-- The onboarding funnel, each step logged once and only in order. Pure. Roblox marks every earlier step complete when
-- a later one is logged, so a player who ranks up before setting bait would fake the bait steps. A step reached
-- early is held in `achieved` until every step before it is logged (analytics-plan 3.2, data-model section 14
-- `telemetry`).
--
-- Version 2 (F87, easy-start.md section 5): 24 finer steps from the first second to Tier 3, logged as the funnel
-- FUNNEL so the alpha's 12 step onboarding funnel stays apart. A saved state from version 1 (`funnel` not 2) is
-- carried over by `fromV1`: each old step maps to the same step in the new numbering, so a player from the alpha
-- starts the new funnel at the step they had reached.

local Types = require(script.Parent.Types)

local Onboarding = {}

Onboarding.VERSION = 2
Onboarding.FUNNEL = "onboarding_v2"

export type StepName =
	"joined"
	| "first_move"
	| "saw_alley"
	| "near_stray"
	| "catch_started"
	| "first_circle_hit"
	| "first_catch"
	| "first_checkin"
	| "first_role"
	| "second_cat"
	| "first_table"
	| "bowl_bought"
	| "first_bait"
	| "first_rescue_started"
	| "first_rescue_done"
	| "first_bait_resolved"
	| "five_cats"
	| "rank_up_card_seen"
	| "rank_up_ready"
	| "tier_2"
	| "first_park_catch"
	| "returned_next_day"
	| "first_offline_claim"
	| "tier_3"
	| "starter_cat"

-- The step number is the index. Names never change once shipped.
Onboarding.STEPS = {
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
	"starter_cat", -- F96 (starter-cat.md section 4): step 25, the free Bellhop Cat taken home
} :: { StepName }

Onboarding.COUNT = #Onboarding.STEPS

-- The version 1 funnel's twelve steps, in order (analytics-plan 3.1 before F87): where each one sits in version 2.
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

-- The step number, 0 for a name that is not a step. Takes any string: a StepName read back out of `reach`'s result
-- in another module is only a string to the type checker.
function Onboarding.index(stepName: string): number
	return indexOf[stepName] or 0
end

-- Whether `stepName` is logged or held already, so a caller can skip work to find out whether it happened.
function Onboarding.reached(state: Types.TelemetryState, stepName: StepName): boolean
	local step = indexOf[stepName]
	return step ~= nil and (step <= state.onboardingStep or state.achieved[tostring(step)] == true)
end

-- A version 1 position (0 to 12) and held steps in the version 2 numbering. Unknown held keys are dropped.
function Onboarding.fromV1(
	step: number,
	achieved: { [string]: boolean }
): (number, { [string]: boolean })
	local function moved(old: number): number
		local name = Onboarding.V1_STEPS[old]
		return if name ~= nil then indexOf[name] or 0 else 0
	end
	local held: { [string]: boolean } = {}
	for key, value in achieved do
		local old = tonumber(key)
		local new = if old ~= nil then moved(old) else 0
		if value == true and new > 0 then
			held[tostring(new)] = true
		end
	end
	return moved(step), held
end

-- Marks `stepName` reached and returns the steps to log now, in order: this step and every held step right after
-- it when it is the next one, or nothing when it is already logged or an earlier step is missing (it is held).
-- Mutates `state`.
function Onboarding.reach(state: Types.TelemetryState, stepName: StepName): { StepName }
	local step = indexOf[stepName]
	local toLog: { StepName } = {}
	if step == nil or step <= state.onboardingStep then
		return toLog
	end
	if step > state.onboardingStep + 1 then
		state.achieved[tostring(step)] = true
		return toLog
	end
	state.onboardingStep = step
	table.insert(toLog, stepName)
	while state.achieved[tostring(state.onboardingStep + 1)] do
		state.onboardingStep += 1
		state.achieved[tostring(state.onboardingStep)] = nil
		table.insert(toLog, Onboarding.STEPS[state.onboardingStep])
	end
	state.achieved[tostring(step)] = nil
	return toLog
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
-- its event is reached anyway: an alpha save fromV1 moved to first_table that already owned the bowl, whose
-- bowl_bought would never come, or one past tier_2 that now catches only beyond the Park. Steps already reached log
-- nothing and steps ahead are held as usual.
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
		-- a cafe past Tier 1 saw the Rank Up card with its needs met
		add("rank_up_card_seen")
		add("rank_up_ready")
		add("tier_2")
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
