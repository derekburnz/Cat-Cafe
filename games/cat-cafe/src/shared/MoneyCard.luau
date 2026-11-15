--!strict
-- #4437 (zero-sales dig, Derek 2026-11-15): the HUD's 2x Money button first opens a small boost card that says what
-- the pass does for this cafe, and only its Buy button opens Roblox's prompt. Gameplay-Engineer's half: the numbers
-- and the telemetry. The card itself (Screens, MenuFamily) is Design-Agent's.
--   MoneyCard.perMinute(prizeRate, current, rung) -> (now, with)
--       now: the cafe's money a minute today; with: a minute with the `rung` Money pass (2, 3 or 4). `prizeRate` is
--       PlayerState.prizeRate (Economy.incomePerSecond, day rate) and `current` is PlayerState.passBoosts.money (the
--       Money pass or Starter Bundle multiplier already in it, 1 without). A rung at or under `current` adds nothing.
--   MoneyCard.SOURCE        PassShop.prompt's source for the card's Buy (StoreFunnel.BUY_SOURCES), so purchase_source
--                           tells the card's sales apart
--   MoneyCard.TELEMETRY     TelemetryReport name; values OUTCOMES, each logged once a session as money_card
--   MoneyCard.OUTCOMES      shown, buy (Buy pressed), closed (the X), hidden (something else took the screen)
--   MoneyCard.report(raw) -> (outcome, rung)
--                           a TelemetryReport value "<outcome>:<rung>" read, or nil, nil for anything else
-- No countdown, no "only X left" (young audience rule).

local MoneyCard = {}

MoneyCard.SOURCE = "money_card"
MoneyCard.TELEMETRY = "money_card"
MoneyCard.OUTCOMES = { "shown", "buy", "closed", "hidden" }
MoneyCard.RUNGS = { 2, 3, 4 }

local function clean(x: number, fallback: number): number
	if x ~= x or x == math.huge or x == -math.huge then
		return fallback
	end
	return x
end

function MoneyCard.perMinute(prizeRate: number, current: number, rung: number): (number, number)
	local rate = math.max(0, clean(prizeRate, 0))
	local have = math.max(1, clean(current, 1))
	local now = math.floor(rate * 60)
	local base = rate / have
	local with = math.floor(base * math.max(have, clean(rung, 1)) * 60)
	return now, with
end

-- The next Money pass rung above `current` (2, 3 or 4), or nil when the player has the top one.
function MoneyCard.nextRung(current: number): number?
	for _, rung in MoneyCard.RUNGS do
		if rung > current then
			return rung
		end
	end
	return nil
end

function MoneyCard.report(raw: unknown): (string?, number?)
	if type(raw) ~= "string" or #raw > 16 then
		return nil, nil
	end
	local outcome, digit = string.match(raw, "^(%a+):(%d)$")
	local rung = tonumber(digit)
	if
		outcome == nil
		or rung == nil
		or table.find(MoneyCard.OUTCOMES, outcome) == nil
		or table.find(MoneyCard.RUNGS, rung) == nil
	then
		return nil, nil
	end
	return outcome, rung
end

return MoneyCard
