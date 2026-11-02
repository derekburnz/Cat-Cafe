--!strict
-- The short night's words (F66, data-model v0.9 night closing; Derek 2026-10-27 19:40): the HUD clock chip's text,
-- the dusk warning in the last DuskWarningSeconds of the day, its banner, and whether the catching areas are open.
-- Pure: no Theme, so the cloud spec runner can load it.

export type Phase = "day" | "night"

local NightClock = {}

-- 4:05 -> "4:05", never below 0:00. A part second rounds to the nearest whole one, as the chip always has.
function NightClock.clock(remaining: number): string
	local seconds = math.max(0, math.floor(remaining + 0.5))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- The last `dusk` seconds of a day, while the areas are about to close.
function NightClock.isDusk(phase: Phase, remaining: number, dusk: number): boolean
	return phase == "day" and remaining > 0 and remaining <= dusk
end

-- "Day  4:12", "Night  1:05", and in the dusk warning "Night in 0:12".
function NightClock.chipText(phase: Phase, remaining: number, dusk: number): string
	if NightClock.isDusk(phase, remaining, dusk) then
		return "Night in " .. NightClock.clock(remaining)
	end
	return (if phase == "night" then "Night  " else "Day  ") .. NightClock.clock(remaining)
end

-- "Night falls in 15 s!", counted up so 14.2 s left still says 15.
function NightClock.duskTitle(remaining: number): string
	return ("Night falls in %d s!"):format(math.max(1, math.ceil(remaining)))
end

-- The Clock folder's AreasOpen attribute: only false closes the areas, so a server without F66 leaves them open.
function NightClock.areasOpen(value: any): boolean
	return value ~= false
end

return NightClock
