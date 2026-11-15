--!strict
-- #3530 (Design-Agent with Growth-Agent's Nov 11 read): the numbers the onboarding read could not answer. Pure.
--   * step_gap: the seconds between two onboarding steps as a bucket, because Roblox's analytics give counts and
--     averages only and an average hides "most players never do it". One event per gap per account, logged when
--     the gap's later step is reached; value the seconds (0 when they are not known), fields the gap and the bucket.
--   * quit_have: beside quit_state (whose three fields are full), what a leaver below Tier 2 had: kinds of cat,
--     coins as a share of Tier 2's cost, and whether Tier 2's needs were met (ready) or not.
-- Counts and buckets only, never who.
local StepGaps = {}

export type Gap = { name: string, from: string, to: string }

StepGaps.EVENT = "step_gap"
StepGaps.QUIT_EVENT = "quit_have"

-- Names never change once shipped (the report reads them). `from` and `to` are Onboarding step names.
StepGaps.GAPS = {
	{ name = "bait_to_rescue", from = "first_bait", to = "first_rescue_started" },
	{ name = "served_to_second_cat", from = "first_customer_served", to = "second_cat" },
	{ name = "second_cat_to_five", from = "second_cat", to = "five_cats" },
	{ name = "ready_to_tier_2", from = "rank_up_ready", to = "tier_2" },
	{ name = "loaded_to_first_move", from = "loaded", to = "first_move" },
} :: { Gap }

StepGaps.UNDER_15 = "under_15s"
StepGaps.TO_60 = "15_60s"
StepGaps.TO_120 = "60_120s"
StepGaps.OVER_120 = "over_120s"
-- the first step came in an earlier visit: the session's clock cannot say how long ago, and nothing is saved for it
StepGaps.EARLIER_VISIT = "earlier_visit"
-- the later step came with the first one still missing (a second cat before the first customer, say)
StepGaps.NO_START = "no_start"

-- The gaps that end at onboarding step `step`.
function StepGaps.endingAt(step: string): { Gap }
	local out: { Gap } = {}
	for _, gap in StepGaps.GAPS do
		if gap.to == step then
			table.insert(out, gap)
		end
	end
	return out
end

-- Whether `step` starts or ends a gap, so its moment is worth keeping for the session.
function StepGaps.marks(step: string): boolean
	for _, gap in StepGaps.GAPS do
		if gap.from == step or gap.to == step then
			return true
		end
	end
	return false
end

function StepGaps.bucket(seconds: number): string
	if seconds ~= seconds or seconds < 15 then
		return StepGaps.UNDER_15
	elseif seconds < 60 then
		return StepGaps.TO_60
	elseif seconds < 120 then
		return StepGaps.TO_120
	end
	return StepGaps.OVER_120
end

-- step_gap's value and bucket. `startReached`: the gap's first step was reached before its later one;
-- `startedAt`: the session clock when it was, nil when that was not in this session; `now`: the same clock.
function StepGaps.measure(startReached: boolean, startedAt: number?, now: number): (number, string)
	if not startReached then
		return 0, StepGaps.NO_START
	elseif startedAt == nil then
		return 0, StepGaps.EARLIER_VISIT
	end
	local seconds = math.max(0, now - startedAt)
	if seconds ~= seconds then
		seconds = 0
	end
	return math.floor(seconds), StepGaps.bucket(seconds)
end

-- quit_have's first field: kinds of cat owned, "0" to "5" (5 for any more: Tier 2 needs five).
function StepGaps.kinds(distinct: number): string
	local n = if distinct ~= distinct then 0 else math.floor(distinct)
	return tostring(math.clamp(n, 0, 5))
end

-- quit_have's second field: coins as a share of Tier 2's cost.
function StepGaps.coinShare(coins: number, cost: number): string
	if cost <= 0 or cost ~= cost then
		return "75_plus"
	end
	local share = if coins ~= coins then 0 else coins / cost
	if share < 0.25 then
		return "under_25"
	elseif share < 0.5 then
		return "25_50"
	elseif share < 0.75 then
		return "50_75"
	end
	return "75_plus"
end

StepGaps.READY = "ready" -- Tier 2's needs were met and the player left without ranking up (rank_up_ready_quit)
StepGaps.NOT_READY = "not_ready"

function StepGaps.quitFields(
	distinct: number,
	coins: number,
	cost: number,
	ready: boolean
): { string }
	return {
		StepGaps.kinds(distinct),
		StepGaps.coinShare(coins, cost),
		if ready then StepGaps.READY else StepGaps.NOT_READY,
	}
end

-- #4189: quit_have past Tier 1 (Tier 1 keeps the fields above). The kinds still short of the next tier ("0", "1-2",
-- "3-5", "6+"), coins as a share of its cost (coinShare), and the first need missing with the tier it is for,
-- "t<next>_<kinds|rarity|coins|ready>" ("ready": every need met).
StepGaps.NEEDS = { "kinds", "rarity", "coins", "ready", "closed" } -- closed: the next tier is held by its switch

function StepGaps.short(missing: number): string
	local n = if missing ~= missing then 0 else math.max(0, math.floor(missing))
	if n == 0 then
		return "0"
	elseif n <= 2 then
		return "1-2"
	elseif n <= 5 then
		return "3-5"
	end
	return "6+"
end

function StepGaps.quitNeedFields(
	missing: number,
	coins: number,
	cost: number,
	need: string,
	nextTier: number
): { string }
	local known = if table.find(StepGaps.NEEDS, need) ~= nil then need else "ready"
	return {
		StepGaps.short(missing),
		StepGaps.coinShare(coins, cost),
		string.format("t%d_%s", math.floor(nextTier), known),
	}
end

return StepGaps
