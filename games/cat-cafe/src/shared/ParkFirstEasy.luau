--!strict
-- #5181 (Growth's Nov 17 device split, onboarding_v9 over 24 h: a third of phones that start their first Park catch
-- never finish it, 62 to 42, against 7% on a computer; tablets lose 26%). The Alleyway's bands are 1.2 times as wide
-- (its catchWindowScale) and stack with the touch scale, so a phone steps from 1.56 down to 1.3 at the Park. With the
-- switch `parkFirstEasy` on (LiveFlags.OFF_BY_DEFAULT), a catch in the Park keeps the Alleyway's 1.2 until the
-- player's first Park catch (onboarding first_park_catch), on every device. Pure.
--   scale(area, caughtThere, on) -> number   the extra width for a catch in `area`

local ParkFirstEasy = {}

ParkFirstEasy.FLAG = "parkFirstEasy"
ParkFirstEasy.AREA = "park"
ParkFirstEasy.SCALE = 1.2 -- the Alleyway's catchWindowScale
ParkFirstEasy.STEP = "first_park_catch" -- the onboarding step that ends it

function ParkFirstEasy.scale(area: string?, caughtThere: boolean, on: boolean): number
	return if on and area == ParkFirstEasy.AREA and not caughtThere then ParkFirstEasy.SCALE else 1
end

return ParkFirstEasy
