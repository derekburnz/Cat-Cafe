--!strict
-- #5506 (Design-Agent's daily-playtime-gifts-spec.md, Derek 2026-11-19: "focus on updates to help with funnel drop
-- offs and retention"): a ladder of ten gifts for minutes played today, behind the switch `dailyGifts`
-- (LiveFlags.OFF_BY_DEFAULT). The day is the UTC day (Spin.day). Time counts only while the player is in the game,
-- carries across rejoins on the same day and starts again at 0 on a new one. The gifts pay one at a time, in order,
-- on the HUD's existing Rewards tile and its countdown (Components/GiftLadderLogic reads the same GiftStepView rows),
-- with the usual "Gift! ..." toast: no new slot on a phone, no pop-up, no streak and nothing to buy. While the switch
-- is on, the once-per-account small steps (Config.PlaytimeGiftSteps) stop paying; the like and favourite cards stay.
-- Saved as profile.dailyGifts = { day, seconds, claimed } (claimed: the steps paid today, in order). Pure.
--   STEPS                                     the ladder
--   fresh(raw, day) -> State                  a save's state for `day` (a new day starts at 0)
--   add(state, day, seconds) -> State         count `seconds` more of play on `day`
--   due(state) -> number?                     the index of the step to pay now, if any
--   upcoming(state, playSeconds, n)           the next `n` steps as GiftStepView rows on the account's play clock
--   sanitize(raw) -> State?                   a save's field made safe

local Types = require(script.Parent.Types)

local DailyGifts = {}

DailyGifts.FLAG = "dailyGifts"
DailyGifts.DAY_SECONDS = 86400
DailyGifts.EVENT = "daily_gift" -- value the minutes played today; fields step, device, first day or later day

export type State = { day: number, seconds: number, claimed: number }
export type Step = { id: string, minutes: number, prize: Types.IndexPrize }

local STEPS: { Step } = {
	{ id = "d1", minutes = 1, prize = { coinSeconds = 60 } },
	{ id = "d3", minutes = 3, prize = { lures = { tuna = 1 } } },
	{ id = "d5", minutes = 5, prize = { spins = 1 } },
	{ id = "d8", minutes = 8, prize = { coinSeconds = 180 } },
	{ id = "d12", minutes = 12, prize = { fish = 5 } },
	{ id = "d16", minutes = 16, prize = { potions = { swift_potion = 1 } } },
	{ id = "d20", minutes = 20, prize = { spins = 2 } },
	{ id = "d30", minutes = 30, prize = { crates = { classic_crate = 1 } } },
	{ id = "d45", minutes = 45, prize = { fish = 15, coinSeconds = 300 } },
	{ id = "d60", minutes = 60, prize = { crates = { classic_golden_crate = 1 } } },
}
table.freeze(STEPS)
DailyGifts.STEPS = STEPS

function DailyGifts.day(now: number): number
	return math.floor(now / DailyGifts.DAY_SECONDS) -- Spin.day
end

local function number(raw: unknown): number?
	return if type(raw) == "number"
			and raw == raw
			and raw > -math.huge
			and raw < math.huge
		then raw
		else nil
end

function DailyGifts.sanitize(raw: unknown): State?
	if type(raw) ~= "table" then
		return nil
	end
	local day = number((raw :: any).day)
	if day == nil then
		return nil
	end
	local seconds = number((raw :: any).seconds) or 0
	local claimed = number((raw :: any).claimed) or 0
	return {
		day = math.floor(day),
		seconds = math.clamp(seconds, 0, DailyGifts.DAY_SECONDS),
		claimed = math.clamp(math.floor(claimed), 0, #DailyGifts.STEPS),
	}
end

function DailyGifts.fresh(raw: State?, day: number): State
	if raw ~= nil and raw.day == day then
		return raw
	end
	return { day = day, seconds = 0, claimed = 0 }
end

function DailyGifts.add(state: State, day: number, seconds: number): State
	local current = DailyGifts.fresh(state, day)
	if seconds > 0 then
		current.seconds = math.min(DailyGifts.DAY_SECONDS, current.seconds + seconds)
	end
	return current
end

function DailyGifts.due(state: State): number?
	local index = state.claimed + 1
	local step = DailyGifts.STEPS[index]
	if step ~= nil and state.seconds >= step.minutes * 60 then
		return index
	end
	return nil
end

-- The next `n` unpaid steps for the Rewards tile. GiftStepView's `at` is on the account's play clock (PlayerState
-- playSeconds, which the client counts on from), so each step's `at` is today's seconds still to go added to it.
function DailyGifts.upcoming(state: State, playSeconds: number, n: number): { Types.GiftStepView }
	local out: { Types.GiftStepView } = {}
	for index = state.claimed + 1, #DailyGifts.STEPS do
		if #out >= n then
			break
		end
		local step = DailyGifts.STEPS[index]
		local left = math.max(0, step.minutes * 60 - state.seconds)
		table.insert(
			out,
			{ id = step.id, at = playSeconds + left, prize = table.clone(step.prize) }
		)
	end
	return out
end

return DailyGifts
