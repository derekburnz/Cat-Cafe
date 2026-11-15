--!strict
-- #4383 (Derek 2026-11-15: "still the drop off at second cat and tier 2 upgrade seems to be huge"; Design-Agent's
-- dropoff-2026-11-15 write-up). Tier 2 is ready about when the tutorial's bait cat is done (#4199), and two things
-- kept new players from pressing it:
--   the stuck cat goal (shared/StuckGoal, #2912) took the goal card and the strip for 120 s and sent the player into
--     the Alleyway, where the rank up walk-through (shared/RankSpot, #3555) never shows. While a Tier 1 cafe can rank
--     up, the stuck cat goal now waits (`holds`) and the strip says so (`line`);
--   any press outside the walk-through's spotlight after RankSpot.KEEP_SECONDS put it away for good, and a phone
--     player's first thumbstick touch is such a press. A press now only rests it REST_SECONDS; the PRESSES-th puts it
--     away (`forGood`).
-- Switch `rankFirst` (LiveFlags), on unless switched off: off gives back the old order and the old one-press close.
-- Pure.

local RankFirst = {}

RankFirst.FLAG = "rankFirst"
RankFirst.REST_SECONDS = 20 -- a press outside the spotlight hides it this long
RankFirst.PRESSES = 3 -- the press that puts it away for good
RankFirst.LINES = table.freeze({
	touch = "Rank up! Tap YOUR GOAL",
	keyboard = "Rank up! Click YOUR GOAL",
	gamepad = "Rank up! Select YOUR GOAL",
})

-- Whether the rank up goes first now: the switch on, the cafe at Tier 1 and every Tier 2 need met.
function RankFirst.holds(on: boolean, tier: number?, ready: boolean): boolean
	return on and (tier or 1) == 1 and ready
end

-- The strip's line for a device ("touch", "keyboard" or "gamepad"; anything else reads as keyboard).
function RankFirst.line(device: string): string
	local lines: { [string]: string } = RankFirst.LINES :: any
	return lines[device] or lines.keyboard
end

-- Whether a press outside the spotlight puts it away for good: with the switch off every such press does (the old
-- rule, RankSpot.putsAway deciding), with it on only the PRESSES-th of this session.
function RankFirst.forGood(on: boolean, presses: number): boolean
	return not on or presses >= RankFirst.PRESSES
end

return RankFirst
