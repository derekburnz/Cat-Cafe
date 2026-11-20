--!strict
-- #5182 (Growth's Nov 17 device split, onboarding_v9 over 24 h: a third of phones that start their first Park catch
-- never finish it, 62 to 42, against 7% on a computer; tablets lose 26%). The Alleyway's bands are 1.2 times as wide
-- (its catchWindowScale) and stack with the touch scale, so a phone steps from 1.56 down to 1.3 at the Park. With the
-- switch `parkFirstEasy` on (LiveFlags.OFF_BY_DEFAULT), a catch in the Park keeps the Alleyway's 1.2 until the
-- player's first Park catch (onboarding first_park_catch), on every device. Pure.
--   scale(area, caughtThere, on) -> number   the extra width for a catch in `area`
-- #5496 (Growth Nov 19: a phone that starts its first Park catch still fails to finish it 36 to 40% of the time,
-- against 12% on a computer): below Tier 2 a phone, tablet or console catches for free (shared/FreeCatch), so the
-- Park is the first time those players meet the full rings, and every miss there sends the cat running with a
-- growing wait. A computer player has met the full rings from the start. With the switch `parkFirstCalm` on, a
-- missed Park catch on those devices leaves the cat put with no sprint or wait (CatService's calm miss) until the
-- player's first Park catch. The rings stay the real ones, so the player learns them where a miss costs nothing.
--   calm(area, caughtThere, device?, on) -> boolean   whether a miss in `area` leaves the cat put

local ParkFirstEasy = {}

ParkFirstEasy.FLAG = "parkFirstEasy"
ParkFirstEasy.AREA = "park"
ParkFirstEasy.SCALE = 1.2 -- the Alleyway's catchWindowScale
ParkFirstEasy.STEP = "first_park_catch" -- the onboarding step that ends it

function ParkFirstEasy.scale(area: string?, caughtThere: boolean, on: boolean): number
	return if on and area == ParkFirstEasy.AREA and not caughtThere then ParkFirstEasy.SCALE else 1
end

ParkFirstEasy.CALM_FLAG = "parkFirstCalm"
ParkFirstEasy.CALM_DEVICES =
	table.freeze({ phone = true, tablet = true, console = true }) :: { [string]: boolean } -- FreeCatch.DEVICES

function ParkFirstEasy.calm(
	area: string?,
	caughtThere: boolean,
	device: string?,
	on: boolean
): boolean
	return on
		and area == ParkFirstEasy.AREA
		and not caughtThere
		and device ~= nil
		and ParkFirstEasy.CALM_DEVICES[device] == true
end

return ParkFirstEasy
