--!strict
-- #5499 (Design-Agent's holdout note, Derek 2026-11-19: "focus on updates to help with funnel drop offs and
-- retention"): a frozen control group for the new retention switches, behind the switch `holdout`
-- (LiveFlags.OFF_BY_DEFAULT). It is forward only: a save joins at its first session while the switch is on, so only
-- accounts that first join on or after the day it goes on are in it. One account in ten (a stable pick from the user
-- id, apart from the bits IntroSplit and TutorialOrder use) is held: for HOLD_DAYS from its first day, every switch in
-- KEYS reads as off for it, on the server (LiveFlagService.on(key, player)) and the client (the Holdout attribute).
-- The rest are "live". The group is saved in profile.telemetry.holdout (no save version, like orderGroup) and goes
-- out as custom field 3 of the funnel's steps, session_5m and the D1 return for a save in no other test.
-- A held save is never in the walk-through order test (orderSplit reads off), so it always gets the bowl first arm.
-- Pure.
--   group(userId) -> string            HELD or LIVE
--   valid(raw) -> string?              a saved group made safe
--   joins(on, sessions, tutorialStep, group) -> boolean
--   held(group, firstDay, now) -> boolean
--   gated(key) -> boolean              whether `key` is one the holdout holds back

local Holdout = {}

Holdout.FLAG = "holdout"
Holdout.ATTR = "Holdout" -- Player attribute, true while held this session
Holdout.HELD = "holdout"
Holdout.LIVE = "live"
Holdout.EVENT = "holdout_group" -- Telemetry.custom, once as a save joins (field 1: the group)
Holdout.PER_TEN = 1
Holdout.HOLD_DAYS = 7
Holdout.DAY_SECONDS = 86400

-- The new retention switches a held save does not get.
local KEYS: { [string]: boolean } = {
	dailyGifts = true, -- #5506
	awayPromise = true, -- #5505: days played milestones and the away row
	orderSplit = true, -- #5498: a held save stays out of the order test
	returnMoment = true, -- #5505: plan A fix 3, the welcome back card's days line and the Rank Up strip line
}
table.freeze(KEYS)
Holdout.KEYS = KEYS

function Holdout.group(userId: number): string
	return if math.floor(userId / 4) % 10 < Holdout.PER_TEN then Holdout.HELD else Holdout.LIVE
end

function Holdout.valid(raw: unknown): string?
	if raw == Holdout.HELD or raw == Holdout.LIVE then
		return raw :: string
	end
	return nil
end

-- Whether a loading save joins now: the switch on, no group yet, its first session, the walk-through not begun.
function Holdout.joins(on: boolean, sessions: number, tutorialStep: number, group: string?): boolean
	return on and group == nil and sessions <= 1 and tutorialStep == 0
end

-- Whether a save in `group` that first joined on UTC day `firstDay` is held back at `now`.
function Holdout.held(group: string?, firstDay: number, now: number): boolean
	return group == Holdout.HELD and now // Holdout.DAY_SECONDS - firstDay < Holdout.HOLD_DAYS
end

function Holdout.gated(key: string): boolean
	return KEYS[key] == true
end

return Holdout
