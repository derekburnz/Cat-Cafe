--!strict
-- Derek 2026-11-17 15:24 UTC ("sure do 50/50 for the pal day and tmmr card"; Growth-Agent's plan
-- Growth-Agent/ab-2026-11-17/return-day-ab-plan.md): two 50/50 tests on new accounts, split by user id.
--   tomorrowCard: the come back tomorrow card (UI tomorrowCard.try). Group floor(userId / 2) % 2.
--   palDay: the Pal Day gift (PalDayService) and its goal line (ReturnGoals). Group floor(userId / 4) % 2.
-- Never userId % 2 (IntroSplit uses it), so the three tests cross evenly. Only accounts first seen on or after the
-- test's START_DAY (telemetry.firstDay, a UTC day number) are in it, so an older player's habit never dilutes it;
-- everyone else keeps the feature as before. Both read only what the save already holds, so no save field. The
-- server logs `ab_return` once a session for an account in a test (field 1 the test, 2 "on" or "off", 3 device).
-- Pure.

local ReturnAB = {}

export type Test = "tomorrowCard" | "palDay"

ReturnAB.EVENT = "ab_return"
ReturnAB.TESTS = table.freeze({
	-- the test starts at the UTC day boundary after the publish, so day 1 and day 7 cohorts are whole days
	tomorrowCard = table.freeze({ divisor = 2, startDay = 20775 }), -- Wed 2026-11-18 00:00 UTC
	palDay = table.freeze({ divisor = 4, startDay = 20776 }), -- Thu 2026-11-19 00:00 UTC, after the Wed restart
}) :: { [string]: { divisor: number, startDay: number } }
ReturnAB.NAMES = { "tomorrowCard", "palDay" } :: { Test }

-- "on" or "off" for an account in `test`, nil for one outside it (first seen before its start, or an id that is not
-- a positive whole number, such as a Studio test player).
function ReturnAB.group(test: Test, userId: unknown, firstDay: unknown): ("on" | "off")?
	local def = ReturnAB.TESTS[test]
	if def == nil or type(userId) ~= "number" or userId <= 0 or userId ~= math.floor(userId) then
		return nil
	end
	if type(firstDay) ~= "number" or firstDay < def.startDay then
		return nil
	end
	return if math.floor(userId / def.divisor) % 2 == 0 then "on" else "off"
end

-- Whether the feature under `test` may show for this account: false only in the test's off group.
function ReturnAB.allows(test: Test, userId: unknown, firstDay: unknown): boolean
	return ReturnAB.group(test, userId, firstDay) ~= "off"
end

return ReturnAB
