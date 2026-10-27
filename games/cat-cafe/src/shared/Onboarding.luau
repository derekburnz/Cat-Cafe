--!strict
-- The onboarding funnel (growth analytics-plan section 3): twelve steps, each logged once and only in order. Pure.
-- Roblox marks every earlier step complete when a later one is logged, so a player who ranks up before setting bait
-- would fake the bait steps. A step reached early is held in `achieved` until every step before it is logged
-- (analytics-plan 3.2, data-model section 14 `telemetry`).

local Types = require(script.Parent.Types)

local Onboarding = {}

export type StepName =
	"joined"
	| "saw_alley"
	| "first_catch"
	| "first_checkin"
	| "first_role"
	| "first_table"
	| "first_bait"
	| "first_bait_resolved"
	| "tier_2"
	| "returned_next_day"
	| "first_offline_claim"
	| "tier_3"

-- The step number is the index. Names never change once shipped.
Onboarding.STEPS = {
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
} :: { StepName }

Onboarding.COUNT = #Onboarding.STEPS

local indexOf: { [string]: number } = {}
for index, name in Onboarding.STEPS do
	indexOf[name] = index
end

-- The step number, 0 for a name that is not a step. Takes any string: a StepName read back out of `reach`'s result
-- in another module is only a string to the type checker.
function Onboarding.index(stepName: string): number
	return indexOf[stepName] or 0
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

return Onboarding
