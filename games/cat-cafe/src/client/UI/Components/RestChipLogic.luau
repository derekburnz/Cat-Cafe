--!strict
-- #3574 (resting in your cafe): the words on the rest chip and where its drifting z's are, kept apart from the
-- chip so they can be tested without a screen.

local RestChipLogic = {}

RestChipLogic.Z_COUNT = 3
RestChipLogic.Z_SECONDS = 3.6 -- one z's whole drift; three take turns, so a new one starts every 1.2 s
RestChipLogic.Z_RISE = 16 -- px up
RestChipLogic.Z_SIDE = 9 -- px to the right
RestChipLogic.Z_SMALL, RestChipLogic.Z_BIG = 12, 15 -- text size at the start and the end (12: 9 px on a phone, the UI gate's floor)

-- The chip's words. "2x" is only shown while it is true (design section 5): during a 2x party the cat pay is not
-- doubled again, so the chip drops the number.
function RestChipLogic.words(doubled: boolean): string
	return if doubled then "Cozy cafe: 2x cat pay 💤" else "Cozy cafe 💤"
end

-- The z numbered `index` (from 1) at `t` seconds: how far right and up of its start it is (px), its text size and
-- how see-through it is (0 solid, 1 gone). Each fades in over its first fifth and out over its last half.
function RestChipLogic.z(index: number, t: number): (number, number, number, number)
	local period = RestChipLogic.Z_SECONDS
	local share = ((t + (index - 1) * period / RestChipLogic.Z_COUNT) % period) / period
	local x = RestChipLogic.Z_SIDE * share
	local y = -RestChipLogic.Z_RISE * share
	local size = RestChipLogic.Z_SMALL + (RestChipLogic.Z_BIG - RestChipLogic.Z_SMALL) * share
	local seen = if share < 0.2 then share / 0.2 elseif share > 0.5 then (1 - share) / 0.5 else 1
	return x, y, size, 1 - seen
end

return RestChipLogic
