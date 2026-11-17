--!strict
-- #5031 (Derek 2026-11-17 02:22 UTC: "figure out what the huge drop off is" between first_checkin and
-- rank_up_ready_shown, 48 to 35; Design-Agent's spec Design-Agent/dropoff-2026-11-17/checkin-to-rankup.md). After the
-- first check-in nothing reliably put the Rank Up in front of a new player. Pure; the server and the HUD read it.
--   Measuring (no switch): the Rank Up window opening at Tier 1 is reported at once (OPEN_REPORT, its `how`), and how
--     it ended (END_REPORT, its outcome); the server logs step 15 at the open and WINDOW_EVENT at the end, or
--     "left" when the player leaves with it open.
--   Switch `rankUpRightAway` (LiveFlags.OFF_BY_DEFAULT):
--     ready: the window opens by itself until it is pressed. Closed, it opens again the next time the player lands
--       in Town or their cafe, at most REOPENS times (againDue), and the goal card reads READY_TITLE (READY_NARROW
--       on a phone) beside its "Rank up!" sticker;
--     not ready (the bowl cat was let go, so Tier 2's cats are short): the goal card reads shortTitle(n) and a stray
--       waits near the Alleyway camp's landing, like SecondCat's, until Tier 2's cat need is met (catsShort).
--   catsShort(profile) -> number        Tier 2's cats still to get, at Tier 1 after the first check-in, else 0
--   strayWaits(profile, on) -> boolean  whether a stray waits for the player for that
--   againDue(o) -> boolean              whether a closed Rank Up window opens again now
--   shortTitle(n, narrow?) -> string    "Catch 1 more cat to rank up"; "Catch 1 more cat" on a phone's card

local Catalog = require(script.Parent.Catalog)
local Economy = require(script.Parent.Economy)
local Onboarding = require(script.Parent.Onboarding)
local Types = require(script.Parent.Types)

local RankUpRightAway = {}

RankUpRightAway.FLAG = "rankUpRightAway"
RankUpRightAway.REOPENS = 2 -- a closed window opens again at most this many times a session
RankUpRightAway.TIER = 1 -- the tier it helps (to Tier 2)
-- Design's "Rank up now! Your cafe is ready" did not fit beside the card's "Rank up!" sticker on any screen (uigate
-- GoalCardReadyTitle), so the sticker says the rank up and the title says why
RankUpRightAway.READY_TITLE = "Your cafe is ready!"
RankUpRightAway.READY_NARROW = "Cafe ready!" -- a phone's card (73 px for the title)
-- TelemetryReport names: the window opened (value a HOWS entry) and how it ended (value an OUTCOMES entry)
RankUpRightAway.OPEN_REPORT = "rank_up_open"
RankUpRightAway.END_REPORT = "rank_up_end"
RankUpRightAway.WINDOW_EVENT = "rank_up_window" -- the custom event; fields how, outcome
RankUpRightAway.HOWS = { "auto", "button" }
RankUpRightAway.OUTCOMES = { "pressed", "closed", "left" }
RankUpRightAway.WINDOWS_MAX = 8 -- rank_up_window events a session at most

function RankUpRightAway.catsShort(profile: Types.PlayerProfile): number
	if Economy.tier(profile) ~= RankUpRightAway.TIER then
		return 0
	end
	if not Onboarding.reached(profile.telemetry, "first_checkin") then
		return 0
	end
	local nextTier = Catalog.getTier(RankUpRightAway.TIER + 1)
	if nextTier == nil then
		return 0
	end
	local have = Economy.rankUpCats(profile.collection, profile.cats, nextTier)
	return math.max(0, nextTier.distinctCats - have)
end

function RankUpRightAway.strayWaits(profile: Types.PlayerProfile, on: boolean): boolean
	return on and RankUpRightAway.catsShort(profile) > 0
end

-- (Sync's 667 x 317 phone: the long line clipped on the goal card, so a phone's card drops "to rank up"; the
-- "Opens Cozy Cafe" line under it says what the cat is for)
function RankUpRightAway.shortTitle(n: number, narrow: boolean?): string
	local cats = if n <= 1 then "Catch 1 more cat" else string.format("Catch %d more cats", n)
	return if narrow then cats else cats .. " to rank up"
end

export type Again = {
	on: boolean, -- the switch
	ready: boolean, -- the rank up is ready
	pressed: boolean, -- RANK UP was pressed this session for this tier
	closes: number, -- times the window was closed without a press this session for this tier
	reopened: number, -- `closes` when it last opened again (0 before), so each close brings at most one reopen
	landed: boolean, -- the player just came into Town or their cafe from somewhere else
}

function RankUpRightAway.againDue(o: Again): boolean
	return o.on
		and o.ready
		and not o.pressed
		and o.landed
		and o.closes > o.reopened
		and o.closes <= RankUpRightAway.REOPENS
end

return RankUpRightAway
