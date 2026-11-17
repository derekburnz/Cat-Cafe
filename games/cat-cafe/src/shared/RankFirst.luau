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
-- #4654: the `rankFirst` switch is retired; this is always the order and the close.
-- Pure.

local RankFirst = {}

RankFirst.REST_SECONDS = 20 -- a press outside the spotlight hides it this long
RankFirst.PRESSES = 3 -- the press that puts it away for good
-- #4836 (Sync's pointer audit: the strip said "Tap YOUR GOAL" while the arrow pointed at the green RANK UP button):
-- the line names the button the arrow and the strip's own button show
-- #4926 (Derek 2026-11-16: what to do and why): and what the rank up opens
RankFirst.LINES = table.freeze({
	touch = "Rank up! Tap RANK UP to open the Park",
	keyboard = "Rank up! Click RANK UP to open the Park",
	gamepad = "Rank up! Select RANK UP to open the Park",
})

-- The strip's button beside a rank up line (client HUD): it opens the rank up window from anywhere, since the
-- walk-through's spotlight only shows on the safe side of the gates (the Nov 16 drop-off read: 148 of 431 ready
-- players never pressed).
RankFirst.BUTTON = "RANK UP"

-- Whether the rank up goes first now: the cafe at Tier 1 and every Tier 2 need met.
function RankFirst.holds(tier: number?, ready: boolean): boolean
	return (tier or 1) == 1 and ready
end

-- The strip's line for a device ("touch", "keyboard" or "gamepad"; anything else reads as keyboard).
function RankFirst.line(device: string): string
	local lines: { [string]: string } = RankFirst.LINES :: any
	return lines[device] or lines.keyboard
end

-- Whether a strip line is one of the rank up lines. The cannon's wrap-up hint ("Hop in the cannon to catch more
-- cats!", CannonLogic.WRAP_UP_HINT) comes the moment the walk-through ends, which is when Tier 2 gets ready, so it gives
-- way to a rank up line (Review-QA's laptop run of #4388: the strip kept the cannon line).
function RankFirst.isLine(text: string?): boolean
	if text == nil then
		return false
	end
	local lines = RankFirst.LINES
	for _, line in { lines.touch, lines.keyboard, lines.gamepad } do
		if line == text then
			return true
		end
	end
	return false
end

-- Whether a press outside the spotlight puts it away for good: only the PRESSES-th of this session.
function RankFirst.forGood(presses: number): boolean
	return presses >= RankFirst.PRESSES
end

return RankFirst
