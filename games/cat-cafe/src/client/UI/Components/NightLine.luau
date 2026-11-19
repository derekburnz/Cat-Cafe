--!strict
-- #5330 (#5285 E, Design-Agent's stall-fixes spec, from Sync's fresh-account run: night held a new player in town with
-- every cannon refused and an empty strip at minutes 3.4 and 9.8), switch `nightLine` (off by default): while the areas
-- are closed at night, a player past the tutorial at Tier MAX_TIER or under gets one strip line with the time to
-- sunrise, and a ring and arrow (no dim) on the HUD's Upgrades. A tap opens nothing; the player taps Upgrades. The
-- line hides at sunrise and while any window is open. Pure.
--   shows(on, tier, step, areasOpen, windowOpen) -> boolean
--   text(seconds) -> string                     "Areas open at sunrise in 0:42. Upgrade your cafe while you wait"
--   arrow(showing, noArrow) -> boolean          #5459 (Derek 2026-11-19: "remove this random arrow pointing to upgrades
--                                               no need for that ever"): the ring and arrow on Upgrades, never with
--                                               switch `nightLineNoArrow` on

local NightLine = {}

NightLine.FLAG = "nightLine"
NightLine.MAX_TIER = 4
NightLine.NO_ARROW_FLAG = "nightLineNoArrow"
NightLine.DONE_STEP = 5 -- the tutorial's last step (TutorialHints.DONE)

function NightLine.shows(
	on: boolean,
	tier: number?,
	step: number?,
	areasOpen: boolean,
	windowOpen: boolean
): boolean
	return on
		and not areasOpen
		and not windowOpen
		and (step or 0) >= NightLine.DONE_STEP
		and (tier or 1) <= NightLine.MAX_TIER
end

function NightLine.arrow(showing: boolean, noArrow: boolean): boolean
	return showing and not noArrow
end

function NightLine.text(seconds: number): string
	local left = math.max(0, math.ceil(if seconds == seconds then seconds else 0))
	return string.format(
		"Areas open at sunrise in %d:%02d. Upgrade your cafe while you wait",
		left // 60,
		left % 60
	)
end

return NightLine
